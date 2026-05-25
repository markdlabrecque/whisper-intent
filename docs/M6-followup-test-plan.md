# M6 — Follow-up Test Plan (Items 1–8)

**Milestone:** [M6 — Hardening + TestFlight beta](MILESTONES.md)
**Status:** Draft v0.1
**Last updated:** 2026-05-25
**Companion to:** [M6 test plan](M6-test-plan.md)

This plan verifies the autonomous slice that landed *between* the original M6 hardening pass and the (still-blocked) on-device matrix. Each section maps to one of the eight items from that slice. Run when you have ten or fifteen minutes — none of these require a connected iPhone.

> **Setup once:** open a fresh terminal at the repo root. Most sections assume `make`, `git`, `bundle`, and Xcode 26 are installed.

---

## Section 1 — Placeholder icon and regeneration

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 1.1 | `ls App/WhisperIntent/Resources/Assets.xcassets/AppIcon.appiconset/` | Both `AppIcon.png` and `AppIcon.svg` present. |  |
| 1.2 | Open `AppIcon.png` in Preview or Finder Quick Look. | Stylised parenthesis + waveform glyph on dark navy. Readable at small sizes. |  |
| 1.3 | `sips -g pixelWidth -g pixelHeight App/WhisperIntent/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` | Exactly 1024 × 1024. |  |
| 1.4 | (Optional) Install one rasteriser: `brew install librsvg`. Then `scripts/regenerate-placeholder-icon.sh`. | Script prints "regenerated:" and the new file is still 1024 × 1024. Visual diff against pre-regen PNG: identical or near-identical (subpixel font/stroke rasteriser drift OK). |  |
| 1.5 | `scripts/regenerate-placeholder-icon.sh` with no rasteriser installed (run `brew uninstall librsvg imagemagick inkscape` first if you want to check). | Script fails with the install-hint error message, exit non-zero. |  |
| 1.6 | `scripts/resize-icon.sh /tmp/not-a-png.txt` (any non-PNG file). | Script fails with a clear "not a PNG file" message. |  |
| 1.7 | `scripts/resize-icon.sh path/to/some-png-that-is-not-1024.png` | Script fails with a clear "must be exactly 1024×1024" message. |  |

## Section 2 — Privacy policy GitHub Pages workflow

The workflow ships disabled at the repo level (Pages must be enabled in Settings → Pages → Source: GitHub Actions). These checks confirm the workflow file is well-formed and the Pages enablement is the only remaining step.

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 2.1 | `cat .github/workflows/publish-privacy-policy.yml` | Workflow exists; triggers on `push` to `main` with path filter on `docs/privacy-policy.md` and on `workflow_dispatch`. |  |
| 2.2 | Validate YAML syntax: `yamllint .github/workflows/publish-privacy-policy.yml` (or any YAML validator). | No syntax errors. |  |
| 2.3 | On GitHub: navigate to repo → Settings → Pages. | Pages is currently set to None / disabled, or already configured. |  |
| 2.4 | (Manual, deferred) Enable Pages: Settings → Pages → Source: GitHub Actions. Then trigger the workflow via Actions → "Publish privacy policy" → Run workflow. | The workflow runs to completion; the deployed URL is visible on the run's summary. Opening it shows the privacy policy as plain HTML with a system font and dark-mode awareness. |  |

