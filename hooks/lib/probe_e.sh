#!/usr/bin/env bash
# probe_e.sh — cross-audit probe E (diff-scope leak — same-file allowlist
# detector) per spec 2026-04-21-probe-e-diff-scope-leak §3.4.
#
# stdin envelope (§3.3):
#   {
#     "diff": {"added_lines": {"<relpath>": [lineno, ...], ...}},
#     "changed_python_files": ["<relpath>", ...],
#     "repo_root": "<abs-or-relative-path>",
#     "audit_slug": "<slug>",
#     "base_ref": "<ref>",
#     "mode": "off|shadow|warn|block"
#   }
#
# stdout (§3.3):
#   {
#     "findings": [{provisional_id, sources, severity, title, file,
#                    description, fix, fingerprint_anchors, canonical_payload}, ...],
#     "receipt_metadata": {probe_id, probe_version, trigger_input_hash,
#                           scope_files_read, skipped_files, emitted_at,
#                           degraded_mode, eligible_reason}
#   }
#
# Receipt envelope construction (including probe_output_hash) happens in the
# cross-auditor orchestrator (§3.5 stage 4.5), not here.
#
# Determinism seam: when PROBE_E_FAKE_NOW env var is set, receipt_metadata's
# emitted_at uses that value verbatim (for fixtures + smoke). Otherwise uses
# current UTC ISO-8601 with trailing "Z".
#
# Per-file SyntaxError → skip the file, append its relpath to skipped_files,
# continue with other files. Whole-probe uncaught exception → exit non-zero
# with stderr diagnostic; orchestrator fails-open.
#
# python3 stdlib only.

set -euo pipefail

STDIN_PAYLOAD=$(cat)

STDIN_PAYLOAD="$STDIN_PAYLOAD" python3 <<'PY'
import ast
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone


PROBE_ID = "E"
PROBE_VERSION = "e.1.0"

# --- Test-file detection (per §3.4 step 1) -----------------------------------
TEST_DIR_RE = re.compile(r"(^|/)(tests?|__tests__)(/|$)")
TEST_FILE_RE = re.compile(r"(^|/)(test_[^/]+|[^/]+_test)\.py$")


def is_test_path(rel):
    if TEST_DIR_RE.search(rel):
        return True
    if TEST_FILE_RE.search(rel):
        return True
    return False


def die(msg, code=2):
    sys.stderr.write(f"probe_e.sh: {msg}\n")
    sys.exit(code)


raw = os.environ.get("STDIN_PAYLOAD", "")
try:
    payload = json.loads(raw)
except json.JSONDecodeError as exc:
    die(f"stdin is not valid JSON: {exc}")

if not isinstance(payload, dict):
    die("stdin JSON must be an object")

diff = payload.get("diff") or {}
added_lines_by_file = diff.get("added_lines") or {}
changed_python_files = payload.get("changed_python_files") or []
repo_root = payload.get("repo_root") or "."
mode = payload.get("mode") or "shadow"

if not isinstance(added_lines_by_file, dict):
    die("diff.added_lines must be an object mapping relpath → [linenos]")
if not isinstance(changed_python_files, list):
    die("changed_python_files must be a list")


# --- Normalize added_lines to sets of ints -----------------------------------
added_lines = {}
for rel, lines in added_lines_by_file.items():
    if not isinstance(lines, list):
        die(f"diff.added_lines['{rel}'] must be a list")
    added_lines[rel] = set(int(x) for x in lines)


# --- Filter changed files to non-test Python files ---------------------------
# Test files skipped BEFORE any file read — per §3.4 step 1. They do not
# appear in scope_files_read, skipped_files, or trigger_input_hash.
scope_candidates = [rel for rel in changed_python_files if not is_test_path(rel)]


# --- trigger_input_hash (Foundation §3.3 canonicalization) -------------------
# sha256 of concat: for each path sorted lex: <relpath>\n<LF-normalized>\n\0
buf = bytearray()
attempted_contents = {}  # rel → content bytes (LF-normalized) — reused below
for rel in sorted(scope_candidates):
    abs_path = os.path.join(repo_root, rel)
    try:
        with open(abs_path, "rb") as fh:
            content = fh.read()
    except (IOError, OSError) as e:
        die(f"failed to read {abs_path}: {e}")
    content = content.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    attempted_contents[rel] = content
    buf.extend(rel.encode("utf-8"))
    buf.extend(b"\n")
    buf.extend(content)
    buf.extend(b"\n")
    buf.append(0x00)
trigger_input_hash = hashlib.sha256(bytes(buf)).hexdigest()


# --- Per-file AST walk -------------------------------------------------------
scope_files_read = []
skipped_files = []
findings = []


# String length floor (§3.4 eligibility thresholds).
STRING_LEN_FLOOR = 5


