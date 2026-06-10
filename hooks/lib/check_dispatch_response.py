#!/usr/bin/env python3
"""Cross-auditor return-contract classifier (runtime helper).

Reads the raw cross-auditor response (spec mode: inline-return text captured
to a file via `--raw-response-file`; code/full mode: same plus `--findings-path`
for the on-disk findings.md) and classifies it into one of 12 enum values.
JSON output to stdout; diagnostic to stderr.

The helper is mode-neutral and all-project: it never blocks. The ai-dev-team
project-policy gate (CLEAN_SINGLE -> STOP-and-DISCUSS) is surfaced as the
`policy_gate` JSON flag ONLY when `--project ai-dev-team` is passed; the
orchestrator prose (SKILL.md §3.4a) enforces the banner.

This helper is consumed by BOTH the SKILL.md recovery callsites AND the smoke
pin `dispatch-response-classifier-fixtures`, closing test/runtime drift.

12-enum classification (per spec 2026-05-15-cross-auditor-contract-gate-automation §3.3.1):
  CLEAN_DUAL                          exit 0
  CLEAN_SINGLE                        exit 0
  MISSING_FOOTER                      exit 1  (spec only)
  MALFORMED_FOOTER_EVIDENCE_CLASS     exit 1  (spec only)
  MALFORMED_FOOTER_EVIDENCE_BLOCKERS  exit 1  (spec only)
  FINDINGS_MISSING                    exit 1  (code only)
  FINDINGS_MALFORMED                  exit 1  (code only)
  BLOCKER_YAML_UNSAFE_APOSTROPHE      exit 1
  BLOCKER_YAML_UNSAFE_NEWLINE         exit 1
  EVIDENCE_CLASS_DISALLOWED           exit 1
  DUAL_MODEL_WITH_BLOCKERS            exit 1
  SINGLE_MODEL_WITHOUT_BLOCKERS       exit 1

Exit codes (load-bearing — the SKILL.md recovery prose branches on these):
  0 — CLEAN_DUAL or CLEAN_SINGLE (any clean classification, regardless of policy_gate)
  1 — any violation (the 10 enum values 3-12)
  2 — classifier's own crash (usage error, file IO error, marshalling error).
      Stderr carries the diagnostic; stdout is empty.

CLI:
  hooks/lib/check_dispatch_response.py
      --mode spec|code|full
      --raw-response-file <path>
      --audit-slug <slug>
      --iteration <N>
      [--findings-path <path>]   # required for code|full; ignored for spec
      [--project <project>]      # optional; `ai-dev-team` activates policy_gate
      [--expected-claude-model <prefix>]  # optional; activates model_gate on
                                          # CLEAN_* responses (model attestation)
      [--debug]                  # on exit 2, emit full Python traceback to stderr

The JSON output additionally carries the model-attestation fields (additive,
never removed): `claude_model` (string|null — the attested Claude model ID,
informational even without the flag) and `model_gate`
(null|MODEL_DEGRADED|MODEL_ATTESTATION_MISSING — set only when
`--expected-claude-model` is passed and the response is CLEAN_*).
"""

import argparse
import json
import re
import sys

# Canonical spaced EVIDENCE FOOTER sentinel literal. This is the single
# producer-side authoritative form per agents/references/
# cross-auditor-evidence-handshake.md — the parser asserts byte-exact
# full-line equality against it.
SENTINEL = "# CROSS-AUDIT EVIDENCE FOOTER"

ALLOWED_EVIDENCE_CLASSES = ("dual_model", "single_model")

# --- Code-mode frontmatter evidence-key recognizer (structural validation) ---
#
# `classify_code` validates the leading frontmatter block as a WHOLE for
# evidence-key well-formedness, rather than scanning line-by-line for the
# exact canonical prefix. Two regexes drive that whole-block validation:
#
#   EVIDENCE_KEY_ATTEMPT_RE — deliberately PERMISSIVE recognizer. It matches
#     any line a reasonable reader would recognize as an *attempt* at an
#     `evidence_class` / `evidence_blockers` key in ANY shape: canonical
#     (`evidence_class: value`), no-space (`evidence_class:value`),
#     tab-after-colon, `=` instead of `:`, hyphen-vs-underscore key spelling,
#     leading whitespace, case variants. The goal is to DETECT a malformed
#     attempt, never to silently skip it. Only the boolean match result is
#     used — the validator does not need to bucket an attempt by which key
#     it was reaching for, so the recognized key spelling is not extracted.
#
#   EVIDENCE_KEY_CANONICAL_RE — STRICT canonical form: line start, the exact
#     lower-case underscore key, a colon, exactly one space, then the value.
#     This is the only shape `awk '/^---$/{c++;next} c==1' | grep -E
#     '^(evidence_class|evidence_blockers): '` (the §2.2 consumer contract)
#     accepts.
#
# Whole-block rule (subsumes X9 + X11 + X14): for each of the two keys,
# require EXACTLY ONE line matching the canonical regex AND ZERO lines that
# match the permissive recognizer but not the canonical regex. Any malformed
# attempt — even one coexisting with a valid canonical line — routes the
# whole findings.md to FINDINGS_MALFORMED. A line-scan loop matching exact
# prefixes could only ever be tightened one missed shape at a time; the
# permissive recognizer closes the asymmetry class structurally.
EVIDENCE_KEY_ATTEMPT_RE = re.compile(
    r"^[ \t]*(evidence[_-]?class|evidence[_-]?blockers)[ \t]*[:=]",
    re.IGNORECASE,
)
EVIDENCE_KEY_CANONICAL_RE = re.compile(
    r"^(evidence_class|evidence_blockers): ",
)

