import Foundation
@preconcurrency import WhisperKit

/// Production `Transcribing` over WhisperKit. Loads the bundled medium model on
/// first use, then reuses it for subsequent calls in the same process.
///
/// Progress is emitted as the indeterminate-phase shape decided by spike S1
/// (`docs/spikes/S1-progress-callbacks.md`): `.starting` is emitted by
/// `TranscriptionSession` before calling here; this transcriber emits
/// `.phase(.encoding)` once the model is ready and the transcribe loop begins,
/// then `.phase(.decoding)` on the first per-token progress callback, then
/// `.finishing` once WhisperKit returns. See `docs/TDD.md` §6.
public final class WhisperKitTranscriber: Transcribing, @unchecked Sendable {
  private let lock = NSLock()
  private var whisperKit: WhisperKit?

  public init() {}

  public func transcribe(
    audio: [Float],
    progress: @Sendable @escaping (TranscriptionProgress) -> Void
  ) async throws -> String {
    do {
      let kit = try await loadModelIfNeeded()
      progress(.phase(.encoding))

      let phaseAdvancer = PhaseAdvancer(progress: progress)
      let callback: TranscriptionCallback = { _ in
        phaseAdvancer.advanceToDecodingIfNeeded()
        return true
      }

      let results = try await kit.transcribe(
        audioArray: audio,
        decodeOptions: nil,
        callback: callback
      )

      progress(.finishing)
      return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
      throw SessionError.transcriptionFailed(underlying: "\(error)")
    }
  }

  // MARK: - Model load

  private func loadModelIfNeeded() async throws -> WhisperKit {
    if let kit = lock.withLock({ whisperKit }) {
      return kit
    }
    guard let modelURL = Bundle.main.url(
      forResource: "openai_whisper-medium",
      withExtension: nil
    ) else {
      throw SessionError.transcriptionFailed(
        underlying: "WhisperKit medium model folder not found in app bundle."
      )
    }

    let kit = try await WhisperKit(
      modelFolder: modelURL.path,
      verbose: false,
      logLevel: .info,
      prewarm: true,
      load: true,
      download: false
    )
    lock.withLock { whisperKit = kit }
    return kit
  }
}

/// Latches the encoding → decoding transition so the per-token callback can
/// trigger it exactly once. Thread-safe; WhisperKit may invoke the callback from
/// any queue.
private final class PhaseAdvancer: @unchecked Sendable {
  private let lock = NSLock()
  private var advanced = false
  private let progress: @Sendable (TranscriptionProgress) -> Void

  init(progress: @Sendable @escaping (TranscriptionProgress) -> Void) {
    self.progress = progress
  }

  func advanceToDecodingIfNeeded() {
    let shouldFire: Bool = lock.withLock {
      guard !advanced else { return false }
      advanced = true
      return true
    }
    if shouldFire {
      progress(.phase(.decoding))
    }
  }
}
