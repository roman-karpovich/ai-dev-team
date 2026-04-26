#!/usr/bin/env bash
set -euo pipefail

WORKING_DIR="${1:-}"
OUTPUT_FILE="${2:-}"
MODEL="${3:-gpt-5.5}"
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

exec "${CODEX_BIN:-codex}" exec --json -m "$MODEL" -c "reasoning.effort=$EFFORT" -s read-only -C "$WORKING_DIR" --skip-git-repo-check -o "$OUTPUT_FILE" -
