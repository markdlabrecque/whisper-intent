import Foundation

/// Energy-based voice activity detector. Implementation deferred to M3.
/// See `docs/TDD.md` §5.2.
final class VoiceActivityDetector: Sendable {
  // Intentionally empty in M0. M3 implements:
  //   - 30ms RMS sliding window
  //   - 500ms warmup noise-floor calibration
  //   - configurable silence threshold (from RecordingConfig.silenceThreshold)
  //   - emit a single stop signal when silence is sustained past threshold
}
