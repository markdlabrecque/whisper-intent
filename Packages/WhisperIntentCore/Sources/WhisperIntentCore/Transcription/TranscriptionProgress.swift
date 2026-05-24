import Foundation

/// Progress reported by `WhisperKitTranscriber` during transcription.
/// Spike S1 resolved v1 to an indeterminate spinner with phase labels: WhisperKit
/// emits frequent callbacks, but not a stable total-work denominator for a truthful
/// 0...1 progress bar. See `docs/spikes/S1-progress-callbacks.md`.
public enum TranscriptionProgress: Sendable, Equatable {
  case starting
  case phase(Phase)
  case finishing

  public enum Phase: String, Sendable, Equatable {
    case encoding
    case decoding
  }
}
