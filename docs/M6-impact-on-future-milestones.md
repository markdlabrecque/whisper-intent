# M6 — Impact on Future Milestones

**Milestone:** [M6 — Hardening + TestFlight beta](MILESTONES.md)
**Status:** Draft v0.1
**Last updated:** 2026-05-25

What the M6 autonomous slice changed, what it deferred, and what it owes M7 (GA) and the still-open Spike S3. Companion to [M5-impact-on-future-milestones.md](M5-impact-on-future-milestones.md).

---

## 1. What landed in the M6 autonomous slice

Code:
- Debug surfaces (`DebugSpikesView`, `DebugRecordingView`, `DebugHelloView`, `DebugHelloIntent`) and the `helloPresentation` plumbing in `AppEnvironment` are now gated behind `#if DEBUG`. Release builds compile clean, and `DebugHelloIntent` no longer appears in the Shortcuts editor for users.

Docs:
- PRD §5.9 and TDD §8.3 mark the "Show recording UI by default" toggle as dropped in M5, with rationale.
- TDD §11 smoke-test matrix extended with the M5 surfaces and the TDD §9 force-quit caveat.
- Privacy policy stale "Show UI default" bullet removed.
- M6 test plan (`docs/M6-test-plan.md`) created with sections explicitly marked `[S3]` where they depend on the spike.

## 2. What M6 still owes (deferred to a future session)

These are M6 bullets in `MILESTONES.md` that need device time, an external system, or a closed S3:

| Item | Why deferred | Where blocked |
|---|---|---|
| Two-device manual smoke matrix (TDD §11) | Requires real iPhones (newest + oldest). | Device time. |
| 5-minute memory profiling at the cap | Requires a real recording-cap and Xcode device profiling. | **S3 closure** + device time. |
| App Store Connect record creation | Apple ID + browser. | External tooling. |
| TestFlight upload (first build) | Needs an App Store Connect record + a real signed IPA. | External tooling + the M0-deferred App Store Connect record. |
| TestFlight invite list + structured feedback channel | People work. | External. |
| Reliability targets monitoring during beta | Requires the beta to be live for 1–2 weeks. | Calendar. |
| App icon at all required sizes | Design work (M0 noted "real icon to be added before M6"). | Design. |
| Final screenshots per `docs/app-store-listing.md` §Screenshots | Need device builds + the production cap surfaced in the UI. | **S3 closure** + device. |

`docs/M6-test-plan.md` enumerates these so the next M6 session can resume cleanly.

## 3. Hard dependencies on Spike S3 (still open)

S3 has not been run. Several M6 deliverables culminate in the cap value:

| Artifact | Action when S3 closes |
|---|---|
| `RecordingLimits.maxRecordingSeconds` | Replace placeholder 600s with the measured cap. |
| `OnboardingView.testScreen` body | Re-insert the cap sentence omitted in M5. |
| `app-store-listing.md` Description + Recording Length | Substitute every `{MAX_DURATION}`. |
| App Store screenshots | Produce against a build with the real cap. |
| Memory/performance profiling | Profile against the real cap, not the placeholder. |

If S3 reveals a cap requiring scope changes (e.g., dropping `showUI = false` support), the M6 test plan and metadata draft both need revision before the TestFlight upload.

## 4. M7 (GA) inheritance from M6

When M7 opens, the following M6 artifacts feed directly into App Store submission:

- The final `app-store-listing.md` (placeholders resolved).
- The screenshots produced in §2.
- The privacy policy hosted at a stable URL.
- App Review notes from `app-store-listing.md`.
- Reliability/crash data from the TestFlight beta — informs the "What's New" copy and any last-minute hold-backs.

M7's own code work is minimal: post-launch monitoring and the marketing README update. The main M7 risk is App Store review pushback on the "no out-of-box functionality" framing (per `MILESTONES.md` risk register) — the listing's "Whisper Intent is a building block, not a finished app" lede is the mitigation.

## 5. Implementation notes worth carrying forward

- The `#if DEBUG` gating is **file-level** for the debug views and intent, and **block-level** inside `AppEnvironment.swift` and `RootView.swift`. If a v2 wants to add a TestFlight-only debug menu, the cleaner pattern is a separate target or a runtime flag — extending `#if DEBUG` further will eventually conflict with TestFlight builds (which are Release configuration).
- The shipped attribution string in `SettingsView` is a plain link to the WhisperKit GitHub. App Store reviewers occasionally ask for an explicit license attribution; if that comes up at review, add the WhisperKit MIT license text under About.

## 6. Quick checklist for the next M6 session

- [ ] S3 closed and `RecordingLimits.maxRecordingSeconds` updated.
- [ ] Onboarding Screen 3 cap sentence restored.
- [ ] App Store listing `{MAX_DURATION}` placeholders resolved.
- [ ] App Store Connect record created.
- [ ] App icon at all required sizes added.
- [ ] `docs/M6-test-plan.md` §1 static checks rerun.
- [ ] §2 matrix run on newest + oldest device.
- [ ] §3 memory profiling on oldest device at the real cap.
- [ ] §4 App Store Connect prep complete.
- [ ] §5 TestFlight upload + beta open for ≥1 week.
- [ ] Privacy policy URL hosted and live.
- [ ] Five screenshots captured at 6.7".
