# M5 — Manual Test Plan

**Milestone:** [M5 — AppIntent + UI surfaces](MILESTONES.md)
**Status:** Draft v0.1
**Last updated:** 2026-05-25

Covers the user-facing surfaces introduced in M5: the production `RecordingSheet`, `RootView`, `SettingsView`, `OnboardingView`, the `RecordingLimits` cap pipeline, and the wiring between `TranscribeSpeechIntent` and the recording sheet.

This plan is a milestone gate, not a regression suite. It validates that the surfaces M5 introduces work end-to-end on a real iPhone. Run it on the newest test device first; defer the oldest-device sweep to M6.

> **Prerequisite:** install a fresh build (delete the app on the device first so onboarding shows). Mic permission must not be pre-granted.

---

## Section 1 — First-run onboarding

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 1.1 | Launch app on a clean install. | `OnboardingView` appears full-screen. Screen 1 ("Whisper Intent is a building block.") visible. Skip button in top-trailing. |  |
| 1.2 | Tap **Continue**. | Screen 2 ("Build the Shortcut you want.") with the numbered Reminders example. |  |
| 1.3 | Tap **Continue**. | Screen 3 ("One quick test.") with Record-a-test button. **No cap sentence** while S3 is shelved. |  |
| 1.4 | Tap **Record a test**, grant mic permission at the system prompt, say a sentence, then tap **Stop**. | State badge shows "Listening…" then "Transcribing…". After completion, Screen 4 ("You're set.") appears. |  |
| 1.5 | Tap **Done**. | `OnboardingView` dismisses. `RootView` landing visible. `UserSettings.onboardingCompleted` = true (verify by force-quitting and relaunching — no onboarding on next launch). |  |
| 1.6 | (Reset) Delete app, reinstall. On Screen 3, tap **Skip** instead. | Onboarding dismisses. App lands on `RootView` with no mic permission granted. |  |
| 1.7 | (Reset) Delete app, reinstall. On Screen 3 tap Record a test, then **Deny** the system mic prompt. | Inline error appears: "Microphone permission was not granted. Enable it in Settings → Whisper Intent to use Shortcuts." Skip button still works. |  |

## Section 2 — `RootView` landing

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 2.1 | Open app from springboard (onboarding completed). | Landing screen: waveform glyph, headline copy, settings gear in top-trailing. In DEBUG builds, a "Spike harness" button is also visible. |  |
| 2.2 | Tap the settings gear. | `SettingsView` presented as a sheet. |  |

## Section 3 — `SettingsView`

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 3.1 | Open Settings. | Three sections: **Defaults** (silence threshold slider, default 2.0s), **Example Shortcut patterns** (three plain-text examples), **About** (version, WhisperKit link, "Show onboarding again"). |  |
| 3.2 | Move the silence-threshold slider to 3.5s. Dismiss Settings, reopen. | Slider still reads 3.5s. (Persisted via `@AppStorage`.) |  |
| 3.3 | Tap the WhisperKit link. | Safari opens to https://github.com/argmaxinc/WhisperKit. |  |
| 3.4 | Tap **Show onboarding again**. | Onboarding flow appears as a sheet. Dismissing it returns to Settings. |  |

## Section 4 — `TranscribeSpeechIntent` with **Show UI = true**

Build a one-step Shortcut: `Transcribe Speech` with `Show UI` enabled, `Silence threshold` default. Set an optional `Prompt` of "Test prompt".

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 4.1 | Run the Shortcut from the Shortcuts app. | App launches, `RecordingSheet` presents with prompt "Test prompt" visible at the top. Recording starts. |  |
| 4.2 | Speak, then tap **Stop**. | Sheet transitions in place to a spinner with phase label ("Encoding…" / "Transcribing…"). On completion the sheet auto-dismisses and control returns to Shortcuts; the next step (or the Shortcut result) shows the transcript. |  |
| 4.3 | Trigger the Shortcut from Siri ("Hey Siri, <shortcut name>"). | Same flow as 4.1–4.2. (Per S2: Siri voice may behave inconsistently for background routing, but `showUI = true` should escalate cleanly.) |  |
| 4.4 | Bind the Shortcut to the Action Button (Settings → Action Button). Press it. | Same flow as 4.1–4.2. |  |
| 4.5 | Pin the Shortcut to a lock-screen widget. Tap from lock screen. | Same flow. |  |
| 4.6 | Run the Shortcut, but during recording **swipe the sheet down**. | Sheet dismisses. Recording continues (PRD §5.8). Transcript still returns to the Shortcut. |  |
| 4.7 | Repeat 4.6, but immediately open Whisper Intent from springboard after dismissing. | `RootView` mirrors the live recording state (level meter, elapsed counter). Tapping Stop in `RootView` ends the recording the same way the sheet would have. |  |
| 4.8 | Tap Stop very early (sub-1s utterance). | Cleanly produces a `.completed(transcript:)` (possibly empty) or a `.failed` — no hang. |  |

## Section 5 — `TranscribeSpeechIntent` with **Show UI = false**

Build a second Shortcut: `Transcribe Speech` with `Show UI` disabled.

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 5.1 | Run the Shortcut from the Shortcuts app. | No sheet, no app launch. System mic indicator appears. After silence-threshold trigger or max-duration, transcript returns to Shortcut. |  |
| 5.2 | Same as 5.1 with mic permission **not yet granted** (fresh install, skipped onboarding). | Shortcut errors with the `IntentError.permissionDenied` localized string. No silent hang. |  |
| 5.3 | Run the Shortcut, then within 0.5s, start it again. | Second invocation returns `IntentError.busy`. |  |
| 5.4 | Run the Shortcut twice back-to-back, waiting for the first to finish. | Both succeed independently. |  |

## Section 6 — Failure modes

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 6.1 | Start a `showUI = true` recording. While recording, receive a phone call (call yourself from another device). | Recording transitions to `.failed(.interrupted)`. Sheet auto-dismisses. Shortcut surfaces `IntentError.interrupted`. |  |
| 6.2 | With AirPods connected, start a `showUI = true` recording. Disconnect AirPods mid-recording. | Same clean `.failed(.interrupted)` path. |  |
| 6.3 | Deny mic permission in iOS Settings, then run any Shortcut. | Shortcut errors with `IntentError.permissionDenied` localized text. |  |

## Section 7 — Visual + cap thresholds

**Note:** while S3 is shelved, `RecordingLimits.maxRecordingSeconds = 600`. Visual cap warnings only appear during very long recordings. Once S3 closes with a shorter cap, this section becomes quicker to exercise.

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 7.1 | Start a long recording (>8 min while cap = 600s). At 480s (80%) the elapsed counter shifts to orange; at 570s (95%) it shifts to red. | Color transitions correctly. |  |
| 7.2 | Let the recording reach the cap (600s). | Audio capture stops automatically; transitions to `.processing`; transcript still returns successfully (cap-reached is not an error, per TDD §7.3). |  |

---

## Sign-off

| Tester | Device + iOS | Date | Outcome |
|---|---|---|---|
|  |  |  |  |

A pass requires sections 1–5 fully green and at least one row in section 6 verified. Section 7 is best-effort while the cap is the 600s placeholder.
