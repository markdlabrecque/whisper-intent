# M6 — Manual Test Plan (Hardening + TestFlight)

**Milestone:** [M6 — Hardening + TestFlight beta](MILESTONES.md)
**Status:** Draft v0.1
**Last updated:** 2026-05-25
**Prerequisite:** M5 test plan (`docs/M5-test-plan.md`) walked at least once.
**Blocked-on:** Spike S3 must close before this plan can be fully executed. Sections marked **[S3]** require the measured cap.

M6 is the hardening pass that produces a TestFlight build. The bulk of the matrix is device-time on real iPhones (oldest supported and newest supported), not code work. The autonomous code/doc work landed during M6 development is verified in §1; the rest is the on-device gauntlet.

---

## Section 1 — Build-time / static checks

| # | Check | Expected | Pass/Fail |
|---|---|---|---|
| 1.1 | `make app-build` (Debug). | Clean exit 0. |  |
| 1.2 | `xcodebuild ... -configuration Release build`. | Clean exit 0. Validates that the `#if DEBUG` gates around the spike harnesses don't leave dangling references in release builds. |  |
| 1.3 | `make test`. | All unit tests pass. |  |
| 1.4 | `make lint`. | SwiftFormat + SwiftLint clean. |  |
| 1.5 | Inspect the Release archive's Shortcuts intents (Xcode → Product → Archive → exported `.ipa` → confirm via "App Intents Browser" or by installing the release IPA on a device and opening Shortcuts → "Apps" list). | Only **Transcribe Speech** is visible. `Debug Hello Foreground Spike` is **not** present. |  |
| 1.6 | Confirm the install size of the release IPA against S4's number (1.4 GB signed `.app`). | Within ±100 MB of the S4 baseline; flag any larger drift. |  |

## Section 2 — TDD §11 manual matrix on two devices

Run every row on both the newest supported iPhone and the oldest supported iPhone (whichever line is decided when S3 closes). Mark device explicitly per row.

| # | Step | Newest device | Oldest device |
|---|---|---|---|
| 2.1 | Invoke via Siri voice phrase. | | |
| 2.2 | Invoke via Action Button. | | |
| 2.3 | Invoke via Shortcuts app. | | |
| 2.4 | Invoke from lock screen widget. | | |
| 2.5 | Dismiss sheet mid-recording, re-open from springboard. RootView mirrors live state. | | |
| 2.6 | Dismiss sheet mid-transcription, re-open from springboard. RootView shows processing UI. | | |
| 2.7 | Phone-call interruption mid-recording (call from another device). Surfaces `.interrupted`. | | |
| 2.8 | Cold-boot, unlock, immediately trigger Siri phrase (post-reboot first-unlock constraint). | | |
| 2.9 | First-run onboarding from a fresh install: three screens, "Record a test" path, "Skip" path. | | |
| 2.10 | Settings persistence: change silence threshold, force-quit, relaunch. | | |
| 2.11 | "Show onboarding again" from Settings re-presents the flow. | | |
| 2.12 | Post-onboarding mic-permission denial → deep-link to Settings → Whisper Intent → Microphone. | | |
| 2.13 | `showUI = false` after fresh force-quit (TDD §9 caveat). Either success or clean `permissionDenied`. | | |

## Section 3 — Memory and performance

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 3.1 | **[S3]** Run a 5-minute recording at the cap on the oldest supported device, with Xcode memory profiling attached. | RAM stays under `os_proc_available_memory()` safety threshold throughout. Transcript returns successfully. |  |
| 3.2 | Repeat 3.1 back-to-back twice without unplugging. Compare timings. | Second run within 20% of first. No thermal-throttling cliff. |  |
| 3.3 | Time-to-transcript for a 10s utterance on the **newest** device (per PRD §8 success criterion). | <3s from stop to transcript returned. |  |
| 3.4 | Time-to-transcript for a 10s utterance on the **oldest** device. | Documented baseline. No PRD target on oldest. |  |

## Section 4 — App Store Connect prep

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 4.1 | App Store Connect record created (deferred from M0). Bundle ID `com.marklabrecque.whisperintent` claimed. | Record exists. |  |
| 4.2 | **[S3]** `{MAX_DURATION}` replaced everywhere: `RecordingLimits.maxRecordingSeconds`, `docs/app-store-listing.md` Description + Recording Length sections, `docs/onboarding-copy.md` Screen 3, `App/WhisperIntent/Views/OnboardingView.swift` (testScreen). | All occurrences updated to the measured cap. `grep -ri "MAX_DURATION"` returns no live placeholders. |  |
| 4.3 | Privacy policy URL is live and reachable. | URL in App Store Connect resolves to `docs/privacy-policy.md` content (or a hosted equivalent). |  |
| 4.4 | Five screenshots produced per `docs/app-store-listing.md` §Screenshots. | 6.7" iPhone size, in stated order. |  |
| 4.5 | App icon at all required sizes. | Asset catalogue passes Xcode validation. |  |
| 4.6 | "App Review notes" copied from `docs/app-store-listing.md` into App Store Connect. | Field populated. |  |

## Section 5 — TestFlight beta

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 5.1 | Upload the first TestFlight build via Fastlane. | Build is processed by Apple. |  |
| 5.2 | Internal testing: install on at least two devices, run the M5 test plan against the TestFlight build. | All M5 sections pass. |  |
| 5.3 | Invite 10–25 external testers (Shortcuts power users). | Invites accepted. |  |
| 5.4 | Collect feedback for 1–2 weeks via the structured form (TBD). | Feedback recorded. |  |
| 5.5 | Monitor: `permissionDenied` rate, `busy` rate, `transcriptionFailed` rate per PRD §8. | All under 0.5% combined (excluding the expected `permissionDenied`/`busy` cases). |  |
| 5.6 | No P0 crashes for the duration of the beta. | Apple Crash Reports clean. |  |

---

## Sign-off

| Stage | Reviewer | Date | Outcome |
|---|---|---|---|
| Section 1 (static checks) |  |  |  |
| Section 2 (matrix, newest device) |  |  |  |
| Section 2 (matrix, oldest device) |  |  |  |
| Section 3 (memory + performance) |  |  |  |
| Section 4 (App Store prep) |  |  |  |
| Section 5 (TestFlight beta) |  |  |  |

Exit criterion: **all sections green; no P0 open; beta surfaced no common failure modes for at least one continuous week.**
