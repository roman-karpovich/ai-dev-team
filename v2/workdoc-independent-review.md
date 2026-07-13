# v2 VERIFY slice — independent cold-review brief (for a fresh Codex)

**You are an INDEPENDENT reviewer.** You did NOT design this code. Do not assume any prior review reached the right conclusions — re-derive everything from the ADRs below. Your value here is precisely that you are a fresh oracle: the code was co-designed with a *different* Codex thread, so that thread is no longer independent of it. Hunt for the errors a co-author would be blind to.

- **Date**: 2026-07-13
- **cwd for this review**: the `ai-dev-team` repo root (the code under review is in `v2/`).
- **Nature of the artifact**: a deterministic, stdlib-only **reference state machine + trace runner** for the v2 VERIFY slice. It is NOT the production engine — it exists to prove the ADR contracts are executable and internally consistent, via scenario traces and adversarial mutants. No provider calls, no side effects.

## 1. What to read

Code (in cwd, read these fully):
- `v2/spec/transitions.json` — the pinned encoding (spec_version `adr1-v7`) of the ADR-1 state machine + the ADR-5 ledger schema. **The ADRs are the contract; this JSON is a mirror. On divergence the ADR wins — report the divergence as a defect in the JSON.**
- `v2/tools/trace_runner.py` (~846 lines) — the reference machine + the fixture assertion harness (`run_trace`).
- `v2/traces/trace-*.json` — 13 scenario fixtures.
- `v2/traces/mutants/*.json` — 17 adversarial mutants (must be REJECTED under `--expect-fail`).

Normative references (absolute paths; read if your sandbox permits — they are the source of truth):
- ADR-1 state machine + snapshot: `/Users/th13f/dev/personal/finance-learning/repos/ai-dev-team/design/2026-07-13-v2-adr-1-state-machine-and-snapshot.md`
- ADR-2 evidence + adjudication: `.../design/2026-07-13-v2-adr-2-evidence-and-adjudication.md`
- ADR-3 risk profiles + sandbox: `.../design/2026-07-13-v2-adr-3-risk-profiles-and-sandbox.md`
- ADR-4 providers/adapters/failures: `.../design/2026-07-13-v2-adr-4-providers-adapters-failures.md`
- ADR-5 ledger + lifecycle: `.../design/2026-07-13-v2-adr-5-ledger-and-lifecycle.md`
- ADR-6 eval + release gate: `.../design/2026-07-13-v2-adr-6-eval-and-release-gate.md`

If you CANNOT read the KB paths, review against the compact contract in §3 below and flag any place the code seems to assume a rule not stated there.

## 2. How to run it

```
python3 v2/tools/trace_runner.py v2/traces/trace-*.json              # expect: 13/13 pass
python3 v2/tools/trace_runner.py --expect-fail v2/traces/mutants/*.json   # expect: 17/17 rejected on named invariant
```
The suites are currently green. **Green is the starting point, not the conclusion** — see §4.

## 3. Compact contract (for review without KB access)

State machine (ADR-1): run phases `CREATED → SNAPSHOT_BOUND → PLAN_BOUND → EXECUTING → CONSOLIDATING → ADJUDICATING → terminal{COMPLETED,INCOMPLETE,FAILED,BLOCKED,CANCELLED}`. Attempts `SCHEDULED→DISPATCHED→{COMPLETED,FAILED,CANCELLED,ABANDONED}` + `SKIPPED`. Terminal decision, ordered: corruption→FAILED; cancelling→CANCELLED; pre-exec block→BLOCKED; any required node not COMPLETED→INCOMPLETE; cutoff set→INCOMPLETE; HEAVY & any UNVERIFIABLE finding with severity level HIGH/CRITICAL→INCOMPLETE (V2-SM-08); else COMPLETED. Release: LIGHT always REPORT_ONLY; HEAVY PROCEED iff COMPLETED and no adjudicated finding ≥HIGH with adjudication∈{CONFIRMED,UNRESOLVED,UNVERIFIABLE}, else HOLD. Event identity `(event_kind,event_id)`; conflicting body→corruption→FAILED; exact duplicate→total no-op. Dispatch at-most-once per `(run_id,node_id,attempt)`. Outbox before dispatch; crash-in-doubt reconciled: proven non-acceptance→N8 FAILED{transport} (retry-eligible), else N6 ABANDONED. Budget cutoff: no new N1/N2, unstarted nodes SKIPPED (N9), never COMPLETED.

