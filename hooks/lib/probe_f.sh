#!/usr/bin/env bash
# probe_f.sh — cross-audit probe F (cardinality blindness — missing-cursor
# detector, v1 Python code-mode) per spec
# 2026-04-21-probe-f-cardinality-blindness §3.4.
#
# stdin envelope (§3.3, shared shape with probe E):
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
# Determinism seam: when PROBE_F_FAKE_NOW env var is set, receipt_metadata's
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


PROBE_ID = "F"
PROBE_VERSION = "f.1.0"


# --- §3.4 authoritative constants -------------------------------------------
# `.all()` deliberately excluded from v1 PAGING_METHODS (high SQLAlchemy-
# lookup false-positive rate per §3.4 + §3.9).
PAGING_METHODS = frozenset({
    "limit", "paginate", "order", "iterator", "iter_pages",
})

DISCIPLINE_PARAMS = frozenset({
    "cursor", "after", "after_cursor", "since",
    "pagination_token", "next_token", "from_marker", "starting_after",
})

# DISCIPLINE_KEYWORDS are applied to the enclosing function's docstring only
# (ast.Expr(ast.Constant(str)) as body[0]). Match semantics: case-insensitive
# substring with word-boundary enforcement; `budget:` uses a left word
# boundary plus the literal colon (non-word char — no right-\b). Per §3.4
# Authoritative-source note.
DISCIPLINE_KEYWORDS = (
    "cardinality",
    "ref_cardinality",
    "perf_budget",
    "budget:",
    "years of history",
    "n records",
)


def _build_discipline_keyword_re():
    """Compile DISCIPLINE_KEYWORDS into a single case-insensitive regex.

    Per §3.4 Authoritative-source note:
    - Build by OR-joining re.escape(kw) for each keyword.
    - Adjust `\\b` anchors per keyword's end character: right-`\\b` only when
      the keyword ends on a word character. `budget:` ends in `:` (non-word),
      so only a left `\\b` is applied; `cardinality`, `perf_budget`, etc. get
      both anchors.
    """
    parts = []
    for kw in DISCIPLINE_KEYWORDS:
        escaped = re.escape(kw)
        last = kw[-1]
        left = r"\b"
        right = r"\b" if last.isalnum() or last == "_" else ""
        parts.append(left + escaped + right)
    pattern = "(?:" + "|".join(parts) + ")"
    return re.compile(pattern, re.IGNORECASE)


DISCIPLINE_KEYWORD_RE = _build_discipline_keyword_re()


# --- Test-file detection (§3.4 step 1, identical to probe E) ----------------
TEST_DIR_RE = re.compile(r"(^|/)(tests?|__tests__)(/|$)")
TEST_FILE_RE = re.compile(r"(^|/)(test_[^/]+|[^/]+_test)\.py$")


def is_test_path(rel):
    if TEST_DIR_RE.search(rel):
        return True
    if TEST_FILE_RE.search(rel):
        return True
    return False


def die(msg, code=2):
    sys.stderr.write(f"probe_f.sh: {msg}\n")
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


def build_parent_map(tree):
    parent_map = {}
    for parent in ast.walk(tree):
        for child in ast.iter_child_nodes(parent):
            parent_map[id(child)] = parent
    return parent_map


def resolve_enclosing_function(node, parent_map):
    """§3.4 step 3 — walk up from node to find the nearest enclosing
    FunctionDef or AsyncFunctionDef. Returns the function node, or None if
    no enclosing function exists (module-level / class-body-direct).
    """
    cur = parent_map.get(id(node))
    while cur is not None:
        if isinstance(cur, (ast.FunctionDef, ast.AsyncFunctionDef)):
            return cur
        cur = parent_map.get(id(cur))
    return None


def function_has_cursor_param(func_node):
    """§3.4 step 4 — inspect function.args.* for any name (case-insensitive)
    in DISCIPLINE_PARAMS.
    """
    args = func_node.args
    names = []
    for a in getattr(args, "args", []) or []:
        if a is not None:
            names.append(a.arg)
    for a in getattr(args, "posonlyargs", []) or []:
        if a is not None:
            names.append(a.arg)
    for a in getattr(args, "kwonlyargs", []) or []:
        if a is not None:
            names.append(a.arg)
    vararg = getattr(args, "vararg", None)
    if vararg is not None:
        names.append(vararg.arg)
    kwarg = getattr(args, "kwarg", None)
    if kwarg is not None:
        names.append(kwarg.arg)
    for n in names:
        if n.lower() in DISCIPLINE_PARAMS:
            return True
    return False


