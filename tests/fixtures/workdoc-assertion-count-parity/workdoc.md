---
title: Synthetic workdoc — workdoc-assertion-count-parity fixture
type: exec-workdoc-fixture
spec: spec.md
---

# Synthetic workdoc for WAP helper behavioral pin

Three steps, each exercising a different class:

- Step 1: inline `passing_test_cmd` form, 3 `n=$((n+1))` occurrences, `expected_pass_pattern: "3"` → INV-1 OK + INV-2 OK against spec §6.1 parenthetical of 3.
- Step 2: block-`|` `passing_test_cmd` form, 4 `n=$((n+1))` occurrences, `expected_pass_pattern: "5"` → INV-1 DRIFT; spec §6.1 parenthetical of 7 also disagrees → INV-2 DRIFT.
- Step 3: non-integer `expected_pass_pattern: "Failed: 0"`, no n+1 counter → INV-1 N/A; spec has no parenthetical on Step 3 → INV-2 N/A → single N/A line.

---

## Step 1: Parity step (inline form, 3 == 3)

### Planned
goal: Exercise the inline `passing_test_cmd` parser path with three increments matching `expected_pass_pattern: "3"`.
allowed_scope: tests/fixtures/workdoc-assertion-count-parity/**
failing_test_cmd: bash -c 'echo 0'
expected_failure_pattern: "0"
passing_test_cmd: bash -c 'n=0; n=$((n+1)); n=$((n+1)); n=$((n+1)); echo $n'
expected_pass_pattern: "3"
integration_probe_cmd: bash -c 'echo OK'
expected_probe_signal: OK

### Observed
actual_files_touched: []
commit_shas: []
notes: ""

---

## Step 2: INV-1 + INV-2 mismatch (block form, 4 actual / 5 expected / spec says 7)

### Planned
goal: Exercise the block-`|` `passing_test_cmd` parser path. Four `n=$((n+1))` occurrences but `expected_pass_pattern: "5"` — INV-1 DRIFT. Spec §6.1 says 7 — INV-2 DRIFT.
allowed_scope: tests/fixtures/workdoc-assertion-count-parity/**
failing_test_cmd: |
  bash -c 'set -e; n=0;
  test 1 -eq 1 && n=$((n+1));
  test 1 -eq 1 && n=$((n+1));
  test 1 -eq 1 && n=$((n+1));
  test 1 -eq 1 && n=$((n+1));
  echo $n'
expected_failure_pattern: "4"
passing_test_cmd: |
  bash -c 'set -e; n=0;
  test 2 -eq 2 && n=$((n+1));
  test 2 -eq 2 && n=$((n+1));
  test 2 -eq 2 && n=$((n+1));
  test 2 -eq 2 && n=$((n+1));
  echo $n'
expected_pass_pattern: "5"
integration_probe_cmd: bash -c 'echo OK'
expected_probe_signal: OK

### Observed
actual_files_touched: []
commit_shas: []
notes: ""

---

## Step 3: N/A skip (non-integer expected_pass_pattern, no n+1 counter)

### Planned
goal: Exercise the N/A code path. `expected_pass_pattern` is the literal smoke summary line — not a pure integer — so INV-1 does not apply. Spec §6.1 omits the parenthetical for Step 3 so INV-2 does not apply either.
allowed_scope: tests/fixtures/workdoc-assertion-count-parity/**
failing_test_cmd: bash -c 'echo "Failed: 1"'
expected_failure_pattern: "Failed: 1"
passing_test_cmd: bash -c 'echo "Failed: 0"'
expected_pass_pattern: "Failed: 0"
integration_probe_cmd: bash -c 'echo OK'
expected_probe_signal: OK

### Observed
actual_files_touched: []
commit_shas: []
notes: ""
