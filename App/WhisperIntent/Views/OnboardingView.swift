import SwiftUI
import WhisperIntentCore

/// First-run onboarding (PRD §5.8, TDD §9). Copy deck: `docs/onboarding-copy.md`.
///
/// Three screens: (1) building-block expectation, (2) how to use it, (3) mic
/// permission + a real test recording. The third screen drives
/// `TranscriptionSession` directly (rather than self-invoking the AppIntent)
/// so the test path is in-process and matches how the AppIntent will exercise
/// the same code on a real Shortcut invocation.
///
/// The cap sentence from copy-doc Screen 3 is intentionally omitted while S3
/// is shelved (`docs/spikes/S3-background-budget.md`). Re-introduce it pulling
/// from `RecordingLimits.maxRecordingSeconds` once the spike closes with a
/// real number.
@MainActor
struct OnboardingView: View {
  let onComplete: () -> Void

  @State private var step: Step = .intro
  @State private var sessionState: TranscriptionSession.State = .idle
  @State private var permissionError: String?

  private enum Step {
    case intro
    case usage
    case test
    case confirmation
  }

  private var session: TranscriptionSession {
    AppEnvironment.shared.session
  }

  private var permissions: PermissionsService {
    AppEnvironment.shared.permissions
  }

  var body: some View {
    NavigationStack {
      VStack {
        screenContent
        Spacer()
        controls
      }
      .padding(24)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          if step != .confirmation {
            Button("Skip") { complete() }
          }
        }
      }
    }
    .task(id: ObjectIdentifier(session)) {
      for await next in await session.stateStream {
        sessionState = next
        if case .completed = next, step == .test {
          step = .confirmation
        }
      }
    }
    .interactiveDismissDisabled()
  }

  // MARK: - Screens

  @ViewBuilder
  private var screenContent: some View {
    switch step {
    case .intro: introScreen
    case .usage: usageScreen
    case .test: testScreen
    case .confirmation: confirmationScreen
    }
  }

  private var introScreen: some View {
    OnboardingScreen(
      headline: "Whisper Intent is a building block.",
      body: """
      On its own, this app doesn't do much. It gives Apple Shortcuts a new \
      step — Transcribe Speech — that records audio and returns the text. You \
      wire it into whatever Shortcut you want: a reminder, a note, a message, \
      a webhook, anything.

      If you're not already an Apple Shortcuts user, this app probably isn't \
      for you.
      """
    )
  }

  private var usageScreen: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Build the Shortcut you want.")
        .font(.title.weight(.semibold))
        .accessibilityAddTraits(.isHeader)
      Text(
        """
        Open the Shortcuts app. Add Transcribe Speech as a step in any \
        Shortcut you're building. The transcript becomes the input to whatever \
        comes next.
        """
      )
      .font(.body)
      VStack(alignment: .leading, spacing: 6) {
        Text("Example").font(.footnote).foregroundStyle(.secondary)
        Text("1. Transcribe Speech")
        Text("2. Add New Reminder → use the transcribed text")
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Example: step 1, Transcribe Speech. Step 2, Add New Reminder using the transcribed text.")
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.thinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 12))

      Text(
        """
        Trigger your Shortcut from Siri, the Action Button, a lock-screen \
        widget, or anywhere else Shortcuts can run. Whisper Intent doesn't \
        need to be open.
        """
      )
      .font(.body)
      .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var testScreen: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("One quick test.")
        .font(.title.weight(.semibold))
        .accessibilityAddTraits(.isHeader)
      Text(
        """
        Tap below and say a few words. This grants Whisper Intent permission \
        to use the microphone, which is needed before any Shortcut can call it.
        """
      )
      .font(.body)
      Text(
        """
        Recordings stay on your device. Audio never leaves the iPhone, and \
        Whisper Intent doesn't store transcripts.
        """
      )
      .font(.body)
      .foregroundStyle(.secondary)

      if let permissionError {
        Text(permissionError)
          .font(.footnote)
          .foregroundStyle(.red)
      }

      stateBadge
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var confirmationScreen: some View {
    OnboardingScreen(
      headline: "You're set.",
      body: """
      Whisper Intent will run when your Shortcuts call it.

      For ideas, see the examples in Settings.
      """
    )
  }

  @ViewBuilder
  private var stateBadge: some View {
    switch sessionState {
    case .recording:
      Label("Listening…", systemImage: "waveform")
        .foregroundStyle(.red)
    case .processing:
      Label("Transcribing…", systemImage: "ellipsis")
        .foregroundStyle(.secondary)
    default:
      EmptyView()
    }
  }

  // MARK: - Controls

  @ViewBuilder
  private var controls: some View {
    switch step {
    case .intro:
      primaryButton("Continue") { step = .usage }
    case .usage:
      primaryButton("Continue") { step = .test }
    case .test:
      testControls
    case .confirmation:
      primaryButton("Done") { complete() }
    }
  }

  @ViewBuilder
  private var testControls: some View {
    switch sessionState {
    case .idle, .completed, .failed:
      primaryButton("Record a test") { startTest() }
        .accessibilityLabel("Record a test, grants microphone permission")
    case .recording:
      primaryButton("Stop", tint: .red) { Task { await session.stopRecording() } }
    case .processing:
      ProgressView().controlSize(.large)
    }
  }

  private func primaryButton(_ label: String, tint: Color = .accentColor, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(.headline)
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .tint(tint)
  }

  // MARK: - Actions

  private func startTest() {
    permissionError = nil
    Task {
      let status = await permissions.requestMicrophone()
      guard status == .granted else {
        permissionError = """
        Microphone permission was not granted. Enable it in \
        Settings → Whisper Intent to use Shortcuts.
        """
        return
      }
      let config = RecordingConfig(
        silenceThreshold: UserSettings.silenceThreshold,
        maxDuration: RecordingLimits.maxRecordingSeconds
      )
      do {
        try await session.startRecording(config: config)
      } catch {
        permissionError = "Couldn't start recording: \(error)"
      }
    }
  }

  private func complete() {
    UserSettings.onboardingCompleted = true
    Task { await session.reset() }
    onComplete()
  }
}

private struct OnboardingScreen: View {
  let headline: String
  let bodyText: String

  init(headline: String, body: String) {
    self.headline = headline
    bodyText = body
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(headline)
        .font(.title.weight(.semibold))
        .accessibilityAddTraits(.isHeader)
      Text(bodyText)
        .font(.body)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

#Preview {
  OnboardingView(onComplete: {})
}
