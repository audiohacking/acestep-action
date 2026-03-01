FROM ubuntu:22.04

LABEL maintainer="audiohacking"
LABEL description="Ace-Step Audio Generation Action — acestep.cpp engine with pre-bundled models"

# Prevent interactive prompts during apt-get
ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# System dependencies
# ---------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        cmake \
        build-essential \
        pkg-config \
        libopenblas-dev \
        python3-pip \
        jq \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Build ace-qwen3 and dit-vae from audiohacking/acestep.cpp
# ---------------------------------------------------------------------------
RUN git clone --depth 1 --recurse-submodules \
        https://github.com/audiohacking/acestep.cpp /tmp/acestep-cpp && \
    cd /tmp/acestep-cpp && \
    mkdir build && cd build && \
    cmake .. -DGGML_BLAS=ON -DCMAKE_BUILD_TYPE=Release && \
    cmake --build . --config Release -j$(nproc) && \
    mkdir -p /action/bin && \
    cp ace-qwen3 dit-vae /action/bin/ && \
    cp libggml.so.0 /usr/local/lib/ && \
    ldconfig && \
    cd / && rm -rf /tmp/acestep-cpp

# ---------------------------------------------------------------------------
# Pre-download GGUF models from Serveurperso/ACE-Step-1.5-GGUF
# Four files totalling ~7.7 GB (Q8_0 turbo essentials)
# ---------------------------------------------------------------------------
ARG GGUF_REPO=Serveurperso/ACE-Step-1.5-GGUF
ARG GGUF_QUANT=Q8_0

ENV GGUF_REPO=${GGUF_REPO}

RUN pip3 install --no-cache-dir hf && \
    mkdir -p /action/models && \
    hf download --quiet "${GGUF_REPO}" "vae-BF16.gguf"                     --local-dir /action/models && \
    hf download --quiet "${GGUF_REPO}" "Qwen3-Embedding-0.6B-${GGUF_QUANT}.gguf" --local-dir /action/models && \
    hf download --quiet "${GGUF_REPO}" "acestep-5Hz-lm-4B-${GGUF_QUANT}.gguf"   --local-dir /action/models && \
    hf download --quiet "${GGUF_REPO}" "acestep-v15-turbo-${GGUF_QUANT}.gguf"    --local-dir /action/models

# ---------------------------------------------------------------------------
# Copy and install entrypoint
# ---------------------------------------------------------------------------
COPY src/entrypoint.sh /action/entrypoint.sh
RUN chmod +x /action/entrypoint.sh

ENTRYPOINT ["/action/entrypoint.sh"]
