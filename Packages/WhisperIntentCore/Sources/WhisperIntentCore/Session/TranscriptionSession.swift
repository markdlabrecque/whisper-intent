import Foundation

/// Single source of truth for whether a recording or transcription is currently
/// active, and what its state is. The AppIntent and the app UI both bind to this
/// actor — no other code owns recording or transcription state. See `docs/TDD.md` §3.
public actor TranscriptionSession {
  public enum State: Sendable, Equatable {
    case idle
    case recording(startedAt: Date, level: Float)
    case processing(progress: TranscriptionProgress)
    case completed(transcript: String)
    case failed(error: SessionError)
  }

  // MARK: - Dependencies

  private let recorder: any AudioRecording
  private let transcriber: any Transcribing
  private let voiceDetector: VoiceActivityDetector
  private let clock: @Sendable () -> Date

  // MARK: - State

  public private(set) var state: State = .idle

  /// Subscribers added by `stateStream`. Yielded to whenever `state` changes.
  private var continuations: [UUID: AsyncStream<State>.Continuation] = [:]

  /// Task running the active recording's pipeline. Held so `cancel()` can stop it.
  private var pipeline: Task<Void, Never>?

  /// Continuation suspending the caller of `awaitCompletion()` until terminal state.
  private var awaiter: CheckedContinuation<String, Error>?

  // MARK: - Init

  public init(
    recorder: any AudioRecording,
    transcriber: any Transcribing,
    voiceDetector: VoiceActivityDetector = VoiceActivityDetector(),
    clock: @Sendable @escaping () -> Date = Date.init
  ) {
    self.recorder = recorder
    self.transcriber = transcriber
    self.voiceDetector = voiceDetector
    self.clock = clock
  }

  // MARK: - State stream

  /// Yields every state change to all subscribers. Each call returns a fresh stream;
  /// the actor multicasts to all live subscribers. The current state is delivered
  /// synchronously on subscription so a late subscriber can render immediately.
  public var stateStream: AsyncStream<State> {
    AsyncStream { continuation in
      let id = UUID()
      continuations[id] = continuation
      continuation.yield(state)
      continuation.onTermination = { [weak self] _ in
        Task { [weak self] in await self?.removeContinuation(id) }
      }
    }
  }

  private func removeContinuation(_ id: UUID) {
    continuations[id] = nil
  }

  private func setState(_ next: State) {
    state = next
    for continuation in continuations.values {
      continuation.yield(next)
    }
  }

  // MARK: - Lifecycle

  /// Begins a recording. Throws `SessionError.busy` if a recording is already in
  /// flight. After this returns, the session is in `.recording` and the caller can
  /// either wait on `awaitCompletion()` or observe `stateStream`.
  public func startRecording(config: RecordingConfig) async throws {
    guard case .idle = state else { throw SessionError.busy }

    voiceDetector.reset(silenceThreshold: config.silenceThreshold)
    setState(.recording(startedAt: clock(), level: 0))

    let buffersHandler: @Sendable ([Float]) -> Void = { [weak self] frames in
      Task { [weak self] in await self?.ingest(buffers: frames) }
    }
    let levelHandler: @Sendable (Float) -> Void = { [weak self] level in
      Task { [weak self] in await self?.updateLevel(level) }
    }
    let stoppedHandler: @Sendable (AudioRecorderStopReason) -> Void = { [weak self] reason in
      Task { [weak self] in await self?.handleRecorderSelfStop(reason: reason) }
    }

    do {
      try await recorder.start(
        maxDuration: config.maxDuration,
        buffers: buffersHandler,
        level: levelHandler,
        stopped: stoppedHandler
      )
    } catch let error as SessionError {
      finish(.failure(error))
      throw error
    } catch {
      let mapped = SessionError.transcriptionFailed(underlying: "\(error)")
      finish(.failure(mapped))
      throw mapped
    }
  }

  /// Stops the active recording and begins transcription. Safe to call from VAD,
  /// the max-duration timer, or the user-tap path; the first call wins, subsequent
  /// calls are no-ops while processing.
  public func stopRecording() async {
    guard case .recording = state else { return }

    let audio: [Float]
    do {
      audio = try await recorder.stop()
    } catch let error as SessionError {
      finish(.failure(error))
      return
    } catch {
      finish(.failure(.transcriptionFailed(underlying: "\(error)")))
      return
    }

    setState(.processing(progress: .starting))

    pipeline = Task { [weak self] in
      await self?.runTranscription(audio: audio)
    }
  }

  /// Aborts an in-flight recording or transcription. Resolves any waiter with
  /// `SessionError.interrupted`. Idempotent.
  public func cancel() async {
    switch state {
    case .idle, .completed, .failed:
      return
    case .recording, .processing:
      await recorder.cancel()
      pipeline?.cancel()
      pipeline = nil
      finish(.failure(.interrupted))
    }
  }

  /// Suspends until the active recording completes (returning the transcript) or
  /// fails (throwing). If called while the session is already terminal, returns or
  /// throws immediately based on that state.
  public func awaitCompletion() async throws -> String {
    switch state {
    case let .completed(transcript):
      return transcript
    case let .failed(error):
      throw error
    case .idle:
      throw SessionError.busy
    case .recording, .processing:
      return try await withCheckedThrowingContinuation { continuation in
        awaiter = continuation
      }
    }
  }

  // MARK: - Internal: recording-time hooks

  private func ingest(buffers frames: [Float]) {
    guard case .recording = state else { return }
    if voiceDetector.observe(frames) {
      Task { await self.stopRecording() }
    }
  }

  private func updateLevel(_ level: Float) {
    guard case let .recording(startedAt, _) = state else { return }
    setState(.recording(startedAt: startedAt, level: level))
  }

  private func handleRecorderSelfStop(reason: AudioRecorderStopReason) async {
    guard case .recording = state else { return }
    switch reason {
    case .normal:
      // Recorder ended capture cleanly (max-duration). Treat as user-initiated stop.
      await stopRecording()
    case let .failure(error):
      // Recorder ended capture because of an error. Tear down without transcribing.
      pipeline?.cancel()
      pipeline = nil
      finish(.failure(error))
    }
  }

  // MARK: - Internal: transcription pipeline

  private func runTranscription(audio: [Float]) async {
    let progressHandler: @Sendable (TranscriptionProgress) -> Void = { [weak self] progress in
      Task { [weak self] in await self?.updateProgress(progress) }
    }

    do {
      let transcript = try await transcriber.transcribe(audio: audio, progress: progressHandler)
      if Task.isCancelled { return }
      finish(.success(transcript))
    } catch let error as SessionError {
      finish(.failure(error))
    } catch {
      finish(.failure(.transcriptionFailed(underlying: "\(error)")))
    }
  }

  private func updateProgress(_ progress: TranscriptionProgress) {
    guard case .processing = state else { return }
    setState(.processing(progress: progress))
  }

  // MARK: - Internal: terminal transitions

  private enum Outcome {
    case success(String)
    case failure(SessionError)
  }

  private func finish(_ outcome: Outcome) {
    pipeline = nil
    switch outcome {
    case let .success(transcript):
      setState(.completed(transcript: transcript))
      awaiter?.resume(returning: transcript)
    case let .failure(error):
      setState(.failed(error: error))
      awaiter?.resume(throwing: error)
    }
    awaiter = nil
  }

  /// Resets to `.idle` after a terminal state. Called by the AppIntent after it
  /// reads `completed.transcript` so the next invocation can start cleanly.
  public func reset() {
    switch state {
    case .completed, .failed:
      setState(.idle)
    case .idle, .recording, .processing:
      return
    }
  }
}
