import Foundation

/// Wraps `AVAudioEngine` for 16 kHz mono PCM capture, with route/interruption handling.
/// Implementation deferred to M3. See `docs/TDD.md` §5.1.
final class AudioRecorder: Sendable {
  // Intentionally empty in M0. M3 implements:
  //   - AVAudioEngine setup with .measurement mode
  //   - 16 kHz mono Float32 tap
  //   - max-duration timer (from RecordingConfig.maxDuration)
  //   - interruption + route-change handling
  //   - os_proc_available_memory() safety net
}
