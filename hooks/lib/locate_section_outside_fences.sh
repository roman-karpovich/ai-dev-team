#!/usr/bin/env bash
# locate_section_outside_fences.sh — deterministic fence-aware section locator.
#
# Decides whether a markdown file contains a section-heading line matching a
# given pattern OUTSIDE every fenced code block (and, optionally, between a
# bounding pair of section headings). This replaces the LLM-prose §1.1
# "absent-section check" with a deterministic, fixture-tested helper.
#
# Invocation:
#   locate_section_outside_fences.sh <file> <section-ere> [<after-ere> <before-ere>]
#
#   <file>          markdown file to scan.
#   <section-ere>   Python `re` pattern the target heading line must match
#                   (re.compile() is the validity gate — NOT POSIX ERE).
#   <after-ere>     optional. With <before-ere>, a match counts as `found`
#   <before-ere>    only if it lies strictly after the first column-0
#                   outside-fence line matching <after-ere> AND strictly
#                   before the first column-0 outside-fence line matching
#                   <before-ere>. Both must be supplied together.
#
# Exit codes — a 3-way partition:
#   0  found       (stdout: "found")
#   1  not-found   (stdout: "not-found")
#   2  arg-error   (stderr: "⚠ locate_section_outside_fences: ...")
#
# Fence grammar — column-0 BACKTICK fences only:
#   Opener — ^(`{3,})[^`]*$        (N>=3 backticks + optional info string)
#   Closer — ^`{N,}\s*$           (>=N backticks, no info string)
# A closer longer than its opener still closes; a shorter run does not.
#
# Deliberate, documented out-of-scope limitations (NOT silent gaps):
#   - CommonMark `~~~` TILDE fences are NOT recognized — a heading inside a
#     `~~~` block is treated as a real outside-fence heading. This is an
#     accepted scope decision: spec-template.md and every spec in design/ use
#     backtick fences exclusively, so a section placed only inside a tilde
#     fence is not an observed input. Reactivate via a follow-up spec if a
#     real spec ever needs `~~~` fences.
#   - Up-to-3-space-indented CommonMark fences are also out of scope; every
#     fence in this repo opens at column 0.

set -u

ERR_PREFIX='⚠ locate_section_outside_fences:'

# --- Arg-error validation precedence (first failing check wins) ---

# 1. arity
if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
  echo "$ERR_PREFIX expected <file> <section-ere> [<after-ere> <before-ere>] (2-4 args)" >&2
  exit 2
fi

FILE="$1"
SECTION_ERE="$2"

# 2. <file>
if [ -z "$FILE" ] || [ ! -e "$FILE" ] || [ ! -r "$FILE" ]; then
  echo "$ERR_PREFIX <file> missing or unreadable" >&2
  exit 2
fi

# 3. <section-ere> — non-empty and re.compile()-acceptable
if [ -z "$SECTION_ERE" ] || ! python3 -c 'import re,sys; re.compile(sys.argv[1])' "$SECTION_ERE" 2>/dev/null; then
  echo "$ERR_PREFIX <section-ere> missing, empty, or not a pattern re.compile() accepts" >&2
  exit 2
fi

# 4. bound pair — both supplied (argc 3 fails), each non-empty + compilable
HAS_BOUNDS=0
AFTER_ERE=""
BEFORE_ERE=""
if [ "$#" -eq 3 ]; then
  echo "$ERR_PREFIX bound patterns must be supplied as a non-empty pair re.compile() accepts" >&2
  exit 2
fi
if [ "$#" -eq 4 ]; then
  AFTER_ERE="$3"
  BEFORE_ERE="$4"
  if [ -z "$AFTER_ERE" ] || [ -z "$BEFORE_ERE" ] \
     || ! python3 -c 'import re,sys; re.compile(sys.argv[1]); re.compile(sys.argv[2])' "$AFTER_ERE" "$BEFORE_ERE" 2>/dev/null; then
    echo "$ERR_PREFIX bound patterns must be supplied as a non-empty pair re.compile() accepts" >&2
    exit 2
  fi
  HAS_BOUNDS=1
fi

# --- Scan ---
python3 - "$FILE" "$SECTION_ERE" "$HAS_BOUNDS" "$AFTER_ERE" "$BEFORE_ERE" <<'PYEOF'
import re, sys

path, section_ere, has_bounds, after_ere, before_ere = sys.argv[1:6]
has_bounds = has_bounds == "1"

section_re = re.compile(section_ere)
after_re = re.compile(after_ere) if has_bounds else None
before_re = re.compile(before_ere) if has_bounds else None

with open(path, "r", encoding="utf-8", errors="replace") as handle:
    raw = handle.read()

# str.splitlines() normalizes \n, \r\n, \r alike and drops the terminator —
# CRLF-agnostic: no trailing \r to defeat a $-anchored pattern.
lines = raw.splitlines()

# Column-0 fence grammar.
OPENER = re.compile(r"^(`{3,})[^`]*$")

open_run = 0          # backtick run length of the currently open fence; 0 = none

# Candidate lines: neither a fence delimiter nor inside an open fence.
# Record (line-index, text) for every such candidate.
candidates = []

for line in lines:
    if open_run:
        # Inside a fence — test ONLY the closer parameterised by N=open_run.
        # A closer is >=N backticks with no info string (only trailing ws).
        if re.match(r"^`{" + str(open_run) + r",}\s*$", line):
            open_run = 0   # the closer line is fence syntax — never a candidate
        # else: fence content (including opener-shaped lines) — not a candidate
        continue
    # No fence open — test the opener.
    m = OPENER.match(line)
    if m:
        open_run = len(m.group(1))  # the opener line is fence syntax
        continue
    # A genuine candidate line (outside any fence, not a delimiter).
    candidates.append(line)

# section / after / before matches are evaluated ONLY over candidate lines.
def first_match(pattern):
    for idx, text in enumerate(candidates):
        if pattern.search(text):
            return idx
    return None

if has_bounds:
    after_idx = first_match(after_re)
    before_idx = first_match(before_re)
    for idx, text in enumerate(candidates):
        if not section_re.search(text):
            continue
        if after_idx is None or idx <= after_idx:
            continue
        if before_idx is None or idx >= before_idx:
            continue
        print("found")
        sys.exit(0)
    print("not-found")
    sys.exit(1)
else:
    for text in candidates:
        if section_re.search(text):
            print("found")
            sys.exit(0)
    print("not-found")
    sys.exit(1)
PYEOF
exit $?