# --- Model-attestation recognizer (§3.1 strict, mirrors the evidence-key
# recognizer pair) ---
#
# The cross-auditor echoes its actual Claude model ID in a `claude_model:`
# line (spec mode: the line immediately preceding the EVIDENCE FOOTER
# sentinel; code/full mode: a key in the leading findings.md frontmatter).
# Parse is strict and per-channel — anything but the exact canonical shape
# with a non-empty value yields claimed = None (no fuzzy recovery), the same
# strictness philosophy as the evidence-key validation above.
#
#   CLAUDE_MODEL_ATTEMPT_RE — PERMISSIVE recognizer: matches any line a
#     reasonable reader would recognize as an *attempt* at the key in ANY
#     shape (`claude_model:x` no-space, `claude_model =`, hyphen/case
#     variants, leading whitespace). Used in code/full mode to DETECT a
#     malformed attempt coexisting with a valid canonical line.
#   CLAUDE_MODEL_CANONICAL_RE — STRICT canonical form: line start, the exact
#     lower-case underscore key, a colon, exactly one space.
CLAUDE_MODEL_ATTEMPT_RE = re.compile(
    r"^[ \t]*claude[_-]?model[ \t]*[:=]",
    re.IGNORECASE,
)
CLAUDE_MODEL_CANONICAL_RE = re.compile(
    r"^claude_model: ",
)


def _parse_claude_model_spec(lines, sentinel_idx):
    """Parse the spec-mode `claude_model:` attestation (§3.1 strict).

    The attestation is the ONE physical line immediately preceding the
    EVIDENCE FOOTER sentinel. Reads `lines[sentinel_idx - 1]` ONLY when
    `sentinel_idx >= 1` (the `>= 1` guard avoids the Python negative-index
    wrap at `sentinel_idx == 0`, which would otherwise read the LAST line of
    the response as the attestation). The line counts as an attestation iff
    it matches the canonical `claude_model: ` prefix AND the value after the
    prefix (stripped) is non-empty. Anything else — absent line, malformed
    key, empty value — returns None. No fuzzy recovery.
    """
    if sentinel_idx < 1:
        return None
    line = lines[sentinel_idx - 1]
    if not CLAUDE_MODEL_CANONICAL_RE.match(line):
        return None
    value = line[len("claude_model: "):].strip()
    if value == "":
        return None
    return value


def _parse_claude_model_code(fm_lines, skip_lines):
    """Parse the code/full-mode `claude_model:` attestation (§3.1 strict).

    Mirrors `_validate_evidence_keys`: scans EVERY non-continuation line of
    the leading frontmatter. Requires EXACTLY ONE canonical `claude_model: `
    line and ZERO malformed attempts (a permissive-recognizer match without a
    canonical match — no-space, `=`, hyphen/case variant). Zero canonical
    lines, duplicate canonical lines, any malformed attempt (even one
    coexisting with a valid canonical line), or an empty value → None.
    """
    canonical_count = 0
    malformed_seen = False
    value = None
    for idx, ln in enumerate(fm_lines):
        if idx in skip_lines:
            continue
        if not CLAUDE_MODEL_ATTEMPT_RE.match(ln):
            continue
        if CLAUDE_MODEL_CANONICAL_RE.match(ln):
            canonical_count += 1
            value = ln[len("claude_model: "):].strip()
        else:
            malformed_seen = True
    if malformed_seen or canonical_count != 1:
        return None
    if value == "":
        return None
    return value


