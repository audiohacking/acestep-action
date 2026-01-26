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

RUN mkdir -p /action/models && \
    python -c "from acestep.pipeline_ace_step import ACEStepPipeline; \
    import torch; \
    print('Pre-downloading ACE-Step model...'); \
    model = ACEStepPipeline.from_pretrained('ACE-Step/ACE-Step-v1-3.5B', torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32, device='cpu'); \
    print('Model downloaded and cached in image')" || echo "Model pre-download skipped (may not be available yet)"

# Copy action source code
COPY src/ ./src/

# Set the entry point
ENTRYPOINT ["python", "/action/src/main.py"]
