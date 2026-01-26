FROM python:3.10-slim

LABEL maintainer="audiohacking"
LABEL description="Ace-Step Audio Generation Action"

# Set working directory
WORKDIR /action

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    wget \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Pre-download the ACE-Step model to include in the image
# This significantly speeds up action execution by avoiding model downloads
ENV HF_HOME=/action/models
ENV TRANSFORMERS_CACHE=/action/models/transformers
ENV HF_DATASETS_CACHE=/action/models/datasets
ENV HF_HUB_OFFLINE=0
ENV HF_HUB_DISABLE_TELEMETRY=1

# Create directories for model cache
RUN mkdir -p /action/models/transformers /action/models/datasets

# Create a Python script for model download with comprehensive error handling
RUN echo 'import sys\n\
import torch\n\
import os\n\
import time\n\
\n\
print("="*80)\n\
print("Starting ACE-Step model pre-download...")\n\
print("="*80)\n\
print(f"Python version: {sys.version}")\n\
print(f"PyTorch version: {torch.__version__}")\n\
print(f"CUDA available: {torch.cuda.is_available()}")\n\
print(f"HF_HOME: {os.environ.get(\"HF_HOME\", \"not set\")}")\n\
print("="*80)\n\
\n\
try:\n\
    from acestep.pipeline_ace_step import ACEStepPipeline\n\
    print("✓ Successfully imported ACEStepPipeline")\n\
    \n\
    # Determine device and dtype\n\
    device = "cpu"  # Force CPU for container builds\n\
    torch_dtype = torch.float32\n\
    print(f"✓ Using device: {device}, dtype: {torch_dtype}")\n\
    \n\
    # Download the model with timeout handling\n\
    print("Downloading model from HuggingFace: ACE-Step/ACE-Step-v1-3.5B...")\n\
    print("Note: This may take several minutes for large models...")\n\
    start_time = time.time()\n\
    \n\
    model = ACEStepPipeline.from_pretrained(\n\
        "ACE-Step/ACE-Step-v1-3.5B",\n\
        torch_dtype=torch_dtype,\n\
        device=device\n\
    )\n\
    \n\
    elapsed = time.time() - start_time\n\
    print(f"✓ Model loaded successfully in {elapsed:.2f} seconds")\n\
    \n\
    # Verify the model cache\n\
    cache_dir = os.environ.get("HF_HOME", "/action/models")\n\
    print(f"\\nVerifying cache at: {cache_dir}")\n\
    \n\
    if os.path.exists(cache_dir):\n\
        # Count files in cache\n\
        file_count = sum(len(files) for _, _, files in os.walk(cache_dir))\n\
        dir_count = sum(len(dirs) for _, dirs, _ in os.walk(cache_dir))\n\
        print(f"✓ Cache directory contains {file_count} files in {dir_count} directories")\n\
        \n\
        # Show top-level structure\n\
        print("\\nTop-level cache structure:")\n\
        for item in sorted(os.listdir(cache_dir))[:10]:\n\
            path = os.path.join(cache_dir, item)\n\
            if os.path.isdir(path):\n\
                subitem_count = len(os.listdir(path))\n\
                print(f"  📁 {item}/ ({subitem_count} items)")\n\
            else:\n\
                size = os.path.getsize(path)\n\
                print(f"  📄 {item} ({size} bytes)")\n\
        \n\
        # Verify we have model files\n\
        if file_count > 0:\n\
            print("\\n" + "="*80)\n\
            print("✓ Model pre-download completed successfully!")\n\
            print("✓ Model is cached and ready for use")\n\
            print("="*80)\n\
            sys.exit(0)\n\
        else:\n\
            print("\\n✗ WARNING: Cache directory exists but contains no files!")\n\
            sys.exit(1)\n\
    else:\n\
        print("✗ ERROR: Cache directory not found!")\n\
        sys.exit(1)\n\
    \n\
except ImportError as e:\n\
    print(f"\\n✗ ERROR: Failed to import ACEStepPipeline")\n\
    print(f"Import error: {e}")\n\
    print("\\nThis may indicate the acestep package is not properly installed.")\n\
    print("Check that all dependencies in requirements.txt are installed.")\n\
    import traceback\n\
    print("\\nFull traceback:")\n\
    traceback.print_exc()\n\
    sys.exit(1)\n\
except Exception as e:\n\
    print(f"\\n✗ ERROR: Failed to download model")\n\
    print(f"Error type: {type(e).__name__}")\n\
    print(f"Error message: {e}")\n\
    import traceback\n\
    print("\\nFull traceback:")\n\
    traceback.print_exc()\n\
    print("\\n" + "="*80)\n\
    print("Build failed: Model download unsuccessful")\n\
    print("="*80)\n\
    sys.exit(1)\n\
' > /action/download_model.py && \
    python /action/download_model.py && \
    rm /action/download_model.py

# Copy action source code
COPY src/ ./src/

# Set the entry point
ENTRYPOINT ["python", "/action/src/main.py"]
