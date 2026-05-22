# Spike S4: WhisperKit medium install size on a real device

**Status:** In progress
**Owner:** Mark Labrecque
**Started:** 2026-05-22
**Completed:**
**Linked from:** [TDD §6.1](../TDD.md), [MILESTONES.md M1](../MILESTONES.md)

---

## 1. Question

What is the actual on-device install size, and the App Store download size, of a Whisper Intent build that bundles the WhisperKit medium model?

## 2. Why it matters

PRD §4 commits to "no first-run download." TDD §6.1 chose bundling (Option A) over On-Demand Resources (Option B) to honor that commitment. But the WhisperKit medium model is ~1.5 GB of `.mlmodelc` data, and the actual delivered size depends on App Store thinning, compression, and packaging choices we haven't tested. Cost of guessing wrong: if the download size is large enough to hurt App Store conversion (or worse, block App Store submission), we need to fall back to ODR — and that contradicts the PRD goal. Better to know in M1 than to discover at M7.

## 3. Method

1. Verify WhisperKit medium model files are present in `Resources/Models/openai_whisper-medium/`.
2. Build a Release archive of the app via `xcodebuild archive`.
3. Export the IPA. Measure its size on disk.
4. Upload the build to TestFlight.
5. Once App Store Connect finishes processing, record the reported **download size** and **install size** for representative device families (iPhone 14, iPhone 15 Pro, etc.).
6. Install on a real device. Measure size shown in Settings → General → iPhone Storage → Whisper Intent.
7. Note: App Store uses per-device thinning — sizes may differ between A16 and A17 builds. Capture both if both are available.

**Test environment:**
- Device(s): one iPhone for installed-size measurement (pending).
- iOS version: latest 26.x.
- Xcode version: (recorded at archive time)
- Submitting from: Mac mini / macOS 15.x.

## 4. Raw findings

| Metric | Value |
|---|---|
| Local IPA file size | **1.35 GB** (1,413,707,355 bytes; 1,348 MB) |
| Signed `.app` bundle on disk | **1.4 GB** (TextDecoder 872 MB + AudioEncoder 586 MB + binary 2.5 MB) |
| App Store download size (A16 thinned) | _pending TestFlight upload_ |
| App Store download size (A17 thinned) | _pending TestFlight upload_ |
| Installed size on device | _pending TestFlight install_ |
| Cellular download limit reached? (200 MB threshold) | **yes** (1.35 GB ≫ 200 MB) |

**Method used for local IPA measurement:**
- `xcodebuild archive` on Release, generic/platform=iOS, code-signed (Team `QS946Z5WWB`).
- `xcodebuild -exportArchive` with `method=development`, `thinning=<none>` (fat IPA, no App Store thinning applied).
- The number above is therefore an **upper bound** on what the App Store will deliver; per-device thinned variants in ASC will be smaller.

**Packaging note (M3 concern, not S4-blocking):**
The `.mlmodelc` directories landed at the **root** of the `.app` bundle rather than at `Models/openai_whisper-medium/`. Xcode's "Copy Bundle Resources" phase is flattening the directory structure. WhisperKit's runtime loader expects models at a path like `<bundle>/openai_whisper-medium/`. Fix needed before M3: declare the model directory as a folder reference in `project.yml` (e.g. via `buildPhase: resources` with `type: folder`) so XcodeGen preserves the hierarchy. Does not change the install-size number.

_(App Store imposes a 200 MB cellular download limit; over that, users must be on Wi-Fi or explicitly opt in. This matters for first-launch experience.)_

## 5. Interpretation

_(is the download size in a defensible range for an enthusiast utility? does it cross the cellular threshold? are there any obvious wins — model file format, dead resources, asset catalog opportunities — that would meaningfully shrink it?)_

## 6. Decision

_Pick one:_

- **Proceed with bundling (Option A).** Install size is acceptable for the target audience. PRD and TDD stand.
- **Fall back to On-Demand Resources (Option B).** Install size is impractical. Accept the first-run download UX cost; update PRD §4 and TDD §6.1.
- **Proceed with bundling, but optimize.** Bundle now, but track size reduction work (e.g., switching to a quantized model variant, dropping unused languages) as a v1.x follow-up.

**Updates required in other docs:**
- [ ] TDD §6.1 — pin the chosen option.
- [ ] PRD §4 (if Option B) — document the first-run download.
- [ ] Onboarding screen copy (if Option B) — explain the download.
- [ ] Risk register in MILESTONES.md — close or update the "install size too large" risk.

## 7. Follow-ups

-
