#if DEBUG
  import AppIntents

  /// Spike S2 harness intent. DEBUG-only so the production Shortcuts editor only
  /// shows `Transcribe Speech`. M6 hardening keeps this for in-house spike re-runs.
  struct DebugHelloIntent: AppIntent {
    static let title: LocalizedStringResource = "Debug Hello Foreground Spike"

    static let description = IntentDescription(
      "Spike harness for validating dynamic foreground continuation from an AppIntent."
    )

    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Parameter(title: "Show UI", default: true)
    var showUI: Bool

    @Parameter(title: "Name", default: "Whisper Intent")
    var name: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
      let greeting = "Hello, \(name)!"
      guard showUI else {
        return .result(value: "\(greeting) Returned from \(systemContext.currentMode.debugDescription).")
      }

      guard systemContext.currentMode.canContinueInForeground else {
        throw needsToContinueInForegroundError(
          "Open Whisper Intent to finish the foreground spike.",
          alwaysConfirm: false
        )
      }

      try await continueInForeground(
        "Opening Whisper Intent for the foreground spike.",
        alwaysConfirm: false
      )

      let foregroundGreeting = await AppEnvironment.shared.presentHelloSpike(
        name: name,
        currentMode: systemContext.currentMode.debugDescription
      )
      return .result(value: "\(foregroundGreeting) Returned after foreground UI.")
    }
  }
#endif
