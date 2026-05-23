#!/usr/bin/env bash
# Generate synthetic English audio samples for spike S1 (and reusable for any
# later spike that needs deterministic audio input).
#
# Produces:
#   App/WhisperIntent/Resources/Samples/sample-30s.wav   (~30 s, mono, 16 kHz)
#   App/WhisperIntent/Resources/Samples/sample-300s.wav  (~5 min, mono, 16 kHz)
#
# Format note: WhisperKit expects mono 16 kHz Float32-friendly PCM. We use
# 16-bit signed PCM here because that's the lowest-friction format `afconvert`
# produces; WhisperKit upcasts internally.
#
# Idempotent: if a target file exists, it is regenerated (samples are cheap;
# no need to short-circuit).
#
# Requires: macOS `say` and `afconvert` (both built-in).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$REPO_DIR/App/WhisperIntent/Resources/Samples"
mkdir -p "$OUT_DIR"

VOICE="${SAY_VOICE:-Samantha}"  # override with SAY_VOICE=... if desired

# Two short paragraphs concatenated to reach ~30 s at typical TTS pace.
TEXT_30S="The quick brown fox jumps over the lazy dog. \
Pack my box with five dozen liquor jugs. \
How vexingly quick daft zebras jump! \
The five boxing wizards jump quickly. \
Sphinx of black quartz, judge my vow. \
Two driven jocks help fax my big quiz. \
Amazingly few discotheques provide jukeboxes. \
Jackdaws love my big sphinx of quartz."

# A longer narrative for the 5-minute sample. Whisper's medium model handles
# varied content better than a single repeated paragraph.
TEXT_300S="The history of speech recognition stretches back further than most \
people realize. In nineteen fifty-two, three researchers at Bell Labs built \
a system that could recognize spoken digits from a single speaker. \
It used the resonant frequencies of the human vocal tract, mapped against \
a small set of templates, and achieved roughly ninety percent accuracy under \
ideal conditions. The system was called Audrey, and it filled most of a room. \
\
Over the next two decades, progress was incremental and frustrating. \
Vocabularies grew from ten digits to several hundred words, but only for \
isolated speech with long pauses between each word. Continuous speech, with \
its overlapping phonemes and contextual ambiguity, remained out of reach. \
\
The first real breakthrough came with hidden Markov models in the late \
nineteen seventies. These statistical models could capture the temporal \
structure of speech in a way that template matching never could. By the \
end of the nineteen eighties, hidden Markov model systems were achieving \
near-human accuracy on certain constrained tasks, like reading aloud from a \
known text. Commercial dictation software followed in the nineteen nineties, \
though it required training for each speaker and a quiet environment. \
\
Neural networks transformed the field again, twice. The first wave, in the \
mid two-thousands, replaced the acoustic modeling component of hidden Markov \
model systems with deep neural networks. Error rates dropped by a third \
almost overnight. The second wave, ten years later, abandoned hidden Markov \
models entirely in favor of end-to-end neural architectures. Connectionist \
temporal classification, attention mechanisms, and eventually transformers \
collapsed what had been a pipeline of distinct stages into a single learned \
function from audio waveform to text. \
\
Whisper, released by OpenAI in twenty twenty-two, demonstrated the practical \
ceiling of this approach. Trained on six hundred eighty thousand hours of \
multilingual speech scraped from the internet, it achieved remarkable \
robustness to accent, background noise, and technical vocabulary without \
any speaker-specific tuning. The model came in several sizes, from a tiny \
thirty-nine megabyte variant suitable for embedded devices, all the way up \
to a one and a half gigabyte large variant that approached human transcription \
accuracy on conversational English. \
\
Apple's Core ML framework made it possible to run these models entirely on \
device, with no network connection required. The medium variant, at roughly \
one and a half gigabytes after conversion, fits comfortably within the storage \
budget of a modern iPhone, and runs in real time on the Neural Engine of \
recent A-series chips. This local-only execution model has implications for \
privacy that are difficult to overstate. Voice data, which is among the most \
sensitive categories of personal information, never needs to leave the device."

generate() {
  local text="$1"
  local out_wav="$2"
  local tmp_aiff
  tmp_aiff="$(mktemp -t spike-sample).aiff"

  echo "Generating $(basename "$out_wav") via say(${VOICE}) → afconvert …"
  say --voice "$VOICE" --output-file "$tmp_aiff" "$text"

  # 16 kHz mono 16-bit signed PCM WAV.
  afconvert \
    -f WAVE \
    -d LEI16@16000 \
    -c 1 \
    "$tmp_aiff" "$out_wav"

  rm -f "$tmp_aiff"
  local dur
  dur="$(afinfo "$out_wav" 2>/dev/null | awk -F': ' '/estimated duration/ {print $2}' | head -1)"
  echo "  → $out_wav (${dur:-unknown duration})"
}

generate "$TEXT_30S" "$OUT_DIR/sample-30s.wav"
generate "$TEXT_300S" "$OUT_DIR/sample-300s.wav"

echo ""
echo "Done. Samples in: $OUT_DIR"
ls -lh "$OUT_DIR"
