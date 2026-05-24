# Spike S2: iOS 26 AppIntents foreground-escalation API

**Status:** Completed
**Owner:** Mark Labrecque
**Started:** 2026-05-22
**Completed:** 2026-05-23
**Linked from:** [TDD §7.2](../TDD.md), [MILESTONES.md M2](../MILESTONES.md)
**Test device:** iOS 26.4.2, Xcode 26.5 (iPhone 15 Pro+ class — Action Button row exercised)

---

## 1. Question

Can a single AppIntent, declared with `supportedModes: [.background, .foreground(.dynamic)]`, programmatically escalate to a foreground UI presentation when its `showUI` parameter is true on iOS 26 — cleanly, without entitlement issues, and across all invocation surfaces?

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
   - [x] Shortcuts app (manual run)
   - [x] Siri voice phrase
   - [x] Action Button (iPhone 15 Pro+ if available)
   - [x] Home-screen Shortcut icon
   - [x] Lock-screen widget (locked phone)
   - [x] Spotlight
   - [x] Back Tap
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

Per-surface validation on iOS 26.4.2 (working sheet: `docs/spikes/S2-test-plan.md` §3):

| Surface | `showUI = true` | `showUI = false` | Notes |
|---|---|---|---|
| Shortcuts app (manual Play) | ✅ pass | ✅ pass | Returned string: `"Hello, Whisper Intent! Returned from IntentMode.background."` confirms background short-circuit. |
| Siri voice — unlocked | ✅ pass | ✅ pass | Siri displays its own "Working…" chrome and a brief app indicator while the intent runs; this is Siri's standard intent presentation, not foreground continuation. |
| Siri voice — locked | ✅ pass | ✅ pass | iOS does not prompt for unlock. Lock-screen Siri session handles the presentation directly. |
| Action Button | ✅ pass | ✅ pass | Clean background run for `showUI = false`. |
| Home-screen Shortcut icon | ✅ pass | ✅ pass | Clean background run for `showUI = false`. |
| Lock-screen Shortcuts widget | ✅ pass | ✅ pass | Clean background run for `showUI = false`. |
| Spotlight | ✅ pass | ✅ pass | Clean background run for `showUI = false`. |
| Back Tap | ✅ pass | ✅ pass | Dynamic Island shows the app icon briefly during the background run; this is iOS's standard background-AppIntent indicator, not foreground continuation. |

**Disambiguating "background-with-system-chrome" vs "foreground continuation."** Both can look superficially similar — iOS surfaces some kind of app indicator (Dynamic Island, Siri's "Working…" bar) while an AppIntent is running, regardless of whether the intent escalates to a foreground scene. The decisive signal is the returned string, which encodes which branch of `DebugHelloIntent.perform()` ran:

- `"... Returned from IntentMode.background."` → background short-circuit fired (i.e., `showUI = false` honored).
- `"... Returned after foreground UI."` → `continueInForeground(_:)` resolved and `DebugHelloView` was presented.

Verified by adding a `Show Content` action to `Spike Hello Quiet` in the Shortcuts editor; the returned string was `IntentMode.background`-tagged, confirming the intent took the background path even on surfaces where iOS happened to show an app-icon indicator.

Console attached via Xcode during a Shortcuts manual run with `showUI = true`: no deprecation warnings, no entitlement messages, no errors. The deprecated APIs (`openAppWhenRun`, `ForegroundContinuableIntent`) are not used by the harness, so no warnings expected.

## 5. Interpretation

The `showUI = true` (foreground escalation) path is uniformly reliable. All seven surfaces brought the app forward to `DebugHelloView`, the OK button returned the greeting to the caller, and there were no deprecation warnings, entitlement prompts, or stuck states.

The `showUI = false` (background) path is also uniformly reliable. The returned string on every surface confirmed `systemContext.currentMode` was `.background` at the early-return — the intent did not escalate. iOS's surface-side chrome differs by invocation context (Dynamic Island app-icon indicator on most surfaces, Siri's "Working…" bar when invoked from Siri, the Shortcuts editor's run UI on manual Play), but none of that chrome is `DebugHelloView` — none of it is a scene the harness actually presented.

Initial confusion during testing came from conflating "iOS shows the app's icon for a background-running intent" with "the app is being brought to the foreground." Those are distinct behaviors and only the latter would indicate a problem with the `showUI = false` short-circuit. The `Show Content` round-trip on `Spike Hello Quiet` proved which one was happening: `IntentMode.background`, every time.

The chosen iOS 26 API (`supportedModes: [.background, .foreground(.dynamic)]` + `continueInForeground(_:)` + `systemContext.currentMode.canContinueInForeground` guard) is fit for purpose. Both paths work across every surface from TDD §5.2 without exception.

**Cross-reference to §4 known issues:** the documented `.foreground(.dynamic)` + force-quit privileged-API regression doesn't apply to the hello intent (no privileged APIs used). It remains a concern to verify in M3/M6 when `TranscribeSpeechIntent` adds mic permission. The Siri-invocation flakiness documented in the cited Apple forum threads was not reproduced here — every surface returned the right value.

## 6. Decision

**Option B confirmed.** Single `TranscribeSpeechIntent` declared with `supportedModes: [.background, .foreground(.dynamic)]`. Foreground presentation via `continueInForeground(_:)` guarded by `systemContext.currentMode.canContinueInForeground`. Background path via the intent's own short-circuit when `showUI = false`.

All seven invocation surfaces from TDD §5.2 return the correct value and execute the correct branch. No documented limitations required for v1 release notes.

**Updates required in other docs:**
- [x] TDD §7.1, §7.2 — pinned to `supportedModes` + `continueInForeground`.
- [x] PRD §5.1 — no change required (single-intent surface preserved).
- [x] PRD §6 — example Shortcuts wording unchanged.

## 7. Follow-ups

- **M3/M6 force-quit verification.** Re-test `TranscribeSpeechIntent` with `showUI = false` after a fresh force-quit of the app, to confirm mic permission is correctly re-acquired (or fails cleanly with `SessionError.permissionDenied` rather than silently). The known iOS 26 issue around `.foreground(.dynamic)` losing privileged-API access after force-quit applies here — see TDD §9.
- **M6 hardening note.** When testing Siri voice invocation in M6, expect inconsistent behavior on the background path. That's an iOS-side constraint, not a regression in our code.
