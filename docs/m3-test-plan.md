# M3 — Core domain on-device test plan

**Companion to:** [MILESTONES.md M3](MILESTONES.md), [TDD.md §3 / §5 / §6 / §9](TDD.md)
**Goal:** Verify the M3 exit criterion — `WhisperIntentCore` records from a real mic, transcribes via WhisperKit medium, and emits a final transcript string, all driven by `TranscriptionSession` and observable through the in-app debug button. Until this checklist is green, the audio + transcription stack is **not** proven to work on real hardware.

Tick boxes inline as you go. Paste console excerpts and transcripts where the document calls for them.

---

## 0. Prerequisites

- [ ] iPhone running iOS 26.x available (note exact version: `___________`).
- [ ] Mac running Xcode 26.x (note exact version: `___________`).
- [ ] Device paired to Xcode, developer mode enabled, signed in with a provisioning-capable Apple ID.
- [ ] AirPods or other Bluetooth headphones available (used in §4 route-loss test). Optional; mark §4 N/A if unavailable.
- [ ] A second phone (or VoIP service) available to call this device (used in §3 interruption test). Optional; mark §3 N/A if unavailable.
- [ ] Branch `develop` checked out locally with the M3 commits merged in. (`git log --oneline -5 develop` should show the AudioRecorder + debug-recording-view commits.)

---

## 1. Build & install

- [ ] From the project root: `make generate` to regenerate `WhisperIntent.xcodeproj` from `project.yml` (picks up any new files added to `App/WhisperIntent/`).
- [ ] Open `WhisperIntent.xcodeproj` (`xed .` or double-click).
- [ ] Select the **WhisperIntent** scheme. Pick **Release** as the build configuration (Debug skews ML perf and we want representative timing).
- [ ] Set the run destination to your physical iPhone.
- [ ] Build & Run (⌘R). Wait for first launch on device.
- [ ] Verify `RootView` appears: `Whisper Intent` title + the `Open spike harness` button.

**Observed app version / build:** `___________`

---

## 2. First-launch permission prompt

The `DebugRecordingView` requests microphone permission lazily on the first tap of **Start recording**. Mic permission must be in the `.undetermined` state for this section (it is on a fresh install).

- [ ] Tap **Open spike harness** from `RootView`.
- [ ] Tap **Open recording harness** in the M3 section.
- [ ] Confirm the State shows `idle`, mic-permission line shows `undetermined`.
- [ ] Tap **Start recording**. iOS should show the standard "Whisper Intent" Would Like to Access the Microphone" prompt with the description "Whisper Intent records your voice when an Apple Shortcut calls the Transcribe Speech action. Audio stays on your iPhone."
- [ ] Tap **Allow**.
- [ ] Mic-permission line should update to `granted`. State should transition to `recording`. Level bar should start moving.

| | Result | Notes |
|---|---|---|
| Permission prompt appeared | ☐ pass ☐ fail | |
| Description text matches Info.plist | ☐ pass ☐ fail | |
| State transitioned to `recording` after grant | ☐ pass ☐ fail | |

**If the prompt never appears or the app crashes immediately:** check the Xcode console for "This app has crashed because it attempted to access privacy-sensitive data without a usage description" — that means `NSMicrophoneUsageDescription` is missing from the built `Info.plist` and the build is stale.

---

## 3. Golden path — short utterance

Test the basic record → transcribe → result cycle with a single short sentence.

- [ ] If state is anything other than `idle`, tap the action button to reset.
- [ ] Tap **Start recording**.
- [ ] State shows `recording`. Level bar moves while you speak.
- [ ] Speak a short, distinctive sentence (e.g., **"The quick brown fox jumps over the lazy dog"**) — about 3–4 seconds.
- [ ] Tap **Stop**.
- [ ] State transitions: `recording → processing(starting) → processing(phase(encoding)) → processing(phase(decoding)) → completed`. Each transition should be visible briefly. The encoding → decoding transition can be very fast on shorter inputs.
- [ ] Transcript appears in the box below.

| Step | Result | Notes |
|---|---|---|
| Recording started cleanly | ☐ pass ☐ fail | |
| Level meter moves with voice | ☐ pass ☐ fail | |
| Stop transitioned to processing | ☐ pass ☐ fail | |
| Processing reached `completed` | ☐ pass ☐ fail | |
| Transcript is plausibly correct | ☐ pass ☐ fail | |

**Transcript actually produced:** `_________________________________________________`

**Time from Stop tap to `completed` state:** `_____` seconds (eyeball estimate is fine)

---

## 4. Long utterance — ~60 seconds

Verifies the recorder + transcriber handle a non-trivial buffer without exhausting memory or producing a degraded transcript.

