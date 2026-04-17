#!/usr/bin/env bash
# build_pr_files.sh — emit the `pr_files:` YAML block for findings frontmatter.
#
# Inputs:
#   stdin               — JSON array of {filename, status, previous_filename, patch_present}
#                         objects, produced by:
#                           gh api "repos/<owner>/<repo>/pulls/<N>/files" --paginate \
#                             --jq '.[] | {filename, status, previous_filename, patch_present: (.patch != null)}' \
#                             | jq -s '.'
#
#   --ls-tree-output <path>
#                       — file containing real `git ls-tree HEAD -- <filename1> <filename2> ...`
#                         output. Tab-delimited grammar: `<mode> SP <type> SP <object>\t<path>`.
#                         Mode 160000 → is_submodule: true; any other mode or absent filename → false.
#                         (Same contract as the cross-auditor running `git ls-tree HEAD -- <filename>`
#                         inside its isolated worktree post-`gh pr checkout`.)
#
# Output:
#   stdout              — canonical YAML block (`pr_files:` list with 5 keys per entry in a fixed
#                         order: filename / status / previous_filename / patch_present / is_submodule).
#                         No patch-text fallback: the jq projection strips .patch, so only git ls-tree
#                         can be used for submodule detection (spec X25).
#
# Notes:
#   - Uses python3 stdlib only (no PyYAML dependency — matches tests/smoke.sh style).
#   - Exact-string-matches each pr_changed_files[].filename against the <path> column after the tab.
#   - null / missing previous_filename preserved as `null` in output (YAML convention).

set -euo pipefail

LS_TREE_PATH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ls-tree-output)
      LS_TREE_PATH="${2:-}"
      shift 2
      ;;
    *)
      echo "build_pr_files.sh: unknown argument '$1'" >&2
      exit 2
      ;;
  esac
done

if [ -z "$LS_TREE_PATH" ]; then
  echo "build_pr_files.sh: --ls-tree-output <path> is required" >&2
  exit 2
fi

if [ ! -f "$LS_TREE_PATH" ]; then
  echo "build_pr_files.sh: ls-tree output file not found: $LS_TREE_PATH" >&2
  exit 2
fi

# Buffer stdin (pr_changed_files JSON) so the heredoc-driven python3 can still consume it.
STDIN_PAYLOAD=$(cat)

LS_TREE_PATH="$LS_TREE_PATH" STDIN_PAYLOAD="$STDIN_PAYLOAD" python3 <<'PY'
import json
import os
import sys

ls_tree_path = os.environ["LS_TREE_PATH"]
raw = os.environ["STDIN_PAYLOAD"]
try:
    entries = json.loads(raw)
except json.JSONDecodeError as exc:
    print(f"build_pr_files.sh: stdin is not valid JSON: {exc}", file=sys.stderr)
    sys.exit(2)

if not isinstance(entries, list):
    print("build_pr_files.sh: stdin JSON must be an array of pr_changed_files objects", file=sys.stderr)
    sys.exit(2)

# Parse ls-tree output: real git ls-tree grammar `<mode> SP <type> SP <object>\t<path>`.
# Tab separates the first three space-delimited fields from the path column. Exact-string
# match on <path>. Mode 160000 (gitlink) → submodule.
submodules = set()
with open(ls_tree_path) as fh:
    for line in fh:
        line = line.rstrip("\n")
        if not line:
            continue
        if "\t" not in line:
            # Malformed line — skip silently; missing filename → is_submodule: false by contract.
            continue
        meta, path = line.split("\t", 1)
        parts = meta.split(" ")
        if len(parts) < 3:
            continue
        mode = parts[0]
        if mode == "160000":
            submodules.add(path)


def yaml_scalar(value):
    """Render a scalar for our fixed-schema YAML output.

    - None → `null`
    - bool → `true` / `false`
    - str  → bare if safe, else single-quoted
    - int  → as-is
    """
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, str):
        # Bare if it only uses filename-safe characters and doesn't collide with YAML specials.
        safe = value and all(
            c.isalnum() or c in "._-/+"
            for c in value
        )
        specials = {"null", "true", "false", "yes", "no", "on", "off", "~"}
        if safe and value.lower() not in specials:
            return value
        escaped = value.replace("'", "''")
        return f"'{escaped}'"
    raise TypeError(f"unsupported scalar type: {type(value).__name__}")


lines = ["pr_files:"]
for entry in entries:
    filename = entry.get("filename")
    if filename is None:
        print("build_pr_files.sh: entry missing 'filename'", file=sys.stderr)
        sys.exit(2)
    status = entry.get("status")
    previous_filename = entry.get("previous_filename", None)
    patch_present = bool(entry.get("patch_present", False))
    is_submodule = filename in submodules

    lines.append(f"  - filename: {yaml_scalar(filename)}")
    lines.append(f"    status: {yaml_scalar(status)}")
    lines.append(f"    previous_filename: {yaml_scalar(previous_filename)}")
    lines.append(f"    patch_present: {yaml_scalar(patch_present)}")
    lines.append(f"    is_submodule: {yaml_scalar(is_submodule)}")

sys.stdout.write("\n".join(lines) + "\n")
PY
