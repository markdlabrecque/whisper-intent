# Spike S2: iOS 26 AppIntents foreground-escalation API

**Status:** Not started
**Owner:**
**Started:**
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

-
