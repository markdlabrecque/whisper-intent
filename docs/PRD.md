# Whisper Intent — Product Requirements Document

**Status:** Draft v0.1
**Author:** Mark Labrecque
**Last updated:** 2026-05-22

---

## 1. Summary

Whisper Intent is an iOS app that turns on-device speech transcription (via WhisperKit) into a reusable building block for Apple Shortcuts. It ships with no pre-built integrations. Instead, it exposes an App Intent that any user can drop into a Shortcut to capture a voice payload, transcribe it locally, and pass the resulting text downstream to whatever app they prefer — Reminders, Notes, Messages, Things, Drafts, OmniFocus, an HTTP webhook, etc.

The product thesis: existing dictation surfaces are tied to specific destinations (Siri → Reminders, keyboard dictation → focused text field). Whisper Intent decouples the *capture* from the *destination*, letting power users author their own voice → action pipelines without writing code.

## 2. Goals & Non-Goals

### v1 Goals
- Provide a single, composable App Intent (`Transcribe Speech`) that records audio, transcribes it on-device with WhisperKit, and returns the transcript as a `String` output for use in Shortcuts.
- Ship a usable default model (WhisperKit medium) bundled with the app — no first-run downloads.
- Support unlimited recording length, with one active recording at a time (subsequent invocations blocked until the current one finishes).
- Give the user two ways to stop a recording: tap-to-stop in the foreground UI, and voice-activity-detection (VAD) auto-stop after a configurable silence threshold.
- Be invisible enough to feel like a system primitive when run from a Shortcut.

### v1 Non-Goals
- No pre-built Shortcuts, templates, or destination integrations. The Shortcuts library is the user's responsibility.
- No cloud transcription, no account, no telemetry beyond crash reports.
- No multi-recording queue, no background recording, no pause/resume mid-recording.
- No transcript editing UI, no history view (a transcript exists only long enough to return it to the calling Shortcut).

### Explicit v2+ candidates (see §9)
- Processing UI with pause/resume.
- Recording history / transcript library.
- Model picker and download manager.
- Structured output (transcript + confidence + timestamps).

## 3. Target Users

- **Apple Shortcuts power users** who already build multi-step automations and want voice as an input modality without being routed through Siri.
- **Privacy-conscious dictation users** who want on-device transcription and don't trust cloud dictation.
- **Accessibility users** who want voice capture pointed at non-Apple destinations (e.g. third-party task managers, custom webhooks).

This is a deliberately narrow, enthusiast-leaning audience. The PRD does not optimize for mass market.

## 4. Platform & Constraints

| Constraint | Decision | Rationale |
|---|---|---|
| Minimum iOS | **iOS 26** | Per Apple's Feb 2026 numbers, ~74% of recent-device iPhones and ~66% of all iPhones run iOS 26. The Shortcuts-power-user audience skews further toward current OS, and iOS 26 gives us the cleanest AppIntents surface. |
| Devices | iPhone only for v1 (iPad post-v1 if demand surfaces) | Reduces QA surface; AppIntents/Shortcuts behavior is consistent on iPhone. |
| Transcription engine | WhisperKit | On-device, Apple Neural Engine accelerated, no cloud dependency. |
| Model | WhisperKit **medium**, bundled | Best balance of accuracy and on-device speed for v1. Bundling avoids first-run download UX. |
| Network | App functions fully offline. | No network calls in the transcription path. |
| Languages | English only for v1 | medium model is multilingual; non-English support is a settings flag we can flip in a point release after v1 QA. |

## 5. v1 Feature Spec

### 5.1 The `Transcribe Speech` App Intent

The headline deliverable. A single AppIntent exposed to Shortcuts.

**Inputs (Shortcut-configurable parameters):**
- `Silence threshold (seconds)` — how long of a silence triggers auto-stop. Default: 2.0s. Range: 0.5–10s. Set to 0 to disable VAD.
- `Show UI` — Bool, default `true`. Covers the full capture lifecycle. When `true`, foreground UI appears during recording (stop button + waveform) **and** during transcription (progress indicator, see §5.5). When `false`, the entire flow runs with only the minimal system indicator (e.g., the orange mic dot) — useful for Shortcuts that want a near-silent capture and don't need visual feedback on processing.
- `Prompt` (optional `String`) — a hint shown in the recording UI ("What's the reminder?"). Cosmetic only; does not affect transcription.

