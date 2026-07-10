#!/usr/bin/env bash
set -euo pipefail

WORKING_DIR="${1:-}"
OUTPUT_FILE="${2:-}"
# Empty/absent model → omit -m so Codex resolves the model from ~/.codex/config.toml
# (single global source of truth; override per-project via .ai-dev-team.yml codex.model).
MODEL="${3:-}"
EFFORT="${4:-xhigh}"

if [ -z "$WORKING_DIR" ]; then
  echo "ERROR: working_dir is required" >&2
  exit 1
fi

if [ -z "$OUTPUT_FILE" ]; then
  echo "ERROR: output_file is required" >&2
  exit 1
fi

if [ ! -d "$WORKING_DIR" ]; then
  echo "ERROR: working_dir does not exist: $WORKING_DIR" >&2
  exit 1
fi

OUTPUT_PARENT="$(dirname "$OUTPUT_FILE")"
if [ ! -d "$OUTPUT_PARENT" ]; then
  echo "ERROR: output_file parent directory does not exist: $OUTPUT_PARENT" >&2
  exit 1
fi

MODEL_ARGS=()
if [ -n "$MODEL" ]; then
  MODEL_ARGS+=(-m "$MODEL")
fi

# ${arr[@]+...} guard: empty-array expansion is an unbound-variable error under
# `set -u` on bash 3.2 (macOS default).
exec "${CODEX_BIN:-codex}" exec --json ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} -c "reasoning.effort=$EFFORT" -s read-only -C "$WORKING_DIR" --skip-git-repo-check -o "$OUTPUT_FILE" -
