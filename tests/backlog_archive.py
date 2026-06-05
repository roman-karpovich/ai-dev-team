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

  table_done — STRUCK-ONLY done-detection (NO column parsing). Parse
    `## Active priorities` (PREFIX header match) pipe tables. A data row is DONE
    iff its raw line STARTS `^\s*\| ~~` (struck). This is a pure line-prefix
    regex — no `split`, no column arity, no Status-cell ordinal — so the
    misparse-data-loss class that recurred 3× (X1 all-cell-scan → X4 escaped `\|`
    → X6 double-escaped `\\|`: a content pipe inflates a row's apparent column
    count and a non-Status cell is mis-read as the Status cell, archiving an OPEN
    row) is IMPOSSIBLE BY CONSTRUCTION. For a struck row record {item_label,
    number (suffix-stripped 42a→42), title (item-cell), date (first YYYY-MM-DD in
    the LINE — struck rows carry status-date == first-date, verified 17/17 in the
    golden)}. NON-struck rows whose raw line CONTAINS a `✅` (loose, anywhere) are
    NOT auto-archived — they are emitted as an advisory FLAG in `--dry-run`
    (`⚠ #N appears done (✅ present) but is not struck …`) and KEPT in BACKLOG.
    The lone real instance is the #76 librarian-cluster row (`**✅ CLOSED
    2026-06-02`); #59/#77 (`✅` in the Rationale cell) are likewise flagged, never
    archived. The item-cell title is still extracted via `split_table_pipes` for
    candidate-matching/index, but that split NEVER influences done-ness.

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
                       (`#<item_label> <title>`) AND STRUCK done table ROWS
                       (`#<item_label> <title> [row]`).
  `FLAGGED (<k>):`     one line per NON-struck table row whose raw line contains
                       a `✅` — advisory only; these rows are KEPT in BACKLOG,
                       NEVER archived (strike the row to archive it).
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
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

# Section-header PREFIX anchors (real headers carry suffixes — `## Active
# priorities (post-convergence …)`, `## P1: High impact`, …), so matching is by
# PREFIX, never literal equality.
ACTIVE_PRIORITIES_PREFIX = "## Active priorities"
BLOCK_SECTION_PREFIXES = ("## P1", "## P2", "## P3")

# A YYYY-MM-DD date.
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")

# A struck table data row: the line STARTS `| ~~` (optionally indented). This
# pure line-prefix regex is the SOLE table-row done-signal (spec §3.2 rule 1) —
# no column split, no Status-column ordinal, no arity. Eliminating the column
# parse closes the misparse-data-loss class (X1/X4/X6) by construction: a content
# pipe can no longer inflate a row's apparent column count and re-key a non-Status
# cell as the Status cell, because no cell is read to decide done-ness.
STRUCK_ROW_RE = re.compile(r"^\s*\|\s*~~")

# The number of a struck row (`| ~~**42a**~~ …` → `42a`), used to match a
# candidate block to a done row. Extracts the label from the struck item cell;
# this is metadata only — it does not influence done-ness.
STRUCK_ROW_LABEL_RE = re.compile(r"^\s*\|\s*~~\*\*([0-9]+[a-z]?)\*\*")

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


def target_escapes(target: Path, root: Path) -> bool:
    """True iff a WRITE target is unsafe — a symlink, or escapes `root`.

    Audit X5 (file-level companion to the X3 directory guard): the `archive/` dir
    guard alone does not protect the individual write targets. A pre-planted
    symlink AT a write path (`archive/backlog-done-YYYY-MM.md` or `BACKLOG.md`)
    would be followed and the write would land at the symlink's out-of-tree
    target. Refuse if `target` is itself a symlink, OR if its parent (resolved)
    escapes `root`. The target itself need not pre-exist (a fresh month file
    does not), so containment is checked on the parent directory.
    """
    if target.is_symlink():
        return True
    return not is_contained(target.parent, root)


