# Spike S3 — On-device test plan

**Companion to:** [S3-background-budget.md](S3-background-budget.md)
**Goal:** Find the longest end-to-end recording + transcription that iOS will reliably allow when `TranscribeSpeechIntent` runs with `showUI = false`, on the **oldest** iOS 26-capable iPhone available. The number that comes out of this checklist becomes the v1 max-duration cap baked into PRD §5.4.1, the AppIntent description, onboarding copy, and the recording UI's warning thresholds.

Tick boxes inline as you go. Capture results into both this file (working sheet) and §4 of `S3-background-budget.md` (canonical record).

---

## 0. Prerequisites

- [X] **Oldest** iOS 26-capable iPhone available (note model + iOS version: `iphone 17 + iOS 26.4.2`). The cap must be set to what the oldest device can handle, not what your newest one can.
- [n/a] One additional iPhone (any iOS 26 generation) for the cross-device comparison row (optional, marks the headroom on newer hardware).
- [X] Mac running Xcode 26.x.
- [X] Device paired to Xcode, developer mode enabled.
- [X] iPhone is **on battery, not plugged in** — matches real-world conditions and lets thermal effects appear.
- [X] iPhone is **not in Low Power Mode** unless you explicitly want to test that case.
- [X] Branch checked out: `feat/m4-spike-s3-intent` (or whatever branch carries the wired `TranscribeSpeechIntent`).
- [ ] **Generate playback samples:** from the project root, `bash scripts/generate-s3-samples.sh`. Produces `s3-samples/sample-{10s,30s,60s,90s,120s,180s,300s}.wav` (gitignored). Each is a cumulative extension of the previous — the 5-minute sample contains the full narrative, and shorter samples are prefixes. Lets you spot mid-recording drops at a glance: a "good" 60s transcript should be a prefix of a "good" 90s transcript, and so on. **Why pre-recorded:** S3 is a controlled experiment; removing the human voice as a variable makes runs comparable across devices and across days. Note: actual sample durations land ~85–100 % of their label (verify with `afinfo s3-samples/sample-*.wav`); the spike's conclusion is unaffected, but record the actual durations in the §4 table notes.
- [ ] **Playback rig:** how you'll route a Mac (or any audio source) into the iPhone's microphone. Options, in rough order of fidelity:
  - **Mac speakers → iPhone mic, in a quiet room** (lowest setup; some ambient noise contamination). Place the phone ~30 cm from the speaker.
  - **Wired or AirPlay loopback** via a second device.
  - **Cabled audio interface** if you have one (best fidelity, no acoustic path).
  Whichever you use, run `sample-10s.wav` through `S3 Foreground` once and check that the returned transcript reads roughly like the sample's text — that confirms the rig works before you start the duration ladder.

---

## 1. Build & install

- [X] From the project root: `make generate` to regenerate the Xcode project.
- [X] Open `WhisperIntent.xcodeproj`.
- [X] Select the **WhisperIntent** scheme, **Release** configuration (Debug skews ML perf and we want representative timing).
- [X] Build & Run to the oldest test iPhone.
- [X] Confirm the app launches and `RootView` appears.

**Observed build / iOS version:** `___________`

---

## 2. Confirm the intent surfaces in Shortcuts

