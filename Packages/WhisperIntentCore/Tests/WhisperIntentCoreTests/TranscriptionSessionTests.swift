import Testing
@testable import WhisperIntentCore

@Suite("TranscriptionSession state machine")
struct TranscriptionSessionTests {
  // MARK: - Initial state + idle invariants

  @Test("initial state is idle")
  func initialStateIsIdle() async {
    let session = makeSession()
    let state = await session.state
    #expect(state == .idle)
  }

  @Test("awaitCompletion on idle session throws .busy")
  func awaitCompletionOnIdle() async {
    let session = makeSession()
    do {
      _ = try await session.awaitCompletion()
      Issue.record("expected throw")
    } catch let error as SessionError {
      #expect(error == .busy)
    } catch {
      Issue.record("wrong error type: \(error)")
    }
  }

  // MARK: - Happy path

  @Test("startRecording transitions idle → recording")
  func startTransitionsToRecording() async throws {
    let session = makeSession()
    try await session.startRecording(config: defaultConfig())
    let state = await session.state
    if case .recording = state {
      // ok
    } else {
      Issue.record("expected .recording, got \(state)")
    }
  }

  @Test("full happy path: idle → recording → processing → completed")
  func happyPath() async throws {
    let recorder = MockRecorder()
    await recorder.setStop(.succeed(audio: [0.1, 0.2, 0.3]))
    let transcriber = MockTranscriber()
    await transcriber.setBehavior(.succeed(
      progressEvents: [.phase(.encoding), .phase(.decoding), .finishing],
      transcript: "hello world"
    ))
    let session = TranscriptionSession(recorder: recorder, transcriber: transcriber)

    try await session.startRecording(config: defaultConfig())
    await session.stopRecording()

    let transcript = try await session.awaitCompletion()
    #expect(transcript == "hello world")

    let final = await session.state
    if case let .completed(value) = final {
      #expect(value == "hello world")
    } else {
      Issue.record("expected .completed, got \(final)")
    }
  }

  // MARK: - Busy lock

  @Test("startRecording while recording throws .busy and does not change state")
  func busyLockWhileRecording() async throws {
    let session = makeSession()
    try await session.startRecording(config: defaultConfig())

    do {
      try await session.startRecording(config: defaultConfig())
      Issue.record("expected throw")
    } catch let error as SessionError {
      #expect(error == .busy)
    } catch {
      Issue.record("wrong error type: \(error)")
    }

    let state = await session.state
    if case .recording = state {
      // still recording — correct
    } else {
      Issue.record("expected .recording, got \(state)")
    }
  }

  // MARK: - Failure paths

  @Test("recorder start failure produces .failed and rethrows")
  func recorderStartFailure() async {
    let recorder = MockRecorder()
    await recorder.setStart(.fail(.permissionDenied))
    let session = TranscriptionSession(recorder: recorder, transcriber: MockTranscriber())

    do {
      try await session.startRecording(config: defaultConfig())
      Issue.record("expected throw")
    } catch let error as SessionError {
      #expect(error == .permissionDenied)
    } catch {
      Issue.record("wrong error type: \(error)")
    }

    let state = await session.state
    if case .failed(.permissionDenied) = state {
      // ok
    } else {
      Issue.record("expected .failed(.permissionDenied), got \(state)")
    }
  }

  @Test("transcriber failure produces .failed and propagates to awaiter")
  func transcriberFailure() async throws {
    let recorder = MockRecorder()
    await recorder.setStop(.succeed(audio: [0.1]))
    let transcriber = MockTranscriber()
    await transcriber.setBehavior(.fail(.transcriptionFailed(underlying: "boom")))
    let session = TranscriptionSession(recorder: recorder, transcriber: transcriber)

    try await session.startRecording(config: defaultConfig())
    await session.stopRecording()

    do {
      _ = try await session.awaitCompletion()
      Issue.record("expected throw")
    } catch let error as SessionError {
      #expect(error == .transcriptionFailed(underlying: "boom"))
    } catch {
      Issue.record("wrong error type: \(error)")
    }
  }

  // MARK: - Cancellation

  @Test("cancel while recording produces .failed(.interrupted)")
  func cancelWhileRecording() async throws {
    let session = makeSession()
    try await session.startRecording(config: defaultConfig())
    await session.cancel()

    let state = await session.state
    if case .failed(.interrupted) = state {
      // ok
    } else {
      Issue.record("expected .failed(.interrupted), got \(state)")
    }
  }

  @Test("cancel on idle session is a no-op")
  func cancelIdle() async {
    let session = makeSession()
    await session.cancel()
    let state = await session.state
    #expect(state == .idle)
  }

  // MARK: - State stream

  @Test("stateStream yields current state on subscription")
  func streamYieldsCurrentState() async {
    let session = makeSession()
    let stream = await session.stateStream
    var iterator = stream.makeAsyncIterator()
    let first = await iterator.next()
    #expect(first == .idle)
  }

  @Test("stateStream yields transitions to multiple subscribers")
  func streamMulticasts() async throws {
    let session = makeSession()
    let stream1 = await session.stateStream
    let stream2 = await session.stateStream

    async let collect1: [TranscriptionSession.State] = collectStates(stream1, count: 2)
    async let collect2: [TranscriptionSession.State] = collectStates(stream2, count: 2)

    // Give both subscribers a chance to register.
    try await Task.sleep(nanoseconds: 10_000_000)
    try await session.startRecording(config: defaultConfig())

    let s1 = await collect1
    let s2 = await collect2

    #expect(s1.count == 2)
    #expect(s2.count == 2)
    #expect(s1.first == .idle)
    #expect(s2.first == .idle)
    if case .recording = s1.last {} else {
      Issue.record("s1 last not .recording: \(String(describing: s1.last))")
    }
    if case .recording = s2.last {} else {
      Issue.record("s2 last not .recording: \(String(describing: s2.last))")
    }
  }

  // MARK: - Reset

  @Test("reset() returns terminal state to idle")
  func resetClearsTerminal() async throws {
    let recorder = MockRecorder()
    await recorder.setStop(.succeed(audio: []))
    let transcriber = MockTranscriber()
    await transcriber.setBehavior(.succeed(progressEvents: [], transcript: "x"))
    let session = TranscriptionSession(recorder: recorder, transcriber: transcriber)

    try await session.startRecording(config: defaultConfig())
    await session.stopRecording()
    _ = try await session.awaitCompletion()

    await session.reset()
    let state = await session.state
    #expect(state == .idle)
  }

  @Test("reset() is a no-op outside terminal states")
  func resetNoOpOnRecording() async throws {
    let session = makeSession()
    try await session.startRecording(config: defaultConfig())
    await session.reset()
    let state = await session.state
    if case .recording = state {
      // unchanged
    } else {
      Issue.record("reset should have been a no-op; got \(state)")
    }
  }
}

// MARK: - Helpers

private func makeSession() -> TranscriptionSession {
  TranscriptionSession(recorder: MockRecorder(), transcriber: MockTranscriber())
}

private func defaultConfig() -> RecordingConfig {
  RecordingConfig(silenceThreshold: 0, maxDuration: 60)
}

private func collectStates(
  _ stream: AsyncStream<TranscriptionSession.State>,
  count: Int
) async -> [TranscriptionSession.State] {
  var collected: [TranscriptionSession.State] = []
  for await state in stream {
    collected.append(state)
    if collected.count >= count { break }
  }
  return collected
}
