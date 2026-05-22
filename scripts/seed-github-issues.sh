#!/usr/bin/env bash
# Seed GitHub milestones and issues for Whisper Intent.
#
# One-shot setup: creates 7 milestones (M1–M7) mirroring docs/MILESTONES.md
# and 11 issues (4 spikes + 7 milestone trackers), each assigned to its
# milestone.
#
# Prerequisite: GH_TOKEN (or `gh auth login`) must have permission to
# create issues and milestones on markdlabrecque/whisper-intent. For a
# fine-grained PAT this means:
#   - Repository access: includes whisper-intent
#   - Repository permissions → Issues: Read and write
#
# Idempotency: the script does NOT check for existing milestones/issues.
# Run it once on an empty repo. If a partial run created some entries,
# delete them via the GitHub UI before re-running.

set -euo pipefail

REPO="markdlabrecque/whisper-intent"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }
}
require gh
require jq

echo "Verifying access to $REPO …"
gh api "repos/$REPO" --jq '.full_name' >/dev/null

# ---------------------------------------------------------------------------
# Milestones
# ---------------------------------------------------------------------------

create_milestone() {
  local title="$1"
  local description="$2"
  gh api "repos/$REPO/milestones" \
    -f title="$title" \
    -f description="$description" \
    -f state=open >/dev/null
  printf '%s' "$title"
}

echo "Creating milestones …"
M1=$(create_milestone "M1 — Spike S4: install size" \
  "Measure WhisperKit medium install size; decide bundling vs ODR. See docs/MILESTONES.md M1.")
M2=$(create_milestone "M2 — Spikes S1 + S2" \
  "Progress callback granularity (S1) and AppIntents foreground-escalation API (S2). See docs/MILESTONES.md M2.")
M3=$(create_milestone "M3 — Core domain implementation" \
  "TranscriptionSession + AudioRecorder + VAD + WhisperKitTranscriber + Permissions. See docs/MILESTONES.md M3.")
M4=$(create_milestone "M4 — Spike S3: background budget" \
  "Determine max-duration cap value via real end-to-end pipeline. See docs/MILESTONES.md M4.")
M5=$(create_milestone "M5 — AppIntent + UI surfaces" \
  "TranscribeSpeechIntent, RecordingSheet, RootView re-entry, SettingsView, OnboardingView. See docs/MILESTONES.md M5.")
M6=$(create_milestone "M6 — Hardening + TestFlight" \
  "Manual smoke matrix, App Store Connect record, real app icon + screenshots, privacy policy hosting, TestFlight beta. See docs/MILESTONES.md M6.")
M7=$(create_milestone "M7 — v1 GA" \
  "App Store submission and post-launch monitoring. See docs/MILESTONES.md M7.")

echo "Milestones created."

# ---------------------------------------------------------------------------
# Issues
# ---------------------------------------------------------------------------

create_issue() {
  local title="$1"
  local milestone_title="$2"
  local body="$3"
  gh issue create --repo "$REPO" \
    --title "$title" \
    --milestone "$milestone_title" \
    --body "$body" >/dev/null
  echo "  ✓ $title"
}

echo "Creating spike issues …"

create_issue "Spike S4: WhisperKit medium install size on a real device" "$M1" \
"Measure install size and download size of a build that bundles the WhisperKit medium model.

**Decides:** whether to ship bundled (TDD §6.1 Option A) or fall back to On-Demand Resources.

**Method, exit criteria, decision log:** see [docs/spikes/S4-install-size.md](../blob/main/docs/spikes/S4-install-size.md).

**Updates required on close:** PRD §4, TDD §6.1, onboarding copy (if Option B), risk register."

create_issue "Spike S1: WhisperKit medium progress callback granularity" "$M2" \
"Determine whether v1 ships a determinate progress bar or an indeterminate spinner with phase labels.

**Decides:** which TranscriptionProgress case is the active one (the other gets removed).

**Method, exit criteria, decision log:** see [docs/spikes/S1-progress-callbacks.md](../blob/main/docs/spikes/S1-progress-callbacks.md).

**Updates required on close:** TDD §6.3, PRD §5.6, RecordingSheet wireframes."

create_issue "Spike S2: iOS 26 AppIntents foreground-escalation API" "$M2" \
"Determine whether a single AppIntent can programmatically escalate to a foreground UI based on a Show UI parameter, or whether v1 must ship two distinct AppIntents.

**Decides:** TDD §7.2 architecture (Option A two-intent vs Option B one-intent).

**Method, exit criteria, decision log:** see [docs/spikes/S2-foreground-escalation.md](../blob/main/docs/spikes/S2-foreground-escalation.md).

**Updates required on close:** TDD §7.1 + §7.2, PRD §5.1 if two-intent."

create_issue "Spike S3: Background execution budget & max-duration cap" "$M4" \
"Determine the longest reliable recording-plus-transcription wall-clock time on the oldest iOS 26-capable iPhone.

**Decides:** the numeric value of the v1 max-duration cap (PRD §5.4.1) — drives App Store description, AppIntent description, onboarding copy, recording UI warning thresholds.

**Method, exit criteria, decision log:** see [docs/spikes/S3-background-budget.md](../blob/main/docs/spikes/S3-background-budget.md).

