---
title: Synthetic spec — workdoc-assertion-count-parity fixture
type: spec-fixture
project: ai-dev-team
---

# Synthetic spec for WAP helper behavioral pin

This file is read by `tests/workdoc_parity_check.py` only via the §6.1 parser.
It exercises INV-2 cross-check for the paired `workdoc.md` fixture:

- Step 1: spec parenthetical matches workdoc `expected_pass_pattern` (3 == 3) — OK.
- Step 2: spec parenthetical (7) disagrees with workdoc `expected_pass_pattern` (5) — INV-2 mismatch.
- Step 3: no parenthetical on the bullet — INV-2 N/A (workdoc Step 3 is already
  N/A by INV-1 because `expected_pass_pattern` is not integer).

## 6.1 Automated verification

- **Step 1**: Helper detects parity step correctly. AND counts three `n=$((n+1))`
  occurrences. AND emits an `OK` verdict line. (3 expected_pass increments.)
- **Step 2**: Helper detects INV-1 mismatch. AND emits `DRIFT INV-1`. AND emits
  `DRIFT INV-2` since the workdoc value disagrees with this parenthetical too.
  (7 expected_pass increments.)
- **Step 3**: Helper detects N/A class. AND emits a single `N/A` verdict line.

## 9. Log

Synthetic fixture — no real history.
