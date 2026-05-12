#!/usr/bin/env python3
"""Scan ai-dev-team source files for `<file>.md` §<heading> pointers and
report each pointer where the named heading does not resolve in the target
file. Closes the pointer-rot defect class surfaced by PR-92 retroactive
audit (X1, X2, X3, X4, X5, X7, X8) — same shape as the WAP-hardening
"silent N/A" anti-pattern but on the documentation-navigation surface.

Scan set: agents/cross-auditor.md + agents/references/*.md + every
skills/*/SKILL.md. The scan widens with new skills automatically.

Pointer extraction: matches ``<repo-relative-path>.md` §<heading>``
followed by any of the canonical anchor terminators (backtick, double-
quote, open-paren, close-paren followed by punctuation, sentence-ending
punctuation, em-dash, or end-of-line).

Heading normalization (case-insensitive comparison):
- strip all backticks (handles `### `spec` mode` form)
- strip leading/trailing whitespace
- strip trailing punctuation (:.,;)
- lowercase

Match modes:
- exact: normalized anchor equals normalized heading text
- prefix: normalized heading starts with anchor followed by `:` / ` — `
  / ` - ` / ` (` (handles `## Step 0.5: Probe dispatch (...)` resolving
  to anchor `Step 0.5`)

Exit 0 with no output when all pointers resolve.
Exit 1 with one diagnostic line per dangling pointer.

CLI:
    python3 tests/check_dangling_anchors.py [--baseline <int>]

When --baseline is given, exit 0 iff dangling-count ≤ baseline AND every
dangling pointer matches the known-residue allowlist below. Anything beyond
the allowlist (a NEW dangling pointer) exits 1 even if total count is
under baseline. This protects against future regressions while letting
the known residue ride until the follow-up doc-cleanup spec lands.
"""
from __future__ import annotations

import argparse
import glob
import re
import sys
from pathlib import Path
from typing import List, Tuple


# Files to scan for pointers.
def scan_targets() -> List[Path]:
    targets: List[Path] = [Path("agents/cross-auditor.md")]
    targets.extend(sorted(Path(p) for p in glob.glob("agents/references/*.md")))
    targets.extend(sorted(Path(p) for p in glob.glob("skills/*/SKILL.md")))
    return [t for t in targets if t.is_file()]


# Pointer extraction: matches `<file>.md` followed by whitespace and §<rest>.
POINTER_RE = re.compile(
    r"`(?P<file>[a-zA-Z0-9/_.-]+\.md)`\s+§(?P<rest>[^\n]+)"
)

# Anchor terminator: any of (backtick, double-quote-preceded-by-whitespace,
# whitespace+open-paren, em-dash, sentence-ending punct followed by space
# or end-of-line, close-paren followed by punct or whitespace).
TERM_RE = re.compile(
    r"(`|\s+\"|\s+\(|\s+—|\s+\+\s|\)\s|\)\.|\)\:|\)$|\.\s|,\s|;\s|:\s|§|\.$|,$|;$)"
)

# Markdown heading: ##, ###, #### with text. Anchored at line start
# (multiline mode against the joined file text).
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)


# Known-residue allowlist (8 dangling pointers we deliberately defer to
# follow-up spec `2026-05-13-pointer-integrity-doc-cleanup`). Each entry is
# (source_file, anchor_text_normalized) so a stale allowlist row that no
# longer triggers gets surfaced as "stale residue entry" — the inverse
# regression of the dangling-pointer class.
KNOWN_RESIDUE = {
    # SKILL.md → cross-auditor.md (7 sites, 6 distinct lines; L531 has 2
    # occurrences of §YAML-safety serialization rule for blocker strings).
    ("skills/feature/SKILL.md", "spec mode"),
    ("skills/feature/SKILL.md", "when to set"),
    ("skills/feature/SKILL.md", "when to set for the cross-auditor's binary emit allowlist"),
    ("skills/feature/SKILL.md", "yaml-safety serialization rule for blocker strings"),
    ("skills/feature/SKILL.md", "r-rule cluster gate"),
    # output-format.md → mode-focus.md (2 sites — §R-rule cluster gate moved
    # nowhere; mode-focus.md never anchored the cluster-gate prose body).
    ("agents/references/cross-auditor-output-format.md", "r-rule cluster gate"),
    ("agents/references/cross-auditor-output-format.md", "r-rule cluster gate fires"),
    # cross-auditor.md → reference files (2 dangling, L117 §security mode
    # bridge resolved by reverse-prefix match against §security mode heading).
    ("agents/cross-auditor.md", "pr_files build"),
    ("agents/cross-auditor.md", "codex prompt templates"),
    # codex-dispatch.md → output-format.md (1).
    ("agents/references/cross-auditor-codex-dispatch.md", "findings-doc emit contract template"),
    # pr-and-probes.md → step-3-pipeline.md (1 anchor, 2 occurrences).
    ("agents/references/cross-auditor-pr-and-probes.md", "step 3 stage 4.5"),
}