## Section 3 — `fastlane/.env.example`

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 3.1 | `cat fastlane/.env.example` | All required variables present with placeholder values: `DEVELOPMENT_TEAM`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILEPATH`. Optional vars (`FASTLANE_APPLE_ID`, `ASC_TEAM_ID`) commented out. |  |
| 3.2 | `cp fastlane/.env.example fastlane/.env` (only if you don't have a real `.env` already — back it up first if you do!). | File copied. |  |
| 3.3 | `git status fastlane/.env` | Marked as ignored / untracked (the `.gitignore` rule must keep the real `.env` out). |  |
| 3.4 | `git status fastlane/.env.example` | Tracked, no changes. (The `.gitignore` negation must keep the example in.) |  |
| 3.5 | Restore your real `.env` if you backed it up; delete the copy otherwise. |  |  |

## Section 4 — Gemfile / Bundler

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 4.1 | `bundle --version` | Bundler version printed. Any 1.17+ / 2.x works. |  |
| 4.2 | `bundle exec fastlane --version` | Reports `fastlane 2.230.0` (or whichever the lock resolves to). Resolves from the repo's `Gemfile.lock`. |  |
| 4.3 | `bundle exec fastlane lanes` | Lists `ios beta` and `ios build_archive`. |  |
| 4.4 | `bundle exec fastlane beta` with no `fastlane/.env` and no `DEVELOPMENT_TEAM` exported. | Lane fails with the explicit "Missing required environment variables: …" message, not a stack trace. |  |

## Section 5 — `make verify`

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 5.1 | From a clean working tree: `make verify` | Exits 0. Prints "verify passed:" at the end. Runs unit tests, lint, Debug sim build, Release sim build — in that order. |  |
| 5.2 | Introduce a deliberate lint error (e.g., `git stash && touch App/WhisperIntent/Broken.swift && echo "var x: Int = 1; x = 2" > App/WhisperIntent/Broken.swift`). Run `make verify`. | Fails at the lint step; doesn't proceed to Debug/Release builds. |  |
| 5.3 | Clean up: `rm App/WhisperIntent/Broken.swift && git stash pop`. |  |  |

## Section 6 — `make doctor`

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 6.1 | `make doctor` | Coloured per-row report. All "CLI tools" green if `xcodegen`, `swiftformat`, `swiftlint`, `gitleaks`, `swift`, `xcodebuild` are installed. |  |
| 6.2 | "Xcode toolchain" section. | `active Xcode` green pointing at your Xcode.app path. `xcodebuild version` green and reports "Xcode 26.x". |  |
| 6.3 | "Project" section. | `project.yml`, `WhisperIntent.xcodeproj`, `WhisperKit model files` all green. |  |
| 6.4 | "Fastlane and signing" section, with no `fastlane/.env`. | `fastlane/.env` row is yellow with the `cp .env.example` hint. `Gemfile.lock` row green. |  |
| 6.5 | "Fastlane and signing" section after copying the example but not filling in placeholders. | `DEVELOPMENT_TEAM` and ASC rows are yellow with the "not set or still placeholder" hint. |  |
| 6.6 | Exit code is always 0 (`make doctor; echo "exit: $?"`). | `exit: 0` regardless of yellow/red rows. |  |

## Section 7 — Accessibility sweep

These require either a real device or the Simulator's Accessibility Inspector. They're the closest thing to "manual testing" in this plan — but they're cheap and can run on a simulator.

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 7.1 | Open Xcode → Open Developer Tool → Accessibility Inspector. Launch the app in the iPhone 17 Pro simulator. | Inspector connects to the simulator process. |  |
| 7.2 | Cold launch on a clean install (delete the app in the simulator first). Onboarding shows. Inspector → audit panel. | No "Hit area too small" or "Missing accessibility label" warnings on Screen 1, 2, 3. |  |
| 7.3 | On Screen 1: Inspector → element panel → click each text element. | Headline is marked as a Header (Heading trait). |  |
| 7.4 | On Screen 2 — the numbered example block. | Reads as a single combined element, e.g. "Example: step 1, Transcribe Speech…" — not three independent text reads. |  |
| 7.5 | On Screen 3: tap Record a test. | VoiceOver label reads "Record a test, grants microphone permission". Recording starts. State badge reads "Listening…" or "Transcribing…" via VoiceOver. |  |
| 7.6 | Dismiss onboarding. RootView. Inspector. | Settings gear button has label "Settings". Landing headline reads as a Header. Waveform glyph is decorative (no VoiceOver focus). |  |
| 7.7 | Open Settings. Silence-threshold slider. | VoiceOver reads "Silence threshold in seconds, 2.0 seconds, Adjustable." Swipe up/down adjusts. |  |
| 7.8 | Example Shortcut pattern (e.g. "New Reminder"). | Reads as one sentence: "New Reminder. Step 1: Transcribe Speech. Step 2: Add New Reminder using transcribed text." — not as three separate focusable items. |  |
| 7.9 | Trigger a Shortcut that calls Transcribe Speech with `Show UI = true`. RecordingSheet appears. | Elapsed counter is read as "Elapsed: 0 seconds" → "Elapsed: 5 seconds" etc., NOT as "0:05" digits. |  |
| 7.10 | Let elapsed pass 80% of the cap (`RecordingLimits.maxRecordingSeconds * 0.8`, currently 480s while the cap is the 600s placeholder — or temporarily lower `maxRecordingSeconds` to 10 to test). | Elapsed reads "warning, nearing recording limit". Above 95% it reads "approaching maximum recording length". |  |
| 7.11 | Dynamic Type test: Settings → Accessibility → Display & Text Size → Larger Text → max slider. Re-launch the app. | All copy in onboarding, RootView, RecordingSheet, SettingsView scales without truncation or overlapping elements. |  |

## Section 8 — Unit tests for RecordingLimits + UserSettings

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 8.1 | `make test` | Both the core SwiftPM suite (22 tests) AND the app-target XCTest suite run. App-target output includes `RecordingLimitsTests` (4 tests) and `UserSettingsTests` (6 tests), all passing. |  |
| 8.2 | Open `App/WhisperIntentTests/RecordingLimitsTests.swift`. Temporarily flip `warningThreshold` and `criticalThreshold` constants by hand in `RecordingLimits.swift` (swap their values). Run `make test`. | `testWarningPrecedesCritical` fails with the explicit "warning threshold must come before critical threshold" message. |  |
| 8.3 | Revert the swap. `make test`. | All tests pass again. |  |
| 8.4 | Open `App/WhisperIntentTests/UserSettingsTests.swift`. Confirm `setUp`/`tearDown` clears the two keys. | Visible in the file. |  |
| 8.5 | After `make test` completes, open the iPhone simulator. Open Whisper Intent. Onboarding shows (i.e., the test-run did NOT leak `onboardingCompleted = true` into the simulator's defaults). | Onboarding shows. |  |

---

## Sign-off

| Section | Reviewer | Date | Outcome |
|---|---|---|---|
| 1 — Icon |  |  |  |
| 2 — Pages |  |  |  |
| 3 — env.example |  |  |  |
| 4 — Gemfile |  |  |  |
| 5 — make verify |  |  |  |
| 6 — make doctor |  |  |  |
| 7 — Accessibility |  |  |  |
| 8 — Unit tests |  |  |  |

A pass requires every section green. The accessibility section (§7) is the longest pole at roughly 10 minutes; everything else is sub-2-minute.
