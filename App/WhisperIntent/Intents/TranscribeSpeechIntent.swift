import AppIntents
import WhisperIntentCore

/// The headline AppIntent (PRD §5.1, TDD §7.1). Records audio, transcribes
/// on-device with WhisperKit, returns the transcript as a `String`. M4 wires the
/// minimum viable surface needed by spike S3 (`docs/spikes/S3-background-budget.md`).
/// M5 layers a polished foreground sheet on top of the same plumbing.
struct TranscribeSpeechIntent: AppIntent {
  static let title: LocalizedStringResource = "Transcribe Speech"

  static let description = IntentDescription(
    """
    Record audio and return the transcript as text. Use this as a step in a Shortcut \
    to capture voice input for any destination.
    """
  )

  @Parameter(
    title: "Silence threshold (seconds)",
    default: 2.0,
    inclusiveRange: (0.0, 10.0)
  )
  var silenceThreshold: Double

  @Parameter(title: "Show UI", default: true)
  var showUI: Bool

  @Parameter(title: "Prompt", default: nil)
  var prompt: String?

  /// iOS 26: `openAppWhenRun` is deprecated; foreground escalation is expressed via
  /// `supportedModes` + `continueInForeground(_:)`. Decided in spike S2.
  static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

  @MainActor
  func perform() async throws -> some IntentResult & ReturnsValue<String> {
    let environment = AppEnvironment.shared
    let session = environment.session

    let permission = await environment.permissions.requestMicrophone()
    guard permission == .granted else {
      throw IntentError.permissionDenied
    }

    if showUI, systemContext.currentMode.canContinueInForeground {
      environment.presentRecordingSheet(prompt: prompt)
      try await continueInForeground(
        "Opening Whisper Intent for recording.",
        alwaysConfirm: false
      )
    }

    let config = RecordingConfig(
      silenceThreshold: silenceThreshold,
      maxDuration: RecordingLimits.maxRecordingSeconds,
      prompt: prompt
    )

    do {
      try await session.startRecording(config: config)
    } catch let error as SessionError {
      throw IntentError(error)
    }

    do {
      let transcript = try await session.awaitCompletion()
      await session.reset()
      return .result(value: transcript)
    } catch let error as SessionError {
      await session.reset()
      throw IntentError(error)
    }
  }
}

/// User-facing error surface. Mapped from `SessionError` at the intent boundary
/// so Shortcuts can branch on these cases. See TDD §7.4.
enum IntentError: Error, CustomLocalizedStringResourceConvertible {
  case permissionDenied
  case busy
  case interrupted
  case transcriptionFailed(String)

  init(_ sessionError: SessionError) {
    switch sessionError {
    case .permissionDenied: self = .permissionDenied
    case .busy: self = .busy
    case .interrupted: self = .interrupted
    case .outOfMemory:
      self = .transcriptionFailed("Whisper Intent ran out of memory. Try a shorter recording.")
    case let .transcriptionFailed(detail):
      self = .transcriptionFailed(detail)
    }
  }

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .permissionDenied:
      "Whisper Intent needs microphone access. Enable it in Settings → Whisper Intent."
    case .busy:
      "Whisper Intent is already recording. Wait for the current capture to finish."
    case .interrupted:
      "Recording was interrupted. Try again."
    case let .transcriptionFailed(detail):
      "Transcription failed: \(detail)"
    }
  }
}
