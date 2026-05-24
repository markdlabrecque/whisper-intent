import Foundation

/// Production `Transcribing` over WhisperKit. Conforms to the protocol so
/// `AppEnvironment` can wire a session today; the real model-load + transcribe
/// implementation will be lifted from `SpikeS1Harness` in a follow-on M3 commit.
/// See `docs/TDD.md` §6.
public final class WhisperKitTranscriber: Transcribing {
  public init() {}

  public func transcribe(
    audio _: [Float],
    progress _: @Sendable @escaping (TranscriptionProgress) -> Void
  ) async throws -> String {
    throw SessionError.transcriptionFailed(
      underlying: "WhisperKitTranscriber.transcribe unimplemented — pending follow-on M3 commit."
    )
  }
}
