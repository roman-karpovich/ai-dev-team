#!/usr/bin/env python3
"""Offline empirical-verification helper for cross-auditor findings.md.

Parses a findings.md file's **Details** section (per the canonical template
at `agents/references/cross-auditor-output-format.md`), extracts
`(X-id, file, line)` tuples from each finding's `- **File**: <path>:<line>`
line, and verifies the named line in the named file against an expected
literal extracted from the finding body.

The Summary table at the top of findings.md carries only
`ID | Severity | Issue | Source | Mode | Confidence | Status` columns and
does NOT carry file:line — only the H3 Details sections are parsed.

Per-finding diagnostic classes emitted to stdout:
  - OK                   <file>:<line>
  - MISMATCH             <file>:<line> — actual: <observed snippet>
  - FILE-MISSING         <file>
  - LINE-OUT-OF-RANGE    <file>:<line>
  - NO-LITERAL-EXTRACTABLE  <file>:<line> (note only, NOT a mismatch)

Final summary line: `Total: N findings, M mismatches`.

Exit code:
  0 — no MISMATCH / FILE-MISSING / LINE-OUT-OF-RANGE findings.
  1 — at least one mismatch, OR malformed findings.md (missing Details section).

CLI:
    python3 tests/check_finding_claims.py <findings-md-path>

Path resolution for the per-finding `<file>`: tries
  (1) cwd-relative,
  (2) directory containing the findings.md (sibling resolution).
First hit wins.

Pure stdlib. Robust against malformed input — never crashes, just exits 1
with diagnostic to stderr.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import List, Optional, Tuple

# Matches `- **File**: <path>:<line>` (canonical Details template line).
FILE_LINE_RE = re.compile(
    r"^-\s+\*\*File\*\*:\s*(?P<path>[^:\s]+):(?P<line>\d+)\s*$"
)

# H3 finding header: `### [X1] <title>`.
HEADING_RE = re.compile(r"^###\s+\[(?P<id>[A-Z]\d+)\]\s+(?P<title>.+)$")

# Description line: `- **Description**: <prose>`.
DESC_RE = re.compile(r"^-\s+\*\*Description\*\*:\s*(?P<body>.*)$")

# Literal-in-backticks: extract first ``...`` quoted span from a string.
BACKTICK_RE = re.compile(r"`([^`]+)`")

# Section header line for the Details block.
DETAILS_HEADER_RE = re.compile(r"^##\s+Details\s*$", re.MULTILINE)


def parse_findings(text: str) -> List[Tuple[str, str, int, Optional[str]]]:
    """Return [(X-id, file_path, line_number, expected_literal_or_None), ...].

    Splits text at the `## Details` header; iterates H3 finding blocks;
    for each, picks the first matching `- **File**: <path>:<line>` line and
    the first backticked literal from the `- **Description**:` body.
    """
    # Anchor to Details section.
    m = DETAILS_HEADER_RE.search(text)
    if not m:
        return []
    details = text[m.end():]

    findings: List[Tuple[str, str, int, Optional[str]]] = []
    # Split into per-finding blocks at H3 boundaries.
    lines = details.splitlines()
    cur_id: Optional[str] = None
    cur_block: List[str] = []
    blocks: List[Tuple[str, List[str]]] = []
    for line in lines:
        h = HEADING_RE.match(line)
        if h:
            if cur_id is not None:
                blocks.append((cur_id, cur_block))
            cur_id = h.group("id")
            cur_block = []
        else:
            if cur_id is not None:
                cur_block.append(line)
    if cur_id is not None:
        blocks.append((cur_id, cur_block))

    for fid, block in blocks:
        file_path: Optional[str] = None
        line_no: Optional[int] = None
        literal: Optional[str] = None
        for bl in block:
            fm = FILE_LINE_RE.match(bl)
            if fm and file_path is None:
                file_path = fm.group("path")
                try:
                    line_no = int(fm.group("line"))
                except ValueError:
                    line_no = None
                continue
            dm = DESC_RE.match(bl)
            if dm and literal is None:
                bm = BACKTICK_RE.search(dm.group("body"))
                if bm:
                    literal = bm.group(1)
        if file_path is None or line_no is None:
            # Malformed finding — skip silently; not the helper's job to
            # validate Details schema, only to verify the claims that are
            # parseable.
            continue
        findings.append((fid, file_path, line_no, literal))
    return findings


def resolve_path(path_str: str, findings_md: Path) -> Optional[Path]:
    """Try cwd-relative then findings-md-sibling. Return first existing."""
    p = Path(path_str)
    if p.is_file():
        return p
    sibling = findings_md.parent / path_str
    if sibling.is_file():
        return sibling
    return None


def verify_one(
    fid: str, file_path: str, line_no: int, literal: Optional[str], findings_md: Path
) -> Tuple[str, bool]:
    """Return (diagnostic_line, is_mismatch_or_error)."""
    resolved = resolve_path(file_path, findings_md)
    if resolved is None:
        return (f"{fid}: FILE-MISSING {file_path}", True)
    try:
        lines = resolved.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        return (f"{fid}: FILE-MISSING {file_path} (read error: {exc})", True)
    if line_no < 1 or line_no > len(lines):
        return (
            f"{fid}: LINE-OUT-OF-RANGE {file_path}:{line_no} (file has {len(lines)} lines)",
            True,
        )
    actual = lines[line_no - 1]
    if literal is None:
        # Parsing-coverage gap — note, but do NOT count as mismatch.
        return (
            f"{fid}: NO-LITERAL-EXTRACTABLE {file_path}:{line_no} (no backticked literal in Description)",
            False,
        )
    if literal in actual:
        return (f"{fid}: OK {file_path}:{line_no}", False)
    snippet = actual.strip()
    if len(snippet) > 120:
        snippet = snippet[:117] + "..."
    return (
        f"{fid}: MISMATCH {file_path}:{line_no} — actual: {snippet}",
        True,
    )


def main(argv: List[str]) -> int:
    if len(argv) != 2:
        print(
            f"usage: {Path(argv[0]).name} <findings-md-path>",
            file=sys.stderr,
        )
        return 1
    findings_md = Path(argv[1])
    if not findings_md.is_file():
        print(f"FATAL: findings file not found: {findings_md}", file=sys.stderr)
        return 1
    try:
        text = findings_md.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"FATAL: cannot read {findings_md}: {exc}", file=sys.stderr)
        return 1

    if not DETAILS_HEADER_RE.search(text):
        print(
            f"FATAL: {findings_md} has no `## Details` section — malformed findings.md",
            file=sys.stderr,
        )
        return 1

    findings = parse_findings(text)
    mismatch_count = 0
    for fid, fpath, lno, literal in findings:
        line, is_mismatch = verify_one(fid, fpath, lno, literal, findings_md)
        print(line)
        if is_mismatch:
            mismatch_count += 1

    print(f"Total: {len(findings)} findings, {mismatch_count} mismatches")
    return 0 if mismatch_count == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
