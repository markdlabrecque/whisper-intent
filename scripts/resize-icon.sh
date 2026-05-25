#!/usr/bin/env bash
# resize-icon.sh — install a new app icon source into the AppIcon asset catalog.
#
# Usage:
#   scripts/resize-icon.sh path/to/source-1024.png
#
# The current AppIcon.appiconset uses the modern single-image universal mode
# introduced in iOS 13 — a single 1024x1024 PNG. Xcode generates every other
# size required for the home screen, Spotlight, Settings, notifications, and
# the App Store from that one source at archive time.
#
# This script:
#   1. Validates that the source is exactly 1024x1024 and PNG.
#   2. Strips its colour profile and metadata so the asset catalog is
#      reproducible across machines.
#   3. Copies it into the asset catalog as AppIcon.png.
#
# Requires macOS (uses `sips` + `file`). No third-party tools.
#
# If you ever need legacy multi-size mode (separate PNG per size), this script
# is the right place to add a `--legacy` flag that fans the source out via
# `sips -z`. Not implemented today because the asset catalog doesn't ask for
# legacy sizes.

set -euo pipefail

APP_ICON_DIR="App/WhisperIntent/Resources/Assets.xcassets/AppIcon.appiconset"
DEST="$APP_ICON_DIR/AppIcon.png"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <source-1024.png>" >&2
  exit 64
fi

SRC="$1"

if [ ! -f "$SRC" ]; then
  echo "error: source file not found: $SRC" >&2
  exit 1
fi

# Verify it's a PNG.
if ! file "$SRC" | grep -q "PNG image data"; then
  echo "error: $SRC is not a PNG file." >&2
  echo "       \`file\` says: $(file -b "$SRC")" >&2
  exit 1
fi

# Verify dimensions.
WIDTH=$(sips -g pixelWidth "$SRC" 2>/dev/null | awk '/pixelWidth:/ {print $2}')
HEIGHT=$(sips -g pixelHeight "$SRC" 2>/dev/null | awk '/pixelHeight:/ {print $2}')

if [ "$WIDTH" != "1024" ] || [ "$HEIGHT" != "1024" ]; then
  echo "error: source must be exactly 1024x1024. Got ${WIDTH}x${HEIGHT}." >&2
  exit 1
fi

if [ ! -d "$APP_ICON_DIR" ]; then
  echo "error: asset catalog missing at $APP_ICON_DIR" >&2
  echo "       run from the repo root and confirm project.yml is set up." >&2
  exit 1
fi

# Copy with metadata stripped. `sips -s format png` rewrites the file and drops
# extraneous metadata (creator, GPS, Photoshop chunks); the result is the same
# image bits but a smaller, reproducible binary.
TMP=$(mktemp -t whisper-icon).png
trap 'rm -f "$TMP"' EXIT
cp "$SRC" "$TMP"
sips -s format png "$TMP" --out "$TMP" >/dev/null

cp "$TMP" "$DEST"

echo "installed: $DEST"
echo "  source:  $SRC (1024x1024 PNG)"
echo "  size:    $(du -h "$DEST" | awk '{print $1}')"
echo
echo "Next: \`make generate && make app-build\` to verify Xcode picks it up."
