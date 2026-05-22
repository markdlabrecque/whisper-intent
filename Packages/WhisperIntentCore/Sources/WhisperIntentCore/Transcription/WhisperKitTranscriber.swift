import Foundation

/// Adapter over the WhisperKit library. Loads the bundled medium model and runs
/// transcription on captured PCM. Implementation deferred to M3.
/// See `docs/TDD.md` §6.
final class WhisperKitTranscriber: Sendable {
  // Intentionally empty in M0. M3 implements:
  //   - lazy model load from Resources/Models/openai_whisper-medium/
  //   - transcribe([Float]) async throws -> String with progress callback
  //   - emit `TranscriptionProgress` updates with shape decided by spike S1
}