def _validate_evidence_keys(fm_lines, skip_lines):
    """Whole-block evidence-key well-formedness check for code-mode frontmatter.

    `fm_lines` is the list of frontmatter lines; `skip_lines` is the set of
    indices that are physical continuation lines of a newline-split
    `evidence_blockers` value (already consumed by `_gather_blockers_value`)
    and MUST NOT be inspected as keys — a continuation line that happens to
    begin with `evidence_class`/`evidence_blockers` blocker text is value
    content, not a key.

    Scans EVERY non-continuation line. A line matching the permissive
    `EVIDENCE_KEY_ATTEMPT_RE` is an *attempt* at one of the two evidence
    keys. If it does NOT also match the strict `EVIDENCE_KEY_CANONICAL_RE`
    it is a malformed attempt (no-space, tab-after-colon, `=`, hyphen key,
    leading whitespace, case variant, ...) — regardless of whether a valid
    canonical line for the same key also exists.

    Returns True iff the block is well-formed: for EACH of the two keys
    exactly one canonical line and zero malformed attempts. Returns False
    on any malformed attempt or any count != 1 (subsumes X9 malformed-as-
    sole-line, X11 duplicate-canonical, X14 malformed-coexisting-with-valid).
    """
    canonical_counts = {"evidence_class": 0, "evidence_blockers": 0}
    malformed_seen = False
    for idx, ln in enumerate(fm_lines):
        if idx in skip_lines:
            continue
        m = EVIDENCE_KEY_ATTEMPT_RE.match(ln)
        if not m:
            continue
        # This line is attempting an evidence key in some shape.
        if EVIDENCE_KEY_CANONICAL_RE.match(ln):
            # Strict canonical form — the regex's group 1 is already the
            # canonical key spelling here, so no normalization is needed.
            key = ln.split(":", 1)[0]
            canonical_counts[key] += 1
        else:
            # Recognized as an evidence-key attempt but NOT in canonical
            # form — a malformed key. Reject the whole block.
            malformed_seen = True
    if malformed_seen:
        return False
    return (canonical_counts["evidence_class"] == 1
            and canonical_counts["evidence_blockers"] == 1)

# Canonical enum -> violation-blocker phrasing. For every non-clean
# classification this is the string the orchestrator records in
# `*_audit_blockers` when the outcome is `contract_violated` (see
# skills/feature/SKILL.md §3.5b Contract-violation rule + §3.5b-2b
# retry-outcome matrix). The clean classifications (CLEAN_DUAL / CLEAN_SINGLE)
# have no violation blocker — the JSON `violation_blocker` field is null for
# them and the orchestrator uses `blockers_yaml` instead (the clean path).
# Three entries carry a templated slot the classifier fills in `run()`:
#   FINDINGS_MISSING          -> `<path>`  (resolved findings path)
#   EVIDENCE_CLASS_DISALLOWED -> `<value>` (sanitized offending evidence_class)
#   DUAL_MODEL_WITH_BLOCKERS  -> `<value>` (the offending blockers_yaml literal)
# The two `<value>` slots satisfy SKILL.md §3.5b's mandate that the
# disallowed-class and dual_model+blockers phrasings embed the offending
# value (sanitized) for post-mortem diagnostics.
VIOLATION_BLOCKERS = {
    "MISSING_FOOTER":
        "cross-auditor return missing evidence_class footer line",
    "MALFORMED_FOOTER_EVIDENCE_CLASS":
        "cross-auditor return malformed evidence_class footer",
    "MALFORMED_FOOTER_EVIDENCE_BLOCKERS":
        "cross-auditor return malformed evidence_blockers footer",
    "FINDINGS_MISSING":
        "findings.md missing at <path>",
    "FINDINGS_MALFORMED":
        "cross-auditor findings.md frontmatter malformed",
    "BLOCKER_YAML_UNSAFE_APOSTROPHE":
        "evidence_blockers entry failed YAML-safety validation: "
        "unescaped apostrophe",
    "BLOCKER_YAML_UNSAFE_NEWLINE":
        "evidence_blockers entry failed YAML-safety validation: "
        "embedded newline",
    "EVIDENCE_CLASS_DISALLOWED":
        "cross-auditor emitted disallowed evidence_class value: <value>",
    "DUAL_MODEL_WITH_BLOCKERS":
        "cross-auditor emitted dual_model with non-empty "
        "evidence_blockers: <value>",
    "SINGLE_MODEL_WITHOUT_BLOCKERS":
        "cross-auditor emitted single_model with empty evidence_blockers",
}


class ClassifierCrash(Exception):
    """Raised for the classifier's own failure (usage / IO / marshalling).

    Mapped to exit code 2 — distinct from a contract violation (exit 1).
    """


