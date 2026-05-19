#!/usr/bin/env bash
# resolve_rule_path.sh — deterministic R-rule path resolver.
#
# Resolves the path to skills/feature/references/code-quality-rules.md for the
# cross-auditor's R-rule loader. This replaces the LLM-prose path-resolution
# logic with a deterministic, fixture-tested helper.
#
# Invocation: resolve_rule_path.sh   (no args)
#
# Exit codes — a 2-way partition:
#   0  resolved     (stdout: the resolved absolute path)
#   3  unreachable  (stderr: "⚠ code-quality-rules.md not reachable")
#
# Strict env-first ("C2 closure"): when ${CLAUDE_PLUGIN_ROOT} is set to an
# absolute path, the resolver resolves UNCONDITIONALLY under it — there is NO
# relative fallback. The relative path is consulted ONLY when the env var is
# unset. A set-but-empty value and a relative-path value are distinct
# unreachable states (exit 3, NO relative fallback) — fail-loud on operator
# misconfiguration.
#
# Every resolved row requires the target be an existing REGULAR FILE
# (os.path.isfile) that is READABLE — a directory or special file named
# code-quality-rules.md does NOT resolve.
#
# The plugin checkout root is computed from THIS script's own location
# (${BASH_SOURCE[0]} -> realpath -> ascend two dirs: hooks/lib/ -> root), NOT
# from cwd. The env-unset relative-path branch is realpath-guarded by a
# separator-safe os.path.commonpath containment test so a target-repo shadow
# file AND a sibling <root>-shadow/... directory are both rejected.
#
# All canonicalization uses python3 os.path.realpath (stdlib, portable) — NOT
# the realpath(1) binary, which is absent on stock macOS.

set -u

REL_PATH='skills/feature/references/code-quality-rules.md'
WARN='⚠ code-quality-rules.md not reachable'

# Absolute path to this script (for the checkout-root computation).
SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"

# The whole decision is delegated to python3 (stdlib): realpath, isfile,
# os.access, commonpath are all needed and python3 is the established pattern.
result=$(
  CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT-__UNSET__}" \
  python3 - "$SCRIPT_SOURCE" "$REL_PATH" <<'PYEOF'
import os, sys

script_source, rel_path = sys.argv[1], sys.argv[2]
env = os.environ.get("CLAUDE_PLUGIN_ROOT", "__UNSET__")
UNSET = env == "__UNSET__"


def emit_resolved(path):
    # stdout line consumed by the bash wrapper.
    sys.stdout.write("OK\t" + path)
    sys.exit(0)


def emit_unreachable():
    sys.stdout.write("UNREACHABLE")
    sys.exit(0)


def usable_regular_file(path):
    """True iff path is an existing regular file that is readable."""
    return os.path.isfile(path) and os.access(path, os.R_OK)


if not UNSET:
    # --- env var IS set: strict env-first, no relative fallback ---
    if env == "":
        # set-but-empty — distinct unreachable state.
        emit_unreachable()
    if not env.startswith("/"):
        # relative env value — rejected (no cwd canonicalization).
        emit_unreachable()
    # absolute-path env value — resolve unconditionally under it.
    candidate = os.path.realpath(os.path.join(env, rel_path))
    if usable_regular_file(candidate):
        emit_resolved(candidate)
    emit_unreachable()

# --- env var is UNSET: realpath-guarded relative path ---
# Plugin checkout root = realpath(script) ascended two dirs (hooks/lib/ -> root).
script_real = os.path.realpath(script_source)
checkout_root = os.path.dirname(os.path.dirname(os.path.dirname(script_real)))
candidate = os.path.realpath(rel_path)

if not os.path.exists(candidate):
    emit_unreachable()

# Separator-safe containment: commonpath compares whole path components, so a
# sibling "<root>-shadow" is NOT treated as living under "<root>".
try:
    inside = os.path.commonpath([checkout_root, candidate]) == checkout_root
except ValueError:
    # Different drives / one path relative — not inside.
    inside = False

if not inside:
    emit_unreachable()

if usable_regular_file(candidate):
    emit_resolved(candidate)
emit_unreachable()
PYEOF
)

case "$result" in
  OK$'\t'*)
    printf '%s\n' "${result#OK$'\t'}"
    exit 0
    ;;
  *)
    echo "$WARN" >&2
    exit 3
    ;;
esac
