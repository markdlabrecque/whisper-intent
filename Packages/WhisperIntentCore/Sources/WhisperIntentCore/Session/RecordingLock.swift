import Foundation

/// The single-recording invariant from PRD §5.3 is enforced by `TranscriptionSession`'s
/// actor-level serialization plus a `guard case .idle = state` check at the entry of
/// `startRecording`. This file exists as a place to document that decision and to host
/// any helper types if the implementation evolves.
///
/// See `docs/TDD.md` §4.
enum RecordingLock {
  // Intentionally empty. The "lock" is the actor's state machine, not a separate primitive.
}