def _parse_blockers_literal(value):
    """Parse a YAML-list-literal blockers value into a list of raw strings.

    `value` is the text after `evidence_blockers: ` — expected to be a
    bracketed list literal, e.g. `[]` or `['a', 'b']`. Returns the list of
    inner string scalars with the surrounding single quotes stripped but NO
    un-escaping applied (the caller inspects raw content for YAML-safety).

    The cross-auditor's YAML-safety serialization contract (spec §2.5;
    `agents/references/cross-auditor-evidence-handshake.md`) requires every
    list item to be in **single-quoted YAML scalar form**. A list literal is
    valid ONLY if it is `[]` or a comma-separated sequence of single-quoted
    scalars. A bare/unquoted scalar item (`[codex unavailable: timeout]`), a
    double-quoted item (`["double quoted"]`), an empty item, or a mapping is
    rejected — `ok=False` — so the gate routes the response to the
    MALFORMED enum rather than green-lighting a non-contract-form literal.

    Returns (list_of_raw_items, ok) where ok is False on unparseable shape.
    """
    text = value.strip()
    if not text.startswith("[") or not text.endswith("]"):
        return [], False
    inner = text[1:-1].strip()
    if inner == "":
        return [], True
    items = []
    i = 0
    n = len(inner)
    while i < n:
        while i < n and inner[i] in " \t":
            i += 1
        if i >= n:
            # trailing comma / whitespace with no item — malformed
            return [], False
        if inner[i] != "'":
            # The contract requires single-quoted scalars only. A bare or
            # double-quoted item starting here is a non-contract-form list
            # literal — reject it (X5: bracketed-bad-items hole).
            return [], False
        # single-quoted scalar — scan to closing quote, honoring '' escape
        i += 1
        buf = []
        closed = False
        while i < n:
            if inner[i] == "'":
                if i + 1 < n and inner[i + 1] == "'":
                    buf.append("'")
                    i += 2
                    continue
                closed = True
                i += 1  # skip closing quote
                break
            buf.append(inner[i])
            i += 1
        if not closed:
            # ran off the end without a closing quote — malformed
            return [], False
        items.append("".join(buf))
        # after a closed scalar only whitespace then a comma (or end) is valid
        while i < n and inner[i] in " \t":
            i += 1
        if i >= n:
            break
        if inner[i] != ",":
            # trailing junk after the closing quote — malformed
            return [], False
        i += 1  # skip the comma
    return items, True


def _bracket_depth_delta(text, depth=0, in_quote=False):
    """Net `[`/`]` depth change of `text`, counting brackets ONLY outside
    single-quoted scalars.

    Shared quote-aware flow-sequence scanner — the SAME single-quote state
    machine `_parse_blockers_literal` / `_scan_blocker_safety` use, so all
    three helpers agree on what counts as structural. A `[` or `]` that
    appears INSIDE a single-quoted YAML scalar (honoring the `''` doubled
    escape) is human-readable blocker text, NOT a list delimiter, and must
    not move the depth (X10: a literal `[` in a blocker scalar formerly
    tricked the naive `count()` into joining the next frontmatter line).

    `depth` / `in_quote` carry the running state from a prior physical line
    so a single-quoted scalar that legitimately spans a physical newline
    (the BLOCKER_YAML_UNSAFE_NEWLINE defect) keeps a `[` or `]` on the
    continuation line correctly suppressed when it falls inside the still-
    open quote span (X10 inverse: a `]` inside a newline-split scalar must
    not balance the literal early and miss the real defect).

    Returns (depth, in_quote) — the updated running state.
    """
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if in_quote:
            if ch == "'":
                if i + 1 < n and text[i + 1] == "'":
                    i += 2  # `''` escaped apostrophe — stays inside the span
                    continue
                in_quote = False
                i += 1
                continue
            i += 1
            continue
        if ch == "'":
            in_quote = True
            i += 1
            continue
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
        i += 1
    return depth, in_quote


def _gather_blockers_value(lines, start_idx):
    """Reconstruct the `evidence_blockers:` value, joining physical lines.

    `lines[start_idx]` is the `evidence_blockers: ...` line; its bracketed
    list literal MAY have been split across a physical newline (the
    BLOCKER_YAML_UNSAFE_NEWLINE defect). This helper joins continuation
    lines until the `[` bracket balances (or input is exhausted).

    Bracket balancing is **quote-aware** (`_bracket_depth_delta`): a `[` or
    `]` inside a single-quoted scalar is blocker text, not a delimiter, so a
    legitimate single-line blocker whose human-readable text contains a
    literal bracket is NOT mistaken for an unbalanced multi-line literal
    (X10).

    Returns (joined_value, spanned_lines) where `joined_value` is the text
    after `evidence_blockers: ` with embedded newlines preserved as `\\n`
    and `spanned_lines` is the count of physical lines the value occupied
    (1 = well-formed single-line literal; >1 = physical-newline defect).
    """
    first = lines[start_idx].split(":", 1)[1] if ":" in lines[start_idx] \
        else lines[start_idx]
    value = first.lstrip()
    spanned = 1
    # Balance brackets on the first line — quote-aware (X10). The `in_quote`
    # state is carried across continuation joins so a quoted scalar split by
    # a physical newline keeps later brackets correctly suppressed.
    depth, in_quote = _bracket_depth_delta(value)
    idx = start_idx + 1
    while depth > 0 and idx < len(lines):
        cont = lines[idx]
        value = value + "\n" + cont
        # A newline inside an open quote span is itself the structure
        # `_scan_blocker_safety` flags as unsafe_newline — `'\n'` re-opens
        # nothing; the quote span simply continues across the join.
        depth, in_quote = _bracket_depth_delta(cont, depth, in_quote)
        spanned += 1
        idx += 1
    return value, spanned