def split_table_pipes(line: str) -> List[str]:
    r"""Split a markdown table row on its CELL-SEPARATOR pipes only.

    A `|` is a cell separator UNLESS it is (audit X4 — a naive `line.split("|")`
    over-counted columns, collapsing a canonical 4-col OPEN row into a 5-col one
    that re-keyed to a `✅`-leading Reason fragment and was silently archived):

    * **Backslash-escaped** — preceded by an ODD run of `\\` (`\\|`). An EVEN run
      (`\\\\|`) is an escaped backslash followed by a REAL separator. Parity-aware,
      mirroring `kb_drift_scan.split_unescaped_pipes` (the repo's C6 cell-split).
    * **Inside an inline-code span** — between a pair of backtick fences (`` `…|…` ``).
      A pipe within `` `a | b` `` is content, not a column boundary. Spans are
      matched left-to-right by equal-length backtick runs (CommonMark code-span
      rule); an unterminated run leaves the rest of the line as plain text.

    Returns the RAW segment texts (backslashes/backticks intact); the caller
    `split_row` strips and drops the empty border cells.
    """
    segments: List[str] = []
    start = 0
    i = 0
    n = len(line)
    code_fence = 0  # length of the backtick run that opened the current code span
    while i < n:
        ch = line[i]
        if ch == "`":
            run = 1
            while i + run < n and line[i + run] == "`":
                run += 1
            if code_fence == 0:
                code_fence = run  # open a span
            elif run == code_fence:
                code_fence = 0  # close it (CommonMark: matching-length run)
            i += run
            continue
        if ch == "|" and code_fence == 0:
            bs = 0
            j = i - 1
            while j >= 0 and line[j] == "\\":
                bs += 1
                j -= 1
            if bs % 2 == 0:
                segments.append(line[start:i])
                start = i + 1
        i += 1
    segments.append(line[start:])
    return segments


def split_row(line: str) -> List[str]:
    r"""Split a pipe-table row into its stripped cell texts.

    Uses `split_table_pipes` (markdown-table-aware — a backslash-escaped `\|` and
    a pipe inside an inline-code span are NOT column boundaries, audit X4), so the
    canonical {4,5}-col arities are not inflated by content pipes. Leading/trailing
    empty cells (from the bordering `|`) are dropped so the list indices line up
    with the visible columns (`# | Item | … `).
    """
    parts = split_table_pipes(line)
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


def parse_table_done(lines: Sequence[str]) -> Tuple[List[Dict], List[Dict]]:
    r"""Parse `## Active priorities` tables → (struck done rows, flagged rows).

    Done-detection is STRUCK-ONLY (spec §3.2 rule 1): a data row is done iff its
    raw line matches `STRUCK_ROW_RE` (`^\s*\|\s*~~`). This is a pure line-prefix
    test — NO column split decides done-ness — so a content pipe can never inflate
    a row's apparent arity and mis-key a non-Status cell as the Status cell (the
    X1/X4/X6 data-loss class, closed by construction).

    A NON-struck data row whose RAW line contains a `✅` (loose, anywhere) is
    FLAGGED, not archived: it stays in BACKLOG and is surfaced as an advisory line
    in `--dry-run`. The lone real instance is the #76 librarian-cluster row
    (`**✅ CLOSED 2026-06-02`); #59/#77 with a `✅` in the Rationale cell are
    likewise flagged, never archived.

    For each STRUCK row record `{item_label, number, title, date, status_cell,
    raw_line, header_line, separator_line}` — the item-cell title is extracted via
    `split_row` for candidate-matching/index ONLY (it does not influence
    done-ness); the date is the first `YYYY-MM-DD` in the whole line. Each FLAGGED
    row is `{number, raw_line}`.
    """
    done_rows: List[Dict] = []
    flagged_rows: List[Dict] = []
    in_section = False
    header_line: Optional[str] = None  # raw header row of the current table
    separator_line: Optional[str] = None  # raw separator row of the current table
    prev_pipe_line: Optional[str] = None  # last pipe row seen (header candidate)
    seen_separator = False  # past the current table's separator → data rows
    for line in lines:
        if line.startswith("## "):
            in_section = line.startswith(ACTIVE_PRIORITIES_PREFIX)
            header_line = None
            separator_line = None
            prev_pipe_line = None
            seen_separator = False
            continue
        if not in_section:
            continue
        stripped = line.lstrip()
        if not stripped.startswith("|"):
            # A non-table line ends the current table.
            if stripped == "":
                continue
            header_line = None
            separator_line = None
            prev_pipe_line = None
            seen_separator = False
            continue
        cells = split_row(line)
        if is_separator_row(cells):
            # The pipe row immediately before a separator is THIS table's header.
            if prev_pipe_line is not None:
                header_line = prev_pipe_line
            separator_line = line
            seen_separator = True
            prev_pipe_line = line
            continue
        if not seen_separator:
            # A pipe row before this table's separator is (the candidate) header.
            prev_pipe_line = line
            continue
        prev_pipe_line = line
        if len(cells) <= 1:
            continue
        if not STRUCK_ROW_RE.match(line):
            # NON-struck data row. If it carries a `✅` anywhere it LOOKS done —
            # flag it (advisory), but NEVER archive it.
            if "✅" in line:
                flagged_rows.append(
                    {"number": bare_number(strip_markup(cells[0])), "raw_line": line}
                )
            continue
        # STRUCK row → done. Title (item-cell) is metadata for matching/index only.
        item_label = strip_markup(cells[0])
        title = cells[1] if len(cells) > 1 else ""
        date_m = DATE_RE.search(line)
        done_rows.append(
            {
                "item_label": item_label,
                "number": bare_number(item_label),
                "title": title.strip(),
                "date": date_m.group(0) if date_m else None,
                "status_cell": line,
                "raw_line": line,
                "header_line": header_line,
                "separator_line": separator_line,
            }
        )
    return done_rows, flagged_rows


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
    """Classify a BACKLOG into AUTO rows + AUTO blocks + CANDIDATEs + FLAGGED + OPEN.

    Returns `{auto_rows, auto_blocks, candidates, flagged_rows, open_blocks}`.
    `auto_rows` are STRUCK done table rows (the only auto-archived row class);
    `flagged_rows` are NON-struck rows carrying a `✅` (advisory, never archived).
    Each candidate carries its advisory metadata (`block_title`,
    `matched_row_title`, `row_date`, `hint`). A `### N` block is a CANDIDATE iff
    (not AUTO-DONE) AND its number matches a STRUCK done row's number.
    """
    lines = text.splitlines()
    table_done, flagged_rows = parse_table_done(lines)
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
        "flagged_rows": flagged_rows,
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
    flagged_rows = result["flagged_rows"]

    auto_lines: List[str] = []
    for block in auto_blocks:
        auto_lines.append(f"#{block['item_label']} {block_title(block)}")
    for row in auto_rows:
        auto_lines.append(f"#{row['item_label']} {strip_markup(row['title'])} [row]")

    flag_lines: List[str] = []
    for row in flagged_rows:
        flag_lines.append(
            f"⚠ #{row['number']} appears done (✅ present) but is not struck — "
            f"strike it (`~~`) to archive"
        )

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
    blocks.append(f"FLAGGED ({len(flag_lines)}):")
    blocks.extend(f"  {line}" for line in flag_lines)
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


