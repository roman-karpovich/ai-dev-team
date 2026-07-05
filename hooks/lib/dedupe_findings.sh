#!/usr/bin/env bash
# dedupe_findings.sh — structured-anchor dedupe pass for cross-audit findings.
#
# Reads `{findings: [...]}` on stdin, writes `{findings_deduped: [...]}` on
# stdout. Fingerprint algorithm per §3.5 of spec 2026-04-21-cross-audit-probes-
# foundation:
#
# - Probe E  fingerprint: normalize(primary_file) + "|" + marker_literal + "|"
#                          + consumer_symbol
# - Probe F  fingerprint: normalize(primary_file) + "|" + paging_symbol + "|"
#                          + failure_kind
#                          (failure_kind ∈ {missing_cursor, no_cardinality_budget,
#                           toy_fixture_only})
# - Probe G  fingerprint: normalize(test_file) + "|" + test_id_or_step_id + "|"
#                          + failure_kind
#                          (failure_kind ∈ {missing_red_proof, duplicate_dimension,
#                           compile_time_equivalent})
# - Legacy LLM: normalize(file) + "|" + severity + "|"
#               + first_80_chars_of_description_lowercased
#
# Match rules (§3.5):
# - Exact fingerprint across sources  → merge; authoritative `sources` list is
#   the union, preserving input order. Merged entry description is preserved
#   from the probe source when present; otherwise from the longer-prose LLM
#   source.
# - Partial match (same file + same probe-specific anchor but different
#   failure_kind, or LLM finding below keyword-overlap threshold) → separate
#   findings; both get a `related_to: [<other_id>]` cross-reference. Never
#   auto-merge on partial match.
# - No match → distinct findings.
#
# Merged entries emit `sources` list authoritatively (e.g. `["probe:E",
# "claude"]`) — no `both` primitive, per §3.3 X2 contract.
#
# Implementation: python3 stdlib only.

set -euo pipefail

STDIN_PAYLOAD=$(cat)

STDIN_PAYLOAD="$STDIN_PAYLOAD" python3 <<'PY'
import json
import os
import re
import sys


def die(msg, code=2):
    sys.stderr.write(f"dedupe_findings.sh: {msg}\n")
    sys.exit(code)


raw = os.environ.get("STDIN_PAYLOAD", "")
try:
    payload = json.loads(raw)
except json.JSONDecodeError as exc:
    die(f"stdin is not valid JSON: {exc}")

if not isinstance(payload, dict):
    die("stdin JSON must be an object with a 'findings' list")

findings = payload.get("findings")
if findings is None or not isinstance(findings, list):
    die("top-level 'findings' must be a list")


# --- Normalization helpers ---------------------------------------------------
_DRIVE_RE = re.compile(r"^[A-Za-z]:[\\/]")


def normalize_path(p):
    """Strip './' prefix, lowercase Windows drive letter (safety-only)."""
    if not isinstance(p, str):
        return ""
    # Lowercase any leading Windows drive letter.
    m = _DRIVE_RE.match(p)
    if m:
        p = p[0].lower() + p[1:]
    # Strip leading './' once.
    if p.startswith("./"):
        p = p[2:]
    return p


def get_probe_id(f):
    """Return 'E'|'F'|'G' if any sources[] element is a probe prefix; else None."""
    for s in f.get("sources") or []:
        if isinstance(s, str) and s.startswith("probe:"):
            return s.split(":", 1)[1]
    return None


def infer_anchor_kind(anchors):
    """Infer probe kind from anchor shape alone — lets an LLM-sourced finding
    carry pre-populated structured anchors (from orchestrator dedupe-hints) and
    match against a probe finding with the same anchors.

    Returns 'E'|'F'|'G' or None.
    """
    if not isinstance(anchors, dict) or not anchors:
        return None
    if "marker_literal" in anchors and "consumer_symbol" in anchors:
        return "E"
    if "paging_symbol" in anchors:
        return "F"
    if "test_file" in anchors and "test_id_or_step_id" in anchors:
        return "G"
    return None


