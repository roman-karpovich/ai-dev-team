# Decoy fixture M2 — in-region duplicate H3 (code-audit X6 REOPENED residual)
# (spec 2026-07-02-decision-audit-mode, code-audit X6 / shape M2)
#
# A DUPLICATE decoy H3 is placed INSIDE the exact parent region, BEFORE the real
# (gutted) H3, carrying the full carve-out text a first-match grab would return.
# Two regions exercised:
#   * duplicate `### Decision mode` inside `## Argument Parsing`
#   * duplicate `### Decision-mode return handling` inside `## Phase 3: Present & Decide`
# The uniqueness-guarded extractors COUNT the H3 occurrences in-region and emit
# nothing when the count != 1, so every consumer check goes RED on the empty
# section. A pre-residual first-match extractor grabbed the decoy H3 and stayed
# GREEN (the reproduced M2 mutant). Exercised by
# check_cross_audit_skill_decision_m2_duplicate_h3_rejected.

## Argument Parsing

### Decision mode (`--mode decision`)

DECOY — a duplicate in-region `### Decision mode` H3 before the real (gutted) one. The skill derives the slug: `feature_slug = basename(scope)` minus the `.md` extension minus the leading `YYYY-MM-DD-` date prefix. Then `workdoc_path = design/workdocs/<feature_slug>/exec.md` and findings glob `security/<feature_slug>-*findings.md`.

### Decision mode (`--mode decision`)

Gutted real section — the slug-derivation formula, the date-prefix rule, and the findings glob were all removed (the M2 mutant). This body carries none of the load-bearing clauses.

---

## Phase 3: Present & Decide (foreground, interactive)

### Decision-mode return handling

DECOY — a duplicate in-region `### Decision-mode return handling` H3 before the real (gutted) one.

- **Skip the findings.md read.** SKIP the findings.md read and present the inline findings from the agent return directly.
- **Report-only — no per-finding triage, no Phase 4 status mutation.** The per-finding banner and the Phase 4 status mutation do NOT apply for decision-mode returns.
- **No publish.** Decision findings are NEVER published to a PR — publishing KB paths violates R8.

### Decision-mode return handling

Gutted real section — the report-only / skip-findings / no-publish carve-out was removed (the M2 mutant). This body carries none of the load-bearing clauses.

## Phase 4: Fix

(end)
