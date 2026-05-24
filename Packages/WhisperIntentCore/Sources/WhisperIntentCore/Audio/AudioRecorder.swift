import Foundation

/// Production `AudioRecording` over `AVAudioEngine`. Conforms to the protocol so
/// `AppEnvironment` can wire a session today; the real engine + tap implementation
/// lands in a follow-on M3 commit. See `docs/TDD.md` §5.1.
public final class AudioRecorder: AudioRecording {
  public init() {}

  public func start(
    maxDuration _: TimeInterval,
    buffers _: @Sendable @escaping ([Float]) -> Void,
    level _: @Sendable @escaping (Float) -> Void
  ) async throws {
    throw SessionError.transcriptionFailed(
      underlying: "AudioRecorder.start unimplemented — pending follow-on M3 commit."
    )
  }

  public func stop() async throws -> [Float] {
    throw SessionError.transcriptionFailed(
      underlying: "AudioRecorder.stop unimplemented — pending follow-on M3 commit."
    )
  }

  public func cancel() async {
    // No-op until the real engine lands.
  }
}
