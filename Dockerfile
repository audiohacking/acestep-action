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
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy action source code
COPY src/ ./src/

# Set the entry point
ENTRYPOINT ["python", "/action/src/main.py"]