Evidence (ADR-2): claims accepted only per claim class; NO global ranking. A machine `artifact_observation` enters ONLY via a control-plane re-read receipt (`claims_reread`, `cp-` id, anchored to a pending finder proposal with matching subject), never from a model envelope. Severity `level` is machine-derived from (impact,reachability) via a fixed ladder — a model-supplied level is an error. B adjudicates on a stable semantic projection of the claim set; canonical findings = CONFIRMED only; REJECTED needs a machine-verified exclusive contradiction (same class/subject/snapshot, `relationship=contradicts`, mutually-exclusive value), else coerced to UNRESOLVED.

Ledger (ADR-5): the MAIN ledger journals **external events + the terminal seal only**; machine-derived transitions (phase advances, N9, derived N4, terminal decision) are replayable, NOT journaled records (this is a deliberate design choice — it keeps the independent head-hash oracle valid; do not flag it as missing coverage, but DO check the boundary is applied consistently). Hash chain: `record_hash = sha256(canonical({format_version,seq,prev_hash,kind,event_id,body_digest,artifact_refs}))`, `prev_hash` links, genesis `"GENESIS/v2-verify"`. Seal is a real appended record whose body binds `{run_id,terminal,release_recommendation,spec_version,pre_seal_head}`; sidecar persists the same projection. A corrupt/unsupported SOURCE journal is NEVER appended-to or sealed. Claim-field lift enforced at registration for every claim: `created_at_seq`, `artifact_refs ⊆ record refs`, pinned `snapshot_id` (foreign rejected), `execution_manifest_id`, `trust_domain.shared_dependencies: string[] | "UNKNOWN"` (missing receipt → UNKNOWN, ≠ explicit empty). Late results → separate hash-chained audit chain (post-terminal, inadmissible).

Risk/adapters/gate (ADR-3/4/6): two profiles LIGHT/HEAVY; budget vectors; sandbox+command policy; `claude -p`/`codex exec` argv, identity split (no silent fallback), failure matrix; preregistered release gate with lower-95%-bound decision value and integrity-never-COMPLETED clause. These are mostly conformance/eval-shaped; the traces exercise the state-machine + evidence + ledger surfaces.

## 4. Your review contract

Produce findings in this priority order. **The highest-value finding is a trace whose expectations are internally consistent with the runner but WRONG against the ADR** — that is the shared-oracle trap and the whole reason you were brought in cold.

1. **Runner ↔ ADR conformance.** Does `trace_runner.py` faithfully implement the state machine, evidence rules, and ledger? Name any rule it gets wrong, omits, or over-applies.
2. **Spec ↔ ADR fidelity.** Does `transitions.json` faithfully encode ADR-1/ADR-5? Any guard/transition/field that diverges.
3. **Trace correctness (not consistency).** For each trace, are the `expected_*` values the CORRECT expectations per the ADRs — terminal, release, node states, coverage gaps, ledger length/head/sealed, candidate dispositions? Re-derive independently; do not assume the runner is right.
4. **Mutant adequacy.** Does each mutant actually exercise its NAMED invariant (via `expect_failure_containing`), or does it pass for an unrelated reason? Any invariant with NO mutant that should have one.
5. **Missing assertions / dead guards.** Contract rules that no trace or mutant checks; guards in the code that are unreachable or never exercised.

Output format: a numbered list of `{location (file:line), defect, why it's wrong vs the ADR, proposed fix}`, most-severe first. If a section is clean, say `CLEAN: <section>`. End with a one-line verdict: is this reference implementation a faithful, independently-verifiable model of the six ADRs, or not.

## 5. Out of scope (declared-deferred — do NOT flag as gaps)

These are known boundaries, specified in the ADRs but intentionally not modelled in the trace layer: artifact-**byte** verification (fixtures carry no real bytes), redaction fixtures, seal-vs-sidecar tail-truncation fixtures, the real provider CLIs (ADR-4 conformance = Work Package D), the eval corpus/statistics (ADR-6 = Work Package E), and the OS sandbox mechanism (ADR-3 = Spike 3). Machine-derived transitions being absent from the crypto ledger is a deliberate design decision (§3), not a defect. Flag these ONLY if the code CLAIMS to do them and doesn't.
