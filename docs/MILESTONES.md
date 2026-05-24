# Whisper Intent — v1 Milestone Plan

**Status:** Draft v0.1
**Last updated:** 2026-05-22
**Companion to:** [PRD.md](PRD.md), [TDD.md](TDD.md)

Sequences the four technical spikes from TDD §13 into a delivery plan, then carries through to v1 GA. Each milestone has a single clear exit criterion. No date estimates are committed here — durations are rough effort sizing only.

---

## Dependency analysis (why the order is what it is)

| Spike | Needs | Blocks |
|---|---|---|
| **S4** Install size | Just WhisperKit medium model in a bundle | Packaging decision; nothing else gates on it. |
| **S1** Progress callback granularity | WhisperKit medium loadable + a sample audio file | UI design for processing indicator (PRD §5.6) |
| **S2** AppIntents foreground-escalation API | iOS 26 SDK, minimal AppIntent skeleton | One-intent vs two-intent architecture (TDD §7.2) |
| **S3** Background execution budget | AppIntent skeleton + WhisperKit pipeline + audio capture | Max-duration cap value (PRD §5.4.1); all user-facing copy |

Ordering rationale:
- **S4 first** — cheapest, no dependencies, gates a packaging decision that affects every subsequent build (install size matters for TestFlight upload time, App Store review).
- **S1 second** — validates WhisperKit integration end-to-end on the chosen model. The harness built for S1 is reused as the basis for the real transcriber.
- **S2 third** — AppIntent skeleton can be built in parallel with S1's audio side once WhisperKit is confirmed loadable.
- **S3 last** — needs both halves (AppIntent context + WhisperKit pipeline) to measure realistic background budget. Running it any earlier produces numbers that don't reflect the real workload.

S1 and S2 can be done in parallel by one person who's comfortable context-switching, or by two people. They're treated as one milestone (M2) for simplicity.

---

## M0 — Project setup

**Effort:** S (1–2 days)

Bare scaffolding to make subsequent work measurable.

- [x] Xcode project: app target + `WhisperIntentCore` Swift package. _(Project generated via XcodeGen — `project.yml` checked in, `.xcodeproj` is generated.)_
- [x] iOS 26 deployment target, Swift 6 strict concurrency on.
- [x] WhisperKit dependency added, pinned version. _(0.18.0, exact pin.)_
- [x] CI pipeline (GitHub Actions): build + test on every push. _(`.github/workflows/ci.yml`. App-target job commented out until GitHub runners ship Xcode 26.)_
- [x] `docs/spikes/` directory created with a template for spike reports. Closed-spike findings are consolidated into [docs/spike-decisions.md](spike-decisions.md); per-spike files exist only while a spike is in progress.
- [x] App icon placeholder, bundle ID registered. _(Bundle ID `com.marklabrecque.whisperintent` registered with Apple Developer. App icon directory exists; real icon to be added before M6.)_
- [ ] ~~App Store Connect record created.~~ **Deferred to M6.** Not needed until TestFlight uploads start. Reopening at M6.

**Exit:** `xcodebuild` builds a do-nothing app that launches to an empty `RootView` on a real device.

**Status (2026-05-22): Closed.** SwiftPM package builds and tests pass. App target builds via XcodeGen-generated `.xcodeproj` and launches on device showing the stub `RootView`. M0 exit criterion met. App Store Connect record deferred to M6.

---

## M1 — Spike S4: install size

**Effort:** XS (half-day)

- [ ] Bundle WhisperKit medium model files in the app bundle.
- [ ] Build a release IPA.
- [ ] Measure on-device install size on a real iPhone (iOS 26).
- [ ] Compare against App Store Connect's reported download size after a TestFlight build.
- [x] Report consolidated into [docs/spike-decisions.md § S4](spike-decisions.md).

**Exit:** documented install size with two numbers (uncompressed app bundle, App Store download size). Decision recorded: stick with bundled (TDD §6.1 Option A) or fall back to ODR.

**Gate:** if the install size is so large that TestFlight or App Store distribution is impractical, revisit ODR before proceeding. Otherwise green-light M2.

---

## M2 — Spikes S1 + S2 in parallel

**Effort:** M (3–5 days combined)

### S1 — Progress callback granularity

- [x] Build a minimal command-line-ish harness inside the app: load WhisperKit medium, transcribe a bundled 30-second sample, log every progress callback with timestamp + payload.
- [x] Repeat with a bundled 5-minute sample to check whether granularity degrades on longer inputs.
- [x] Capture: callback frequency, payload structure, whether segment indices are exposed.
- [x] Report consolidated into [docs/spike-decisions.md § S1](spike-decisions.md).

