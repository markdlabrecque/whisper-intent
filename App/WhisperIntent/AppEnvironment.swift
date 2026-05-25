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

  /// Active recording-sheet presentation, set by the AppIntent when `showUI = true`.
  /// `RootView` observes this and presents `RecordingSheet`. Cleared when the sheet
  /// dismisses (sheet auto-dismisses on `.completed` / `.failed`).
  @Published var recordingPresentation: RecordingPresentation?

  #if DEBUG
    /// Spike S2 harness state — DEBUG builds only. Stripped from release so the
    /// `Debug Hello` intent doesn't appear in the Shortcuts editor for users.
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
  #endif

  func presentRecordingSheet(prompt: String?) {
    recordingPresentation = RecordingPresentation(prompt: prompt)
  }

  func dismissRecordingSheet() {
    recordingPresentation = nil
  }

  private init() {}
}

struct RecordingPresentation: Identifiable {
  let id = UUID()
  let prompt: String?
}

#if DEBUG
  struct DebugHelloPresentation: Identifiable {
    let id = UUID()
    let name: String
    let greeting: String
    let currentMode: String
  }
#endif
