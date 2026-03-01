# Ace-Step Audio Generation Action

A GitHub Action that generates music from text prompts using [Ace-Step 1.5](https://github.com/ACE-Step/ACE-Step-1.5) via the native [acestep.cpp](https://github.com/audiohacking/acestep.cpp) engine.  
Text + optional lyrics in, stereo 48 kHz WAV out.

**No Python. No PyTorch. No waiting.**  
The pre-built Docker image ships with compiled `ace-qwen3`/`dit-vae` binaries **and** all ~7.7 GB of pre-quantized GGUF models baked in — action execution starts immediately.

## Features

- 🎵 Generate high-quality music from a text caption
- 🖊️ Optional lyrics — or let the LLM write them for you
- ⚡ Native C++17 / GGML engine — lightweight, no GPU required
- 🐳 Pre-built Docker image with models included — zero download wait
- 🎲 Reproducible generation with optional seed
- 🔧 Easy integration with GitHub Actions workflows

## Usage

### Basic Example

```yaml
name: Generate Audio
on: [push]

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Generate audio
        id: audio
        uses: audiohacking/acestep-action@main
        with:
          caption: 'upbeat electronic chiptune music'

      - name: Use generated audio
        run: echo "Audio saved to ${{ steps.audio.outputs.audio_file }}"
```

### With lyrics and seed

```yaml
- name: Generate audio
  id: audio
  uses: audiohacking/acestep-action@main
  with:
    caption: 'calm ambient piano melody, lo-fi, warm'
    lyrics: |
      [Verse]
      Floating on a cloud of sound
      Melodies that go around
    duration: '30'
    seed: '42'
    output_path: 'generated_music.wav'
```

### Upload the result as an artifact

```yaml
- name: Upload audio
  uses: actions/upload-artifact@v4
  with:
    name: generated-audio
    path: ${{ steps.audio.outputs.audio_file }}
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `caption` | Text description for music generation | No | `chiptune` |
| `lyrics` | Lyrics (empty = LLM auto-generates) | No | _(empty)_ |
| `duration` | Duration in seconds | No | `20` |
| `seed` | Random seed for reproducible generation | No | _(random)_ |
| `inference_steps` | Number of DiT inference steps | No | `8` |
| `shift` | Flow-matching shift parameter | No | `3` |
| `vocal_language` | Vocal language code (`en`, `fr`, …) | No | `en` |
| `output_path` | Output path for the generated WAV file | No | `output.wav` |

## Outputs

| Output | Description |
|--------|-------------|
| `audio_file` | Path to the generated WAV audio file |
| `generation_time` | Time taken to generate the audio in seconds |

## How it works

The action runs as a **pre-built Docker container** published to GitHub Container Registry.  The image is built once (by `build-docker.yml`) and contains everything needed:

| What | Where in image |
|------|---------------|
| `ace-qwen3` binary (Qwen3 causal LM) | `/action/bin/ace-qwen3` |
| `dit-vae` binary (DiT + Oobleck VAE) | `/action/bin/dit-vae` |
| `Qwen3-Embedding-0.6B-Q8_0.gguf` | `/action/models/` |
| `acestep-5Hz-lm-4B-Q8_0.gguf` | `/action/models/` |
| `acestep-v15-turbo-Q8_0.gguf` | `/action/models/` |
| `vae-BF16.gguf` | `/action/models/` |

At runtime the entrypoint (`src/entrypoint.sh`):
1. Builds a request JSON from inputs
2. Runs `ace-qwen3` (LLM stage: caption → enriched JSON with lyrics + audio codes)
3. Runs `dit-vae` (DiT + VAE stage: JSON → stereo 48 kHz WAV)
4. Moves the output WAV to the requested path in `$GITHUB_WORKSPACE`

**Image location:** `ghcr.io/audiohacking/acestep-action:latest`

## Project structure

```
acestep-action/
├── action.yml                      # Docker action definition
├── Dockerfile                      # Image: build binaries + download models
├── src/
│   └── entrypoint.sh              # Generation shell script (Docker entrypoint)
└── .github/
    └── workflows/
        ├── build-docker.yml       # Build and publish image to GHCR
        └── test.yml               # CI test workflow
```

## Local development

To test locally with the Dockerfile instead of the GHCR image, change `action.yml`:

```yaml
runs:
  using: 'docker'
  image: 'Dockerfile'   # instead of 'docker://ghcr.io/...'
```

Then build and run the container manually:

```bash
docker build -t acestep-action .

docker run --rm \
  -e INPUT_CAPTION="upbeat chiptune" \
  -e INPUT_DURATION="10" \
  -e GITHUB_WORKSPACE=/out \
  -e GITHUB_OUTPUT=/dev/stdout \
  -v /tmp/out:/out \
  acestep-action
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See [LICENSE](LICENSE) file for details.
