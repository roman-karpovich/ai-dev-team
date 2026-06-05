#!/usr/bin/env python3
r"""Offline BACKLOG deep-clean archiver — classify + plan + apply.

Companion to the report-only drift scanner `kb_drift_scan.py` (C7 detects the
bloat; THIS tool performs the move). Strict separation of concerns: the scanner
never edits, the archiver never auto-guesses ambiguous items and never commits.

`--dry-run` (default) covers CLASSIFICATION + the PLAN only and writes nothing.
`--apply [--archive-candidates <ids>]` writes the working tree: it moves the
AUTO set plus the human-approved candidate blocks into
`archive/backlog-done-YYYY-MM.md` (codified structure, prose byte-exact),
trims those items out of `BACKLOG.md`, regenerates the dated compact
`## Completed` index from the merged archive files (one line per
index-logical-identity; anti-bloat — never blind-appended), and merges
idempotently on re-run (append only entries whose archive-storage identity is
not already present; never clobber). It NEVER commits.

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

# A `PR #M` reference, used to annotate index lines (`— PR #M`).
PR_RE = re.compile(r"PR #(\d+)")

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
    header_line: Optional[str] = None  # raw header row of the current table
    separator_line: Optional[str] = None  # raw separator row of the current table
    for line in lines:
        if line.startswith("## "):
            in_section = line.startswith(ACTIVE_PRIORITIES_PREFIX)
            status_idx = None
            header_line = None
            separator_line = None
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
            header_line = None
            separator_line = None
            continue
        cells = split_row(line)
        if is_separator_row(cells):
            separator_line = line
            continue
        if status_idx is None:
            # Header row: detect the Status column by its cell text.
            for i, cell in enumerate(cells):
                if cell.strip() == "Status":
                    status_idx = i
                    break
            header_line = line
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
                "raw_line": line,
                "header_line": header_line,
                "separator_line": separator_line,
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


def block_auto_date(block: Dict) -> Optional[str]:
    """Completion date of an AUTO-DONE block (date-bucketing, spec §3.2).

    - struck header → the first `YYYY-MM-DD` on the header line;
    - own-status block → the date on its `**Status: ✅ … (DATE)**` field line.
    Returns None if no date is resolvable (the caller hard-errors).
    """
    if block["struck"]:
        if m := DATE_RE.search(block["header"]):
            return m.group(0)
        return None
    for line in block["body"]:
        if OWN_STATUS_DONE_RE.search(line) and (m := DATE_RE.search(line)):
            return m.group(0)
    return None


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
                    "_block": block,
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
        date = block_auto_date(block)
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


# --- `--apply`: archive write + BACKLOG trim + idempotent merge (spec §3.2) ---

# Archive section headers (codified 2026-06-04 structure).
ARCHIVE_BLOCKS_HEADER = "## Done items (original write-ups)"
ARCHIVE_ROWS_HEADER = "## Done items (Active-priorities table rows)"

# BACKLOG `## Completed` index headers (codified 2026-06-04 structure).
COMPLETED_HEADER_PREFIX = "## Completed"
INDEX_HEADER = "### Done backlog items — index"
COMPLETED_SPECS_HEADER = "### Completed specs"
INDEX_COLLISION_NOTE = (
    "Repeated `#N` lines are expected — reused numbers and letter-suffixed "
    "sub-items (`#42a`/`#42b`) are historically distinct items; see the "
    "archive prose."
)

_MONTH_NAMES = {
    "01": "January",
    "02": "February",
    "03": "March",
    "04": "April",
    "05": "May",
    "06": "June",
    "07": "July",
    "08": "August",
    "09": "September",
    "10": "October",
    "11": "November",
    "12": "December",
}


def parse_candidate_ids(raw: str) -> List[str]:
    """Parse the `--archive-candidates` comma list into bare item numbers."""
    return [tok.strip() for tok in raw.split(",") if tok.strip()]


def block_body_verbatim(block: Dict) -> str:
    """The block's prose (`### N.` header + body) with trailing blanks stripped.

    Prose is copied BYTE-EXACT (spec §3.2 "moved byte-exact, copy never
    rewrite"); only trailing blank body lines are dropped so archive entries are
    separated by exactly one blank line.
    """
    lines = [block["header"], *block["body"]]
    while lines and lines[-1].strip() == "":
        lines.pop()
    return "\n".join(lines)


def select_archive_set(
    result: Dict, approved: List[str]
) -> Tuple[List[Dict], List[Dict]]:
    """Resolve the full archive set for `--apply`.

    Returns `(blocks, rows)` where `blocks` = AUTO-DONE blocks + APPROVED
    candidate blocks (each annotated with its resolved `_date`), and `rows` =
    every done table row. Candidates NOT in `approved` stay open.
    """
    approved_set = set(approved)
    done_by_number: Dict[str, List[Dict]] = {}
    for row in result["auto_rows"]:
        done_by_number.setdefault(row["number"], []).append(row)

    blocks: List[Dict] = []
    for block in result["auto_blocks"]:
        annotated = dict(block)
        annotated["_date"] = block_auto_date(block)
        blocks.append(annotated)

    # Approved candidates: bucket by the matching done row's status-cell date
    # (completion), earliest across suffixed rows (spec §3.2 date clause 4).
    for cand in result["candidates"]:
        if cand["number"] not in approved_set:
            continue
        match_block = cand.get("_block")
        rows = done_by_number.get(cand["number"], [])
        dates = sorted(r["date"] for r in rows if r["date"])
        annotated = dict(match_block) if match_block else None
        if annotated is None:
            continue
        annotated["_date"] = dates[0] if dates else None
        blocks.append(annotated)

    return blocks, list(result["auto_rows"])


def archive_month_path(project_root: Path, month: str) -> Path:
    """`<project_root>/archive/backlog-done-YYYY-MM.md` for a `YYYY-MM` month."""
    return project_root / "archive" / f"backlog-done-{month}.md"


def render_fresh_archive(
    project: str, month: str, blocks: List[Dict], rows: List[Dict]
) -> str:
    """Render a brand-new archive file for one month (codified structure)."""
    year, mm = month.split("-")
    month_name = _MONTH_NAMES.get(mm, mm)
    out: List[str] = []
    out.append("---")
    out.append(f"title: {project} — Completed backlog ({month_name} {year})")
    out.append(f"project: {project}")
    out.append("type: backlog-archive")
    out.append(f"created: {month}-01")
    out.append("tags: [backlog, archive, ai-dev-team]")
    out.append("---")
    out.append("")
    out.append(f"# Completed backlog items — {month_name} {year}")
    out.append("")
    out.append(
        "Full prose of DONE backlog items, moved out of `BACKLOG.md` to keep it "
        "compact."
    )
    out.append(
        "Index + month grouping live in `BACKLOG.md` §Completed. Numbering "
        "collisions are historical — see the item text."
    )
    out.append("")
    out.append(ARCHIVE_BLOCKS_HEADER)
    for block in blocks:
        out.append("")
        out.append(block_body_verbatim(block))
    out.append("")
    out.append(ARCHIVE_ROWS_HEADER)
    for group in group_rows_by_table(rows):
        out.append("")
        out.append(group["header_line"])
        if group["separator_line"] is not None:
            out.append(group["separator_line"])
        for row in group["rows"]:
            out.append(row["raw_line"])
    out.append("")
    return "\n".join(out) + "\n"


def group_rows_by_table(rows: List[Dict]) -> List[Dict]:
    """Group done rows under their source table header, preserving order."""
    groups: List[Dict] = []
    index: Dict[str, Dict] = {}
    for row in rows:
        key = row.get("header_line") or ""
        group = index.get(key)
        if group is None:
            group = {
                "header_line": row.get("header_line") or "",
                "separator_line": row.get("separator_line"),
                "rows": [],
            }
            index[key] = group
            groups.append(group)
        group["rows"].append(row)
    return groups


def existing_block_identities(archive_text: str) -> set:
    """Bare item labels of `### N.` write-ups already present in an archive."""
    labels = set()
    for line in archive_text.splitlines():
        m = BLOCK_HEADER_RE.match(line)
        if m:
            labels.add(m.group(1))
    return labels


def existing_row_lines(archive_text: str) -> set:
    """Verbatim done-row lines already present in an archive's rows section."""
    present = set()
    in_rows = False
    for line in archive_text.splitlines():
        if line.startswith("## "):
            in_rows = line.startswith(ARCHIVE_ROWS_HEADER)
            continue
        if in_rows and line.lstrip().startswith("|"):
            present.add(line)
    return present


def merge_into_archive(archive_text: str, blocks: List[Dict], rows: List[Dict]) -> str:
    """Insert only-new entries into an existing archive, preserving its bytes.

    Storage identity (spec §3.2): a block is keyed by its bare `item_label`, a
    row by its verbatim line. Already-present entries are skipped (idempotent
    no-clobber merge); new ones are appended into the matching section.
    """
    have_blocks = existing_block_identities(archive_text)
    have_rows = existing_row_lines(archive_text)
    new_blocks = [b for b in blocks if b["item_label"] not in have_blocks]
    new_rows = [r for r in rows if r["raw_line"] not in have_rows]
    if not new_blocks and not new_rows:
        return archive_text

    lines = archive_text.splitlines()
    # Insert new write-ups at the end of the blocks section (before the rows
    # header), new rows at the end of the rows section.
    out: List[str] = []
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        if line.startswith(ARCHIVE_ROWS_HEADER) and new_blocks:
            # Append new blocks just before the rows-section header.
            while out and out[-1].strip() == "":
                out.pop()
            for block in new_blocks:
                out.append("")
                out.append(block_body_verbatim(block))
            out.append("")
            out.append(line)
            i += 1
            continue
        out.append(line)
        i += 1

    if new_blocks and not any(ln.startswith(ARCHIVE_ROWS_HEADER) for ln in lines):
        # No rows section existed — append the blocks at file end.
        while out and out[-1].strip() == "":
            out.pop()
        for block in new_blocks:
            out.append("")
            out.append(block_body_verbatim(block))

    if new_rows:
        while out and out[-1].strip() == "":
            out.pop()
        for group in group_rows_by_table(new_rows):
            if group["header_line"] not in out:
                out.append("")
                out.append(group["header_line"])
                if group["separator_line"] is not None:
                    out.append(group["separator_line"])
            for row in group["rows"]:
                out.append(row["raw_line"])

    return "\n".join(out) + "\n"


def trim_backlog(text: str, archived_labels: set, archived_rows: set) -> str:
    """Remove archived block write-ups + done rows from BACKLOG, keep the rest.

    `archived_labels` = bare item labels of archived `### N.` blocks (header +
    body dropped). `archived_rows` = verbatim done-row lines to drop. Open
    blocks/rows and every non-`## P*`/`## Active priorities` section are kept.
    """
    lines = text.splitlines()
    out: List[str] = []
    in_block_section = False
    in_active = False
    dropping_block = False
    for line in lines:
        if line.startswith("## "):
            in_block_section = line.startswith(BLOCK_SECTION_PREFIXES)
            in_active = line.startswith(ACTIVE_PRIORITIES_PREFIX)
            dropping_block = False
            out.append(line)
            continue
        if in_block_section:
            header_m = BLOCK_HEADER_RE.match(line)
            if header_m:
                dropping_block = header_m.group(1) in archived_labels
                if dropping_block:
                    continue
            elif dropping_block:
                continue
            out.append(line)
            continue
        if in_active and line in archived_rows:
            continue
        out.append(line)
    trimmed = "\n".join(out)
    if text.endswith("\n") and not trimmed.endswith("\n"):
        trimmed += "\n"
    return trimmed


def parse_archive_entries(archive_text: str) -> Tuple[List[Dict], List[Dict]]:
    """Parse one archive file into its stored blocks + rows.

    Reads the two codified sections — `## Done items (original write-ups)` and
    `## Done items (Active-priorities table rows)` — back into `### N.` block
    dicts (`{item_label, header, body, struck}`, same shape `parse_blocks`
    yields) and done-row dicts (`{item_label, title, status_cell, raw_line}`).
    The index is rebuilt from THESE entries every run (spec §3.2 "regenerated
    from the archive files"), so it can never blind-append or bloat.
    """
    blocks: List[Dict] = []
    rows: List[Dict] = []
    lines = archive_text.splitlines()
    section: Optional[str] = None
    current: Optional[Dict] = None
    status_idx: Optional[int] = None
    for line in lines:
        if line.startswith("## "):
            if line.startswith(ARCHIVE_BLOCKS_HEADER):
                section = "blocks"
            elif line.startswith(ARCHIVE_ROWS_HEADER):
                section = "rows"
            else:
                section = None
            current = None
            status_idx = None
            continue
        if section == "blocks":
            header_m = BLOCK_HEADER_RE.match(line)
            if header_m:
                current = {
                    "item_label": header_m.group(1),
                    "header": line,
                    "struck": line.startswith("### ~~"),
                    "body": [],
                }
                blocks.append(current)
            elif current is not None:
                current["body"].append(line)
        elif section == "rows":
            stripped = line.lstrip()
            if not stripped.startswith("|"):
                continue
            cells = split_row(line)
            if is_separator_row(cells):
                continue
            if status_idx is None:
                for i, cell in enumerate(cells):
                    if cell.strip() == "Status":
                        status_idx = i
                        break
                continue
            if len(cells) <= 1:
                continue
            status_cell = cells[status_idx] if status_idx < len(cells) else ""
            rows.append(
                {
                    "item_label": strip_markup(cells[0]),
                    "title": cells[1].strip() if len(cells) > 1 else "",
                    "status_cell": status_cell,
                    "raw_line": line,
                }
            )
    return blocks, rows


def _pr_suffix(text: str) -> str:
    """`— PR #M` suffix derived from a `PR #M` mention in `text`, else ``."""
    m = PR_RE.search(text)
    return f" — PR #{m.group(1)}" if m else ""


def build_index(archives_by_month: Dict[str, str]) -> List[str]:
    """Build the `### Done backlog items — index` body from archive files.

    `archives_by_month` maps `YYYY-MM` → archive file text. Emits the index
    header, then per month (sorted) a `#### YYYY-MM  →  [[backlog-done-YYYY-MM]]`
    sub-header followed by ONE line per index-logical-identity (spec §3.2):

    - an APPROVED-candidate block (non-auto: not struck, no own-status field)
      coalesces with the done row of the SAME bare `item_label` → one line;
    - an AUTO-DONE block (struck / own-status) does NOT coalesce with a
      same-number done row → distinct lines;
    - a block matched only to SUFFIXED rows of a different label does NOT
      coalesce (block `42` vs rows `42a`/`42b`/`42c` → 4 distinct lines);
    - letter-suffixed rows index distinctly (`#40a`/`#40b`, never a `#40`).
    """
    out: List[str] = [INDEX_HEADER, ""]
    for month in sorted(archives_by_month):
        blocks, rows = parse_archive_entries(archives_by_month[month])
        # Rows a candidate block coalesces away (exact bare-label match of a
        # NON-auto block) are emitted on the block's line, not their own. The
        # coalesced line keeps the BLOCK title but sources `— PR #M` from the
        # matched ROW's status cell (golden shape: `#37 — <block> — PR #57`,
        # the PR sits in the done row, not the block prose).
        coalesced_row_by_label: Dict[str, Dict] = {}
        for row in rows:
            coalesced_row_by_label.setdefault(row["item_label"], row)
        coalesced_row_labels = {
            b["item_label"]
            for b in blocks
            if not block_is_auto(b) and b["item_label"] in coalesced_row_by_label
        }
        out.append(f"#### {month}  →  [[backlog-done-{month}]]")
        for block in blocks:
            title = block_title(block)
            if block["item_label"] in coalesced_row_labels:
                pr = _pr_suffix(
                    coalesced_row_by_label[block["item_label"]]["status_cell"]
                )
            else:
                pr = _pr_suffix(block["header"] + "\n" + "\n".join(block["body"]))
            out.append(f"- **#{block['item_label']}** — {title}{pr}")
        for row in rows:
            if row["item_label"] in coalesced_row_labels:
                continue
            title = strip_markup(row["title"])
            pr = _pr_suffix(row["status_cell"])
            out.append(f"- **#{row['item_label']}** — {title}{pr}")
        out.append("")
    out.append(INDEX_COLLISION_NOTE)
    out.append("")
    return out


def load_archives_by_month(project_root: Path) -> Dict[str, str]:
    """Read every `archive/backlog-done-YYYY-MM.md` → {month: text}."""
    archives: Dict[str, str] = {}
    archive_dir = project_root / "archive"
    if not archive_dir.is_dir():
        return archives
    for path in archive_dir.glob("backlog-done-*.md"):
        m = re.search(r"backlog-done-(\d{4}-\d{2})\.md$", path.name)
        if m:
            archives[m.group(1)] = path.read_text(encoding="utf-8")
    return archives


def regenerate_completed_index(text: str, index_lines: List[str]) -> str:
    """Rewrite BACKLOG `## Completed` with the regenerated index.

    Replaces everything between the `## Completed` header and the
    `### Completed specs` sub-list with the freshly built index (spec §3.2:
    "regenerated from the archive files every run, never blind-appended"). The
    `### Completed specs` sub-list and anything after it are kept verbatim. If
    no `## Completed` section exists, the BACKLOG is returned unchanged.
    """
    lines = text.splitlines()
    completed_idx: Optional[int] = None
    for i, line in enumerate(lines):
        if line.startswith(COMPLETED_HEADER_PREFIX):
            completed_idx = i
            break
    if completed_idx is None:
        return text

    # Find where the kept tail (`### Completed specs` onward, or the next H2)
    # begins so the regenerated index replaces only the index region.
    tail_idx = len(lines)
    for i in range(completed_idx + 1, len(lines)):
        line = lines[i]
        if line.startswith(COMPLETED_SPECS_HEADER) or line.startswith("## "):
            tail_idx = i
            break

    head = lines[: completed_idx + 1]
    tail = lines[tail_idx:]
    rebuilt = [*head, "", *index_lines, *tail]
    out = "\n".join(rebuilt)
    if text.endswith("\n") and not out.endswith("\n"):
        out += "\n"
    return out


def apply_archive(
    project_root: Path, project: str, text: str, result: Dict, approved: List[str]
) -> Tuple[int, List[str]]:
    """Apply the archive move: write archives + trim BACKLOG. Returns (rc, msgs).

    rc = 0 nothing-to-do, 1 changes applied, 2 unresolvable date.
    """
    blocks, rows = select_archive_set(result, approved)
    if not blocks and not rows:
        return 0, ["nothing to archive"]

    # Resolve a month for every archived entry; a missing date is a hard error.
    by_month_blocks: Dict[str, List[Dict]] = {}
    for block in blocks:
        month = month_of(block.get("_date"))
        if month is None:
            print(
                f"error: no resolvable completion date for block "
                f"#{block['item_label']}",
                file=sys.stderr,
            )
            return 2, []
        by_month_blocks.setdefault(month, []).append(block)

    by_month_rows: Dict[str, List[Dict]] = {}
    for row in rows:
        month = month_of(row["date"])
        if month is None:
            print(
                f"error: no resolvable completion date for row #{row['item_label']}",
                file=sys.stderr,
            )
            return 2, []
        by_month_rows.setdefault(month, []).append(row)

    archive_dir = project_root / "archive"
    archive_dir.mkdir(parents=True, exist_ok=True)

    msgs: List[str] = []
    for month in sorted(set(by_month_blocks) | set(by_month_rows)):
        mblocks = by_month_blocks.get(month, [])
        mrows = by_month_rows.get(month, [])
        path = archive_month_path(project_root, month)
        if path.exists():
            merged = merge_into_archive(
                path.read_text(encoding="utf-8"), mblocks, mrows
            )
            path.write_text(merged, encoding="utf-8")
        else:
            path.write_text(
                render_fresh_archive(project, month, mblocks, mrows), encoding="utf-8"
            )
        msgs.append(f"{path.name}: {len(mblocks)} block(s) + {len(mrows)} row(s)")

    archived_labels = {b["item_label"] for b in blocks}
    archived_rows = {r["raw_line"] for r in rows}
    trimmed = trim_backlog(text, archived_labels, archived_rows)

    # Regenerate the dated compact `## Completed` index from the MERGED archive
    # files (spec §3.2: rebuilt every run from the archives, never blind-appended
    # → cannot bloat, a re-run never duplicates lines).
    index_lines = build_index(load_archives_by_month(project_root))
    trimmed = regenerate_completed_index(trimmed, index_lines)
    (project_root / "BACKLOG.md").write_text(trimmed, encoding="utf-8")

    return 1, msgs


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
        help="write the working tree (archives + trimmed BACKLOG); never commits",
    )
    parser.add_argument(
        "--archive-candidates",
        dest="archive_candidates",
        default="",
        help=(
            "comma-separated candidate item numbers the human APPROVED for "
            "archival; candidates not listed stay open. Only meaningful with "
            "--apply"
        ),
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

    if args.apply:
        approved = parse_candidate_ids(args.archive_candidates)
        rc, msgs = apply_archive(project_root, args.project, text, result, approved)
        for msg in msgs:
            print(msg)
        return rc

    plan, archived_count = render_dry_run(result)
    print(plan)
    return 1 if archived_count or result["candidates"] else 0


if __name__ == "__main__":
    sys.exit(main())
