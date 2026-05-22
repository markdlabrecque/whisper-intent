import Foundation

/// Single source of truth for whether a recording or transcription is currently active,
/// and what its state is. Both the AppIntent UI and the app's root view bind to this actor.
///
/// See `docs/TDD.md` §3 for the full design.
public actor TranscriptionSession {
  public enum State: Sendable, Equatable {
    case idle
    case recording(startedAt: Date, level: Float)
    case processing(progress: TranscriptionProgress)
    case completed(transcript: String)
    case failed(error: SessionError)
  }

  public init() {}

  // MARK: - Public surface (bodies deferred to M3)

  public private(set) var state: State = .idle

  public var stateStream: AsyncStream<State> {
    fatalError("Unimplemented (M3). See docs/TDD.md §3.")
  }

  public func startRecording(config _: RecordingConfig) async throws {
    fatalError("Unimplemented (M3). See docs/TDD.md §3.")
  }

  public func stopRecording() async {
    fatalError("Unimplemented (M3). See docs/TDD.md §3.")
  }

  public func cancel() async {
    fatalError("Unimplemented (M3). See docs/TDD.md §3.")
  }

  public func awaitCompletion() async throws -> String {
    fatalError("Unimplemented (M3). See docs/TDD.md §3.")
  }
}
