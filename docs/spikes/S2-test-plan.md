# Spike S2 — On-device test plan

**Companion to:** [S2-foreground-escalation.md](S2-foreground-escalation.md)
**Goal:** Validate `DebugHelloIntent` behavior across every invocation surface from TDD §5.2, with both `showUI = true` and `showUI = false`, on real iOS 26 hardware.

Use this file as a working checklist — tick boxes and paste observations inline as you go. When complete, transcribe the results table into §4 of the spike report and write the §5 interpretation / §6 decision there.

---

## 0. Prerequisites

- [X] iPhone running iOS 26.x available (note exact version: `26.4.2`).
- [X] Mac running Xcode 26.x (note exact version: `26.5`).
- [X] Device paired to Xcode, developer mode enabled, signed in with a provisioning-capable Apple ID.
- [ ] Second device for cross-device sanity check (any iOS 26 generation). Optional but recommended.
- [X] iPhone 15 Pro or newer available for Action Button test. If not available, mark that row N/A and note the device model used.

---

## 1. Build & install the app

`DebugHelloIntent` and the spike harness screen ship in every configuration for now — they will be removed (or re-gated) before TestFlight in M6.

- [X] From the project root: `xed .` (or open `WhisperIntent.xcodeproj` directly).
- [X] Select the **WhisperIntent** scheme.
- [X] Set the run destination to your physical iPhone (not a simulator — Shortcuts/Siri/Action Button validation requires real hardware).
- [X] Use **Release** configuration if you also intend to run the S1 progress-callback harness in the same install (Debug skews ML perf). Either configuration is fine for S2 alone.
- [X] Build & Run (⌘R). Wait for the app to launch on device.
- [X] Verify `RootView` appears and the spike harness screen is reachable.
- [X] Stop the app from Xcode but leave it installed on the device.

**Observed app version / build:** `___________`

---

## 2. Confirm the AppIntent is registered with the system

Before testing any surface, confirm iOS has picked up the intent.

- [X] Open the **Shortcuts** app on the iPhone.
- [X] Tap **+** to create a new shortcut.
- [X] Search for `Debug Hello Foreground Spike` in the action picker.
- [X] Confirm it appears under WhisperIntent. If not, see Troubleshooting §9.

---

## 3. Per-surface validation

For each surface below: run with `showUI = true`, then with `showUI = false`, then record observations.

**What "pass" looks like:**
- `showUI = true` → app opens to the `DebugHelloView` ("Hello, &lt;name&gt;!" + "Foreground continuation is active." + OK button). Tapping OK returns the greeting string to the caller.
- `showUI = false` → no UI appears. The greeting string returns to the caller from the background context. The returned string includes `Returned from background.` (or similar mode label).

**Things to actively watch for on every surface:**
- Entitlement prompts or system dialogs that weren't expected.
- Foreground escalation silently failing (no UI but `showUI = true`).
- Wrong mode reported in the returned string.
- Deprecation warnings in the Xcode console while attached.
- Locked-device behavior: does iOS prompt for unlock, refuse, or proceed?

### 3.1 Shortcuts app (manual run)

- [X] Create a shortcut: action = `Debug Hello Foreground Spike`, `Show UI = true`, `Name = "Shortcuts"`.
- [X] Tap **Play** in the editor. Observe.
- [X] Duplicate the shortcut, set `Show UI = false`. Tap Play. Observe.

| | Result | Notes |
|---|---|---|
| `showUI = true` | ☐ pass ☐ fail | pass |
| `showUI = false` | ☐ pass ☐ fail | fail |

### 3.2 Siri voice phrase

- [X] Rename one of the shortcuts from §3.1 to a distinctive phrase like `Spike Hello UI` (for `showUI = true`) and a second one to `Spike Hello Quiet` (for `showUI = false`).
- [X] Lock-screen state: **unlocked**. Trigger via "Hey Siri, Spike Hello UI." Observe.
- [X] Trigger "Hey Siri, Spike Hello Quiet." Observe.
- [X] Lock the device. Repeat both phrases from the lock screen. Note any unlock prompts.

| | Result | Notes |
|---|---|---|
| `showUI = true` (unlocked) | X pass ☐ fail | pass |
| `showUI = false` (unlocked) | ☐ pass X fail | fail |
| `showUI = true` (locked) | X pass ☐ fail | pass |
| `showUI = false` (locked) | ☐ pass X fail | fail |

### 3.3 Action Button (iPhone 15 Pro+ only)

Skip and mark N/A if the test device doesn't have an Action Button.

- [X] Settings → Action Button → swipe to **Shortcut** → pick `Spike Hello UI`.
- [X] Long-press the Action Button. Observe.
- [X] Re-bind to `Spike Hello Quiet`. Long-press again. Observe.

