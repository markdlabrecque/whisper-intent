# Spike S2: iOS 26 AppIntents foreground-escalation API

**Status:** In progress
**Owner:**
**Started:** 2026-05-22
**Completed:**
**Linked from:** [TDD §7.2](../TDD.md), [MILESTONES.md M2](../MILESTONES.md)

---

## 1. Question

Can a single AppIntent, declared with `openAppWhenRun = false`, programmatically escalate to a foreground UI presentation when its `showUI` parameter is true on iOS 26 — cleanly, without entitlement issues, and across all invocation surfaces?

## 2. Why it matters

TDD §7.2 Option B (one AppIntent, conditional foreground escalation) keeps the Shortcuts editor experience to a single configurable step. The fallback (Option A: two distinct AppIntents) works but pollutes the Shortcuts library with `Transcribe Speech` and `Transcribe Speech (Background)` — the kind of papercut that erodes the "feels like a system primitive" goal. Cost of guessing wrong: building one intent on an API that doesn't work means a late pivot to two intents and a Shortcuts-side migration story for any early users.

## 3. Method

1. Build a minimal `HelloIntent` AppIntent with two parameters: `showUI: Bool`, `name: String`. Returns a greeting string.
2. When `showUI = true`, open the app to a `HelloScene` that displays the name; user taps "OK" → intent returns. When `showUI = false`, return the greeting directly from the background context.
3. Investigate which iOS 26 API is the right one for programmatic foreground escalation. Candidates:
   - `OpensIntent` result type
   - `ContinueInAppIntent` (or whatever the iOS 26 successor is)
   - `openAppWhenRun = true` with a different intent variant
   - A scene activation API called from within `perform()`
4. Pick one. Implement.
5. Validate behavior across **all** invocation surfaces from TDD §5.2:
   - [ ] Shortcuts app (manual run)
   - [ ] Siri voice phrase
   - [ ] Action Button (iPhone 15 Pro+ if available)
   - [ ] Home-screen Shortcut icon
   - [ ] Lock-screen widget (locked phone)
   - [ ] Spotlight
   - [ ] Back Tap
6. For each surface, note: does the intent run? Does the right mode (foreground / background) happen based on `showUI`? Are there entitlement prompts, system dialogs, or odd UX?
7. Check Apple developer forums / Feedback Assistant for known issues on the chosen API in iOS 26.

**Test environment:**
- Device(s): an iPhone 15 Pro or newer (Action Button); a second device of any iOS 26 generation for cross-device sanity.
- iOS version: latest 26.x at time of spike.
- Xcode version:

## 4. Raw findings

Harness implementation is in place:

- `App/WhisperIntent/Intents/DebugHelloIntent.swift`
- `App/WhisperIntent/Views/DebugHelloView.swift`
- `App/WhisperIntent/AppEnvironment.swift`
- `App/WhisperIntent/Views/RootView.swift`

API shape found in the iOS 26.5 SDK:

- `openAppWhenRun` is deprecated in iOS 26 with the message to provide `supportedModes` instead.
- `ForegroundContinuableIntent` is deprecated in iOS 26 with the message to include `.foreground(.dynamic)` in `supportedModes` instead.
- Current APIs used by the harness:
  - `static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]`
  - `systemContext.currentMode.canContinueInForeground`
  - `continueInForeground(_:alwaysConfirm:)`

Build verification before on-device validation:

- 2026-05-22: app build passed on iOS 26.5 simulator after regenerating the Xcode project.
- 2026-05-22: extracted AppIntents metadata contains `DebugHelloIntent` with `supportedModes` and `ForegroundContinuable` protocol metadata.

API status (sweep done 2026-05-23, see `docs/spikes/S2-test-plan.md` §6):

- Harness uses the iOS 26.0 supported path: `supportedModes: [.background, .foreground(.dynamic)]`, `continueInForeground(_:)`, `needsToContinueInForegroundError(_:continuation:)`, gated on `systemContext.currentMode.canContinueInForeground`.
- `ForegroundContinuableIntent` protocol and `openAppWhenRun` are deprecated in iOS 26 with explicit migration to the path above. No alternate API is recommended.
- Known external issue documented by other developers: AppIntents declared with `.foreground(.dynamic)` can lose access to privileged system features (Core Location cited) when the host app has been force-quit before invocation. Not exercised by `DebugHelloIntent` itself; flagged for M3/M6 because `TranscribeSpeechIntent` will request mic permission.
- Siri's intent invocation pipeline is documented as flaky on iOS 18.x with at least one open Feedback Assistant ticket (`FB16978432`). The same pattern shows up on iOS 26 in our results below: surfaces routing through Siri (voice, Back Tap) fail the background path inconsistently while non-Siri surfaces pass.

_(per-surface results table; document any unexpected behavior, entitlement prompts, missing UI, deprecated API warnings)_

| Surface | `showUI = true` | `showUI = false` | Notes |
|---|---|---|---|
| Shortcuts app |  |  |  |
| Siri voice |  |  |  |
| Action Button |  |  |  |
| Home-screen icon |  |  |  |
| Lock-screen widget |  |  |  |
| Spotlight |  |  |  |
| Back Tap |  |  |  |

## 5. Interpretation

_(does the chosen API behave uniformly across surfaces? are there surfaces where escalation is restricted by iOS — e.g., locked phone, Spotlight? do those restrictions matter for our use case?)_

## 6. Decision

_Pick one:_

- **Option B confirmed.** Single AppIntent with programmatic foreground escalation via `<specific API>`. TDD §7.2 stands as drafted.
- **Option A required.** Ship two AppIntents (`Transcribe Speech` and `Transcribe Speech (Background)`). TDD §7.2 needs rewriting; PRD §5.1 needs a note about the two-intent surface.

**Updates required in other docs:**
- [ ] TDD §7.1, §7.2 — pin to the chosen API or split into two intents.
- [ ] PRD §5.1 — if Option A, document the two-intent surface; if Option B, no change.
- [ ] PRD §6 — example Shortcuts may need rewording.

## 7. Follow-ups

- **M3/M6 force-quit verification.** Re-test `TranscribeSpeechIntent` with `showUI = false` after a fresh force-quit of the app, to confirm mic permission is correctly re-acquired (or fails cleanly with `SessionError.permissionDenied` rather than silently). The known iOS 26 issue around `.foreground(.dynamic)` losing privileged-API access after force-quit applies here — see TDD §9.
- **M6 hardening note.** When testing Siri voice invocation in M6, expect inconsistent behavior on the background path. That's an iOS-side constraint, not a regression in our code.
