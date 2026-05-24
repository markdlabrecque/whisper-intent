import Foundation

/// Contract for an audio-capture backend. Decoupled from the concrete
/// `AudioRecorder` (AVAudioEngine) so `TranscriptionSession` is testable with mocks.
/// See `docs/TDD.md` §3 + §5.1.
public protocol AudioRecording: Sendable {
  /// Begins capture. The session subscribes to two streams:
  /// - `buffers`: 16 kHz mono Float32 PCM frames, delivered as they arrive. Used to
  ///   drive the VAD and the on-screen level meter, and accumulated by the recorder
  ///   into the final captured buffer returned by `stop()`.
  /// - `level`: a downsampled RMS level for UI metering (~20 Hz cadence).
  ///
  /// `maxDuration` is enforced by the recorder; when the elapsed wall-clock reaches
  /// it, capture stops as if the user tapped Stop. The recorder transitions itself
  /// to a stopped state and the next `stop()` call returns the captured PCM.
  ///
  /// Throws `SessionError.permissionDenied` if the mic permission is denied,
  /// `SessionError.interrupted` for audio-session interruptions, or
  /// `SessionError.outOfMemory` if the capture exceeds available memory.
  func start(
    maxDuration: TimeInterval,
    buffers: @Sendable @escaping ([Float]) -> Void,
    level: @Sendable @escaping (Float) -> Void
  ) async throws

  /// Stops capture if active and returns the accumulated PCM. Idempotent: calling
  /// `stop()` after the recorder has self-stopped (max-duration, interruption)
  /// returns the captured audio without error.
  func stop() async throws -> [Float]

  /// Aborts capture without returning audio. Used by error paths.
  func cancel() async
}
