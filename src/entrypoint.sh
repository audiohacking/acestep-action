#!/bin/bash
# Ace-Step Audio Generation — Docker action entrypoint.
#
# When running as a GitHub Actions Docker action, inputs arrive as
# INPUT_<NAME> environment variables.  Binaries and models are pre-installed
# in the Docker image at build time:
#
#   /action/bin/ace-qwen3   — Qwen3 causal LM (audio codes)
#   /action/bin/dit-vae     — DiT flow-matching + Oobleck VAE
#   /action/models/         — GGUF model files

set -euo pipefail

# ---------------------------------------------------------------------------
# Read inputs (Docker action convention: INPUT_<NAME>)
# ---------------------------------------------------------------------------

CAPTION="${INPUT_CAPTION:-chiptune}"
LYRICS="${INPUT_LYRICS:-}"
DURATION="${INPUT_DURATION:-20}"
SEED="${INPUT_SEED:-}"
INFERENCE_STEPS="${INPUT_INFERENCE_STEPS:-8}"
SHIFT="${INPUT_SHIFT:-3}"
VOCAL_LANGUAGE="${INPUT_VOCAL_LANGUAGE:-en}"
OUTPUT_PATH="${INPUT_OUTPUT_PATH:-}"

# ---------------------------------------------------------------------------
# Fixed in-image paths
# ---------------------------------------------------------------------------

MODEL_DIR="/action/models"
ACE_QWEN3="/action/bin/ace-qwen3"
DIT_VAE="/action/bin/dit-vae"

# ---------------------------------------------------------------------------
# Validate binaries
# ---------------------------------------------------------------------------

if [ ! -x "$ACE_QWEN3" ]; then
    echo "Error: ace-qwen3 binary not found at $ACE_QWEN3" >&2
    exit 1
fi
if [ ! -x "$DIT_VAE" ]; then
    echo "Error: dit-vae binary not found at $DIT_VAE" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Resolve output path: relative paths are relative to $GITHUB_WORKSPACE
# ---------------------------------------------------------------------------

WORKSPACE_ROOT="${GITHUB_WORKSPACE:-/github/workspace}"

# Default to workspace root if not specified
if [ -z "$OUTPUT_PATH" ]; then
    OUTPUT_PATH="${WORKSPACE_ROOT}/output.wav"
elif [[ "$OUTPUT_PATH" != /* ]]; then
    OUTPUT_PATH="${WORKSPACE_ROOT}/${OUTPUT_PATH}"
fi

# ---------------------------------------------------------------------------
# Build request JSON (jq handles escaping of caption/lyrics)
# ---------------------------------------------------------------------------

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

REQUEST_FILE="$WORK_DIR/request.json"

jq -n \
    --arg      caption         "${CAPTION}" \
    --arg      lyrics          "${LYRICS}" \
    --argjson  duration        "${DURATION}" \
    --argjson  inference_steps "${INFERENCE_STEPS}" \
    --argjson  shift           "${SHIFT}" \
    --arg      vocal_language  "${VOCAL_LANGUAGE}" \
    '{
        task_type:       "text2music",
        caption:         $caption,
        lyrics:          $lyrics,
        duration:        $duration,
        inference_steps: $inference_steps,
        guidance_scale:  1,
        shift:           $shift,
        vocal_language:  $vocal_language,
        audio_codes:     ""
    }' > "$REQUEST_FILE"

# Optionally add seed (must be a valid integer)
if [ -n "${SEED}" ]; then
    jq --argjson seed "${SEED}" '. + {seed: $seed}' \
        "$REQUEST_FILE" > "${REQUEST_FILE}.tmp"
    mv "${REQUEST_FILE}.tmp" "$REQUEST_FILE"
fi

echo "Request:"
cat "$REQUEST_FILE"

# ---------------------------------------------------------------------------
# Stage 1 — LLM: fills in bpm, keyscale, lyrics, audio_codes → request0.json
# ---------------------------------------------------------------------------

START_TIME=$(date +%s)

echo ""
echo "=== Stage 1: ace-qwen3 (LLM) ==="
"$ACE_QWEN3" \
    --request "$REQUEST_FILE" \
    --model   "$MODEL_DIR/acestep-5Hz-lm-4B-Q8_0.gguf"

# ace-qwen3 writes requestN.json alongside the input file
REQUEST0_FILE="${REQUEST_FILE%.json}0.json"

# ---------------------------------------------------------------------------
# Stage 2 — DiT + VAE: synthesises stereo 48 kHz WAV → request00.wav
# ---------------------------------------------------------------------------

echo ""
echo "=== Stage 2: dit-vae (DiT + VAE) ==="
"$DIT_VAE" \
    --request      "$REQUEST0_FILE" \
    --text-encoder "$MODEL_DIR/Qwen3-Embedding-0.6B-Q8_0.gguf" \
    --dit          "$MODEL_DIR/acestep-v15-turbo-Q8_0.gguf" \
    --vae          "$MODEL_DIR/vae-BF16.gguf"

# dit-vae writes requestN0.wav alongside the request0.json file
OUTPUT_WAV="${REQUEST0_FILE%.json}0.wav"

# ---------------------------------------------------------------------------
# Move output to requested location
# ---------------------------------------------------------------------------

mkdir -p "$(dirname "$OUTPUT_PATH")"
mv "$OUTPUT_WAV" "$OUTPUT_PATH"

END_TIME=$(date +%s)
GENERATION_TIME=$(( END_TIME - START_TIME ))

echo ""
echo "=== Output ==="
echo "Output path: $OUTPUT_PATH"
if [ -f "$OUTPUT_PATH" ]; then
    ls -lh "$OUTPUT_PATH"
    echo "Generation time: ${GENERATION_TIME}s"
else
    echo "Error: generated file not found at $OUTPUT_PATH" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Set GitHub Actions outputs
# ---------------------------------------------------------------------------

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "audio_file=${OUTPUT_PATH}" >> "$GITHUB_OUTPUT"
    echo "generation_time=${GENERATION_TIME}" >> "$GITHUB_OUTPUT"
fi

