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

# Create a Python script for model download with better error handling
RUN echo 'import sys\n\
import torch\n\
import os\n\
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
    # Download the model\n\
    print("Downloading model from HuggingFace: ACE-Step/ACE-Step-v1-3.5B...")\n\
    model = ACEStepPipeline.from_pretrained(\n\
        "ACE-Step/ACE-Step-v1-3.5B",\n\
        torch_dtype=torch_dtype,\n\
        device=device\n\
    )\n\
    print("✓ Model loaded successfully")\n\
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
        for item in os.listdir(cache_dir)[:10]:\n\
            path = os.path.join(cache_dir, item)\n\
            if os.path.isdir(path):\n\
                print(f"  📁 {item}/")\n\
            else:\n\
                print(f"  📄 {item}")\n\
    else:\n\
        print("✗ ERROR: Cache directory not found!")\n\
        sys.exit(1)\n\
    \n\
    print("\\n" + "="*80)\n\
    print("✓ Model pre-download completed successfully!")\n\
    print("="*80)\n\
    sys.exit(0)\n\
    \n\
except ImportError as e:\n\
    print(f"\\n✗ ERROR: Failed to import ACEStepPipeline")\n\
    print(f"Import error: {e}")\n\
    print("\\nThis may indicate the acestep package is not properly installed.")\n\
    sys.exit(1)\n\
except Exception as e:\n\
    print(f"\\n✗ ERROR: Failed to download model")\n\
    print(f"Error type: {type(e).__name__}")\n\
    print(f"Error message: {e}")\n\
    import traceback\n\
    print("\\nFull traceback:")\n\
    traceback.print_exc()\n\
    sys.exit(1)\n\
' > /action/download_model.py && \
    python /action/download_model.py && \
    rm /action/download_model.py

# Copy action source code
COPY src/ ./src/

# Set the entry point
ENTRYPOINT ["python", "/action/src/main.py"]
