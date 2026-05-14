---
title: Audit Findings — malformed-no-file-line fixture
project: ai-dev-team
type: audit-findings
mode: spec
iteration: 1
created: 2026-05-14
evidence_class: dual_model
evidence_blockers: []
tags: [audit, ai-dev-team, fixture, malformed, x1-code-audit]
fixture_purpose: |
  Synthetic findings.md exercising the MALFORMED-FINDING diagnostic class
  added by code-audit X1 fix on 2026-05-14. Every H3 block has a parseable
  `### [X<n>] <title>` heading and the `## Details` section is present,
  but EVERY block is missing the canonical `- **File**: <path>:<line>` line.

  Pre-X1 behavior: helper silently skipped all blocks → exit 0 with
  "Total: 0 findings, 0 mismatches" — the empirical-verification gate was
  defeated precisely when upstream auditor failure is most severe.

  Post-X1 behavior: helper emits one `Xn: MALFORMED-FINDING <reason>`
  diagnostic per parseable-heading-but-no-File-line block; counts each
  into the mismatch tally; exits 1.
expected_helper_output: |
  X1 MALFORMED-FINDING missing `- **File**: <path>:<line>` line in Details body
  X2 MALFORMED-FINDING missing `- **File**: <path>:<line>` line in Details body
  X3 MALFORMED-FINDING missing `- **File**: <path>:<line>` line in Details body
  Total: 0 findings, 3 mismatches; exit 1.
---

# Audit Findings: malformed-no-file-line fixture

- Date: 2026-05-14
- Iteration: 1
- Mode: spec
- Codex: OK
- Status: IN PROGRESS

## Summary

| ID | Severity | Issue | Source | Mode | Confidence | Status |
|----|----------|-------|--------|------|------------|--------|
| X1 | HIGH | H3 block missing File line | claude | | 80 | OPEN |
| X2 | HIGH | H3 block missing File line | claude | | 80 | OPEN |
| X3 | HIGH | H3 block missing File line | claude | | 80 | OPEN |

## Details

### [X1] First malformed block — no File line
- **Severity**: HIGH
- **Found by**: Only Claude
- **Description**: This block has a parseable H3 heading and a Description, but no `- **File**: <path>:<line>` line. Helper MUST flag MALFORMED-FINDING (pre-X1 behavior: silent skip).
- **Fix**: N/A — fixture is intentionally malformed.
- **Sources**: [claude]
- **Status**: OPEN

### [X2] Second malformed block — no File line
- **Severity**: HIGH
- **Found by**: Only Claude
- **Description**: Same shape as X1 — heading parseable, File line absent. Helper MUST flag MALFORMED-FINDING.
- **Fix**: N/A — fixture is intentionally malformed.
- **Sources**: [claude]
- **Status**: OPEN

### [X3] Third malformed block — no File line
- **Severity**: HIGH
- **Found by**: Only Claude
- **Description**: Third malformed block to verify the helper emits one diagnostic per block (not a single aggregated diagnostic). Helper MUST flag MALFORMED-FINDING.
- **Fix**: N/A — fixture is intentionally malformed.
- **Sources**: [claude]
- **Status**: OPEN
