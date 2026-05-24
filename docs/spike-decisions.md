# Whisper Intent — Spike Decision Record

**Companion to:** [PRD.md](PRD.md), [TDD.md](TDD.md), [MILESTONES.md](MILESTONES.md)

A single rolling record of the four pre-implementation spikes from TDD §13. Each entry below summarises the decision, the evidence behind it, and any remaining follow-ups. The per-spike working documents have been removed now that the decisions are landed; their content is consolidated here.

For open spikes (currently S3), the working document is still in `docs/spikes/` and gets folded into this record once the decision is made.

---

## S1 — WhisperKit progress-callback granularity

- **Status:** Closed (M2)
- **Owner:** Mark Labrecque
- **Completed:** 2026-05-23
- **Related code:** `Packages/WhisperIntentCore/Sources/WhisperIntentCore/Transcription/TranscriptionProgress.swift`, `SpikeHarness/SpikeS1Harness.swift`

### Question

Does WhisperKit's medium model expose progress callbacks at fine enough granularity to drive a determinate progress bar, or is v1 limited to an indeterminate spinner?

### Decision

**Indeterminate spinner with phase labels in v1.** `TranscriptionProgress.phase(_:)` is the active case; the `.progress(fraction:)` case was never landed. Determinate progress is deferred to v2 only if a later WhisperKit API or deeper adapter work exposes a reliable total-work denominator.

### Evidence

Harness logged every progress + segment + state callback on the bundled medium model. Two synthetic samples:

| Sample | Total transcription time | Progress callbacks | Frequency | Mean interval | Segment callbacks |
|---|---:|---:|---:|---:|---:|
| 30 s | 4.057 s | 104 | 25.636 Hz | 0.034 s | 1 |
| 300 s | 25.000 s | 633 | 25.320 Hz | 0.039 s | 7 |

Progress callbacks fire at ~25 Hz on both inputs with no degradation on longer audio. Payload exposes `tokens.count` and `windowId` — enough to *show* activity, but **not** a stable total-work denominator for a 0...1 bar. Segment callbacks are far too coarse to drive smooth progress.

Test device was a recent iPhone; raw timing numbers above are not minimum-spec targets — S3 covers oldest-device runtime budget.

### Propagated changes

- TDD §6.3 — narrowed `TranscriptionProgress` to the chosen case.
- PRD §5.6 — replaced the "determinate vs indeterminate" paragraph with the decided UI.

### Open follow-ups

- M5 wireframes for `RecordingSheet` processing state must use a spinner + phase label, not a determinate bar.

---

## S2 — iOS 26 AppIntents foreground-escalation API

- **Status:** Closed (M2)
- **Owner:** Mark Labrecque
- **Completed:** 2026-05-23
- **Test device:** iOS 26.4.2, Xcode 26.5 (iPhone 15 Pro+ class)
- **Related code:** `App/WhisperIntent/Intents/DebugHelloIntent.swift`, `App/WhisperIntent/Views/DebugHelloView.swift`, `App/WhisperIntent/AppEnvironment.swift`

### Question

Can a single AppIntent, declared with `supportedModes: [.background, .foreground(.dynamic)]`, programmatically escalate to a foreground UI when its `showUI` parameter is true on iOS 26 — cleanly, without entitlement issues, and across all invocation surfaces?

### Decision

**Option B confirmed.** Single `TranscribeSpeechIntent` declared with `supportedModes: [.background, .foreground(.dynamic)]`. Foreground presentation via `continueInForeground(_:)` guarded by `systemContext.currentMode.canContinueInForeground`. Background path via the intent's own short-circuit when `showUI = false`. No documented limitations required for v1 release notes.

### Evidence

`DebugHelloIntent` validated across all seven invocation surfaces from TDD §5.2 with both `showUI` values:

| Surface | `showUI = true` | `showUI = false` |
|---|---|---|
| Shortcuts app (manual Play) | ✅ pass | ✅ pass |
| Siri voice — unlocked | ✅ pass | ✅ pass |
| Siri voice — locked | ✅ pass | ✅ pass |
| Action Button | ✅ pass | ✅ pass |
| Home-screen Shortcut icon | ✅ pass | ✅ pass |
| Lock-screen Shortcuts widget | ✅ pass | ✅ pass |
| Spotlight | ✅ pass | ✅ pass |
| Back Tap | ✅ pass | ✅ pass |

