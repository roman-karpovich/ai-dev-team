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
      [--debug]                  # on exit 2, emit full Python traceback to stderr
"""

import argparse
import json
import sys

# Canonical spaced EVIDENCE FOOTER sentinel literal. This is the single
# producer-side authoritative form per agents/references/
# cross-auditor-evidence-handshake.md — the parser asserts byte-exact
# full-line equality against it.
SENTINEL = "# CROSS-AUDIT EVIDENCE FOOTER"

ALLOWED_EVIDENCE_CLASSES = ("dual_model", "single_model")


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
        while i < n and inner[i] in " \t,":
            i += 1
        if i >= n:
            break
        if inner[i] != "'":
            # bare scalar — collect up to next comma
            start = i
            while i < n and inner[i] != ",":
                i += 1
            items.append(inner[start:i].strip())
            continue
        # single-quoted scalar — scan to closing quote, honoring '' escape
        i += 1
        start = i
        buf = []
        while i < n:
            if inner[i] == "'":
                if i + 1 < n and inner[i + 1] == "'":
                    buf.append("'")
                    i += 2
                    continue
                break
            buf.append(inner[i])
            i += 1
        items.append("".join(buf))
        i += 1  # skip closing quote
    return items, True


def _scan_blocker_safety(raw_value):
    """Inspect the raw blockers literal text for YAML-safety violations.

    Returns one of: "ok", "unsafe_newline", "unsafe_apostrophe".
    Operates on the raw literal text (pre-parse) because an unescaped
    apostrophe is detectable only in the raw single-quoted form.
    """
    # Physical newline anywhere inside the list literal is unsafe.
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
    """Return the lines of the first YAML frontmatter block (between the
    first two `---` delimiter lines), or None if no frontmatter block."""
    lines = text.splitlines()
    delim_idx = [i for i, ln in enumerate(lines) if ln.rstrip() == "---"]
    if len(delim_idx) < 2:
        return None
    return lines[delim_idx[0] + 1 : delim_idx[1]]


def _classify_fields(evidence_class, blockers_raw, blockers_safety,
                      blockers_items):
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

    Returns (classification, evidence_class, blockers_items, blockers_yaml).
    """
    # Strip ALL trailing newlines (transport artifact) then take last 3 lines.
    stripped = raw_text.rstrip("\n").rstrip("\r\n")
    lines = stripped.splitlines()
    if len(lines) < 3:
        return "MISSING_FOOTER", None, [], "[]"
    footer = lines[-3:]
    if footer[0] != SENTINEL:
        return "MISSING_FOOTER", None, [], "[]"
    if not footer[1].startswith("evidence_class: "):
        return "MALFORMED_FOOTER_EVIDENCE_CLASS", None, [], "[]"
    if not footer[2].startswith("evidence_blockers: "):
        return "MALFORMED_FOOTER_EVIDENCE_BLOCKERS", None, [], "[]"
    evidence_class = footer[1][len("evidence_class: "):].strip()
    blockers_raw = footer[2][len("evidence_blockers: "):]
    blockers_safety = _scan_blocker_safety(blockers_raw)
    blockers_items, _ = _parse_blockers_literal(blockers_raw)
    classification = _classify_fields(
        evidence_class, blockers_raw, blockers_safety, blockers_items
    )
    blockers_yaml = _emit_blockers_yaml(blockers_items)
    return classification, evidence_class, blockers_items, blockers_yaml


def classify_code(findings_path):
    """Classify a code/full-mode response from the on-disk findings.md.

    Returns (classification, evidence_class, blockers_items, blockers_yaml).
    """
    try:
        with open(findings_path, "r", encoding="utf-8") as fh:
            text = fh.read()
    except FileNotFoundError:
        return "FINDINGS_MISSING", None, [], "[]"
    except OSError as exc:
        raise ClassifierCrash(
            f"cannot read findings file {findings_path}: {exc}"
        )
    fm = _frontmatter_lines(text)
    if fm is None:
        return "FINDINGS_MALFORMED", None, [], "[]"
    evidence_class = None
    blockers_raw = None
    for ln in fm:
        if ln.startswith("evidence_class:"):
            evidence_class = ln[len("evidence_class:"):].strip()
        elif ln.startswith("evidence_blockers:"):
            blockers_raw = ln[len("evidence_blockers:"):].strip()
    if evidence_class is None or blockers_raw is None:
        return "FINDINGS_MALFORMED", None, [], "[]"
    blockers_safety = _scan_blocker_safety(blockers_raw)
    blockers_items, _ = _parse_blockers_literal(blockers_raw)
    classification = _classify_fields(
        evidence_class, blockers_raw, blockers_safety, blockers_items
    )
    blockers_yaml = _emit_blockers_yaml(blockers_items)
    return classification, evidence_class, blockers_items, blockers_yaml


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
        classification, evidence_class, blockers_items, blockers_yaml = \
            classify_spec(raw_text)
        findings_path = None
    else:  # code | full
        if args.findings_path is None:
            raise ClassifierCrash(
                "--findings-path is required for --mode code|full"
            )
        findings_path = args.findings_path
        classification, evidence_class, blockers_items, blockers_yaml = \
            classify_code(findings_path)

    # Project-policy gate (§3.4a): ai-dev-team CLEAN_SINGLE -> STOP_AND_DISCUSS.
    policy_gate = None
    if args.project == "ai-dev-team" and classification == "CLEAN_SINGLE":
        policy_gate = "STOP_AND_DISCUSS"

    exit_code = 0 if classification in ("CLEAN_DUAL", "CLEAN_SINGLE") else 1

    result = {
        "classification": classification,
        "evidence_class": evidence_class,
        "evidence_blockers": list(blockers_items),
        "blockers_yaml": blockers_yaml,
        "blockers": list(blockers_items),
        "policy_gate": policy_gate,
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