- [ ] Open the **Shortcuts** app on the iPhone.
- [ ] Tap **+** to create a new shortcut.
- [ ] Search for `Transcribe Speech` in the action picker. It should appear under WhisperIntent.
- [ ] Add the action. Configure: `Silence threshold = 1.0` (seconds), `Show UI = Off`, `Prompt` empty.
- [ ] After `Transcribe Speech`, add a **Show Content** action. Set its content to the magic variable named `Transcribe Speech` (the action's output).
- [ ] After Show Content, add a **Get Current Date** action, then a **Format Date** action set to `Time` style. (Used in §3 to capture elapsed wall-clock if you want it.)
- [ ] Save the shortcut as `S3 Background` and add to the home screen as a tap target.
- [ ] Duplicate the shortcut, set `Show UI = On`, save as `S3 Foreground`. Also add to the home screen.

**Why VAD-based stop:** background-mode invocations have no UI to tap Stop, so the test recording stops via VAD (silence threshold) after you stop speaking. A 1-second silence threshold keeps the spike runs tight; the user-facing default is 2 seconds (PRD §5.4).

---

## 3. Permission grant (one-time)

- [ ] Run `S3 Foreground` from the home screen once. Grant mic permission when prompted (the foreground path makes the prompt visible — easier than debugging "Why did the background run silently fail?").
- [ ] Confirm `S3 Foreground` completes and Show Content displays a transcript.
- [ ] Now `S3 Background` should run without re-prompting.

---

## 4. Duration ladder — `showUI = false` (the load-bearing measurement)

For each row:

1. Queue up the matching playback sample (e.g., for the 60 s row, open `s3-samples/sample-60s.wav` in QuickTime or your audio player of choice, but **don't start playback yet**).
2. Start the Stopwatch (iOS Clock app), tap `S3 Background` on the home screen.
3. **Immediately** start playback of the sample. The Shortcut's recording will pick it up via the iPhone's mic.
4. When the sample finishes playing, leave the iPhone alone. The VAD will trigger ~1 second after the audio stops, then the recorder hands off to WhisperKit.
5. **Wait** for Show Content to appear with the transcript.
6. **Then** record:

- **Captured?** ✅ if Show Content displayed a transcript that matches (or is a sensible prefix of) the sample's text. ❌ if the Shortcut showed an error, an empty result, or never returned.
- **Total wall-clock** = stopwatch reading when Show Content appears.
- **Notes** = anything unusual (Dynamic Island indicator disappeared mid-run, app crashed, system notification, the transcript was a short prefix that suggests mid-recording termination, etc.).

Each row gets **three runs** to detect flakiness.

### 4.1 Oldest test device (`___________`)

| Duration | Run 1 captured? | Run 1 total | Run 2 captured? | Run 2 total | Run 3 captured? | Run 3 total | Notes |
|---|---|---|---|---|---|---|---|
| 10 s | ☐ ✅ ☐ ❌ | `____` | ☐ ✅ ☐ ❌ | `____` | ☐ ✅ ☐ ❌ | `____` | |
| 30 s | ☐ ✅ ☐ ❌ | `____` | ☐ ✅ ☐ ❌ | `____` | ☐ ✅ ☐ ❌ | `____` | |
| 60 s | ☐ ✅ ☐ ❌ | `____` | ☐ ✅ ☐ ❌ | `____` | ☐ ✅ ☐ ❌ | `____` | |
| 90 s | ☐ ✅ ☐ ❌ | `____` | ☐ ✅ ☐ ❌ | `____` | ☐ ✅ ☐ ❌ | `____` | |
| 2 min | ☐ ✅ ☐ ❌ | `____` | ☐ ✅ ☐ ❌ | `____` | ☐ ✅ ☐ ❌ | `____` | |
| 3 min | ☐ ✅ ☐ ❌ | `____` | ☐ ✅ ☐ ❌ | `____` | ☐ ✅ ☐ ❌ | `____` | |
| 5 min | ☐ ✅ ☐ ❌ | `____` | ☐ ✅ ☐ ❌ | `____` | ☐ ✅ ☐ ❌ | `____` | |

**Stop early if:** a duration fails on all three runs. There's no point measuring longer ones — the cap will land at or below the longest duration that passed at least 2/3.

**Cool-down between rows:** wait ~30 seconds between consecutive runs so thermal carry-over from a long run doesn't poison the next row's measurement.

---

## 5. Spot-check — `showUI = true` (foreground sanity)

The cap applies uniformly to both modes (PRD §5.4.1), but the spike is primarily about the background budget. Sanity-check the foreground path so we know it's not similarly constrained.

- [ ] Run `S3 Foreground` for **60 s** (same protocol as §4). Expect ✅, transcript returned. Note total: `____` seconds.
- [ ] Run `S3 Foreground` for **5 min** (or the longest duration that passed in §4 + 60 seconds). Expect ✅, transcript returned. Note total: `____` seconds.

If foreground succeeds at a duration where background failed, that's expected and informative — confirms the background limit is iOS's budget, not our pipeline.

---

## 6. Thermal back-to-back

Background runs that ride right up against the budget may pass once when the SoC is cool but fail after thermal load. Test this.

Pick the longest duration that passed all three runs in §4. Call it `D`.

- [ ] Run `S3 Background` for `D` seconds (Run A). Expect ✅. Record total: `____` seconds.
- [ ] **Immediately** (no cool-down) run again for `D` seconds (Run B). Expect ✅. Record total: `____` seconds.
- [ ] **Immediately** again for `D` seconds (Run C). Record total: `____` seconds.

| Run | Captured? | Total wall-clock | Δ vs Run A |
|---|---|---|---|
| A | ☐ ✅ ☐ ❌ | `____` | — |
| B | ☐ ✅ ☐ ❌ | `____` | `____` |
| C | ☐ ✅ ☐ ❌ | `____` | `____` |

If Run C fails or its wall-clock grows by >20% versus Run A, the cap should drop one rung below `D`.

---

## 7. Cross-device — newer iPhone (optional)

Install the same Release build on a newer iPhone.

- [ ] Repeat the 5 min row of §4 (three runs).
- [ ] Note whether the longer durations that failed on the oldest device pass here.

This row exists to **document the headroom on newer hardware**, not to influence the cap. The cap stays keyed to the oldest device.

| Duration | Run 1 captured? | Run 2 captured? | Run 3 captured? | Notes |
|---|---|---|---|---|
| 5 min | ☐ ✅ ☐ ❌ | ☐ ✅ ☐ ❌ | ☐ ✅ ☐ ❌ | |

---

## 8. Console scan (one run)

- [ ] Attach Xcode to the oldest test device.
- [ ] Run `S3 Background` for the longest duration that passed in §4.
- [ ] Capture the Xcode console output for the duration of the run.
- [ ] Search for: `memory`, `terminated`, `background`, `deactivat`, `interrupted`, `denied`, `failed`.
- [ ] Paste anything noteworthy below.

```
(paste here — or write "no issues" if clean)
```

---

## 9. Choose the cap

1. The longest duration that **passed 3/3 runs in §4 and survived §6 thermal**, on the oldest test device, is the safe budget.
2. The v1 cap is the largest **round number** at or under that safe budget. Round-number examples: `60 s`, `90 s`, `2 min`, `3 min`, `5 min`. Picking a round number makes the user-facing copy cleaner and gives ~10–20 % headroom against your measured number.

**Recorded safe budget on oldest device:** `____` seconds

**Chosen v1 cap:** `____` (with reasoning: `___________`)

**Escalation trigger:** if the chosen cap is **<30 s** on the oldest device, **pause and escalate to product before proceeding to M5.** A sub-30-second cap changes the value proposition and may warrant a scope conversation (drop background mode? raise the iOS minimum to exclude the oldest devices? both?).

---

## 10. Propagate the decision

Once the cap is chosen:

- [ ] Fill in §4 of `docs/spikes/S3-background-budget.md` from the raw rows in §4 above.
- [ ] Write the §5 interpretation: where does the cliff appear? is it gradual or sharp? does thermal shift it?
- [ ] Write the §6 decision with the chosen cap and reasoning.
- [ ] Update PRD §5.4.1 — replace "TBD" with the chosen value.
- [ ] Update TDD §7.3 — pin `maxDuration` (currently `600` placeholder in `TranscribeSpeechIntent.swift`).
- [ ] Replace the `spikeMaxDuration: TimeInterval = 600` placeholder in `TranscribeSpeechIntent.swift` with the chosen cap.
- [ ] Update the AppIntent's `IntentDescription` copy in `TranscribeSpeechIntent.swift` so it tells the Shortcuts user the cap: "Records up to N minutes per invocation."
- [ ] Fold the S3 entry into `docs/spike-decisions.md` and delete `docs/spikes/S3-background-budget.md` + this test plan, matching the convention used for S1 / S2 / S4.
- [ ] Close GitHub issue #4 (spike) and #8 (M4 tracker).

Then green-light M5 (AppIntent + UI surfaces).

---

## 11. Troubleshooting

**Shortcut shows an error like "Whisper Intent encountered an error":**
- Check Console.app on the Mac filtered to the WhisperIntent process. The error message from `IntentError` should show up there.
- `permissionDenied` → §3 wasn't completed. Open `S3 Foreground` once to grant mic.
- `busy` → a previous run is still in-flight. Wait, or restart the app.
- `interrupted` → audio session was interrupted mid-recording (incoming notification audio, route change). Re-run in a quiet environment.

**Shortcut returns silently with an empty transcript:**
- Means the intent's `perform()` returned a `String` that was empty. Possible causes: VAD never triggered (you didn't pause speaking long enough) and iOS terminated the background process mid-recording, returning whatever WhisperKit produced from the partial audio. Mark the row as ❌ and note "empty result".

**The Dynamic Island indicator disappears mid-recording:**
- iOS killed the background AppIntent. The Shortcut should also show an error or empty result. Treat as ❌.

**`S3 Foreground` brings the app forward and shows only the placeholder `RootView`:**
- Expected for M4. The polished `RecordingSheet` is M5 work. The recording is still happening — wait for Show Content to appear with the transcript.

**Transcription takes a noticeably long time for a 5-minute recording:**
- Expected. S1 measured ~25 Hz progress callbacks but didn't profile total transcription time on the oldest device. If transcription itself eats most of the background budget, that's a finding — record total wall-clock including transcription, and consider whether the cap needs to account for it (it should — the user cares about end-to-end time, not just recording time).
