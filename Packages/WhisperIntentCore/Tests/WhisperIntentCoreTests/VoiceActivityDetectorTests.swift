import Foundation
import Testing
@testable import WhisperIntentCore

@Suite("VoiceActivityDetector")
struct VoiceActivityDetectorTests {
  @Test("threshold of zero disables the detector")
  func thresholdZeroDisables() {
    let vad = VoiceActivityDetector()
    vad.reset(silenceThreshold: 0)
    let silentSeconds = 5
    for _ in 0 ..< silentSeconds {
      let triggered = vad.observe(silentBuffer(seconds: 1))
      #expect(!triggered)
    }
  }

  @Test("does not trigger during warmup window")
  func noTriggerDuringWarmup() {
    let vad = VoiceActivityDetector()
    vad.reset(silenceThreshold: 0.5)
    // 250 ms of silence — well inside the 500 ms warmup.
    let triggered = vad.observe(silentBuffer(seconds: 0.25))
    #expect(!triggered)
  }

  @Test("triggers after silence sustained past threshold")
  func triggersAfterSilence() {
    let vad = VoiceActivityDetector()
    vad.reset(silenceThreshold: 1.0)

    // Warmup with low-level noise so the noise floor isn't 0.
    let warmup = noiseBuffer(seconds: 0.6, amplitude: 0.001)
    #expect(!vad.observe(warmup))

    // Feed silence for longer than the threshold.
    let silence = silentBuffer(seconds: 1.2)
    let triggered = vad.observe(silence)
    #expect(triggered)
  }

  @Test("speech-then-silence: silence after voice triggers stop")
  func speechThenSilence() {
    let vad = VoiceActivityDetector()
    vad.reset(silenceThreshold: 0.8)

    // 600 ms of speech-level signal (well above the noise floor + margin).
    let speech = noiseBuffer(seconds: 0.6, amplitude: 0.1)
    #expect(!vad.observe(speech))

    // 1 s of silence — should trigger.
    let triggered = vad.observe(silentBuffer(seconds: 1.0))
    #expect(triggered)
  }

  @Test("speech mid-silence resets the silence counter")
  func speechResetsCounter() {
    let vad = VoiceActivityDetector()
    vad.reset(silenceThreshold: 1.0)

    #expect(!vad.observe(noiseBuffer(seconds: 0.6, amplitude: 0.001))) // warmup

    // Half a second of silence...
    #expect(!vad.observe(silentBuffer(seconds: 0.5)))
    // ...then a burst of speech...
    #expect(!vad.observe(noiseBuffer(seconds: 0.2, amplitude: 0.1)))
    // ...then half a second of silence again. Should NOT trigger yet because the
    // mid-window speech reset the silence counter.
    let triggered = vad.observe(silentBuffer(seconds: 0.5))
    #expect(!triggered)
  }

  @Test("trigger is single-shot per recording")
  func singleShot() {
    let vad = VoiceActivityDetector()
    vad.reset(silenceThreshold: 0.5)

    #expect(!vad.observe(noiseBuffer(seconds: 0.6, amplitude: 0.001))) // warmup
    #expect(vad.observe(silentBuffer(seconds: 1.0))) // triggers
    #expect(!vad.observe(silentBuffer(seconds: 1.0))) // already triggered, no repeat
  }

  @Test("reset clears prior detection state")
  func resetClearsState() {
    let vad = VoiceActivityDetector()
    vad.reset(silenceThreshold: 0.5)

    #expect(!vad.observe(noiseBuffer(seconds: 0.6, amplitude: 0.001)))
    #expect(vad.observe(silentBuffer(seconds: 1.0)))

    vad.reset(silenceThreshold: 0.5)
    // After reset, warmup runs again and silence within warmup must not trigger.
    let triggered = vad.observe(silentBuffer(seconds: 0.3))
    #expect(!triggered)
  }
}

// MARK: - Synthetic audio helpers

private let sampleRate: Int = 16000

private func silentBuffer(seconds: Double) -> [Float] {
  Array(repeating: Float(0), count: Int(Double(sampleRate) * seconds))
}

private func noiseBuffer(seconds: Double, amplitude: Float) -> [Float] {
  let count = Int(Double(sampleRate) * seconds)
  var generator = SystemRandomNumberGenerator()
  return (0 ..< count).map { _ in
    let value = Float.random(in: -1 ... 1, using: &generator)
    return value * amplitude
  }
}
