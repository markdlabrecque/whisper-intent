# Privacy Policy

**Effective date:** _(set on publication, before App Store submission)_
**App:** Whisper Intent for iPhone
**Publisher:** Mark Labrecque
**Contact:** mark@affinitybridge.com

---

## The short version

Whisper Intent does not collect any data about you.

Audio you record is transcribed on your iPhone and is never transmitted off the device. Transcripts are returned to the Apple Shortcut that called Whisper Intent and are not stored by Whisper Intent itself. There are no accounts, no analytics, no third-party tracking, and no advertising identifiers.

The rest of this document explains that statement in detail.

---

## What Whisper Intent does

Whisper Intent provides a single Apple Shortcuts action called **Transcribe Speech**. When an Apple Shortcut runs this action, Whisper Intent:

1. Records audio from the iPhone's microphone for the duration of the recording.
2. Converts that audio into text using the WhisperKit library, which runs entirely on the iPhone.
3. Returns the text to the Shortcut that called the action.
4. Discards the audio buffer and the text from memory.

Whisper Intent does not perform any other data processing.

## Data that leaves your iPhone

**None.** Whisper Intent makes no network requests. Audio recordings, transcripts, and any text derived from them are processed only on your iPhone. We have no servers, and Whisper Intent is not configured to communicate with any third party.

## Data that is stored on your iPhone

Whisper Intent stores only the following on your iPhone, all in standard iOS storage that is sandboxed to the app:

- Your settings for default recording behavior (currently: silence threshold).
- The WhisperKit model files that ship with the app, used for on-device transcription.

Whisper Intent does **not** store:
- Audio recordings.
- Transcripts of recordings.
- Logs of when, where, or how you used the app.

## Microphone access

Whisper Intent requests permission to use the microphone. This permission is required for the Transcribe Speech action to function. The microphone is used only while a recording is actively in progress.

You can revoke microphone access at any time in **Settings → Whisper Intent → Microphone**. Doing so will cause the Transcribe Speech action to fail until permission is restored.

## Crash reports

If you have enabled "Share with App Developers" in **Settings → Privacy & Security → Analytics & Improvements**, Apple may send anonymized crash reports for Whisper Intent to the developer. These reports are provided by Apple, are not personally identifying, and contain only technical information about the crash (stack traces, device model, iOS version).

You can disable this in your iPhone's system settings. Whisper Intent itself has no separate analytics or crash-reporting integration.

## Children

Whisper Intent is not directed at children under the age of 13 and does not knowingly collect any information from them. Because Whisper Intent does not collect information from anyone, this point is somewhat academic, but it is included for clarity.

## Third-party software

Whisper Intent uses the open-source **WhisperKit** library by Argmax, which runs OpenAI's Whisper speech-recognition model on Apple's Neural Engine. WhisperKit is included as a software library bundled inside the app. It is **not** a third-party service: it does not make network calls, communicate with Argmax, or report any data anywhere. It is code that runs locally on your iPhone, like any other library inside the app.

Whisper Intent uses no other third-party SDKs.

## Your rights

Because Whisper Intent does not collect or store data about you, there is no data to request, export, or delete. If you uninstall the app, all settings and the bundled WhisperKit model are removed from your iPhone by iOS.

If you have questions about this policy, you can contact mark@affinitybridge.com.

## Changes to this policy

If this policy is updated, the new version will be published at the same URL as this document, and the **Effective date** at the top will be updated.

Because Whisper Intent does not collect contact information from users, there is no mailing list to notify of changes. Users who want to track policy changes can watch the public repository at _(repository URL TBD before publication)_.

## Jurisdictions

This policy is written to be accurate under United States, European Union (GDPR), and California (CCPA) privacy frameworks. The simplifying factor is that Whisper Intent does not collect personal data; most jurisdictional requirements concern the handling of personal data, and there is none here to handle.

---

_Whisper Intent is an independent app. It is not affiliated with or endorsed by Apple Inc., OpenAI, or Argmax._