def _scan_blocker_safety(raw_value):
    """Inspect the raw blockers literal text for YAML-safety violations.

    Returns one of: "ok", "unsafe_newline", "unsafe_apostrophe".
    Operates on the raw literal text (pre-parse) because an unescaped
    apostrophe is detectable only in the raw single-quoted form.
    """
    # Physical newline anywhere inside the list literal is unsafe — the
    # canonical YAML-safety rule (§2.5) requires newline->space before emit.
    if "\n" in raw_value or "\r" in raw_value:
        return "unsafe_newline"
    text = raw_value.strip()
    if not text.startswith("[") or not text.endswith("]"):
        return "ok"
    inner = text[1:-1]
    # Walk single-quoted scalars; a lone `'` inside a scalar (not part of a
    # `''` escape pair and not the closing quote) is an unescaped apostrophe.
    i = 0
    n = len(inner)
    while i < n:
        if inner[i] != "'":
            i += 1
            continue
        # opening quote of a scalar
        i += 1
        while i < n:
            if inner[i] == "'":
                if i + 1 < n and inner[i + 1] == "'":
                    i += 2  # escaped apostrophe
                    continue
                # closing quote — but if followed by non-delimiter text,
                # this scalar held an unescaped apostrophe mid-content.
                j = i + 1
                while j < n and inner[j] in " \t":
                    j += 1
                if j < n and inner[j] not in ",]":
                    return "unsafe_apostrophe"
                i += 1
                break
            i += 1
        else:
            # ran off the end without a closing quote
            return "unsafe_apostrophe"
    return "ok"


def sanitize_blocker(text):
    """Canonical YAML-safety sanitizer per spec §2.5 / handshake doc §22-25.

    Load-bearing order: newline-strip -> truncate-to-199(+ellipsis)
    -> escape-quotes ('->'') -> (caller emits single-quoted YAML form).
    """
    # 1. Replace newlines with a single space.
    s = text.replace("\r\n", " ").replace("\r", " ").replace("\n", " ")
    # 2. Truncate to 199 chars on the human-meaningful prefix; append ellipsis.
    if len(s) > 199:
        s = s[:199] + "…"
    # 3. Escape single quotes by doubling.
    s = s.replace("'", "''")
    return s


def _emit_blockers_yaml(items):
    """Render a list of sanitized strings as a YAML single-quoted list literal."""
    if not items:
        return "[]"
    quoted = ["'" + sanitize_blocker(item) + "'" for item in items]
    return "[" + ", ".join(quoted) + "]"


def _frontmatter_lines(text):
    """Return the lines of the leading top-of-file YAML frontmatter block.

    Per the cross-auditor contract (SKILL.md §3.5b — the two scalars are
    written "in the **leading** top-of-file YAML frontmatter block"), the
    opening `---` MUST be the first non-empty line of the file. A non-leading
    `---` block (prose-then-frontmatter) is NOT findings frontmatter and
    returns None — the caller routes that to FINDINGS_MALFORMED.

    Narrow tolerance: leading blank lines and a leading UTF-8 BOM are
    permitted before the opening `---` (editor / encoding artifacts); any
    non-blank prose line before the opening `---` rejects the block.

    Returns the lines between the opening and the next `---` delimiter, or
    None if there is no leading frontmatter block.
    """
    lines = text.splitlines()
    # Find the first non-empty line, tolerating a leading BOM.
    open_idx = None
    for i, ln in enumerate(lines):
        bare = ln.lstrip("﻿") if i == 0 else ln
        if bare.strip() == "":
            continue
        # First non-empty line: must be the opening `---` delimiter.
        if bare.rstrip() == "---":
            open_idx = i
        break
    if open_idx is None:
        return None
    # Closing `---` is the next delimiter line after the opening one.
    for j in range(open_idx + 1, len(lines)):
        if lines[j].rstrip() == "---":
            return lines[open_idx + 1 : j]
    return None


def _classify_fields(evidence_class, blockers_safety, blockers_items):
    """Apply the value/cross-field invariants common to spec + code mode.

    Returns a classification enum value. Caller has already confirmed the
    transport (footer present / findings.md present + parseable).
    """
    # YAML-safety of the blockers literal (checked before semantic invariants
    # so an unsafe scalar is never mis-reported as a cross-field violation).
    if blockers_safety == "unsafe_newline":
        return "BLOCKER_YAML_UNSAFE_NEWLINE"
    if blockers_safety == "unsafe_apostrophe":
        return "BLOCKER_YAML_UNSAFE_APOSTROPHE"
    # evidence_class must be on the binary emit allowlist.
    if evidence_class not in ALLOWED_EVIDENCE_CLASSES:
        return "EVIDENCE_CLASS_DISALLOWED"
    # Cross-field invariants.
    if evidence_class == "dual_model":
        if blockers_items:
            return "DUAL_MODEL_WITH_BLOCKERS"
        return "CLEAN_DUAL"
    # evidence_class == "single_model"
    if not blockers_items:
        return "SINGLE_MODEL_WITHOUT_BLOCKERS"
    return "CLEAN_SINGLE"


