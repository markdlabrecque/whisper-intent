# Whisper Intent — Technical Design Document

**Status:** Draft v0.1
**Author:** Mark Labrecque
**Last updated:** 2026-05-22
**Companion to:** [PRD.md](PRD.md)

This document specifies the technical design for Whisper Intent v1. It assumes the product scope defined in the PRD: a single `Transcribe Speech` AppIntent that records audio, transcribes locally with WhisperKit medium, and returns a `String` transcript to Apple Shortcuts.

---

## 1. Platform & Tooling

| Component | Choice | Notes |
|---|---|---|
| Minimum iOS | 26.0 | Per PRD §4. Allows the cleanest AppIntents surface. |
| Language | Swift 6 (strict concurrency) | All shared mutable state goes through actors; data races are compile errors. |
| UI | SwiftUI | The whole app is small enough that UIKit interop is not needed. |
| Concurrency | Swift Concurrency (`async`/`await`, `actor`) | No GCD queues in app code. AVFoundation callbacks bridge through `AsyncStream`. |
| Audio | AVFoundation (`AVAudioEngine`) | Direct PCM tap, no `AVAudioRecorder` (we need realtime buffers for VAD and waveform). |
| ML | WhisperKit (Swift package) | Medium model bundled. |
| Build system | Xcode 26 + Swift Package Manager | One app target, one shared package for the core domain (`WhisperIntentCore`). |
| CI | GitHub Actions, `xcodebuild` | TestFlight upload via Fastlane. |

## 2. Module Layout

```
WhisperIntent/                  # app target — SwiftUI + AppIntents
  WhisperIntentApp.swift        # @main entry; wires DI
  Views/
    RootView.swift              # re-entry surface (PRD §5.8)
    RecordingSheet.swift        # foreground UI for AppIntent (§5.5)
    SettingsView.swift
  Intents/
    TranscribeSpeechIntent.swift
  Resources/
    Models/                     # bundled WhisperKit medium model files
WhisperIntentCore/              # Swift package — domain logic, no UI
  Sources/
    Session/
      TranscriptionSession.swift   # the shared actor (§3)
      RecordingLock.swift          # single-recording invariant (§4)
    Audio/
      AudioRecorder.swift          # AVAudioEngine wrapper
      VoiceActivityDetector.swift  # silence detection (§5)
    Transcription/
      WhisperKitTranscriber.swift  # WhisperKit adapter (§6)
      TranscriptionProgress.swift
    Permissions/
      PermissionsService.swift
  Tests/
    ...
```

The `WhisperIntentCore` split exists so domain logic is unit-testable without an iOS host and stays free of any AppIntents/SwiftUI imports.

## 3. `TranscriptionSession` — the central actor

This is the single source of truth for "is something recording or transcribing right now, and what's its state." Both the AppIntent and the app's root view read from and write to this actor. No other code owns recording or transcription state.

```swift
public actor TranscriptionSession {
    public enum State: Sendable, Equatable {
        case idle
        case recording(startedAt: Date, level: Float)       // level updates ~20Hz
        case processing(progress: TranscriptionProgress)    // see §6
        case completed(transcript: String)
        case failed(error: SessionError)
    }

    public var state: State { get }
    public var stateStream: AsyncStream<State> { get }      // for SwiftUI views

    public func startRecording(config: RecordingConfig) async throws
    public func stopRecording() async                       // user tap or VAD
    public func cancel() async                              // only used by error paths
}
```

Design notes:
- `State` carries everything the UI needs to render. Views never reach behind it to query the recorder or transcriber directly.
- `stateStream` is consumed by SwiftUI via a `@Observable` adapter that bridges the `AsyncStream` into observable storage. Both `RecordingSheet` and `RootView` subscribe; they re-render identically when state changes.
- The actor owns the `AudioRecorder` and `WhisperKitTranscriber`. They are not directly visible to anything else.
- `RecordingConfig` carries the per-invocation parameters from the AppIntent (silence threshold, optional prompt). `Show UI` is **not** a property of the session — it's a presentation decision made by the AppIntent at invocation time (§7).

