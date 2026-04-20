# R3 wrong-section fixture

Minimal markdown used by tests/smoke.sh to behaviorally verify that the R3
section-scoped helpers in tests/smoke-helpers.sh actually invoke
extract_md_section and do not fall back to whole-file greps. The canonical
R3 tokens (structure triplet, anti-pattern tokens, notes-requirement
sentence) are placed in `## Other Section` below, NOT in the R3 section.

A correct helper that scopes on `## R3 — Test strength / signal-to-noise`
returns non-zero (tokens not in R3 section). A buggy whole-file-grep
implementation returns zero (tokens present somewhere in the file) — that
is exactly the class of bug this fixture catches.

## R3 — Test strength / signal-to-noise

This section is intentionally empty of any canonical R3 content.

## Other Section

**Rule**: placeholder rule body.
**Why**: placeholder why body.
**How to apply**: placeholder how-to-apply body.

Anti-pattern tokens planted here to spoof whole-file greps: tautological,
setter-getter round-trip, mock-call-counter, assertIsNotNone, type-checker.

Every fresh test must have a one-sentence note in `observed.notes` naming the regression it catches; if you cannot name it, the test is weak — rewrite or delete.
