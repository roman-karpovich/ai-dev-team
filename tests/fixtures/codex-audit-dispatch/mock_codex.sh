#!/usr/bin/env bash
set -euo pipefail

outfile=""

while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then
    shift
    outfile="${1:-}"
  fi
  shift || true
done

cat >/dev/null

printf '%s' '{"final":"ok-mock-response"}' > "$outfile"
printf '%s\n' '{"type":"task_started"}'
printf '%s\n' '{"type":"task_complete"}'
