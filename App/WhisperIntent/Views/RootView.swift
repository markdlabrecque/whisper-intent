import SwiftUI
import WhisperIntentCore

/// App-launch surface. Two responsibilities:
///
/// 1. **Re-entry surface (PRD §5.8).** When the user opens the app from
///    springboard while a recording or transcription is in flight, render the
///    same visual treatment as `RecordingSheet` so the experience is continuous.
/// 2. **Landing screen** when idle: brief explainer, settings, debug entry.
///
/// `RecordingSheet` is presented over this view when the AppIntent escalates
/// to foreground with `showUI = true` (see `AppEnvironment.recordingPresentation`).
@MainActor
struct RootView: View {
  @StateObject private var environment = AppEnvironment.shared
  @State private var state: TranscriptionSession.State = .idle
  #if DEBUG
    @State private var showSpikes = false
  #endif
  @State private var showSettings = false
  @State private var showOnboarding = !UserSettings.onboardingCompleted

  private var session: TranscriptionSession {
    environment.session
  }

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("Whisper Intent")
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              showSettings = true
            } label: {
              Image(systemName: "gear")
            }
            .accessibilityLabel("Settings")
          }
        }
    }
    .task {
      for await next in await session.stateStream {
        state = next
      }
    }
    .sheet(item: $environment.recordingPresentation) { presentation in
      RecordingSheet(prompt: presentation.prompt) {
        environment.dismissRecordingSheet()
      }
    }
    .fullScreenCover(isPresented: $showOnboarding) {
      OnboardingView { showOnboarding = false }
    }
    .sheet(isPresented: $showSettings) {
      NavigationStack { SettingsView() }
    }
    #if DEBUG
    .sheet(isPresented: $showSpikes) {
        DebugSpikesView()
      }
      .sheet(item: $environment.helloPresentation) { presentation in
        DebugHelloView(presentation: presentation) {
          environment.finishHelloSpike()
        }
      }
    #endif
  }

  @ViewBuilder
  private var content: some View {
    switch state {
    case .idle, .completed, .failed:
      landing
    case .recording, .processing:
      // Mirror the recording sheet's visuals so a user who opened the app from
      // springboard mid-session sees the same surface (PRD §5.8). The sheet
      // itself, if also presented, will sit on top.
      RecordingSheet(prompt: nil) {}
    }
  }

  private var landing: some View {
    VStack(spacing: 24) {
      Spacer()

      VStack(spacing: 8) {
        Image(systemName: "waveform")
          .font(.system(size: 64))
          .foregroundStyle(.tint)
          .accessibilityHidden(true)
        Text("Voice capture for Shortcuts")
          .font(.title3)
          .multilineTextAlignment(.center)
          .accessibilityAddTraits(.isHeader)
        Text(
          """
          Whisper Intent adds a Transcribe Speech step to Apple Shortcuts. \
          Trigger it from Siri, the Action Button, or any other Shortcut surface.
          """
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
      }

      if case let .completed(transcript) = state {
        completedPreview(transcript: transcript)
      }

      Spacer()

      #if DEBUG
        Button("Spike harness") { showSpikes = true }
          .buttonStyle(.bordered)
      #endif
    }
    .padding()
  }

  private func completedPreview(transcript: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Last transcript")
        .font(.caption)
        .foregroundStyle(.secondary)
      ScrollView {
        Text(transcript.isEmpty ? "(empty transcript)" : transcript)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: 160)
      .padding(12)
      .background(.thinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding(.horizontal)
  }
}

#Preview {
  RootView()
}
