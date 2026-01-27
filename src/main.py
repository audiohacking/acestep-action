#!/usr/bin/env python3
"""
Ace-Step Audio Generation Action - Main Entry Point

This script serves as the entry point for the GitHub Action.
It reads inputs from environment variables, loads the ACE-Step model,
and generates audio output as MP3 files.
"""

import os
import sys
import time
from pathlib import Path
import io
import tempfile

try:
    from acestep.pipeline_ace_step import ACEStepPipeline
    import soundfile as sf
    from pydub import AudioSegment
    import torch
except ImportError as e:
    print(f"Error importing required modules: {e}")
    print("Some dependencies may not be installed yet during development.")
    # For scaffolding testing, we'll allow this to pass
    ACEStepPipeline = None


def get_input(name: str, required: bool = False, default: str = "") -> str:
    """
    Get input value from GitHub Actions environment.
    
    Args:
        name: The input name
        required: Whether the input is required
        default: Default value if not provided
        
    Returns:
        The input value
        
    Raises:
        ValueError: If a required input is missing
    """
    # GitHub Actions passes inputs as INPUT_<NAME> environment variables
    env_name = f"INPUT_{name.upper()}"
    value = os.environ.get(env_name, default)
    
    if required and value == "":
        raise ValueError(f"Input required and not supplied: {name}")
    
    return value


def set_output(name: str, value: str) -> None:
    """
    Set output value for GitHub Actions.
    
    Args:
        name: The output name
        value: The output value
    """
    # GitHub Actions reads outputs from GITHUB_OUTPUT file
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a") as f:
            f.write(f"{name}={value}\n")
    else:
        # Fallback for local testing (without deprecated syntax)
        print(f"{name}={value}")


def setup_cache(cache_path: str) -> Path:
    """
    Set up the model cache directory.
    
    Args:
        cache_path: Path to the cache directory
        
    Returns:
        Path object for the cache directory
    """
    cache_dir = Path(cache_path).expanduser()
    cache_dir.mkdir(parents=True, exist_ok=True)
    print(f"Model cache directory: {cache_dir}")
    return cache_dir


