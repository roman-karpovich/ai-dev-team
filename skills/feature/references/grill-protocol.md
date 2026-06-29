# Grill protocol (canonical)

Single source of truth for the grill interview. Grill = relentless decision-tree
interview that stress-tests a DRAFT spec against the real codebase before any code
is written. Runs as a DRAFT-hardening sub-phase (`DRAFT → [grill] → APPROVED`) — NOT
a new state-machine token. Opt-in, off by default, interactive-only, INLINE (no
subagent — a live interview cannot be backgrounded, and the human is the gate).

This reference defines the interview discipline. Wiring into `/feature` lives in
`skills/feature/SKILL.md`; the write-back surface (`## Decisions` table + grill
frontmatter) lives in `skills/feature/references/spec-template.md`.

## 1. Branch-map traversal

Open by MAPPING the decision branches — enumerate the spec's open decisions as a
tree before grilling any of them. Then walk ONE branch to its leaves before moving
to the next; do not hop between branches. Resolve dependencies in order —
foundational decisions first, so a downstream branch is grilled against settled
upstream answers, never against a guess that later flips.

The branch-map is **human-authored in v1**. Autonomous tree-seeding (e.g. a Codex
pre-pass) is deferred to v2 — it helps only the code-grounded question class and
adds anchoring plus build cost.

## 2. The three load-bearing mechanics

Three mechanics. All three are **required / load-bearing** — none is dispensable.
Each prevents a distinct failure mode and each maps to one Decisions column.

1. **recommended-answer-per-question** — every question ships the model's own best
   answer, stated up front, to attack or confirm. Purpose: forcing function (a
   concrete position to attack beats an open prompt) plus cost control (the user
   one-word-confirms the easy majority). Maps to the `confirmed-answer` column.
2. **explore-codebase-instead-of-ask** — ground every claim in real symbols and
   line-refs; verify constants in the source instead of assuming them. Purpose: the
   only path to the code-grounded defect class — symbol/constant mismatches an
   autonomous reader could catch. Maps to the `evidence-ref` column.
3. **numeric-worked-examples-on-contested-points** — on any contested point, work a
   concrete numeric example through the boundary math. Purpose: catches the defect
   that passes mechanic 2 (the symbols exist exactly as assumed) yet fails the
   boundary arithmetic. Maps to the `numeric-example` column.

Mechanics 2 and 3 are distinct: (2) checks the symbols/constants **exist as
assumed**; (3) checks the **boundary math holds**.

## 3. Coarse route classification

Each question self-classifies a **coarse route**: `routine` vs `domain_input`. The
route enum is `{routine, domain_input}` — a two-value coarse label, **NOT** a numeric
confidence score. Numeric confidence is deliberately avoided: an overconfident
numeric label anchors the user harder than a coarse one.

- `routine` — the model's recommended answer is offered directly; the user confirms
  or corrects.
- `domain_input` — the question turns on user domain knowledge. **Ask FIRST, then
  reveal** the recommendation, so the user's own answer is not anchored by the
  model's.

The user may **override** the self-classification on any question (`treat as
domain-input`). A route change marks that row **contested** (see §4).

## 4. Decisions write-back schema

Grill folds outcomes into existing spec sections where possible — risk deltas into
`### 3.6 Risks`, the changelog line into `## 9. Log`. New decisions land in a NEW
`## Decisions` table on this **fixed** schema, columns in this **exact order**:

| decision-id | question | confirmed-answer | route | evidence-ref | numeric-example | changed-sections |
|-------------|----------|------------------|-------|--------------|-----------------|------------------|

Column ↔ mechanic mapping: `confirmed-answer` ↔ mechanic 1; `evidence-ref` ↔
mechanic 2; `numeric-example` ↔ mechanic 3.

Contract:

- `changed-sections: none` is a **VALID value** — some decisions confirm that no
  section changes. Never fake a bogus section ref; record `none` honestly.
- A row is **CONTESTED iff**: the user disagreed, OR the route changed, OR numeric
  derivation was required, OR code evidence changed the answer, OR a deferred /
  unknown answer was chosen.
- **Contested rows** MUST carry non-empty `evidence-ref` AND non-empty
  `numeric-example`.
- **All rows** (contested or not) MUST carry `confirmed-answer` AND
  `changed-sections`.

**No machine handshake parser in v1.** Grill is human-driven and the human is the
gate. The smoke pins assert the table **structure** (the floor); the grill-aware
Step 3.5 cross-audit verifies that cited `evidence-ref` citations **resolve**
(Goodhart mitigation); the user judges answer quality.

## 5. Coverage / termination

Coverage is an **advisory** signal, never a gate. Report it as
`grill_coverage: visited/total/deferred`, framed strictly as "of the branches WE
MAPPED" — it is **never** a claim over the true decision space (the map itself may be
incomplete). It is an honesty signal — stopped-because-done vs stopped-because-tired
— not a formal completeness metric. `deferred > 0` is advisory; grill NEVER gates.

The interview is bounded by:

- **max turns / branches** — a hard ceiling on interview length.
- **user cadence** — `small portions` = one sub-question at a time; default = batch.
  Switch on the user's signal.
- **`--focus <branch>`** — scope the interview to a single named branch.
- **explicit stop criteria** — the user can stop at any point.
