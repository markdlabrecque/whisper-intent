import Foundation
import WhisperIntentCore

/// Process-wide singleton wiring the AppIntent and the UI to the same
/// `TranscriptionSession`. See `docs/TDD.md` §3 and §7.1.
@MainActor
final class AppEnvironment {
  static let shared = AppEnvironment()

  let session = TranscriptionSession()

  // Future: presenter for routing the foreground recording sheet when the AppIntent
  // escalates with showUI = true. Implementation deferred to M5.

  private init() {}
}