- [ ] Tap the action button to reset, then tap **Start recording**.
- [ ] Speak continuously for ~60 seconds. Read a paragraph from a book, recite a memorised passage, or describe what you're looking at right now.
- [ ] Tap **Stop**.
- [ ] Wait for transcription to complete. Note wall-clock time.
- [ ] Skim the transcript for obvious quality regressions (dropped words mid-sentence, long stretches of garbled output, runaway repetition).

| | Result | Notes |
|---|---|---|
| Recording captured the full ~60s | ☐ pass ☐ fail | |
| Transcription completed | ☐ pass ☐ fail | |
| Transcript reads coherently | ☐ pass ☐ fail | |

**Transcription wall-clock time:** `_____` seconds

**Anything notable about the transcript:**
```
(paste a snippet or any oddities)
```

---

## 5. Phone-call interruption mid-recording

The recorder subscribes to `AVAudioSession.interruptionNotification` and should surface `failed(interrupted)` when iOS pauses the audio session — TDD §5.1.

Skip and mark N/A if you don't have a way to phone this device. Cellular call is the most reliable interrupter; FaceTime / WhatsApp also work.

- [ ] Tap the action button to reset, then tap **Start recording**.
- [ ] Speak normally for a few seconds.
- [ ] Have the second device place a call to this iPhone (or initiate a FaceTime call).
- [ ] Observe the state on the iPhone as the call rings / connects.
- [ ] State should transition to `failed(interrupted)`. The level bar should freeze. The transcript box should not appear.
- [ ] Decline / hang up the call.
- [ ] Tap **Start recording** again to verify the session can be restarted cleanly after an interruption.

| | Result | Notes |
|---|---|---|
| State went to `failed(interrupted)` | ☐ pass ☐ fail ☐ N/A | |
| App did not crash or hang | ☐ pass ☐ fail ☐ N/A | |
| Restart after interruption works | ☐ pass ☐ fail ☐ N/A | |

---

## 6. Route loss — AirPods disconnect mid-recording

Tests `AVAudioSession.routeChangeNotification` handling with reason `.oldDeviceUnavailable` — TDD §5.1.

Skip and mark N/A if no Bluetooth headphones are available.

- [ ] Connect AirPods (or other Bluetooth headphones) to the iPhone.
- [ ] Confirm audio is being routed to them (Control Center → AirPlay icon).
- [ ] Tap the action button to reset, then tap **Start recording**.
- [ ] Speak normally for a few seconds.
- [ ] Disconnect the AirPods (open the case, or hold both stems until they unpair, or toggle Bluetooth off).
- [ ] Observe the state on the iPhone.
- [ ] State should transition to `failed(interrupted)`. Level bar freezes.
- [ ] Reconnect AirPods (or toggle Bluetooth back on if disabled).
- [ ] Tap **Start recording** again to verify a clean restart.

| | Result | Notes |
|---|---|---|
| State went to `failed(interrupted)` | ☐ pass ☐ fail ☐ N/A | |
| App did not crash or hang | ☐ pass ☐ fail ☐ N/A | |
| Restart after route loss works | ☐ pass ☐ fail ☐ N/A | |

---

## 7. Permission denial path

Verifies `requestMicrophone()` surfaces denial cleanly.

- [ ] Open **Settings → Privacy & Security → Microphone → Whisper Intent**. Toggle it **off**.
- [ ] Return to the app. (May require a relaunch — iOS sometimes terminates apps when their privacy switches change. If so, relaunch from the home screen.)
- [ ] Tap **Open spike harness → Open recording harness**.
- [ ] Tap **Start recording**.
- [ ] Mic-permission line should read `denied`. An error message should appear: "Microphone permission not granted (denied)."
- [ ] State should remain `idle`. No crash, no recording.
- [ ] Re-enable microphone access in Settings.
- [ ] Tap **Start recording** again. Should now proceed into `recording` cleanly (no second prompt — permission is already granted).

| | Result | Notes |
|---|---|---|
| Denied state surfaces error | ☐ pass ☐ fail | |
| App does not crash on denial | ☐ pass ☐ fail | |
| Re-grant via Settings works without prompt | ☐ pass ☐ fail | |

---

## 8. Backgrounding mid-recording

