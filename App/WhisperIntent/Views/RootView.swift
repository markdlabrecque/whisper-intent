import SwiftUI
import WhisperIntentCore

/// Re-entry surface (PRD §5.8). Shows the same in-flight recording/processing UI as
/// the AppIntent's recording sheet if a session is active; otherwise the landing
/// screen with onboarding link or settings. Implementation deferred to M5.
struct RootView: View {
  #if DEBUG
    @State private var showSpikes = false
  #endif

  var body: some View {
    VStack(spacing: 24) {
      Text("Whisper Intent")
        .font(.title)
      Text("Production UI lands in M5.")
        .font(.footnote)
        .foregroundStyle(.secondary)

      #if DEBUG
        Button("Open spike harness") { showSpikes = true }
          .buttonStyle(.borderedProminent)
      #endif
    }
    .padding()
    #if DEBUG
      .sheet(isPresented: $showSpikes) {
        DebugSpikesView()
      }
    #endif
  }
}

#Preview {
  RootView()
}
