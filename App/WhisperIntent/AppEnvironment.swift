import Foundation
import WhisperIntentCore

/// Process-wide singleton wiring the AppIntent and the UI to the same
/// `TranscriptionSession`. See `docs/TDD.md` §3 and §7.1.
@MainActor
final class AppEnvironment: ObservableObject {
  static let shared = AppEnvironment()

  let session = TranscriptionSession(
    recorder: AudioRecorder(),
    transcriber: WhisperKitTranscriber()
  )

  let permissions = PermissionsService()

  /// Spike S2 harness state — remove (or re-gate) before TestFlight in M6.
  @Published var helloPresentation: DebugHelloPresentation?

  private var helloContinuation: CheckedContinuation<String, Never>?

  func presentHelloSpike(name: String, currentMode: String) async -> String {
    let greeting = "Hello, \(name)!"
    helloPresentation = DebugHelloPresentation(
      name: name,
      greeting: greeting,
      currentMode: currentMode
    )

    return await withCheckedContinuation { continuation in
      helloContinuation = continuation
    }
  }

  func finishHelloSpike() {
    let greeting = helloPresentation?.greeting ?? "Hello!"
    helloPresentation = nil
    helloContinuation?.resume(returning: greeting)
    helloContinuation = nil
  }

  private init() {}
}

struct DebugHelloPresentation: Identifiable {
  let id = UUID()
  let name: String
  let greeting: String
  let currentMode: String
}
