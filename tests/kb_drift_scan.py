#!/usr/bin/env python3
r"""Offline KB-vault drift scanner — narrow first check set (C1/C2/C3/C4/C5/C6).

Sibling of the existing offline checkers `check_dangling_anchors.py` /
`check_finding_claims.py`, but scoped to the KB Obsidian vault (NOT the plugin
repo). Surfaces mechanical drift the librarian's KB-curator role consumes; each
finding carries an `auto_safe` flag the curator uses as its autonomy gate
(autonomous fix iff `auto_safe: true`, else propose-only).

Check set (narrow first slice):
  C1 broken `[[wikilink]]`  — an Obsidian wikilink whose as-written target
                              resolves to ZERO vault notes (two-stage; a link
                              that resolves as-written by ANY accepted form —
                              bare name, path-qualified, or `.md`-suffixed — is
                              a WORKING link and is NOT a finding).
  C2 dangling §-pointer     — a `` `<relpath>.md` §<heading> `` pointer whose
                              heading does not resolve in the target KB `.md`.
                              Reuses the heading-resolution logic imported from
                              `check_dangling_anchors.py`.
  C3 status-enum violation  — a `type: spec` doc whose frontmatter `status:` is
                              not in the accepted enum (legacy `DONE` accepted).
  C4 status-drift           — a `type: spec` doc whose `status:` is pre-code-
                              audit (APPROVED/AUDIT_PASSED — NOT IN_PROGRESS) yet
                              carries a code-audit COMPLETION record: a non-null
                              frontmatter `code_audit_evidence:` (structured) OR
                              a canonical column-0 terminal Log marker (legacy
                              fallback). The record implies the work shipped while
                              the status was left stale. Offline / git-free — reads
                              only the spec file. `auto_safe: false` (a status flip
                              is a human decision).
  C5 research-status-enum   — a `type: research` doc whose frontmatter `status:`
                              is not in the documented research enum
                              {ACTIVE, CONCLUDED, ARCHIVED} (or is missing). The C3
                              analog, type-scoped on `type: research` (NEVER the
                              `research/` path — legacy `type: research-note` notes
                              stay clean). `auto_safe: false`.
  C6 index-row bloat        — an index/MOC file's table data row or list entry
                              whose measure exceeds INDEX_ROW_BLOAT_THRESHOLD
                              (300) chars. Index/MOC predicate: leading-
                              frontmatter `type:` ∈ {moc, index} OR the basename
                              is `vault-index.md` (a no-frontmatter file qualifies
                              ONLY via the basename clause). Runs in the C1/C2
                              region ABOVE the frontmatter gate so the no-
                              frontmatter `vault-index.md` is reachable. Table
                              measure = MAX stripped cell length (cells split on
                              UNESCAPED `|`, separator rows excluded); list
                              measure = stripped content length AFTER the marker.
                              `auto_safe: false` (trimming requires summarization,
                              a human/librarian call).

Known limitations (heuristic, like the existing checkers):
  - C6 multi-physical-line dumps are under-reported: a pipe-table row is one
    physical line, so the dominant one-giant-cell case is caught, but a bullet
    whose status dump spills onto indented continuation lines is measured per-
    line only (the continuation is not summed). Conservative FN consistent with
    the under-report posture; the long-single-line/long-single-bullet defects
    ARE caught.
  - C6 markup counts toward length: cell length is raw stripped text (wikilink/
    backtick/**bold** markup included). The 300-char budget has ample margin
    over real one-liners (median 92), so markup overhead does not cause FPs.
  - C6 header-row edge: a pathologically long table HEADER row flags like a data
    row. Not excluded (real headers are short); acceptable rare case.
  - C6 measures PER-CELL, not whole-row: the table measure is the MAX single-
    cell length, not the sum of cells. A multi-cell row whose cells total > 300
    but each is ≤ 300 does NOT flag. Deliberate — the bloat defect is a single
    prose cell, and the codified convention (docs/kb-layout.md / vault AGENTS.md)
    is worded per-cell to match.
  - C1 vault-wide bare-name resolution can false-positive on intentional stub
    links (hence `auto_safe: false` on ambiguity — the curator surfaces, never
    auto-fixes those).
  - C1 path-qualified resolution APPROXIMATES Obsidian's note resolver via
    vault-relative component-suffix matching (.md notes only); exact resolver
    internals are not public.
  - C1 unresolved `.`/`..` relative wikilinks fall back to bare-stem to avoid
    live-vault false-positives; this may under-report a broken relative path
    when a same-stem note exists elsewhere (scoped subset of #76d).
  - C1 backslash-separated path-qualified targets are not normalized (POSIX
    vault assumption; not observed on the real vault).
  - C1 escaped alias separator `\|` IS normalized to a plain `|` before the
    target split (the Obsidian table-cell escape); escaped `\#` / `\^` (heading /
    block-ref markers) are NOT normalized — not observed in the vault, a
    conservative deferred case that would split at the literal `#` / `^` as today.
  - C1 a wrong-looking path that is a valid Obsidian suffix of a DIFFERENT note
    resolves clean (Obsidian-consistent — partial-path resolution).
  - Code is skipped: lines inside (or delimiting) a fenced ```code block``` are
    masked for both C1 and C2, and single-backtick inline-code spans are
    stripped before the C1 wikilink scan. Double-/multi-backtick inline spans
    and prose-example wikilinks written outside code (an illustrative
    `[[future-note]]` in body prose) remain a residual minority false-positive —
    distinguishing illustrative-from-real `[[...]]` outside code is deferred.
  - C2 resolution: target-class dispatch — the pointer target is classified by
    its parsed parts and resolved against the SINGLE correct candidate (drops the
    old `kb_root/target` candidate for bare / non-`repos/` targets, which killed
    the cross-repo basename-collision FP class — a deep `CLAUDE.md` resolving to
    the vault-root `CLAUDE.md`):
      * `..`-traversal       → escape-detection only (source-relative resolve);
      * `repos/`-prefixed    → vault-root-relative only (no local-alias shadow);
      * bare / non-`repos/`  → source-relative only.
    A candidate that is a real file OUTSIDE vault containment (a `../`- or
    absolute-path escape) is still flagged via the explicit
    `is_file() and not is_contained()` escape test — that false-clean trap is
    preserved. Accepted conservative false-negatives (all auto_safe-safe;
    under-report is preferred over false-positive per the scanner's posture):
      * FN-1: a deep source's bare-name pointing at a GENUINE vault-root note →
        source-relative resolve misses it → skipped (0 cases on the real vault).
      * FN-2: a project-root-relative `design/foo.md` from a DEEPER dir than the
        project root → the `cand_proj` candidate is deferred → skipped (0 usage).
      * FN-3: a flat deep-source path-qualified `Note.md` → `flat/Note.md` →
        skipped (0 usage).
      * Pre-existing #76f: a genuine intra-KB pointer to a deleted/renamed `.md`
        that now resolves nowhere is silently skipped (dangling-FILE detection is
        dominated by cross-repo noise on the real vault; re-adding a cross-repo
        predicate to recover it is a deferred follow-up).
  - Whole-vault scan exclusion (no `--project`) is whole-component anchored,
    never substring. Excluded (NOT scanned): case-insensitive `templates`/
    `images`, the Obsidian numbered-prefix form `90_Templates/` / `01-images/`
    (leading ASCII digits `[0-9]` only — a name prefixed with a non-ASCII decimal
    digit is NOT a build dir and stays scanned), and any dot-dir. NOT excluded
    (still scanned): content dirs like `templates-analysis/` and `image-pipeline/`
    — they embed the token but are not the build dir. The wikilink resolution
    index stays whole-vault regardless.
  - No git/network reads.
  - C4 is offline status-drift via the spec's own frontmatter
    `code_audit_evidence:` + column-0 `code audit passed`/zero-diff Log markers.
    Git merge-state is NOT used (the git approach is squash-blind — a squash-
    merge leaves no main-ancestor branch commit). Residual: a squash-merged spec
    that carries NEITHER a non-null `code_audit_evidence` NOR a terminal Log
    marker is not caught. Further residuals (consistent with the scanner's
    case-sensitive, column-0-anchored heuristics): a lowercase `status:` is
    C3-flagged and not pre-terminal anyway; an indented Log marker won't match
    TERMINAL_LOG_MARKER_RE.
  - First slice covers C1/C2/C3/C4 only (no git-status-drift, no concluded-but-
    not-ARCHIVED research check — those are follow-ups).

CLI:
    python3 tests/kb_drift_scan.py <kb_root> [--project <name>] [--json] [--summary]

`<kb_root>` is the vault root. `--project <name>` restricts the scan to
`<kb_root>/repos/<name>/` (path-prefix filter) and is an error (exit 2) when
that subtree does not exist — never a silent zero-scan. Without `--project`,
the scan covers the whole `<kb_root>` vault recursively, excluding dot-
directories and the `templates/` / `images/` build dirs; the wikilink
resolution index stays whole-vault (unfiltered) so links into those dirs still
resolve.

Output: JSON
    {"scanned": <int>, "findings": [{"class", "file", "line", "detail", "auto_safe"}]}
`class` is one of {C1_broken_wikilink, C2_dangling_section_pointer,
C3_status_enum_violation, C4_status_drift, C5_research_status_enum_violation,
C6_index_row_bloat, C7_backlog_done_bloat}.
`file` is KB-relative. `--json` is accepted for explicitness; JSON is always
emitted.

Exit codes: 0 = no findings; 1 = >=1 finding; 2 = usage/IO error.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path, PurePosixPath
from typing import Dict, List, Optional

# C2 reuses the heading-resolution machinery from check_dangling_anchors.py.
# That module is __main__-guarded, so importing it does not run a scan.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_dangling_anchors import (  # noqa: E402
    POINTER_RE,
    anchor_resolves,
    headings_in,
    trim_anchor,
)

# C3 enum source-of-truth (two constants).
# CANONICAL_SPEC_STATUSES — the 8-status enum exactly as written on the
# docs/kb-layout.md §Feature Spec frontmatter enum line. NO `DONE`.
CANONICAL_SPEC_STATUSES = (
    "DRAFT",
    "APPROVED",
    "AUDIT_PASSED",
    "IN_PROGRESS",
    "BLOCKED",
    "SHIPPED",
    "VERIFIED",
    "DISCARDED",
)
# ACCEPTED_SPEC_STATUSES — canonical plus the legacy read-compat synonym DONE.
# A `status: DONE` spec is accepted (NOT flagged) because DONE is a legacy
# read-only synonym of VERIFIED (specs predating 2026-04-17).
ACCEPTED_SPEC_STATUSES = frozenset(CANONICAL_SPEC_STATUSES) | {"DONE"}

# C5-R enum source-of-truth (research-note lifecycle). CANONICAL_RESEARCH_STATUSES
# — the 3-status enum exactly as documented (ACTIVE → CONCLUDED → ARCHIVED) on
# docs/kb-layout.md §research frontmatter + skills/research/SKILL.md. Unlike the
# spec lifecycle there is NO legacy synonym, so ACCEPTED == CANONICAL.
CANONICAL_RESEARCH_STATUSES = ("ACTIVE", "CONCLUDED", "ARCHIVED")
ACCEPTED_RESEARCH_STATUSES = frozenset(CANONICAL_RESEARCH_STATUSES)

# C6 index-row bloat budget — the one-liner character ceiling for an index/MOC
# table cell or list-entry. A row flags iff its measure is STRICTLY greater than
# this (300 sits above the 258/288 cells maintainers accept and below the
# observed dumps at 315/325/333/441/1756). No CLI override (consistent with
# C1–C5 having no tunables).
INDEX_ROW_BLOAT_THRESHOLD = 300
C7_BLOAT_THRESHOLD = 12

# C6 index/MOC file-type tokens (the `type:` values that mark an index/MOC, in
# addition to the `vault-index.md` basename clause).
INDEX_MOC_TYPES = frozenset({"moc", "index"})

# Build/template dirnames excluded from the SCANNED set (NOT the wikilink
# resolution index). `templates/` carries illustrative `[[example]]` wikilinks +
# status-enum samples that would false-positive; `images/` has no `.md`. Plus
# any path component that starts with `.` (dot-dirs: `.obsidian`, `.claude`,
# `.git`, `.trash`, future ones) is excluded — generalized so new dot-dirs need
# no constant edit. The comparison is on kb_root-RELATIVE path components, so an
# excluded-named ancestor ABOVE the vault root does not nuke the scan.
#
# Matched forms (whole-component anchored, NEVER substring):
#   - case-insensitive plain `templates` / `images` (e.g. `Templates`, `IMAGES`)
#     via `comp.casefold()`;
#   - the Obsidian numbered-prefix form `90_Templates` / `01-images` / `2 Template`
#     via SCAN_EXCLUDE_RE.fullmatch (anchored to the whole component).
# NOT matched (still scanned — these are content dirs, not build dirs):
#   `templates-analysis`, `my-templates`, `image-pipeline` — no leading digits
#   and `fullmatch` rejects the trailing suffix.
SCAN_EXCLUDE_DIRNAMES = frozenset({"templates", "images"})

# Obsidian numbered-prefix build-dir form: leading ASCII digits + optional
# ` `/`_`/`-` separator + `template(s)`/`image(s)`. Matched with `fullmatch`
# (anchored to the WHOLE component, equivalent to `^…$`) — case-insensitive.
# Matches `90_Templates`, `01-images`, `2 Template`. Does NOT match
# `templates-analysis` (no leading digits + trailing suffix) or `image-pipeline`.
# The digit class is `[0-9]` (ASCII only) — NOT `\d`, which is Unicode-aware and
# would over-exclude exotic non-ASCII-digit-prefixed content dirs (`٩_templates`,
# `１２_images`) beyond this documented ASCII contract.
SCAN_EXCLUDE_RE = re.compile(r"[0-9]+[ _-]?(?:templates?|images?)", re.IGNORECASE)

# C6 table data row: a line that opens and closes with a `|` (whitespace
# allowed). The separator-row exclusion is done on the parsed cells, not here.
C6_TABLE_ROW_RE = re.compile(r"^\s*\|.*\|\s*$")

# C6 list entry: a bullet (`-`/`*`/`+`) or ordered (`1.`) marker followed by
# whitespace and at least one non-space content char.
C6_LIST_ENTRY_RE = re.compile(r"^\s*([-*+]|\d+\.)\s+\S")

# C6 separator-cell shape: a stripped cell consisting only of dashes with
# optional leading/trailing `:` alignment colons.
C6_SEPARATOR_CELL_RE = re.compile(r"^:?-+:?$")

# C7 backlog done-bloat markers: completed backlog section headers and
# completed Active-priorities table rows kept inline in BACKLOG.md.
C7_STRUCK_HEADER_RE = re.compile(r"^### ~~")
C7_STRUCK_TABLE_ROW_RE = re.compile(r"^\s*\| ~~")

# Obsidian wikilink: [[target]] with optional #heading / |alias / ^block-id.
WIKILINK_RE = re.compile(r"\[\[([^\[\]]+?)\]\]")

# Single-backtick inline-code span. Stripped from a NON-fenced line before the
# C1 wikilink scan (C1 ONLY — the C2 §-pointer path is backtick-wrapped by
# syntax, so stripping inline code there would destroy a legitimate pointer).
# Double-/multi-backtick inline spans are a documented residual (rare in prose).
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")

# Fence delimiter chars Obsidian/CommonMark recognise for code blocks.
_FENCE_CHARS = ("`", "~")

# C3 reads `type` / `status` from the LEADING `--- ... ---` YAML frontmatter
# block ONLY — never from the body (a body that QUOTES `type: spec` inside a
# fenced ```yaml block must not be misclassified as a spec). These match a
# `key: value` line WITHIN the already-isolated frontmatter block.
FM_TYPE_RE = re.compile(r"^type:\s*(\S+)\s*$", re.MULTILINE)
FM_STATUS_RE = re.compile(r"^status:\s*(\S+)\s*$", re.MULTILINE)

# C4 status-drift source-of-truth.
# PRE_TERMINAL_SPEC_STATUSES — the two statuses that PRECEDE the code-audit
# phase. A code-audit completion record at one of them is anomalous (the work
# shipped but the status was left stale). IN_PROGRESS is deliberately EXCLUDED:
# per skills/feature/SKILL.md §Verify/§3.4a the code-audit phase writes
# code_audit_evidence (and the `code audit passed` Log marker) WITHOUT changing
# status — status stays IN_PROGRESS until hand-off. So IN_PROGRESS + evidence is
# the normal awaiting-hand-off state, NOT drift.
PRE_TERMINAL_SPEC_STATUSES = frozenset({"APPROVED", "AUDIT_PASSED"})
# CODE_AUDIT_EVIDENCE_VALUES — the five non-null values code_audit_evidence
# resolves to ONLY when the code-audit phase completes (per
# 2026-04-27-audit-evidence-enum.md §2.2 / SKILL.md §3.5b). The literal token
# `null` is deliberately NOT in this set — `null`/empty/absent → no evidence.
CODE_AUDIT_EVIDENCE_VALUES = frozenset(
    {"dual_model", "single_model", "self_fallback", "contract_violated", "skipped"}
)
# C4 reads the frontmatter `code_audit_evidence:` scalar (structured signal).
FM_CODE_AUDIT_EVIDENCE_RE = re.compile(
    r"^code_audit_evidence:\s*(\S+)\s*$", re.MULTILINE
)
# C4 legacy fallback: a canonical terminal code-audit Log marker. LINE-ANCHORED
# at column 0 (NOT a free substring) to match the canonical Log-item shape and
# avoid matching narrative prose that merely mentions "code audit passed".
TERMINAL_LOG_MARKER_RE = re.compile(
    r"^- \d{4}-\d{2}-\d{2}: code audit passed\b"
    r"|^- \d{4}-\d{2}-\d{2}: code audit: no auditable files in diff",
    re.MULTILINE,
)


def is_contained(path: Path, root: Path) -> bool:
    """True iff `path`, fully resolved, stays at or under `root` (resolved).

    Containment guard for every site where a user-controlled string (a
    `--project` value, a wikilink target, a `§`-pointer relpath) becomes a
    filesystem path. `Path.resolve()` collapses `../` and follows symlinks, so
    an escaping value (`../outside`, an absolute path, a symlink out of tree)
    is rejected here BEFORE any `is_dir()` / `is_file()` / `headings_in()` read.
    An out-of-tree resolution is never a valid target — a `../`-escaping link is
    reported broken/dangling, never silently treated as clean.
    """
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def scan_roots(kb_root: Path, project: Optional[str]) -> List[Path]:
    """Resolve the directory subtree(s) to walk.

    --project <name>  → <kb_root>/repos/<name>/
    otherwise         → <kb_root> itself (the whole vault — root files +
                        non-repos top-level dirs + repos/*, each walked once).
    """
    if project is not None:
        return [kb_root / "repos" / project]
    return [kb_root]


def _is_excluded(path: Path, kb_root: Path) -> bool:
    """True iff any kb_root-RELATIVE path component of `path` is a build/template
    dirname or starts with `.` (dot-dir).

    A component is excluded iff ANY of:
      - `comp.startswith(".")` — dot-dir rule (UNCHANGED);
      - `comp.casefold()` ∈ {"templates", "images"} — plain name, matched
        case-insensitively (whole component, never substring);
      - `SCAN_EXCLUDE_RE.fullmatch(comp)` — the Obsidian numbered-prefix form
        (`90_Templates`, `01-images`), anchored to the WHOLE component.
    Matching is whole-component anchored — NEVER substring — so content dirs like
    `templates-analysis` / `image-pipeline` stay scanned.

    Compares kb_root-RELATIVE components (NOT absolute) so an excluded-named
    ancestor ABOVE kb_root (e.g. the vault living under `~/.../templates/`) does
    not wrongly exclude everything. A path outside kb_root is treated as not
    excluded (relative_to raises → no filtering).
    """
    try:
        rel = path.relative_to(kb_root)
    except ValueError:
        return False
    return any(
        comp.startswith(".")
        or comp.casefold() in SCAN_EXCLUDE_DIRNAMES
        or SCAN_EXCLUDE_RE.fullmatch(comp)
        for comp in rel.parts
    )


def md_files(
    roots: List[Path], kb_root: Optional[Path] = None, exclude_build_dirs: bool = False
) -> List[Path]:
    files: List[Path] = []
    for root in roots:
        if not root.is_dir():
            continue
        for p in sorted(root.rglob("*.md")):
            if exclude_build_dirs and kb_root is not None and _is_excluded(p, kb_root):
                continue
            files.append(p)
    return files


def note_stem(path: Path) -> str:
    """Case-insensitive bare note name (filename stem) for resolution."""
    return path.stem.lower()


def build_note_index(all_md: List[Path]) -> Dict[str, List[Path]]:
    """Map case-insensitive bare stem → list of notes carrying that stem.

    Used by stage-1 as-written resolution (exact case-insensitive stem).
    """
    index: Dict[str, List[Path]] = {}
    for p in all_md:
        index.setdefault(note_stem(p), []).append(p)
    return index


def fuzzy_key(name: str) -> str:
    """Stage-2 correction key — alphanumeric-only, lowercase.

    Collapses separators/case so a broken target can match a near-miss note
    that stage-1 exact-stem resolution did not (e.g. broken `[[My Note]]` →
    candidate `My-Note.md`). Deliberately distinct from stage-1's exact stem
    so a unique correction is detectable without resolving the link itself.
    """
    return re.sub(r"[^a-z0-9]", "", name.lower())


def build_fuzzy_index(all_md: List[Path]) -> Dict[str, List[Path]]:
    """Map stage-2 fuzzy key → list of notes carrying that key."""
    index: Dict[str, List[Path]] = {}
    for p in all_md:
        index.setdefault(fuzzy_key(p.stem), []).append(p)
    return index


def build_suffix_index(all_md: List[Path], kb_root: Path) -> set:
    """Set of vault-relative component-tuple SUFFIXES (length >= 2) of all notes.

    Obsidian resolves a path-qualified link `[[a/Note]]` to any note whose
    vault-relative path ENDS with those components, so the resolver checks
    membership of the target's component tuple in this set. Tuple (not string)
    suffixing enforces the path boundary: `("a","note")` is a suffix of
    `("x","a","note")` but NOT `("xa","note")`. 1-tuples are omitted — a bare
    name stays in note_index, never the suffix index.
    """
    idx: set = set()
    for p in all_md:
        parts = normalized_note_parts(p.relative_to(kb_root).as_posix())
        for i in range(len(parts) - 1):
            idx.add(parts[i:])
    return idx


def bare_target(raw: str) -> str:
    """Strip #heading / |alias / ^block-id suffixes to the bare link target.

    EVERY pipe ends the target — both the plain `|` and the table-escaped `\\|` are
    Obsidian alias separators — so truncation happens at the FIRST `|` of any
    backslash parity. The literal backslashes that survive into the target are
    `floor(bs/2)`, where `bs` is the consecutive `\\` run immediately before that
    pipe (an odd run's last `\\` is the pipe's escape and is dropped; pairs collapse
    to one literal `\\`). `#`/`^` truncate at their first occurrence; final
    `.strip()` is unchanged. NOTE: does NOT use split_unescaped_pipes — that
    even-parity split would leave an odd `\\|` (e.g. `Real Note\\|alias`)
    un-truncated.
    """
    pipe = raw.find("|")
    if pipe != -1:
        bs = 0
        j = pipe - 1
        while j >= 0 and raw[j] == "\\":
            bs += 1
            j -= 1
        target = raw[: pipe - bs] + "\\" * (bs // 2)
    else:
        target = raw
    for sep in ("#", "^"):
        idx = target.find(sep)
        if idx != -1:
            target = target[:idx]
    return target.strip()


def normalized_note_parts(target: str) -> tuple:
    """Vault-relative component tuple of a wikilink target / note relpath.

    Drops empty components (leading / trailing / doubled slash) and lowercases
    each (Obsidian resolution is case-insensitive). The LAST component's `.md`
    suffix is stripped AFTER the empty-drop so a `.md`-qualified target and its
    note share one key. Used for both the suffix index and the resolver's
    shape dispatch.
    """
    parts = [p.lower() for p in target.split("/") if p]
    if parts and parts[-1].endswith(".md"):
        parts[-1] = parts[-1][:-3]
    return tuple(parts)


def wikilink_resolves_as_written(
    target: str,
    kb_root: Path,
    note_index: Dict[str, List[Path]],
    suffix_index: set,
    source_path: Path,
) -> bool:
    """Stage 1 — Obsidian as-written resolution, dispatched by target SHAPE.

    - bare (no `/`)            → vault-wide case-insensitive note_index.
    - path-qualified (no `..`/`.`) → component-tuple SUFFIX match (Obsidian
      partial-path semantics: `[[a/Note]]` resolves `x/a/Note.md`). A wrong
      path that is NOT a tuple-suffix of any note no longer false-resolves via
      a bare-stem fallback (#76d FN closed).
    - relative (`..`/`.`)      → source-relative FS try, then a conservative
      bare-stem fallback (Option B — empirically keeps live `../` links clean,
      no-FP posture; named known-limitation for the residual miss).

    True iff the target resolves under any of those shapes. The vault-root FS
    tries run UNCHANGED first (so an explicit `.md`/path target that is a real
    vault file always wins). `is_contained` short-circuits before `is_file()`,
    so an absolute / `../`-escaping FS try is rejected, never silently clean.
    """
    if not target:
        return True  # empty target — not a broken-link finding
    parts = normalized_note_parts(target)
    if not parts:
        return True  # degenerate (only slashes) — not a broken-link finding
    candidate = target[: -len(".md")] if target.lower().endswith(".md") else target
    # Vault-root FS tries (UNCHANGED): guard containment before is_file() so a
    # `../`-escaping or absolute target that resolves to a real out-of-vault
    # `.md` is NOT a silent false-clean.
    rel_md = kb_root / (candidate + ".md")
    if is_contained(rel_md, kb_root) and rel_md.is_file():
        return True
    rel_exact = kb_root / target
    if is_contained(rel_exact, kb_root) and rel_exact.is_file():
        return True
    if ".." in parts or "." in parts:
        # Relative form (Option B): try source-relative FS, then fall back to a
        # conservative bare-stem check (scoped #76d residual — no-FP posture).
        srel_md = source_path.parent / (candidate + ".md")
        if is_contained(srel_md, kb_root) and srel_md.is_file():
            return True
        srel_exact = source_path.parent / target
        if is_contained(srel_exact, kb_root) and srel_exact.is_file():
            return True
        return parts[-1] in note_index
    if len(parts) == 1:
        return parts[0] in note_index  # bare note-name (UNCHANGED)
    return parts in suffix_index  # path-qualified — strict component-tuple suffix


def correction_candidates(target: str, fuzzy_index: Dict[str, List[Path]]) -> int:
    """Stage 2 — count fuzzy correction candidates for a BROKEN link.

    A candidate is a vault note whose fuzzy key (alphanumeric-only, lowercase)
    equals the broken target's fuzzy key. Returns the candidate count; the
    caller maps 1 → auto_safe:true (unique fix), 0 or >1 → auto_safe:false
    (no fix / ambiguous).
    """
    key = fuzzy_key(Path(bare_target(target)).name)
    if not key:
        return 0
    return len(fuzzy_index.get(key, []))


def kb_relative(path: Path, kb_root: Path) -> str:
    try:
        return str(path.relative_to(kb_root))
    except ValueError:
        return str(path)


def leading_frontmatter(text: str) -> Optional[str]:
    """Return the leading `--- ... ---` YAML frontmatter block, or None.

    A frontmatter block exists only when the document's first line is a bare
    `---` fence and a closing `---` fence follows. Returns the body BETWEEN the
    fences (exclusive). None means no leading frontmatter — the doc is not a
    spec for C3 purposes regardless of what its body quotes.
    """
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            return "\n".join(lines[1:idx])
    return None


def fenced_line_mask(lines: List[str]) -> List[bool]:
    """Per-line mask: True iff a line is inside (or delimits) a fenced code block.

    Obsidian does not render wikilinks / §-pointers inside fenced code, so a
    masked line is skipped by both the C1 and C2 per-line loops. Fence-
    recognition contract (§3.2a of the spec):

    - A fence char is `` ` `` or `~`. A fence OPENS (when not already inside one)
      when the stripped line begins with ≥3 of a single fence char; the run
      length and char are recorded. An info string may follow the run. The
      opening delimiter line is itself masked.
    - A fence CLOSES (when inside one) when the stripped line consists solely of
      ≥`run_length` of the SAME char (trailing whitespace allowed, nothing
      else). The closing delimiter line is itself masked. Any other line while
      inside a fence stays masked.
    - `---` / `***` / `___` are thematic-break / frontmatter markers, NOT fences
      — they never toggle.
    - An unclosed fence at EOF leaves every line from the opener onward masked
      (conservative: under-reports inside an unterminated block, never
      false-positives outside one).
    """
    mask = [False] * len(lines)
    fence_char: Optional[str] = None
    fence_len = 0
    for idx, line in enumerate(lines):
        stripped = line.strip()
        if fence_char is None:
            char = stripped[0] if stripped else ""
            if char in _FENCE_CHARS:
                run = len(stripped) - len(stripped.lstrip(char))
                if run >= 3:
                    fence_char = char
                    fence_len = run
                    mask[idx] = True
        else:
            mask[idx] = True
            if (
                stripped
                and set(stripped) == {fence_char}
                and len(stripped) >= fence_len
            ):
                fence_char = None
                fence_len = 0
    return mask


def split_unescaped_pipes(s: str) -> List[str]:
    """Split a string on UNESCAPED `|` cell separators (backslash-parity aware).

    A `|` is a SEPARATOR iff the run of consecutive `\\` immediately before it is
    EVEN (0, 2, 4, …): zero backslashes is a plain separator; two backslashes are
    an escaped backslash followed by an unescaped pipe; etc. An ODD run (1, 3, …)
    escapes the pipe, which stays inside its segment. Segments keep their RAW text
    (backslashes intact — C6 measures visual length). So `a\\|b` (1 `\\`, odd)
    stays one segment `['a\\|b']`, while `a\\\\|b` (2 `\\`, even) splits into
    `['a\\\\', 'b']`.
    """
    segments: List[str] = []
    start = 0
    i = 0
    n = len(s)
    while i < n:
        if s[i] == "|":
            bs = 0
            j = i - 1
            while j >= 0 and s[j] == "\\":
                bs += 1
                j -= 1
            if bs % 2 == 0:
                segments.append(s[start:i])
                start = i + 1
        i += 1
    segments.append(s[start:])
    return segments


def c6_table_row_measure(line: str) -> Optional[int]:
    """Measure a markdown table data row for C6, or None if it is not one.

    Splits on UNESCAPED `|` only (via split_unescaped_pipes — a `|` separates iff
    the preceding `\\` run is EVEN, so `a\\|b` with one `\\` stays one cell while a
    real `a\\\\|b` separator with two `\\` splits), drops the empty leading/trailing
    cells produced by the outer pipes, and returns the MAX stripped-cell length.
    Returns None when the line is a header SEPARATOR row (every non-empty stripped
    cell matches `^:?-+:?$` AND at least one cell contains a `-`) — an all-empty
    `|  |  |` row is NOT a separator (it is a degenerate data row, measure 0).
    """
    cells = [c.strip() for c in split_unescaped_pipes(line)]
    # Drop the empty outer cells produced by the leading/trailing pipes.
    if cells and cells[0] == "":
        cells = cells[1:]
    if cells and cells[-1] == "":
        cells = cells[:-1]
    nonempty = [c for c in cells if c]
    if (
        nonempty
        and all(C6_SEPARATOR_CELL_RE.match(c) for c in nonempty)
        and any("-" in c for c in nonempty)
    ):
        return None  # header separator row
    return max((len(c) for c in cells), default=0)


def c6_list_entry_measure(line: str) -> int:
    """Stripped length of a list entry's content AFTER its marker.

    The caller has already matched C6_LIST_ENTRY_RE; this strips the leading
    whitespace + marker + the following whitespace and measures the remainder.
    """
    m = C6_LIST_ENTRY_RE.match(line)
    assert m is not None  # caller matched first
    return len(line[m.end() - 1 :].strip())


def c6_frontmatter_skip_count(lines: List[str]) -> int:
    """Number of LEADING lines (1-based count) covered by the `--- … ---` block.

    Returns the 1-based count of leading lines to skip — both fences plus any
    body between them. 0 = no leading frontmatter (skip nothing). The empty-FM
    file `---\\n---` resolves to 2 (both fences, zero body). A file whose first
    line is not `---`, or with no closing fence, yields 0.
    """
    fm_end = 0
    if lines and lines[0].strip() == "---":
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                fm_end = i + 1
                break
    return fm_end


def scan(kb_root: Path, project: Optional[str]) -> Dict:
    roots = scan_roots(kb_root, project)
    # The SCANNED set excludes dot-dirs + templates/images (build/template
    # content). The note/resolution index below stays UNFILTERED.
    files = md_files(roots, kb_root, exclude_build_dirs=True)
    # Note index spans the WHOLE vault (wikilinks resolve vault-wide in
    # Obsidian), not just the scanned subtree — and NOT filtered, so wikilink
    # targets in templates/ or dot-dirs still resolve (no spurious C1).
    all_md = md_files([kb_root])
    note_index = build_note_index(all_md)
    fuzzy_index = build_fuzzy_index(all_md)
    suffix_index = build_suffix_index(all_md, kb_root)

    findings: List[Dict] = []

    for path in files:
        rel = kb_relative(path, kb_root)
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        lines = text.splitlines()
        # Single shared fenced-code mask, computed ONCE per file and consulted
        # by BOTH the C1 and C2 per-line loops below — Obsidian does not render
        # wikilinks / §-pointers inside fenced code.
        mask = fenced_line_mask(lines)

        # --- C1 broken wikilink ---
        for line_num, line in enumerate(lines, 1):
            if mask[line_num - 1]:
                continue  # inside a fenced code block — not a rendered link
            # Strip single-backtick inline-code spans before the wikilink scan
            # (C1 ONLY): an inline `code [[x]]` span is not a rendered link.
            line = INLINE_CODE_RE.sub("", line)
            for m in WIKILINK_RE.finditer(line):
                target = bare_target(m.group(1))
                if not target:
                    continue
                if wikilink_resolves_as_written(
                    target, kb_root, note_index, suffix_index, path
                ):
                    continue  # stage 1 resolved → working link → NOT a finding
                # Broken at stage 1 — assess correction candidacy (stage 2).
                n_cand = correction_candidates(target, fuzzy_index)
                auto_safe = n_cand == 1
                findings.append(
                    {
                        "class": "C1_broken_wikilink",
                        "file": rel,
                        "line": line_num,
                        "detail": f"wikilink [[{target}]] resolves to zero vault notes "
                        f"(correction candidates: {n_cand})",
                        "auto_safe": auto_safe,
                    }
                )

        # --- C2 dangling section pointer ---
        # Shares the single `mask` above. NO inline-code strip here: the
        # §-pointer path is backtick-wrapped by syntax (`` `path.md` §heading ``),
        # so stripping inline code would destroy a legitimate pointer.
        for line_num, line in enumerate(lines, 1):
            if mask[line_num - 1]:
                continue  # inside a fenced code block — not a rendered pointer
            for m in POINTER_RE.finditer(line):
                pointer_target = m.group("file")
                anchor = trim_anchor(m.group("rest"))
                if not anchor:
                    continue
                # Target-class dispatch: classify the pointer target by its
                # parsed parts FIRST, then build the SINGLE correct candidate.
                # Dropping the old `kb_root/target` candidate for bare / path-
                # qualified-non-`repos/` targets kills the cross-repo basename
                # collision at source (a deep `CLAUDE.md` no longer resolves to
                # the vault-root `CLAUDE.md`).
                parts = PurePosixPath(pointer_target).parts
                if ".." in parts:
                    # `..`-traversal → escape-detection ONLY; routed BEFORE any
                    # kb_root resolution so `repos/../CLAUDE.md` cannot collapse
                    # back to `kb_root/CLAUDE.md`.
                    cands = [(path.parent / pointer_target).resolve()]
                elif parts and parts[0] == "repos":
                    # Explicit cross-project → vault-root-relative ONLY (no
                    # source-relative cand, so a local `repos/...` shadow under
                    # the source dir never wins over the intended vault file).
                    cands = [(kb_root / pointer_target).resolve()]
                else:
                    # Bare basename OR path-qualified-non-`repos/` → SOURCE-
                    # relative ONLY. Absolute targets (`parts[0] == '/'`) land
                    # here too: `(path.parent / "/abs").resolve()` discards the
                    # left operand and yields the real out-of-vault file, caught
                    # by the explicit escape test below.
                    cands = [(path.parent / pointer_target).resolve()]
                # In-KB target: a candidate that is a real file contained under
                # the vault → this is the resolved pointer; do the heading check.
                target_path: Optional[Path] = next(
                    (c for c in cands if is_contained(c, kb_root) and c.is_file()),
                    None,
                )
                if target_path is None:
                    # Not an in-KB file. Split the not-found case:
                    #   - a candidate is a REAL file OUT of vault containment (a
                    #     `../`- or absolute-path escape to a real note) → still
                    #     a false-clean trap → flag (preserves the X5 lock). The
                    #     test MUST be `is_file() and not is_contained()` — NOT a
                    #     bare `is_file()` — so a rejected IN-vault candidate is
                    #     not mis-flagged as an escape;
                    #   - resolves to NO file (out-of-scope cross-repo reference,
                    #     e.g. `skills/...md`, or simply unresolvable) → skip, NOT
                    #     a finding (#76f).
                    escaped = any(
                        c.is_file() and not is_contained(c, kb_root) for c in cands
                    )
                    if escaped:
                        findings.append(
                            {
                                "class": "C2_dangling_section_pointer",
                                "file": rel,
                                "line": line_num,
                                "detail": f"pointer `{pointer_target}` §{anchor} → target escapes vault containment",
                                "auto_safe": False,
                            }
                        )
                    continue
                heads = headings_in(target_path)
                if not anchor_resolves(anchor, heads):
                    findings.append(
                        {
                            "class": "C2_dangling_section_pointer",
                            "file": rel,
                            "line": line_num,
                            "detail": f"pointer `{pointer_target}` §{anchor} → no matching heading",
                            "auto_safe": False,
                        }
                    )

        # --- C6 index-row bloat ---
        # Runs in the C1/C2 region — ABOVE the `frontmatter is None: continue`
        # gate below — with its OWN index/MOC predicate (§3.2 a′). A no-
        # frontmatter `vault-index.md` returns None from leading_frontmatter() and
        # would `continue` before a C6 block placed alongside C3/C4/C5 ever ran,
        # making the basename clause dead code. The predicate: leading-frontmatter
        # `type:` ∈ {moc, index} OR the basename is `vault-index.md` (a no-
        # frontmatter file qualifies ONLY via the basename clause).
        c6_fm = leading_frontmatter(text)
        c6_type = None
        if c6_fm is not None:
            c6_type_match = FM_TYPE_RE.search(c6_fm)
            if c6_type_match is not None:
                c6_type = c6_type_match.group(1)
        is_index_moc = (
            c6_type in INDEX_MOC_TYPES or path.name.lower() == "vault-index.md"
        )
        if is_index_moc:
            # Skip the leading `--- … ---` frontmatter block (b′): C6 sees it
            # because it runs above the gate, and a YAML block-sequence line
            # (`  - tag`) would otherwise match the list-entry regex.
            fm_skip = c6_frontmatter_skip_count(lines)
            for line_num, line in enumerate(lines, 1):
                if line_num <= fm_skip:
                    continue  # inside the leading frontmatter block
                if mask[line_num - 1]:
                    continue  # inside a fenced code block
                measure: Optional[int] = None
                if C6_TABLE_ROW_RE.match(line):
                    measure = c6_table_row_measure(line)
                elif C6_LIST_ENTRY_RE.match(line):
                    measure = c6_list_entry_measure(line)
                if measure is not None and measure > INDEX_ROW_BLOAT_THRESHOLD:
                    findings.append(
                        {
                            "class": "C6_index_row_bloat",
                            "file": rel,
                            "line": line_num,
                            "detail": f"index row exceeds one-liner budget: {measure} chars > {INDEX_ROW_BLOAT_THRESHOLD} (summary belongs on the page, not the index row)",
                            "auto_safe": False,
                        }
                    )

        # --- C7 backlog done bloat ---
        # Runs ABOVE the `frontmatter is None: continue` gate so BACKLOG.md files
        # without YAML frontmatter are still checked.
        if path.name == "BACKLOG.md":
            completed_inline = sum(
                1
                for line in lines
                if C7_STRUCK_HEADER_RE.match(line) or C7_STRUCK_TABLE_ROW_RE.match(line)
            )
            if completed_inline >= C7_BLOAT_THRESHOLD:
                findings.append(
                    {
                        "class": "C7_backlog_done_bloat",
                        "file": rel,
                        "line": None,
                        "detail": f"BACKLOG.md has {completed_inline} completed items inline (>= {C7_BLOAT_THRESHOLD}) — run python3 tests/backlog_archive.py <kb_root> --project <p> --dry-run to review",
                        "auto_safe": False,
                    }
                )

        # --- C3 status-enum violation ---
        # Scope strictly to the leading `--- ... ---` frontmatter block — a body
        # that merely QUOTES `type: spec` (e.g. a research note documenting the
        # schema in a fenced ```yaml block) is NOT a spec and must not be flagged.
        # A doc with no leading frontmatter (plain note) is not a spec → skip.
        frontmatter = leading_frontmatter(text)
        if frontmatter is None:
            continue
        type_match = FM_TYPE_RE.search(frontmatter)
        if type_match is not None and type_match.group(1) == "spec":
            status_match = FM_STATUS_RE.search(frontmatter)
            if status_match is None:
                findings.append(
                    {
                        "class": "C3_status_enum_violation",
                        "file": rel,
                        "line": None,
                        "detail": "type: spec doc has no frontmatter status:",
                        "auto_safe": False,
                    }
                )
            else:
                status = status_match.group(1)
                if status not in ACCEPTED_SPEC_STATUSES:
                    # Frontmatter body starts at file line 2 (line 1 is the
                    # opening `---` fence).
                    line_num = frontmatter[: status_match.start()].count("\n") + 2
                    findings.append(
                        {
                            "class": "C3_status_enum_violation",
                            "file": rel,
                            "line": line_num,
                            "detail": f"status: {status} not in accepted spec-status enum",
                            "auto_safe": False,
                        }
                    )

                # --- C4 status-drift (offline, git-free) ---
                # Fire iff a pre-code-audit status (APPROVED/AUDIT_PASSED — NOT
                # IN_PROGRESS) carries a code-audit COMPLETION record: a non-null
                # frontmatter `code_audit_evidence:` (structured, primary) OR a
                # canonical column-0 terminal Log marker (legacy fallback). Reads
                # the spec file only. C4 recomputes its own status/line rather
                # than reusing the C3 locals (those bind only inside the narrower
                # enum-violation sub-branch). C4 is independent of C3's validity
                # check — every PRE_TERMINAL status is a valid enum value, so no
                # double-flag in practice.
                c4_status = status_match.group(1)
                if c4_status in PRE_TERMINAL_SPEC_STATUSES:
                    c4_line = frontmatter[: status_match.start()].count("\n") + 2
                    ev_match = FM_CODE_AUDIT_EVIDENCE_RE.search(frontmatter)
                    ev = ev_match.group(1) if ev_match else None
                    # `null`/empty/absent → no evidence (the literal token `null`
                    # is not in CODE_AUDIT_EVIDENCE_VALUES).
                    structured = ev in CODE_AUDIT_EVIDENCE_VALUES
                    marker = bool(TERMINAL_LOG_MARKER_RE.search(text))
                    if structured or marker:
                        if structured:
                            detail = (
                                f"status: {c4_status} precedes the code-audit phase "
                                f"but code_audit_evidence: {ev} is set (code audit "
                                f"completed → status likely stale; should be "
                                f"SHIPPED/VERIFIED)"
                            )
                        else:
                            detail = (
                                f"status: {c4_status} precedes the code-audit phase "
                                f"but Log records a 'code audit passed' terminal "
                                f"marker (status likely stale)"
                            )
                        findings.append(
                            {
                                "class": "C4_status_drift",
                                "file": rel,
                                "line": c4_line,
                                "detail": detail,
                                "auto_safe": False,
                            }
                        )

        # --- C5 research-status enum violation ---
        # The C3 analog, type-scoped on the EXACT leading-frontmatter string
        # `type: research` (NEVER the `research/` path — legacy
        # `type: research-note` notes are a distinct, intentional type spelling
        # and stay clean even with off-enum statuses, a deliberate conservative
        # FN). Reuses the same `leading_frontmatter()` isolation + FM_STATUS_RE
        # as C3 against the 3-value research enum (no legacy synonym).
        elif type_match is not None and type_match.group(1) == "research":
            status_match = FM_STATUS_RE.search(frontmatter)
            if status_match is None:
                findings.append(
                    {
                        "class": "C5_research_status_enum_violation",
                        "file": rel,
                        "line": None,
                        "detail": "type: research doc has no frontmatter status:",
                        "auto_safe": False,
                    }
                )
            else:
                status = status_match.group(1)
                if status not in ACCEPTED_RESEARCH_STATUSES:
                    # Frontmatter body starts at file line 2 (line 1 is the
                    # opening `---` fence).
                    line_num = frontmatter[: status_match.start()].count("\n") + 2
                    findings.append(
                        {
                            "class": "C5_research_status_enum_violation",
                            "file": rel,
                            "line": line_num,
                            "detail": f"status: {status} not in accepted research-status enum",
                            "auto_safe": False,
                        }
                    )

    return {"scanned": len(files), "findings": findings}


# Canonical class order for the --summary render (C1<C2<C3<C4<C5<C6<C7). Keyed by
# the leading CLASS_SHORT token (the class up to the first `_`).
_CLASS_ORDER = ("C1", "C2", "C3", "C4", "C5", "C6", "C7")


def class_short(cls: str) -> str:
    """Leading CLASS_SHORT token of a finding class (up to the first `_`).

    `C4_status_drift` → `C4`. Used for the headline per-class counts and to
    order/group the detail block in canonical class order.
    """
    return cls.split("_", 1)[0]


def render_summary(report: Dict) -> str:
    """Human digest of a scan `report` — pure presentation, no scan logic.

    Line 1 (headline) is stable + machine-reusable (the status fold reads it):
      clean    → `✓ KB clean — 0 drift findings (scanned <N>)`
      findings → `⚠ KB drift — <M> findings: <C?:n ...> (scanned <N>)` where the
                 per-class counts list ONLY classes with count >0, in canonical
                 C1<C2<C3<C4 order, space-joined.
    Detail block (findings only): one group per class present, canonical order.
    Group header: `<full-class> (<count>) [<boundary>]` — boundary is
    `needs human decision` if ANY finding in the group is `auto_safe:false`,
    else `auto-safe`. Then one indented line per finding (scan order preserved):
    `  <file>:<line> — <detail>`, or `  <file> — <detail>` when `line is None`.
    """
    scanned = report["scanned"]
    findings = report["findings"]
    if not findings:
        return f"✓ KB clean — 0 drift findings (scanned {scanned})"

    # Group findings by CLASS_SHORT, preserving scan order within each group.
    groups: Dict[str, List[Dict]] = {}
    for f in findings:
        groups.setdefault(class_short(f["class"]), []).append(f)

    present = [short for short in _CLASS_ORDER if short in groups]

    counts = " ".join(f"{short}:{len(groups[short])}" for short in present)
    headline = f"⚠ KB drift — {len(findings)} findings: {counts} (scanned {scanned})"

    blocks = [headline]
    for short in present:
        group = groups[short]
        full_class = group[0]["class"]
        boundary = (
            "needs human decision"
            if any(not f["auto_safe"] for f in group)
            else "auto-safe"
        )
        blocks.append(f"{full_class} ({len(group)}) [{boundary}]")
        for f in group:
            if f["line"] is None:
                blocks.append(f"  {f['file']} — {f['detail']}")
            else:
                blocks.append(f"  {f['file']}:{f['line']} — {f['detail']}")
    return "\n".join(blocks)


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kb_root", help="KB vault root directory")
    parser.add_argument(
        "--project",
        default=None,
        help="restrict scan to <kb_root>/repos/<name>/",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="emit JSON (always emitted; flag kept for explicitness)",
    )
    parser.add_argument(
        "--summary",
        action="store_true",
        help="print a human digest (stable headline + grouped detail) instead "
        "of JSON; wins over --json when both are set",
    )
    args = parser.parse_args(argv)

    kb_root = Path(args.kb_root)
    if not kb_root.is_dir():
        print(
            f"error: KB root not found or not a directory: {kb_root}", file=sys.stderr
        )
        return 2

    # A typo'd / missing --project must NOT yield a silent false-clean scan
    # ({"scanned": 0, "findings": []} exit 0). Fail loud like the kb_root check.
    if args.project is not None:
        project_root = kb_root / "repos" / args.project
        # A `--project ../foo` (or absolute) value can resolve to a real dir
        # OUTSIDE repos/ and pass is_dir(), scanning an unintended subtree in
        # violation of the documented <kb_root>/repos/<name>/ path-prefix. Reject
        # any value that escapes repos/ before the existence check.
        repos_root = kb_root / "repos"
        if not is_contained(project_root, repos_root):
            print(
                f"error: --project must stay under {repos_root}; "
                f"traversing value rejected: {args.project!r}",
                file=sys.stderr,
            )
            return 2
        if not project_root.is_dir():
            print(
                f"error: project subtree not found or not a directory: {project_root}",
                file=sys.stderr,
            )
            return 2

    try:
        report = scan(kb_root, args.project)
    except OSError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    if args.summary:
        print(render_summary(report))
    else:
        print(json.dumps(report, indent=2))
    return 1 if report["findings"] else 0


if __name__ == "__main__":
    sys.exit(main())
