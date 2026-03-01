#!/bin/bash
# Ace-Step Audio Generation — entrypoint for the composite GitHub Action.
# Reads inputs from environment variables set by action.yml, builds a request
# JSON, runs the two-stage acestep.cpp pipeline (ace-qwen3 → dit-vae), and
# writes the generated WAV to the requested output path.
#
# Required env vars (set by action.yml):
#   CAPTION          – text description / caption
#   LYRICS           – lyrics string (empty = LLM auto-generates)
#   DURATION         – audio duration in seconds (integer)
#   SEED             – random seed (empty = non-deterministic)
#   INFERENCE_STEPS  – DiT inference steps
#   SHIFT            – flow-matching shift parameter
#   VOCAL_LANGUAGE   – BCP-47 language code (en, fr, …)
#   OUTPUT_PATH      – desired output WAV path
#   MODEL_DIR        – directory containing downloaded GGUF files
#   BIN_DIR          – directory containing ace-qwen3 and dit-vae binaries

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

expand_path() {
    local p="$1"
    echo "${p/#\~/$HOME}"
}

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------

MODEL_DIR=$(expand_path "${MODEL_DIR:-~/.cache/acestep}")
BIN_DIR=$(expand_path "${BIN_DIR:-~/.cache/acestep-bin}")
OUTPUT_EXPANDED=$(expand_path "${OUTPUT_PATH:-output.wav}")

ACE_QWEN3="$BIN_DIR/ace-qwen3"
DIT_VAE="$BIN_DIR/dit-vae"

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
# Build request JSON (jq handles escaping of caption/lyrics)
# ---------------------------------------------------------------------------

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

REQUEST_FILE="$WORK_DIR/request.json"

jq -n \
    --arg      caption         "${CAPTION:-chiptune}" \
    --arg      lyrics          "${LYRICS:-}" \
    --argjson  duration        "${DURATION:-20}" \
    --argjson  inference_steps "${INFERENCE_STEPS:-8}" \
    --argjson  shift           "${SHIFT:-3}" \
    --arg      vocal_language  "${VOCAL_LANGUAGE:-en}" \
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
if [ -n "${SEED:-}" ]; then
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

mkdir -p "$(dirname "$OUTPUT_EXPANDED")"
mv "$OUTPUT_WAV" "$OUTPUT_EXPANDED"

END_TIME=$(date +%s)
GENERATION_TIME=$(( END_TIME - START_TIME ))

echo ""
echo "Audio saved to: $OUTPUT_EXPANDED"
echo "Generation time: ${GENERATION_TIME}s"

# ---------------------------------------------------------------------------
# Set GitHub Actions outputs
# ---------------------------------------------------------------------------

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "audio_file=${OUTPUT_EXPANDED}" >> "$GITHUB_OUTPUT"
    echo "generation_time=${GENERATION_TIME}" >> "$GITHUB_OUTPUT"
fi
