import Foundation

/// Contract for an audio-capture backend. Decoupled from the concrete
/// `AudioRecorder` (AVAudioEngine) so `TranscriptionSession` is testable with mocks.
/// See `docs/TDD.md` §3 + §5.1.
public protocol AudioRecording: Sendable {
  /// Begins capture. The session subscribes to three streams:
  /// - `buffers`: 16 kHz mono Float32 PCM frames, delivered as they arrive. Used to
  ///   drive the VAD and the on-screen level meter, and accumulated by the recorder
  ///   into the final captured buffer returned by `stop()`.
  /// - `level`: a downsampled RMS level for UI metering (~20 Hz cadence).
  /// - `stopped`: invoked when the recorder ends capture on its own (max-duration
  ///   reached, audio-session interruption, route loss). `.normal` means "I stopped
  ///   capturing cleanly — call `stop()` to retrieve the audio." `.failure(error)`
  ///   means "I stopped because of `error` — call `stop()` which will throw it."
  ///   Never fires for caller-initiated `stop()` or `cancel()`.
  ///
  /// `maxDuration` is the upper bound the recorder enforces internally; a
  /// `.normal` `stopped` event fires when the cap is reached. The session may also
  /// enforce its own cap on top of this; whichever fires first wins.
  ///
  /// Throws `SessionError.permissionDenied` if mic permission is denied or
  /// `SessionError.transcriptionFailed` for engine setup failures. Audio-session
  /// interruptions are reported via `stopped`, not by throwing from `start`.
  func start(
    maxDuration: TimeInterval,
    buffers: @Sendable @escaping ([Float]) -> Void,
    level: @Sendable @escaping (Float) -> Void,
    stopped: @Sendable @escaping (AudioRecorderStopReason) -> Void
  ) async throws

  /// Stops capture if active and returns the accumulated PCM. If the recorder
  /// previously self-stopped via `.normal`, returns the captured audio. If it
  /// self-stopped via `.failure(error)`, throws that error.
  func stop() async throws -> [Float]

  /// Aborts capture without returning audio. Used by error paths.
  func cancel() async
}

/// Why an `AudioRecording` self-stopped, surfaced through the `stopped` callback
/// passed to `start`.
public enum AudioRecorderStopReason: Sendable, Equatable {
  /// Recorder ended capture cleanly. The next `stop()` call returns the audio.
  case normal
  /// Recorder ended capture because of an error. The next `stop()` call throws it.
  case failure(SessionError)
}
