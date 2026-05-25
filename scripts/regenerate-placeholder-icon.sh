#!/usr/bin/env bash
# regenerate-placeholder-icon.sh — rasterise AppIcon.svg → AppIcon.png at 1024x1024.
#
# This script regenerates the *placeholder* app icon from its SVG
# source-of-truth. It is not used for the final designed icon — that one
# will arrive as a 1024 PNG and be installed via scripts/resize-icon.sh.
#
# Requires one of (in order of preference):
#   - rsvg-convert (`brew install librsvg`)
#   - magick / convert (`brew install imagemagick`)
#   - inkscape (`brew install --cask inkscape`)
#
# If none are present, the script prints install hints and exits non-zero.

set -euo pipefail

SVG="App/WhisperIntent/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.svg"
PNG="App/WhisperIntent/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

if [ ! -f "$SVG" ]; then
  echo "error: SVG source not found at $SVG" >&2
  exit 1
fi

if command -v rsvg-convert >/dev/null; then
  rsvg-convert -w 1024 -h 1024 "$SVG" -o "$PNG"
elif command -v magick >/dev/null; then
  magick -background none -density 1024 "$SVG" -resize 1024x1024 "$PNG"
elif command -v convert >/dev/null; then
  convert -background none -density 1024 "$SVG" -resize 1024x1024 "$PNG"
elif command -v inkscape >/dev/null; then
  inkscape "$SVG" --export-type=png --export-filename="$PNG" --export-width=1024 --export-height=1024
else
  echo "error: no SVG rasteriser found." >&2
  echo "       install one of: brew install librsvg | imagemagick | --cask inkscape" >&2
  exit 1
fi

# Strip extraneous metadata so the file is reproducible bit-for-bit
# across machines (different rasterisers embed different timestamps).
sips -s format png "$PNG" --out "$PNG" >/dev/null

echo "regenerated: $PNG"
sips -g pixelWidth -g pixelHeight "$PNG" | tail -2