**Escalation:** if the cap has to be <30 s, pause and reopen the product conversation before continuing to M5.

**Updates required on close:** PRD §5.4.1, TDD §7.3, all user-facing copy."

echo "Creating milestone tracker issues …"

create_issue "M1 — Spike S4: install size" "$M1" \
"Tracker for [M1 in docs/MILESTONES.md](../blob/main/docs/MILESTONES.md).

### Tasks
- [ ] Bundle WhisperKit medium model in App/WhisperIntent/Resources/Models/
- [ ] Build Release IPA and upload to TestFlight (or local archive if no ASC record yet)
- [ ] Measure local IPA size + App Store Connect download size + on-device installed size
- [ ] Decide bundling vs ODR
- [ ] Complete docs/spikes/S4-install-size.md report

### Exit criterion
Documented install size with App Store download number. Decision recorded (bundle vs ODR)."

create_issue "M2 — Spikes S1 + S2" "$M2" \
"Tracker for [M2 in docs/MILESTONES.md](../blob/main/docs/MILESTONES.md). Two parallel spikes.

### Tasks
- [ ] S1: progress-callback harness + report (see issue for S1)
- [ ] S2: foreground-escalation HelloIntent + report (see issue for S2)
- [ ] Update TDD §6.3 and §7.2 based on both outcomes

### Exit criterion
Both spike reports complete; TranscriptionProgress narrowed; AppIntent architecture decided."

create_issue "M3 — Core domain implementation" "$M3" \
"Tracker for [M3 in docs/MILESTONES.md](../blob/main/docs/MILESTONES.md).

### Tasks
- [ ] Implement TranscriptionSession state machine (replacing M0 stubs)
- [ ] Implement AudioRecorder over AVAudioEngine
- [ ] Implement VoiceActivityDetector (energy-based)
- [ ] Implement WhisperKitTranscriber adapter
- [ ] Implement PermissionsService
- [ ] Unit-test session state transitions with mocked recorder + transcriber

### Exit criterion
WhisperIntentCore can record from a real mic, transcribe via WhisperKit medium, and emit a final transcript string — all driven by TranscriptionSession, verified on a real device via a debug button."

create_issue "M4 — Spike S3: background budget" "$M4" \
"Tracker for [M4 in docs/MILESTONES.md](../blob/main/docs/MILESTONES.md).

### Tasks
- [ ] Wire minimal TranscribeSpeechIntent to drive TranscriptionSession with showUI=false
- [ ] Run S3 spike measurements on oldest iOS 26 device
- [ ] Choose max-duration cap value
- [ ] Propagate cap value to PRD §5.4.1, TDD §7.3, and all user-facing copy slots

### Exit criterion
v1 max-duration cap value chosen and pinned in code + docs."

create_issue "M5 — AppIntent + UI surfaces" "$M5" \
"Tracker for [M5 in docs/MILESTONES.md](../blob/main/docs/MILESTONES.md).

### Tasks
- [ ] Implement TranscribeSpeechIntent perform() with architecture from S2
- [ ] Implement IntentError mapping
- [ ] Enforce max-duration cap in AudioRecorder
- [ ] Implement RecordingSheet (waveform + stop button + processing indicator)
- [ ] Implement RootView re-entry (PRD §5.8)
- [ ] Implement SettingsView (defaults + attribution)
- [ ] Implement OnboardingView (3-screen flow from docs/onboarding-copy.md)

### Exit criterion
End-to-end demo: install TestFlight build, create Shortcut that calls Transcribe Speech, trigger from Siri/Action Button, get transcript back into Shortcut. All invocation surfaces from TDD §5.2 work."

create_issue "M6 — Hardening + TestFlight" "$M6" \
"Tracker for [M6 in docs/MILESTONES.md](../blob/main/docs/MILESTONES.md).

### Tasks
- [ ] Complete manual smoke test matrix from TDD §11 on newest + oldest devices
- [ ] Verify phone-call interruption → clean .interrupted failure
- [ ] Verify dismiss-and-reopen in every state
- [ ] Verify post-reboot first-unlock behavior
- [ ] Memory profile a 5-min recording at the cap
- [ ] Create App Store Connect record (deferred from M0)
- [ ] Real 1024×1024 app icon
- [ ] Five App Store screenshots per docs/app-store-listing.md
- [ ] Publish privacy policy (decide hosting, deploy)
- [ ] App Store metadata draft committed to App Store Connect
- [ ] TestFlight invite to 10–25 testers; collect feedback 1–2 weeks

### Exit criterion
TestFlight beta live long enough to surface common failure modes. Reliability targets from PRD §8 tracking. No P0 bugs open."

create_issue "M7 — v1 GA" "$M7" \
"Tracker for [M7 in docs/MILESTONES.md](../blob/main/docs/MILESTONES.md).

### Tasks
- [ ] App Store submission with final metadata
- [ ] Marketing post / README updated with App Store link
- [ ] Post-launch monitoring for first week (crash reports, review tone)

### Exit criterion
Whisper Intent v1 live on the App Store."

echo ""
echo "Done. Visit https://github.com/$REPO/milestones and /issues to review."