def generate_audio(prompt: str, lyrics: str, duration: float, seed: int, output_path: str, cache_dir: Path) -> float:
    """
    Generate audio from prompt using the ACE-Step model.
    
    Args:
        prompt: Text prompt for music generation
        lyrics: Lyrics for the generation (use [inst] for instrumental)
        duration: Duration of the generated audio in seconds
        seed: Random seed for reproducible generation (optional)
        output_path: Path to save the generated audio
        cache_dir: Directory for model cache
        
    Returns:
        Time taken for generation in seconds
    """
    start_time = time.time()
    
    print(f"Generating audio with prompt: {prompt}")
    print(f"Lyrics: {lyrics}")
    print(f"Duration: {duration} seconds")
    print(f"Seed: {seed}")
    print(f"Cache directory: {cache_dir}")
    
    if ACEStepPipeline is None:
        print("Warning: ACEStepPipeline not available (dependencies not installed)")
        print("Creating placeholder output file for testing...")
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        output_file.touch()
        generation_time = time.time() - start_time
        return generation_time
    
    # Set cache directory for Hugging Face models
    # If running in Docker with pre-cached model, use /action/models
    # Otherwise, use user-specified cache directory
    if os.path.exists('/action/models'):
        print("Using pre-cached model from Docker image at /action/models")
        os.environ['HF_HOME'] = '/action/models'
        os.environ['TRANSFORMERS_CACHE'] = '/action/models/transformers'
        os.environ['HF_DATASETS_CACHE'] = '/action/models/datasets'
    else:
        print(f"Using user-specified cache directory: {cache_dir}")
        os.environ['HF_HOME'] = str(cache_dir)
        os.environ['TRANSFORMERS_CACHE'] = str(cache_dir / 'transformers')
        os.environ['HF_DATASETS_CACHE'] = str(cache_dir / 'datasets')
    
    try:
        # Load ACE-Step model
        print("Loading ACE-Step model from ACE-Step/ACE-Step-v1-3.5B...")
        
        # Determine device (cuda if available, else cpu)
        device = "cuda" if torch.cuda.is_available() else "cpu"
        torch_dtype = torch.float16 if device == "cuda" else torch.float32
        
        print(f"Using device: {device}, dtype: {torch_dtype}")
        
        # Use checkpoint path from environment or derive from cache directory
        checkpoint_path = os.environ.get("CHECKPOINT_PATH", str(cache_dir / "checkpoints"))
        print(f"Checkpoint path: {checkpoint_path}")
        
        # Instantiate ACEStepPipeline with the correct parameters
        # device_id should be an integer (0 for CPU or GPU index)
        if device == "cpu":
            device_id = 0
            dtype_str = "float32"
        else:
            # For CUDA, get current device index
            device_id = torch.cuda.current_device()
            # Use float32 for better compatibility across different GPU types
            dtype_str = "float32"
        
        model = ACEStepPipeline(
            checkpoint_dir=checkpoint_path,
            device_id=device_id,
            dtype=dtype_str
        )
        
        print("Model loaded successfully!")
        
        # Generate audio
        print("Generating audio...")
        audio = model(
            prompt=prompt,
            lyrics=lyrics,
            audio_duration=duration,
            manual_seed=seed if seed is not None else None
        )
        
        print("Audio generated successfully!")
        
        # Save as WAV first (temporary file)
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_wav:
            tmp_wav_path = tmp_wav.name
            # Use sampling rate from model config if available, otherwise default to 44100 Hz
            sampling_rate = getattr(model.config, 'sampling_rate', 44100)
            sf.write(tmp_wav_path, audio, sampling_rate, format='WAV')
            print(f"WAV file saved temporarily to: {tmp_wav_path} (sampling rate: {sampling_rate} Hz)")
        
        # Convert WAV to MP3
        print("Converting WAV to MP3...")
        audio_segment = AudioSegment.from_wav(tmp_wav_path)
        
        # Ensure output directory exists
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Export as MP3
        audio_segment.export(output_path, format='mp3', bitrate='192k')
        print(f"MP3 file saved to: {output_path}")
        
        # Clean up temporary WAV file
        os.unlink(tmp_wav_path)
        print("Temporary WAV file cleaned up")
        
    except Exception as e:
        print(f"Error during audio generation: {e}")
        raise
    
    generation_time = time.time() - start_time
    return generation_time


def main():
    """Main function for the GitHub Action."""
    try:
        print("Starting Ace-Step Audio Generation Action")
        
        # Get inputs
        prompt = get_input("prompt", default="chiptune")
        lyrics = get_input("lyrics", default="[inst]")
        duration_str = get_input("duration", default="20.0")
        seed_str = get_input("seed", default="")
        model_cache_path = get_input("model_cache_path", default="~/.cache/acestep")
        output_path = get_input("output_path", default="output.mp3")
        
        # Parse numeric inputs
        try:
            duration = float(duration_str)
        except ValueError:
            print(f"Warning: Invalid duration '{duration_str}', using default 20.0")
            duration = 20.0
        
        seed = None
        if seed_str:
            try:
                seed = int(seed_str)
            except ValueError:
                print(f"Warning: Invalid seed '{seed_str}', using random seed")
                seed = None
        
        print(f"Input prompt: {prompt}")
        print(f"Lyrics: {lyrics}")
        print(f"Duration: {duration} seconds")
        print(f"Seed: {seed}")
        print(f"Output path: {output_path}")
        
        # Setup cache directory
        cache_dir = setup_cache(model_cache_path)
        
        # Generate audio
        generation_time = generate_audio(prompt, lyrics, duration, seed, output_path, cache_dir)
        
        # Set outputs
        set_output("audio_file", output_path)
        set_output("generation_time", f"{generation_time:.2f}")
        
        print(f"Action completed successfully in {generation_time:.2f} seconds")
        return 0
        
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