Lifecycle:
1. AppIntent calls `startRecording`. Actor checks the recording lock (§4), transitions `idle → recording`, starts the audio engine.
2. Audio buffer taps push frames into VAD and the level meter; both produce updates that mutate `state` (level changes) or trigger `stopRecording` (VAD silence threshold hit).
3. `stopRecording` halts the audio engine, transitions `recording → processing(progress: .starting)`, and hands the captured PCM to `WhisperKitTranscriber`.
4. Transcriber emits progress updates that drive `state` to successive `.processing(progress: …)` values.
5. On completion, `state → completed(transcript:)`. AppIntent reads it, returns it to the Shortcut.
6. After a short cooldown, `state → idle`. Lock released.

Failure handling: any error in steps 2–4 transitions to `.failed(error:)`. AppIntent throws an `IntentError` mapped from `SessionError`.

## 4. Recording lock

Encoded as the actor's `state`. The check is trivial:

```swift
guard case .idle = state else { throw SessionError.busy }
```

No separate `os_unfair_lock` needed — Swift actors serialize all access to `state`. The "lock" is the actor's serialization guarantee.

Cross-process is not a concern: AppIntents always run inside Whisper Intent's process. iOS doesn't run two instances of the app simultaneously.

## 5. Audio capture & VAD

### 5.1 `AudioRecorder`

