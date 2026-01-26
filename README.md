# Ace-Step Audio Generation Action

A GitHub Action that generates music from text prompts using the ACE-Step model. This action automatically handles model downloads with intelligent caching for efficient repeated runs, and outputs high-quality MP3 files.

## Features

- 🎵 Generate high-quality music from text prompts
- 🎹 Support for instrumental and lyric-based generation
- 🚀 Automatic model caching for fast repeated runs
- 🐳 Containerized execution for consistency
- 📦 Returns MP3 files ready for use in your workflow
- ⚡ Easy integration with GitHub Actions workflows
- 🎲 Reproducible generation with seed parameter

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
        uses: audiohacking/acestep-action@v1
        with:
          prompt: 'upbeat electronic chiptune music'
          
      - name: Use generated audio
        run: echo "Audio saved to ${{ steps.audio.outputs.audio_file }}"
```

### With Caching

For optimal performance on repeated runs, use GitHub's cache action:

```yaml
name: Generate Audio with Cache
on: [push]

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # Cache the model files
      - name: Cache Ace-Step models
        uses: actions/cache@v4
        with:
          path: ~/.cache/acestep
          key: ${{ runner.os }}-acestep-models-${{ hashFiles('**/requirements.txt') }}
          restore-keys: |
            ${{ runner.os }}-acestep-models-
      
      - name: Generate audio
        id: audio
        uses: audiohacking/acestep-action@v1
        with:
          prompt: 'calm ambient piano melody'
          lyrics: '[inst]'
          duration: '30.0'
          seed: '42'
          model_cache_path: '~/.cache/acestep'
          output_path: 'generated_music.mp3'
      
      # Upload the generated audio as an artifact
      - name: Upload audio
        uses: actions/upload-artifact@v4
        with:
          name: generated-audio
          path: ${{ steps.audio.outputs.audio_file }}
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `prompt` | Text prompt for music generation | No | `chiptune` |
| `lyrics` | Lyrics for the generation (use `[inst]` for instrumental) | No | `[inst]` |
| `duration` | Duration of the generated audio in seconds | No | `20.0` |
| `seed` | Random seed for reproducible generation | No | `None` (random) |
| `model_cache_path` | Path to cache the model files | No | `~/.cache/acestep` |
| `output_path` | Output path for the generated MP3 file | No | `output.mp3` |

## Outputs

| Output | Description |
|--------|-------------|
| `audio_file` | Path to the generated MP3 audio file |
| `generation_time` | Time taken to generate the audio in seconds |

## Model Caching

The action automatically caches downloaded models in the specified `model_cache_path`. For GitHub Actions, we recommend:

1. Use the `actions/cache@v4` action to persist the cache between workflow runs
2. Set the cache path to match the `model_cache_path` input (default: `~/.cache/acestep`)
3. Use a cache key that includes your requirements hash for automatic invalidation on dependency changes

This dramatically reduces execution time on subsequent runs by avoiding model re-downloads.

## Development

### Project Structure

```
acestep-action/
├── action.yml          # Action metadata and configuration
├── Dockerfile          # Container definition
├── requirements.txt    # Python dependencies
├── src/
│   └── main.py        # Main action script
└── .github/
    └── workflows/
        └── test.yml   # Test workflow
```

### Local Testing

You can test the action locally using Docker:

```bash
docker build -t acestep-action .
docker run -e INPUT_TEXT="Test message" acestep-action
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/audiohacking/acestep-action).
