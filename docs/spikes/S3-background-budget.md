# Spike S3: Background execution budget & max-duration cap

**Status:** Not started
**Owner:**
**Started:**
**Completed:**
**Linked from:** [PRD §5.4.1](../PRD.md), [TDD §7.3](../TDD.md), [MILESTONES.md M4](../MILESTONES.md)

---

## 1. Question

What is the longest recording-plus-transcription wall-clock time that iOS will reliably allow when the `Transcribe Speech` AppIntent runs with `showUI = false`, on the oldest iOS 26-capable iPhone?

## 2. Why it matters

This is the **load-bearing spike** for v1. Its answer becomes the max-duration cap value baked into:
- App Store description ("Records up to N minutes per invocation").
- AppIntent description shown in the Shortcuts editor.
- Onboarding screen.
- The recording UI's warning thresholds (80% and 95% of cap).

Cost of guessing wrong: a too-generous cap means recordings get killed by iOS mid-way and Shortcuts return errors that the user can't diagnose; a too-conservative cap means the product is artificially limited. Run this spike on a *real* end-to-end pipeline (M3 must be complete) — synthetic numbers from a stub harness do not predict real behavior.

## 3. Method

1. Confirm M3 is complete: `TranscriptionSession` drives a real `AudioRecorder` + real `WhisperKitTranscriber` with the bundled medium model.
2. Wire a minimal `TranscribeSpeechIntent` with `showUI` parameter to drive `TranscriptionSession`.
3. Build a test Shortcut on a real iPhone that invokes the intent and logs the result + any error.
4. On the **oldest iOS 26-capable iPhone** available, run the Shortcut with progressively longer recordings:
   - 10s, 30s, 60s, 90s, 2min, 3min, 5min (use a stopwatch or a recorded test pattern).
   - Both `showUI = true` and `showUI = false`.
5. For each run, record: did it complete? was the transcript returned? did iOS terminate the process? was there an OOM signal? what was the elapsed wall-clock from "intent invoked" to "transcript returned to Shortcut"?
6. Repeat each duration 3× to detect flakiness.
7. Repeat on a newer device to compare; the cap must be set to what the *oldest* device can handle.
8. Note thermal effects: run the 5-minute test back-to-back twice; does the second run degrade?

**Test environment:**
- Device(s): oldest iOS 26-capable iPhone (TBD); plus one newer iPhone for comparison.
- iOS version: latest 26.x at time of spike.
- WhisperKit version: pinned version from `Package.resolved`.
- Build configuration: Release.
- Test conducted with phone on battery (not plugged in) — matches real-world conditions.

## 4. Raw findings

| Device | Duration | `showUI` | Run 1 | Run 2 | Run 3 | Notes |
|---|---|---|---|---|---|---|
| Oldest | 10s | false |  |  |  |  |
| Oldest | 30s | false |  |  |  |  |
| Oldest | 60s | false |  |  |  |  |
| Oldest | 90s | false |  |  |  |  |
| Oldest | 2min | false |  |  |  |  |
| Oldest | 3min | false |  |  |  |  |
| Oldest | 5min | false |  |  |  |  |
| Oldest | 60s | true |  |  |  |  |
| Oldest | 5min | true |  |  |  |  |
| Newer | 5min | false |  |  |  |  |

_(thermal back-to-back results below)_

## 5. Interpretation

_(at what duration does background mode start failing? is there a clear cliff or a soft degradation? does foreground mode hold up? does thermal throttling shift the cliff?)_

## 6. Decision

**v1 max-duration cap:** _<chosen value>_ (likely 60s, 2 min, or 5 min)

The cap applies uniformly to both `showUI = true` and `showUI = false` — one number, one user-facing message.

**Reasoning:** _(why this number; the headroom margin chosen; the device the number is keyed to)_

**Updates required in other docs:**
- [ ] PRD §5.4.1 — replace "TBD" with the chosen cap.
- [ ] TDD §7.3 — pin `maxDuration` in `RecordingConfig`.
- [ ] App Store description (M6 / M7).
- [ ] AppIntent `description` string.
- [ ] Onboarding screen copy.
- [ ] Recording UI warning thresholds (80% / 95% of cap).

**Escalation trigger:** if the chosen cap is <30s on the oldest device, escalate to product before proceeding to M5. A sub-30-second cap changes the value proposition and may warrant a scope conversation (drop background mode? raise iOS minimum to exclude the oldest devices? both?).

## 7. Follow-ups

-
