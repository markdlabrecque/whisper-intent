#!/usr/bin/env bash
# doctor.sh — self-diagnostic for Whisper Intent local development.
#
# Prints a per-row report. Green = ready; yellow = optional/missing-but-OK;
# red = a real prerequisite is missing. Always exits 0 — the tool is for
# humans to scan, not for CI to gate on.

set -uo pipefail

GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
DIM=$'\033[2m'
RESET=$'\033[0m'

pass() { printf "  ${GREEN}✓${RESET} %-38s %s\n" "$1" "${2:-}"; }
warn() { printf "  ${YELLOW}!${RESET} %-38s %s\n" "$1" "${2:-}"; }
fail() { printf "  ${RED}✗${RESET} %-38s %s\n" "$1" "${2:-}"; }

section() { printf "\n${DIM}── %s ──${RESET}\n" "$1"; }

# ----------------------------------------------------------------------------
# CLI tools
# ----------------------------------------------------------------------------

section "CLI tools"

check_tool() {
  local name="$1"
  local install_hint="$2"
  local version_flag="${3:---version}"
  if command -v "$name" >/dev/null 2>&1; then
    pass "$name" "$($name $version_flag 2>&1 | head -1)"
  else
    fail "$name" "missing — $install_hint"
  fi
}

check_tool xcodegen "brew install xcodegen"
check_tool swiftformat "brew install swiftformat"
check_tool swiftlint "brew install swiftlint"
check_tool gitleaks "brew install gitleaks"
check_tool swift "ship with Xcode"
check_tool xcodebuild "ship with Xcode" "-version"

# ----------------------------------------------------------------------------
# Xcode toolchain
# ----------------------------------------------------------------------------

section "Xcode toolchain"

if XCODE_PATH=$(xcode-select -p 2>/dev/null); then
  pass "active Xcode" "$XCODE_PATH"
else
  fail "active Xcode" "xcode-select -p failed"
fi

XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -1)
if [ -n "$XCODE_VERSION" ]; then
  if echo "$XCODE_VERSION" | grep -Eq "Xcode (26|27|28|29|30)"; then
    pass "xcodebuild version" "$XCODE_VERSION"
  else
    warn "xcodebuild version" "$XCODE_VERSION (M5/M6 assume Xcode 26+)"
  fi
else
  fail "xcodebuild version" "xcodebuild -version produced no output"
fi

# ----------------------------------------------------------------------------
# Project setup
# ----------------------------------------------------------------------------

section "Project"

if [ -f project.yml ]; then
  pass "project.yml" "present"
else
  fail "project.yml" "missing — repo layout broken"
fi

if [ -d WhisperIntent.xcodeproj ]; then
  pass "WhisperIntent.xcodeproj" "generated (run \`make generate\` to refresh)"
else
  warn "WhisperIntent.xcodeproj" "missing — run \`make generate\`"
fi

if [ -d "App/WhisperIntent/Resources/Models/openai_whisper-medium" ] && \
   [ -n "$(ls -A "App/WhisperIntent/Resources/Models/openai_whisper-medium" 2>/dev/null)" ]; then
  pass "WhisperKit model files" "present"
else
  fail "WhisperKit model files" "missing — required for device builds. See docs/spikes/S4-install-size.md"
fi

# ----------------------------------------------------------------------------
# Fastlane / signing
# ----------------------------------------------------------------------------

section "Fastlane and signing"

if [ -f fastlane/.env ]; then
  pass "fastlane/.env" "present (gitignored)"

  # Source for the variable checks. Don't export — keep them local to this shell.
  set -a
  # shellcheck disable=SC1091
  . fastlane/.env 2>/dev/null || true
  set +a

  if [ -n "${DEVELOPMENT_TEAM:-}" ] && [ "${DEVELOPMENT_TEAM}" != "XXXXXXXXXX" ]; then
    pass "DEVELOPMENT_TEAM" "set"
  else
    warn "DEVELOPMENT_TEAM" "not set or still placeholder — \`make release-archive\` will fail"
  fi

  for var in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_FILEPATH; do
    val="${!var:-}"
    if [ -n "$val" ] && ! echo "$val" | grep -qE "^(XXXXX|ABCDE|00000)"; then
      pass "$var" "set"
    else
      warn "$var" "not set — \`fastlane beta\` will fail"
    fi
  done

  if [ -n "${ASC_KEY_FILEPATH:-}" ] && [ -f "${ASC_KEY_FILEPATH}" ]; then
    pass "ASC .p8 key file" "${ASC_KEY_FILEPATH}"
  else
    warn "ASC .p8 key file" "path in \$ASC_KEY_FILEPATH not readable"
  fi
else
  warn "fastlane/.env" "missing — \`cp fastlane/.env.example fastlane/.env\` and fill in"
fi

if [ -f Gemfile.lock ]; then
  pass "Gemfile.lock" "present (Fastlane pinned)"
else
  warn "Gemfile.lock" "missing — run \`bundle lock\`"
fi

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------

section "Summary"
echo "  Doctor is informational only. Red rows block specific tasks (build,"
echo "  TestFlight upload, etc.); yellow rows are optional but recommended."
echo "  Run \`make verify\` for the actual pre-push check."
echo
