#!/usr/bin/env bash
# tests/smoke-helpers-check-phase0-wiring.sh — structural integrity check for
# shared-phase0 (spec 2026-04-20) Step 6 smoke.sh wiring.
# Bash-3.2 compatible (macOS default). Exits 0 on success (prints
# STEP_PHASE0_OK), 1 with diagnostic on any inconsistency.
#
# Asserts the 17-row (check-name, target-path) invocation matrix from spec
# §6.1 appears in tests/smoke.sh exactly once per row. A mis-wiring (e.g.
# duplicated SKILL.md path for helper #3 while missing another) fails even
# when the total stays at 17.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PLUGIN_ROOT"
S=tests/smoke.sh

# Assertion 1: 17-row invocation matrix (per spec §6.1). Each row asserts
# `grep -cF "check \"<name>\" <name> <path>"` equals exactly 1 (positive
# invocations with a path argument) OR `grep -cF "check \"<name>\" <name>"`
# equals exactly 1 with no trailing path (negative wrappers).
# Bash-3.2: use parallel args to a function (no `declare -A`).
assert_row() {
  local name="$1" path="$2"
  local needle
  if [ -n "$path" ]; then
    needle="check \"$name\" $name $path"
  else
    needle="check \"$name\" $name"
  fi
  local n
  n=$(grep -cF -- "$needle" "$S" || true)
  [ "$n" -eq 1 ] || { echo "FAIL: expected exactly 1 invocation '$needle', got $n"; exit 1; }
}

# Positive invocations (13 rows).
assert_row check_kb_discovery_doc_canonical             docs/kb-discovery.md
assert_row check_skill_phase0_references_shared_doc     skills/feature/SKILL.md
assert_row check_skill_phase0_references_shared_doc     skills/cross-audit/SKILL.md
assert_row check_skill_phase0_references_shared_doc     skills/research/SKILL.md
assert_row check_skill_phase0_extensions_present        skills/feature/SKILL.md
assert_row check_skill_phase0_extensions_present        skills/cross-audit/SKILL.md
assert_row check_skill_phase0_extensions_present        skills/research/SKILL.md
assert_row check_skill_phase0_no_inline_algorithm       skills/feature/SKILL.md
assert_row check_skill_phase0_no_inline_algorithm       skills/cross-audit/SKILL.md
assert_row check_skill_phase0_no_inline_algorithm       skills/research/SKILL.md
assert_row check_feature_phase0_mentions_codex_keys     skills/feature/SKILL.md
assert_row check_cross_audit_phase0_bans_model_fast     skills/cross-audit/SKILL.md
assert_row check_investigate_no_phase0                  skills/investigate/SKILL.md
# Negative wrappers (4 rows — no path arg).
assert_row check_smoke_helper_phase0_append_rejected      ""
assert_row check_smoke_helper_phase0_inline_rejected      ""
assert_row check_smoke_helper_phase0_investigate_rejected ""
assert_row check_smoke_helper_phase0_cross_audit_rejected ""

# Assertion 2: each of the 4 negative wrapper function definitions exists
# exactly once.
for w in append inline investigate cross_audit; do
  n=$(grep -cE "^check_smoke_helper_phase0_${w}_rejected\\(\\)" "$S" || true)
  [ "$n" -eq 1 ] || { echo "FAIL: expected 1 def 'check_smoke_helper_phase0_${w}_rejected()', got $n"; exit 1; }
done

# Assertion 3: each wrapper body carries the three-substring contract
# (negation `!` on the helper invocation, rejection guard diagnostic
# mentioning the fixture basename, success echo confirming rejection).
# Mirrors spec #1 `tests/smoke-helpers-check-wiring.sh` pattern.
# Bash-3.2: plain function + parallel positional args.
assert_wrapper_body() {
  local wrapper="$1" helper="$2" fixture_path="$3" fixture_basename="$4"
  local body
  body=$(awk -v w="^${wrapper}\\\\(\\\\)" '$0 ~ w {f=1; next} f && /^}/ {exit} f' "$S")
  printf '%s\n' "$body" | grep -qF "! $helper '$fixture_path'" \
    || { echo "FAIL: $wrapper missing negation '! $helper <fixture>'"; exit 1; }
  printf '%s\n' "$body" | grep -qF "$helper wrongly accepted $fixture_basename" \
    || { echo "FAIL: $wrapper missing rejection guard diagnostic for $fixture_basename"; exit 1; }
  printf '%s\n' "$body" | grep -qF "$helper correctly rejected stale" \
    || { echo "FAIL: $wrapper missing success echo"; exit 1; }
}
assert_wrapper_body \
  check_smoke_helper_phase0_append_rejected \
  check_skill_phase0_no_inline_algorithm \
  tests/fixtures/shared-phase0/feature-append-instead-of-replace.md \
  feature-append-instead-of-replace.md
assert_wrapper_body \
  check_smoke_helper_phase0_inline_rejected \
  check_skill_phase0_no_inline_algorithm \
  tests/fixtures/shared-phase0/feature-inline-algorithm.md \
  feature-inline-algorithm.md
assert_wrapper_body \
  check_smoke_helper_phase0_investigate_rejected \
  check_investigate_no_phase0 \
  tests/fixtures/shared-phase0/investigate-with-phase0.md \
  investigate-with-phase0.md
assert_wrapper_body \
  check_smoke_helper_phase0_cross_audit_rejected \
  check_cross_audit_phase0_bans_model_fast \
  tests/fixtures/shared-phase0/cross-audit-no-ban.md \
  cross-audit-no-ban.md

# Assertion 4: actual smoke run passes with exactly 17 new PASS lines for
# the shared-phase0 check names and Failed: 0. Guard against set -e
# swallowing the non-zero exit before rc capture.
if bash tests/smoke.sh > /tmp/smoke-phase0.out 2>&1; then rc=0; else rc=$?; fi
passes=$(grep -cE '^  PASS  (check_kb_discovery_doc_canonical|check_skill_phase0_references_shared_doc|check_skill_phase0_extensions_present|check_skill_phase0_no_inline_algorithm|check_investigate_no_phase0|check_feature_phase0_mentions_codex_keys|check_cross_audit_phase0_bans_model_fast|check_smoke_helper_phase0_append_rejected|check_smoke_helper_phase0_inline_rejected|check_smoke_helper_phase0_investigate_rejected|check_smoke_helper_phase0_cross_audit_rejected)$' /tmp/smoke-phase0.out || true)
failed_count=$(grep '^Failed: ' /tmp/smoke-phase0.out | head -1 | awk '{print $2}')
if [ "$rc" -ne 0 ] || [ "$passes" -ne 17 ] || [ "$failed_count" != "0" ]; then
  echo "FAIL: smoke run rc=$rc passes=$passes failed=$failed_count"
  tail -40 /tmp/smoke-phase0.out
  exit 1
fi

echo STEP_PHASE0_OK