def block_storage_identity(header_line: str, item_label: str) -> Tuple[str, str, str]:
    """Archive-storage identity of a `### N.` block (spec §3.2).

    `(scheme, item_label, title)` where scheme is the literal `"block"`, the
    item_label is the bare number/letter label, and the title is the markup-
    stripped header text minus the leading `N.` and any trailing `✅ …` marker.
    Keying on the FULL identity (not the bare `item_label`) keeps two DISTINCT
    items that REUSE a number — same label, different title — as separate
    archive entries; keying on `item_label` alone would silently collapse them
    and the second item's prose would be lost on an idempotent merge (X1).
    """
    title = block_title({"header": header_line})
    return ("block", item_label, title)


def existing_block_identities(archive_text: str) -> set:
    """Full storage identities of `### N.` write-ups already in an archive.

    Returns a set of `(scheme, item_label, title)` tuples (spec §3.2), NOT bare
    labels — see `block_storage_identity` for why a reused number must NOT
    collapse two distinct write-ups on merge.
    """
    identities = set()
    for line in archive_text.splitlines():
        m = BLOCK_HEADER_RE.match(line)
        if m:
            identities.add(block_storage_identity(line, m.group(1)))
    return identities


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

    Storage identity (spec §3.2): a block is keyed by its FULL
    `(scheme, item_label, title)` identity, a row by its verbatim line.
    Already-present entries are skipped (idempotent no-clobber merge); new ones
    are appended into the matching section. Keying blocks on the full identity
    (not the bare `item_label`) is what lets two DISTINCT items reusing a number
    both survive a merge — see `block_storage_identity` (X1).
    """
    have_blocks = existing_block_identities(archive_text)
    have_rows = existing_row_lines(archive_text)
    new_blocks = [
        b
        for b in blocks
        if block_storage_identity(b["header"], b["item_label"]) not in have_blocks
    ]
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


def trim_backlog(text: str, archived_identities: set, archived_rows: set) -> str:
    """Remove archived block write-ups + done rows from BACKLOG, keep the rest.

    `archived_identities` = FULL `(scheme, item_label, title)` storage identities
    of archived `### N.` blocks (header + body dropped). `archived_rows` =
    verbatim done-row lines to drop. Keying the trim on the same full identity
    the archive merge keys on guarantees the trim set and the archive-insert set
    cannot diverge: a BACKLOG block is removed only if its exact identity was
    archived, so a reused-number block whose distinct twin was archived is never
    trimmed by mistake (X1). Open blocks/rows and every non-`## P*` /
    `## Active priorities` section are kept.
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
                identity = block_storage_identity(line, header_m.group(1))
                dropping_block = identity in archived_identities
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
    # One-row lookahead: a pipe row is only committed as a DATA row once the next
    # line proves it is NOT a table header (i.e. not immediately followed by a
    # `---` separator). This is what lets a SECOND table shape in the same rows
    # section (its own header + separator) be skipped instead of the prior table's
    # header being read as a data row → a garbage index line and a lost PR# (X3).
    # Works whether tables are blank-separated or back-to-back.
    pending: Optional[List[str]] = None  # held data-candidate row's cells
    pending_line: Optional[str] = None

    def flush_pending() -> None:
        nonlocal pending, pending_line
        if pending is None or pending_line is None:
            pending, pending_line = None, None
            return
        cells = pending
        if len(cells) > 1:
            # Archived rows are all STRUCK done rows (the only auto-archived row
            # class). The index sources `— PR #M` from the whole raw line, so no
            # Status-column parse is needed; `status_cell` carries the raw line.
            rows.append(
                {
                    "item_label": strip_markup(cells[0]),
                    "title": cells[1].strip() if len(cells) > 1 else "",
                    "status_cell": pending_line,
                    "raw_line": pending_line,
                }
            )
        pending, pending_line = None, None

    for line in lines:
        if line.startswith("## "):
            flush_pending()
            if line.startswith(ARCHIVE_BLOCKS_HEADER):
                section = "blocks"
            elif line.startswith(ARCHIVE_ROWS_HEADER):
                section = "rows"
            else:
                section = None
            current = None
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
                flush_pending()
                continue
            cells = split_row(line)
            if is_separator_row(cells):
                # The pending pipe row was THIS table's header (a separator
                # follows it): discard it. Done-ness is struck-only, so the
                # header arity is irrelevant here.
                pending, pending_line = None, None
                continue
            # A new pipe row: the previously-pending row is confirmed DATA.
            flush_pending()
            pending, pending_line = cells, line
    flush_pending()
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
    # Audit X3: refuse a symlinked `archive/` and any archive dir that resolves
    # outside the project root — writing through such a symlink lands files
    # outside the intended tree. Resolve the real path and require containment.
    if archive_dir.is_symlink() or not is_contained(archive_dir, project_root):
        print(
            f"error: archive directory {archive_dir} escapes the project root "
            f"{project_root} (symlink or out-of-tree target); refusing to write",
            file=sys.stderr,
        )
        return 2, []
    archive_dir.mkdir(parents=True, exist_ok=True)

    # Audit X5: file-level symlink/containment guard on EVERY write target before
    # any write — a pre-planted symlink at a month file or at BACKLOG.md would
    # otherwise be followed out of tree. Refuse the whole run (exit 2, nothing
    # written) if any target is unsafe, so a partial archive cannot leak.
    backlog_path = project_root / "BACKLOG.md"
    write_targets = [archive_month_path(project_root, m)
                     for m in sorted(set(by_month_blocks) | set(by_month_rows))]
    write_targets.append(backlog_path)
    for target in write_targets:
        if target_escapes(target, project_root):
            print(
                f"error: write target {target} is a symlink or escapes the "
                f"project root {project_root}; refusing to write",
                file=sys.stderr,
            )
            return 2, []

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

    archived_identities = {
        block_storage_identity(b["header"], b["item_label"]) for b in blocks
    }
    archived_rows = {r["raw_line"] for r in rows}
    trimmed = trim_backlog(text, archived_identities, archived_rows)

    # Regenerate the dated compact `## Completed` index from the MERGED archive
    # files (spec §3.2: rebuilt every run from the archives, never blind-appended
    # → cannot bloat, a re-run never duplicates lines).
    index_lines = build_index(load_archives_by_month(project_root))
    trimmed = regenerate_completed_index(trimmed, index_lines)
    backlog_path.write_text(trimmed, encoding="utf-8")

    return 1, msgs