**Disambiguating signal:** the returned string encodes which branch of `perform()` ran — `"... Returned from IntentMode.background."` for the short-circuit, `"... Returned after foreground UI."` for the escalation. iOS surfaces some kind of app indicator (Dynamic Island, Siri's "Working…" chrome) while any background AppIntent runs; this is *not* foreground continuation and the returned-string check proved it on every surface.

### Propagated changes

- TDD §7.1 — code snippet pinned to `supportedModes: [.background, .foreground(.dynamic)]` (replaced deprecated `openAppWhenRun`).
- TDD §7.2 — Option B confirmed as the architecture; deprecated `ContinueInAppIntent` reference removed.
- PRD §5.1 — no change required (single-intent surface preserved).
- PRD §6 — example Shortcuts wording unchanged.

### Known issues recorded for M3 / M6

- **Force-quit + `.foreground(.dynamic)` privileged-API regression.** AppIntents declared with `.foreground(.dynamic)` have been reported by other developers to lose access to privileged system features (Core Location cited) when the host app has been force-quit before invocation. Not exercised by `DebugHelloIntent` (no privileged APIs). Re-verify during M6 hardening that `TranscribeSpeechIntent` with `showUI = false` after a fresh force-quit either acquires mic permission cleanly or fails with `SessionError.permissionDenied` (not a silent hang). Captured in TDD §9.
- **Siri invocation pipeline flakiness.** Documented on iOS 18.x with at least one open Feedback Assistant ticket (`FB16978432`). Not reproduced on iOS 26.4.2 in our results, but worth re-checking during M6 if Siri-path tests behave inconsistently.

### Open follow-ups

- M6 hardening: force-quit verification for `TranscribeSpeechIntent` mic-permission path.

### Sources

- [supportedModes — Apple Developer Documentation](https://developer.apple.com/documentation/appintents/appintent/supportedmodes)
- [IntentModes — Apple Developer Documentation](https://developer.apple.com/documentation/appintents/intentmodes)
- [ForegroundContinuableIntent — Apple Developer Documentation](https://developer.apple.com/documentation/appintents/foregroundcontinuableintent) (deprecation note)
- [needsToContinueInForegroundError — Apple Developer Documentation](https://developer.apple.com/documentation/appintents/foregroundcontinuableintent/needstocontinueinforegrounderror(_:continuation:))
- [Siri not calling AppIntents — Apple Developer Forums](https://developer.apple.com/forums/thread/757298)
- [Siri Shortcuts confirmation / recognition issues — Apple Developer Forums](https://developer.apple.com/forums/thread/775638)

---

## S3 — Background execution budget & max-duration cap

- **Status:** Open (M4)
- **Working document:** [docs/spikes/S3-background-budget.md](spikes/S3-background-budget.md)

Pending M3 close-out. The working document carries the method, sample-duration ladder, and exit criteria. Once the spike runs and a decision is recorded, it gets folded into this file the same way S1, S2, and S4 were.

The cap value chosen by S3 propagates into:

- TDD §7.3 (implementation)
- PRD §5.4.1 (product copy)
- App Store description, AppIntent description, onboarding screen, recording UI warning thresholds

---

## S4 — WhisperKit medium install size on a real device

- **Status:** Closed (M1, provisional — thinned/installed numbers deferred to M6)
- **Owner:** Mark Labrecque
- **Completed:** 2026-05-22
- **Related code:** `App/WhisperIntent/Resources/Models/openai_whisper-medium/`, `project.yml` (folder-reference resource entry)

### Question

What is the actual on-device install size, and the App Store download size, of a Whisper Intent build that bundles the WhisperKit medium model?

### Decision

**Proceed with bundling (Option A).** PRD §4's "no first-run download" commitment stands. Local fat IPA is 1.35 GB, comfortably under Apple's 4 GB uncompressed ceiling. If M6 TestFlight numbers come in dramatically worse than expected (e.g. >2 GB installed or App Store review pushback), the fallback is a smaller model variant — **not** On-Demand Resources. ODR would contradict the "no first-run download" promise that anchors the product.

### Evidence

| Metric | Value |
|---|---|
| Local IPA file size | **1.35 GB** (1,413,707,355 bytes) |
| Signed `.app` bundle on disk | **1.4 GB** (TextDecoder 872 MB + AudioEncoder 586 MB + binary 2.5 MB) |
| App Store download size (A16 thinned) | _pending TestFlight upload — M6_ |
| App Store download size (A17 thinned) | _pending TestFlight upload — M6_ |
| Installed size on device | _pending TestFlight install — M6_ |
| Triggers iOS large-cellular-download confirmation prompt | **yes** (1.35 GB; modern iOS no longer hard-caps but does prompt) |
| Against Apple's 4 GB uncompressed ceiling | ~35 % of ceiling |

Measurement method: `xcodebuild archive` on Release, generic/platform=iOS, code-signed (Team `QS946Z5WWB`); `xcodebuild -exportArchive` with `method=development`, `thinning=<none>` (fat IPA, no per-device thinning). Number is therefore an **upper bound** on what the App Store will deliver.

App binary itself is 2.5 MB; the rest is the two Core ML model directories. No low-effort bundle reductions available — meaningful shrink would require switching to a smaller/quantized model, which would change S1's transcription quality input. Out of scope for v1.

### Packaging note (resolved 2026-05-22)

Initial archive flattened the `.mlmodelc` directories to the `.app` bundle root because XcodeGen's `sources: App/WhisperIntent` recursively claimed the model directory as a group, overriding the `type: folder` resource entry. Fixed by:

1. Adding `Resources/Models/openai_whisper-medium` and its README to the sources `excludes`.
2. Declaring the model as a folder-reference source with `buildPhase: resources` and `type: folder`.

Verified the model now lives at `<bundle>/openai_whisper-medium/` with directory structure preserved. Install-size number unchanged.

### Propagated changes

- TDD §6.1 — Option A confirmed.
- MILESTONES.md risk register — "install size too large" downgraded from open to monitoring; re-evaluate at M6.

### Open follow-ups

- **M6:** Record App Store Connect thinned download size (A16, A17) and on-device installed size.
- **M6:** Decide whether App Store metadata should call out the ~1+ GB install size + Wi-Fi recommendation so first-install on cellular isn't a surprise.

### Sources

- [Maximum Build File Sizes — Apple Developer](https://developer.apple.com/help/app-store-connect/reference/maximum-build-file-sizes/)