def fingerprint(f):
    """Return (kind, fp_string) for f. kind ∈ {'E','F','G','llm'}.

    Probe-sourced findings use their probe-specific structured fingerprint.
    LLM findings whose `fingerprint_anchors` shape matches a probe kind (E/F/G)
    inherit that kind's fingerprint — this is how an LLM half and a probe
    merge into a single entry with sources: [probe:X, claude] (§3.5 structured
    anchors). LLM findings with no anchors fall back to the legacy LLM
    fingerprint (file + severity + first-80-chars-of-description-lowercased).
    """
    pid = get_probe_id(f)
    anchors = f.get("fingerprint_anchors") or {}
    if pid in ("E", "F", "G"):
        kind = pid
    else:
        kind = infer_anchor_kind(anchors)
    if kind == "E":
        fp = "|".join([
            normalize_path(anchors.get("primary_file", "")),
            str(anchors.get("marker_literal", "")),
            str(anchors.get("consumer_symbol", "")),
        ])
        return ("E", fp)
    if kind == "F":
        fp = "|".join([
            normalize_path(anchors.get("primary_file", "")),
            str(anchors.get("paging_symbol", "")),
            str(anchors.get("failure_kind", "")),
        ])
        return ("F", fp)
    if kind == "G":
        fp = "|".join([
            normalize_path(anchors.get("test_file", "")),
            str(anchors.get("test_id_or_step_id", "")),
            str(anchors.get("failure_kind", "")),
        ])
        return ("G", fp)
    # Legacy LLM
    desc = f.get("description", "") or ""
    fp = "|".join([
        normalize_path(f.get("file", "") or ""),
        str(f.get("severity", "") or ""),
        desc[:80].lower(),
    ])
    return ("llm", fp)


def partial_match_key(f):
    """Return a tuple used to detect partial matches (same file + same probe-
    specific anchor but different failure_kind). Returns None for kinds that
    do not carry a failure_kind concept.

    For probe F/G: (kind, normalized_file, anchor_sans_failure_kind)
    For E: no failure_kind → None.
    For LLM: no failure_kind → None.
    """
    pid = get_probe_id(f)
    anchors = f.get("fingerprint_anchors") or {}
    kind = pid if pid in ("E", "F", "G") else infer_anchor_kind(anchors)
    if kind == "E":
        # E has no failure_kind; "partial match" = same file + same marker,
        # different consumer_symbol. Pair by (file, marker).
        return (
            "E",
            normalize_path(anchors.get("primary_file", "")),
            str(anchors.get("marker_literal", "")),
        )
    if kind == "F":
        return (
            "F",
            normalize_path(anchors.get("primary_file", "")),
            str(anchors.get("paging_symbol", "")),
        )
    if kind == "G":
        return (
            "G",
            normalize_path(anchors.get("test_file", "")),
            str(anchors.get("test_id_or_step_id", "")),
        )
    return None


# --- Severity ordering (for merge) ------------------------------------------
SEVERITY_RANK = {"MEDIUM": 1, "HIGH": 2, "CRITICAL": 3}


def max_severity(a, b):
    return a if SEVERITY_RANK.get(a, 0) >= SEVERITY_RANK.get(b, 0) else b


