# App Store Privacy Nutrition Label — Whisper Intent

**Status:** Final for v1
**Last updated:** 2026-05-25
**Companion to:** [PRD §7](PRD.md), [privacy-policy.md](privacy-policy.md)

Pre-answers every field in App Store Connect → App Privacy. Whisper Intent's nutrition label is the trivial case: **Data Not Collected**. The detail here exists so the submission form is filled out from a single page rather than re-derived under time pressure.

If a future version adds any data collection, update this file *before* updating the form, so the change is documented.

---

## Summary line shown on the App Store listing

> **Data Not Collected**
> The developer does not collect any data from this app.

## Form selections

### Does this app collect data?

> **No, we do not collect data from this app.**

Selecting this option closes out the rest of the form. The form will ask one confirmation question:

### Confirm

> The developer has confirmed that this app does not collect any data.

Confirm: yes.

---

## Reasoning, per Apple's categories

Apple's privacy form enumerates data types under 14 categories. Each is "Not Collected" for Whisper Intent. The justifications below are recorded here so any future review can reproduce the answer.

| Category | Subtypes considered | Collected? | Why not |
|---|---|---|---|
| Contact Info | Name, email, phone, address, etc. | No | App has no accounts, no forms, no contact capture. |
| Health & Fitness | Health, fitness | No | Not a health app. |
| Financial Info | Payment, credit, financial details | No | Free app, no IAP, no payment flows. |
| Location | Precise, coarse | No | Location is never read. No `NSLocationWhenInUseUsageDescription` in `Info.plist`. |
| Sensitive Info | Race, religion, sexual orientation, etc. | No | Not collected, not inferred. |
| Contacts | Address book | No | Contacts entitlement not requested. |
| User Content | Email/text content, photos, videos, **audio**, gameplay, customer support, other | No | **Important nuance:** audio is *processed in memory* during transcription, but the developer does not *collect* it — nothing is sent off-device, written to disk by Whisper Intent, or retained after the recording ends. Apple's definition of "collect" requires the data to leave the user's device or be persisted by the developer. Neither applies here. |
| Browsing History | Web/app history | No | No tracking. |
| Search History | Searches in the app | No | App has no search feature. |
| Identifiers | User ID, device ID | No | No analytics SDK, no IDFA, no custom IDs. |
| Purchases | Purchase history | No | No purchases. |
| Usage Data | Product interaction, advertising data, other | No | No telemetry. The Apple-level "Share with App Developers" toggle controls Apple's anonymized crash reporting — that's covered by Apple's own privacy posture, not the app's. |
| Diagnostics | Crash, performance, other diagnostic | No | Whisper Intent has no third-party crash reporter. Apple's optional system-level crash sharing is the user's decision, surfaced in iOS Settings, not in the app. |
| Other Data | Anything not above | No | n/a |

---

## Notes for the App Review reviewer

The reviewer may ask why microphone permission is requested if no data is collected. The short answer:

> Microphone permission is required to record audio during a transcription session. Audio is processed on-device by WhisperKit and is never sent to any server, written to persistent storage, or retained beyond the active recording. The transcript is returned to the calling Shortcut and immediately released by Whisper Intent.

This is consistent with the Privacy Policy at the URL provided in the App Store Connect record and with the Info.plist `NSMicrophoneUsageDescription` string.

---

## Maintenance

- This file must be re-verified before every App Store submission. If any answer changes, update both this file and the App Store Connect form in the same session.
- If a future version adds a third-party SDK, *that SDK's* data collection becomes the app's data collection — re-evaluate every row above.
- The privacy nutrition label is independent of `Info.plist` privacy strings; both must be consistent.
