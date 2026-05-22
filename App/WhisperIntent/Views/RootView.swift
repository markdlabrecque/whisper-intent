import SwiftUI
import WhisperIntentCore

/// Re-entry surface (PRD §5.8). Shows the same in-flight recording/processing UI as
/// the AppIntent's recording sheet if a session is active; otherwise the landing
/// screen with onboarding link or settings. Implementation deferred to M5.
struct RootView: View {
  var body: some View {
    Text("Whisper Intent")
      .font(.title)
      .padding()
  }
}

#Preview {
  RootView()
}
