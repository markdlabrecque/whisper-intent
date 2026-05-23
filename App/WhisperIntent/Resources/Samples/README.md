# Samples/

Synthetic English audio used by spike S1 (progress-callback granularity) and
reusable for any later spike that needs deterministic, reproducible audio
input.

**Files in this directory are not in git** — they are generated locally and
gitignored.

## How to populate

From the repo root:

```bash
scripts/generate-spike-samples.sh
```

This uses macOS's built-in `say` (TTS) + `afconvert` to produce two WAV
files at 16 kHz mono 16-bit PCM:

| File | Approx. duration | Purpose |
|---|---|---|
| `sample-30s.wav` | ~20 s (Samantha voice at default rate) | short-input baseline |
| `sample-300s.wav` | ~165 s | long-input granularity check |

Actual durations vary by voice and macOS version. The script names them
`30s` / `300s` to match the spike doc, but the on-device measurement should
read the real duration from the audio file rather than assume the filename.

## Why synthetic and not human-recorded

- Reproducible across machines, across re-runs, no licensing concerns.
- Spike S1's question is *callback granularity*, not transcription quality —
  TTS audio is fine for measuring callback frequency.
- Spike S1's findings don't depend on accent or recording conditions.

If a later spike needs naturalistic audio (e.g. measuring real-world WER),
swap in human-recorded samples at that point.
