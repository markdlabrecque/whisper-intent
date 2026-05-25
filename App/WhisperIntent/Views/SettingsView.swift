import SwiftUI

/// In-app settings (PRD §5.9, TDD §8.3). Intentionally sparse: per-invocation
/// configuration lives on the AppIntent parameters; this screen exists only for
/// defaults, attribution, and an entry point to re-run onboarding.
struct SettingsView: View {
  @SilenceThresholdSetting private var silenceThreshold
  @Environment(\.dismiss) private var dismiss
  @State private var showOnboarding = false

  private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
  private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

  var body: some View {
    Form {
      defaultsSection
      examplesSection
      aboutSection
    }
    .navigationTitle("Settings")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Done") { dismiss() }
      }
    }
    .sheet(isPresented: $showOnboarding) {
      OnboardingView { showOnboarding = false }
    }
  }

  private var defaultsSection: some View {
    Section {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Silence threshold")
          Spacer()
          Text(String(format: "%.1fs", silenceThreshold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        Slider(value: $silenceThreshold, in: 0.5 ... 10.0, step: 0.5)
      }
    } header: {
      Text("Defaults")
    } footer: {
      Text(
        """
        Suggested silence threshold when a Shortcut doesn't set its own value. \
        Each Shortcut step can still override this.
        """
      )
    }
  }

  private var examplesSection: some View {
    Section {
      example(
        title: "New Reminder",
        steps: ["Transcribe Speech", "Add New Reminder → use transcribed text"]
      )
      example(
        title: "Quick Note",
        steps: ["Transcribe Speech (Show UI off)", "Append to Note"]
      )
      example(
        title: "Send to webhook",
        steps: ["Transcribe Speech", "Get Contents of URL → POST transcript"]
      )
    } header: {
      Text("Example Shortcut patterns")
    } footer: {
      Text("Whisper Intent doesn't ship these — they're patterns you build in the Shortcuts app.")
    }
  }

  private func example(title: String, steps: [String]) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title).font(.subheadline.weight(.semibold))
      ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
        Text("\(index + 1). \(step)")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
  }

  private var aboutSection: some View {
    Section {
      LabeledContent("Version", value: "\(appVersion) (\(buildNumber))")

      Link(destination: URL(string: "https://github.com/argmaxinc/WhisperKit")!) {
        LabeledContent("Speech engine", value: "WhisperKit")
      }

      Button("Show onboarding again") { showOnboarding = true }
    } header: {
      Text("About")
    } footer: {
      Text(
        """
        Audio and transcripts stay on your iPhone. Whisper Intent doesn't \
        store transcripts and doesn't collect analytics.
        """
      )
    }
  }
}

#Preview {
  NavigationStack { SettingsView() }
}
