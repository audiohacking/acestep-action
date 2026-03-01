# Ace-Step Audio Generation Action

A GitHub Action that generates music from text prompts using [Ace-Step 1.5](https://github.com/ACE-Step/ACE-Step-1.5) via the native [acestep.cpp](https://github.com/audiohacking/acestep.cpp) engine — **no Python, no PyTorch**.  
Text + optional lyrics in, stereo 48 kHz WAV out.  Runs entirely on CPU (OpenBLAS).

## Features

- 🎵 Generate high-quality music from a text caption
- 🖊️ Optional lyrics — or let the LLM write them for you
- ⚡ Native C++17 / GGML engine — lightweight, no GPU required
- 📦 GGUF models cached with `actions/cache@v4` — fast on repeat runs
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
| `model_cache_path` | Directory to cache GGUF model files | No | `~/.cache/acestep` |
| `output_path` | Output path for the generated WAV file | No | `output.wav` |

## Outputs

| Output | Description |
|--------|-------------|
| `audio_file` | Path to the generated WAV audio file |
| `generation_time` | Time taken to generate the audio in seconds |

## How it works

The action is a **composite action** that:

1. **Installs** CMake and OpenBLAS on the runner.
2. **Builds** `ace-qwen3` and `dit-vae` from [audiohacking/acestep.cpp](https://github.com/audiohacking/acestep.cpp) (cached per commit).
3. **Downloads** four GGUF files from [Serveurperso/ACE-Step-1.5-GGUF](https://huggingface.co/Serveurperso/ACE-Step-1.5-GGUF) (~7.7 GB, cached across runs):
   - `Qwen3-Embedding-0.6B-Q8_0.gguf` — text encoder
   - `acestep-5Hz-lm-4B-Q8_0.gguf` — Qwen3 causal LM (audio codes)
   - `acestep-v15-turbo-Q8_0.gguf` — DiT diffusion transformer
   - `vae-BF16.gguf` — Oobleck VAE decoder
4. **Generates** audio via two stages:
   - `ace-qwen3`: caption → enriched JSON with lyrics + audio codes
   - `dit-vae`: JSON → stereo 48 kHz WAV

## Project structure

```
acestep-action/
├── action.yml                    # Composite action definition
├── src/
│   └── entrypoint.sh            # Generation shell script
└── .github/
    └── workflows/
        └── test.yml             # CI test workflow
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/audiohacking/acestep-action).
