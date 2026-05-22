import AppIntents
import WhisperIntentCore

/// The headline AppIntent (PRD §5.1, TDD §7.1).
/// Records audio, transcribes on-device with WhisperKit, returns the transcript as a String.
/// Implementation deferred to M5 (after S2 confirms foreground-escalation API).
struct TranscribeSpeechIntent: AppIntent {
  static var title: LocalizedStringResource = "Transcribe Speech"

  static var description = IntentDescription(
    """
    Record audio and return the transcript as text. Use this as a step in a Shortcut \
    to capture voice input for any destination.
    """
  )

  @Parameter(title: "Silence threshold (seconds)", default: 2.0)
  var silenceThreshold: Double

  @Parameter(title: "Show UI", default: true)
  var showUI: Bool

  @Parameter(title: "Prompt", default: nil)
  var prompt: String?

  static var openAppWhenRun: Bool {
    false
  }

  @MainActor
  func perform() async throws -> some IntentResult & ReturnsValue<String> {
    // Deferred to M5. See docs/TDD.md §7.1 and docs/spikes/S2-foreground-escalation.md.
    .result(value: "")
  }
}
