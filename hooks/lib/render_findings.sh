#!/usr/bin/env bash
# render_findings.sh — central findings.md renderer for cross-audit probes foundation.
#
# Reads JSON on stdin, writes findings.md body markdown on stdout.
#
# Input JSON schema (§3.3 of spec 2026-04-21-cross-audit-probes-foundation):
#   {
#     "findings": [
#       {
#         "id": "X1", "severity": "CRITICAL|HIGH|MEDIUM",
#         "title": "...", "sources": ["claude", "codex" | "probe:E|F|G", ...],
#         "file": "path:line", "description": "...",
#         "failure_class": "<string>",  # optional; rendered empty when absent
#         "fix": "...",
#         "mode_at_emit": null | "shadow" | "warn" | "block",
#         "blocking": true|false,
#         "probe_receipt": null | "<path>", "probe_version": null | "<version>",
#         "eligible_reason": null | "<reason>",
#         "confidence": 0-100, "status": "OPEN|FIXED|..."
#       }
#     ],
#     "probe_modes": { "<probe_id>": "off|shadow|warn|block", ... },
#     "probe_failures": [
#       { "probe_id": "<id>", "reason": "<str>", "remediation": "<str>" }
#     ],
#     "scorer_status": "ok" | "failed"
#   }
#
# Output structure:
#   - Degraded-mode banner (top) when probe_failures[] is non-empty.
#   - `## Summary` table (probe findings in warn|block + pure-LLM findings).
#   - `## Shadow findings (informational)` table when any shadow-mode probe findings.
#   - `## Details` section — all findings with schema-cut detail fields.
#
# Routing (per §3.5a single cascade, Steps 2-5 scope):
#   - Any probe:* in sources[] + mode_at_emit == "shadow" → Shadow section.
#   - Any probe:* in sources[] + mode_at_emit in {warn, block} → Summary.
#   - Pure-LLM (no probe:* in sources[]) → Summary.
#   (Step 6 extends pure-LLM routing with the advisory section.)
#
# Hard-stop contract (X10):
#   - probe_failures[] malformed (missing required field, non-string value,
#     or wrong container type) → exit 2 with diagnostic on stderr.
#   - Input is not JSON, not an object, or required top-level keys missing
#     → exit 2 with diagnostic on stderr.
#
# Implementation: python3 stdlib only (matches hooks/lib/build_pr_files.sh).

set -euo pipefail

STDIN_PAYLOAD=$(cat)

STDIN_PAYLOAD="$STDIN_PAYLOAD" python3 <<'PY'
import json
import os
import sys


def die(msg, code=2):
    sys.stderr.write(f"render_findings.sh: {msg}\n")
    sys.exit(code)


raw = os.environ.get("STDIN_PAYLOAD", "")
try:
    payload = json.loads(raw)
except json.JSONDecodeError as exc:
    die(f"stdin is not valid JSON: {exc}")

if not isinstance(payload, dict):
    die("stdin JSON must be an object with keys findings/probe_modes/probe_failures/scorer_status")

findings = payload.get("findings")
probe_modes = payload.get("probe_modes")
probe_failures = payload.get("probe_failures")
scorer_status = payload.get("scorer_status", "ok")
scorer_failure_reason = payload.get("scorer_failure_reason", "")

if findings is None or not isinstance(findings, list):
    die("top-level 'findings' must be a list")
if probe_modes is None or not isinstance(probe_modes, dict):
    die("top-level 'probe_modes' must be an object")
if probe_failures is None or not isinstance(probe_failures, list):
    die("top-level 'probe_failures' must be a list")
if scorer_status not in ("ok", "failed"):
    die(f"top-level 'scorer_status' must be 'ok' or 'failed' (got {scorer_status!r})")
if scorer_status == "failed" and not isinstance(scorer_failure_reason, str):
    die("'scorer_failure_reason' must be a string when scorer_status == 'failed'")

# ---- Validate probe_failures[] schema (X10 hard-stop contract) --------------
REQUIRED_FAILURE_FIELDS = ("probe_id", "reason", "remediation")
for i, pf in enumerate(probe_failures):
    if not isinstance(pf, dict):
        die(f"probe_failures[{i}] must be an object (got {type(pf).__name__})")
    for field in REQUIRED_FAILURE_FIELDS:
        if field not in pf:
            die(f"probe_failures[{i}] missing required field '{field}'")
        if not isinstance(pf[field], str):
            die(
                f"probe_failures[{i}].{field} must be a string "
                f"(got {type(pf[field]).__name__})"
            )


# ---- Helpers ---------------------------------------------------------------
def is_probe_sourced(finding):
    """True iff any element of sources[] carries the 'probe:' prefix (§3.3 X2)."""
    sources = finding.get("sources") or []
    return any(isinstance(s, str) and s.startswith("probe:") for s in sources)


def render_source_cell(sources):
    """Derived display cell from sources[] (single → verbatim; multi → `+`-joined
    in emission order). Per §3.3 X2 contract."""
    if not sources:
        return ""
    return "+".join(sources)


def render_sources_list(sources):
    """Authoritative details-block list value, e.g. '[probe:E, claude]'."""
    return "[" + ", ".join(sources) + "]"


def render_scalar(value):
    """Render a nullable string for the details block — None → 'null'."""
    if value is None:
        return "null"
    return str(value)


