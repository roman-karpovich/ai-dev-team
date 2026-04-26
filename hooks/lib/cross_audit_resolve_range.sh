#!/usr/bin/env bash
set -euo pipefail

INVALID_SYNTAX="ERROR: invalid ref-range syntax (expected refA..refB or refA...refB, optional -- <path>)"

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

slug_part() {
  printf '%s' "$1" | LC_ALL=C sed 's/[^a-zA-Z0-9._-]/-/g' | cut -c1-60
}

die_invalid_syntax() {
  echo "$INVALID_SYNTAX" >&2
  exit 1
}

arg="${1:-}"
range_part="$arg"
path_filter=""

if [[ "$arg" == *" -- "* ]]; then
  suffix="${arg#* -- }"
  if [[ "$suffix" == *" -- "* ]]; then
    die_invalid_syntax
  fi
  range_part="${arg%% -- *}"
  path_filter=$(trim "$suffix")
fi

range_part=$(trim "$range_part")

if [[ "$range_part" == *"..."* ]]; then
  refA="${range_part%%...*}"
  refB="${range_part#*...}"
  op="..."
elif [[ "$range_part" == *".."* ]]; then
  refA="${range_part%%..*}"
  refB="${range_part#*..}"
  op=".."
else
  die_invalid_syntax
fi

if [ -z "$refA" ] || [ -z "$refB" ]; then
  die_invalid_syntax
fi

shaA=$(git rev-parse --verify "$refA" 2>/dev/null || true)
if [ -z "$shaA" ]; then
  echo "ERROR: ref does not exist: $refA" >&2
  exit 1
fi

shaB=$(git rev-parse --verify "$refB" 2>/dev/null || true)
if [ -z "$shaB" ]; then
  echo "ERROR: ref does not exist: $refB" >&2
  exit 1
fi

if [ "$shaA" = "$shaB" ]; then
  echo "ERROR: no changes between refs (refA == refB at $shaA)" >&2
  exit 1
fi

slug_pair="$(slug_part "$refA")__$(slug_part "$refB")"

printf 'refA=%s\n' "$refA"
printf 'refB=%s\n' "$refB"
printf 'op=%s\n' "$op"
printf 'path_filter=%s\n' "$path_filter"
printf 'slug_pair=%s\n' "$slug_pair"
