"""Shared helpers + per-rule golden/expected dicts for R-rule cluster smoke pins.

Heredoc-isolation architecture (PR-D §3.0a iter2): each smoke pin's heredoc spawns its own
Python interpreter, so pin-local helpers are invisible across pins. This module is the single
source of truth, imported by every R-rule pin heredoc via `from smoke_rule_helpers import ...`.

Importers must arrange `sys.path.insert(0, "tests")` (or run with cwd at the plugin root and
add `tests` to PYTHONPATH) before importing — the existing pin heredocs already `cd` to the
plugin root before invoking python3. The fixture is therefore: every pin heredoc starts with
`import sys; sys.path.insert(0, "tests")` then `from smoke_rule_helpers import ...`.
"""
import re

# ----- per-rule expected-metadata single source of truth -----

# Per-rule golden table consumed by `check_r_rules_taxonomy_schema`'s assertion (j)
# (schema-validator). Tuple shape `(category, applies_to_list, enforced_by_list)`.
R_RULE_GOLDEN_TABLE = {
    "R1":  ("quality",  ["all"],     ["spec-compliance-checker"]),
    "R2":  ("quality",  ["all"],     ["spec-compliance-checker"]),
    "R3":  ("quality",  ["all"],     ["spec-compliance-checker"]),
    "R5":  ("quality",  ["all"],     ["none"]),
    "R6":  ("quality",  ["all"],     ["none"]),
    "R7":  ("quality",  ["all"],     ["none"]),
    "R8":  ("process",  ["all"],     ["spec-compliance-checker"]),
    "R9":  ("security", ["backend"], ["cross-auditor:security"]),
    "R10": ("security", ["backend"], ["cross-auditor:security"]),
    "R11": ("security", ["all"],     ["cross-auditor:security"]),  # PR-D Step 3 — was [backend]
    "R12": ("security", ["backend"], ["cross-auditor:security"]),
    "R13": ("security", ["all"],     ["cross-auditor:security"]),  # PR-D Step 4 — was [backend]
    "R14": ("security", ["backend"], ["cross-auditor:security"]),
    "R16": ("quality",  ["all"],     ["none"]),
}

# Per-rule expected applies_to list consumed by `check_security_cluster_rules_present`'s
# assertion (b) refactor — replaces the uniform `!= ["backend"]` check that pre-existed
# at smoke-helpers.sh:4062-4067.
R_RULE_CLUSTER_EXPECTED_APPLIES = {
    "R9":  ["backend"],
    "R10": ["backend"],
    "R11": ["all"],      # PR-D Step 3 — was [backend]
    "R12": ["backend"],
    "R13": ["all"],      # PR-D Step 4 — was [backend]
    "R14": ["backend"],
}

# ----- text extraction helpers -----

def extract_section(text, rid):
    """Return the substring of `text` from `## <rid> — ` heading through the next `^---$`
    divider line (inclusive). Returns None if heading missing."""
    pat = re.compile(r"(?m)^## " + re.escape(rid) + r" — ")
    m_h = pat.search(text)
    if not m_h:
        return None
    start = m_h.start()
    div_pat = re.compile(r"(?m)^---$")
    m_d = div_pat.search(text, m_h.end())
    if not m_d:
        return text[start:]
    return text[start:m_d.end()]


def extract_block_after(section, marker):
    """Return text from `marker` through the next `^---$` divider (exclusive). Used for
    Good code block extraction."""
    if section is None:
        return ""
    idx = section.find(marker)
    if idx == -1:
        return ""
    rest = section[idx:]
    m_d = re.search(r"(?m)^---$", rest)
    if not m_d:
        return rest
    return rest[:m_d.start()]


def good_block(text, rid):
    """Return the Good-code block of rule `rid` from full markdown `text`."""
    return extract_block_after(extract_section(text, rid), "**Good code**")


def bad_block(text, rid):
    """Return the Bad-code block of rule `rid` (text from `**Bad code**` marker through
    the next `**Good code**` marker; if no Good marker, through the next `^---$` divider)."""
    sec = extract_section(text, rid)
    if sec is None:
        return ""
    idx = sec.find("**Bad code**")
    if idx == -1:
        return ""
    rest = sec[idx:]
    g_idx = rest.find("**Good code**")
    if g_idx != -1:
        return rest[:g_idx]
    m_d = re.search(r"(?m)^---$", rest)
    if not m_d:
        return rest
    return rest[:m_d.start()]


def iter_fences(block, lang):
    """Yield each ```<lang> fenced sub-block's body (without the fence markers).

    `block` is a string (e.g. the return of good_block(text, rid)); `lang` is the fence
    info string ("python", "yaml", "javascript"). Returns an iterator of strings — one
    per matching fence."""
    pattern = re.compile(
        r'^```' + re.escape(lang) + r'\s*\n(.*?)\n```\s*$',
        re.DOTALL | re.MULTILINE,
    )
    for m in pattern.finditer(block):
        yield m.group(1)