The recording UI is a debug screen, not the AppIntent foreground sheet — so this is informational only. It tells us how `AVAudioEngine` behaves when the app is backgrounded without the proper background-audio entitlement (which v1 doesn't include).

- [ ] Tap the action button to reset, then tap **Start recording**.
- [ ] Swipe up (home gesture) to send the app to the background while still recording.
- [ ] Wait ~5 seconds.
- [ ] Swipe back to the app.
- [ ] Observe the state.

| | Result | Notes |
|---|---|---|
| State after foregrounding | record what state was: `_______________` | |
| App did not crash | ☐ pass ☐ fail | |
| Restart from current state works | ☐ pass ☐ fail | |

**Acceptable outcomes:** the recording continues (iOS may allow audio capture briefly while backgrounded), OR the session transitions to `failed(interrupted)` because iOS suspended the audio session. Either is fine for the debug view. The production AppIntent will set `supportedModes: [.background, .foreground(.dynamic)]` and have a different lifecycle — that's M5/M4 territory.

---

## 9. Memory check — multiple consecutive recordings

Catches leaks or buffer accumulation across sessions. PRD allows long recordings; we want to confirm the recorder cleans up its accumulator on each cycle.

- [ ] Open Xcode → **Debug Navigator** (⌘7) → with the app running, watch the Memory gauge.
- [ ] Note the baseline memory before any recording: `_____` MB.
- [ ] Record + stop + wait for transcription 5 times in a row (short ~5-second utterances each, no need to read the transcript).
- [ ] Note the memory after the 5th completion: `_____` MB.
- [ ] Difference should be small (≪ 50 MB). Significant growth indicates a leak in the accumulator or observer chain.

| | Result | Notes |
|---|---|---|
| Memory stays roughly flat | ☐ pass ☐ fail | |
| No assert / fatal error across 5 cycles | ☐ pass ☐ fail | |

---

## 10. Console scan while attached

- [ ] Run the app from Xcode (so the console is attached).
- [ ] Repeat the golden-path test from §3 once.
- [ ] In the Xcode console, search for: `error`, `failed`, `deprecat`, `entitle`, `denied`, `crash`, `assertion`.
- [ ] Paste anything suspicious below.

```
(paste here — or write "no issues" if clean)
```

---

## 11. M3 exit criterion — final sign-off

The M3 exit criterion in MILESTONES.md:

> `WhisperIntentCore` can record a sample audio file from a real mic, transcribe it via WhisperKit medium, and emit a final transcript string — all driven by `TranscriptionSession`, with progress callbacks flowing through the state stream. Verified on a real device via a temporary in-app debug button.

Mark complete only when sections 1–3 + 7 + 10 are all passing. Sections 4–6, 8, 9 are highly recommended but not strict gates for M3 — failures there go on the M6-hardening list rather than blocking M4.

- [ ] M3 exit criterion met.
- [ ] No P0 issues observed (crashes, hangs, missing transcript on the golden path).
- [ ] Issues that surfaced and need follow-up:
  - (list any here, with milestone they belong to — M4 / M5 / M6)

Once green, close GitHub issue #7 with a one-line summary, then green-light M4 (Spike S3 — background execution budget).

---

## 12. Troubleshooting

**App crashes immediately on Start recording with no console message:**
- Most likely the build is stale and `NSMicrophoneUsageDescription` isn't in the running binary's `Info.plist`. Clean build folder (Shift+⌘+K), then rebuild.

**State goes to `failed(transcriptionFailed)` immediately when tapping Start:**
- Read the error text — it'll have the underlying message. Common causes: WhisperKit model not found in bundle, AVAudioSession setup failed (rare on iOS), AVAudioEngine couldn't start (also rare).
- Check Console.app for system-level audio errors filtered to the WhisperIntent process.

**Transcript is gibberish or empty:**
- Confirm the model directory is actually in the bundle: in Xcode, with the running app selected → Debug Navigator → tap the process → look at "Loaded Models". If `openai_whisper-medium` isn't there, the bundling broke.
- Try the same utterance through the S1 spike harness (`Run 30s sample`). If S1 works but this doesn't, the issue is in the AudioRecorder's PCM output (sample rate, channel count, format), not WhisperKit.

**Level meter never moves:**
- Confirm mic permission is granted.
- Check whether the input route is bound to a working device (Settings → Privacy & Security → Microphone shows other apps are working).
- Try with internal mic only (disconnect any Bluetooth).

**Long delay between Stop and `completed`:**
- Expected on first run of the process — WhisperKit lazy-loads the medium model (~1.5 GB) on the first transcribe call. Subsequent runs reuse it.
- Spike S1 measured ~25 Hz progress callbacks with no degradation on a 5-minute sample. If you're seeing pauses that look like a stall, capture a sample with Instruments → Time Profiler.

**Recording UI looks frozen:**
- The action button disables itself while an async operation is in flight (`actionInFlight`). If it stays disabled forever, that suggests the underlying `Task` never returns — file a follow-up with the state value visible at the time.
