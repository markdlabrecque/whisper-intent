# App Store Listing — Draft

**Status:** Draft v0.1 — cap value pending S3
**Last updated:** 2026-05-22
**Companion to:** [PRD.md §8](PRD.md), [MILESTONES.md M6/M7](MILESTONES.md)

This document is the copy deck for the App Store Connect listing. Numbers in the table below are Apple's hard character limits; nothing here exceeds them. Substitute `{MAX_DURATION}` at submission time with the value chosen in spike S3 (PRD §5.4.1).

| Field | Limit | Used |
|---|---|---|
| App name | 30 | 14 |
| Subtitle | 30 | 28 |
| Promotional text | 170 | (see below) |
| Keywords | 100 | (see below) |
| Description | 4000 | (see below) |

---

## App name

> **Whisper Intent**

## Subtitle

> **Voice capture for Shortcuts**

_(Alternatives considered: "Voice input, your way" — too vague. "On-device dictation for Shortcuts" — accurate but cedes the headline to "Shortcuts" rather than the unique angle.)_

## Promotional text

_Updateable without a new build. Use this slot for any timely positioning._

> A voice input step you can drop into any Apple Shortcut. Records on-device with WhisperKit and returns the transcript as text. No cloud. No accounts.

_(165 / 170 chars.)_

## Keywords

_Comma-separated, no spaces after commas (Apple counts them). Order doesn't affect ranking; presence does._

> shortcuts,dictation,voice,transcription,whisperkit,whisper,speech,offline,reminders,automation

_(99 / 100 chars.)_

## Description

> **Whisper Intent is a building block, not a finished app.**
>
> It gives Apple Shortcuts a new step — **Transcribe Speech** — that records audio on your iPhone and returns the text. You wire that text into whatever Shortcut you're building: a reminder, a note, a message, a webhook, a third-party task manager, anything that accepts text from Shortcuts.
>
> If you're not already an Apple Shortcuts user, this app probably isn't for you.
>
>
> **HOW IT WORKS**
>
> Open the Shortcuts app. Add Transcribe Speech as a step in your Shortcut. The transcript becomes the input to the next step.
>
> Example:
> 1. Transcribe Speech
> 2. Add New Reminder — use the transcribed text
>
> Trigger your Shortcut from Siri, the Action Button, a Home Screen icon, a Lock Screen widget, Back Tap, or any other Shortcuts surface. Whisper Intent doesn't need to be open — iOS launches it on demand.
>
>
> **THE TRANSCRIBE SPEECH STEP**
>
> Three optional parameters per invocation:
>
> • **Silence threshold.** How long of a pause auto-ends the recording. Default 2 seconds.
> • **Show UI.** Whether to show a recording sheet, or run silently with only the system microphone indicator.
> • **Prompt.** Optional hint text shown above the recording sheet.
>
> Returns a single Text value: the transcript.
>
>
> **PRIVACY**
>
> Everything runs on your iPhone. Audio never leaves the device, and Whisper Intent does not store transcripts. There are no accounts, no analytics, no third-party SDKs.
>
> App Store Privacy: Data Not Collected.
>
>
> **WHAT IT DOESN'T INCLUDE**
>
> Whisper Intent does not ship with any pre-built Shortcuts, templates, or destination integrations. The point is that you build the Shortcut you want. The app on its own does almost nothing.
>
>
> **RECORDING LENGTH**
>
> Up to {MAX_DURATION} per invocation. The cap exists to keep background invocations reliable across all supported devices.
>
>
> **REQUIREMENTS**
>
> • iPhone running iOS 26 or later
> • Microphone permission (requested on first use)
>
>
> **POWERED BY WHISPERKIT**
>
> Transcription uses WhisperKit by Argmax, which runs OpenAI's Whisper model on Apple's Neural Engine. The hard part of this app is theirs; Whisper Intent is the Shortcuts plumbing around it.

_(approximate length: ~1,950 chars of 4,000.)_

## "What's New in This Version" — v1.0

> First release. Adds the Transcribe Speech step to Apple Shortcuts.

## Category

- **Primary:** Productivity
- **Secondary:** Utilities

## Age rating

- 4+

## Pricing

- Free
- No in-app purchases

## Support URL

- _(TBD — likely a GitHub Pages or simple static page)_

## Marketing URL

- _(optional, can leave blank for v1)_

## Privacy policy URL

- _(TBD — one-page static document, "Data Not Collected" plus contact email)_

---

## Screenshots

Apple requires screenshots at the 6.7" iPhone size. Five recommended, in this order:

1. **Cover screen** — large text "A voice step for Apple Shortcuts" + subtitle "On-device. No accounts." Visual: minimal, brand-mark + a microphone icon.
2. **Shortcuts editor view** — a screenshot of the Shortcuts app editor showing the Transcribe Speech step inserted between two other steps. Caption: "Drop it into any Shortcut."
3. **Recording sheet** — the in-app recording UI mid-capture, with waveform and stop button. Caption: "On-device dictation, full sentence."
4. **Processing sheet** — the processing indicator (determinate bar or spinner depending on S1 outcome). Caption: "Transcript ready in seconds."
5. **Privacy callout** — a plain text screen reading "Audio never leaves your iPhone. Whisper Intent stores nothing. No accounts. No analytics." Caption: "Privacy is the point."

Avoid: stock-photo people, fake transcripts that look like ads, anything cute. The audience is power users; they read the screenshots as documentation, not advertising.

---

## App Review notes (for the App Store reviewer)

_Provided in the App Store Connect "Notes for the Reviewer" field._

> Whisper Intent is a building-block utility for Apple Shortcuts. The app's primary purpose is to expose a single App Intent (Transcribe Speech) that other Shortcuts can call.
>
> To test:
> 1. Open the Shortcuts app on the test device.
> 2. Create a new Shortcut.
> 3. Add the "Transcribe Speech" action (provided by Whisper Intent).
> 4. Run the Shortcut and speak a short phrase.
> 5. The transcript is returned to the Shortcut as a Text value.
>
> The app itself, when opened directly, shows a brief Settings screen and an explanation of how to use it from Shortcuts. This is by design — it is not a standalone dictation app.
>
> All transcription is performed on-device via the WhisperKit library. No network calls are made by Whisper Intent.

---

## Substitutions before submission

- `{MAX_DURATION}` — replaced with the v1 cap value chosen in S3. If S3 determines no cap is needed, remove the entire "Recording Length" section from the description.
- Support and Privacy URLs — published before M7 submission.
- Screenshots — produced during M6 against a real device build.

## Anti-checklist (things deliberately omitted)

- No comparison to other apps. Never mention competitors.
- No "powered by AI" framing in the headline. WhisperKit is credited in its own section, not as a buzzword.
- No bullet-list of "features." This is a one-feature app.
- No emoji in the description. The audience reads it like documentation.
- No "v2 coming soon" teasers. v1 is the product.
