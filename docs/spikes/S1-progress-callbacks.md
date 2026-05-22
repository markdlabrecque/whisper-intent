# Spike S1: WhisperKit medium progress callback granularity

**Status:** Not started
**Owner:**
**Started:**
**Completed:**
**Linked from:** [TDD §6.3](../TDD.md), [MILESTONES.md M2](../MILESTONES.md)

---

## 1. Question

Does WhisperKit's medium model expose progress callbacks at fine enough granularity to drive a determinate progress bar, or is v1 limited to an indeterminate spinner?

## 2. Why it matters

PRD §5.6 commits to *some* processing indicator in v1, but determinate vs indeterminate is open. Determinate gives the user a real ETA; indeterminate is honest about uncertainty. The choice changes the visual design of both `RecordingSheet` and `RootView` and the shape of `TranscriptionProgress` (TDD §6.3). Cost of guessing wrong: building a determinate UI on top of callbacks that turn out to be too coarse means rebuilding the UI mid-implementation.

## 3. Method

1. Add WhisperKit medium to a throwaway harness target (or use a debug button inside the main app).
2. Bundle two sample audio files:
   - `sample-30s.wav` — a 30-second English voice sample (varied speech, ~75 words).
   - `sample-300s.wav` — a 5-minute English voice sample to test whether granularity degrades on longer inputs.
3. For each sample, transcribe via WhisperKit medium with every available progress callback wired up. Log each callback with: wall-clock timestamp, callback type, payload (segments decoded, tokens, anything else exposed).
4. Save the logs verbatim into §4.
5. Compute: callback frequency (Hz), wall-clock between callbacks, and what fraction of total transcription time each callback represents.

**Test environment:**
- Device(s): iPhone 14 (A16) at minimum; ideally also the oldest iOS 26 device.
- iOS version: latest 26.x at time of spike.
- WhisperKit version: pinned version from `Package.resolved`.
- Xcode version:
- Build configuration: Release (Debug skews ML perf).

## 4. Raw findings

_(paste logs, screenshots, callback frequency tables here)_

| Sample | Total transcription time | # callbacks fired | Mean interval | Payload shape |
|---|---|---|---|---|
| 30s |  |  |  |  |
| 300s |  |  |  |  |

## 5. Interpretation

_(does granularity hold up on longer inputs? are callbacks evenly distributed or clumpy? is there a signal that maps cleanly to a 0..1 fraction?)_

## 6. Decision

_Pick one:_

- **Determinate progress bar in v1.** Driven by `<specific signal>`. `TranscriptionProgress.progress(fraction:phase:)` is the active case.
- **Indeterminate spinner with phase labels in v1.** `TranscriptionProgress.phase(_:)` is the active case. Determinate bar moves to v2 roadmap.

**Updates required in other docs:**
- [ ] TDD §6.3 — narrow `TranscriptionProgress` to the chosen case; drop the unused one.
- [ ] PRD §5.6 — replace "determinate vs indeterminate" paragraph with the decided UI.
- [ ] Wireframes/design for `RecordingSheet` processing state.

## 7. Follow-ups

-