def _selftest() -> int:
    r"""Behavioral self-test for the struck-only contract (spec §3.2).

    Each case asserts the post-§3.5c contract: a table row is done IFF it is
    STRUCK (`^\s*\|\s*~~`); a NON-struck row carrying a `✅` is FLAGGED, never
    archived. The historic column-parse data-loss vectors (X1 all-cell-scan, X4
    escaped `\|`, X6 double-escaped `\\|`, inline-code-span pipes) are now inert
    BY CONSTRUCTION — they are pinned here as "OPEN/flagged row never archived"
    and stay RED if done-detection ever regresses to a column parse. Run with
    `python3 tests/backlog_archive.py --selftest`; returns 0 iff every assertion
    holds. The symlink-escape cases use a self-cleaning `TemporaryDirectory`.
    """
    failures: List[str] = []

    def check(name: str, cond: bool, detail: str = "") -> None:
        status = "PASS" if cond else "FAIL"
        print(f"  [{status}] {name}{(' — ' + detail) if detail else ''}")
        if not cond:
            failures.append(name)

    def done_labels(text: str) -> set:
        done, _flagged = parse_table_done(text.splitlines())
        return {r["item_label"] for r in done}

    def flagged_numbers(text: str) -> set:
        _done, flagged = parse_table_done(text.splitlines())
        return {r["number"] for r in flagged}

    # --- STRUCK-ONLY done-detection: a row is done IFF struck. A non-struck row
    # carrying a `✅` (the real #76 librarian-cluster shape) is FLAGGED, kept in
    # BACKLOG, NEVER archived. Mirrors the golden mixed P2 table. ---
    print("STRUCK-ONLY — struck rows done; non-struck ✅ rows flagged not archived:")
    so_text = "\n".join(
        [
            "## Active priorities",
            "",
            "| # | Item | Status | Reason |",
            "|---|------|--------|--------|",
            "| ~~**5**~~ | struck done row | **✅ DONE 2026-04-10** | r |",
            "| **76** | librarian cluster | **✅ CLOSED 2026-06-02 — done** | "
            "process-truthfulness (disc 2026-05-31) |",
            "| **59** | open item | P2 queued | discussion ✅ RESOLVED mid-cell |",
            "| **41** | genuinely open | P1 queued | reason |",
        ]
    )
    so_done = done_labels(so_text)
    so_flagged = flagged_numbers(so_text)
    check("struck #5 detected done", "5" in so_done, f"done={sorted(so_done)}")
    check(
        "non-struck ✅ #76 row FLAGGED (not done)",
        "76" not in so_done and "76" in so_flagged,
        f"done={sorted(so_done)} flagged={sorted(so_flagged)}",
    )
    check(
        "non-struck ✅ #59 row FLAGGED (not done)",
        "59" not in so_done and "59" in so_flagged,
        f"done={sorted(so_done)} flagged={sorted(so_flagged)}",
    )
    check(
        "genuinely-open #41 (no ✅) neither done nor flagged",
        "41" not in so_done and "41" not in so_flagged,
        f"done={sorted(so_done)} flagged={sorted(so_flagged)}",
    )

    # --- struck-row date = first YYYY-MM-DD in the LINE (no column parse). ---
    print("DATE — struck-row date is the first YYYY-MM-DD in the line:")
    date_text = "\n".join(
        [
            "## Active priorities",
            "",
            "| # | Item | Status | Reason |",
            "|---|------|--------|--------|",
            "| ~~**8**~~ | struck | **✅ DONE 2026-04-12 — PR #91** | "
            "disc 2026-03-01 |",
        ]
    )
    d_rows, _ = parse_table_done(date_text.splitlines())
    check(
        "struck #8 date is first line date 2026-04-12 (not the later 2026-03-01)",
        bool(d_rows) and d_rows[0]["date"] == "2026-04-12",
        f"date={d_rows[0]['date'] if d_rows else None}",
    )

    # --- MISPARSE VECTORS NOW INERT BY CONSTRUCTION (the X1/X4/X6 class). Each
    # OPEN row has a content pipe (escaped `\|`, double-escaped `\\|`, inline-code-
    # span pipe) AND a leading `✅` in a cell — pre-fix these inflated the apparent
    # arity and re-keyed a non-Status cell as Status → the OPEN row was archived
    # (data loss). Struck-only detection reads NO cell to decide done-ness, so
    # NONE can be done: each is flagged (✅ present, not struck), never archived.
    # These RED if done-detection ever regresses to a column parse. ---
    print("INERT — escaped/double-escaped/code-span content pipes never archive:")
    vec_text = "\n".join(
        [
            "## Active priorities",
            "",
            "| # | Item | Status | Reason |",
            "|---|------|--------|--------|",
            r"| **36** | escaped-pipe open | P2 queued | "
            r"✅ RESOLVED 2026-05-31 \| extra note |",
            r"| **37** | double-escaped open | P2 queued | "
            r"✅ RESOLVED 2026-05-31 \\| extra note |",
            "| **38** | code-span open | P2 queued | ✅ see `a | b` pipe |",
        ]
    )
    vec_done = done_labels(vec_text)
    vec_flagged = flagged_numbers(vec_text)
    for n in ("36", "37", "38"):
        check(
            f"misparse-vector #{n} OPEN row never DONE (column-parse inert)",
            n not in vec_done,
            f"done={sorted(vec_done)}",
        )
        check(
            f"misparse-vector #{n} OPEN row FLAGGED (✅ present, not struck)",
            n in vec_flagged,
            f"flagged={sorted(vec_flagged)}",
        )

    # --- candidate-matching keys on a STRUCK row's number (extracted from the
    # struck item cell), unaffected by column parse. ---
    print("CANDIDATE — a `### N` block matches a STRUCK row's number:")
    cand_text = "\n".join(
        [
            "## Active priorities",
            "",
            "| # | Item | Status | Reason |",
            "|---|------|--------|--------|",
            "| ~~**9**~~ | candidate-similar topic | **✅ DONE 2026-04-12** | r |",
            "| **76** | non-struck ✅ row | **✅ CLOSED 2026-06-02** | r |",
            "",
            "## P3: blocks",
            "",
            "### 9. candidate-similar topic block",
            "",
            "CAND_BLOCK_9 — not struck, no own-status; matches struck row #9.",
            "",
            "### 76. non-struck row number block",
            "",
            "This block's number matches a NON-struck (flagged) row → NOT a "
            "candidate (no struck row #76).",
        ]
    )
    cand_res = classify(cand_text)
    cand_nums = {c["number"] for c in cand_res["candidates"]}
    check(
        "#9 block is a CANDIDATE (matches struck row #9)",
        "9" in cand_nums,
        f"candidates={sorted(cand_nums)}",
    )
    check(
        "#76 block NOT a candidate (#76 row is non-struck/flagged, not a done row)",
        "76" not in cand_nums,
        f"candidates={sorted(cand_nums)}",
    )

    # --- AUTO-DONE blocks retained: struck `### ~~` header OR own-line
    # `**Status: ✅` (matched mid-line); body-wide `✅ DONE` does NOT classify. ---
    print("BLOCK AUTO-DONE — struck header / own-status field; body-✅ guard:")
    block_text = "\n".join(
        [
            "## P1: section",
            "",
            "### ~~12. struck block~~ ✅ DONE (2026-04-17)",
            "",
            "STRUCK_DONE_12.",
            "",
            "### 20. own-status mid-line block",
            "",
            "**Axis:** foo. **Status: ✅ DONE (2026-04-18) — PR #99** OWN_20",
            "",
            "### 50. FP-guard open block",
            "",
            "FP_GUARD_50.",
            "",
            "- ~~**Cx — foo.**~~ ✅ DONE (2026-04-27, PR #64)",
        ]
    )
    block_res = classify(block_text)
    auto_block_labels = {b["item_label"] for b in block_res["auto_blocks"]}
    open_block_labels = {b["item_label"] for b in block_res["open_blocks"]}
    check(
        "struck #12 block AUTO-DONE",
        "12" in auto_block_labels,
        f"auto={sorted(auto_block_labels)}",
    )
    check(
        "own-status mid-line #20 block AUTO-DONE",
        "20" in auto_block_labels,
        f"auto={sorted(auto_block_labels)}",
    )
    check(
        "body-wide-✅ #50 block stays OPEN (no own-status field)",
        "50" in open_block_labels and "50" not in auto_block_labels,
        f"open={sorted(open_block_labels)}",
    )

    # --- X1: two DISTINCT items reusing a number (different title) BOTH survive
    # an idempotent merge — the second is not dropped by a bare-label dedup. ---
    print("X1 — reused-number block both-preserved on merge:")
    base_archive = "\n".join(
        [
            "---",
            "title: x",
            "---",
            "# Completed",
            "",
            ARCHIVE_BLOCKS_HEADER,
            "",
            "### ~~12. Original twelve~~ ✅ DONE (2026-04-17)",
            "",
            "ORIGINAL_12_BODY content.",
            "",
            ARCHIVE_ROWS_HEADER,
            "",
        ]
    )
    reused_block = {
        "item_label": "12",
        "header": "### ~~12. Reused twelve different topic~~ ✅ DONE (2026-04-18)",
        "body": ["", "REUSED_12_BODY_DIFFERENT content."],
        "struck": True,
    }
    merged = merge_into_archive(base_archive, [reused_block], [])
    check("X1 original #12 body preserved", "ORIGINAL_12_BODY" in merged)
    check(
        "X1 reused #12 (different title) preserved, not deduped away",
        "REUSED_12_BODY_DIFFERENT" in merged,
    )
    remerged = merge_into_archive(merged, [reused_block], [])
    check(
        "X1 identity-equal re-merge is a no-op (no duplicate)",
        remerged == merged and remerged.count("REUSED_12_BODY_DIFFERENT") == 1,
    )
    backlog_two_twelves = "\n".join(
        [
            "## P1: section",
            "",
            "### ~~12. Reused twelve different topic~~ ✅ DONE (2026-04-18)",
            "",
            "REUSED_12_BODY_DIFFERENT content.",
            "",
            "### 12. Still-open twelve unrelated",
            "",
            "STILL_OPEN_12 — must stay.",
        ]
    )
    trimmed = trim_backlog(
        backlog_two_twelves,
        {block_storage_identity(reused_block["header"], "12")},
        set(),
    )
    check(
        "X1 archived reused #12 trimmed from BACKLOG",
        "REUSED_12_BODY_DIFFERENT" not in trimmed,
    )
    check(
        "X1 same-number OPEN #12 (distinct title) NOT trimmed",
        "STILL_OPEN_12" in trimmed,
    )

    # --- X3: a 2-table-shape archive rows section regenerates clean index lines
    # (no `**##**` header-as-data garbage; each table's PR# is preserved). ---
    print("X3 — multi-table-shape archive yields clean index lines:")
    arch_two_shapes = "\n".join(
        [
            ARCHIVE_BLOCKS_HEADER,
            "",
            ARCHIVE_ROWS_HEADER,
            "",
            "| # | Item | Axis | Status | Rationale |",
            "|---|------|------|--------|-----------|",
            "| ~~**5**~~ | five-col item | ax | **✅ DONE 2026-04-10 — PR #50** | r |",
            "",
            "| # | Item | Status | Reason |",
            "|---|------|--------|--------|",
            "| ~~**6**~~ | four-col item | **✅ DONE 2026-04-11 — PR #6** | reason |",
        ]
    )
    idx = build_index({"2026-04": arch_two_shapes})
    check(
        "X3 no garbage header-as-data index line",
        not any("**##**" in ln for ln in idx),
    )
    check(
        "X3 5-col table row indexed with its PR#",
        any("**#5**" in ln and "PR #50" in ln for ln in idx),
    )
    check(
        "X3 4-col table row indexed with its PR# (not lost)",
        any("**#6**" in ln and "PR #6" in ln for ln in idx),
    )
    _, x3_rows = parse_archive_entries(arch_two_shapes)
    check(
        "X3 exactly the two real data rows parsed (no header rows)",
        sorted(r["item_label"] for r in x3_rows) == ["5", "6"],
        f"labels={sorted(r['item_label'] for r in x3_rows)}",
    )

    # --- END-TO-END (--apply): struck rows + AUTO blocks archive; a NON-struck
    # ✅ row stays OPEN (flagged), with every misparse vector inert. ---
    print("E2E — --apply archives struck/AUTO only; non-struck ✅ rows stay OPEN:")
    e2e = "\n".join(
        [
            "# BACKLOG",
            "",
            "## Active priorities",
            "",
            "| # | Item | Status | Reason |",
            "|---|------|--------|--------|",
            "| ~~**5**~~ | E2ESTRUCK struck done | **✅ DONE 2026-04-10** | r |",
            "| **76** | E2EFLAG non-struck ✅ row | **✅ CLOSED 2026-06-02** | r |",
            r"| **36** | E2EESC escaped-pipe open | P2 queued | "
            r"✅ RESOLVED 2026-05-31 \| extra |",
            "| **38** | E2ECODE code-span open | P2 queued | ✅ see `a | b` |",
            "",
            "## P1: section",
            "",
            "### ~~12. E2EBLOCK struck block~~ ✅ DONE (2026-04-17)",
            "",
            "STRUCK_DONE_12.",
            "",
        ]
    )
    with tempfile.TemporaryDirectory() as e2etd:
        e2eproj = Path(e2etd) / "repos" / "ai-dev-team"
        e2eproj.mkdir(parents=True)
        (e2eproj / "BACKLOG.md").write_text(e2e, encoding="utf-8")
        rc_e, _ = apply_archive(
            e2eproj, "ai-dev-team", e2e, classify(e2e), []
        )
        bl_e = (e2eproj / "BACKLOG.md").read_text()
        open_e = bl_e.split("## Completed")[0]
        arch_e = "\n".join(
            a.read_text() for a in (e2eproj / "archive").glob("backlog-done-*.md")
        )
        check("E2E --apply exit 1 (changes)", rc_e == 1, f"rc={rc_e}")
        check(
            "E2E struck row #5 archived (move not copy)",
            "E2ESTRUCK" in arch_e and "E2ESTRUCK" not in open_e,
        )
        check(
            "E2E struck AUTO block #12 archived",
            "E2EBLOCK" in arch_e and "E2EBLOCK" not in open_e,
        )
        check(
            "E2E non-struck ✅ #76 row FLAGGED — stays OPEN, never archived",
            "E2EFLAG" in open_e and "E2EFLAG" not in arch_e,
        )
        for marker in ("E2EESC", "E2ECODE"):
            check(
                f"E2E misparse-vector {marker} OPEN row stays OPEN (inert)",
                marker in open_e and marker not in arch_e,
            )

    # --- AUDIT X5 (file-level symlink guard): a pre-planted symlink AT a write
    # target (month file OR BACKLOG.md) is refused (exit 2, nothing written). ---
    print("AUDIT-X5 — file-level symlinked write targets are refused:")
    with tempfile.TemporaryDirectory() as _x5td:
        _proj = Path(_x5td) / "repos" / "ai-dev-team"
        _proj.mkdir(parents=True)
        (_proj / "BACKLOG.md").write_text(
            "# BACKLOG\n\n## P1: section\n\n"
            "### ~~5. struck done~~ ✅ DONE (2026-04-10)\n\nBODY_5 content.\n",
            encoding="utf-8",
        )
        (_proj / "archive").mkdir()  # a REAL dir → passes the X3 dir-level guard
        _outside = Path(_x5td) / "OUTSIDE"
        _outside.mkdir()
        _victim = _outside / "victim.md"
        _victim.write_text("ORIGINAL VICTIM\n", encoding="utf-8")
        os.symlink(str(_victim), str(_proj / "archive" / "backlog-done-2026-04.md"))
        _btext = (_proj / "BACKLOG.md").read_text()
        _rc, _ = apply_archive(_proj, "ai-dev-team", _btext, classify(_btext), [])
        check("AUDIT-X5 symlinked month-file target refused exit 2", _rc == 2, f"rc={_rc}")
        check(
            "AUDIT-X5 outside victim untouched (not written through symlink)",
            _victim.read_text() == "ORIGINAL VICTIM\n",
        )
    with tempfile.TemporaryDirectory() as _x5td2:
        _proj2 = Path(_x5td2) / "repos" / "ai-dev-team"
        _proj2.mkdir(parents=True)
        _outside2 = Path(_x5td2) / "OUTSIDE"
        _outside2.mkdir()
        _realbl = _outside2 / "real-backlog.md"
        _realbl.write_text(
            "# BACKLOG\n\n## P1: section\n\n"
            "### ~~5. struck done~~ ✅ DONE (2026-04-10)\n\nBODY_5 content.\n",
            encoding="utf-8",
        )
        os.symlink(str(_realbl), str(_proj2 / "BACKLOG.md"))
        (_proj2 / "archive").mkdir()
        _btext2 = (_proj2 / "BACKLOG.md").read_text()
        _rc2, _ = apply_archive(_proj2, "ai-dev-team", _btext2, classify(_btext2), [])
        check("AUDIT-X5 symlinked BACKLOG.md target refused exit 2", _rc2 == 2, f"rc={_rc2}")
        check(
            "AUDIT-X5 outside real-backlog untrimmed (not written through symlink)",
            "BODY_5" in _realbl.read_text(),
        )

    # --- AUDIT X3 (dir-level symlink guard): a pre-existing `archive/` symlink
    # whose target is outside the project root MUST be refused (exit 2). ---
    print("AUDIT-X3 — symlinked archive/ that escapes the project root is refused:")
    with tempfile.TemporaryDirectory() as _x3td:
        _proj = Path(_x3td) / "repos" / "ai-dev-team"
        _proj.mkdir(parents=True)
        (_proj / "BACKLOG.md").write_text(
            "# BACKLOG\n\n## P1: section\n\n"
            "### ~~5. struck done~~ ✅ DONE (2026-04-10)\n\nBODY_5 content.\n",
            encoding="utf-8",
        )
        _outside = Path(_x3td) / "OUTSIDE_TARGET"
        _outside.mkdir()
        os.symlink(str(_outside), str(_proj / "archive"))
        _btext = (_proj / "BACKLOG.md").read_text()
        _rc, _ = apply_archive(_proj, "ai-dev-team", _btext, classify(_btext), [])
        _escaped = list(_outside.glob("backlog-done-*.md"))
        check("AUDIT-X3 symlinked-escape archive/ refused exit 2", _rc == 2, f"rc={_rc}")
        check(
            "AUDIT-X3 nothing written outside the project root",
            not _escaped,
            f"escaped={[p.name for p in _escaped]}",
        )

    if failures:
        print(f"\nSELFTEST FAILED: {len(failures)} assertion(s): {', '.join(failures)}")
        return 1
    print("\nSELFTEST OK: struck-only done-detection + flagged non-struck-✅ rows + X1/X3/X5 GREEN")
    return 0


def main(argv: Optional[List[str]] = None) -> int:
    if argv is None:
        argv = sys.argv[1:]
    if "--selftest" in argv:
        return _selftest()

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