def classify_spec(raw_text):
    """Classify a spec-mode inline-return text.

    Returns (classification, evidence_class, blockers_items, blockers_yaml,
    claude_model).

    The footer is the LAST sentinel-anchored block: the sentinel line, then
    an `evidence_class: ` line, then the `evidence_blockers: ` line whose
    list literal may span >1 physical line (the newline-unsafe defect — the
    `evidence_blockers` value is the rest of the response after the
    `evidence_class:` line).

    The model attestation (`claude_model: <id>`) is the ONE line immediately
    PRECEDING the sentinel — parsed independently of the classification
    (§3.1: a malformed attestation never perturbs the 12-enum verdict). It
    is None when the sentinel is absent / not near EOF, since there is no
    anchor to read it from.
    """
    # Strip ALL trailing newlines (transport artifact).
    stripped = raw_text.rstrip("\n").rstrip("\r\n")
    lines = stripped.splitlines()
    if len(lines) < 3:
        return "MISSING_FOOTER", None, [], "[]", None
    # Anchor on the LAST occurrence of the sentinel line.
    sentinel_idx = None
    for i in range(len(lines) - 1, -1, -1):
        if lines[i] == SENTINEL:
            sentinel_idx = i
            break
    # The sentinel must be 3rd-from-EOF for a well-formed footer; a sentinel
    # further from EOF is acceptable ONLY when the extra trailing lines are
    # the continuation of a multi-line (newline-unsafe) evidence_blockers
    # value. Anything else (no sentinel, sentinel not near EOF) is missing.
    if sentinel_idx is None or sentinel_idx > len(lines) - 3:
        return "MISSING_FOOTER", None, [], "[]", None
    # Model attestation: the line immediately preceding the sentinel (§3.1
    # strict, guarded against negative-index wrap at sentinel_idx == 0). Read
    # before the footer-shape checks below so a CLEAN response with a
    # malformed footer is irrelevant — the value is captured regardless.
    claude_model = _parse_claude_model_spec(lines, sentinel_idx)
    class_line = lines[sentinel_idx + 1]
    blockers_idx = sentinel_idx + 2
    if not class_line.startswith("evidence_class: "):
        return "MALFORMED_FOOTER_EVIDENCE_CLASS", None, [], "[]", claude_model
    if not lines[blockers_idx].startswith("evidence_blockers: "):
        return ("MALFORMED_FOOTER_EVIDENCE_BLOCKERS", None, [], "[]",
                claude_model)
    evidence_class = class_line[len("evidence_class: "):].strip()
    blockers_raw, spanned = _gather_blockers_value(lines, blockers_idx)
    # A footer that is exactly 3 physical lines (spanned == 1) AND has no
    # trailing lines beyond the blockers line is the well-formed shape.
    if spanned == 1 and blockers_idx != len(lines) - 1:
        return "MISSING_FOOTER", None, [], "[]", claude_model
    blockers_safety = _scan_blocker_safety(blockers_raw)
    blockers_items, blockers_ok = _parse_blockers_literal(blockers_raw)
    # A non-list `evidence_blockers` value (bare scalar, unclosed bracket,
    # empty value) is a malformed footer — NOT a silently-empty list. The
    # newline-unsafe case still has a parseable bracketed shape, so the
    # safety scan ("unsafe_newline"/"unsafe_apostrophe") takes precedence;
    # `blockers_ok` only gates the genuinely non-list shape.
    if not blockers_ok and blockers_safety == "ok":
        return ("MALFORMED_FOOTER_EVIDENCE_BLOCKERS", evidence_class, [],
                "[]", claude_model)
    classification = _classify_fields(
        evidence_class, blockers_safety, blockers_items
    )
    blockers_yaml = _emit_blockers_yaml(blockers_items)
    return (classification, evidence_class, blockers_items, blockers_yaml,
            claude_model)


