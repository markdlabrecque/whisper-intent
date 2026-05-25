# TestFlight — What to Test

**Status:** Draft v0.1, for the v1.0 beta
**Last updated:** 2026-05-25
**Companion to:** [M6 test plan](M6-test-plan.md)

Copy paste this into the TestFlight "What to Test" field when uploading a build. The audience is the 10–25 Shortcuts power users on the external beta, not engineers — so the prose is practical, not formal.

If the next build changes meaningfully, update the dated section at the bottom rather than rewriting from scratch.

---

## What to test — paste into TestFlight

> Thanks for testing Whisper Intent. The app gives Apple Shortcuts a new step called **Transcribe Speech**: it records audio on your iPhone and returns the transcript. You wire that into whatever Shortcut you want — a reminder, a note, a webhook, anything.
>
> Whisper Intent doesn't ship any pre-built Shortcuts. You build the Shortcut you want, with Transcribe Speech as one of its steps. **If you don't already use Apple Shortcuts, this app probably isn't for you** — please pass the invite on.
>
> **What we want you to try:**
>
> 1. Build a Shortcut that uses Transcribe Speech and pipes the output somewhere useful to you. A "voice → reminder" Shortcut is the canonical example, but anything works.
> 2. Trigger your Shortcut multiple ways: Siri, the Action Button, a Home Screen icon, a lock screen widget. Try the spots you actually use.
> 3. Try with `Show UI` both on and off. The "off" mode runs entirely from background — no app launch, just the system mic indicator.
> 4. Run it after the phone has been idle for a while (lock screen, hours later). Some routing surfaces behave differently after a long idle.
> 5. If you can: a phone call mid-recording. We want to know it fails cleanly, not silently.
>
> **What we're listening for:**
>
> - Did Transcribe Speech land transcripts that were good enough for the task you used it for? Whisper medium is what's running — accurate but not perfect.
> - Did anything hang, return a generic error, or behave weirdly after a long delay?
> - Did the recording UI feel like the right level of "in your face" — too much, too little, right?
> - Was the cap on recording length ever in your way?
>
> **What we're *not* asking about for v1:**
>
> - Languages other than English. Whisper Intent is English-only for v1; multilingual is on the v2 list.
> - Pause/resume mid-recording. Not in v1 — also v2 list.
> - A determinate progress bar during transcription. WhisperKit doesn't expose the right hook for v1; the indeterminate spinner is intentional.
> - Apple Watch or iPad. iPhone only for v1.
>
> **Where to send feedback:**
>
> Use the TestFlight "Send Beta Feedback" button. A short paragraph plus a screenshot beats a long structured report — we'll follow up if we need more.
>
> Thanks for the early signal. — Mark

---

## Internal notes (not part of the TestFlight copy)

- The "what we want you to try" list deliberately puts Shortcut-building first. If a tester doesn't get past step 1, they're not the audience and that's useful data.
- The "what we're not asking about" list is load-bearing. Beta testers will report missing features as bugs unless we explicitly say which absences are intentional.
- The phone-call mid-recording ask in step 5 is a request, not a requirement. We can't ask non-engineers to test interrupt handling reliably — but if anyone happens to hit it, the data is gold.
- Don't list specific cap numbers in this copy until S3 closes. The "Was the cap on recording length ever in your way?" wording works either way.

## Per-build update slot

Append a dated subsection here when subsequent builds need targeted callouts.

### Build 1 (initial beta)

_Nothing build-specific; the full list above applies._
