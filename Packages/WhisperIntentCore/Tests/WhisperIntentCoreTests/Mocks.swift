import Foundation
@testable import WhisperIntentCore

/// Scriptable recorder for unit tests. Records the requested max duration, lets
/// the test drive the buffer/level streams manually, and returns a pre-set audio
/// buffer (or pre-set error) on stop.
actor MockRecorder: AudioRecording {
  enum StartBehavior {
    case succeed
    case fail(SessionError)
  }

  enum StopBehavior {
    case succeed(audio: [Float])
    case fail(SessionError)
  }

  var startBehavior: StartBehavior = .succeed
  var stopBehavior: StopBehavior = .succeed(audio: [])

  private(set) var lastMaxDuration: TimeInterval?
  private(set) var startCount: Int = 0
  private(set) var stopCount: Int = 0
  private(set) var cancelCount: Int = 0

  private var buffersHandler: (@Sendable ([Float]) -> Void)?
  private var levelHandler: (@Sendable (Float) -> Void)?

  func setStart(_ behavior: StartBehavior) {
    startBehavior = behavior
  }

  func setStop(_ behavior: StopBehavior) {
    stopBehavior = behavior
  }

  /// Drives the buffer stream from the test side.
  func emit(buffers frames: [Float]) {
    buffersHandler?(frames)
  }

  /// Drives the level stream from the test side.
  func emit(level: Float) {
    levelHandler?(level)
  }

  // MARK: - AudioRecording

  nonisolated func start(
    maxDuration: TimeInterval,
    buffers: @Sendable @escaping ([Float]) -> Void,
    level: @Sendable @escaping (Float) -> Void
  ) async throws {
    try await applyStart(maxDuration: maxDuration, buffers: buffers, level: level)
  }

  private func applyStart(
    maxDuration: TimeInterval,
    buffers: @Sendable @escaping ([Float]) -> Void,
    level: @Sendable @escaping (Float) -> Void
  ) async throws {
    startCount += 1
    lastMaxDuration = maxDuration
    buffersHandler = buffers
    levelHandler = level
    switch startBehavior {
    case .succeed:
      return
    case let .fail(error):
      throw error
    }
  }

  nonisolated func stop() async throws -> [Float] {
    try await applyStop()
  }

  private func applyStop() async throws -> [Float] {
    stopCount += 1
    switch stopBehavior {
    case let .succeed(audio):
      return audio
    case let .fail(error):
      throw error
    }
  }

  nonisolated func cancel() async {
    await applyCancel()
  }

  private func applyCancel() {
    cancelCount += 1
    buffersHandler = nil
    levelHandler = nil
  }
}

/// Scriptable transcriber for unit tests. Lets the test pre-set progress events
/// to emit and the final transcript or error.
actor MockTranscriber: Transcribing {
  enum Behavior {
    case succeed(progressEvents: [TranscriptionProgress], transcript: String)
    case fail(SessionError)
  }

  var behavior: Behavior = .succeed(progressEvents: [], transcript: "")

  private(set) var callCount: Int = 0

  func setBehavior(_ behavior: Behavior) {
    self.behavior = behavior
  }

  nonisolated func transcribe(
    audio _: [Float],
    progress: @Sendable @escaping (TranscriptionProgress) -> Void
  ) async throws -> String {
    try await applyTranscribe(progress: progress)
  }

  private func applyTranscribe(
    progress: @Sendable @escaping (TranscriptionProgress) -> Void
  ) async throws -> String {
    callCount += 1
    switch behavior {
    case let .succeed(events, transcript):
      for event in events {
        progress(event)
        await Task.yield()
      }
      return transcript
    case let .fail(error):
      throw error
    }
  }
}

/// Polls `body` until it returns true, or fails after `timeout`. Used for tests
/// that depend on the actor having drained an enqueued Task.
func waitUntil(
  timeout: TimeInterval = 1.0,
  _ body: @Sendable () async -> Bool
) async -> Bool {
  let deadline = Date().addingTimeInterval(timeout)
  while Date() < deadline {
    if await body() { return true }
    try? await Task.sleep(nanoseconds: 5_000_000)
  }
  return false
}
