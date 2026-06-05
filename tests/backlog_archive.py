#!/usr/bin/env python3
r"""Offline BACKLOG deep-clean archiver — classify + plan (Step 2: --dry-run).

Companion to the report-only drift scanner `kb_drift_scan.py` (C7 detects the
bloat; THIS tool performs the move). Strict separation of concerns: the scanner
never edits, the archiver never auto-guesses ambiguous items and never commits.

This module covers CLASSIFICATION + the `--dry-run` PLAN only. It writes
nothing. `--apply` (working-tree writes + idempotent archive merge + index
regeneration) is a later step.

Classification (spec §3.2) — AUTO set + CANDIDATES (human-approved):

  table_done — parse `## Active priorities` (PREFIX header match) pipe tables.
    The Status column index is DETECTED FROM THE TABLE HEADER row (the `Status`
    cell), NOT a fixed ordinal: the 5-col `# | Item | Axis | Status | Rationale`
    has Status=col-4, the 4-col `# | Item | Status | Reason` has Status=col-3.
    For each data row record {item_label, number (suffix-stripped 42a→42),
    title (item-cell), date (first YYYY-MM-DD in the STATUS CELL), done?}. A row
    is DONE iff it starts `^\s*\| ~~` OR its detected status cell begins
    `✅` / `**✅`.

  `### N.` blocks — split `## P1/P2/P3` (PREFIX match) into blocks. Each is:
    * AUTO-DONE iff the header is struck (`### ~~`) OR a body line CONTAINS the
      bold field `**Status: ✅` (regex `\*\*Status:\s*✅`, matched ANYWHERE on
      the line, NOT line-start-pinned — the real #76 status sits mid-line after
      `**Axis:** …`). This is NOT a body-wide ✅ scan: #40's prose `~~…~~ ✅ DONE`
      and #50's struck sub-bullet `~~**C11…**~~ ✅ DONE` LACK `**Status:` → stay
      OPEN.
    * CANDIDATE iff not AUTO-DONE AND its number matches some DONE table_done
      entry. Covers both stale-non-struck and reused-number collisions; the
      helper does NOT try to tell them apart — the human approves a subset.
    * OPEN otherwise.

  Candidate metadata: {N, block_title, matched_row_title, row_date, hint} where
  hint = "likely-same-item" if block_title and matched_row_title share >= 1
  distinctive non-stopword token else "likely-collision". The hint is ADVISORY
  (annotates the human's proposal) — it NEVER decides archival.

`--dry-run` plan (writes nothing) under LABELED headers so consumers/tests can
section-scope:
  `AUTO (<n>):`        one line per auto item — BOTH AUTO-DONE blocks
                       (`#<item_label> <title>`) AND struck / `✅`-status done
                       table ROWS (`#<item_label> <title> [row]`).
  `CANDIDATES (<m>):`  one line per candidate block
                       (`#<N> "<block_title>" ↔ "<matched_row_title>" — <hint>`).
OPEN items are NOT listed (their absence from AUTO+CANDIDATES is the assertion
surface). Then per-month done counts + the BACKLOG line delta.

CLI:
    python3 tests/backlog_archive.py <kb_root> --project <name> [--dry-run|--apply]

`<kb_root>` is the vault root; the BACKLOG is `<kb_root>/repos/<name>/BACKLOG.md`.
`--project <name>` is required and is rejected (exit 2) if it escapes
`<kb_root>/repos/` (a `..`-traversing or absolute value). Default is `--dry-run`.

Exit codes: 0 = nothing to archive; 1 = changes planned; 2 = usage/IO error.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Section-header PREFIX anchors (real headers carry suffixes — `## Active
# priorities (post-convergence …)`, `## P1: High impact`, …), so matching is by
# PREFIX, never literal equality.
ACTIVE_PRIORITIES_PREFIX = "## Active priorities"
BLOCK_SECTION_PREFIXES = ("## P1", "## P2", "## P3")

# A YYYY-MM-DD date.
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")

# `### N.` block header; captures the bare item_label (`9`, `12`, `40a`) whether
# or not the header is struck (`### ~~12. …~~`).
BLOCK_HEADER_RE = re.compile(r"^###\s+(?:~~)?\s*(\d+[a-z]?)\.")

# The own-status-line AUTO-DONE discriminator: the bold field `**Status: ✅`
# matched ANYWHERE on the line (NOT line-start-pinned — #76's sits mid-line).
OWN_STATUS_DONE_RE = re.compile(r"\*\*Status:\s*✅")

# English stopwords dropped before the candidate title-overlap hint.
_STOPWORDS = frozenset(
    {
        "a",
        "an",
        "and",
        "the",
        "of",
        "for",
        "to",
        "in",
        "on",
        "at",
        "by",
        "with",
        "via",
        "is",
        "are",
        "be",
        "item",
        "block",
        "topic",
        "done",
    }
)


def is_contained(path: Path, root: Path) -> bool:
    """True iff `path`, fully resolved, stays at or under `root` (resolved).

    Containment guard for the user-controlled `--project` value: `resolve()`
    collapses `../` and follows symlinks, so a `../outside` or absolute value is
    rejected here before any filesystem read.
    """
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def split_row(line: str) -> List[str]:
    """Split a pipe-table row into its stripped cell texts.

    Leading/trailing empty cells (from the bordering `|`) are dropped so the
    list indices line up with the visible columns (`# | Item | … `).
    """
    parts = line.split("|")
    # Drop the empty strings produced by the leading/trailing border pipes.
    if parts and parts[0].strip() == "":
        parts = parts[1:]
    if parts and parts[-1].strip() == "":
        parts = parts[:-1]
    return [p.strip() for p in parts]


def is_separator_row(cells: List[str]) -> bool:
    """True iff every cell is a markdown table separator (`---`, `:--:`, …)."""
    return bool(cells) and all(re.fullmatch(r":?-+:?", c) for c in cells if c != "")


def strip_markup(text: str) -> str:
    """Strip `~~strike~~` / `**bold**` markup and surrounding whitespace."""
    return text.replace("~~", "").replace("**", "").strip()


def bare_number(label: str) -> str:
    """Suffix-stripped bare number of an item label (`42a` → `42`)."""
    m = re.match(r"(\d+)", label)
    return m.group(1) if m else label


def _tokens(title: str) -> set:
    """Distinctive non-stopword lowercase tokens of a title."""
    words = re.findall(r"[A-Za-z][A-Za-z0-9-]+", title.lower())
    return {w for w in words if w not in _STOPWORDS}


def parse_table_done(lines: List[str]) -> List[Dict]:
    """Parse `## Active priorities` tables → list of done-row descriptors.

    Walks every `## Active priorities`-prefixed section, finds each pipe table
    inside it, detects the Status column from the header row, and records every
    DONE data row as `{item_label, number, title, date, status_cell}`.
    """
    rows: List[Dict] = []
    in_section = False
    status_idx: Optional[int] = None  # detected per-table from its header row
    for line in lines:
        if line.startswith("## "):
            in_section = line.startswith(ACTIVE_PRIORITIES_PREFIX)
            status_idx = None
            continue
        if not in_section:
            continue
        stripped = line.lstrip()
        if not stripped.startswith("|"):
            # A non-table line ends the current table; the next table re-detects
            # its own Status column.
            if stripped == "":
                continue
            status_idx = None
            continue
        cells = split_row(line)
        if is_separator_row(cells):
            continue
        if status_idx is None:
            # Header row: detect the Status column by its cell text.
            for i, cell in enumerate(cells):
                if cell.strip() == "Status":
                    status_idx = i
                    break
            continue
        if len(cells) <= 1:
            continue
        status_cell = cells[status_idx] if status_idx < len(cells) else ""
        struck = bool(re.match(r"^\s*\|\s*~~", line))
        status_done = strip_markup(status_cell).startswith("✅")
        if not (struck or status_done):
            continue
        item_label = strip_markup(cells[0])
        title = cells[1] if len(cells) > 1 else ""
        date_m = DATE_RE.search(status_cell)
        rows.append(
            {
                "item_label": item_label,
                "number": bare_number(item_label),
                "title": title.strip(),
                "date": date_m.group(0) if date_m else None,
                "status_cell": status_cell,
            }
        )
    return rows


def parse_blocks(lines: List[str]) -> List[Dict]:
    """Split `## P1/P2/P3` sections into `### N.` blocks with raw bodies."""
    blocks: List[Dict] = []
    in_section = False
    current: Optional[Dict] = None
    for line in lines:
        if line.startswith("## "):
            in_section = line.startswith(BLOCK_SECTION_PREFIXES)
            current = None
            continue
        if not in_section:
            continue
        header_m = BLOCK_HEADER_RE.match(line)
        if header_m:
            current = {
                "item_label": header_m.group(1),
                "number": bare_number(header_m.group(1)),
                "header": line,
                "struck": line.startswith("### ~~"),
                "body": [],
            }
            blocks.append(current)
        elif current is not None:
            current["body"].append(line)
    return blocks


def block_title(block: Dict) -> str:
    """Human title of a `### N.` block — header text minus markup / `N.`."""
    text = block["header"][3:].strip()  # drop `### `
    text = strip_markup(text)
    text = re.sub(r"^\d+[a-z]?\.\s*", "", text)
    # Drop a trailing `✅ DONE (…)` completion marker on struck headers.
    text = re.split(r"\s*✅", text)[0].strip()
    return text


def block_is_auto(block: Dict) -> bool:
    """True iff a block is AUTO-DONE (struck header OR own-status `**Status: ✅`)."""
    if block["struck"]:
        return True
    return any(OWN_STATUS_DONE_RE.search(line) for line in block["body"])


def hint_for(block_t: str, row_t: str) -> str:
    """Advisory candidate hint from title-token overlap (never a gate)."""
    shared = _tokens(block_t) & _tokens(row_t)
    return "likely-same-item" if shared else "likely-collision"


def classify(text: str) -> Dict:
    """Classify a BACKLOG into AUTO rows + AUTO blocks + CANDIDATEs + OPEN.

    Returns `{auto_rows, auto_blocks, candidates, open_blocks}` where each
    candidate carries its advisory metadata (`block_title`, `matched_row_title`,
    `row_date`, `hint`).
    """
    lines = text.splitlines()
    table_done = parse_table_done(lines)
    done_by_number: Dict[str, List[Dict]] = {}
    for row in table_done:
        done_by_number.setdefault(row["number"], []).append(row)

    auto_blocks: List[Dict] = []
    candidates: List[Dict] = []
    open_blocks: List[Dict] = []
    for block in parse_blocks(lines):
        if block_is_auto(block):
            auto_blocks.append(block)
            continue
        matches = done_by_number.get(block["number"])
        if matches:
            row = matches[0]
            bt = block_title(block)
            rt = strip_markup(row["title"])
            candidates.append(
                {
                    "number": block["number"],
                    "block_title": bt,
                    "matched_row_title": rt,
                    "row_date": row["date"],
                    "hint": hint_for(bt, rt),
                }
            )
        else:
            open_blocks.append(block)

    return {
        "auto_rows": table_done,
        "auto_blocks": auto_blocks,
        "candidates": candidates,
        "open_blocks": open_blocks,
    }


def month_of(date: Optional[str]) -> Optional[str]:
    """`YYYY-MM` bucket of a `YYYY-MM-DD` date (or None)."""
    return date[:7] if date else None


def render_dry_run(result: Dict) -> Tuple[str, int]:
    """Render the `--dry-run` plan. Returns (text, archived_count)."""
    auto_blocks = result["auto_blocks"]
    auto_rows = result["auto_rows"]
    candidates = result["candidates"]

    auto_lines: List[str] = []
    for block in auto_blocks:
        auto_lines.append(f"#{block['item_label']} {block_title(block)}")
    for row in auto_rows:
        auto_lines.append(f"#{row['item_label']} {strip_markup(row['title'])} [row]")

    cand_lines: List[str] = []
    for cand in candidates:
        cand_lines.append(
            f'#{cand["number"]} "{cand["block_title"]}" ↔ '
            f'"{cand["matched_row_title"]}" — {cand["hint"]}'
        )

    archived_count = len(auto_lines)

    blocks: List[str] = []
    blocks.append(f"AUTO ({len(auto_lines)}):")
    blocks.extend(f"  {line}" for line in auto_lines)
    blocks.append(f"CANDIDATES ({len(cand_lines)}):")
    blocks.extend(f"  {line}" for line in cand_lines)

    # Per-month done counts (AUTO set only — the unambiguous archive set).
    month_counts: Dict[str, int] = {}
    for block in auto_blocks:
        date = next(
            (
                DATE_RE.search(line).group(0)
                for line in [block["header"], *block["body"]]
                if DATE_RE.search(line)
            ),
            None,
        )
        m = month_of(date)
        if m:
            month_counts[m] = month_counts.get(m, 0) + 1
    for row in auto_rows:
        m = month_of(row["date"])
        if m:
            month_counts[m] = month_counts.get(m, 0) + 1
    if month_counts:
        blocks.append("Per-month:")
        for m in sorted(month_counts):
            blocks.append(f"  {m}: {month_counts[m]}")

    return "\n".join(blocks), archived_count


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kb_root", help="KB vault root directory")
    parser.add_argument(
        "--project",
        required=True,
        help="project under <kb_root>/repos/<name>/ whose BACKLOG.md to archive",
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--dry-run",
        dest="dry_run",
        action="store_true",
        help="print the archive plan; write nothing (default)",
    )
    mode.add_argument(
        "--apply",
        dest="apply",
        action="store_true",
        help="write the working tree (later step; not yet implemented)",
    )
    args = parser.parse_args(argv)

    kb_root = Path(args.kb_root)
    if not kb_root.is_dir():
        print(
            f"error: KB root not found or not a directory: {kb_root}", file=sys.stderr
        )
        return 2

    repos_root = kb_root / "repos"
    project_root = repos_root / args.project
    if not is_contained(project_root, repos_root):
        print(
            f"error: --project must stay under {repos_root}; "
            f"traversing value rejected: {args.project!r}",
            file=sys.stderr,
        )
        return 2
    backlog = project_root / "BACKLOG.md"
    if not backlog.is_file():
        print(f"error: BACKLOG.md not found: {backlog}", file=sys.stderr)
        return 2

    try:
        text = backlog.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    result = classify(text)
    plan, archived_count = render_dry_run(result)
    print(plan)
    return 1 if archived_count or result["candidates"] else 0


if __name__ == "__main__":
    sys.exit(main())
