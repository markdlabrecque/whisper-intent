import Foundation

/// Energy-based voice-activity detector. Maintains a noise-floor estimate over a
/// 500 ms warmup window, then triggers a stop signal when RMS stays below
/// `noiseFloor + threshold` for the configured silence duration.
///
/// Pure algorithmic; no audio session or hardware coupling. Owned by
/// `TranscriptionSession` and fed PCM frames from `AudioRecording.buffers`.
/// See `docs/TDD.md` §5.2.
public final class VoiceActivityDetector: @unchecked Sendable {
  // MARK: - Tuning (constants per TDD §5.2)

  /// Capture sample rate (Hz). PCM is 16 kHz mono Float32.
  private let sampleRate: Double = 16000

  /// RMS window length, in seconds. 30 ms ≈ 480 samples at 16 kHz.
  private let rmsWindowSeconds: Double = 0.030

  /// Warmup window during which a noise-floor estimate is built and the detector
  /// cannot trigger. 500 ms ≈ 8 000 samples at 16 kHz.
  private let warmupSeconds: Double = 0.500

  /// Margin above the noise floor that still counts as "silence." Linear amplitude
  /// units (not dB). Chosen empirically — easy to swap for a dB-based threshold if
  /// real-world testing shows the linear version is too sensitive.
  private let silenceMargin: Float = 0.005

  // MARK: - Mutable state

  /// Silence duration that triggers a stop, in seconds. Set per recording via
  /// `reset(silenceThreshold:)`. A value of 0 disables the detector entirely.
  private var silenceThreshold: TimeInterval = 0

  /// Total samples observed since the last reset.
  private var sampleCount: Int = 0

  /// Sum of `rms` across all windows seen during warmup. Divided at the end of
  /// warmup to produce the noise-floor estimate.
  private var warmupAccumulator: Float = 0
  private var warmupWindows: Int = 0

  /// Estimated noise floor (linear amplitude), or nil while warmup is in progress.
  private var noiseFloor: Float?

  /// Consecutive samples of post-warmup silence accumulated so far.
  private var silenceSamples: Int = 0

  /// Set once the detector has emitted its single stop signal for the current
  /// recording. Prevents repeated triggers.
  private var hasTriggered: Bool = false

  /// In-flight RMS window accumulator: running sum of squares + sample count.
  private var windowSquaresSum: Float = 0
  private var windowSampleCount: Int = 0

  public init() {}

  /// Begins a new detection session. Clears all running state.
  /// `silenceThreshold == 0` disables the detector.
  public func reset(silenceThreshold: TimeInterval) {
    self.silenceThreshold = max(0, silenceThreshold)
    sampleCount = 0
    warmupAccumulator = 0
    warmupWindows = 0
    noiseFloor = nil
    silenceSamples = 0
    hasTriggered = false
    windowSquaresSum = 0
    windowSampleCount = 0
  }

  /// Observes one buffer of PCM frames and returns `true` once the silence
  /// threshold has been sustained past the configured duration. Returns `false`
  /// during warmup, while voice is active, and after the single stop signal has
  /// already fired (idempotent for the rest of the recording).
  @discardableResult
  public func observe(_ frames: [Float]) -> Bool {
    guard silenceThreshold > 0, !hasTriggered, !frames.isEmpty else { return false }

    let windowSamples = Int(rmsWindowSeconds * sampleRate)
    let warmupSamples = Int(warmupSeconds * sampleRate)
    let silenceTriggerSamples = Int(silenceThreshold * sampleRate)

    for sample in frames {
      sampleCount += 1
      windowSquaresSum += sample * sample
      windowSampleCount += 1

      guard windowSampleCount >= windowSamples else { continue }

      let mean = windowSquaresSum / Float(windowSampleCount)
      let rms = mean.squareRoot()
      windowSquaresSum = 0
      windowSampleCount = 0

      if sampleCount <= warmupSamples {
        warmupAccumulator += rms
        warmupWindows += 1
        continue
      }

      if noiseFloor == nil {
        noiseFloor = warmupWindows > 0
          ? warmupAccumulator / Float(warmupWindows)
          : 0
      }

      let floor = noiseFloor ?? 0
      let isSilent = rms < floor + silenceMargin

      if isSilent {
        silenceSamples += windowSamples
        if silenceSamples >= silenceTriggerSamples {
          hasTriggered = true
          return true
        }
      } else {
        silenceSamples = 0
      }
    }

    return false
  }
}