**Output:**
- `String` — the final transcript. Empty string if the recording produced no speech.

**Behavior:**
1. Acquire the recording lock (see §5.3). If a recording is already in progress, the intent throws an error so the calling Shortcut can branch on it.
2. Request mic permission if not granted.
3. If `Show UI = true`, the intent runs in foreground mode (the host Shortcut briefly hands control to Whisper Intent, which presents the recording → processing UI). If `Show UI = false`, the intent runs entirely in the background; the Shortcut does not switch apps.
4. Start recording.
5. Recording ends when **either** the user taps stop **or** VAD detects continuous silence exceeding the threshold.
6. Transcribe the captured audio with WhisperKit medium. UI (if shown) transitions in place to the processing indicator.
7. Return the transcript string. Control returns to the Shortcut.
8. Release the lock.

**Important:** the recording and processing UI are owned by the AppIntent itself. The user does not need to add separate "show UI" steps to their Shortcut — `Transcribe Speech` is a single Shortcut step that handles its own presentation based on the `Show UI` parameter.

**Error modes:**
- Mic permission denied → throw `.permissionDenied`.
- Recording already in progress → throw `.busy`.
- Transcription failure → throw `.transcriptionFailed` with underlying error message.

### 5.2 Invocation contexts

The AppIntent must work regardless of whether Whisper Intent is currently running. iOS launches the app on demand for any AppIntent invocation. Supported invocation surfaces (all inherited from being a well-formed AppIntent, not implemented per-surface):

