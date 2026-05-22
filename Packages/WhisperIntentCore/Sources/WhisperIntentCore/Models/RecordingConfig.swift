import Foundation

/// Per-invocation recording parameters passed from the AppIntent down to
/// `TranscriptionSession`. `Show UI` is not present here — it's a presentation decision
/// owned by the AppIntent, not a recording-domain concern. See `docs/TDD.md` §3.
public struct RecordingConfig: Sendable, Equatable {
  /// Silence threshold for the voice-activity detector, in seconds.
  /// Set to 0 to disable VAD.
  public let silenceThreshold: TimeInterval

  /// Maximum recording duration before auto-stop. Pinned at build time from spike S3.
  /// See PRD §5.4.1 and `docs/spikes/S3-background-budget.md`.
  public let maxDuration: TimeInterval

  /// Optional prompt shown above the recording UI. Cosmetic only.
  public let prompt: String?

  public init(
    silenceThreshold: TimeInterval,
    maxDuration: TimeInterval,
    prompt: String? = nil
  ) {
    self.silenceThreshold = silenceThreshold
    self.maxDuration = maxDuration
    self.prompt = prompt
  }
}
