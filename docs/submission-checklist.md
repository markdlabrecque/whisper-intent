# App Store Submission — Go/No-Go Checklist

**Status:** Living document
**Last updated:** 2026-05-25
**Companion to:** [MILESTONES.md](MILESTONES.md), [M5-impact](M5-impact-on-future-milestones.md), [M6-impact](M6-impact-on-future-milestones.md)

Single source of truth for "are we ready to submit v1?" Every blocker has an owner and a status. When every row is **✅ Done**, the answer is yes.

## Status legend

- ✅ Done — verified complete.
- 🟡 In progress — work has started but isn't finished.
- 🔴 Blocked — depends on another item or external action.
- ⚪ Not started — no work yet.

---

## A. Engineering — code, tests, build

| # | Item | Status | Owner | Notes |
|---|---|---|---|---|
| A1 | All unit tests pass (`make test`) | ✅ | eng | 22 tests, all green at M5 close. |
| A2 | Lint clean (`make lint`) | ✅ | eng | swiftformat + swiftlint --strict. |
| A3 | Debug build clean (`make app-build`) | ✅ | eng | Verified after M6 debug-gating commit. |
| A4 | Release build clean (`xcodebuild -configuration Release`) | ✅ | eng | Verified after M6 debug-gating commit. |
| A5 | `DebugHelloIntent` not present in release Shortcuts editor | ✅ | eng | Confirmed via `#if DEBUG` gating; spot-check on real device pending §C below. |
| A6 | `make release-archive` produces a signed `.xcarchive` | 🔴 | eng | Recipe in `Makefile`; signing certs/profile not yet wired. Blocked on Apple Developer setup. |

## B. Hard blockers — must close before submission