def is_numeric_only_string(s):
    """§3.4 eligibility — numeric-only strings excluded (parsable as int/float)."""
    if not s:
        return False
    try:
        int(s)
        return True
    except (TypeError, ValueError):
        pass
    try:
        float(s)
        return True
    except (TypeError, ValueError):
        return False


def collection_element_nodes(node):
    """Return list of ast.Constant(str) elements in a collection-literal node,
    or None if `node` is not an eligible collection shape (§3.4 step 3).

    Eligible shapes: ast.Set, ast.List, ast.Tuple, ast.Call frozenset(<Set>),
    ast.Dict (keys only).
    """
    # frozenset({...}) with a single set/list/tuple literal arg.
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) \
            and node.func.id == "frozenset" and len(node.args) == 1:
        inner = node.args[0]
        if isinstance(inner, (ast.Set, ast.List, ast.Tuple)):
            elts = inner.elts
        else:
            return None
    elif isinstance(node, (ast.Set, ast.List, ast.Tuple)):
        elts = node.elts
    elif isinstance(node, ast.Dict):
        elts = [k for k in node.keys if k is not None]
    else:
        return None
    str_elts = [e for e in elts
                if isinstance(e, ast.Constant) and isinstance(e.value, str)]
    return str_elts


def all_elements_are_strings(node):
    """True iff every element of the collection is a string Constant (no
    partial-match collections allowed per §3.4 step 4 'every element of C must
    share the pattern'). Callers still need to verify the str_elts list has
    ≥3 non-numeric strings after length/numeric filtering."""
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) \
            and node.func.id == "frozenset" and len(node.args) == 1:
        inner = node.args[0]
        if isinstance(inner, (ast.Set, ast.List, ast.Tuple)):
            elts = inner.elts
        else:
            return False
    elif isinstance(node, (ast.Set, ast.List, ast.Tuple)):
        elts = node.elts
    elif isinstance(node, ast.Dict):
        elts = [k for k in node.keys if k is not None]
    else:
        return False
    if not elts:
        return False
    return all(isinstance(e, ast.Constant) and isinstance(e.value, str)
               for e in elts)


def collection_lineno_range(node):
    """Return (start, end) line range of the collection literal node inclusive.
    Uses ast.Call outer range for frozenset(...); inner literal range otherwise.
    """
    start = node.lineno
    end = getattr(node, "end_lineno", node.lineno) or node.lineno
    return (start, end)


