#!/usr/bin/env bash
# Generate synthetic English audio samples for spike S3 (background-execution
# budget / max-duration cap measurement).
#
# Why pre-recorded clips: S3 is a controlled experiment — feeding the iPhone
# mic with a deterministic, repeatable audio signal removes the human voice as
# a variable. Play these from a Mac speaker (or any source) into the test
# iPhone while running the S3 Shortcut.
#
# Output (gitignored — see .gitignore):
#   s3-samples/sample-10s.wav
#   s3-samples/sample-30s.wav
#   s3-samples/sample-60s.wav
#   s3-samples/sample-90s.wav
#   s3-samples/sample-120s.wav
#   s3-samples/sample-180s.wav
#   s3-samples/sample-300s.wav
#
# Each sample is a cumulative extension of the previous one — the 5-minute
# sample contains the full narrative, and shorter samples are prefixes. That
# lets you spot mid-recording drops at a glance: a "good" transcript of the
# 60s sample should be a prefix of a "good" 90s transcript, and so on.
#
# Format: 44.1 kHz stereo WAV. The iPhone mic resamples on its end; we
# optimise for clean playback through Mac speakers rather than for any
# specific input format.
#
# Idempotent: regenerates every file on each run (cheap, ~few seconds total).

set -euo pipefail

VOICE="${VOICE:-Samantha}"
# Words per minute. Default `say` rate (~175) renders faster than natural
# reading; 140 lines up closer to the calibrated word counts below and reads
# more clearly through Mac speakers.
RATE="${RATE:-140}"
OUT_DIR="${OUT_DIR:-./s3-samples}"

mkdir -p "$OUT_DIR"

# Each `SEG_*` is the *additional* text for that duration. The actual text
# spoken for a given target is the concatenation of all preceding segments.
# Word counts roughly calibrated for ~150 wpm rendered speech; tune the texts
# if `afinfo` shows a target is more than a few seconds off.

SEG_10S="The harbor was quiet when Ellis arrived, just before sunrise. \
The boats rocked gently in their moorings. \
A single gull called from the breakwater."

SEG_30S_ADD="Ellis had walked this path every morning for the past three years. \
The small cafe at the end of the pier always opened at five thirty, \
and Theo, the owner, had the coffee ready before the first regulars arrived. \
Theo nodded a quiet greeting and slid a paper cup across the counter without a word. \
Today was no different, and Ellis was glad of it."

SEG_60S_ADD="Outside again, Ellis sat on the bench facing the water and watched the fog burn off in patches. \
There was a particular pleasure in being awake before the rest of the town. \
The streetlights still glowed orange against the lightening sky. \
A bakery van rolled past on the street behind the pier, on its usual run to the corner grocery. \
The same van, the same driver, every morning at six fifteen exactly."

SEG_90S_ADD="Ellis pulled a small notebook from a pocket and uncapped a pen. \
The notebook was small enough to fit in one hand and battered enough that the corners had softened to a kind of cloth. \
Each page held a few sentences, dated, often nothing more than an observation about the weather or the people on the pier. \
Ellis had kept this notebook, or one very much like it, for as long as anyone could remember."

SEG_120S_ADD="This morning's entry began simply enough. \
Fog at five. Theo wearing the green sweater again. \
The orange cat from the second floor apartment above the cafe perched on the railing, watching the gulls with a kind of disinterested professional interest. \
Ellis paused, considered the cat, then added a single line. \
Patience is its own occupation. \
The cat did not respond. It rarely did. \
Ellis closed the notebook and tucked it away."

SEG_180S_ADD="By six the regulars had begun to arrive. \
First was Hannah, who worked at the small bookshop two streets over and always stopped for an espresso before opening up. \
Then came Marcus and his daughter, on their way to the early ferry. \
The daughter was perhaps eight, and she had a habit of carrying a chess piece in her pocket. \
A different piece every day, traded for the one she had carried yesterday. \
Ellis had asked her about this once. \
The daughter had explained, with the seriousness of someone disclosing a state secret, \
that each piece needed to see the world before it was permanently retired to the board. \
Today she carried a black knight. \
Ellis tipped a hat to her, gravely, as she passed, and she tipped a small imaginary hat back."