def merge_pair(primary, secondary):
    """Merge `secondary` into `primary` (both findings with the same fingerprint).

    - sources: union, preserving primary's order then appending new sources
      from secondary in their order.
    - severity: max of the two.
    - description: preserve probe's description when a probe source is present;
      otherwise use whichever is longer.
    - probe fields (probe_receipt, probe_version, mode_at_emit, eligible_reason,
      provisional_id, canonical_payload, blocking, fingerprint_anchors):
      take from whichever finding is probe-sourced.

    Probe+LLM mixed merges (iter-5 X23 — spec 2026-04-21-probe-e-diff-scope-leak
    §3.2): swap so the probe-sourced member becomes primary BEFORE the
    ``dict(members[0])`` copy. `sources` union order becomes probe-first
    deterministically; the merged entry retains the probe's `provisional_id`,
    `canonical_payload`, `blocking`, and `fingerprint_anchors` so the Step 3
    stage-4.5 side-map lookup by `provisional_id` succeeds post-merge (iter-4
    X19 coupling). Probe+probe and LLM+LLM paths unchanged.
    """
    primary_has_probe = get_probe_id(primary) is not None
    secondary_has_probe = get_probe_id(secondary) is not None
    # iter-5 X23 — probe-primary swap for mixed probe+LLM merges.
    if secondary_has_probe and not primary_has_probe:
        primary, secondary = secondary, primary
        primary_has_probe, secondary_has_probe = True, False
    out = dict(primary)
    # sources — union preserving primary's (now probe, in mixed case) order.
    sources_out = list(primary.get("sources") or [])
    for s in secondary.get("sources") or []:
        if s not in sources_out:
            sources_out.append(s)
    out["sources"] = sources_out
    # severity
    out["severity"] = max_severity(
        primary.get("severity", ""), secondary.get("severity", "")
    )
    # description: probe description wins; else longer prose. (After the X23
    # swap `primary_has_probe` is True for any probe+LLM mixed merge.)
    if primary_has_probe and not secondary_has_probe:
        out["description"] = primary.get("description", "")
    else:
        p_desc = primary.get("description", "") or ""
        s_desc = secondary.get("description", "") or ""
        out["description"] = p_desc if len(p_desc) >= len(s_desc) else s_desc
    # failure_class carry — the X23 swap makes the probe member primary on mixed
    # probe+LLM merges, and probes don't emit failure_class, so an LLM-side value
    # on the secondary would be dropped by dict(primary) alone. Carry it
    # explicitly. §3.3 treats an absent failure_class as valid (rendered empty;
    # old producers / probe findings stay valid), so only set the key when a
    # value is actually present — all-absent merges keep the key absent rather
    # than gaining a spurious empty string, which keeps every pre-existing merged
    # finding byte-stable through the renderer.
    carried_failure_class = (
        primary.get("failure_class") or secondary.get("failure_class")
    )
    if carried_failure_class:
        out["failure_class"] = carried_failure_class
    # probe-only fields — already on `out` via dict(primary) because the X23
    # swap guarantees primary is the probe-sourced member for mixed merges.
    # This residual block is a safety-net for future probe+probe+LLM multi-way
    # merges where a canonical probe field could live on a non-primary member.
    # iter-5 X23 extends the carried-field list to eight keys.
    if secondary_has_probe and not primary_has_probe:
        for key in (
            "probe_receipt", "probe_version", "mode_at_emit", "eligible_reason",
            "provisional_id", "canonical_payload", "blocking",
            "fingerprint_anchors",
        ):
            if secondary.get(key) is not None:
                out[key] = secondary[key]
    return out


# --- Dedupe pass -------------------------------------------------------------
#
# Algorithm:
# 1. Compute each finding's fingerprint.
# 2. Group by (kind, fp). Each group of size >=2 merges into a single entry.
# 3. For ungrouped findings that share a partial_match_key (same file + same
#    probe-specific anchor minus failure_kind), attach mutual `related_to`
#    cross-references.
# 4. Emit in input order (by the first ID in each merge group).

groups_by_fp = {}
order = []  # list of (kind, fp) in first-seen order
for f in findings:
    kind, fp = fingerprint(f)
    key = (kind, fp)
    if key not in groups_by_fp:
        groups_by_fp[key] = []
        order.append(key)
    groups_by_fp[key].append(f)

merged_findings = []
id_to_dedup = {}  # original id → deduped entry (for related_to back-reference)
for key in order:
    members = groups_by_fp[key]
    if len(members) == 1:
        entry = dict(members[0])
    else:
        entry = dict(members[0])
        for m in members[1:]:
            entry = merge_pair(entry, m)
    merged_findings.append(entry)
    for m in members:
        id_to_dedup[m["id"]] = entry

# Partial-match pass: same partial_match_key but different fingerprint → related_to.
partial_groups = {}
for entry in merged_findings:
    pkey = partial_match_key(entry)
    if pkey is None:
        continue
    partial_groups.setdefault(pkey, []).append(entry)

for pkey, members in partial_groups.items():
    if len(members) < 2:
        continue
    # Verify they are NOT full-fingerprint matches (those would already be merged).
    fps = {fingerprint(m)[1] for m in members}
    if len(fps) == 1:
        continue
    # Attach mutual related_to cross-references.
    for m in members:
        related = list(m.get("related_to") or [])
        for other in members:
            if other["id"] == m["id"]:
                continue
            if other["id"] not in related:
                related.append(other["id"])
        m["related_to"] = related

# Canonical JSON emission — sorted keys, compact separators, LF terminator.
out = {"findings_deduped": merged_findings}
sys.stdout.write(
    json.dumps(out, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n"
)
PY
