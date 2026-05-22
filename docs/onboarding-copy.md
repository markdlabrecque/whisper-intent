# First-Run Onboarding Copy

**Status:** Draft v0.1
**Last updated:** 2026-05-22
**Companion to:** [PRD.md §5.4.1, §5.7](PRD.md), [TDD §9](TDD.md)

This document is the copy deck for the first-run onboarding flow. It is shown the first time the user launches Whisper Intent and is not shown again unless the user resets onboarding from Settings.

The flow has three screens. Each has a single job. Total time-to-completion should be under 60 seconds including granting mic permission.

---

## Design principles for this copy

1. **Set the building-block expectation in the first sentence.** Users who don't get it in the first sentence won't read further, and they're the ones who'll leave the "this app doesn't do anything" review.
2. **No marketing fluff.** Power users see through it and resent it.
3. **No "tap continue to proceed" filler.** Every paragraph carries information the user needs.
4. **Cap and permission are introduced together** on the last screen, where they're action-paired with the test recording.
5. **No screenshots of competing apps**, no logos. Plain text and the system icons we have.

---

## Screen 1 — What this is

**Headline:**
> Whisper Intent is a building block.

**Body:**
> On its own, this app doesn't do much. It gives Apple Shortcuts a new step — **Transcribe Speech** — that records audio and returns the text. You wire it into whatever Shortcut you want: a reminder, a note, a message, a webhook, anything.
>
> If you're not already an Apple Shortcuts user, this app probably isn't for you.

**Primary button:** Continue
**Secondary button:** _(none)_

---

## Screen 2 — How you use it

**Headline:**
> Build the Shortcut you want.

**Body:**
> Open the Shortcuts app. Add **Transcribe Speech** as a step in any Shortcut you're building. The transcript becomes the input to whatever comes next.
>
> Example:
> &nbsp;&nbsp;&nbsp;1. Transcribe Speech
> &nbsp;&nbsp;&nbsp;2. Add New Reminder → use the transcribed text
>
> Trigger your Shortcut from Siri, the Action Button, a lock-screen widget, or anywhere else Shortcuts can run. Whisper Intent doesn't need to be open.

**Primary button:** Continue
**Secondary button:** _(none)_

---

## Screen 3 — Permission and a test

**Headline:**
> One quick test.

**Body:**
> Tap below and say a few words. This grants Whisper Intent permission to use the microphone, which is needed before any Shortcut can call it.
>
> Recordings stay on your device. Audio never leaves the iPhone, and Whisper Intent doesn't store transcripts. Each recording can be up to **{MAX_DURATION}** per invocation.

**Primary button:** Record a test
**Secondary button:** Skip for now

### When "Record a test" is tapped

The button invokes `TranscribeSpeechIntent` with `showUI = true` and a hidden prompt. The standard recording UI appears. iOS shows the system mic-permission prompt; user grants it; recording proceeds normally.

When the AppIntent returns, onboarding dismisses to a brief confirmation:

**Headline:**
> You're set.

**Body:**
> Whisper Intent will run when your Shortcuts call it.
>
> *(For ideas, see the examples in Settings.)*

**Primary button:** Done

### When "Skip for now" is tapped

Onboarding dismisses immediately to the main `RootView`. A small banner appears at the top: "Microphone permission is needed before Shortcuts can call Whisper Intent. [Grant permission]" — tapping the link invokes the same test-recording flow.

If the user denies the system mic-permission prompt, onboarding dismisses but the banner persists until permission is granted (the banner deep-links to Settings → Whisper Intent if the user has hard-denied).

---

## Placeholders

- `{MAX_DURATION}` — replaced at build time with the value chosen in spike S3. Likely "60 seconds," "2 minutes," or "5 minutes." If the spike concludes no cap is needed, this entire sentence in Screen 3 is removed.

---

## Tone notes

- Voice is direct, no marketing words. No "powerful," "seamless," "intelligent." No exclamation marks.
- Second person ("you wire it") not first person plural ("we built this").
- Where the app is doing less than the user might expect, say so explicitly. The "If you're not already an Apple Shortcuts user, this app probably isn't for you" line in Screen 1 is the most important sentence in this entire flow — it filters out the audience that will leave bad reviews.
- "iPhone" not "device." We're iPhone-only in v1.

## Accessibility

- All copy passes through the standard SwiftUI dynamic type and VoiceOver paths.
- The "Record a test" button has a VoiceOver label of "Record a test, grants microphone permission."
- The example numbered list in Screen 2 uses a real `<ol>`-equivalent structure (SwiftUI `LazyVStack` with semantic labels), not numbered text in a single paragraph — so VoiceOver reads it as a list.

## What this onboarding deliberately does not do

- It does not list integrations. The whole product is that the user picks their own.
- It does not have a "next time" carousel of features. There is one feature.
- It does not have a sign-in. There is no account.
- It does not collect any preference upfront. Settings come later, and only if the user wants to change defaults.

## Settings link target

Settings (the destination of "see examples in Settings" in the confirmation screen) contains the example Shortcut patterns listed in PRD §6, presented as plain text with the same numbered-list structure as Screen 2 above. They are documentation, not actionable buttons — the user copies the pattern into their own Shortcut.