def normalize(text: str) -> str:
    """Normalize heading or anchor text for comparison.

    Removes formatting/punctuation that doesn't carry semantic weight in
    a section-pointer-to-heading match: backticks (handles inline-code
    in headings like inline-backticked ``spec`` mode), all colons
    (separator between identifier prefix and title, e.g. Step 0.5: Probe
    dispatch), trailing close-paren, trailing punct dot/comma/semicolon.
    Collapses runs of whitespace.
    """
    text = text.replace("`", "")
    text = text.replace(":", " ")
    # Section-numbering convention: '5. Implementation' → '5 Implementation'
    # so anchor `§5` matches heading `## 5. Implementation`.
    text = re.sub(r"(\d)\.\s", r"\1 ", text)
    text = text.strip()
    text = text.rstrip(":.,;)+")
    text = re.sub(r"\s+", " ", text)
    return text.lower()


def trim_anchor(rest: str) -> str:
    """Trim §<rest> at the first canonical terminator."""
    m = TERM_RE.search(rest)
    if m:
        rest = rest[: m.start()]
    return rest.strip()


def headings_in(path: Path) -> List[Tuple[int, str]]:
    """Return (line_number, raw_heading_text) for each Markdown heading."""
    if not path.is_file():
        return []
    text = path.read_text(encoding="utf-8")
    result = []
    for line_num, line in enumerate(text.splitlines(), 1):
        m = HEADING_RE.match(line)
        if m:
            result.append((line_num, m.group(2)))
    return result


def anchor_resolves(anchor: str, headings: List[Tuple[int, str]]) -> bool:
    """Check anchor matches some heading via exact, prefix, or reverse-prefix match.

    - Exact: normalized anchor equals normalized heading.
    - Prefix (anchor shorter than heading): heading starts with anchor + word boundary —
      handles `§Step 0.5` resolving to `## Step 0.5 Probe dispatch (...)` (colon
      stripped to space via normalize).
    - Reverse-prefix (anchor over-describes heading): anchor starts with heading +
      word boundary — handles `§Mode Focus Areas for the canonical per-mode list`
      resolving to `## Mode Focus Areas`. Common when a pointer author appends a
      descriptor phrase to the bare heading anchor.
    """
    n_anchor = normalize(anchor)
    if not n_anchor:
        return True  # empty anchor — treat as non-match-but-not-dangling
    for _, raw in headings:
        n_head = normalize(raw)
        if n_head == n_anchor:
            return True
        if n_head.startswith(n_anchor) and len(n_head) > len(n_anchor) and n_head[len(n_anchor)] == " ":
            return True
        if n_anchor.startswith(n_head) and len(n_anchor) > len(n_head) and n_anchor[len(n_head)] == " ":
            return True
    return False


def resolve_target(source: Path, target: str) -> Path:
    """Resolve target path. Pointers may be repo-relative (canonical) or
    skill-relative (e.g. `references/spec-template.md` inside a SKILL.md).
    Try repo-root first; fall back to <source-dir>/<target>."""
    p = Path(target)
    if p.is_file():
        return p
    sibling = source.parent / target
    if sibling.is_file():
        return sibling
    return p  # return repo-relative form for the dangling diagnostic


def main(argv: List[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--baseline",
        type=int,
        default=None,
        help="Maximum allowed dangling count. With known-residue allowlist, "
        "exit 0 iff every dangling matches the allowlist AND total ≤ baseline.",
    )
    args = parser.parse_args(argv)

    dangling: List[Tuple[str, int, str, str]] = []  # (src_file, line, target_file, anchor)
    for source in scan_targets():
        text = source.read_text(encoding="utf-8")
        for line_num, line in enumerate(text.splitlines(), 1):
            for m in POINTER_RE.finditer(line):
                target = m.group("file")
                anchor = trim_anchor(m.group("rest"))
                if not anchor:
                    continue
                target_path = resolve_target(source, target)
                heads = headings_in(target_path)
                if not target_path.is_file():
                    dangling.append((str(source), line_num, target, anchor))
                    continue
                if not anchor_resolves(anchor, heads):
                    dangling.append((str(source), line_num, target, anchor))

    # Report shape.
    new_dangling = []
    residue_hits = set()
    for src, line, target, anchor in dangling:
        n = normalize(anchor)
        if (src, n) in KNOWN_RESIDUE:
            residue_hits.add((src, n))
            continue
        new_dangling.append((src, line, target, anchor))

    # Emit all dangling for diagnostic visibility.
    for src, line, target, anchor in dangling:
        n = normalize(anchor)
        marker = "RESIDUE" if (src, n) in KNOWN_RESIDUE else "DANGLING"
        print(f"{marker} {src}:{line}: §{anchor!r} → {target} (no matching heading)")

    # Stale-allowlist surface: residue entry that did not appear in this run.
    stale = KNOWN_RESIDUE - residue_hits
    for src, n in sorted(stale):
        print(f"STALE-RESIDUE-ENTRY {src}: §{n!r} listed in KNOWN_RESIDUE but no longer triggers — remove from allowlist")

    if args.baseline is not None:
        if new_dangling:
            print(f"FAIL: {len(new_dangling)} NEW dangling pointer(s) beyond known residue", file=sys.stderr)
            return 1
        if stale:
            print(f"FAIL: {len(stale)} STALE residue entry/entries — KNOWN_RESIDUE drift", file=sys.stderr)
            return 1
        if len(dangling) > args.baseline:
            print(f"FAIL: dangling count {len(dangling)} exceeds baseline {args.baseline}", file=sys.stderr)
            return 1
        return 0

    return 1 if dangling else 0


if __name__ == "__main__":
    sys.exit(main())