| # | Item | Status | Owner | Notes |
|---|---|---|---|---|
| B1 | Spike S3 closed (cap value chosen) | 🔴 | eng | On-device matrix in `docs/spikes/S3-background-budget.md`. Currently shelved; placeholder `RecordingLimits.maxRecordingSeconds = 600`. |
| B2 | All `{MAX_DURATION}` placeholders replaced | 🔴 | eng | Files: `RecordingLimits.swift`, `OnboardingView.swift`, `app-store-listing.md`. `grep -ri "MAX_DURATION"` must return zero. Blocked on B1. |
| B3 | Onboarding Screen 3 cap sentence restored | 🔴 | eng | Omitted at M5 with S3 shelved. Blocked on B1. |
| B4 | App icon at all required sizes | 🟡 | design | Placeholder icon (`AppIcon.png`, regenerable from `AppIcon.svg` via `scripts/regenerate-placeholder-icon.sh`) is good enough for TestFlight. Final designed icon installs via `scripts/resize-icon.sh` once a 1024×1024 source is supplied. |
| B5 | Five App Store screenshots (6.7") | ⚪ | design/eng | Per `docs/app-store-listing.md` §Screenshots. Need real device + B1 cap surfaced in UI. |
| B6 | App Store Connect record created | ⚪ | ops | Deferred from M0. Bundle ID `com.marklabrecque.whisperintent`. |
| B7 | Privacy policy hosted at a stable URL | ⚪ | ops | Source: `docs/privacy-policy.md`. Hosting choice TBD (GitHub Pages, static site, etc.). |
| B8 | Support email + URL chosen | ⚪ | ops | `mark@affinitybridge.com` is current contact in privacy policy; confirm before submission. |

## C. M5/M6 manual verification

| # | Item | Status | Owner | Notes |
|---|---|---|---|---|
| C1 | M5 test plan walked on a real device | ⚪ | eng | `docs/M5-test-plan.md`. Required before opening M6 manual matrix. |
| C2 | M6 §2 manual matrix on newest supported iPhone | ⚪ | eng | `docs/M6-test-plan.md` §2. |
| C3 | M6 §2 manual matrix on oldest supported iPhone | ⚪ | eng | Per S3 / scope decision (see project memory: scope may be raised to exclude oldest hardware). |
| C4 | M6 §3 memory profiling at the cap | ⚪ | eng | Blocked on B1. |
| C5 | M6 §3 time-to-transcript meets PRD §8 success criterion | ⚪ | eng | <3s for 10s utterance on newest device. |

## D. App Store Connect — metadata

All copy is pre-written in `docs/app-store-listing.md`. The submission task is paste + verify.

| # | Item | Status | Owner | Notes |
|---|---|---|---|---|
| D1 | App name set to "Whisper Intent" | ⚪ | ops | Per app-store-listing.md. |
| D2 | Subtitle: "Voice capture for Shortcuts" | ⚪ | ops |  |
| D3 | Promotional text (≤170 chars) | ⚪ | ops | Source drafted. |
| D4 | Keywords (≤100 chars) | ⚪ | ops | Source drafted. |
| D5 | Description (≤4000 chars) | ⚪ | ops | Source drafted. `{MAX_DURATION}` placeholder must be resolved (B2). |
| D6 | "What's New" copy for v1.0 | ⚪ | ops | Drafted: "First release. Adds the Transcribe Speech step to Apple Shortcuts." |
| D7 | Category: Productivity (primary), Utilities (secondary) | ⚪ | ops |  |
| D8 | Age rating: 4+ | ⚪ | ops |  |
| D9 | Pricing: Free, no IAP | ⚪ | ops |  |
| D10 | Support URL set | ⚪ | ops | Blocked on B7/B8. |
| D11 | Marketing URL set (optional, can leave blank) | n/a | ops | Optional for v1. |
| D12 | Privacy policy URL set | ⚪ | ops | Blocked on B7. |
| D13 | App Review notes pasted | ⚪ | ops | Source in app-store-listing.md §App Review notes. |

## E. App Store Connect — privacy

| # | Item | Status | Owner | Notes |
|---|---|---|---|---|
| E1 | Privacy nutrition label: "Data Not Collected" | ⚪ | ops | Source: `docs/privacy-nutrition-label.md`. Single answer; selection closes the form. |
| E2 | `Info.plist` `NSMicrophoneUsageDescription` matches privacy policy wording | ✅ | eng | Already in `App/WhisperIntent/Info.plist`. |
| E3 | `Info.plist` `ITSAppUsesNonExemptEncryption` = `false` | ✅ | eng | Already set. |

## F. TestFlight beta

| # | Item | Status | Owner | Notes |
|---|---|---|---|---|
| F1 | First TestFlight build uploaded | ⚪ | eng | Blocked on B6, A6, signing. |
| F2 | TestFlight "What to Test" copy pasted in App Store Connect | ⚪ | ops | Source: `docs/testflight-what-to-test.md`. |
| F3 | Internal testing pass (M5 + M6 §2 on the TF build) | ⚪ | eng | Blocked on F1. |
| F4 | External invites sent (10–25 testers) | ⚪ | ops | Blocked on F1 + F3. |
| F5 | Beta open for ≥1 continuous week, no P0 surfaced | ⚪ | eng | Blocked on F4. |
| F6 | PRD §8 reliability targets tracking on track | ⚪ | eng | <0.5% intent-failure rate (excl. permissionDenied/busy) across first 1,000 invocations. |

## G. Submission

| # | Item | Status | Owner | Notes |
|---|---|---|---|---|
| G1 | All A–F rows green (or marked n/a) | ⚪ | eng + ops | Submission gate. |
| G2 | Final pre-submission review of metadata in App Store Connect | ⚪ | ops | One person, one pass, before clicking Submit for Review. |
| G3 | Submit for Review clicked | ⚪ | ops |  |
| G4 | Review passed | ⚪ | Apple | Out of our hands; address review feedback if it comes. |
| G5 | "Release this version" clicked (manual release) | ⚪ | ops | Default to manual release so the launch timing is chosen, not Apple's. |

---

## Current snapshot (2026-05-25)

**Engineering work autonomously closable:** A1–A5 ✅, A6 recipe in place.
**Hardest remaining blockers:** B1 (S3 spike, device time), B4 (icon design), B6 (App Store Connect record), B7 (privacy policy hosting).
**Verdict:** Not ready. Closest hard blocker to act on is B1 — every cap-dependent item (B2, B3, C4, D5) cascades off it.

When the next person sits down with this file, the highest-leverage next action is whichever of {B1, B4, B6, B7} is easiest for them to move that day.
