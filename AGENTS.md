# AGENTS.md — Whisper Intent

Repo-specific instructions for any agent (or human) picking up this project.

## What this is

iOS app that exposes a single Apple Shortcuts `Transcribe Speech` AppIntent backed by on-device WhisperKit. v1 scope is documented in [`docs/PRD.md`](docs/PRD.md); technical design in [`docs/TDD.md`](docs/TDD.md); delivery sequencing in [`docs/MILESTONES.md`](docs/MILESTONES.md). Read those before making non-trivial changes.

## Layout

- `App/WhisperIntent/` — iOS app target sources (SwiftUI + AppIntents). Thin presentation layer.
- `Packages/WhisperIntentCore/` — Swift package containing the domain logic. No UI, no AppIntents imports. Testable without an iOS host.
- `project.yml` — XcodeGen project definition. The `.xcodeproj` is generated, not checked in.
- `docs/` — all design docs and spike reports.

## Common commands

```bash
make generate    # regenerate WhisperIntent.xcodeproj from project.yml
make build       # build the core package via SwiftPM (fast feedback)
make test        # test the core package via SwiftPM
make app-build   # build the iOS app target via xcodebuild
make lint        # run swiftlint + swiftformat in lint mode
make clean       # remove DerivedData, .build/, generated project
```

## Code quality commands (run before committing)

`.coding-standards` in the repo root runs these. They are blocking on the pre-commit hook:

```bash
swiftformat --lint .
swiftlint --strict
gitleaks git --staged --no-banner --redact
```

The gitleaks step scans staged content for credentials (API keys, private
keys, OAuth tokens) using its default rule set. `--redact` ensures the
detected secret value is never printed — only its location in the diff.
If gitleaks flags something, **do not just disable the rule**: rotate the
exposed credential, then determine whether the file should be `.gitignore`'d
or whether the value should move to an environment variable.

If a specific false positive needs to be allowed, add it to a
`.gitleaks.toml` config at the repo root (does not exist by default).

## Style notes

- Swift 6, strict concurrency on. No GCD, no `DispatchQueue.main.async` in app code. Use Swift Concurrency.
- Actors own mutable state. Don't reach into actor internals from views — bind to `AsyncStream` outputs.
- `WhisperIntentCore` must not import `AppIntents`, `SwiftUI`, or `UIKit`. If you need to do so, the abstraction is in the wrong layer.
- 2-space indentation, per `.editorconfig`.

## When to update docs

- Changing the AppIntent surface → update PRD §5.1 and TDD §7.
- Changing the recording-stop or VAD behavior → update PRD §5.4 and TDD §5.
- Changing the model or transcription path → update TDD §6.
- Closing a spike → update the corresponding `docs/spikes/S*.md` report's §6 (Decision) and follow the "Updates required in other docs" checklist there.

## What not to do

- Don't add features beyond what the PRD currently scopes for v1. v2 candidates are listed in PRD §9.
- Don't add analytics, third-party SDKs, or any network calls. The "Data Not Collected" privacy commitment is load-bearing.
- Don't check in the `.xcodeproj` (it's gitignored — regenerate with `make generate`).
- Don't bump WhisperKit to a new version without running spike S1 again to confirm progress callbacks still work as expected.
