import SwiftUI

/// Minimal foreground surface for Spike S2. The AppIntent waits until the user
/// taps OK, then returns the greeting to Shortcuts.
struct DebugHelloView: View {
  let presentation: DebugHelloPresentation
  let onFinish: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      Text(presentation.greeting)
        .font(.title)
        .fontWeight(.semibold)

      VStack(spacing: 8) {
        Text("Foreground continuation is active.")
          .font(.body)
        Text(presentation.currentMode)
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
      }
      .multilineTextAlignment(.center)

      Button("OK", action: onFinish)
        .buttonStyle(.borderedProminent)
    }
    .padding(28)
  }
}

#Preview {
  DebugHelloView(
    presentation: DebugHelloPresentation(
      name: "Preview",
      greeting: "Hello, Preview!",
      currentMode: "foreground"
    ),
    onFinish: {}
  )
}
