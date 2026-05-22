#!/usr/bin/env bash
# Download a WhisperKit Core ML model into App/WhisperIntent/Resources/Models/.
#
# Usage:
#   scripts/download-whisperkit-model.sh                  # defaults to medium
#   scripts/download-whisperkit-model.sh openai_whisper-tiny
#   MODEL=openai_whisper-medium scripts/download-whisperkit-model.sh
#
# Source: https://huggingface.co/argmaxinc/whisperkit-coreml
#
# Idempotent: if the target directory already exists and is non-empty, the
# script exits 0 without re-downloading. Delete the directory to force a
# refetch.
#
# Two transports, tried in order:
#   1. huggingface-cli (recommended; respects HF_TOKEN, resumable)
#   2. git clone + LFS (fallback if huggingface-cli is not installed)

set -euo pipefail

MODEL="${1:-${MODEL:-openai_whisper-medium}}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEST_DIR="$REPO_DIR/App/WhisperIntent/Resources/Models/$MODEL"
HF_REPO="argmaxinc/whisperkit-coreml"

if [[ -d "$DEST_DIR" ]] && [[ -n "$(ls -A "$DEST_DIR" 2>/dev/null)" ]]; then
  echo "Model already present at $DEST_DIR — skipping download."
  echo "Delete the directory and re-run if you want to refetch."
  exit 0
fi

mkdir -p "$DEST_DIR"

if command -v huggingface-cli >/dev/null 2>&1; then
  echo "Downloading $MODEL via huggingface-cli …"
  huggingface-cli download "$HF_REPO" \
    --include "$MODEL/*" \
    --local-dir "$REPO_DIR/App/WhisperIntent/Resources/Models" \
    --local-dir-use-symlinks False
elif command -v git >/dev/null 2>&1 && command -v git-lfs >/dev/null 2>&1; then
  echo "huggingface-cli not found; falling back to git + LFS sparse checkout …"
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  git clone --depth=1 --filter=blob:none --sparse \
    "https://huggingface.co/$HF_REPO" "$TMP_DIR/repo"
  (cd "$TMP_DIR/repo" && git sparse-checkout set "$MODEL" && git lfs pull --include "$MODEL/*")
  mv "$TMP_DIR/repo/$MODEL"/* "$DEST_DIR/"
else
  echo "ERROR: need either huggingface-cli or (git + git-lfs) installed." >&2
  echo "Install one of:" >&2
  echo "  pip install --user 'huggingface_hub[cli]'" >&2
  echo "  brew install huggingface-cli" >&2
  echo "  brew install git-lfs" >&2
  exit 1
fi

echo ""
echo "Done. Model at: $DEST_DIR"
du -sh "$DEST_DIR" 2>/dev/null || true