Wraps `AVAudioEngine`:
- Configures `AVAudioSession` with category `.playAndRecord`, mode `.measurement`, options `[.allowBluetoothHFP, .defaultToSpeaker]`. `.measurement` mode disables system audio processing (AGC, noise suppression) that would distort what WhisperKit sees.
- Installs an input tap at 16 kHz mono (WhisperKit's expected input format). Down-mix/down-sample done with `AVAudioConverter`, not by reconfiguring the hardware (which can fail on Bluetooth devices).
- Pushes each buffer to two consumers: the VAD and an in-memory `[Float]` accumulator (the full recording, kept in RAM — see §10 for size analysis).
- Handles `AVAudioSession.interruptionNotification` and route changes; on interruption (phone call, Siri), the recording is stopped and surfaced as `SessionError.interrupted`. v1 does not attempt to resume after interruption (that's a v2 pause/resume concern).

### 5.2 `VoiceActivityDetector`

Simple energy-based detector for v1, not a neural VAD:
- Computes short-term RMS over a sliding ~30ms window.
- Maintains a running noise-floor estimate from the first 500ms of audio (an automatic "warmup" period during which VAD cannot trigger — protects against cutting off the user's first word, per PRD §5.4).
- "Silence" = RMS below `noiseFloor + threshold_dB` for a continuous duration ≥ the user-configured silence threshold (default 2.0s).
- When silence is sustained for the threshold duration, calls `session.stopRecording()`.

This is intentionally not a neural VAD. WhisperKit ships one (`silero-vad`), and we'll evaluate swapping it in if energy-based VAD has false-positive issues during real-world testing. The interface stays the same.

## 6. WhisperKit integration

### 6.1 Model bundling

The medium model (~1.5 GB on disk) is bundled in `Resources/Models/`. Two delivery options:
- **Option A (preferred):** ship as part of the main app bundle. Adds ~1.5 GB to install size.
- **Option B (fallback):** ship via On-Demand Resources (ODR). Smaller install footprint, but model is downloaded after first launch — contradicts the "no first-run download" PRD goal.

**Decision (confirmed by spike S4, 2026-05-22):** Option A. Local fat IPA measured at 1.35 GB; signed `.app` bundle 1.4 GB. The PRD's "no first-run download" requirement and the realities of Shortcuts users wiring up an automation only to have it fail because the model isn't downloaded yet make ODR a poor fit. If thinned App Store numbers at M6 come in dramatically worse than expected, the fallback is a smaller model variant — not ODR. See [docs/spikes/S4-install-size.md](spikes/S4-install-size.md).

Model files (Core ML `.mlmodelc` directories for encoder + decoder + tokenizer JSON) live under `Resources/Models/openai_whisper-medium/`. Verified at app launch — if files are missing or corrupted, app shows an error and refuses to start (this is a build/packaging error, not a user-recoverable state).

### 6.2 `WhisperKitTranscriber`

```swift
final class WhisperKitTranscriber {
    init() async throws  // loads model from bundle; ~1–3s on A16+
    func transcribe(_ pcm: [Float],
                    progress: @Sendable (TranscriptionProgress) -> Void) async throws -> String
}
```

- Single instance held by `TranscriptionSession`. Lazy-initialized on first use (model load is deferred until needed to keep cold-start fast).
- After model is loaded once in the process, subsequent transcriptions reuse it — no reload cost on repeated invocations within the same app lifetime.
- WhisperKit is called with `language: "en"`, `task: .transcribe`. Multilingual is a v2 feature.

### 6.3 Progress callbacks

WhisperKit exposes progress via `TranscriptionCallback` on its decoder loop.

**Decision (S1, 2026-05-23):** v1 ships an indeterminate spinner with phase labels. The S1 harness measured frequent progress callbacks (~25 Hz) on both short and longer synthetic samples, with no cadence degradation on longer input. However, the callback payload (`tokens.count`, `windowId`) does not expose a stable total-work denominator for a truthful 0...1 progress bar. Segment-discovery callbacks are much coarser and are also not suitable for smooth determinate progress.

The UI still gets useful phase updates: starting, encoding, decoding, and finishing. A determinate bar remains a v2 candidate if a future WhisperKit API or adapter change exposes trustworthy progress fractions.

`TranscriptionProgress` is the abstraction over this:

```swift
public enum TranscriptionProgress: Sendable, Equatable {
    case starting
    case phase(Phase)
    case finishing
    public enum Phase: String, Sendable { case encoding, decoding }
}
```

UI binds to this enum and renders a spinner with the current phase label.

## 7. AppIntent design

### 7.1 `TranscribeSpeechIntent`

```swift
struct TranscribeSpeechIntent: AppIntent {
    static var title: LocalizedStringResource = "Transcribe Speech"
    static var description = IntentDescription(
        "Record audio and return the transcript as text. Use this as a step in a Shortcut to capture voice input for any destination."
    )

    // Parameters per PRD §5.1
    @Parameter(title: "Silence threshold (seconds)",
               default: 2.0,
               inclusiveRange: (0.0, 10.0))
    var silenceThreshold: Double

    @Parameter(title: "Show UI", default: true)
    var showUI: Bool

    @Parameter(title: "Prompt", default: nil)
    var prompt: String?

    static var openAppWhenRun: Bool { false }   // see §7.2

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let session = AppEnvironment.shared.session
        let config = RecordingConfig(
            silenceThreshold: silenceThreshold,
            prompt: prompt
        )

        if showUI {
            // Present the recording sheet via the app's scene.
            try await AppEnvironment.shared.presenter.presentRecordingSheet()
        }

        try await session.startRecording(config: config)
        let transcript = try await session.awaitCompletion()  // suspends until .completed or .failed
        return .result(value: transcript)
    }
}
```

### 7.2 Foreground vs background execution

The PRD requires both modes (`Show UI = true/false`). AppIntents in iOS 26 distinguish them via `openAppWhenRun`, but that's a static property. Two options:

- **Option A:** Two AppIntent types, one with `openAppWhenRun = true` (foreground), one with `false` (background). Shortcuts user picks the one they want.
- **Option B (chosen):** One AppIntent with `openAppWhenRun = false`. When `showUI = true`, the intent uses `ContinueInAppIntent` (or equivalent iOS 26 API) to programmatically open the app to its recording scene; when `false`, it runs entirely in the extension's background context.

Option B keeps the Shortcuts surface clean (one step, configurable) and matches the PRD's "single step in the Shortcut" requirement. The cost is more careful lifecycle handling — the spike on iOS 26 AppIntents API for programmatic foreground escalation is the second technical task.

### 7.3 Background execution constraints and the max-duration cap

When `showUI = false`, `perform()` runs in the AppIntents extension's background context. Constraints:
- Limited wall-clock budget (Apple documents ~30s for some intent types but doesn't publish hard limits for AppIntents — assume 30–60s for planning).
- No UI APIs available.
- Process can be terminated by iOS if memory pressure is high.

Per PRD §5.4.1, the resolution is a documented hard cap on recording duration — not an auto-escalation kludge. The cap applies uniformly whether `showUI` is true or false, so the behavior is consistent and the user-facing message is one sentence ("Records up to N minutes per invocation") rather than a conditional explanation.

**Implementation:**
- `RecordingConfig` carries a `maxDuration: TimeInterval` constant baked at build time (initially TBD, set after spike #3).
- `AudioRecorder` runs an internal timer; when elapsed time reaches `maxDuration`, it calls `session.stopRecording()` — identical to a user tap.
- The recording UI shows a normal elapsed-time counter, transitioning to a "warning" visual treatment (color shift) at 80% of the cap and a more prominent indicator at 95%. No modal popups — the user is informed but not interrupted.
- Cap-reached is not an error: the captured audio is transcribed normally and the transcript is returned. The Shortcut never sees a failure.

**Setting the cap value:** spike #3 (TDD §13) measures the safe budget on a real device. The cap is then chosen as the largest round number at or under the safe budget (likely 60s, 2 min, or 5 min depending on what the spike reveals). All user-facing copy in PRD §5.4.1 is updated to match.

**v2 considerations:** if `BGProcessingTask` or a similar mechanism can extend background runtime safely, the cap may be raised or removed in a later release. v1 ships with whatever cap the spike justifies.

### 7.4 Error mapping

```swift
enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case permissionDenied
    case busy                       // recording lock held
    case interrupted                // phone call etc.
    case transcriptionFailed(String)

    var localizedStringResource: LocalizedStringResource {
        // human-readable strings for the Shortcuts error UI
    }
}
```

Errors are typed so the calling Shortcut can branch on them (e.g., retry on `.busy`, skip on `.permissionDenied`).

## 8. UI surfaces

### 8.1 `RecordingSheet` (AppIntent foreground UI)

Bound to `TranscriptionSession.state`. Renders:
- `.recording` → waveform + elapsed time + stop button + optional prompt text.
- `.processing` → progress bar/spinner + "Transcribing..." label.
- `.completed` / `.failed` → dismisses itself (control returns to Shortcut).

Presented as a `.sheet` from the app's root scene when the AppIntent escalates to foreground. Non-dismissable via swipe-down during `.processing` would be ideal, but iOS 26's sheet API allows swipe-down regardless — instead, the dismiss path is made safe via §5.8 (re-entry).

### 8.2 `RootView` (re-entry surface, PRD §5.8)

Same bindings as `RecordingSheet`. Renders:
- `.idle` → settings landing screen.
- `.recording` / `.processing` → identical UI to the recording sheet, in the root view.
- `.completed` → transcript preview, auto-returns to `.idle` after a few seconds.

The visual treatment is the same in both contexts so the user experiences continuity when transitioning from "AppIntent sheet" → "open app from springboard."

### 8.3 `SettingsView`

Reads/writes `UserDefaults`:
- `defaultSilenceThreshold: Double`
- `showUIByDefault: Bool` *(applied only as the default value the AppIntent suggests in the Shortcuts editor; the per-invocation parameter still wins)*
- Static: app version, WhisperKit attribution, privacy statement.

## 9. Permissions

`PermissionsService`:
- `microphoneStatus()` and `requestMicrophone()` wrap `AVAudioApplication.shared.recordPermission` / `requestRecordPermission`.
- Called by `TranscriptionSession.startRecording`; throws `SessionError.permissionDenied` if status is `.denied` or `.undetermined` cannot be resolved (the latter only happens if background context can't show a prompt — see §7.3).
- The app's first-run onboarding screen prompts the user to run the intent once in foreground, ensuring permission is granted before any background invocation is attempted.

## 10. Memory & performance budget

### 10.1 Audio buffer

16 kHz mono Float32 = 64 KB/sec. The PRD allows unlimited recording length but realistic ceiling for a single voice utterance is bounded by the user's patience and the device's available memory.

| Duration | RAM cost |
|---|---|
| 1 min | 3.75 MB |
| 5 min | 18.75 MB |
| 30 min | 112.5 MB |

At 30+ minutes, sustained recording starts to compete with WhisperKit's memory needs (model + activations on Neural Engine). In practice this is a non-issue in v1 because the documented max-duration cap (§7.3, PRD §5.4.1) is well under that range. As a defense in depth, `AudioRecorder` still monitors `os_proc_available_memory()` and surfaces a `.failed(.outOfMemory)` state if headroom drops below a safety threshold — a clean failure rather than an OOM kill.

### 10.2 Cold-start budget

Target: from AppIntent invocation to "recording started" indicator in <800ms on iPhone 14 (A16).
- Process launch: ~150–250ms.
- WhisperKit model loaded **lazily** — not on launch. Model load only blocks the *first* transcription, not the start of recording.
- Audio session activation: ~50–150ms.

The bulk of cold-start work is the OS launching the process; the app itself is small.

### 10.3 Transcription budget

PRD success criterion: <3s from "stop" to "transcript returned" for a 10-second utterance on A16+. WhisperKit medium on Neural Engine should comfortably hit this; the spike (§6.3) validates.

## 11. Testing strategy

- **Unit tests** (`WhisperIntentCoreTests`): `TranscriptionSession` state machine with mock recorder and mock transcriber. VAD with synthetic audio (silence, speech, mixed). Permissions service with mocked status.
- **Integration tests** (Xcode UI tests, limited): launch app, simulate AppIntent invocation via deeplink (Shortcuts can't easily be scripted in CI), verify state transitions in `RootView`.
- **Manual smoke tests** documented in `docs/QA.md`:
  - Invoke via Siri voice phrase.
  - Invoke via Action Button.
  - Invoke via Shortcuts app.
  - Invoke from lock screen.
  - Dismiss UI mid-recording, re-open from springboard.
  - Dismiss UI mid-transcription, re-open from springboard.
  - Phone-call interruption mid-recording.
  - Cold-boot, unlock, immediately trigger Siri phrase (verifies post-reboot first-unlock constraint).
- **TestFlight signals:** `permissionDenied` rate, `busy` rate, `transcriptionFailed` rate, and observed time-to-transcript distribution. Logged locally only; surfaced via a debug menu in TestFlight builds.

## 12. Build, ship, release

- One main app target, one Swift package (`WhisperIntentCore`).
- WhisperKit pinned to a specific version (lockfile committed).
- TestFlight builds gated behind a Fastlane lane; release builds the same.
- Symbol upload to Apple for crash reports.
- No third-party analytics. No third-party crash reporters.

## 13. Technical spikes — ordered

These are the explicit "answer this before implementing" tasks:

1. **WhisperKit medium progress callback granularity** (§6.3). Decides determinate vs indeterminate progress UI.
2. **iOS 26 AppIntents foreground-escalation API** (§7.2). Decides one-intent vs two-intents architecture.
3. **Background execution budget for `showUI = false`** (§7.3). Determines the value of the max-duration cap baked into v1. This is a load-bearing spike — the chosen number drives App Store description, AppIntent description, onboarding copy, and the recording UI's warning thresholds (PRD §5.4.1). Run on the lowest-spec supported device (iPhone with A-series chip oldest still on iOS 26) to avoid setting a cap that fails on older hardware.
4. **WhisperKit medium install size on a real device** (§6.1). Confirms install-size cost; informs whether ODR fallback is worth keeping as a backup plan.

Each spike produces a short note in `docs/spikes/` documenting findings; the TDD is updated based on what's learned.

## 14. Open questions deferred from PRD

- **App name conflicts** — to be resolved before submission.
- **Pricing** — not a technical question, but the App Store metadata setup must reflect the decision.
- **Bundle size impact on conversion** — needs real-world data after launch; revisit at first point release.

---

*End of draft. Once spikes 1–4 are complete, this document is updated and an implementation milestone plan (sprint-sized) is generated.*
