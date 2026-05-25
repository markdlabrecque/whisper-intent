# M5 — Impact on Future Milestones

**Milestone:** [M5 — AppIntent + UI surfaces](MILESTONES.md)
**Status:** Draft v0.1
**Last updated:** 2026-05-25

Decisions, placeholders, and gaps that landed during M5 with downstream effect on M6, M7, or the still-open S3 spike. Tracked here so the work surfaces explicitly when those milestones open rather than getting buried in code.

---

## 1. Hard dependencies on Spike S3

S3 is shelved (see `docs/spikes/S3-background-budget.md`). The following M5 artifacts hold placeholder values that must be replaced before TestFlight (M6):

| Artifact | File | Placeholder | Action when S3 closes |
|---|---|---|---|
| Max-duration cap | `App/WhisperIntent/RecordingLimits.swift` | `maxRecordingSeconds: TimeInterval = 600` | Replace with the measured cap. One-line change. |
| Warning thresholds | `App/WhisperIntent/RecordingLimits.swift` | 80% / 95% (cap-relative) | Confirm thresholds still feel right against the new cap. The values are fractions, so no change needed unless the UX warrants it. |
| Onboarding cap sentence | `App/WhisperIntent/Views/OnboardingView.swift` (`testScreen`) | **Omitted entirely** | Re-introduce the sentence from `docs/onboarding-copy.md` Screen 3, interpolating `RecordingLimits.maxRecordingSeconds`. |
| AppIntent description | `App/WhisperIntent/Intents/TranscribeSpeechIntent.swift` | No cap mentioned | Decide in M6 whether to add the cap to the `IntentDescription` string visible in the Shortcuts editor. PRD §5.4.1 says it must be surfaced *somewhere* in product copy. |
| App Store description | _(not yet written)_ | n/a | Drafted in M6 with the measured cap. |

**M6 entry gate:** S3 must close before M6 can land its TestFlight build. The work is small once the cap number is known; the spike itself is the long pole.

## 2. Settings deltas vs. PRD §5.9 and TDD §8.3

The "Show UI by default" toggle described in both documents was **dropped from v1** during M5. Reason: AppIntent `@Parameter(default:)` is static and can't read `UserDefaults` at parameter-definition time, so the toggle would have had no effect on the Shortcuts-editor default. Honoring it at runtime would silently contradict the visible parameter UI in Shortcuts.

**Action in M6:**
- Update PRD §5.9 to drop the toggle from the settings inventory.
- Update TDD §8.3 to remove the bullet.
- No code change required — the setting was never implemented.

## 3. Debug / spike harnesses still in the codebase

M5 left the M3 / S1 / S2 debug surfaces in place:

| Symbol | File | M6 action |
|---|---|---|
| `DebugSpikesView` entry | `App/WhisperIntent/Views/RootView.swift` | Gated behind `#if DEBUG` already. Decide whether to keep for TestFlight or strip entirely. |
| `DebugRecordingView` | `App/WhisperIntent/Views/DebugRecordingView.swift` | Used during M3 verification. Remove in M6 along with its `DebugSpikesView` entry. |
| `DebugHelloView` | `App/WhisperIntent/Views/DebugHelloView.swift` | Same — remove. |
| `DebugHelloIntent` | `App/WhisperIntent/Intents/DebugHelloIntent.swift` | The S2 spike intent. Visible to Shortcuts users in non-DEBUG builds today. **Strip before TestFlight** so it doesn't show up as a real intent in the Shortcuts editor. |
| `AppEnvironment.helloPresentation` + `presentHelloSpike` | `App/WhisperIntent/AppEnvironment.swift` | Remove when `DebugHelloIntent` goes. |

`AGENTS.md` already lists "remove (or re-gate) before TestFlight in M6" on each of these — formalize during M6 hardening.

## 4. App Store metadata work touched by M5

The user-facing copy in `OnboardingView` (per `docs/onboarding-copy.md`) and the `IntentDescription` on `TranscribeSpeechIntent` set tone for the App Store description. M6 should:

- Use the same "building block" framing as onboarding Screen 1.
- Keep the cap number consistent across: AppIntent description, onboarding Screen 3 (when restored), App Store description, screenshots.
- Avoid contradicting the on-device privacy promise in the About-section footer of `SettingsView`.

## 5. M6 hardening pass — new surfaces to exercise

M6's manual smoke test matrix (TDD §11) must add the following rows now that the surfaces exist:

- Fresh-install onboarding flow on both newest and oldest supported device.
- "Show onboarding again" re-entry from Settings → mic-permission re-prompt path on oldest device.
- Settings persistence across cold-launch.
- Sheet-dismiss + RootView re-entry mirror, mid-recording and mid-processing (PRD §5.8).
- The mic-permission denial path (`OnboardingView` and post-onboarding deep-link to system Settings).

The S3 force-quit caveat noted in TDD §9 (`showUI = false` after fresh force-quit) is unchanged by M5 but still owed to M6.

## 6. Architecture notes for v2 candidates

- `RecordingPresentation` in `AppEnvironment` carries only `prompt` today. When the v2 pause/resume work (PRD §9 item 1) lands, it will need to carry more state (e.g., the originating intent's continuation token). The presentation struct is the right seam to extend.
- The `LevelMeter` view in `RecordingSheet.swift` is reusable; a v2 waveform implementation can drop in behind the same interface.

---

## Quick checklist for M6 open

When M6 starts, walk this list:

- [ ] S3 closed and `RecordingLimits.maxRecordingSeconds` updated.
- [ ] Onboarding Screen 3 cap sentence restored.
- [ ] AppIntent description re-evaluated for cap mention.
- [ ] PRD §5.9 + TDD §8.3 updated to drop the "Show UI by default" toggle.
- [ ] All `Debug*` views, the spike intent, and `helloPresentation` plumbing removed (or `#if DEBUG`-gated and confirmed stripped from release builds).
- [ ] Smoke test matrix in TDD §11 extended per §5 above.