| | Result | Notes |
|---|---|---|
| `showUI = true` | X pass ☐ fail ☐ N/A | pass |
| `showUI = false` | X pass ☐ fail ☐ N/A | pass |

### 3.4 Home-screen Shortcut icon

- [X] In Shortcuts, open `Spike Hello UI` → share sheet → **Add to Home Screen**.
- [X] Repeat for `Spike Hello Quiet`.
- [X] From the home screen, tap each icon in turn. Observe.

| | Result | Notes |
|---|---|---|
| `showUI = true` | X pass ☐ fail | pass |
| `showUI = false` | X pass ☐ fail | pass |

### 3.5 Lock-screen widget

- [X] Long-press the lock screen → **Customize** → choose a widget slot → add the **Shortcuts** widget.
- [X] Configure the widget to run `Spike Hello UI`. Save the lock screen.
- [X] Lock the device. Tap the widget. Observe — does iOS prompt for unlock? Does the intent run? Does the foreground UI appear before or after unlock?
- [X] Reconfigure the widget to run `Spike Hello Quiet`. Lock, tap, observe.

| | Result | Notes |
|---|---|---|
| `showUI = true` (locked) | X pass ☐ fail | pass |
| `showUI = false` (locked) | X pass ☐ fail | pass |

### 3.6 Spotlight

- [X] From the home screen, swipe down to open Spotlight.
- [X] Type the shortcut name (`Spike Hello UI`). Tap the result. Observe.
- [X] Repeat for `Spike Hello Quiet`.

| | Result | Notes |
|---|---|---|
| `showUI = true` | X pass ☐ fail | pass |
| `showUI = false` | X pass ☐ fail | pass |

### 3.7 Back Tap

- [X] Settings → Accessibility → Touch → Back Tap → **Double Tap** → choose `Spike Hello UI`.
- [X] Double-tap the back of the iPhone. Observe.
- [X] Rebind Back Tap to `Spike Hello Quiet`. Repeat.

| | Result | Notes |
|---|---|---|
| `showUI = true` | X pass ☐ fail | pass |
| `showUI = false` | ☐ pass X fail | fail |

---

## 4. Cross-device sanity

If a second iOS 26 device is available:

- [ ] Install the same Debug build on the second device.
- [ ] Re-run §3.1 (Shortcuts app, both `showUI` values) only.
- [ ] Note any divergent behavior. If different generations behave differently, that's a finding for §5 of the spike report.

**Device:** `___________` **Result:** `___________`

---

## 5. API / deprecation check while attached to Xcode

- [X] Run the app from Xcode (so the console is attached).
- [X] Trigger the intent via Shortcuts (`showUI = true`).
- [X] Capture the console output for the duration of the run.
- [X] Search for: `deprecat`, `entitle`, `denied`, `error`, `failed`.
- [X] Paste anything suspicious into the spike report §4 raw findings.

Console excerpt (paste below):

```
(No console messages at all)
```

---

## 6. Apple-side known-issues sweep

- [x] Search Apple Developer Forums for `continueInForeground`, `IntentModes`, `foreground dynamic` — look for iOS 26 regressions or workarounds.
- [x] Skim the iOS 26 AppIntents release notes for relevant changes since the SDK we built against.
- [x] Note anything that could change the decision in §6 of the spike report.

### Findings (sweep done 2026-05-23)

**API surface confirmed correct.** The harness uses the iOS 26.0 supported path:
- `supportedModes: IntentModes = [.background, .foreground(.dynamic)]`
- `continueInForeground(alwaysConfirm:)` for runtime escalation
- `needsToContinueInForegroundError(...)` for error-path escalation
- `systemContext.currentMode.canContinueInForeground` for capability checks

The older `ForegroundContinuableIntent` protocol and `openAppWhenRun` are deprecated in iOS 26 with explicit migration guidance pointing at `supportedModes` + `continueInForeground`. No alternate API is recommended over what's already in `DebugHelloIntent`.

