# Spike S4: WhisperKit medium install size on a real device

**Status:** Complete (provisional — thinned/installed numbers deferred to M6)
**Owner:** Mark Labrecque
**Started:** 2026-05-22
**Completed:** 2026-05-22
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

A 1.35 GB fat IPA is large for a utility app but defensible for an enthusiast tool that promises fully-offline, on-device speech recognition. Two facts shape this:

- **The 200 MB cellular threshold is unreachable** with the medium model bundled — first installs and updates over cellular will require either Wi-Fi or an explicit "Download Anyway" tap. This is a real onboarding friction but not a blocker for the target audience (power users adding the Shortcut deliberately).
- **App Store per-device thinning will reduce this number meaningfully**, but the bulk of the payload is two Core ML model directories that are not architecture-thinnable in the same way an executable slice is. The thinned numbers (M6) are unlikely to drop below ~1 GB.

No obvious low-effort wins in the bundle: app binary is 2.5 MB; everything else is the model. Meaningful reductions would require switching to a smaller/quantized model variant, which would change S1's transcription quality input — out of scope for v1.

## 6. Decision

**Proceed with bundling (Option A).**

Install size is acceptable for the v1 target audience. PRD §4's "no first-run download" commitment stands. Thinned download size and on-device installed size are deferred to M6, when the first TestFlight upload happens. If the M6 numbers come in dramatically worse than expected (e.g. >2 GB installed, or App Store review pushback), the fallback is to bundle a smaller model variant rather than switch to On-Demand Resources — ODR would contradict the "no first-run download" promise that anchors the whole product.

**Updates required in other docs:**
- [x] TDD §6.1 — pin the chosen option (Option A confirmed).
- [ ] Risk register in MILESTONES.md — downgrade the "install size too large" risk from open to monitoring; re-evaluate at M6 with thinned numbers.
- [ ] App Store description copy (later, in M6) — call out the size + Wi-Fi requirement so the first-install experience isn't a surprise.

## 7. Follow-ups

- **M3:** Fix the bundle-resource flattening — `.mlmodelc` directories currently land at the root of the `.app` instead of `Models/openai_whisper-medium/`. WhisperKit's loader will not find them as-is.
- **M6:** Record App Store Connect thinned download size (A16, A17) and on-device installed size; close out this spike doc's deferred rows.
- **M6:** Decide whether to ship a "Download over Wi-Fi only" hint in App Store metadata given the cellular threshold is exceeded.
