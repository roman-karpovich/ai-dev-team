---
title: Audit Findings — synthetic-known-wrong fixture
project: ai-dev-team
type: audit-findings
mode: spec
iteration: 1
created: 2026-05-14
evidence_class: dual_model
evidence_blockers: []
tags: [audit, ai-dev-team, fixture, known-wrong]
fixture_purpose: |
  Synthetic findings.md exercising tests/check_finding_claims.py against
  ground-truth-wrong file:line claims at HEAD d29b0cf. Used by the
  behavioral pin check_finding_claims_helper_flags_known_wrong_fixture.

  Each finding below has its claim's wrongness empirically verified against
  the live repo at HEAD d29b0cf BEFORE writing this fixture — this fixture
  authoring is itself an exercise of R15 (the rule the spec codifies).
expected_helper_output: |
  X1 MISMATCH agents/cross-auditor.md:99 (Step 2.5 H2 is at L119, not L99)
  X2 MISMATCH skills/feature/SKILL.md:42 (cap banner literal at L561, L42 is frontmatter terminator)
  X3 LINE-OUT-OF-RANGE agents/cross-auditor.md:9999 (file has 146 lines)
  X4 FILE-MISSING nonexistent/path.md (path does not exist)
  X5 OK agents/cross-auditor.md:113 (Step 2 H2 actually at L113 — control case)
  Total: 5 findings, 4 mismatches; exit 1.
---

# Audit Findings: synthetic-known-wrong fixture

- Date: 2026-05-14
- Iteration: 1
- Mode: spec
- Codex: OK
- Status: IN PROGRESS

## Summary

| ID | Severity | Issue | Source | Mode | Confidence | Status |
|----|----------|-------|--------|------|------------|--------|
| X1 | HIGH | Step 2.5 H2 line claim is wrong | claude | | 80 | OPEN |
| X2 | HIGH | Cap banner literal line claim is wrong | claude | | 80 | OPEN |
| X3 | HIGH | Out-of-range line claim | claude | | 80 | OPEN |
| X4 | HIGH | File-missing path claim | claude | | 80 | OPEN |
| X5 | HIGH | Control claim — should verify OK | claude | | 80 | OPEN |

## Details

### [X1] Step 2.5 H2 mis-anchored
- **Severity**: HIGH
- **Found by**: Only Claude
- **File**: agents/cross-auditor.md:99
- **Description**: The Step 2.5 H2 should be at this line — the heading literal `## Step 2.5: Empirical claim verification` is expected here per the auditor's claim.
- **Fix**: Re-verify; helper must flag MISMATCH because the actual line content differs.
- **Sources**: [claude]
- **Status**: OPEN

### [X2] Cap banner line claim wrong
- **Severity**: HIGH
- **Found by**: Only Claude
- **File**: skills/feature/SKILL.md:42
- **Description**: Cap banner literal `Audit iteration cap reached` should sit at this line per the auditor's claim.
- **Fix**: Helper must flag MISMATCH — the banner is elsewhere; this is a known-wrong line drift.
- **Sources**: [claude]
- **Status**: OPEN

### [X3] Line number out of range
- **Severity**: HIGH
- **Found by**: Only Claude
- **File**: agents/cross-auditor.md:9999
- **Description**: Phantom finding at non-existent line; literal `## Step 2: Claude Audit` claimed at L9999.
- **Fix**: Helper must flag LINE-OUT-OF-RANGE.
- **Sources**: [claude]
- **Status**: OPEN

### [X4] File missing
- **Severity**: HIGH
- **Found by**: Only Claude
- **File**: nonexistent/path.md:1
- **Description**: Claim against a path that does not exist; literal `irrelevant` expected.
- **Fix**: Helper must flag FILE-MISSING.
- **Sources**: [claude]
- **Status**: OPEN

### [X5] Control — claim should verify OK
- **Severity**: HIGH
- **Found by**: Only Claude
- **File**: agents/cross-auditor.md:113
- **Description**: The Step 2 H2 sits at this line — literal `## Step 2: Claude Audit (you)` expected and present.
- **Fix**: None — control case for OK path; helper must NOT flag this one.
- **Sources**: [claude]
- **Status**: OPEN
