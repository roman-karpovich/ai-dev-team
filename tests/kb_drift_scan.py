#!/usr/bin/env python3
"""Offline KB-vault drift scanner — narrow first check set (C1/C2/C3).

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

Known limitations (heuristic, like the existing checkers):
  - C1 vault-wide bare-name resolution can false-positive on intentional stub
    links (hence `auto_safe: false` on ambiguity — the curator surfaces, never
    auto-fixes those).
  - Code is skipped: lines inside (or delimiting) a fenced ```code block``` are
    masked for both C1 and C2, and single-backtick inline-code spans are
    stripped before the C1 wikilink scan. Double-/multi-backtick inline spans
    and prose-example wikilinks written outside code (an illustrative
    `[[future-note]]` in body prose) remain a residual minority false-positive —
    distinguishing illustrative-from-real `[[...]]` outside code is deferred.
  - C2 resolution: a §-pointer whose target resolves to NO file at any candidate
    (out-of-scope cross-repo reference, e.g. `skills/...md`, or a target that
    resolves nowhere) is skipped — NOT flagged. The cost: a genuine intra-KB
    pointer to a deleted/renamed `.md` that now resolves nowhere is also
    silently skipped (dangling-FILE detection is dominated by cross-repo noise
    on the real vault; re-adding a cross-repo predicate to recover it is a
    deferred follow-up). A target that resolves to a REAL file OUTSIDE vault
    containment (a `../`-escape) is still flagged — that false-clean trap is
    preserved.
  - No git/network reads.
  - First slice covers C1/C2/C3 only (no git-status-drift, no concluded-but-not-
    ARCHIVED research check — those are follow-ups).

CLI:
    python3 tests/kb_drift_scan.py <kb_root> [--project <name>] [--json]

`<kb_root>` is the vault root. `--project <name>` restricts the scan to
`<kb_root>/repos/<name>/` (path-prefix filter) and is an error (exit 2) when
that subtree does not exist — never a silent zero-scan. Without `--project`,
the scan covers `<kb_root>/repos/*/`; when `<kb_root>/repos/` does not exist the
scanner walks `<kb_root>` directly (covers a flat fixture vault).

Output: JSON
    {"scanned": <int>, "findings": [{"class", "file", "line", "detail", "auto_safe"}]}
`class` is one of {C1_broken_wikilink, C2_dangling_section_pointer,
C3_status_enum_violation}. `file` is KB-relative. `--json` is accepted for
explicitness; JSON is always emitted.

Exit codes: 0 = no findings; 1 = >=1 finding; 2 = usage/IO error.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
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

    --project <name>      → <kb_root>/repos/<name>/
    <kb_root>/repos/ exists → every <kb_root>/repos/*/ subdir
    otherwise             → <kb_root> itself (flat fixture vault)
    """
    if project is not None:
        return [kb_root / "repos" / project]
    repos = kb_root / "repos"
    if repos.is_dir():
        return sorted(p for p in repos.iterdir() if p.is_dir())
    return [kb_root]


def md_files(roots: List[Path]) -> List[Path]:
    files: List[Path] = []
    for root in roots:
        if not root.is_dir():
            continue
        files.extend(sorted(root.rglob("*.md")))
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


def bare_target(raw: str) -> str:
    """Strip #heading / |alias / ^block-id suffixes to the bare link target."""
    target = raw
    for sep in ("|", "#", "^"):
        idx = target.find(sep)
        if idx != -1:
            target = target[:idx]
    return target.strip()


def wikilink_resolves_as_written(
    target: str, kb_root: Path, note_index: Dict[str, List[Path]]
) -> bool:
    """Stage 1 — Obsidian as-written resolution.

    A target resolves if it matches a vault note by bare note-name
    (case-insensitive stem) OR by an explicit vault-relative path / `.md`-
    qualified form. True iff at least one matching note exists.
    """
    if not target:
        return True  # empty target — not a broken-link finding
    # Path-qualified or `.md`-suffixed form: try as a vault-relative path,
    # with and without an appended `.md`.
    candidate = target
    if candidate.lower().endswith(".md"):
        candidate = candidate[: -len(".md")]
    # Each KB-relative candidate must stay inside the vault: a `../`-escaping or
    # absolute target that happens to resolve to a real out-of-vault `.md` is
    # NOT a working link (it would be a silent false-clean), so guard with
    # is_contained before is_file().
    rel_md = kb_root / (candidate + ".md")
    if is_contained(rel_md, kb_root) and rel_md.is_file():
        return True
    rel_exact = kb_root / target
    if is_contained(rel_exact, kb_root) and rel_exact.is_file():
        return True
    # Bare note-name form (last path component, case-insensitive stem).
    stem = Path(candidate).name.lower()
    if stem in note_index:
        return True
    return False


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


def scan(kb_root: Path, project: Optional[str]) -> Dict:
    roots = scan_roots(kb_root, project)
    files = md_files(roots)
    # Note index spans the WHOLE vault (wikilinks resolve vault-wide in
    # Obsidian), not just the scanned subtree.
    all_md = md_files([kb_root])
    note_index = build_note_index(all_md)
    fuzzy_index = build_fuzzy_index(all_md)

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
                if wikilink_resolves_as_written(target, kb_root, note_index):
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
                # Build BOTH candidate resolutions: relative to the source
                # file's directory, and relative to the vault root.
                cand_rel = (path.parent / pointer_target).resolve()
                cand_root = (kb_root / pointer_target).resolve()
                # In-KB target: either candidate is a real file contained under
                # the vault → this is the resolved pointer; do the heading check.
                target_path: Optional[Path] = None
                for c in (cand_rel, cand_root):
                    if is_contained(c, kb_root) and c.is_file():
                        target_path = c
                        break
                if target_path is None:
                    # Not an in-KB file. Split the not-found case:
                    #   - resolves to a REAL file OUT of vault containment (a
                    #     `../`-escape to a real note) → still a false-clean trap
                    #     → flag (preserves the X5 escaping-refs lock);
                    #   - resolves to NO file at any candidate (out-of-scope
                    #     cross-repo reference, e.g. `skills/...md`, or simply
                    #     unresolvable) → skip, NOT a finding (f).
                    if cand_rel.is_file() or cand_root.is_file():
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

    return {"scanned": len(files), "findings": findings}


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

    print(json.dumps(report, indent=2))
    return 1 if report["findings"] else 0


if __name__ == "__main__":
    sys.exit(main())
