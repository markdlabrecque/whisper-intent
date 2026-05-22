import Testing
@testable import WhisperIntentCore

/// Placeholder. Real state-machine tests land in M3.
/// See `docs/TDD.md` §11.
@Suite("TranscriptionSession")
struct TranscriptionSessionTests {
  @Test("initial state is idle")
  func initialStateIsIdle() async {
    let session = TranscriptionSession()
    let state = await session.state
    #expect(state == .idle)
  }
}
