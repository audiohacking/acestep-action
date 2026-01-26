#!/usr/bin/env python3
"""
Model Pre-download Script for Docker Build

This script downloads the ACE-Step model during Docker image build and verifies
that the model is properly cached for fast action execution.
"""

import sys
import torch
import os
import time


def main():
    """Main function to download and verify the ACE-Step model."""
    print("=" * 80)
    print("Starting ACE-Step model pre-download...")
    print("=" * 80)
    print(f"Python version: {sys.version}")
    print(f"PyTorch version: {torch.__version__}")
    print(f"CUDA available: {torch.cuda.is_available()}")
    print(f"HF_HOME: {os.environ.get('HF_HOME', 'not set')}")
    print("=" * 80)

    try:
        from acestep.pipeline_ace_step import ACEStepPipeline
        print("✓ Successfully imported ACEStepPipeline")

        # Determine device and dtype
        # Force CPU for container builds to ensure compatibility across different
        # host environments and because CUDA is typically not available during build
        device = "cpu"
        torch_dtype = torch.float32
        print(f"✓ Using device: {device}, dtype: {torch_dtype}")

        # Get model identifier from environment or use default
        model_id = os.environ.get("ACESTEP_MODEL_ID", "ACE-Step/ACE-Step-v1-3.5B")
        print(f"✓ Model identifier: {model_id}")

        # Download the model with timeout handling
        print(f"Downloading model from HuggingFace: {model_id}...")
        print("Note: This may take several minutes for large models...")
        start_time = time.time()

        model = ACEStepPipeline.from_pretrained(
            model_id,
            torch_dtype=torch_dtype,
            device=device
        )

        elapsed = time.time() - start_time
        print(f"✓ Model loaded successfully in {elapsed:.2f} seconds")

        # Verify the model cache
        cache_dir = os.environ.get("HF_HOME")
        if not cache_dir:
            print("✗ ERROR: HF_HOME environment variable not set!")
            return 1
            
        print(f"\nVerifying cache at: {cache_dir}")

        if os.path.exists(cache_dir):
            # Count files in cache
            file_count = sum(len(files) for _, _, files in os.walk(cache_dir))
            dir_count = sum(len(dirs) for _, dirs, _ in os.walk(cache_dir))
            print(f"✓ Cache directory contains {file_count} files in {dir_count} directories")

            # Show top-level structure
            print("\nTop-level cache structure:")
            for item in sorted(os.listdir(cache_dir))[:10]:
                path = os.path.join(cache_dir, item)
                if os.path.isdir(path):
                    subitem_count = len(os.listdir(path))
                    print(f"  📁 {item}/ ({subitem_count} items)")
                else:
                    size = os.path.getsize(path)
                    print(f"  📄 {item} ({size} bytes)")

            # Verify we have model files
            if file_count > 0:
                print("\n" + "=" * 80)
                print("✓ Model pre-download completed successfully!")
                print("✓ Model is cached and ready for use")
                print("=" * 80)
                return 0
            else:
                print("\n✗ WARNING: Cache directory exists but contains no files!")
                return 1
        else:
            print("✗ ERROR: Cache directory not found!")
            return 1

    except ImportError as e:
        print(f"\n✗ ERROR: Failed to import ACEStepPipeline")
        print(f"Import error: {e}")
        print("\nThis may indicate the acestep package is not properly installed.")
        print("Verify that the package was installed successfully:")
        print("  pip install git+https://github.com/ACE-Step/ACE-Step.git")
        print("And that all dependencies in requirements.txt are installed.")
        import traceback
        print("\nFull traceback:")
        traceback.print_exc()
        return 1

    except Exception as e:
        print(f"\n✗ ERROR: Failed to download model")
        print(f"Error type: {type(e).__name__}")
        print(f"Error message: {e}")
        import traceback
        print("\nFull traceback:")
        traceback.print_exc()
        print("\n" + "=" * 80)
        print("Build failed: Model download unsuccessful")
        print("=" * 80)
        return 1


if __name__ == "__main__":
    sys.exit(main())
