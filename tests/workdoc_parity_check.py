#!/usr/bin/env python3
"""
Workdoc Assertion-count Parity (WAP) check — deterministic helper.

Enforces two parity invariants per spec/workdoc step:

INV-1 (workdoc-internal):
    For each workdoc step where `expected_pass_pattern` parses as a pure integer
    AND `passing_test_cmd` contains at least one `n=$((n+1))` occurrence —
    the parsed integer MUST equal the count of `n=$((n+1))` substrings inside
    `passing_test_cmd`.

INV-2 (spec ↔ workdoc):
    For each `## 6.1`-section step parenthetical of the form
    `(<int> expected_pass increments<.|, …>)`, the parsed integer MUST equal
    the corresponding workdoc step's `expected_pass_pattern` integer.

Both INVs degrade to N/A when their precondition is not met (non-integer
pattern, missing parenthetical, missing block, etc.) — N/A is never DRIFT.

CLI:
    python3 tests/workdoc_parity_check.py <workdoc> [--spec <spec>] [--step <N>]

Output (one line per applicable verdict, em-dash separator):
    step 1 — OK (...)
    step 2 — DRIFT INV-1 (...)
    step 2 — DRIFT INV-2 (...)
    step 3 — N/A (...)

Exit status:
    0 — every applicable step is OK (no DRIFT lines emitted)
    1 — at least one DRIFT line emitted
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Em-dash glyph used in output lines — matches spec §3.4 byte-exact.
EMDASH = "—"

# Step heading: "## Step <N>:" optionally with trailing prose.
STEP_HEADING_RE = re.compile(r"^##\s+Step\s+(\d+)\s*:")

# YAML-ish key recognizers inside a Planned block.
KEY_INLINE_RE = re.compile(r"^(?P<key>[A-Za-z_][A-Za-z0-9_]*)\s*:\s*(?P<value>.*?)\s*$")
KEY_BLOCK_RE = re.compile(r"^(?P<key>[A-Za-z_][A-Za-z0-9_]*)\s*:\s*\|\s*$")
FENCE_RE = re.compile(r"^\s*```")

# Spec §6.1 step bullet: "- **Step <N>**: ... (<int> expected_pass increments...)".
SPEC_STEP_BULLET_RE = re.compile(r"^[-*]\s+(?:\*\*)?Step\s+(\d+)(?:\*\*)?\s*:")
SPEC_PAREN_RE = re.compile(r"\((\d+)\s+expected_pass\s+increments?\b")

# Spec §6.1 section heading (we accept "## 6.1" with optional trailing prose).
SPEC_61_HEADING_RE = re.compile(r"^#{2,4}\s+6\.1\b")
# Any other "## <digit>" heading terminates §6.1 scope.
SPEC_NEXT_SECTION_RE = re.compile(r"^#{2,4}\s+\d+(\.\d+)?\b")


def _strip_block_indent(lines: List[str]) -> str:
    """Strip the common leading indent from a YAML block-scalar body."""
    non_empty = [ln for ln in lines if ln.strip()]
    if not non_empty:
        return ""
    indent = min(len(ln) - len(ln.lstrip(" ")) for ln in non_empty)
    return "\n".join(ln[indent:] if len(ln) >= indent else ln for ln in lines)


def parse_workdoc_steps(path: Path) -> Dict[int, Dict[str, str]]:
    """
    Parse workdoc into {step_number: {key: value, ...}}.

    Only keys that appear inside a `### Planned` block beneath a `## Step N:`
    heading are captured. Both inline (`key: value`) and block-`|` styles are
    supported for any key — we focus on `passing_test_cmd` and
    `expected_pass_pattern` but the parser is generic.
    """
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    steps: Dict[int, Dict[str, str]] = {}

    current_step: Optional[int] = None
    in_planned = False
    in_fence = False
    # When parsing a block-`|` value:
    block_key: Optional[str] = None
    block_indent: Optional[int] = None
    block_lines: List[str] = []

    def _flush_block() -> None:
        nonlocal block_key, block_indent, block_lines
        if block_key is not None and current_step is not None:
            steps.setdefault(current_step, {})[block_key] = _strip_block_indent(
                block_lines
            )
        block_key = None
        block_indent = None
        block_lines = []

    for raw in lines:
        stripped = raw.rstrip("\n")

        # In-block continuation? Lines belong to block-scalar while indented at
        # >= block_indent OR empty.
        if block_key is not None:
            if stripped.strip() == "":
                block_lines.append("")
                continue
            indent = len(stripped) - len(stripped.lstrip(" "))
            if block_indent is not None and indent >= block_indent and indent > 0:
                block_lines.append(stripped)
                continue
            # De-indent — terminates the block. Fall through to process this line.
            _flush_block()

        fence_match = FENCE_RE.match(stripped)
        if fence_match:
            in_fence = not in_fence
            continue
        if in_fence:
            continue

        step_match = STEP_HEADING_RE.match(stripped)
        if step_match:
            current_step = int(step_match.group(1))
            in_planned = False
            steps.setdefault(current_step, {})
            continue

        if current_step is None:
            continue

        # Track Planned/Observed mode.
        if stripped.startswith("### "):
            heading = stripped[4:].strip().lower()
            in_planned = heading == "planned"
            continue
        if stripped.startswith("## ") or stripped.startswith("---"):
            in_planned = False
            continue

        if not in_planned:
            continue

        block_match = KEY_BLOCK_RE.match(stripped)
        if block_match:
            key = block_match.group("key")
            # Body indent is determined by the first non-empty body line; track
            # the heading indent as a floor (must be greater than this).
            heading_indent = len(stripped) - len(stripped.lstrip(" "))
            block_key = key
            block_indent = heading_indent + 1  # any indent strictly past heading
            block_lines = []
            continue

        inline_match = KEY_INLINE_RE.match(stripped)
        if inline_match:
            key = inline_match.group("key")
            value = inline_match.group("value")
            steps.setdefault(current_step, {})[key] = value
            continue

    # Flush any tail block.
    _flush_block()
    return steps


def parse_spec_61_parentheticals(path: Path) -> Tuple[Dict[int, int], Dict[int, str]]:
    """
    Parse spec §6.1 step bullets and extract `(<int> expected_pass increments…)`.

    Returns ({step_number: integer_count}, {step_number: raw_parenthetical_text}).
    Steps without the parenthetical are omitted from both results (INV-2 is N/A
    for them).
    """
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    result: Dict[int, int] = {}
    result_malformed: Dict[int, str] = {}
    in_fence = False
    in_61 = False
    current_step: Optional[int] = None
    current_buf: List[str] = []

    def _commit() -> None:
        nonlocal current_step, current_buf, result_malformed
        if current_step is not None and current_buf:
            joined = " ".join(current_buf)
            has_expected_pass_parenthetical = "expected_pass increment" in joined
            match = SPEC_PAREN_RE.search(joined)
            if match:
                result[current_step] = int(match.group(1))
            elif has_expected_pass_parenthetical:
                result_malformed[current_step] = joined
        current_step = None
        current_buf = []

    for raw in lines:
        stripped = raw.rstrip("\n")

        fence_match = FENCE_RE.match(stripped)
        if fence_match:
            in_fence = not in_fence
            continue
        if in_fence:
            continue

        if SPEC_61_HEADING_RE.match(stripped):
            _commit()
            in_61 = True
            continue
        if (
            in_61
            and SPEC_NEXT_SECTION_RE.match(stripped)
            and not SPEC_61_HEADING_RE.match(stripped)
        ):
            _commit()
            in_61 = False
            continue
        if not in_61:
            continue

        bullet_match = SPEC_STEP_BULLET_RE.match(stripped)
        if bullet_match:
            _commit()
            current_step = int(bullet_match.group(1))
            current_buf = [stripped]
            continue

        if current_step is not None:
            # Continuation lines (wrapped bullet content) — accumulate until next
            # bullet/heading.
            if stripped.lstrip().startswith(("- ", "* ")):
                _commit()
                continue
            current_buf.append(stripped)

    _commit()
    return result, result_malformed


def count_n_increments(passing_cmd: str) -> int:
    """Count literal `n=$((n+1))` substrings inside a passing_test_cmd block."""
    return passing_cmd.count("n=$((n+1))")


def parse_int_or_none(value: str) -> Optional[int]:
    """Return int(value) if `value` (after stripping surrounding quotes) is a
    pure non-negative integer literal, else None."""
    if value is None:
        return None
    v = value.strip()
    # Strip surrounding quotes (single or double) if both present and matched.
    if len(v) >= 2 and v[0] == v[-1] and v[0] in ("'", '"'):
        v = v[1:-1].strip()
    if v.isdigit():
        return int(v)
    return None


def evaluate(
    workdoc_steps: Dict[int, Dict[str, str]],
    spec_parens: Dict[int, int],
    only_step: Optional[int] = None,
    spec_malformed: Optional[Dict[int, str]] = None,
) -> Tuple[List[str], bool]:
    """
    Produce per-step verdict lines. Returns (lines, any_drift).
    """
    lines: List[str] = []
    any_drift = False

    step_numbers = sorted(workdoc_steps.keys())
    if only_step is not None:
        step_numbers = [s for s in step_numbers if s == only_step]

    for step in step_numbers:
        block = workdoc_steps.get(step, {})
        passing_cmd = block.get("passing_test_cmd", "")
        expected_raw = block.get("expected_pass_pattern", "")
        expected_int = parse_int_or_none(expected_raw)
        n_count = count_n_increments(passing_cmd) if passing_cmd else 0

        # INV-1
        inv1_applicable = expected_int is not None and n_count > 0
        inv1_ok = inv1_applicable and expected_int == n_count

        # INV-2
        spec_int = spec_parens.get(step) if spec_parens else None
        inv2_applicable = spec_int is not None and expected_int is not None
        inv2_ok = inv2_applicable and spec_int == expected_int

        # Compose output:
        # - If both INVs are non-applicable -> N/A line.
        # - Else emit OK or DRIFT lines per applicable invariant.
        if not inv1_applicable and not inv2_applicable:
            if expected_int is None:
                reason = "expected_pass_pattern not integer"
            elif n_count == 0:
                reason = "no n=$((n+1)) occurrences in passing_test_cmd"
            else:
                reason = "no spec §6.1 parenthetical"
            lines.append(f"step {step} {EMDASH} N/A ({reason})")
            continue

        all_ok = True

        if inv1_applicable:
            if inv1_ok:
                detail = (
                    f"expected_pass_pattern={expected_int}, n=$((n+1)) count={n_count}"
                )
                if inv2_applicable and inv2_ok:
                    detail += f", spec §6.1 parenthetical={spec_int}"
                lines.append(f"step {step} {EMDASH} OK ({detail})")
            else:
                any_drift = True
                all_ok = False
                lines.append(
                    f"step {step} {EMDASH} DRIFT INV-1 "
                    f"(expected_pass_pattern={expected_int}, n=$((n+1)) count={n_count})"
                )

        if inv2_applicable:
            if not inv2_ok:
                any_drift = True
                all_ok = False
                lines.append(
                    f"step {step} {EMDASH} DRIFT INV-2 "
                    f"(workdoc expected_pass_pattern={expected_int}, spec §6.1 parenthetical={spec_int})"
                )
            elif not inv1_applicable:
                # INV-1 N/A but INV-2 OK — emit a positive line so silence
                # doesn't look like the step was skipped.
                lines.append(
                    f"step {step} {EMDASH} OK "
                    f"(expected_pass_pattern={expected_int}, spec §6.1 parenthetical={spec_int})"
                )

        # Combined OK already covered above; nothing more to do.
        _ = all_ok  # explicitly silence flake — already used via any_drift.

    return lines, any_drift


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("workdoc", help="Path to exec.md workdoc")
    parser.add_argument(
        "--spec", default=None, help="Optional spec.md path for INV-2 cross-check"
    )
    parser.add_argument(
        "--step", type=int, default=None, help="Restrict to single step number"
    )
    args = parser.parse_args(argv)

    workdoc_path = Path(args.workdoc)
    if not workdoc_path.is_file():
        print(f"workdoc not found: {workdoc_path}", file=sys.stderr)
        return 2

    workdoc_steps = parse_workdoc_steps(workdoc_path)

    spec_parens: Dict[int, int] = {}
    spec_malformed: Dict[int, str] = {}
    if args.spec:
        spec_path = Path(args.spec)
        if not spec_path.is_file():
            print(f"spec not found: {spec_path}", file=sys.stderr)
            return 2
        spec_parens, spec_malformed = parse_spec_61_parentheticals(spec_path)

    lines, any_drift = evaluate(
        workdoc_steps,
        spec_parens,
        only_step=args.step,
        spec_malformed=spec_malformed,
    )
    for ln in lines:
        print(ln)

    return 1 if any_drift else 0


if __name__ == "__main__":
    sys.exit(main())