def classify_code(findings_path):
    """Classify a code/full-mode response from the on-disk findings.md.

    Returns (classification, evidence_class, blockers_items, blockers_yaml,
    claude_model).

    Code/spec-mode strictness parity: `classify_spec` reads the two scalars
    strictly positionally (`lines[sentinel_idx + 1]` / `+ 2`), so a malformed
    line right after the sentinel IS the line it reads and is rejected by the
    canonical prefix check — spec mode is frontmatter-strict by construction.
    Code mode reaches the same guarantee with `_validate_evidence_keys`, a
    WHOLE-BLOCK validator: it recognizes EVERY line attempting an evidence
    key in ANY shape (`EVIDENCE_KEY_ATTEMPT_RE`) and rejects the findings.md
    unless each key appears exactly once in strict canonical form and zero
    times in any malformed form. This structurally closes the code-mode
    frontmatter-strictness asymmetry class — it is not a per-shape patch, so
    it subsumes X9 (malformed-as-sole-line), X11 (duplicate canonical key)
    and X14 (a malformed sibling coexisting with a valid canonical line) in
    one predicate.
    """
    try:
        with open(findings_path, "r", encoding="utf-8") as fh:
            text = fh.read()
    except FileNotFoundError:
        return "FINDINGS_MISSING", None, [], "[]", None
    except OSError as exc:
        raise ClassifierCrash(
            f"cannot read findings file {findings_path}: {exc}"
        )
    fm = _frontmatter_lines(text)
    if fm is None:
        return "FINDINGS_MALFORMED", None, [], "[]", None
    # First pass: locate the canonical `evidence_blockers:` line and gather
    # its value across any physical continuation lines (a list literal split
    # by an embedded newline — the newline-unsafe defect). The continuation
    # line indices are recorded so the whole-block validator below does NOT
    # mistake a continuation line that happens to begin with evidence-key
    # text for a malformed key.
    blockers_raw = None
    skip_lines = set()
    skip_until = -1
    for idx, ln in enumerate(fm):
        if idx <= skip_until:
            continue
        if EVIDENCE_KEY_CANONICAL_RE.match(ln) \
                and ln.split(":", 1)[0] == "evidence_blockers":
            blockers_raw, spanned = _gather_blockers_value(fm, idx)
            skip_until = idx + spanned - 1
            for cont in range(idx + 1, idx + spanned):
                skip_lines.add(cont)
    # Model attestation: exactly one canonical `claude_model: ` line in the
    # leading frontmatter, zero malformed attempts (§3.1 strict). Parsed
    # independently of the classification — a malformed/duplicate/empty
    # attestation yields None but never perturbs the 12-enum verdict. The
    # continuation-line skip set is reused so a blockers value continuation
    # line that happens to begin with claude_model text is not misread.
    claude_model = _parse_claude_model_code(fm, skip_lines)
    # Whole-block evidence-key well-formedness check (structural — closes the
    # X9/X11/X14 frontmatter-strictness asymmetry class). Any malformed
    # attempt at either key, any count != 1, routes to FINDINGS_MALFORMED.
    if not _validate_evidence_keys(fm, skip_lines):
        return "FINDINGS_MALFORMED", None, [], "[]", claude_model
    # The block is well-formed: exactly one canonical line for each key.
    # Extract the `evidence_class` value from its canonical line.
    evidence_class = None
    for idx, ln in enumerate(fm):
        if idx in skip_lines:
            continue
        if EVIDENCE_KEY_CANONICAL_RE.match(ln) \
                and ln.split(":", 1)[0] == "evidence_class":
            evidence_class = ln[len("evidence_class: "):].strip()
            break
    if evidence_class is None or blockers_raw is None:
        # Unreachable given a passing _validate_evidence_keys (which requires
        # exactly one canonical line for each key), but kept as a defensive
        # invariant assertion for the value-extraction step.
        return "FINDINGS_MALFORMED", None, [], "[]", claude_model
    blockers_safety = _scan_blocker_safety(blockers_raw)
    blockers_items, blockers_ok = _parse_blockers_literal(blockers_raw)
    # A non-list `evidence_blockers` value in the findings.md frontmatter is
    # a malformed findings file — NOT a silently-empty list. As in spec mode
    # the newline-unsafe safety scan takes precedence over the shape check.
    if not blockers_ok and blockers_safety == "ok":
        return "FINDINGS_MALFORMED", evidence_class, [], "[]", claude_model
    classification = _classify_fields(
        evidence_class, blockers_safety, blockers_items
    )
    blockers_yaml = _emit_blockers_yaml(blockers_items)
    return (classification, evidence_class, blockers_items, blockers_yaml,
            claude_model)


def build_parser():
    parser = argparse.ArgumentParser(
        prog="check_dispatch_response.py",
        description="Cross-auditor return-contract classifier.",
    )
    parser.add_argument("--mode", required=True,
                        choices=["spec", "code", "full"])
    parser.add_argument("--raw-response-file", required=True)
    parser.add_argument("--audit-slug", required=True)
    parser.add_argument("--iteration", required=True, type=int)
    parser.add_argument("--findings-path", default=None)
    parser.add_argument("--project", default=None)
    parser.add_argument("--expected-claude-model", default=None,
                        help="when set, validate the parsed claude_model "
                             "attestation against this prefix on CLEAN_* "
                             "responses; mismatch -> model_gate")
    parser.add_argument("--debug", action="store_true",
                        help="on exit 2 (classifier crash), emit full "
                             "Python traceback to stderr")
    return parser