SEG_300S_ADD="After Marcus and his daughter came the older couple from the apartments above the hardware store. \
They never spoke to each other on these walks, but they always held hands, \
and Ellis suspected this said more about their marriage than anything they could have said aloud. \
Then a small parade of fishermen, hands deep in jacket pockets, talking quietly about the tide tables and the price of bait. \
Then the postman on his bicycle, far too early to be delivering anything, \
but headed nowhere in particular at a pace that suggested he simply enjoyed the ride. \
Then a stranger, which was unusual. \
The stranger paused at the end of the pier, looked out at the water, looked back at the cafe, \
and stood there long enough that Ellis began to wonder whether something was about to happen. \
But nothing did. The stranger walked away, hands in pockets, and the morning continued. \
By seven the sun had cleared the rooftops behind the harbor. \
The water turned from grey to a kind of bright pewter, and the fishing boats began motoring out, \
one by one, leaving behind low triangular wakes. \
Ellis finished the coffee, stood, stretched, and walked back along the pier toward the small house at the end of the lane. \
There would be a few hours of work waiting, and then errands, \
and then perhaps a quiet afternoon in the garden if the weather held. \
The notebook would come out again at noon, and again in the evening, \
and the day would end as it had begun, \
with the harbor settling into a familiar silence, and the boats rocking gently against their moorings. \
It was, Ellis often thought, a small life. \
But the smallness was deliberate, and the deliberateness was the whole point. \
Some lives reach outward, some lives reach inward. \
The harbor, the cafe, the notebook, the orange cat. \
These were enough. They had been enough for a long time. \
They would be enough for a long time still."

# Compose cumulative texts.
TEXT_10S="$SEG_10S"
TEXT_30S="$TEXT_10S $SEG_30S_ADD"
TEXT_60S="$TEXT_30S $SEG_60S_ADD"
TEXT_90S="$TEXT_60S $SEG_90S_ADD"
TEXT_120S="$TEXT_90S $SEG_120S_ADD"
TEXT_180S="$TEXT_120S $SEG_180S_ADD"
TEXT_300S="$TEXT_180S $SEG_300S_ADD"

generate() {
  local text="$1"
  local out_wav="$2"
  local tmp_aiff
  tmp_aiff="$(mktemp -t s3-sample).aiff"

  echo "Generating $(basename "$out_wav") via say(${VOICE}) → afconvert …"
  say --voice "$VOICE" --rate "$RATE" --output-file "$tmp_aiff" "$text"

  # Stereo 44.1 kHz 16-bit signed PCM WAV — good for Mac-speaker playback.
  afconvert \
    -f WAVE \
    -d LEI16@44100 \
    -c 2 \
    "$tmp_aiff" "$out_wav"

  rm -f "$tmp_aiff"
  local dur
  dur="$(afinfo "$out_wav" 2>/dev/null | awk -F': ' '/estimated duration/ {print $2}' | head -1)"
  echo "  → $out_wav (${dur:-unknown duration})"
}

generate "$TEXT_10S"  "$OUT_DIR/sample-10s.wav"
generate "$TEXT_30S"  "$OUT_DIR/sample-30s.wav"
generate "$TEXT_60S"  "$OUT_DIR/sample-60s.wav"
generate "$TEXT_90S"  "$OUT_DIR/sample-90s.wav"
generate "$TEXT_120S" "$OUT_DIR/sample-120s.wav"
generate "$TEXT_180S" "$OUT_DIR/sample-180s.wav"
generate "$TEXT_300S" "$OUT_DIR/sample-300s.wav"

echo ""
echo "Done. Samples in: $OUT_DIR"
echo "Verify durations with: afinfo $OUT_DIR/sample-*.wav | grep duration"
