import Foundation

/// Contract for a transcription backend. Decoupled from the concrete
/// `WhisperKitTranscriber` so `TranscriptionSession` can be unit-tested with mocks.
/// See `docs/TDD.md` §3 + §6.
public protocol Transcribing: Sendable {
  /// Loads the model if not yet loaded, then transcribes `audio` (16 kHz mono
  /// Float32 PCM). Emits `TranscriptionProgress` updates through `progress` as the
  /// backend works. Throws `SessionError.transcriptionFailed(underlying:)` on any
  /// backend failure.
  ///
  /// First call in the process pays the model-load cost; subsequent calls reuse it.
  func transcribe(
    audio: [Float],
    progress: @Sendable @escaping (TranscriptionProgress) -> Void
  ) async throws -> String
}