def run(args):
    """Core classification — raises ClassifierCrash for exit-2 conditions."""
    # Read the raw response file.
    try:
        with open(args.raw_response_file, "r", encoding="utf-8") as fh:
            raw_text = fh.read()
    except OSError as exc:
        raise ClassifierCrash(
            f"cannot read raw-response file {args.raw_response_file}: {exc}"
        )

    if args.mode == "spec":
        (classification, evidence_class, blockers_items, blockers_yaml,
         claude_model) = classify_spec(raw_text)
        findings_path = None
    else:  # code | full
        if args.findings_path is None:
            raise ClassifierCrash(
                "--findings-path is required for --mode code|full"
            )
        findings_path = args.findings_path
        (classification, evidence_class, blockers_items, blockers_yaml,
         claude_model) = classify_code(findings_path)

    # Project-policy gate (§3.4a): ai-dev-team CLEAN_SINGLE -> STOP_AND_DISCUSS.
    policy_gate = None
    if args.project == "ai-dev-team" and classification == "CLEAN_SINGLE":
        policy_gate = "STOP_AND_DISCUSS"

    # Model-attestation gate (§3.4). Set ONLY when `--expected-claude-model`
    # is passed AND the response is CLEAN_* (a violation already routes to
    # retry — model_gate stays null and lets the violation path supersede).
    # claimed null/absent -> MISSING; claimed present but not a prefix of the
    # expected (e.g. the honest `unknown` fallback, or a silent Opus fold)
    # -> DEGRADED; otherwise null. The claude_model parse NEVER changes the
    # 12-enum classification or exit code.
    model_gate = None
    if (args.expected_claude_model is not None
            and classification in ("CLEAN_DUAL", "CLEAN_SINGLE")):
        if claude_model is None:
            model_gate = "MODEL_ATTESTATION_MISSING"
        elif not claude_model.startswith(args.expected_claude_model):
            model_gate = "MODEL_DEGRADED"

    exit_code = 0 if classification in ("CLEAN_DUAL", "CLEAN_SINGLE") else 1

    # Violation-blocker phrasing: the canonical string the orchestrator
    # records in `*_audit_blockers` for a `contract_violated` outcome (§3.5b-2b
    # retry-outcome matrix). Null for the clean classifications — those use
    # `blockers_yaml` (the clean path). Three classes carry a templated slot:
    #   FINDINGS_MISSING          -> <path>  : resolved findings path
    #   EVIDENCE_CLASS_DISALLOWED -> <value> : sanitized offending evidence_class
    #   DUAL_MODEL_WITH_BLOCKERS  -> <value> : the offending blockers_yaml literal
    # The offending value is sanitized through the canonical blocker
    # sanitizer (§2.5) before embedding, per SKILL.md §3.5b L523.
    violation_blocker = VIOLATION_BLOCKERS.get(classification)
    if violation_blocker is not None and "<path>" in violation_blocker:
        violation_blocker = violation_blocker.replace(
            "<path>", findings_path if findings_path else "<unknown>"
        )
    if violation_blocker is not None and "<value>" in violation_blocker:
        if classification == "EVIDENCE_CLASS_DISALLOWED":
            offending = sanitize_blocker(evidence_class or "")
        elif classification == "DUAL_MODEL_WITH_BLOCKERS":
            offending = sanitize_blocker(blockers_yaml or "[]")
        else:
            offending = "<unknown>"
        violation_blocker = violation_blocker.replace("<value>", offending)

    result = {
        "classification": classification,
        "evidence_class": evidence_class,
        "evidence_blockers": list(blockers_items),
        "blockers_yaml": blockers_yaml,
        "blockers": list(blockers_items),
        "violation_blocker": violation_blocker,
        "policy_gate": policy_gate,
        "claude_model": claude_model,
        "model_gate": model_gate,
        "iteration": args.iteration,
        "audit_slug": args.audit_slug,
        "mode": args.mode,
        "raw_response_path": args.raw_response_file,
        "findings_path": findings_path,
    }
    return result, exit_code


def main(argv):
    parser = build_parser()
    # argparse exits 2 on usage error by default — that matches our exit-2
    # contract for classifier crash (usage error).
    args = parser.parse_args(argv[1:])
    try:
        result, exit_code = run(args)
    except ClassifierCrash as exc:
        if args.debug:
            import traceback
            traceback.print_exc(file=sys.stderr)
        print(f"check_dispatch_response: classifier crash: {exc}",
              file=sys.stderr)
        return 2
    except Exception as exc:  # noqa: BLE001 — any unexpected fault is exit 2
        if args.debug:
            import traceback
            traceback.print_exc(file=sys.stderr)
        print(f"check_dispatch_response: classifier crash: {exc}",
              file=sys.stderr)
        return 2
    try:
        sys.stdout.write(json.dumps(result) + "\n")
    except (OSError, TypeError, ValueError) as exc:
        print(f"check_dispatch_response: classifier crash: "
              f"JSON marshalling error: {exc}", file=sys.stderr)
        return 2
    return exit_code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