**Exit:** decision recorded as either:
- "Determinate progress bar in v1, driven by `<specific signal>`," or
- "Indeterminate spinner with phase labels in v1; determinate bar deferred to v2."

### S2 — AppIntents foreground-escalation API

- [x] Build a minimal `HelloIntent` that, with a `showUI: Bool` parameter, either opens the app to a "hello" scene or returns a string from background.
- [x] Validate behavior via:
  - Manual run from the Shortcuts app.
  - Siri voice phrase.
  - Action Button bound to a Shortcut.
  - Lock-screen widget.
  - (Also exercised: home-screen icon, Spotlight, Back Tap.)
- [x] Confirm the foreground-escalation API works as expected on iOS 26 (no deprecation, no entitlement gotchas).
- [x] Report consolidated into [docs/spike-decisions.md § S2](spike-decisions.md).

**Exit:** decision recorded as either:
- "Single AppIntent with programmatic foreground escalation works — TDD §7.2 Option B is feasible," or
- "Foreground escalation has unworkable constraints; v1 ships two AppIntents instead."

**Gate:** either outcome is acceptable. Update TDD §7.2 to reflect what was learned. Green-light M3.

---

## M3 — Core domain implementation

**Effort:** M (5–8 days)

With spikes settled, the design in TDD §3–§6 is implementable.

- [x] `TranscriptionSession` actor with the full state machine.
- [x] `RecordingLock` semantics validated via unit tests.
- [x] `AudioRecorder` over `AVAudioEngine`: 16 kHz mono PCM, `.measurement` mode, route/interruption handling.
- [x] `VoiceActivityDetector` (energy-based) with 500ms warmup and configurable threshold.
- [x] `WhisperKitTranscriber` adapter that emits the `TranscriptionProgress` enum shape decided in S1.
- [x] Unit test coverage of session state transitions with mocked recorder and transcriber.

**Exit:** `WhisperIntentCore` can record a sample audio file from a real mic, transcribe it via WhisperKit medium, and emit a final transcript string — all driven by `TranscriptionSession`, with progress callbacks flowing through the state stream. Verified on a real device via a temporary in-app debug button. No AppIntent yet.

**Status (2026-05-24): Closed.** On-device verification on iPhone (iOS 26.4.2) walked every section of the M3 test plan with `pass` on all rows — golden-path short utterance, ~60 s long utterance, phone-call interruption surfacing `failed(interrupted)`, AirPods route-loss surfacing `failed(interrupted)`, permission-denial path, backgrounding, memory flat across 5 consecutive cycles, no console errors. 22 unit tests green. `DebugRecordingView` lives behind the spike harness screen and is the in-app debug button required by the exit criterion; it's marked for removal in M6 alongside the spike harnesses. One UX tweak landed during testing: the level meter now uses a dB-style remap of the raw RMS so the bar responds across the full range of voice (see TDD §8.1 for the formula M5 should reuse).

---

## M4 — Spike S3: background execution budget

**Effort:** S (1–2 days)

Run *after* M3 because we need the real audio + transcription pipeline to measure a realistic budget.

- [ ] Wire a minimal `TranscribeSpeechIntent` to drive `TranscriptionSession` with `showUI = false`.
- [ ] Invoke it from a test Shortcut on a real iPhone, with progressively longer recordings (10s, 30s, 60s, 2min, 5min).
- [ ] Identify the duration at which iOS terminates the background invocation or audible degradation appears.
- [ ] Run on the **lowest-spec supported device** (oldest iPhone still on iOS 26) — older hardware has tighter budgets.
- [ ] Repeat with `showUI = true` to confirm the foreground path is not similarly constrained.
- [ ] Report in `docs/spikes/S3-background-budget.md`.

**Exit:** the v1 max-duration cap value is chosen (likely 60s, 2 min, or 5 min) per PRD §5.4.1. The number is recorded and propagated to:
- TDD §7.3 (implementation).
- PRD §5.4.1 (product copy).
- The list of user-facing surfaces that must reflect it (App Store description, AppIntent description, onboarding screen, recording UI warning thresholds).

**Gate:** if the spike reveals the cap must be uncomfortably short (e.g., <30s), revisit product framing with the user before continuing — that may change the value proposition enough to warrant a scope conversation.

---

## M5 — AppIntent + UI surfaces

**Effort:** M (5–7 days)

With the domain working and the cap known, build the user-facing layers.

