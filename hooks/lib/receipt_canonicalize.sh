#!/usr/bin/env bash
# receipt_canonicalize.sh — reference implementation of §3.3 probe-receipt hash
# canonicalization for spec 2026-04-21-cross-audit-probes-foundation.
#
# Reads `{scope_files: [...], scope_file_contents: {...}, envelope: {...}}` on
# stdin (synthetic test seam — real probes would read disk directly), emits
# `{trigger_input_hash: "<sha256>", probe_output_hash: "<sha256>"}` on stdout.
#
# trigger_input_hash canonicalization (§3.3):
#   sha256(canonical_input_bytes)
#   where canonical_input_bytes is, for each file in scope_files sorted
#   lexicographically by relative path string, the concatenation of:
#     <relative_path> + "\n" + <content_bytes_LF_normalized> + "\n" + 0x00
#   Newlines in content_bytes are normalized CRLF→LF and bare-CR→LF before
#   hashing; no trailing-newline stripping. Empty scope_files → empty input
#   → sha256 of 0 bytes (e3b0c44…b855).
#   Sorting is internal — caller may pass scope_files in any order.
#
# probe_output_hash canonicalization (§3.3):
#   sha256(json.dumps(envelope, sort_keys=True, separators=(",", ":"),
#                     ensure_ascii=False))
#   where envelope = {"probe_id": <id>, "probe_version": <string>,
#                     "emitted_findings": <list of probe-specific canonical payloads>}
#
# Rerun stability: identical inputs on two invocations produce byte-identical
# outputs. Re-ordering scope_files internally does not change the hash (sort is
# internal). Per-probe canonical payload shapes are defined in each probe's own
# spec — this Foundation helper only guarantees the envelope wrapper and the
# json.dumps parameters.
#
# Implementation: python3 stdlib only.

set -euo pipefail

STDIN_PAYLOAD=$(cat)

STDIN_PAYLOAD="$STDIN_PAYLOAD" python3 <<'PY'
import hashlib
import json
import os
import sys


def die(msg, code=2):
    sys.stderr.write(f"receipt_canonicalize.sh: {msg}\n")
    sys.exit(code)


raw = os.environ.get("STDIN_PAYLOAD", "")
try:
    payload = json.loads(raw)
except json.JSONDecodeError as exc:
    die(f"stdin is not valid JSON: {exc}")

if not isinstance(payload, dict):
    die("stdin JSON must be an object")

scope_files = payload.get("scope_files", [])
scope_file_contents = payload.get("scope_file_contents", {})
envelope = payload.get("envelope", {})

if not isinstance(scope_files, list):
    die("'scope_files' must be a list of relative paths")
if not isinstance(scope_file_contents, dict):
    die("'scope_file_contents' must be an object keyed by relative path")
if not isinstance(envelope, dict):
    die("'envelope' must be an object")


# --- trigger_input_hash ------------------------------------------------------
# Sort paths lexicographically by the relative-path string. Concatenate
#   <relative_path> + "\n" + <LF-normalized content> + "\n" + 0x00
# per file. Hash the concatenation.
sorted_paths = sorted(scope_files)
buf = bytearray()
for rel in sorted_paths:
    content = scope_file_contents.get(rel, "")
    if isinstance(content, bytes):
        content_bytes = content
    else:
        content_bytes = str(content).encode("utf-8")
    # Normalize CRLF → LF, bare-CR → LF (no trailing-newline stripping).
    content_bytes = content_bytes.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    buf.extend(rel.encode("utf-8"))
    buf.extend(b"\n")
    buf.extend(content_bytes)
    buf.extend(b"\n")
    buf.append(0x00)

trigger_input_hash = hashlib.sha256(bytes(buf)).hexdigest()


# --- probe_output_hash -------------------------------------------------------
envelope_json = json.dumps(
    envelope, sort_keys=True, separators=(",", ":"), ensure_ascii=False
)
probe_output_hash = hashlib.sha256(envelope_json.encode("utf-8")).hexdigest()


out = {
    "trigger_input_hash": trigger_input_hash,
    "probe_output_hash": probe_output_hash,
}
sys.stdout.write(
    json.dumps(out, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n"
)
PY
