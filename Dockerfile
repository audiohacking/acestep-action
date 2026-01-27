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
# Install ACE-Step library first to ensure it's available for download_model.py
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir git+https://github.com/ACE-Step/ACE-Step.git && \
    pip install --no-cache-dir -r requirements.txt

# Allow model ID to be customized at build time
ARG ACESTEP_MODEL_ID=ACE-Step/ACE-Step-v1-3.5B

# Pre-download the ACE-Step model to include in the image
# This significantly speeds up action execution by avoiding model downloads
ENV HF_HOME=/action/models
ENV TRANSFORMERS_CACHE=/action/models/transformers
ENV HF_DATASETS_CACHE=/action/models/datasets
ENV HF_HUB_OFFLINE=0
ENV HF_HUB_DISABLE_TELEMETRY=1
ENV ACESTEP_MODEL_ID=${ACESTEP_MODEL_ID}
ENV CHECKPOINT_PATH=/action/models/checkpoints

# Create directories for model cache with proper permissions
RUN mkdir -p /action/models/transformers /action/models/datasets /action/models/checkpoints && \
    chmod -R 755 /action/models

# Copy and run the model download script
COPY download_model.py .
RUN python download_model.py && rm download_model.py

# Copy action source code
COPY src/ ./src/

# Set the entry point
ENTRYPOINT ["python", "/action/src/main.py"]
