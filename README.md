# Ace-Step Audio Generation Action

A GitHub Action that generates music from text prompts using the ACE-Step-v1-3.5B model. This action uses a **pre-built Docker image** with the model and all dependencies included for fast, consistent execution.

## Features

- 🎵 Generate high-quality music from text prompts
- 🎹 Support for instrumental and lyric-based generation
- ⚡ **Pre-built Docker image** with model included - no download wait time
- 🚀 Fast execution with pre-cached dependencies
- 🐳 Containerized execution for consistency
- 📦 Returns MP3 files ready for use in your workflow
- 🔧 Easy integration with GitHub Actions workflows
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

## Model Caching & Pre-built Docker Image

### Pre-built Docker Image (Recommended)

This action uses a **pre-built Docker image** published to GitHub Container Registry that includes:
- All Python dependencies pre-installed
- The ACE-Step-v1-3.5B model pre-downloaded
- All system dependencies (ffmpeg, etc.)

**Benefits:**
- ⚡ **Significantly faster execution** - No need to download the model on each run
- 🔒 **Consistent environment** - Same dependencies across all runs
- 💾 **Reduced bandwidth** - Model is cached in the image

The image is automatically built and published when code changes are pushed to the main branch.

**Image location:** `ghcr.io/audiohacking/acestep-action:latest`

### Local Caching (Alternative)

If you prefer to use local caching with `actions/cache@v4`:

1. Set the cache path to match the `model_cache_path` input (default: `~/.cache/acestep`)
2. Use a cache key that includes your requirements hash for automatic invalidation on dependency changes

Example:
```yaml
- uses: actions/cache@v4
  with:
    path: ~/.cache/acestep
    key: ${{ runner.os }}-acestep-models-${{ hashFiles('**/requirements.txt') }}
```

**Note:** The pre-built image already contains the model, so additional caching is typically not needed unless you want to experiment with different models.

## Development

### Project Structure

```
acestep-action/
├── action.yml                    # Action metadata and configuration
├── Dockerfile                    # Container definition with pre-downloaded model
├── requirements.txt              # Python dependencies
├── src/
│   └── main.py                  # Main action script
└── .github/
    └── workflows/
        ├── test.yml             # Test workflow
        └── build-docker.yml     # Docker image build and publish workflow
```

### Building the Docker Image

The Docker image is automatically built and published to `ghcr.io/audiohacking/acestep-action` when changes are pushed to the main branch.

To build locally:

```bash
docker build -t acestep-action .
```

To publish manually (requires appropriate permissions):

```bash
docker tag acestep-action ghcr.io/audiohacking/acestep-action:latest
docker push ghcr.io/audiohacking/acestep-action:latest
```

### Local Testing

You can test the action locally using Docker:

```bash
# Build the image
docker build -t acestep-action .

# Run with test parameters
docker run -e INPUT_PROMPT="upbeat chiptune" \
           -e INPUT_LYRICS="[inst]" \
           -e INPUT_DURATION="15.0" \
           acestep-action
```

### Using Local Dockerfile

To use the local Dockerfile instead of the pre-built image (for development), update `action.yml`:

```yaml
runs:
  using: 'docker'
  image: 'Dockerfile'  # Change from 'docker://ghcr.io/...'
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/audiohacking/acestep-action).
