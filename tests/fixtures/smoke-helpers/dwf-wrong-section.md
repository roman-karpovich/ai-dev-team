# DWF wrong-section fixture

Minimal markdown used by tests/smoke.sh to behaviorally verify that the
developer-workflow.md section-scoped helpers in tests/smoke-helpers.sh
actually invoke extract_md_section against `## Code Quality Rules`,
`## Test Quality`, and `## Per-step protocol`. The canonical sentences are
placed in `## Other Section` below, NOT in the three target sections.

## Code Quality Rules

This section is intentionally empty of any canonical R3 short-form bullet.

## Test Quality

This section is intentionally empty of any canonical R3 pointer sentence.

## Per-step protocol

This section is intentionally empty of any canonical report.json notes
sentence.

## Other Section

- R3 test strength: see `code-quality-rules.md`.
- For test strength (whether a test actually catches regressions), see R3 in `code-quality-rules.md`.
- If the step adds or modifies a fresh test, `notes` MUST include a one-sentence description of the regression the test catches (see R3).
