# Decoy fixture — decision-mode anchored-extractor negative test
# (spec 2026-07-02-decision-audit-mode, code-audit X6 / sweep-B)
#
# Two decoy headings sit OUTSIDE their canonical parent region, each carrying the
# full carve-out text a pre-X6 FIRST-MATCH extractor would grab. The REAL headings
# inside `## Argument Parsing` / `## Phase 3` are gutted (carve-out removed — the
# confirmed mutant). The anchored extractors MUST grab the gutted real sections so
# every consumer check goes RED; the pre-X6 extractors grabbed the decoys and
# stayed GREEN. Exercised by check_cross_audit_skill_decision_phase3_decoy_rejected.

## Intro (deliberately NOT Argument Parsing)

### Decision mode (`--mode decision`)

DECOY — this `### Decision mode` heading sits ABOVE `## Argument Parsing`. A pre-X6 first-match `_skill_decision_mode_section` grabbed it.

The skill derives the slug: `feature_slug = basename(scope)` minus the `.md` extension minus the leading `YYYY-MM-DD-` date prefix. Then `workdoc_path = design/workdocs/<feature_slug>/exec.md` and findings glob `security/<feature_slug>-*findings.md`.

### Decision-mode return handling

DECOY — this `### Decision-mode return handling` heading sits ABOVE `## Phase 3`. A pre-X6 first-match `_skill_decision_phase3_section` grabbed it.

- **Skip the findings.md read.** SKIP the findings.md read and present the inline findings from the agent return directly.
- **Report-only — no per-finding triage, no Phase 4 status mutation.** The per-finding banner and the Phase 4 status mutation do NOT apply for decision-mode returns.
- **No publish.** Decision findings are NEVER published to a PR — publishing KB paths violates R8.

---

## Argument Parsing

### Decision mode (`--mode decision`)

Gutted real section — the slug-derivation formula, findings glob, and date-prefix rule were all removed (the mutant). This body carries none of the load-bearing clauses.

---

## Phase 3: Present & Decide

### Decision-mode return handling

Gutted real section — the report-only / skip-findings / no-publish carve-out was removed (the mutant). This body carries none of the load-bearing clauses.

## Phase 4: Fix

(end)
