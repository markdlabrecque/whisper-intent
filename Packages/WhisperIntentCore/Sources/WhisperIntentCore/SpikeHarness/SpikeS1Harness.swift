import Foundation
@preconcurrency import WhisperKit

/// Spike S1 — measures WhisperKit medium's progress-callback granularity by
/// wiring every available callback (model state, transcription state, per-token
/// progress, segment discovery) and emitting timestamped events.
///
/// The harness is intentionally separate from `WhisperKitTranscriber`. The
/// transcriber's final API was decided by this spike; this harness remains only
/// as reproducible evidence for that decision.
public final class SpikeS1Harness: @unchecked Sendable {
  /// Callback that fires for each observation. Implementations must be
  /// non-blocking — WhisperKit's docs warn that slow callbacks add extra
  /// decoding loops. We hop to a background queue inside before notifying the
  /// observer to be safe.
  public typealias Observer = @Sendable (SpikeLogEvent) -> Void

  private let observer: Observer
  private var startTime: Date = .init()
  private var whisperKit: WhisperKit?

  public init(observer: @escaping Observer) {
    self.observer = observer
  }

  /// Loads the bundled medium model + transcribes the file at `audioURL`.
  /// All callbacks are wired and reported through the observer.
  public func run(audioURL: URL) async {
    startTime = Date()
    let metrics = SpikeS1MetricsRecorder()
    emit(.harnessStart, "audio=\(audioURL.lastPathComponent)")

    do {
      try await loadModelIfNeeded()
      guard let whisperKit else {
        emit(.harnessError, "whisperKit nil after load")
        return
      }

      emit(.transcribeStart, "")
      metrics.markTranscribeStart(elapsed: elapsed)
      wireCallbacks(on: whisperKit, metrics: metrics)

      let results = try await whisperKit.transcribe(
        audioPath: audioURL.path,
        decodeOptions: nil,
        callback: progressCallback(metrics: metrics)
      )

      let text = results.map(\.text).joined(separator: " ")
      let preview = text.prefix(120)
      metrics.markTranscribeEnd(elapsed: elapsed)
      emit(.transcribeEnd, "chars=\(text.count) preview=\"\(preview)…\"")
      for line in metrics.reportLines() {
        emit(.metrics, line)
      }
    } catch {
      emit(.harnessError, "error=\(error)")
    }
  }

  private func wireCallbacks(on whisperKit: WhisperKit, metrics: SpikeS1MetricsRecorder) {
    whisperKit.segmentDiscoveryCallback = { [weak self] segments in
      guard let self else { return }
      metrics.recordSegment(
        elapsed: elapsed,
        segmentCount: segments.count,
        lastEnd: segments.last?.end
      )
      let summary = "segments=\(segments.count) lastEnd=\(segments.last?.end ?? 0)"
      emit(.segmentDiscovered, summary)
    }
    whisperKit.transcriptionStateCallback = { [weak self] state in
      guard let self else { return }
      metrics.recordPayloadShape("transcriptionState: state.description")
      emit(.transcriptionState, "state=\(state.description)")
    }
    whisperKit.modelStateCallback = { [weak self] _, new in
      guard let self else { return }
      metrics.recordPayloadShape("modelState: old,new")
      emit(.modelState, "state=\(new)")
    }
  }

  private func progressCallback(metrics: SpikeS1MetricsRecorder) -> TranscriptionCallback {
    { [weak self] progress in
      guard let self else { return true }
      metrics.recordProgress(
        elapsed: elapsed,
        tokenCount: progress.tokens.count,
        windowId: progress.windowId
      )
      let summary = "tokens=\(progress.tokens.count) windowId=\(progress.windowId)"
      emit(.progress, summary)
      return true
    }
  }

  // MARK: - Model load

  private func loadModelIfNeeded() async throws {
    guard whisperKit == nil else { return }
    emit(.modelLoadStart, "")

    // Bundled at <app>/openai_whisper-medium/ — see project.yml folder-reference
    // resource entry. The model directory itself isn't a .bundle, so
    // `url(forResource:withExtension:)` finds it as a folder.
    guard let modelURL = Bundle.main.url(forResource: "openai_whisper-medium", withExtension: nil) else {
      emit(.harnessError, "model folder not found in bundle")
      throw HarnessError.modelMissing
    }

    let kit = try await WhisperKit(
      modelFolder: modelURL.path,
      verbose: false,
      logLevel: .info,
      prewarm: true,
      load: true,
      download: false
    )
    whisperKit = kit
    emit(.modelLoadEnd, "modelFolder=\(modelURL.lastPathComponent)")
  }