- Shortcuts app — manual run or scheduled automation.
- Siri voice phrase — "Hey Siri, [user's phrase]" → Shortcut → `Transcribe Speech`.
- Action Button (iPhone 15 Pro and later).
- Home-screen Shortcut icon or widget.
- Lock-screen widget (works with phone locked, *if* the user's Shortcut is configured to allow it).
- Spotlight search.
- Back Tap (Accessibility).
- Focus filters and other automation triggers.

**Cold-start behavior:** the app does not need to be open. iOS spins up Whisper Intent's process when the AppIntent fires and tears it down when the intent returns. With `Show UI = false`, the user may never see the app launch.

**Constraints inherited from iOS:**
- After a reboot, the device must be unlocked at least once before Shortcuts (and therefore any AppIntent driven by one) can execute. This is system-wide, not Whisper Intent's behavior.
- First-ever invocation of `Transcribe Speech` after install must occur with `Show UI = true` so the mic-permission prompt can be shown. After permission is granted, subsequent invocations can run fully in the background. The app's onboarding screen should prime the user to run the intent once in foreground before relying on background invocations.

### 5.3 Recording lock (single-recording invariant)

A process-wide lock ensures only one recording is active at a time. If the intent is invoked while a recording is running, it fails fast rather than queuing. This is the v1 gate — queue/multi-recording behavior is explicitly deferred.

### 5.4 Stop triggers

- **Tap to stop** — primary stop control in the foreground UI. Always available when UI is shown.
- **Voice Activity Detection (VAD)** — auto-stop after N seconds of detected silence. Threshold is per-invocation (configured on the AppIntent). VAD must not stop the recording during the first ~0.5s (avoids cutting off the moment the user starts speaking).
- **Max-duration cap (if necessary)** — see §5.4.1.

#### 5.4.1 Maximum recording length

The product preference is "as long as feasible." However, iOS imposes hard limits on background execution time, and AppIntent invocations with `Show UI = false` (§5.1) run in that background context. If technical investigation (TDD §13, spike #3) shows a recording length beyond which reliability degrades, **a hard cap is acceptable** — but only if it is communicated clearly to the user in every place they encounter it:

- App Store description — explicit numeric limit ("Records up to N minutes per invocation").
- AppIntent description shown in the Shortcuts editor — same limit, same wording.
- In-app onboarding screen — same limit, called out plainly.
- Recording UI — an elapsed-time counter (already in §5.5) plus a visual indicator (color shift, subtle warning) as the recording approaches the cap.
- Cap-reached behavior — the recording stops automatically as if the user tapped stop. The transcript is still returned. No data is lost.

**v1 process for setting the cap:**
1. Spike #3 measures the safe background execution budget on the medium model.
2. The cap is set to a round, memorable number (e.g., 60s, 2 min, 5 min) at or below that budget.
3. The chosen number is reflected in *all* user-facing surfaces above before launch.
4. If a future iOS release or WhisperKit improvement raises the budget, the cap can be lifted in a point release.

If the spike confirms no practical cap is needed even in the background context, this section becomes "no cap" and the user-facing copy is simplified accordingly. Either outcome is acceptable — the requirement is honesty, not unlimited length.

### 5.5 Recording UI (foreground)

Minimal, system-feeling. When the AppIntent runs with `Show UI = true`:
- Sheet or full-screen modal presented over whatever launched the Shortcut.
- Large stop button.
- Live waveform or level meter (cheap, just gives the user confidence audio is being captured).
- Optional prompt text from the AppIntent parameter.
- Elapsed time counter.
- **Processing progress indicator** after stop — see §5.6.

### 5.6 Processing progress indicator (v1 scope)

Once recording stops, WhisperKit needs time to transcribe. On a medium model with a long recording, this is not instant. A processing progress indicator is **in v1 scope** as part of the foreground UI gated by the `Show UI` AppIntent parameter (§5.1).

When `Show UI = true`, the recording sheet transitions in place from the recording state (waveform + stop button) into a processing state (progress indicator) without dismissing — the user sees one continuous UI from "tap stop" through "transcript returned." When `Show UI = false`, no processing indicator is shown; the Shortcut just blocks on the AppIntent until the transcript is ready.

**Decision (S1, 2026-05-23):** v1 ships an **indeterminate** spinner with phase labels. WhisperKit's callbacks are frequent enough to prove the app is actively working, but they do not expose a reliable total-work denominator for an honest determinate 0...1 progress bar. A determinate bar remains a v2 candidate if a future WhisperKit API or deeper adapter work exposes trustworthy progress fractions.

### 5.7 Permissions

- Microphone access — required, requested on first AppIntent invocation.
- Speech Recognition — not required (WhisperKit doesn't use Apple's `SFSpeechRecognizer`).
- No other permissions.

### 5.8 Dismiss & re-entry behavior

The AppIntent-presented UI (§5.5, §5.6) is dismissible — the user can swipe it away, switch apps, or lock the phone mid-recording or mid-transcription.

**Behavior contract:**
- Dismissing the UI does **not** cancel the recording or transcription. `perform()` continues running in the background, and the transcript is still returned to the calling Shortcut when complete.
- iOS does not re-present a dismissed AppIntent UI. To let the user check on an in-flight session, the **app itself** must expose a re-entry surface.

**v1 implementation:**
- Recording and transcription state live in a single shared `TranscriptionSession` service (not owned by any view).
- Both the AppIntent UI and the main app root view subscribe to that service.
- When the user opens Whisper Intent from springboard:
  - If a session is in flight, the root view shows the same recording/processing UI as the AppIntent (stop button or progress indicator, as appropriate).
  - If no session is in flight, the root view shows the normal landing screen (settings + about).
- When a session completes while the app is foregrounded via the re-entry path, the UI shows the resulting transcript briefly and then returns to the normal landing screen. The transcript is **not** persisted (§7).

This makes dismissal safe: the user never loses work, and never lands in a confusing "where did my recording go?" state.

### 5.9 Settings (app-level, outside the AppIntent)

A simple in-app settings screen:
- Default silence threshold (used when an AppIntent invocation doesn't specify one).
- ~~Toggle: "Show recording UI by default."~~ **Dropped in M5 (2026-05-25).** AppIntent `@Parameter(default:)` is static and can't read `UserDefaults` at parameter-definition time, so the toggle would have had no effect on the Shortcuts editor default. Honoring it at runtime would silently contradict the visible parameter UI. Revisit if a future AppIntents API exposes a dynamic default.
- About / version / WhisperKit attribution.

Settings are intentionally sparse. The AppIntent parameters carry the per-invocation config; the settings screen exists only for defaults and attribution.

## 6. Shortcuts Integration Examples (illustrative — not shipped)

The app ships no pre-built shortcuts, but the README and App Store screenshots can show patterns like:

- **"New Reminder"** — Shortcut runs `Transcribe Speech` → pipes output into `Add New Reminder`.
- **"Quick Note"** — Shortcut runs `Transcribe Speech` (UI hidden) → appends to a Note.
- **"Send to Slack via Webhook"** — Shortcut runs `Transcribe Speech` → `Get Contents of URL` POST to a webhook.

These exist as documentation only.

## 7. Privacy & Data Handling

- All audio and transcription stays on-device. No audio leaves the phone.
- No transcripts are persisted by Whisper Intent itself. The transcript exists in memory long enough to be returned to the calling Shortcut, then is released.
- No analytics, no third-party SDKs in v1.
- Crash reporting: Apple's built-in crash reporting only, gated by the user's system-level opt-in.

App Store privacy nutrition label target: "Data Not Collected."

## 8. Success Criteria

This is an enthusiast tool, so traditional DAU/MAU metrics are weak signals. Better signals for v1 success:

- **AppIntent reliability:** <0.5% intent-failure rate (excluding `permissionDenied` and `busy`, which are expected) across the first 1,000 invocations in TestFlight.
- **Transcription quality:** subjective — the medium model should produce transcripts a power user finds acceptable for task-capture use cases (reminders, notes, messages). Validated via TestFlight feedback, not a formal benchmark.
- **Time-to-transcript:** for a 10-second utterance, time from "stop" to "transcript returned to Shortcut" should be under 3 seconds on an iPhone 14 / A16 or newer.
- **App Store reviews:** absence of "this app doesn't do anything" reviews. The marketing must successfully set the expectation that Whisper Intent is a *building block*, not a finished product.

## 9. v2+ Roadmap (non-binding)

Listed in rough priority order, no commitments:

1. **Processing UI with pause/resume** — extend the recording UI to allow pausing mid-recording and resuming, with a unified "processing" view that shows transcription progress. This is the headline v2 feature.
2. **Determinate progress bar** — promoted from indeterminate, if v1 had to ship indeterminate due to WhisperKit callback limitations.
3. **Structured AppIntent output** — second AppIntent variant returning a struct (transcript, duration, confidence, segment timestamps) for advanced Shortcuts.
4. **Model picker + downloader** — let users choose tiny/base/small/medium/large with on-demand download.
5. **Recording history** — opt-in local history of transcripts (off by default; user-controlled retention).
6. **Multi-language support** — settings flag to choose transcription language or auto-detect.
7. **iPad support.**
8. **`StopRecording` AppIntent** — a second intent that stops an active recording, callable from a separate Shortcut step.

## 10. Open Questions

- ~~**Progress bar fidelity:** progress indicator is locked in for v1, but determinate vs indeterminate depends on WhisperKit's progress callback granularity for the medium model. Needs a spike before UI design is finalized.~~ **Resolved 2026-05-23.** S1 chose an indeterminate spinner with phase labels for v1; determinate progress remains a v2 candidate.
- **Bundle size impact on conversion:** the medium WhisperKit model adds ~1.5 GB to install size (exact number pending S4). Bundling vs ODR is decided (bundling — TDD §6.1), and S4 will validate the numbers. The remaining question is purely empirical: does the download size deter App Store installs? Only answerable post-launch via App Store Connect conversion data. Carried into post-launch monitoring rather than gating v1.
- **Background behavior:** if iOS suspends the app mid-recording (e.g., user switches away during a long capture), does the recording survive? v1 acceptable answer is "recording ends cleanly and returns whatever was captured." Needs validation.
- ~~**App name conflicts:** confirm "Whisper Intent" doesn't collide with existing App Store apps or trademarks.~~ **Resolved 2026-05-22.** No App Store collision. OpenAI holds a USPTO trademark on `WHISPER` covering speech-recognition software; shipping as "Whisper Intent" anyway, accepting the same posture WhisperKit operates under. See MILESTONES.md cross-cutting tracks for full reasoning.
- ~~**Pricing:** free, paid up-front, or free + tip jar? Out of scope for this draft; revisit before submission.~~ **Resolved 2026-05-22.** Free. No IAP, no tip jar in v1. Revisit if maintenance burden materially exceeds expectations post-launch.

---

*End of draft. Next steps: validate the WhisperKit medium-model progress-callback question (drives §5.5), then move to a technical design doc covering AppIntent lifecycle, the recording-lock implementation, and audio session configuration.*
