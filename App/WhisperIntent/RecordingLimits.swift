import Foundation

/// Single source of truth for the max-duration cap baked into v1.
///
/// **Placeholder until S3 closes.** Spike S3
/// (`docs/spikes/S3-background-budget.md`) measures the largest recording
/// duration iOS will reliably allow when the AppIntent runs with
/// `showUI = false` on the oldest supported device. Until those numbers
/// land, this constant is a generous upper bound that lets development
/// proceed without an artificial cap masking real behaviour.
///
/// When S3 closes, update `maxRecordingSeconds` here and propagate the
/// number to PRD §5.4.1, the AppIntent description string, onboarding
/// copy, and the App Store listing. Nothing else should hardcode a cap.
enum RecordingLimits {
  /// Maximum recording duration in seconds. Placeholder — see file comment.
  static let maxRecordingSeconds: TimeInterval = 600

  /// Threshold (fraction of cap) above which the recording UI shifts to its
  /// "warning" treatment (TDD §7.3). Cap-relative so the threshold tracks
  /// the cap when S3 lands.
  static let warningThreshold: Double = 0.80

  /// Threshold (fraction of cap) above which the recording UI shifts to its
  /// "critical" treatment (TDD §7.3).
  static let criticalThreshold: Double = 0.95
}
