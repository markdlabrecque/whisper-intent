# Whisper Intent

**Voice capture as a Shortcuts building block.** On-device speech-to-text for iPhone, exposed as a single App Intent you can drop into any Apple Shortcut.

---

## What it is

Whisper Intent gives Apple Shortcuts a missing primitive: a voice input step that captures audio, transcribes it on-device using [WhisperKit](https://github.com/argmaxinc/WhisperKit), and returns the transcript as text for the rest of your Shortcut to use.

You wire the captured text into whatever destination you want — Reminders, Notes, Messages, Drafts, a webhook, a third-party task manager, anything that accepts a string from Shortcuts.

## What it isn't

Whisper Intent does **not** ship with any pre-built Shortcuts, templates, or destination integrations. The app itself, opened on its own, does almost nothing — it's a building block, not a finished product.

If you want a "voice → Reminder" tap shortcut, you build that Shortcut yourself in 30 seconds using the `Transcribe Speech` step Whisper Intent provides. That's the entire design philosophy.

If you're not already an Apple Shortcuts user, this app is probably not for you.

## How it works

```
[ your trigger ]  →  Transcribe Speech  →  [ your destination ]
   Siri phrase                                 Add to Reminders
   Action Button                               Append to Note
   Home-screen icon                            Send Message
   Lock-screen widget                          POST to webhook
   Back Tap                                    …anything
```

The `Transcribe Speech` step takes three optional parameters:
- **Silence threshold** — how long of a pause auto-ends the recording (default 2 seconds).
- **Show UI** — whether to show Whisper Intent's recording UI, or run silently with only the system mic indicator.
- **Prompt** — optional text shown above the recording UI ("What's the reminder?").

It returns a single `Text` value: the transcript.

## Example Shortcuts (you build these)

The app doesn't ship these — they're illustrations of patterns you can build yourself in the Shortcuts app.

**Quick Reminder**
1. `Transcribe Speech` (Show UI = on)
2. `Add new reminder` → use *Transcribed Text* as the title

**Silent Note Capture**
1. `Transcribe Speech` (Show UI = off, Silence threshold = 1.5s)
2. `Append to note` → "Inbox"

**Send to a Webhook**
1. `Transcribe Speech` (Show UI = on)
2. `Get contents of URL` → POST to your endpoint with the transcript as the body

Trigger any of these from Siri ("Hey Siri, quick reminder"), the Action Button, a lock-screen widget, or any other Shortcuts surface. Whisper Intent doesn't need to be open — iOS launches it on demand.

## Privacy

- All audio and transcription stays on the device. Audio never leaves the iPhone.
- Transcripts are not stored by Whisper Intent. They live in memory only long enough to return to your Shortcut.
- No analytics, no third-party SDKs, no accounts. App Store privacy label: **Data Not Collected**.

## Requirements

- iPhone running iOS 26 or later.
- Microphone permission (requested on first use).

## Recording length

A documented per-invocation recording cap applies to keep background invocations reliable across all supported devices. The cap is communicated in-app and in the recording UI. _(Specific value pending — see [docs/spikes/S3-background-budget.md](docs/spikes/S3-background-budget.md).)_

## Status

In development. The product specification and technical design are tracked in this repo:

- [`docs/PRD.md`](docs/PRD.md) — product requirements
- [`docs/TDD.md`](docs/TDD.md) — technical design
- [`docs/MILESTONES.md`](docs/MILESTONES.md) — delivery plan, spike-driven
- [`docs/spikes/`](docs/spikes/) — technical investigation reports

## Acknowledgements

Whisper Intent stands on top of [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax — a Swift package that makes OpenAI's Whisper models run efficiently on Apple's Neural Engine. The hard part of this app is theirs; Whisper Intent is just the Shortcuts plumbing around it.

## License

_(TBD)_
