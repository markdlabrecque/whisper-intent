import SwiftUI
import WhisperIntentCore

/// Foreground recording UI presented when the AppIntent runs with showUI = true.
/// Transitions in place from recording → processing without dismissing.
/// Implementation deferred to M5. See PRD §5.5 and TDD §8.1.
struct RecordingSheet: View {
  var body: some View {
    Text("Recording")
  }
}