def classify_section(finding, scorer_failed):
    """Return 'shadow', 'summary', or 'advisory' — the section this finding
    lands in per §3.5a single routing cascade (first match wins):

    1. Any probe:* in sources[] → route by mode_at_emit:
       - shadow → Shadow section
       - warn | block → Summary section
       (Probe mode DOMINATES even for merged probe+LLM — LLM half is absorbed.)
    2. Pure-LLM with confidence >= 80 → Summary
    3. Pure-LLM with confidence < 80 → Advisory
       UNLESS scorer failed — in which case ALL pure-LLM land in Summary
       (§3.5a fail-open: renderer cannot trust low confidence values to route).
    """
    if is_probe_sourced(finding):
        mode = finding.get("mode_at_emit")
        if mode == "shadow":
            return "shadow"
        return "summary"
    # Pure-LLM
    if scorer_failed:
        return "summary"
    conf = finding.get("confidence", 0)
    if isinstance(conf, int) and conf >= 80:
        return "summary"
    return "advisory"


# ---- Emit output ------------------------------------------------------------
out = []
scorer_failed = (scorer_status == "failed")

# Degraded-mode banner — top of findings.md when any probe fail-opened OR the
# scorer fail-opened. Both lines render inside a single banner block (§3.5a
# X6 combined-fail layout).
if probe_failures or scorer_failed:
    if probe_failures:
        out.append("⚠️  Probe(s) fail-opened this iteration — findings may be incomplete:")
        for pf in probe_failures:
            out.append(
                f"  - probe:{pf['probe_id']} (reason: {pf['reason']}; "
                f"remediation: {pf['remediation']})"
            )
    if scorer_failed:
        out.append(
            f"⚠️  Haiku finding-scorer unavailable ({scorer_failure_reason}). "
            "LLM findings retain legacy self-reported confidence labels "
            "mapped to pseudo-confidence — rerun /cross-audit when scorer "
            "is restored for full decoupled scoring."
        )
    out.append("")  # blank line before Summary

# Partition findings by section per §3.5a routing cascade.
summary = []
shadow = []
advisory = []
for f in findings:
    section = classify_section(f, scorer_failed)
    if section == "shadow":
        shadow.append(f)
    elif section == "advisory":
        advisory.append(f)
    else:
        summary.append(f)

# ## Summary table — rendered even when empty (canonical anchor)? No: only when
# Summary has entries. This mirrors §3.5a "Empty sections are omitted by the renderer."
if summary:
    out.append("## Summary")
    out.append("")
    out.append("| ID | Severity | Issue | Source | Mode | Confidence | Status |")
    out.append("|----|----------|-------|--------|------|------------|--------|")
    for f in summary:
        mode = f.get("mode_at_emit") or ""
        src = render_source_cell(f.get("sources") or [])
        out.append(
            f"| {f['id']} | {f['severity']} | {f['title']} | {src} | {mode} | "
            f"{f['confidence']} | {f['status']} |"
        )
    out.append("")

# ## Low-confidence LLM findings (advisory) table — when any pure-LLM
# findings scored below 80. Suppressed entirely when scorer failed (all
# pure-LLM already rerouted to Summary via classify_section).
if advisory:
    out.append("## Low-confidence LLM findings (advisory)")
    out.append("")
    out.append("| ID | Severity | Issue | Source | Mode | Confidence | Status |")
    out.append("|----|----------|-------|--------|------|------------|--------|")
    for f in advisory:
        mode = f.get("mode_at_emit") or ""
        src = render_source_cell(f.get("sources") or [])
        out.append(
            f"| {f['id']} | {f['severity']} | {f['title']} | {src} | {mode} | "
            f"{f['confidence']} | {f['status']} |"
        )
    out.append("")

# ## Shadow findings (informational) table — when any shadow findings.
if shadow:
    out.append("## Shadow findings (informational)")
    out.append("")
    out.append("| ID | Severity | Issue | Source | Mode | Confidence | Status |")
    out.append("|----|----------|-------|--------|------|------------|--------|")
    for f in shadow:
        mode = f.get("mode_at_emit") or ""
        src = render_source_cell(f.get("sources") or [])
        out.append(
            f"| {f['id']} | {f['severity']} | {f['title']} | {src} | {mode} | "
            f"{f['confidence']} | {f['status']} |"
        )
    out.append("")

# ## Details — combined block for summary + advisory + shadow, in input order.
all_findings = summary + advisory + shadow
if all_findings:
    out.append("## Details")
    out.append("")
    for idx, f in enumerate(all_findings):
        if idx > 0:
            out.append("")  # blank line between detail entries
        out.append(f"### [{f['id']}] {f['title']}")
        out.append(f"- **Severity**: {f['severity']}")
        out.append(f"- **File**: {f['file']}")
        out.append(f"- **Description**: {f['description']}")
        out.append(f"- **Failure class / input domain**: {f.get('failure_class') or ''}")
        out.append(f"- **Fix (advisory)**: {f['fix']}")
        out.append(f"- **Sources**: {render_sources_list(f.get('sources') or [])}")
        out.append(f"- **Mode at emit**: {f.get('mode_at_emit') or ''}")
        blocking = f.get("blocking", False)
        out.append(f"- **Blocking**: {'true' if blocking else 'false'}")
        out.append(f"- **Probe receipt**: {render_scalar(f.get('probe_receipt'))}")
        out.append(f"- **Probe version**: {render_scalar(f.get('probe_version'))}")
        out.append(f"- **Eligible reason**: {render_scalar(f.get('eligible_reason'))}")
        out.append(f"- **Confidence**: {f['confidence']}")
        # `legacy_pseudo_confidence: true` detail renders only when the flag
        # is truthy on the entry. Per §3.5a it's set on pure-LLM entries
        # during scorer fail-open AND on round-trip legacy migrations; it is
        # NEVER set on merged probe+LLM entries (probe pins confidence=100
        # independently of scorer state).
        if f.get("legacy_pseudo_confidence"):
            out.append(f"- **Legacy pseudo-confidence**: true")
        out.append(f"- **Status**: {f['status']}")

sys.stdout.write("\n".join(out) + "\n")
PY