- [ ] `TranscribeSpeechIntent` per TDD §7.1, using the architecture confirmed by S2.
- [ ] Error mapping (`IntentError`) with user-readable strings.
- [ ] Max-duration cap enforced in `AudioRecorder` (from M4 result).
- [ ] `RecordingSheet` (foreground UI): waveform, stop button, elapsed counter with warning treatment at 80% / 95% of cap, processing indicator (determinate or indeterminate per S1).
- [ ] `RootView` (re-entry surface, PRD §5.8): same state binding, identical visual treatment.
- [ ] `SettingsView`: defaults storage, attribution, version info.
- [ ] First-run onboarding screen: explains the building-block model, calls out the cap, primes the user to grant mic permission.

**Exit:** an end-user can install a TestFlight build, create a Shortcut that calls `Transcribe Speech`, trigger it from Siri or the Action Button, and get a transcript back into their Shortcut. All invocation surfaces from TDD §5.2 work.

---

## M6 — Hardening + TestFlight beta

**Effort:** M (5–7 days, partly elapsed-time-bound by external feedback)

- [ ] Complete the manual smoke test matrix from TDD §11 on at least two devices (newest supported, oldest supported).
- [ ] Phone-call interruption mid-recording: verify clean `.interrupted` failure, no stuck lock.
- [ ] Dismiss-and-reopen flows in every state.
- [ ] Cold-boot, unlock, immediately trigger via Siri (verifies first-unlock constraint behavior).
- [ ] Memory profiling on a 5-minute recording at the cap.
- [ ] App Store metadata draft: description, screenshots, privacy nutrition label ("Data Not Collected"), keywords.
- [ ] Privacy policy page (one short page; on-device only).
- [ ] TestFlight invite list of 10–25 known Shortcuts power users; collect structured feedback for 1–2 weeks.

**Exit:** TestFlight beta has been live long enough to surface any common failure mode. Reliability targets from PRD §8 are tracking on track. No P0 bugs open.

---

## M7 — v1 GA

**Effort:** S (1–3 days, mostly process)

- [ ] App Store submission with final metadata and the cap number reflected in copy.
- [ ] Marketing post / README pointing to example Shortcuts (illustrative only, per PRD §6).
- [ ] Post-launch monitoring of crash reports and review tone for the first week.

**Exit:** Whisper Intent v1 is live on the App Store.

---

## Cross-cutting tracks (run in parallel from M0 onward)

- **Visual design:** icon, screenshots, recording UI polish. Can start in M0; needs to be done by M6.
- **App name conflict check:** ~~quick App Store search + USPTO check. Do in M0; if a conflict exists, rename before M1.~~ **Resolved 2026-05-22.** No App Store collision on "Whisper Intent." OpenAI holds a USPTO trademark on `WHISPER` for speech-recognition software (reg. 97815511); decision is to ship as "Whisper Intent" anyway, accepting the same exposure WhisperKit operates under. Revisit if OpenAI's posture changes or if the app gains material traction.
- ~~**Pricing decision:** punted from PRD. Resolve by M6 (App Store metadata).~~ **Resolved 2026-05-22.** Free, no IAP, no tip jar.
- **WhisperKit version watch:** subscribe to releases. If a significant accuracy or performance update lands during the build, evaluate before locking pre-launch.

---

## Risk register

| Risk | Where it surfaces | Mitigation |
|---|---|---|
| ~~Install size too large for App Store distribution~~ | ~~M1 / S4~~ | **Monitoring (downgraded 2026-05-22):** S4 measured local IPA at 1.35 GB; bundling decision (Option A) confirmed. Thinned App Store numbers deferred to M6 — fallback if those land much worse than expected is a smaller model variant, not ODR. |
| WhisperKit progress callbacks are too coarse | M2 / S1 | Ship indeterminate spinner; revisit in v2 — already an acceptable PRD outcome. |
| Foreground escalation API doesn't work cleanly | M2 / S2 | Ship two AppIntents instead — uglier in Shortcuts but functional. |
| Background cap has to be uncomfortably short | M4 / S3 | Reframe as "designed for quick capture, not long-form" in marketing — or ship without `showUI = false` support in v1 and revisit. Requires scope conversation. |
| Phone-call interruption leaves recording lock stuck | M6 | Already designed for (`.interrupted` error path); verify in QA. |
| App Store review pushes back on "no out-of-box functionality" framing | M7 | Be explicit in description and screenshots: this is a building block for Shortcuts. Reference precedent (Toolbox Pro, Data Jar, etc.). |

---

## Decision log location

Each spike produces a markdown report in `docs/spikes/`. Decisions made during M3–M7 that change PRD or TDD content are made by editing those documents directly with a dated note. No separate ADR system for a project this size.
