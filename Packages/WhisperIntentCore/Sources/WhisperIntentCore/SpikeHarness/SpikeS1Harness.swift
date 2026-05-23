import Foundation
@preconcurrency import WhisperKit

/// Spike S1 — measures WhisperKit medium's progress-callback granularity by
/// wiring every available callback (model state, transcription state, per-token
/// progress, segment discovery) and emitting timestamped events.
///
/// The harness is intentionally separate from `WhisperKitTranscriber`. The
/// transcriber's final API (`.progress(...)` vs `.phase(_:)`) is decided by
/// this spike — coupling the two would put the cart before the horse.
public final class SpikeS1Harness: @unchecked Sendable {
  /// Callback that fires for each observation. Implementations must be
  /// non-blocking — WhisperKit's docs warn that slow callbacks add extra
  /// decoding loops. We hop to a background queue inside before notifying the
  /// observer to be safe.
  public typealias Observer = @Sendable (SpikeLogEvent) -> Void

  private let observer: Observer
  private let observerQueue = DispatchQueue(label: "spike-s1-observer", qos: .utility)
  private var startTime: Date = .init()
  private var whisperKit: WhisperKit?

  public init(observer: @escaping Observer) {
    self.observer = observer
  }

  /// Loads the bundled medium model + transcribes the file at `audioURL`.
  /// All callbacks are wired and reported through the observer.
  public func run(audioURL: URL) async {
    startTime = Date()
    emit(.harnessStart, "audio=\(audioURL.lastPathComponent)")

    do {
      try await loadModelIfNeeded()
      guard let whisperKit else {
        emit(.harnessError, "whisperKit nil after load")
        return
      }

      emit(.transcribeStart, "")

      // Wire segment + state callbacks on the WhisperKit instance.
      whisperKit.segmentDiscoveryCallback = { [weak self] segments in
        guard let self else { return }
        let summary = "segments=\(segments.count) lastEnd=\(segments.last?.end ?? 0)"
        emit(.segmentDiscovered, summary)
      }
      whisperKit.transcriptionStateCallback = { [weak self] state in
        guard let self else { return }
        emit(.transcriptionState, "state=\(state.description)")
      }
      whisperKit.modelStateCallback = { [weak self] _, new in
        guard let self else { return }
        emit(.modelState, "state=\(new)")
      }

      // The per-token progress callback runs inside transcribe(...).
      // We must return `nil`/`true` to continue, never `false` (that aborts).
      let callback: TranscriptionCallback = { [weak self] progress in
        guard let self else { return true }
        // Keep payload tiny — full text grows linearly and floods the log.
        let summary = "tokens=\(progress.tokens.count) windowId=\(progress.windowId)"
        emit(.progress, summary)
        return true
      }

      let results = try await whisperKit.transcribe(
        audioPath: audioURL.path,
        decodeOptions: nil,
        callback: callback
      )

      let text = results.map(\.text).joined(separator: " ")
      let preview = text.prefix(120)
      emit(.transcribeEnd, "chars=\(text.count) preview=\"\(preview)…\"")
    } catch {
      emit(.harnessError, "error=\(error)")
    }
  }

  // MARK: - Model load

  private func loadModelIfNeeded() async throws {
    guard whisperKit == nil else { return }
    emit(.modelLoadStart, "")

    // Bundled at <app>/openai_whisper-medium/ — see project.yml folder-reference
    // resource entry. The model directory itself isn't a .bundle, so
    // `url(forResource:withExtension:)` finds it as a folder.
    guard let modelURL = Bundle.main.url(forResource: "openai_whisper-medium", withExtension: nil) else {
      emit(.harnessError, "model folder not found in bundle")
      throw HarnessError.modelMissing
    }

    let kit = try await WhisperKit(
      modelFolder: modelURL.path,
      verbose: false,
      logLevel: .info,
      prewarm: true,
      load: true,
      download: false
    )
    whisperKit = kit
    emit(.modelLoadEnd, "modelFolder=\(modelURL.lastPathComponent)")
  }

  // MARK: - Emit helper

  private func emit(_ kind: SpikeLogEvent.Kind, _ summary: String) {
    let elapsed = Date().timeIntervalSince(startTime)
    let event = SpikeLogEvent(kind: kind, elapsed: elapsed, summary: summary)
    observerQueue.async { [observer] in
      observer(event)
    }
  }

  public enum HarnessError: Error {
    case modelMissing
  }
}
