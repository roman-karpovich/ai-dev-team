#!/usr/bin/env bash
# tests/smoke-helpers-check-wiring.sh — structural integrity check for
# done-verified-migration Step 5 smoke.sh wiring (spec §3.9a).
# Bash-3.2 compatible (macOS default). Exits 0 on success (prints STEP5_OK),
# 1 with diagnostic on any inconsistency.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PLUGIN_ROOT"
S=tests/smoke.sh

# Assertion 1: each of the 8 check-invocation lines appears exactly once.
# Check-name == fn-name convention; invocations placed at column 1 per house style.
for name in \
  check_librarian_status_block_canonical \
  check_discard_mode_refuses_verified_shipped \
  check_feature_skill_no_active_done_writes \
  check_developer_workflow_no_active_done_writes \
  check_smoke_helper_librarian_rejects_stale \
  check_smoke_helper_discard_mode_rejects_stale \
  check_smoke_helper_feature_skill_rejects_stale \
  check_smoke_helper_developer_workflow_rejects_stale; do
  n=$(grep -cE "^check \"$name\" $name(\\b|$)" "$S" || true)
  [ "$n" -eq 1 ] || { echo "FAIL: expected exactly 1 'check \"$name\" $name ...' line, got $n"; exit 1; }
done

# Assertion 2: each of the 4 negative wrapper function definitions exists exactly once.
for w in librarian discard_mode feature_skill developer_workflow; do
  n=$(grep -cE "^check_smoke_helper_${w}_rejects_stale\\(\\)" "$S" || true)
  [ "$n" -eq 1 ] || { echo "FAIL: expected 1 def 'check_smoke_helper_${w}_rejects_stale()', got $n"; exit 1; }
done

# Assertion 3: each wrapper body must include three substrings that together
# prove (a) the negation `!` is present, (b) the rejection guard fires with
# the correct diagnostic, (c) the success echo confirms rejection. A wrapper
# missing any of the three is a stub and fails the check. (bash-3.2: use
# a plain function + parallel args instead of `declare -A`.)
assert_wrapper_body() {
  local wrapper="$1" helper="$2" fixture_path="$3" fixture_basename="$4" slug="$5"
  local body
  body=$(awk -v w="^${wrapper}\\\\(\\\\)" '$0 ~ w {f=1; next} f && /^}/ {exit} f' "$S")
  printf '%s\n' "$body" | grep -qF "! $helper '$fixture_path'" \
    || { echo "FAIL: $wrapper missing negation '! $helper <fixture>'"; exit 1; }
  printf '%s\n' "$body" | grep -qF "$helper wrongly accepted $fixture_basename" \
    || { echo "FAIL: $wrapper missing rejection guard diagnostic for $fixture_basename"; exit 1; }
  printf '%s\n' "$body" | grep -qF "$helper correctly rejected stale $slug fixture" \
    || { echo "FAIL: $wrapper missing success echo for $slug"; exit 1; }
}
assert_wrapper_body \
  check_smoke_helper_librarian_rejects_stale \
  check_librarian_status_block_canonical \
  tests/fixtures/done-verified-migration/librarian-stale.md \
  librarian-stale.md \
  librarian
assert_wrapper_body \
  check_smoke_helper_discard_mode_rejects_stale \
  check_discard_mode_refuses_verified_shipped \
  tests/fixtures/done-verified-migration/discard-mode-stale.md \
  discard-mode-stale.md \
  discard-mode
assert_wrapper_body \
  check_smoke_helper_feature_skill_rejects_stale \
  check_feature_skill_no_active_done_writes \
  tests/fixtures/done-verified-migration/skill-md-stale.md \
  skill-md-stale.md \
  skill-md
assert_wrapper_body \
  check_smoke_helper_developer_workflow_rejects_stale \
  check_developer_workflow_no_active_done_writes \
  tests/fixtures/done-verified-migration/developer-workflow-stale.md \
  developer-workflow-stale.md \
  developer-workflow

# Assertion 4: actual smoke run passes with all 8 new PASS lines and Failed: 0.
# Guard against set -e swallowing the non-zero exit before rc capture.
if bash tests/smoke.sh > /tmp/smoke-dv.out 2>&1; then rc=0; else rc=$?; fi
passes=$(grep -cE '^  PASS  (check_librarian_status_block_canonical|check_discard_mode_refuses_verified_shipped|check_feature_skill_no_active_done_writes|check_developer_workflow_no_active_done_writes|check_smoke_helper_librarian_rejects_stale|check_smoke_helper_discard_mode_rejects_stale|check_smoke_helper_feature_skill_rejects_stale|check_smoke_helper_developer_workflow_rejects_stale)$' /tmp/smoke-dv.out || true)
failed_count=$(grep '^Failed: ' /tmp/smoke-dv.out | head -1 | awk '{print $2}')
if [ "$rc" -ne 0 ] || [ "$passes" -ne 8 ] || [ "$failed_count" != "0" ]; then
  echo "FAIL: smoke run rc=$rc passes=$passes failed=$failed_count"
  tail -40 /tmp/smoke-dv.out
  exit 1
fi

echo STEP5_OK
