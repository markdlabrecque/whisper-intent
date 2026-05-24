# Spike S1: WhisperKit medium progress callback granularity

**Status:** Completed
**Owner:**
**Started:** 2026-05-22
**Completed:** 2026-05-23
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

**Running the harness:**

1. Install a DEBUG build on device.
2. Open Whisper Intent → **Open spike harness**.
3. Tap **Run 30s sample** or **Run 300s sample**.
4. Wait for `transcribeEnd`, followed by `METRIC ...` lines.
5. Tap **Share log** and save or send the `.log` file. The same file is also written to the app's Documents directory.

The `METRIC` lines are the source of truth for the table below:

- `totalTranscriptionTime` → total transcription time.
- `progressCallbacks` / `segmentCallbacks` → callback count, callback frequency, mean/min/max wall-clock interval.
- `payloadShapes` / `finalProgressPayload` / `finalSegmentPayload` → callback payload structure.
- `firstProgressFractions` → sample callback positions as a fraction of total transcription time.

**Test environment:**
- Device(s): iPhone 18 (latest available local test device). Timing numbers are not treated as minimum-device performance targets; S3 covers oldest-device runtime budget.
- iOS version: latest local iOS 26.x at time of spike.
- WhisperKit version: pinned version from `Package.resolved`.
- Xcode version:
- Build configuration: Debug harness build. Use these results for callback semantics/granularity, not launch performance targets.

## 4. Raw findings

Harness implementation is in place:

- `Packages/WhisperIntentCore/Sources/WhisperIntentCore/SpikeHarness/SpikeS1Harness.swift`
- `App/WhisperIntent/Views/DebugSpikesView.swift`
- Bundled samples:
  - `App/WhisperIntent/Resources/Samples/sample-30s.wav`
  - `App/WhisperIntent/Resources/Samples/sample-300s.wav`

Build verification before on-device run:

- 2026-05-22: `make build` passed.
- 2026-05-22: app build passed on iOS 26.5 simulator after regenerating the Xcode project.

| Sample | Total transcription time | Progress callbacks | Progress callback frequency | Mean progress interval | Segment callbacks | Final payloads | First progress fractions |
|---|---:|---:|---:|---:|---:|---|---|
| 30s | 4.057s | 104 | 25.636 Hz | 0.034s | 1 | `progress: tokens=105, windowId=0`; `segmentDiscovery: segments=9, lastEnd=20.720`; `transcriptionState: state=Finished` | `0.119,0.128,0.137,0.146,0.155,0.164,0.172,0.181,0.190,0.198,0.207,0.215` |
| 300s | 25.000s | 633 | 25.320 Hz | 0.039s | 7 | `progress: tokens=11, windowId=6`; `segmentDiscovery: segments=1, lastEnd=165.440`; `transcriptionState: state=Finished` | `0.019,0.021,0.022,0.024,0.025,0.027,0.028,0.029,0.031,0.032,0.034,0.035` |

## 5. Interpretation

Progress callbacks are frequent on both samples: ~25 Hz on the short sample and ~25 Hz on the longer sample. Granularity does not degrade on longer input. The callback payload exposes token count and window ID, which is enough to show frequent activity but not, by itself, a stable total-work denominator for a determinate 0...1 progress bar.

Segment discovery is much coarser: one callback for the short sample and seven callbacks for the longer sample. Segment callbacks are useful for phase/status detail, but too sparse to drive smooth progress.

Processing time on the available test device was short enough that a determinate progress bar is not necessary for v1 UX. These times were measured on a newer device than the planned minimum; S3/M4 will still validate end-to-end runtime budget on the oldest supported iOS 26 device.

## 6. Decision

**Indeterminate spinner with phase labels in v1.** `TranscriptionProgress.phase(_:)` is the active case. Determinate progress moves to v2 only if a later WhisperKit API or deeper adapter work exposes a reliable total-work denominator.

**Updates required in other docs:**
- [x] TDD §6.3 — narrow `TranscriptionProgress` to the chosen case; drop the unused one.
- [x] PRD §5.6 — replace "determinate vs indeterminate" paragraph with the decided UI.
- [ ] Wireframes/design for `RecordingSheet` processing state.

## 7. Follow-ups

- S3/M4 must still measure end-to-end background runtime on the oldest supported iOS 26 device.
- RecordingSheet processing wireframes should use spinner + phase labels, not a determinate bar.