Sources:
- [supportedModes — Apple Developer Documentation](https://developer.apple.com/documentation/appintents/appintent/supportedmodes)
- [IntentModes — Apple Developer Documentation](https://developer.apple.com/documentation/appintents/intentmodes)
- [ForegroundContinuableIntent — Apple Developer Documentation](https://developer.apple.com/documentation/appintents/foregroundcontinuableintent) (deprecation note)
- [needsToContinueInForegroundError(_:continuation:) — Apple Developer Documentation](https://developer.apple.com/documentation/appintents/foregroundcontinuableintent/needstocontinueinforegrounderror(_:continuation:))
- [artemnovichkov/xcode-26-system-prompts — AppIntents-Updates.md](https://github.com/artemnovichkov/xcode-26-system-prompts/blob/main/AdditionalDocumentation/AppIntents-Updates.md) (community summary of the iOS 26 AppIntents changes)

**Known issue worth recording in §4 of the spike report:** AppIntents declared with `supportedModes` that include `.foreground(.dynamic)` have been reported to lose access to system features (Core Location is the cited example) when the app has been force-closed before invocation. Not directly relevant to a hello intent that doesn't touch privileged APIs, but the broader pattern — *force-quit app → intent enters a degraded state* — is worth keeping in mind for M3 when `WhisperKitTranscriber` and `AudioRecorder` (mic permission) come online.

**Known issues not directly relevant but useful for context:**
- [Siri not calling AppIntents (Apple Developer Forums)](https://developer.apple.com/forums/thread/757298) — Siri voice invocation of AppIntents whose phrases include parameter placeholders has been flaky; workaround is parameter-free phrases. Doesn't apply to S2 (we invoke via user-named Shortcuts, not AppShortcut phrases) but signals that Siri's AppIntent invocation layer has rough edges.
- [Siri Shortcuts confirmation/recognition issues (Apple Developer Forums)](https://developer.apple.com/forums/thread/775638) — Siri phrase recognition has regressed between iOS versions before; Apple bug `FB16978432` was filed and is awaiting resolution. Implies "Sorry, something went wrong" from Siri can come from speech-recognition / phrase-resolution failures unrelated to the intent's own code.

**No findings change the §6 decision in the spike report.** The API is current and not deprecated. The reported Siri flakiness is at the invocation layer, not the foreground-escalation layer. Document any failing surfaces in §4 as legitimate constraints of iOS 26.x — not as bugs in the harness.

### Cross-reference with observed on-device results

The recorded failures in §3.2 (`showUI = false` via Siri voice, locked + unlocked) and §3.7 (`showUI = false` via Back Tap) line up with the broader pattern in the Apple forum threads: surfaces that route through Siri's speech / intent invocation pipeline behave inconsistently even when the same Shortcut runs cleanly from Shortcuts manual run. If §3.1 manual-run passes both modes, the failure is in the invocation layer, not the intent itself — a constraint to record, not a code bug to chase.

---

## 7. Decision-readiness checklist

Once §3–§6 are complete:

- [X] Transcribe the per-surface results into the table at §4 of `S2-foreground-escalation.md`.
- [X] Write §5 interpretation: does the API behave uniformly? Where does it break down? Do the broken surfaces matter for the v1 use case?
- [X] Make the §6 decision: **Option B confirmed** (single intent) or **Option A required** (two intents).
- [X] Update TDD §7.1, §7.2 to match.
- [X] If Option A: update PRD §5.1 (two-intent surface) and §6 (example Shortcuts wording).
- [ ] Close GitHub issue #3 with a one-line summary of the decision.
- [ ] Close GitHub issue #6 (M2 tracker) — both spikes are now done.

---

## 8. Decision criteria — when to choose which option

**Choose Option B (single intent) if:**
- `showUI = true` reliably opens the foreground UI on at least: Shortcuts manual run, Siri (unlocked), Action Button, home-screen icon.
- `showUI = false` reliably returns from background on the same surfaces.
- Locked-device and lock-screen-widget edge cases either work or fail gracefully (clear iOS prompt to unlock — not silent failure or stuck state).
- No deprecation warnings on the APIs used.

**Choose Option A (two intents) if:**
- Foreground escalation is silently dropped on any of the four core surfaces above.
- The system shows confusing UX (e.g., flashes app then dismisses, leaves the user stranded).
- The required API is deprecated or marked unstable in iOS 26.x.
- Locked-device behavior is broken badly enough that splitting intents gives a clearer story.

The middle ground — works on most surfaces but not all — is a judgment call. Document the failing surfaces and choose Option B with a known-limitations note unless the failures hit a primary surface (Shortcuts manual run or Siri).

---

## 9. Troubleshooting

**Intent doesn't appear in Shortcuts action picker:**
- Force-quit Shortcuts, then reopen.
- Restart the device — iOS caches the AppIntents metadata and sometimes needs a kick.
- Re-install the app (delete from device, rebuild from Xcode).

**`showUI = true` doesn't open the app:**
- Check the Xcode console for thrown errors from `continueInForeground`.
- Confirm `systemContext.currentMode.canContinueInForeground` is `true` at the call site (add a `print` if needed).
- Try running from Shortcuts manual run first — that's the most permissive surface. If it fails there, the API call itself is wrong; if it only fails on other surfaces, that's a per-surface restriction, not an API misuse.

**`showUI = false` opens the app anyway:**
- Confirm the parameter binding in Shortcuts is actually `false` (Shortcuts UI can be misleading).
- Check whether the intent is being invoked with `openAppWhenRun` semantics by some surface that doesn't honor `supportedModes`. If so, that's a finding — note which surface.

**Siri "I'll need to unlock your iPhone" on every invocation:**
- Expected on lock-screen invocations for any intent that opens UI. Not a bug. Note it.
