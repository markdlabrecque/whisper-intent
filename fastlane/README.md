# Fastlane — Whisper Intent

Build, sign, and upload TestFlight beta builds. v1 scope is intentionally narrow: one lane to archive, one lane to ship.

## Prerequisites

Install the toolchain:

```bash
brew install fastlane
```

(Or use `bundler` if you prefer pinning — `Gemfile` is not provided in v1.)

Confirm Xcode 26 is the active toolchain:

```bash
xcode-select -p   # → /Applications/Xcode.app/Contents/Developer
```

## Secrets

Nothing sensitive is committed. The lanes read from environment variables; create `fastlane/.env` locally (it is gitignored) and fill in:

```dotenv
# Apple Developer team identifier (10-character alphanumeric).
# Find it: developer.apple.com → Account → Membership.
DEVELOPMENT_TEAM=XXXXXXXXXX

# Optional — only needed if you maintain multiple Apple IDs and want Fastlane
# to pick a specific one.
FASTLANE_APPLE_ID=mark@example.com

# App Store Connect team identifier (numeric). Required if your Apple ID is
# on more than one ASC team.
ASC_TEAM_ID=12345678

# App Store Connect API key. Generate at:
# appstoreconnect.apple.com → Users and Access → Integrations → App Store Connect API.
# Required role: App Manager or Admin.
ASC_KEY_ID=ABCDE12345
ASC_ISSUER_ID=00000000-0000-0000-0000-000000000000
ASC_KEY_FILEPATH=/absolute/path/to/AuthKey_ABCDE12345.p8
```

The `.p8` file itself must not be checked in — `.gitignore` excludes it. Keep it outside the repo or in a secret manager.

## Lanes

### `bundle exec fastlane build_archive`

Produces `build/WhisperIntent.xcarchive` signed with your Apple Developer team's distribution certificate. Useful for inspecting the archive in Xcode (Organizer → Archives) before uploading.

Requires: `DEVELOPMENT_TEAM`.

### `bundle exec fastlane beta`

The full TestFlight pipeline:

1. Regenerates the Xcode project (`xcodegen`).
2. Archives in Release configuration.
3. Exports as `app-store` IPA.
4. Uploads to TestFlight via `pilot`, using the App Store Connect API key.
5. Sets the build's "What to Test" notes from `docs/testflight-what-to-test.md`.

Requires: `DEVELOPMENT_TEAM`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILEPATH`.

The lane fails loudly if any required variable is unset rather than guessing.

## What's NOT here (v1)

- **`match` / signing automation.** Manual signing for v1 — one developer machine, one Apple ID. If a second developer joins, set up `match` then.
- **`screenshots` / `frameit`.** Screenshots are produced manually per `docs/app-store-listing.md` §Screenshots; not worth automating for a one-feature app.
- **`deliver` for App Store metadata.** Submission metadata is paste-from-docs (per `docs/submission-checklist.md` §D); App Store Connect's web UI is fast enough that automating it for a single submission isn't worth the maintenance.
- **CI invocation.** The repo's GitHub Actions config (`.github/workflows/ci.yml`) currently keeps the app target commented out pending Xcode 26 on hosted runners. Add a `beta` job to CI once that lands.

## First-time setup checklist

- [ ] `fastlane/.env` created and populated.
- [ ] `.p8` API key file referenced by `ASC_KEY_FILEPATH` exists and is readable.
- [ ] Provisioning profile for `com.marklabrecque.whisperintent` exists in `~/Library/MobileDevice/Provisioning Profiles/` (or Xcode "Automatically manage signing" is enabled).
- [ ] `bundle exec fastlane build_archive` produces a `.xcarchive` without prompting for credentials.
- [ ] Spot-check the archive in Xcode Organizer.
- [ ] `bundle exec fastlane beta` uploads a build that appears in App Store Connect → TestFlight within ~10 minutes.

## Troubleshooting

- **"No signing certificate found."** → Xcode → Settings → Accounts → Manage Certificates → "+" → Apple Distribution.
- **"App Store Connect API key invalid."** → Verify the `.p8` file isn't expired (keys can be revoked or expire) and that the key has App Manager role.
- **"Provisioning profile doesn't include the device."** → For TestFlight uploads this shouldn't matter (App Store distribution doesn't pin to a device list), but if you're running `build_archive` and exporting with a development profile, the profile must include your device's UDID.
