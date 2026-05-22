# Models/

This directory holds the WhisperKit medium model (`openai_whisper-medium/`)
that ships inside the app bundle. **The model files themselves are not in
git** — they are large (~1.5 GB total), and `.gitignore` excludes them.

## How to populate this directory

Run the download script from the repo root:

```bash
scripts/download-whisperkit-model.sh           # default: openai_whisper-medium
scripts/download-whisperkit-model.sh openai_whisper-tiny   # override
```

Requires `huggingface-cli` (preferred) or `git` + `git-lfs` as fallback. The
script is idempotent — it skips if the model dir already exists.

The expected final layout is:

```
Models/
├── README.md                                     (this file, committed)
└── openai_whisper-medium/                        (gitignored)
    ├── AudioEncoder.mlmodelc/
    ├── TextDecoder.mlmodelc/
    ├── MelSpectrogram.mlmodelc/
    ├── config.json
    └── tokenizer.json
```

## Why this is gitignored

- GitHub has a 100 MB per-file limit; the `.mlmodelc` blobs are well over.
- Committing them would bloat repository history permanently.
- The model files are not source code — they are an upstream artifact from
  Argmax's WhisperKit model distribution. They can always be re-downloaded.

## Where they come from

WhisperKit publishes ML models at: https://huggingface.co/argmaxinc/whisperkit-coreml

For spike S4 we use a checked-in shell script (see above). The longer-term
mechanism (build-time SwiftPM plugin vs. continuing with the script) will be
revisited if S4's outcome forces a switch to On-Demand Resources — see
[`docs/spikes/S4-install-size.md`](../../../../docs/spikes/S4-install-size.md).

## CI

CI does not currently download model files. The `core-package` job builds
and tests the Swift package only, which does not link the model. The
`app-build` job (commented out in `.github/workflows/ci.yml`) will need
to fetch the model before building once it is enabled.
