import Foundation

/// Progress reported by `WhisperKitTranscriber` during transcription.
///
/// The exact case used by v1 (`.progress(...)` for determinate, or `.phase(_:)` for
/// indeterminate) is decided by spike S1. Both cases are declared here so the rest of
/// the code compiles regardless of the outcome; the unused case will be deleted when S1
/// closes. See `docs/spikes/S1-progress-callbacks.md`.
public enum TranscriptionProgress: Sendable, Equatable {
  case starting
  case progress(fraction: Double, phase: Phase)
  case phase(Phase)
  case finishing

  public enum Phase: String, Sendable, Equatable {
    case encoding
    case decoding
  }
}