  // MARK: - Emit helper

  private func emit(_ kind: SpikeLogEvent.Kind, _ summary: String) {
    let event = SpikeLogEvent(kind: kind, elapsed: elapsed, summary: summary)
    Task {
      observer(event)
    }
  }

  private var elapsed: TimeInterval {
    Date().timeIntervalSince(startTime)
  }

  public enum HarnessError: Error {
    case modelMissing
  }
}

private final class SpikeS1MetricsRecorder: @unchecked Sendable {
  private struct ProgressObservation {
    let elapsed: TimeInterval
    let tokenCount: Int
    let windowId: Int
  }

  private struct SegmentObservation {
    let elapsed: TimeInterval
    let segmentCount: Int
    let lastEnd: Float?
  }

  private let lock = NSLock()
  private var transcribeStart: TimeInterval?
  private var transcribeEnd: TimeInterval?
  private var progressObservations: [ProgressObservation] = []
  private var segmentObservations: [SegmentObservation] = []
  private var payloadShapes: Set<String> = []

  func markTranscribeStart(elapsed: TimeInterval) {
    lock.withLock {
      transcribeStart = elapsed
    }
  }

  func markTranscribeEnd(elapsed: TimeInterval) {
    lock.withLock {
      transcribeEnd = elapsed
    }
  }

  func recordProgress(elapsed: TimeInterval, tokenCount: Int, windowId: Int) {
    lock.withLock {
      progressObservations.append(ProgressObservation(
        elapsed: elapsed,
        tokenCount: tokenCount,
        windowId: windowId
      ))
      payloadShapes.insert("progress: tokens.count, windowId")
    }
  }

  func recordSegment(elapsed: TimeInterval, segmentCount: Int, lastEnd: Float?) {
    lock.withLock {
      segmentObservations.append(SegmentObservation(
        elapsed: elapsed,
        segmentCount: segmentCount,
        lastEnd: lastEnd
      ))
      payloadShapes.insert("segmentDiscovery: segments.count, segments.last?.end")
    }
  }

  func recordPayloadShape(_ shape: String) {
    lock.withLock {
      _ = payloadShapes.insert(shape)
    }
  }

  func reportLines() -> [String] {
    let snapshot = lock.withLock {
      (
        start: transcribeStart,
        end: transcribeEnd,
        progress: progressObservations,
        segments: segmentObservations,
        shapes: payloadShapes.sorted()
      )
    }

    guard let start = snapshot.start, let end = snapshot.end else {
      return ["summary unavailable: missing transcribe start/end timestamps"]
    }

    let total = end - start
    var lines: [String] = [
      "METRIC totalTranscriptionTime=\(format(total))s",
      metricLine(name: "progressCallbacks", observations: snapshot.progress.map(\.elapsed), total: total),
      metricLine(name: "segmentCallbacks", observations: snapshot.segments.map(\.elapsed), total: total),
      "METRIC payloadShapes=\(snapshot.shapes.joined(separator: " | "))"
    ]

    if let lastProgress = snapshot.progress.last {
      lines.append(
        "METRIC finalProgressPayload=tokens=\(lastProgress.tokenCount) windowId=\(lastProgress.windowId)"
      )
    }

    if let lastSegment = snapshot.segments.last {
      let lastEnd = lastSegment.lastEnd.map { format(TimeInterval($0)) } ?? "nil"
      lines.append(
        "METRIC finalSegmentPayload=segments=\(lastSegment.segmentCount) lastEnd=\(lastEnd)"
      )
    }

    let fractionSamples = snapshot.progress
      .prefix(12)
      .map { format(($0.elapsed - start) / max(total, 0.001)) }
      .joined(separator: ",")
    lines.append("METRIC firstProgressFractions=\(fractionSamples)")

    return lines
  }

  private func metricLine(name: String, observations: [TimeInterval], total: TimeInterval) -> String {
    let intervals = zip(observations.dropFirst(), observations).map(-)
    let mean = intervals.isEmpty ? 0 : intervals.reduce(0, +) / Double(intervals.count)
    let minInterval = intervals.min() ?? 0
    let maxInterval = intervals.max() ?? 0
    let frequency = total > 0 ? Double(observations.count) / total : 0

    return [
      "METRIC \(name)=\(observations.count)",
      "frequencyHz=\(format(frequency))",
      "meanInterval=\(format(mean))s",
      "minInterval=\(format(minInterval))s",
      "maxInterval=\(format(maxInterval))s"
    ].joined(separator: " ")
  }

  private func format(_ value: Double) -> String {
    String(format: "%.3f", value)
  }
}
