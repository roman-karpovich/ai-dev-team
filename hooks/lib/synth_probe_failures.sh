#!/usr/bin/env bash
# synth_probe_failures.sh — reference implementation of the cross-auditor
# Step 3 Consolidation's `probe_failures[]` synthesis step (spec 2026-04-21-
# cross-audit-probes-foundation §3.3 X10 + §3.7 X18).
#
# Reads `{probe_receipts: [...]}` on stdin. For each receipt with
# `degraded_mode: true`, emits one `probe_failures[]` item with the three
# required string fields: `probe_id`, `reason`, `remediation`.
#
# Reason/remediation sourcing:
# - If the receipt carries non-empty string `failure_reason`, use it.
# - Otherwise synthesize `"probe produced degraded_mode=true without surfacing
#   reason/remediation strings"`.
# - Same rule for `failure_remediation`, with the synthetic fallback
#   `"check probe logs in <receipt path>; re-run when probe is fixed"` where
#   `<receipt path>` comes from the receipt's `_receipt_path` field (added
#   by the orchestrator when it reads each receipt from disk; tests simulate
#   this by setting the field directly on the synthetic receipt).
#
# Emits `{probe_failures: [...]}` on stdout. Canonical JSON (sort_keys,
# compact separators).
#
# Implementation: python3 stdlib only.

set -euo pipefail

STDIN_PAYLOAD=$(cat)

STDIN_PAYLOAD="$STDIN_PAYLOAD" python3 <<'PY'
import json
import os
import sys


def die(msg, code=2):
    sys.stderr.write(f"synth_probe_failures.sh: {msg}\n")
    sys.exit(code)


raw = os.environ.get("STDIN_PAYLOAD", "")
try:
    payload = json.loads(raw)
except json.JSONDecodeError as exc:
    die(f"stdin is not valid JSON: {exc}")

if not isinstance(payload, dict):
    die("stdin JSON must be an object with a 'probe_receipts' list")

receipts = payload.get("probe_receipts")
if receipts is None or not isinstance(receipts, list):
    die("top-level 'probe_receipts' must be a list")


def nonempty_string(v):
    return isinstance(v, str) and len(v) > 0


probe_failures = []
for i, r in enumerate(receipts):
    if not isinstance(r, dict):
        die(f"probe_receipts[{i}] must be an object")
    if not r.get("degraded_mode"):
        continue
    probe_id = r.get("probe_id", "")
    if not nonempty_string(probe_id):
        die(f"probe_receipts[{i}].probe_id must be a non-empty string")
    receipt_path = r.get("_receipt_path", "") or "<unknown>"
    reason = r.get("failure_reason")
    if not nonempty_string(reason):
        reason = (
            "probe produced degraded_mode=true without surfacing "
            "reason/remediation strings"
        )
    remediation = r.get("failure_remediation")
    if not nonempty_string(remediation):
        remediation = (
            f"check probe logs in {receipt_path}; re-run when probe is fixed"
        )
    probe_failures.append(
        {"probe_id": probe_id, "reason": reason, "remediation": remediation}
    )

sys.stdout.write(
    json.dumps(
        {"probe_failures": probe_failures},
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    )
    + "\n"
)
PY
