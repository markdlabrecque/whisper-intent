import AVFoundation
import Foundation

#if os(iOS)

  /// Production `AudioRecording` over `AVAudioEngine`. Captures the input device at
  /// its natural format, converts each buffer to 16 kHz mono Float32 via
  /// `AVAudioConverter`, accumulates the full recording in RAM, and reports
  /// per-buffer level + a self-stop signal for max-duration / interruption.
  ///
  /// See `docs/TDD.md` §5.1.
  public final class AudioRecorder: AudioRecording, @unchecked Sendable {
    // MARK: - Concurrency

    /// Serializes all mutable state. The AVAudioEngine tap callback runs on a
    /// real-time thread; it dispatches into this queue and never touches state
    /// directly.
    private let queue = DispatchQueue(label: "com.marklabrecque.whisperintent.audio-recorder")

    // MARK: - State (queue-confined)

    private var engine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?
    private var accumulator: [Float] = []

    private var buffersHandler: (@Sendable ([Float]) -> Void)?
    private var levelHandler: (@Sendable (Float) -> Void)?
    private var stoppedHandler: (@Sendable (AudioRecorderStopReason) -> Void)?

    private var maxDurationTask: Task<Void, Never>?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?

    /// Set to `.normal` or `.failure(error)` once capture has ended for any reason.
    /// `stop()` consumes this and either returns the buffer or throws.
    private var stopReason: AudioRecorderStopReason?

    /// True between `start()` returning and the first end-of-capture event. Used to
    /// guard against double-stop and to suppress level/buffer callbacks after stop.
    private var isCapturing: Bool = false

    public init() {}

    // MARK: - AudioRecording

    public func start(
      maxDuration: TimeInterval,
      buffers: @Sendable @escaping ([Float]) -> Void,
      level: @Sendable @escaping (Float) -> Void,
      stopped: @Sendable @escaping (AudioRecorderStopReason) -> Void
    ) async throws {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        queue.async { [weak self] in
          guard let self else {
            continuation.resume(throwing: SessionError.transcriptionFailed(underlying: "recorder deallocated"))
            return
          }
          do {
            try startLocked(
              maxDuration: maxDuration,
              buffers: buffers,
              level: level,
              stopped: stopped
            )
            continuation.resume()
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
    }

    public func stop() async throws -> [Float] {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Float], Error>) in
        queue.async { [weak self] in
          guard let self else {
            continuation.resume(throwing: SessionError.transcriptionFailed(underlying: "recorder deallocated"))
            return
          }
          do {
            let audio = try stopLocked()
            continuation.resume(returning: audio)
          } catch {
            continuation.resume(throwing: error)
          }
        }
      }
    }

    public func cancel() async {
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        queue.async { [weak self] in
          self?.tearDown(reason: nil, deliverStoppedCallback: false)
          continuation.resume()
        }
      }
    }

    // MARK: - Queue-confined helpers

    private func startLocked(
      maxDuration: TimeInterval,
      buffers: @Sendable @escaping ([Float]) -> Void,
      level: @Sendable @escaping (Float) -> Void,
      stopped: @Sendable @escaping (AudioRecorderStopReason) -> Void
    ) throws {
      guard !isCapturing else { throw SessionError.busy }

      buffersHandler = buffers
      levelHandler = level
      stoppedHandler = stopped
      accumulator = []
      stopReason = nil

      try configureAudioSession()
      try buildEngine()
      try startEngine()

      subscribeToAudioSessionEvents()
      isCapturing = true

      if maxDuration > 0 {
        scheduleMaxDuration(seconds: maxDuration)
      }
    }

    private func configureAudioSession() throws {
      let session = AVAudioSession.sharedInstance()
      do {
        try session.setCategory(
          .playAndRecord,
          mode: .measurement,
          options: [.allowBluetoothHFP, .defaultToSpeaker]
        )
        try session.setActive(true, options: [])
      } catch {
        cleanupResources()
        throw SessionError.transcriptionFailed(underlying: "AVAudioSession setup failed: \(error)")
      }
    }

    private func buildEngine() throws {
      let engine = AVAudioEngine()
      let input = engine.inputNode
      let inputFormat = input.outputFormat(forBus: 0)

      guard
        let target = AVAudioFormat(
          commonFormat: .pcmFormatFloat32,
          sampleRate: 16000,
          channels: 1,
          interleaved: false
        ),
        let converter = AVAudioConverter(from: inputFormat, to: target)
      else {
        cleanupResources()
        throw SessionError.transcriptionFailed(underlying: "AVAudioConverter init failed")
      }

      self.engine = engine
      self.converter = converter
      outputFormat = target

      input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
        guard let self else { return }
        queue.async { [weak self] in
          self?.processInputBuffer(buffer)
        }
      }
    }

    private func startEngine() throws {
      guard let engine else { return }
      do {
        engine.prepare()
        try engine.start()
      } catch {
        cleanupResources()
        throw SessionError.transcriptionFailed(underlying: "AVAudioEngine.start failed: \(error)")
      }
    }

    private func stopLocked() throws -> [Float] {
      if let reason = stopReason {
        // Recorder self-stopped earlier; consume the recorded reason.
        stopReason = nil
        switch reason {
        case .normal:
          let audio = accumulator
          accumulator = []
          return audio
        case let .failure(error):
          accumulator = []
          throw error
        }
      }

      // Caller-initiated stop while still capturing.
      let audio = accumulator
      accumulator = []
      tearDown(reason: nil, deliverStoppedCallback: false)
      return audio
    }

    // MARK: - Tap processing

    private func processInputBuffer(_ inputBuffer: AVAudioPCMBuffer) {
      guard isCapturing, let converter, let outputFormat else { return }

      // Allocate an output buffer sized for the worst-case conversion ratio.
      let ratio = outputFormat.sampleRate / inputBuffer.format.sampleRate
      let outputCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio + 16)

      guard let outputBuffer = AVAudioPCMBuffer(
        pcmFormat: outputFormat,
        frameCapacity: outputCapacity
      ) else { return }

      var providedBuffer = false
      var conversionError: NSError?
      let status = converter.convert(to: outputBuffer, error: &conversionError) { _, inputStatus in
        // The converter calls this repeatedly until it has enough input. We have
        // exactly one buffer per tap callback, so we hand it over once and then
        // signal end-of-stream on subsequent calls.
        if providedBuffer {
          inputStatus.pointee = .noDataNow
          return nil
        }
        providedBuffer = true
        inputStatus.pointee = .haveData
        return inputBuffer
      }

      guard status != .error else {
        let message = conversionError?.localizedDescription ?? "AVAudioConverter conversion failed"
        finishCapture(reason: .failure(.transcriptionFailed(underlying: message)))
        return
      }

      let frameCount = Int(outputBuffer.frameLength)
      guard frameCount > 0, let channelData = outputBuffer.floatChannelData?[0] else { return }

      var frames = [Float](repeating: 0, count: frameCount)
      frames.withUnsafeMutableBufferPointer { dest in
        dest.baseAddress!.update(from: channelData, count: frameCount)
      }

      accumulator.append(contentsOf: frames)
      buffersHandler?(frames)

      // Level meter: RMS of this buffer, clamped to [0, 1].
      let level = rms(frames)
      levelHandler?(level)
    }

    private func rms(_ frames: [Float]) -> Float {
      guard !frames.isEmpty else { return 0 }
      var sumSquares: Float = 0
      for sample in frames {
        sumSquares += sample * sample
      }
      let mean = sumSquares / Float(frames.count)
      return min(1, mean.squareRoot())
    }

    // MARK: - Max-duration

    private func scheduleMaxDuration(seconds: TimeInterval) {
      maxDurationTask = Task { [weak self] in
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        guard !Task.isCancelled else { return }
        self?.queue.async { [weak self] in
          guard let self, isCapturing else { return }
          finishCapture(reason: .normal)
        }
      }
    }
  }

  // MARK: - Audio-session events + teardown (in an extension to keep the type

  // body within SwiftLint's length limit and to group lifecycle concerns).

  fileprivate extension AudioRecorder {
    func subscribeToAudioSessionEvents() {
      let center = NotificationCenter.default
      interruptionObserver = center.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: nil,
        queue: nil
      ) { [weak self] notification in
        guard let typeRaw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw),
              type == .began
        else { return }
        self?.queue.async {
          self?.finishCapture(reason: .failure(.interrupted))
        }
      }

      routeChangeObserver = center.addObserver(
        forName: AVAudioSession.routeChangeNotification,
        object: nil,
        queue: nil
      ) { [weak self] notification in
        guard let reasonRaw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw),
              reason == .oldDeviceUnavailable
        else { return }
        // Route loss mid-recording (e.g., AirPods disconnected). Surface as
        // interruption so the session ends cleanly rather than capturing silence.
        self?.queue.async {
          self?.finishCapture(reason: .failure(.interrupted))
        }
      }
    }

    func finishCapture(reason: AudioRecorderStopReason) {
      guard isCapturing, stopReason == nil else { return }
      stopReason = reason
      tearDown(reason: reason, deliverStoppedCallback: true)
    }

    func tearDown(
      reason: AudioRecorderStopReason?,
      deliverStoppedCallback: Bool
    ) {
      isCapturing = false
      maxDurationTask?.cancel()
      maxDurationTask = nil

      if let engine {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
      }

      let session = AVAudioSession.sharedInstance()
      try? session.setActive(false, options: [.notifyOthersOnDeactivation])

      let center = NotificationCenter.default
      if let observer = interruptionObserver {
        center.removeObserver(observer)
        interruptionObserver = nil
      }
      if let observer = routeChangeObserver {
        center.removeObserver(observer)
        routeChangeObserver = nil
      }

      if deliverStoppedCallback, let reason {
        stoppedHandler?(reason)
      }

      cleanupResources()
    }

    func cleanupResources() {
      engine = nil
      converter = nil
      outputFormat = nil
      buffersHandler = nil
      levelHandler = nil
      // stoppedHandler released last so tearDown's callback can still fire above.
      stoppedHandler = nil
    }
  }

#else

  /// macOS placeholder so the package compiles on developer machines for
  /// `swift build` / `swift test`. The real implementation is iOS-only.
  public final class AudioRecorder: AudioRecording, @unchecked Sendable {
    public init() {}

    public func start(
      maxDuration _: TimeInterval,
      buffers _: @Sendable @escaping ([Float]) -> Void,
      level _: @Sendable @escaping (Float) -> Void,
      stopped _: @Sendable @escaping (AudioRecorderStopReason) -> Void
    ) async throws {
      throw SessionError.transcriptionFailed(underlying: "AudioRecorder is iOS-only.")
    }

    public func stop() async throws -> [Float] {
      throw SessionError.transcriptionFailed(underlying: "AudioRecorder is iOS-only.")
    }

    public func cancel() async {}
  }

#endif