def resolve_consumer_symbol(node, parent_map):
    """§3.4 step 5: walk up from node; find nearest enclosing named scope
    (FunctionDef / AsyncFunctionDef / ClassDef / module-level Assign with a
    single Name target). Fall back to '<module>'.

    Returns (symbol_name, symbol_lineno).
    """
    cur = parent_map.get(id(node))
    while cur is not None:
        if isinstance(cur, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            return (cur.name, cur.lineno)
        if isinstance(cur, ast.Assign) and len(cur.targets) == 1 \
                and isinstance(cur.targets[0], ast.Name):
            # Only accept module-level (parent is ast.Module).
            grand = parent_map.get(id(cur))
            if isinstance(grand, ast.Module):
                return (cur.targets[0].id, cur.lineno)
        cur = parent_map.get(id(cur))
    return ("<module>", 1)


def shared_pattern(strings, L):
    """§3.4 step 4: return 'trailing_<char>' | 'leading_<prefix>' | None for
    the (collection-strings, added-literal) pair.
    """
    if not strings:
        return None
    # Trailing non-alphanumeric single-char rule.
    last_chars = {s[-1] for s in strings if s}
    if len(last_chars) == 1:
        ch = next(iter(last_chars))
        if ch and not ch.isalnum():
            if L and L.endswith(ch):
                return f"trailing_{ch}"
    # Leading 3-char prefix rule.
    if all(len(s) >= 3 for s in strings):
        prefixes = {s[:3] for s in strings}
        if len(prefixes) == 1:
            p = next(iter(prefixes))
            if L and L.startswith(p):
                return f"leading_{p}"
    return None


def build_parent_map(tree):
    parent_map = {}
    for parent in ast.walk(tree):
        for child in ast.iter_child_nodes(parent):
            parent_map[id(child)] = parent
    return parent_map


for rel in sorted(scope_candidates):
    content = attempted_contents[rel]
    try:
        tree = ast.parse(content.decode("utf-8", errors="replace"), filename=rel)
    except SyntaxError:
        skipped_files.append(rel)
        continue
    scope_files_read.append(rel)

    added_set = added_lines.get(rel, set())

    # Collect added string literals (ast.Constant(str) with lineno in added_set).
    added_str_nodes = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            if node.lineno in added_set:
                s = node.value
                if len(s) < STRING_LEN_FLOOR:
                    continue
                if is_numeric_only_string(s):
                    continue
                added_str_nodes.append(node)

    if not added_str_nodes:
        continue

    parent_map = build_parent_map(tree)

    # Collect candidate collections. Must have ≥3 string elements, all strings
    # (no partial-match), and no element's lineno in added_set → unchanged.
    candidate_collections = []
    for node in ast.walk(tree):
        # Skip inner Set/List/Tuple whose parent is a `frozenset(...)` Call —
        # the outer Call is the authoritative collection node; otherwise we
        # double-emit on the same allowlist.
        parent = parent_map.get(id(node))
        if isinstance(node, (ast.Set, ast.List, ast.Tuple)) \
                and isinstance(parent, ast.Call) \
                and isinstance(parent.func, ast.Name) \
                and parent.func.id == "frozenset":
            continue
        str_elts = collection_element_nodes(node)
        if str_elts is None:
            continue
        if not all_elements_are_strings(node):
            continue
        # Keep only non-numeric, length >= floor. For pattern purposes we still
        # need all elements to share a pattern; numeric / too-short reject
        # the whole collection.
        if any(is_numeric_only_string(e.value) for e in str_elts):
            continue
        if any(len(e.value) < STRING_LEN_FLOOR for e in str_elts):
            continue
        if len(str_elts) < 3:
            continue
        # Unchanged: no element's lineno in added_set, AND the collection
        # literal's own line range has no overlap with added_set (catches the
        # case of an opening-brace add line without a new string element —
        # the allowlist was reformatted in the diff, treat as changed).
        collection_touched = any(e.lineno in added_set for e in str_elts)
        if collection_touched:
            continue
        start, end = collection_lineno_range(node)
        # Also skip if any line in the range overlaps added_set (catches diff
        # edits inside the collection that don't land on a string element).
        overlap = any((ln in added_set) for ln in range(start, end + 1))
        if overlap:
            continue
        candidate_collections.append((node, str_elts))

    for L_node in added_str_nodes:
        L = L_node.value
        for C_node, C_str_elts in candidate_collections:
            C_values = [e.value for e in C_str_elts]
            pattern = shared_pattern(C_values, L)
            if pattern is None:
                continue
            # `L` must NOT already be in the collection.
            if L in C_values:
                continue
            consumer_symbol, consumer_line = resolve_consumer_symbol(
                C_node, parent_map)
            canonical_payload = {
                "primary_file": rel,
                "marker_literal": L,
                "consumer_symbol": consumer_symbol,
                "add_site_line": L_node.lineno,
                "consumer_line": consumer_line,
                "allowlist_size": len(C_values),
                "shared_pattern": pattern,
            }
            # Pattern description text: trailing_<char> or leading_<prefix>.
            if pattern.startswith("trailing_"):
                ch = pattern[len("trailing_"):]
                pattern_prose = f"all end with '{ch}'"
            else:
                prefix = pattern[len("leading_"):]
                pattern_prose = f"all start with '{prefix}'"
            description = (
                f"Marker '{L}' added at line {L_node.lineno} matches the "
                f"structural pattern of {len(C_values)} existing allowlist "
                f"entries in {consumer_symbol} (line {consumer_line}) — "
                f"{pattern_prose}. The allowlist was not updated to include "
                f"the new marker. Unchanged consumer likely drops values "
                f"carrying this marker."
            )
            fix = (
                f"Either add '{L}' to the allowlist in {consumer_symbol}, OR "
                f"document in the spec §2 Current State why the new marker "
                f"is deliberately out of the consumer's scope."
            )
            findings.append({
                "provisional_id": f"pE-{len(findings) + 1}",
                "sources": [f"probe:{PROBE_ID}"],
                "severity": "HIGH",
                "title": "New marker added; same-file consumer allowlist unchanged",
                "file": f"{rel}:{consumer_line}",
                "description": description,
                "fix": fix,
                "fingerprint_anchors": {
                    "primary_file": rel,
                    "marker_literal": L,
                    "consumer_symbol": consumer_symbol,
                },
                "canonical_payload": canonical_payload,
            })


# --- emitted_at (deterministic seam for fixtures) ----------------------------
emitted_at = os.environ.get("PROBE_E_FAKE_NOW")
if not emitted_at:
    emitted_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# --- Assemble output ---------------------------------------------------------
n = len(findings)
eligible_reason = (
    f"{n} same-file allowlist-leak candidate detected" if n == 1
    else f"{n} same-file allowlist-leak candidates detected"
)

receipt_metadata = {
    "probe_id": PROBE_ID,
    "probe_version": PROBE_VERSION,
    "trigger_input_hash": trigger_input_hash,
    "scope_files_read": scope_files_read,
    "skipped_files": skipped_files,
    "emitted_at": emitted_at,
    "degraded_mode": False,
    "eligible_reason": eligible_reason,
}

out = {"findings": findings, "receipt_metadata": receipt_metadata}
sys.stdout.write(
    json.dumps(out, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    + "\n"
)
PY
