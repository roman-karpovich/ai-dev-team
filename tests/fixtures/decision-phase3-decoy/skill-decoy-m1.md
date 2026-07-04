# Decoy fixture M1 — prefix-sibling H2 (code-audit X6 REOPENED residual)
# (spec 2026-07-02-decision-audit-mode, code-audit X6 / shape M1)
#
# A decoy H2 that SHARES A PREFIX with the real parent H2 is placed ABOVE the real
# one, carrying the full carve-out text a loose-prefix region anchor would grab;
# the REAL heading inside the exact region is gutted. Two regions exercised:
#   * `## Argument Parsing (legacy)` above the exact `## Argument Parsing`
#   * `## Phase 3.5 Decoy` above `## Phase 3: Present & Decide (foreground, ...)`
# The exact-anchor extractors MUST ignore the prefix-sibling decoy and grab the
# gutted real section, so every consumer check goes RED. A pre-residual
# `/^## Argument Parsing/` + `/^## Phase 3/` anchor opened the decoy region and
# stayed GREEN (the reproduced M1 mutant). Exercised by
# check_cross_audit_skill_decision_m1_prefix_sibling_rejected.

## Argument Parsing (legacy)

### Decision mode (`--mode decision`)

DECOY — this `### Decision mode` lives under a prefix-sibling `## Argument Parsing (legacy)` H2 placed ABOVE the exact `## Argument Parsing`. The skill derives the slug: `feature_slug = basename(scope)` minus the `.md` extension minus the leading `YYYY-MM-DD-` date prefix. Then `workdoc_path = design/workdocs/<feature_slug>/exec.md` and findings glob `security/<feature_slug>-*findings.md`.

---

## Argument Parsing

### Decision mode (`--mode decision`)

Gutted real section — the slug-derivation formula, the date-prefix rule, and the findings glob were all removed (the M1 mutant). This body carries none of the load-bearing clauses.

---

## Phase 3.5 Decoy

### Decision-mode return handling

DECOY — this `### Decision-mode return handling` lives under a prefix-sibling `## Phase 3.5 Decoy` H2 placed ABOVE the exact `## Phase 3: Present & Decide`.

- **Skip the findings.md read.** SKIP the findings.md read and present the inline findings from the agent return directly.
- **Report-only — no per-finding triage, no Phase 4 status mutation.** The per-finding banner and the Phase 4 status mutation do NOT apply for decision-mode returns.
- **No publish.** Decision findings are NEVER published to a PR — publishing KB paths violates R8.

## Phase 3: Present & Decide (foreground, interactive)

### Decision-mode return handling

Gutted real section — the report-only / skip-findings / no-publish carve-out was removed (the M1 mutant). This body carries none of the load-bearing clauses.

## Phase 4: Fix

(end)
