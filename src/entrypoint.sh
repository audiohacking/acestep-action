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

set -euxo pipefail

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
# Print variable context for debugging
# ---------------------------------------------------------------------------

echo "=== Variable context ==="
echo "CAPTION=${CAPTION}"
echo "LYRICS=${LYRICS}"
echo "DURATION=${DURATION}"
echo "SEED=${SEED}"
echo "INFERENCE_STEPS=${INFERENCE_STEPS}"
echo "SHIFT=${SHIFT}"
echo "VOCAL_LANGUAGE=${VOCAL_LANGUAGE}"
echo "OUTPUT_PATH=${OUTPUT_PATH}"
echo "WORKSPACE_ROOT=${WORKSPACE_ROOT}"
echo "GITHUB_WORKSPACE=${GITHUB_WORKSPACE:-<unset>}"

echo "=== Directory listings (initial) ==="
ls -lh /github/workspace || echo "(ls /github/workspace failed)"
ls -lh /tmp || echo "(ls /tmp failed)"

# ---------------------------------------------------------------------------
# Build request JSON (jq handles escaping of caption/lyrics)
# ---------------------------------------------------------------------------

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo "WORK_DIR=${WORK_DIR}"

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

echo "=== Directory listings (pre-move) ==="
echo "WORK_DIR=${WORK_DIR}"
ls -lh "$WORK_DIR"
ls -lh /tmp
ls -lh /github/workspace || echo "(ls /github/workspace failed)"

# ---------------------------------------------------------------------------
# Move output to requested location
# ---------------------------------------------------------------------------

if [ ! -f "$OUTPUT_WAV" ]; then
    echo "Error: expected output WAV not found at ${OUTPUT_WAV} — dit-vae may have failed or written to a different path" >&2
    echo "WORK_DIR contents:" >&2
    ls -lh "$WORK_DIR" >&2
    ls -lh /tmp >&2
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"
mv "$OUTPUT_WAV" "$OUTPUT_PATH"

echo "=== Directory listings (post-move) ==="
ls -lh "$WORK_DIR"
ls -lh "$(dirname "$OUTPUT_PATH")"
ls -lh /github/workspace || echo "(ls /github/workspace failed)"

if [ ! -f "$OUTPUT_PATH" ]; then
    echo "Error: move failed — file not found at ${OUTPUT_PATH}" >&2
    echo "Source dir (${WORK_DIR}) contents:" >&2
    ls -lh "$WORK_DIR" >&2
    echo "Destination dir ($(dirname "$OUTPUT_PATH")) contents:" >&2
    ls -lh "$(dirname "$OUTPUT_PATH")" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Copy output to /github/workspace so it is accessible from subsequent steps.
# /github/workspace is bind-mounted by the runner and is the only path
# guaranteed to be visible outside the container (see GitHub docs on
# Dockerfile actions).
# ---------------------------------------------------------------------------

ACTIONS_WORKSPACE="/github/workspace"
ACTIONS_OUTPUT="${ACTIONS_WORKSPACE}/output.wav"

echo "=== Directory listings (pre-copy) ==="
ls -lh "$ACTIONS_WORKSPACE" || echo "(ls ${ACTIONS_WORKSPACE} failed)"

if [ "$OUTPUT_PATH" != "$ACTIONS_OUTPUT" ]; then
    cp "$OUTPUT_PATH" "$ACTIONS_OUTPUT"
fi

echo "=== Directory listings (post-copy) ==="
ls -lh "$ACTIONS_WORKSPACE" || echo "(ls ${ACTIONS_WORKSPACE} failed)"

END_TIME=$(date +%s)
GENERATION_TIME=$(( END_TIME - START_TIME ))

echo ""
echo "=== Output ==="
echo "OUTPUT_PATH=${OUTPUT_PATH}"
echo "ACTIONS_WORKSPACE=${ACTIONS_WORKSPACE}"
echo "ACTIONS_OUTPUT=${ACTIONS_OUTPUT}"
if [ -f "$ACTIONS_OUTPUT" ]; then
    ls -lh "$ACTIONS_OUTPUT"
    echo "Generation time: ${GENERATION_TIME}s"
else
    echo "Error: generated file not found at ${ACTIONS_OUTPUT}" >&2
    echo "Directory listing of ${ACTIONS_WORKSPACE}:" >&2
    ls -lh "$ACTIONS_WORKSPACE" >&2 || echo "(ls ${ACTIONS_WORKSPACE} failed)" >&2
    echo "Directory listing of /tmp:" >&2
    ls -lh /tmp >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Set GitHub Actions outputs
# ---------------------------------------------------------------------------

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    # Always point to /github/workspace/output.wav so subsequent steps can
    # reliably access the file regardless of what output_path was specified.
    echo "audio_file=${ACTIONS_OUTPUT}" >> "$GITHUB_OUTPUT"
    echo "generation_time=${GENERATION_TIME}" >> "$GITHUB_OUTPUT"
fi

