import Foundation

/// Failure modes for `TranscriptionSession`. Mapped to `IntentError` at the AppIntent
/// boundary so the calling Shortcut can branch on them. See `docs/TDD.md` §3 and §7.4.
public enum SessionError: Error, Sendable, Equatable {
  case permissionDenied
  case busy
  case interrupted
  case outOfMemory
  case transcriptionFailed(underlying: String)
}
