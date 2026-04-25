# spec-compliance-checker R3 wrong-section fixture

Minimal markdown used by tests/smoke.sh to verify that the compliance-checker
R3 helpers in tests/smoke-helpers.sh are section-scoped and byte-exact, not
whole-file greps. Canonical tokens are planted in a spoof section only.

A correct helper rejects this fixture (no load-bearing content in the right
sections). A buggy whole-file-grep implementation accepts it — that is exactly
the bug class (X1 + X2) this fixture catches.

#### R3 — Test strength / weak-phrase regex check

This subsection is intentionally empty of any canonical content.

Loose-token bait is noncanonical by design: ignore assertIsNotNone — deferred;
ignore call_count — deferred.

### 6. Return verdict

This section intentionally omits the R3 line from the ### Code quality block.

### Code quality
- R1 (dead-code cleanup): <clean>
- R2 (fresh tests in green capture): <none>

## Rules

This section intentionally omits the R3 DRIFT bullet.

- You do NOT fix anything. You only report.

## Spoof Section

Tokens planted here to spoof whole-file and loose-token helpers:
assertIsNotNone, call_count, assert_called_once, assert_called_with, weak-phrase, DRIFT — R3.
Loose regex anchors also planted: \bassertIsNotNone\b, \bcall_count\s*==.