def function_has_docstring_discipline(func_node):
    """§3.4 step 4 — inspect body[0] for a string-constant docstring and
    scan it against DISCIPLINE_KEYWORD_RE.
    """
    body = getattr(func_node, "body", []) or []
    if not body:
        return False
    first = body[0]
    if not isinstance(first, ast.Expr):
        return False
    val = getattr(first, "value", None)
    if not isinstance(val, ast.Constant):
        return False
    if not isinstance(val.value, str):
        return False
    return bool(DISCIPLINE_KEYWORD_RE.search(val.value))


for rel in sorted(scope_candidates):
    content = attempted_contents[rel]
    try:
        tree = ast.parse(content.decode("utf-8", errors="replace"), filename=rel)
    except SyntaxError:
        skipped_files.append(rel)
        continue
    scope_files_read.append(rel)

    added_set = added_lines.get(rel, set())

    parent_map = build_parent_map(tree)

    # §3.4 step 2 — collect paging-marker call nodes on added lines.
    paging_marker_calls = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        if not isinstance(node.func, ast.Attribute):
            continue
        if node.func.attr not in PAGING_METHODS:
            continue
        if node.lineno not in added_set:
            continue
        paging_marker_calls.append(node)

    if not paging_marker_calls:
        continue

    # §3.4 step 3 — group calls by their enclosing FunctionDef/AsyncFunctionDef.
    # Skip markers with no enclosing function (module-level / class-body-direct
    # anti-goal in v1).
    calls_by_function = {}  # id(func) → (func_node, [call_node, ...])
    for call in paging_marker_calls:
        func = resolve_enclosing_function(call, parent_map)
        if func is None:
            continue  # §3.4 anti-goal — no module-level detection in v1
        key = id(func)
        if key not in calls_by_function:
            calls_by_function[key] = (func, [])
        calls_by_function[key][1].append(call)

    # §3.4 step 4 — discipline check per enclosing function; emit one finding
    # per disciplined-negative function via §3.4 step 5 multi-marker collapse.
    # Preserve a stable per-file order: emit by ascending function.lineno so
    # findings within a file are deterministic regardless of walk order.
    for func, calls in sorted(calls_by_function.values(),
                              key=lambda pair: pair[0].lineno):
        if function_has_cursor_param(func):
            continue  # discipline found — skip all markers in this function
        if function_has_docstring_discipline(func):
            continue  # discipline found — skip all markers in this function

        # §3.4 step 5 — collapse multi-marker to one finding.
        # Winner: ascending (lineno, end_col_offset). Within a line, smallest
        # end_col_offset wins — picks .limit over .order in chained calls.
        def _sort_key(c):
            return (c.lineno, getattr(c, "end_col_offset", c.col_offset) or 0)
        winner = min(calls, key=_sort_key)
        paging_symbol = "." + winner.func.attr
        canonical_payload = {
            "primary_file": rel,
            "paging_symbol": paging_symbol,
            "failure_kind": "missing_cursor",
            "enclosing_function": func.name,
            "add_site_line": winner.lineno,
            "function_line": func.lineno,
            "discipline_params_observed": [],
            "discipline_keywords_observed": [],
        }
        description = (
            f"`{paging_symbol}` call added at line {winner.lineno} inside "
            f"function `{func.name}` (line {func.lineno}). The function "
            f"signature has no cursor-discipline parameter (see §3.4 "
            f"`DISCIPLINE_PARAMS` authoritative set) and its docstring "
            f"carries no cardinality keyword (see §3.4 "
            f"`DISCIPLINE_KEYWORDS` authoritative set). Code may time out "
            f"under production cardinality."
        )
        fix = (
            "Either (a) add a cursor parameter to the function signature "
            "and seek from recent rather than genesis, (b) add a docstring "
            "naming the cardinality budget (e.g. `assumes ≤ 10k records; "
            "budget: 5s wall-time`), OR (c) document in the spec §2 "
            "Current State why unbounded iteration is deliberate."
        )
        findings.append({
            "provisional_id": f"pF-{len(findings) + 1}",
            "sources": [f"probe:{PROBE_ID}"],
            "severity": "HIGH",
            "title": "Pagination marker added; enclosing function lacks cardinality discipline",
            "file": f"{rel}:{winner.lineno}",
            "description": description,
            "fix": fix,
            "fingerprint_anchors": {
                "primary_file": rel,
                "paging_symbol": paging_symbol,
                "failure_kind": "missing_cursor",
            },
            "canonical_payload": canonical_payload,
        })


# --- emitted_at (deterministic seam for fixtures) ----------------------------
emitted_at = os.environ.get("PROBE_F_FAKE_NOW")
if not emitted_at:
    emitted_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# --- Assemble output ---------------------------------------------------------
n = len(findings)
if n == 1:
    eligible_reason = "1 paging-marker add in function lacking cursor-discipline"
else:
    eligible_reason = f"{n} paging-marker adds in functions lacking cursor-discipline"

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
