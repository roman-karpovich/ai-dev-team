---
title: An In-Progress Spec Awaiting Hand-off (c5)
project: fixture
type: spec
status: IN_PROGRESS
code_audit_evidence: null
created: 2026-05-31
tags: [spec, fixture]
---

# An In-Progress Spec Awaiting Hand-off (c5)

The load-bearing anti-FP case: the code-audit phase wrote the 'code audit
passed' Log marker while status STAYS IN_PROGRESS until hand-off (per
skills/feature/SKILL.md §Verify/§3.4a). IN_PROGRESS is EXCLUDED from
PRE_TERMINAL_SPEC_STATUSES → no C4. This fixture differs from the drift
Log-marker fixture ONLY in status (IN_PROGRESS vs AUDIT_PASSED).

## Log

- 2026-05-12: code audit passed; iteration=3
