---
title: AI Dev Team — Backlog
project: ai-dev-team
type: backlog
created: 2026-04-16
tags: [backlog, ai-dev-team]
---

# AI Dev Team — Backlog

**Updated:** 2026-06-02 (added #76 — smoke-pin placement: canonical 3-edit protocol "function in smoke-helpers.sh" contradicts actual topical-clustering convention, surfaced by X1/X5/X6 recurrence in r5-r7 spec-audit; P3, align doc to reality; AND #75 — R7 `enforced_by` flip → spec-compliance-checker deterministic Rust gate; DEFERRED pending 1 recurrence post-`2026-06-02-r5-r7-test-placement-enforcement` ship, per /investigate convergence 2026-06-02; previous: 2026-05-10 added #74 — hybrid lift from GitHub spec-kit: copy `clarify` phase + `analyze` consistency check + tasks.md `[P]` parallel markers + extensions.yml hook-name alignment; full migration rejected — spec-kit covers ~30-40% heavy lifting, cross-audit/probes/R1-R14/KB/MCP-Codex orchestration are agent-centric and outside spec-kit's agent-agnostic scope; previous: 2026-05-08 added #65-#72 from radaro-queue post-hoc cumulative audit 2026-05-07; #73 codifies 2× Opus audit mode as first-class fallback per user directive after Codex limit exhaustion mid-day 2026-05-08)

Out-of-scope items from анализа плагина 2026-04-16. Приоритизация — от impact к nice-to-have. Активные спеки: `design/`. Завершённые: по Log в самом спеке.

**2026-04-20 addendum**: items #26–#35 ниже — результат сквозного аудита плагина (4 skills, 8 agents, 5 references, 3 docs, hooks, README) на избыточность и двусмысленность. Каждый item помечен требованием "no functional regression" — поведение плагина не меняется, только источник истины унифицируется.

**2026-04-25 addendum**: investigate convergence 2026-04-25 (Claude Opus xhigh + Codex GPT-5.5 xhigh, CONVERGED) пересмотрел binding constraint. MISSION.md формулировка "binding constraint = audit coverage" устарела: E/F probes shipped, audit-coverage axis = tail. Active constraint set теперь `audit-coverage tail / rollout-isolation / process-truthfulness / rule-enforcement`. Активные priorities ниже отражают этот сдвиг; исторические P1/P2/P3 sections сохранены для git-history continuity.

---

## Active priorities (post-convergence 2026-04-25)

### P0 — Active binding constraint set (next default moves)

| # | Item | Axis | Status | Rationale |
|---|------|------|--------|-----------|
| ~~**42a**~~ | ~~Conditional activation в `hooks/session-start` (split from #42)~~ | rollout-isolation | ✅ DONE (2026-04-25) — PR #47 | Hook dormant в orthogonal projects (3-arm OR signal detection); X1 audit fix landed (compgen -G + shopt -u defense-in-depth + BASH_ENV regression smoke). Smoke 401→407. |
| ~~**44**~~ | ~~Librarian effectiveness review — actual-vs-declared role~~ | process-truthfulness | ✅ DONE (2026-04-26) — Mode B chosen, PR #51 | Audit confirmed 0.54% delegation rate over 10 days / 184 KB-files; Mode B narrow-framing landed. Methodology validated for #46. Research note: `<kb>/research/librarian-effectiveness-review/2026-04-25-actual-vs-declared-role.md`. |
| ~~**46**~~ | ~~Plugin claims-vs-runtime audit pass~~ | process-truthfulness | ✅ DONE (2026-04-26) — PR #60 | Smoke `proves:` classification (manifest + per-class summary; first quantitative read on suite — Behavioral: 28 / Schema: 2 / Prompt-text: 12 / Unclassified: 403). New `docs/agent-claims-vs-runtime.md` classifying 20 high-leverage MUST/always/never claims across 8 agents (enforced/convention/self-policed). `agents/spec-compliance-checker.md` description narrowed (R1, R2, R3 enforcement explicit; R4-R7 marked convention-text). MISSION.md re-verified. Smoke 440 → 445. Bonus: Bash 3.2 graceful fallback. |
| ~~**(quick-task)**~~ | ~~R5 ↔ R7 inline contradiction fix в `code-quality-rules.md`~~ | code-quality conventions | ✅ DONE (2026-04-25) — PR #46 | R5 step 4 теперь defers к R7 step 3 (R7 wins per convergence). |
| ~~**47**~~ | ~~R3 weak-phrase check in `spec-compliance-checker`~~ | rule-enforcement | ✅ DONE (2026-04-25) — PR #48 (R3 enforcement + tamper fixture) + iter-1 audit X1+X2 fixed | First Tier 3 enforcement slice live (compgen -G + byte-exact regex anchor pinning + tamper-fixture wrappers). Smoke 412→416. Closes MISSION line 38 partial claim. |
| ~~**(quick-task)**~~ | ~~MISSION.md honesty edits — line 38 R1-R7 claim + binding-constraint frame replacement + NEW operational rule #7~~ | mission-truthfulness | ✅ DONE (2026-04-25) — PR #49 (CLAUDE.md mirror) + KB-side MISSION.md rewrite | Bundled with PR #48 per new operational rule #7. Line 38 narrowed to "R1/R2/R3 enforced; R4-R7 queued"; §Current binding constraint → §Active constraint set; §Operational rules #7 added. |
| ~~**53**~~ | ~~Integrate orchestrator-delegation discipline + spec-audit stop-criteria into plugin source~~ | process-truthfulness × code-quality conventions | ✅ DONE (2026-04-28) — PR #68 | MISSION rules #10 + #11 added; SKILL.md §3.5c "Stop criteria" subsection added with phase-split semantics + paired control with rule #10; fixture-based smoke pin `audit-iteration-hard-cap-recognition` + R6 mutation-protected meta-pin shipped (smoke 399 → 401); 3 fixtures clean/violation/justified; memory bridges dropped. Spec dogfooded the rules: spec audit triggered iter-2 stop signal → comprehensive sweep → AUDIT_PASSED; code audit converged in 3 iters with paired-control fresh-context senior on each fix. |
| ~~**55**~~ | ~~contract-violated-enum (Q3 slice 1)~~ | process-truthfulness × honesty | ✅ DONE (2026-04-28) — PR #70 squash-merged, status: VERIFIED | Spec audit ran 4 iters (X1-X17 fixed; iter-4 itself contract_violated event — meta-perfect dogfood). Code audit ran 6 iters (12 findings: 8 VERIFIED including X1 CRITICAL parser-adjacency-EOF, X5 path-coherence; 4 ACCEPTED with rationale → Q3 slice 2 territory). Smoke 401 → 409 (+8 pins). `code_audit_evidence: dual_model`. |
| ~~**56**~~ | ~~removed-cli-flag-hard-fail (Q4 slice 1)~~ | code-quality conventions × user-path defects | ✅ DONE (2026-04-29) — PR #72 | One-cycle deprecation policy codified in new `docs/cut-spec-policy.md` (placeholder-only) + MISSION rule #12. Retroactive detection at parsing surfaces for 4 already-shipped cuts (5 canonical hard-fail lines, 3 voice anchors byte-for-byte). Architectural pivot Path 4 = surgical assertion retirement: 3 absence guards each lose ONE assertion (`check_codex_fast_absent` 8→7, `check_probe_downgrade_flag_absent` 6→5, `check_feature_from_investigation_absent` 6→5; `check_multi_gh_account_absent` undisturbed). 6 R3-strong smoke pins (5 prompt-text + 1 schema). Smoke 415 → 421. Spec audit: 6 iters, 17 findings dual_model. Code audit: closed-gate clean dual_model. §8 seeds 3 post-merge items (1.14.0 removal cycle; X17 block-anchored pin tightening as Q4-slice-2 under #57; pre-existing dup-numbering housekeeping). |
| ~~**57**~~ | ~~shared-absence-helper-extraction (Q4 slice 2)~~ | verification rigor × code-quality conventions | ✅ DONE (2026-04-30) — PR #76 squash-merged, status: SHIPPED | Two shared helpers (`assert_literal_absent_in_live_source`, `assert_no_stale_section_header_comments`) in `tests/smoke-helpers.sh` with optional path-list arg form for tamper-fixture rejection wrappers. 4 cut-spec absence guards retrofitted (codex_fast, multi_gh_account, probe_downgrade, from_investigation). Step 5 also fixed pre-existing dup-numbering bug in `check_feature_from_investigation_absent` (claimed `all 5` over 7 actual checks → now `all 6` over 6 distinct numbers). Smoke 421→423. Spec audit: 6 iters dual_model with iter-5 architectural pivot (Path B scope reduction — Helper C / Step 6 / X17 block-anchored pin tightening dropped, deferred to follow-up spec). Code audit: `code_audit_evidence: self_fallback` (4th instance of BACKLOG #51 — cross-auditor stalled with no findings.md persisted; orchestrator manually self-verified per `feedback_iter_2_audit_fallback.md` adapted to iter-1; tracking entry updated). §8 has 2 pending: parent #56 §8 item 3 closure cross-reference + follow-up spec for #56 §8 item 2 (X17 block-anchored pin tightening). Remote agent scheduled for 2026-05-14 to revisit BACKLOG #51 graduation question. |
| **58** | sentinel-ledger-pilot-shallow-review (Q1) | quality verification × pain measurement | **P0 queued (depends on #55 + Q3 slice 2)** | Investigator round-2 mission audit 2026-04-28 — pilot for pain #6 ("shallow review quality"). Scope: 3 historical incidents per pain #6 + replay mechanics + telemetry surface + exit criteria. Natural ordering: last because needs measurement infrastructure (#55 contract_violated enum + Q3 slice 2 distribution rollup) to score sentinels meaningfully. Q1 acknowledged inline at MISSION L127 (paradox-flagged: rule #11 catalyst spec exceeded cap pre-rule, n=1 calibration; recalibration data points come from this pilot). |
| ~~**52**~~ | ~~`/feature continue` blind to multi-spec queues planned in research notes (session-handoff gap)~~ | process-truthfulness × workflow ergonomics | ✅ DONE (2026-04-29) — PR #71 squash-merged, status: VERIFIED | Hybrid landing: option (c) `/research conclude --queue-spec <slug-list>` parameter + option (a) `/feature continue` scan surface. Research-template `queued_specs:` YAML list in CONCLUDED notes' frontmatter; `/feature continue` no-in-flight branch + `/feature status` `### Queued from retrospectives` section render queued items with materialization-status branching (DRAFT/APPROVED/BLOCKED/IN_PROGRESS/AUDIT_PASSED/SHIPPED/VERIFIED/DISCARDED + no-match). Recursive walk of `<kb>/repos/<project>/research/**/*.md` covering depth-0 and deeper; date-prefix-anchored canonical lookup `<YYYY>-<MM>-<DD>-<slug>.md` (rejects slug-suffix collisions). Defensive frontmatter parsing with malformed-YAML warnings. Spec audit + code audit both `dual_model`. |
| **59** | per-release audit-evidence distribution report (rec #6) | process-truthfulness × visibility | **P2 deferred — DISCARDED draft 2026-04-30 (premature; reactivate at ≥30 enum-tagged specs OR first observed goodhart complaint)** | Round-2 retrospective recommendation #6: visibility-only telemetry surface protecting against goodhart on `dual_model` count. **Demoted P0→P2 2026-04-30** at pre-approval mission-fit review. 5 issues surfaced: preventive infrastructure for hypothetical drift (no observed goodhart evidence), sample size n=6 too small for signal, functional equivalent is a 3-second awk one-liner, "critical path to #58" thin (Q3 slice 2 itself waits for 5-10 release windows so report runs idle), cost high vs alternatives. Discarded draft at `<kb>/repos/ai-dev-team/design/2026-04-30-audit-evidence-distribution-report.md` (status: DISCARDED, no feature branch created). Reactivate when: ≥30 enum-tagged specs accumulated (~5x current sample) OR first observed complaint that `dual_model`-count metric is being gamed. Until then this is preventive overhead. |

### P1 — Real pain, mission-aligned, not binding

| # | Item | Axis | Status | Rationale |
|---|------|------|--------|-----------|
| ~~**37**~~ | ~~AGENTS.md proactive read в `/feature` Research phase~~ | code-quality conventions | ✅ DONE (2026-04-26) — PR #57 | `/feature` Step 1 now reads AGENTS.md / CLAUDE.md / .github/CONTRIBUTING.md and lifts directive rules into spec §2.X "Repo conventions"; Step 2 forbids 4 ambiguity tokens (`developer's call` / `at developer's discretion` / `as you see fit` / `at agent discretion`) for §5 decisions covered by Repo conventions; cross-auditor spec-mode enforces the rule (HIGH). R5 step 1 prepends directive-file precedence before grep-heuristic. Closes the soroban-amm `plane.rs` X3 gap at spec-write time. Smoke +4. |
| ~~**45**~~ | ~~`/cross-audit` ref-to-ref scope (`v2.0.2..v1.7.0` form)~~ | verification ergonomics | ✅ DONE (2026-04-26) — PR #56 | New scope form `<refA>..<refB>` / `<refA>...<refB>` with optional `-- <path>` filter; opt-in `--materialize=worktree` for content-correct audits at refB; new `hooks/lib/cross_audit_resolve_range.sh` resolver helper + tiny git fixture; cross-auditor `range_spec` parameter takes precedence over `<base_branch>...HEAD`. Smoke +6. Subsystem-split deferred to follow-up. |
| ~~**42b**~~ | ~~Plugin coexistence — inject-thinning (sub-piece A: extract sibling; sub-piece B: compress + redistribute)~~ | rollout-isolation | ✅ DONE (2026-04-26) — PR #53 (sub-piece A) + PR #54 (sub-piece B) | Inject 69→24 lines (-65%), context 5398→1796 chars (-67%); trigger map preserved verbatim; 5 sections lazy-loaded into skill bodies. Iter-1 audit caught X1 anti-goal violation (Key facts dropped) — fixed bundled. |
| ~~**42c**~~ | ~~Plugin coexistence — scope-narrowing of rule applicability (rest of #42)~~ | rollout-isolation | ✅ DONE (2026-04-26) — PR #55 | `## Confirmation cadence` extracted to single canonical `docs/confirmation-cadence.md` (active-flow-scoped opening); both `/feature` + `/cross-audit` skill bodies replaced 10-line block with 2-line pointer; new `### Coexistence` section in inject (priority order `user's CLAUDE.md > other plugins > ai-dev-team > default Claude behavior` + complement note); inject cap 25 → 30 (still −58% vs pre-#42b 69-line baseline). Smoke +2. Closes #42 series. |
| **60** | rule-admission gate for new MISSION operational rules (rec #1) | mission-truthfulness × rule-quality | **P2 deferred — demoted P1→P2 2026-04-30 (likely boilerplate-filled, alternative: periodic review pass)** | Round-2 retrospective recommendation #1: 0 → 11 operational rules in 7 minor versions (v1.6.0 → v1.13.0), only rule #8 has revival conditions; drift pattern #2. **Demoted P1→P2 2026-04-30** at pre-draft mission-fit review. User self-reported (verbatim "буду шаблонить") that 5-field admission gate (Anchor / Owner / Enforcement / Retirement / Success signal) would degrade into boilerplate — `Owner: user`, `Retirement: review periodically`, `Anchor: see BACKLOG #N` — passing smoke pin without adding signal. Goodhart-friendly presence-check at admission. Q2 hybrid Type-tag inline edit (2026-04-28) already addresses the worst part of the drift for rules #7-#12. **Alternative path (when gap re-asserts)**: periodic review pass — scheduled remote agent every N releases re-reads MISSION rules and asks "is each still serving its anchor incident?" Reactive instead of proactive; lower admission cost; relies on review-cadence discipline holding. Reactivate this entry when: (a) a new operational rule lands without retirement criteria AND becomes problematic later, OR (b) the periodic review pass alternative ships and proves insufficient. |
| ~~**61**~~ | ~~100% classification of new smoke pins at write time (rec #3)~~ | code-quality conventions × verification rigor | ✅ DONE (2026-04-30) — PR #77 squash-merged, status: VERIFIED | Spec audit 6 iters dual_model with iter-4 architectural pivot (Path B-min/+1 — dropped freeze pin / sidecar / tamper fixture / rejection wrapper; closed X10/X14/X15 by-construction). Code audit 6 iters dual_model: X1 multiline-bypass refactored, X2 decision-tree rule 1 tightened to plugin-component scope, X3 5 label-form bypasses closed via absence #6, X4 5 prefix-form bypasses ACCEPTED with follow-up BACKLOG #64 (runtime-check-recording redesign), X5 audit-metadata inconsistency, X6 quantifier asymmetry. Final shape: presence gate `check_new_pin_classified` + 342-line grandfather baseline + 3-class doc with mechanical decision tree + 6 absence assertions. Smoke 424 → 425 (+1 pin). Process-truthfulness defect class trajectory: 12 cumulative instances across 11 audit iters; converged at iter-6 with surgical narrowing throughout. Anchor: 343 / 395 (~87% of helper tokens unclassified, live HEAD `2ea2c56` pre-merge). |
| **62** | open-loop scorecard (rec #7) | process-truthfulness × follow-up debt visibility | **P1 queued — promoted 2026-04-30** | Round-2 retrospective recommendation #7: per-release scorecard counting follow-up debt CREATED vs CLOSED — addresses drift pattern #1 (mission claims that R3-R7 enforcement is "named follow-up slice" while open-loop count grows). Visibility-only, not a target. Hooks into `§8 Post-merge checklist` items + `follows_up:` frontmatter chain + `defer:` triage decisions in code-audit findings. Decision space: (a) reuses #59 distribution-report machinery (currently DISCARDED P2); (b) standalone `/feature status --debt` view; (c) per-release agent-produced rollup. Likely subject to the same "premature-without-data" critique as #59 — re-evaluate at promotion. |
| **63** | Workdoc assertion-count parity rule (compliance-checker slice 1) | code-quality conventions × verification rigor | **P1 queued — promoted 2026-04-30 (anti-n=1: source incidents BACKLOG #57 + #61 audit logs, 12 process-truthfulness findings combined)** | Compliance-checker rule: `expected_pass_pattern: N` MUST equal counted `n=$((n+1))` increments in the corresponding workdoc step's `passing_test_cmd`; spec §6.1 step parenthetical "(N expected_pass increments)" MUST equal workdoc's `expected_pass_pattern`. Mechanical regex + count, no semantic verification. Workdoc-first scope only. **Out of scope for slice 1**: file-placement claims (X14 class), numeric/empirical claims (X9/X13 class), strength-promising-adverb narrative-flagging (X10/X15 class) — slices 2/3/4, deferred. **Anchored in**: MISSION rule #7 (honesty edits ship bundled with named first enforcement slice). First enforceable slice rationale: assertion-count is most mechanical, highest defect frequency in #61 audit log, cheapest to implement. |
| **64** | runtime-check-recording — replace static-grep extraction with `check()` runtime ledger (gate-redesign) | code-quality conventions × verification rigor × test-infra ordering | **P2 queued — promoted 2026-04-30 (anti-loss follow-up from #61 code-audit X4 ACCEPTED iter-3; forward-only future-bypass; reactivate on first observed instance)** | Spec #61 code audit hit 3 consecutive iters of same-defect-class continuation around static-grep extraction grammar (X1 multiline iter-1 → X3 5 label forms iter-2 → X4 5 prefix forms iter-3; 10th-instance class continuation overall). Both auditors converged on architectural root-cause: replace regex extraction with runtime recording inside `check()` (function appends `$2` to a registered-helpers file at invocation; gate reads that file instead of regex'ing smoke.sh). Closes ALL bypass forms by-construction (anything that successfully invokes `check()` is recorded). Cost: small `check()` extension + gate body rewrite + test-infra ordering change (gate must run AFTER all `check()` invocations). Out of scope for #61 (architectural pivot of test infra, not surgical). Reactivation criterion: first observed instance of forms F-K (assignment-prefix / backslash-prefix / operator-prefix / eval-wrapped / quoted-command-word) landing in production `tests/smoke.sh` AND a real classification gap caused by it. Anchored in #61 §3.7 honest residue bullet 5; findings file `<kb>/repos/ai-dev-team/security/2026-04-30-smoke-pin-100pct-classification-code-findings.md` X4 ACCEPTED rationale. |
| ~~**75**~~ | ~~`hooks/stop-check` mislabels unmerged-into-base commits as "unpushed"; false-positive fires forever after push~~ | rule-enforcement × process-truthfulness | ✅ DONE (2026-05-16) — PR #98 | Hook computes `git rev-list --count master..HEAD` (unmerged-into-base) and emits user-facing label `"N unpushed commit(s)"`. Any pushed feature branch fires the warning forever (its commits don't enter master until PR lands but they are not unpushed). Observed 2026-05-13 in stellar-arbiter session: `ci/2026-05-13-github-actions` pushed cleanly (`git log origin/<branch>..HEAD` empty), hook still emitted "1 unpushed commit(s)" on every subsequent Stop event. Fix sketch: split the two concepts — keep `master..HEAD` count for "unmerged into base" framing, ADD `@{u}..HEAD` count for true "unpushed", silent-skip when `unmerged > 0 ∧ unpushed == 0 ∧ branch has upstream` (= pushed, awaiting PR). Research note `<kb>/repos/ai-dev-team/research/stop-hook-false-positive/2026-05-13-unpushed-label-bug.md` carries full reproduce + three fix options (A relabel / B semantic split / C intent-aware via gh CLI; recommend B). Source: `hooks/stop-check:83-95`. |

### P2 — Deferred / Blocked

| # | Item | Status | Reason |
|---|------|--------|--------|
| **36** | Deploy-prerequisites prompt UX redesign | **DEPRIORITIZE** per convergence | UX polish, low ROI vs P0/P1; не закрывает documented audit-class. |
| **38** | G probe (test redundancy / failure_kind enum) | **DEFERRED pending shadow-mode metrics** | Convergence: Probe E/F = "experiment infrastructure, not proven rollout value yet". Возобновить когда 2nd user включит E/F в shadow и metrics оправдают expansion. |
| **39** | N probe (format-churn PR-level ratio) | **DEFERRED pending shadow-mode metrics** | Same reason as #38. Single-rule mitigation уже задокументирован (memory `feedback_formatters_changed_lines_only`); probe inflation has cost. |
| **40** | Librarian — add `backlog` document type | **BLOCKED by #44** | No point optimising librarian schema если #44 audit решит "delete agent entirely" (mode C) или "inline rules" (mode B partial). |
| **41** | `/feature` BACKLOG.md scan in Phase 0 | **BLOCKED by Active/Completed re-bucketing** | 909-line backlog → automation needs split first. Эта re-prioritisation = partial step; full re-bucketing pending. |
| **43** | Librarian → Haiku model downgrade | **BLOCKED by #44** | No point downgrading model agent'а который может быть deleted. |
| **48** | Audit-blind-spot class: env-stripping masks production-env interactions (env-fuzz probe candidate) | **DEFERRED — evidence pool 1/2** | X1 in #47 (BASH_ENV nullglob/failglob) caught manually, fixed inline. Class generalises (LANG/LC_*/TZ/shopt). Wait for 2nd incident before graduating to probe spec. |
| **65** | `probe-g-h-repo-root-normalization` (X1 from radaro post-hoc audit) | **P2 queued — added 2026-05-08** | Probe G/H accept arbitrary `repo_root` and emit it verbatim in finding paths; `..` traversal segments leak into PR review-comment publish surface. Fix: `os.path.realpath` normalization + reject paths containing `..` after normalization. R8-class hygiene for cross-audit publish flow. Anchor: findings doc `2026-05-07-radaro-queue-cumulative-posthoc-rerun-findings.md` X1 (HIGH, claude+codex confirmed). |
| **66** | `probe-h-corpus-growth-determinism` (X5 from radaro post-hoc audit) | **P3 deferred — reactivate at corpus ≥ 50 packages** | Probe H first-match break is order-dependent on `freshness_corpus.json` JSON dict iteration. With current 13-package corpus the bug is unobservable (no two canonicals collide on common typos); as corpus grows toward hundreds, equidistant-canonical typosquats will be reported against arbitrary canonical depending on JSON insertion order. Fix: collect ALL distance-≤2 candidates, sort `(distance, canonical_name)`, emit lowest. Defer until first corpus-growth PR or first observed wrong-canonical-attribution. Anchor: findings doc X5 (HIGH, claude). |
| **67** | `probe-h-legitimate-collisions-allowlist` (X6 from radaro post-hoc audit) | **P2 queued — added 2026-05-08** | Probe H Levenshtein-≤2 false-positive class on legitimate short-name PyPI/npm packages (e.g. `flak`, `djang`, `requesta`, `expresss`, `tokyo` flag against `flask`/`django`/`requests`/`express`/`tokio`). No allowlist mechanism — teams using these legit packages see permanent HIGH on every audit. Fix: `known_legitimate_collisions: [...]` per-canonical field in corpus + skip when `pinned_name.lower() in entry["legitimate_collisions"]`. Document curation discipline (registry-verification anchor per allowlist entry). Anchor: findings doc X6 (HIGH, claude only — codex did not review this class). |
| **68** | `probe-g-live-corpus` (X8 + X20 from radaro post-hoc audit; folds existing follow-up) | **P1 queued — promoted 2026-05-08 (anti-n=1: X8/X20 + retrospective §4 follow-up + Z2 fastapi pre-1.0 collision)** | Corpus values are integer-only (`{"latest_major": N}`) — no `last_verified` provenance, no `source_url`, no `corpus_version` field. Every value is model-memory snapshot, not registry-verified. Forward-compat broken: any schema bump (e.g. adding `last_verified` per X8 or `pre_1_0` per Z2 pattern) breaks byte-exact smoke fixtures' `eligible_reason` strings. Three coupled fixes: (a) `schema_version` top-level (X20); (b) `{latest_major, last_verified, source_url, pre_1_0}` per-package (X8 + Z2 forward-cover); (c) live-fetch refresh job (cron / shadow-mode probe). PR-B's X18 ACCEPT (`probe-g-drift-threshold-policy-after-corpus-provenance` follow-up #71) explicitly depends on this closing first. Smoke pin asserting all `last_verified` within 90d of HEAD commit date. Anchor: findings doc X8 + X20 + retrospective §7.4 fold table. |
| **69** | `replace-substring-pin-with-json-schema-lint` (X10 + X13 + X14 + X15 + X17 from radaro post-hoc audit; folds existing follow-up) | **P1 queued — promoted 2026-05-08 (strong anti-n=1: 12+ instances across 5 separate spec/code-audit incidents — PR #81, PR-B iter1, PR-A iter3/iter5/iter6/code-iter1)** | Substring-pin paradigm fragility — auditor flagged structurally on PR #81, PR-B spec audit, PR-A iter3 X13 (CRITICAL), iter5 X22+X23 (HIGH), iter6 X24 (HIGH), code-audit X1 (HIGH R8 leak). Each round adds awk-scoping + AND-conjunctive clauses + uniquely-bounded anchors as surgical fixes; structural defect persists. Replace substring-pin paradigm with: (a) JSON-Schema CI lint for fixture envelopes (replaces byte-diff snapshot pins X10); (b) block-extraction with semantic predicates for prose anchors (replaces §1.1/§1.2 detection X13/X15); (c) deterministic shell helper for path-resolution / R-rule load contracts (replaces X14 prose checks); (d) manifest classification rewrite to `byte-diff-snapshot` class so X17 mis-classification stops recurring. Spec ≈ 1-day effort. Behavioural fixture self-validation needed. Anchor: findings doc + retrospective §7.4 fold table; auditor's iter4 explicit flag at /feature SKILL.md §3.5c stop-criteria evidence. |
| **70** | `probe-shared-lockfile-parsers-extraction` (X16 from radaro post-hoc audit) | **P2 queued — added 2026-05-08** | Probe G + Probe H share ~140 lines verbatim duplication (`LOCKFILE_NAMES` + 7 parsers + `parse_lockfile` + `find_lockfiles` + `to_relpath` + `has_changed_lockfile` + `load_corpus` + emit helpers). Any bug-fix in the parsers (X2/X3/X11/Y1/Y2/Y3 from PR-B) requires editing two files. Extract `hooks/lib/lockfile_parsers.py` callable from both probes via `python3 -c "import lockfile_parsers; …"` or imported into the heredoc. Migrate parser-by-parser to keep smoke green incrementally. Anchor: findings doc X16 (MEDIUM — surfaced by claude, not codex). |
| **71** | `probe-g-drift-threshold-policy-after-corpus-provenance` (X18 ACCEPT follow-up; depends on #68) | **P3 blocked-by-#68** | Drift-threshold policy decision deferred per X18 ACCEPT (user 2026-05-07): keep current `pinned_major >= latest_major - 2 → SKIP` (drift=2 suppressed). Reactivate AFTER #68 ships (corpus carries `last_verified`) so threshold tightening (drift=2 fire vs suppress) can be evaluated against staleness data, not model-memory values. Decision space: (a) keep drift>2 fire (current); (b) tighten to drift≥2 fire (catches Django 3 vs 5, React 16 vs 18); (c) per-ecosystem threshold in corpus. Anchor: findings doc X18 ACCEPT rationale + retrospective §7.4 fold table. |
| **72** | `probe-g-pnpm-version-detection` (X19 — subsumed by Y2 in PR-B; future-format-evolution coverage) | **P3 deferred — reactivate on next pnpm format change** | X19 (LOW originally → upgraded HIGH by codex due to mainstream pnpm v9+ adoption) is subsumed by PR-B Step 5 Y2 fix (regex rewrite handling pnpm v9+ peer-dep + leading-`/`-optional + scoped/unscoped forms). This entry kept as forward-coverage placeholder for future pnpm format breaks (v10+, alternative schemes). Reactivate when: (a) pnpm releases new lockfile schema; OR (b) probe G/H emits 0 findings on a real pnpm repo where staleness was expected. Anchor: findings doc X19 + Y2; PR-B Step 5 implementation. |
| **74** | `spec-kit-hybrid-lift` (selective adoption from GitHub spec-kit; full migration rejected) | code-quality conventions × workflow ergonomics | **P3 deferred — added 2026-05-10 (opportunistic; no current pain anchor)** | Source: user-initiated evaluation 2026-05-10 of GitHub spec-kit (`~/dev/vendor/spec-kit`, Python CLI `specify` via `uv tool install`) as candidate "heavy-lifter" so ai-dev-team becomes thin add-on with minimum preference files. **Verdict: rejected full migration.** Spec-kit is **agent-agnostic + workflow-centric** (generates templates + hooks; user invokes agents manually); ai-dev-team is **agent-centric + orchestration-focused** (auto-spawns cross-auditor/investigator/verifier/spec-compliance-checker as background processes). Architectural mismatch — spec-kit covers ~30-40% of plugin value (spec lifecycle templates, GitHub integration, extension/preset catalog with 180+ entries). Distinctive 60-70% has NO equivalent: cross-model parallel audit with confidence consolidation (community ext `multi-model-review` is external/lightweight); deterministic probes E/F/G/H with receipts + fingerprint_anchors + shadow/warn/block modes; R1-R14 enforced via spec-compliance-checker reading captures (their `constitution.md` is high-level architectural articles, advisory-only); workdoc evidence-capture protocol (red/green/probe captures mandatory); KB-backed session resumption scanning `<kb>/repos/<project>/design/` (their memory = single `constitution.md`); investigator agent (formal multi-round Claude+Codex debate with convergence detection); MCP-Codex tight coupling. Migration would lose enforcement teeth, add Python runtime dependency, and still require Claude Code plugin code for agent spawning — net-zero simplification, net-negative capability. **Hybrid lift scope (each ≈ small spec, not blocking anything)**: (a) **`clarify` phase** in `/feature` between Phase 1 (research) and Phase 2 (spec write) — structured coverage-based ambiguity opensourcer with answers recorded in spec §1.X "Clarifications"; closes the gap where spec-write proceeds with implicit assumptions that surface as cross-auditor X-findings later. (b) **`analyze` read-only consistency check** across spec ↔ implementation-checklist ↔ workdoc — complement to spec-compliance-checker (their gate is consistency, ours is evidence; non-overlapping). Could ship as `agents/spec-consistency-checker.md` or fold into existing `cross-auditor:spec` mode. (c) **`tasks.md` `[P]` parallel-execution markers** — formalize parallelizable steps in implementation checklist (current free-form prose loses parallelism opportunities; explicit `[P]` enables future parallel-developer dispatch). (d) **`extensions.yml` hook-name alignment** — rename our hook points (`SessionStart`/`PostToolUse`/`Stop`) to also accept `before_specify`/`after_implement` aliases so probes/cross-audit could be repackaged later as spec-kit extension if community-publishing path opens (per BACKLOG #74 sibling option B in eval discussion). **Reactivation criteria (per item)**: (a) clarify — first observed cross-audit X-finding traceable to "spec assumption never elicited" (anti-n=1 trigger ≥2 instances); (b) analyze — first observed inconsistency between spec checklist + workdoc that compliance-checker's evidence-only scope missed; (c) `[P]` markers — first observed serial implementation where parallelizable steps were obvious in retrospect; (d) hook alignment — first community interest in publishing probes as spec-kit extension OR first user request to use ai-dev-team agents alongside spec-kit project. **Full re-evaluation trigger**: spec-kit ships native multi-model audit consolidation OR probe-style deterministic verification OR agent-spawning extension API — any one of these flips the cost/benefit. Anchor: this BACKLOG entry + parallel Explore-agent maps recorded in conversation 2026-05-10 (spec-kit structural map + ai-dev-team inventory + 8-section comparison). |
| **73** | `2x-opus-audit-mode-as-first-class-fallback` (codex token-burn-rate vs claude headroom — added 2026-05-08; **PROMOTED P1 2026-05-08** after empirical evidence of correlated blind spots) | **P1 queued — promoted 2026-05-08** | Codex GPT-5.5 xhigh on cross-auditor cumulative-audit prompts burns through monthly token budgets fast (observed 2026-05-08: limit exhausted mid-day → extra-usage billing). Reducing `reasoning_effort` to medium/low is risky — quality of audit findings drops (auditor's job IS exhaustive reasoning over diff + spec; xhigh empirically catches class B "stale-prose-at-parallel-surfaces" which lower tiers miss). Meanwhile user's Claude subscription has substantial headroom — viable to lean harder on Opus and treat 2× Opus parallel as a legitimate first-class audit mode rather than emergency fallback. **Two-auditor invariant retained**: dual-auditor cross-check is non-negotiable per user 2026-05-08 — single-auditor mode lets one auditor "authoritatively create nonsense" with no counterweight. **Protocol correction 2026-05-08 (full-overlap, NOT diversity-framing)**: per user directive «run parallel opus with full overlap - they work separately on one task» — both Opus instances audit the SAME complete diff scope independently. Cross-check value comes from **agreement between halves** (findings reported by BOTH = high-confidence `dual_opus_confirmed`; findings only one half catches = lower-confidence `single_opus`). Diversity-framing approach (auditor A on logic/correctness, auditor B on R-rules/R8/cross-cutting) is BROKEN by construction — produces non-overlapping findings, so neither half validates the other. Spec scope: (a) codify 2× Opus full-overlap dispatch protocol into `agents/cross-auditor.md` as supported mode (alongside Claude+Codex); (b) consolidation rules (`dual_opus_confirmed` when both halves report same defect, `single_opus` when only one half catches; severity-take-higher; source-merge); (c) `audit_evidence: dual_model` semantic — accept "two independent Opus instances" as satisfying dual-coverage intent, with §Process notes disclosure of half-composition (NOT silent misrepresentation); (d) feature-skill-side knob to pick mode (auto-fallback when Codex unavailable / explicit user toggle); (e) update handoff doc §4 to remove obsolete "diversity-framing" prescription and replace with full-overlap protocol. Cost note: 2× Opus parallel ≈ same total Opus tokens as one cross-auditor invocation, no Codex cost — effectively trades Codex extra-usage for additional Opus tokens, cheaper than re-runs caused by Codex hangs. **Empirical evidence 2026-05-08 — correlated blind spots in same-model parallel** (consolidated findings doc `2026-05-08-pr-c-code-audit-consolidated.md` §Protocol learning): two parallel runs were executed today on PR-C diff — Run 1 = orthogonal-framing 2× Opus (Opus-A logic / Opus-B R-rules), Run 2 = full-overlap 2× Opus (identical scope). The full-overlap run surfaced ZERO `dual_opus_confirmed` findings. Empirical re-check (running actual parser pseudocode + grepping smoke pins) confirmed: BOTH full-overlap halves missed two real defects that single Opus halves correctly identified — (i) Z7 footer parser breaks on trailing-newline `$captured` (HIGH; Opus-A caught, Opus-1 + Opus-2 said clean despite Opus-1 running a "6-case bash harness" with wrongly-constructed inputs); (ii) X18(b) missing positive smoke-pin clause for rewritten L428 summary literal (MEDIUM; Opus-B caught, Opus-1 + Opus-2 claimed all directives landed). Same-model instances share training, biases, blind spots → correlated false negatives. The "agreement filter" REMOVED real signal. Codex (genuinely different training) is the missing piece. **Protocol implication**: when Codex unavailable, fallback must be (a) restore Codex ASAP / (b) combine orthogonal+full-overlap runs (4× Opus tokens, max coverage) / (c) add executable-verification step (run actual code, not reason about it) / (d) do NOT treat `dual_opus_confirmed` as quality floor — single-half findings with empirical verification deserve REOPEN. Anchor: handoff doc §4 + consolidated findings doc + user directives 2026-05-08 («codex лимит закончился» / «давай в 2 opus audit дальше» / «но важно иметь всегда прогон двумя аудиторами, т.к. это не дает одному аудитору авторитарно творить херню» / «run parallel opus with full overlap - they work separately on one task» / «wtf - два опуса пропустили то что нашел один?»). |
| **76** | `librarian-kb-actualization` follow-ups (deferred anti-goals from the 2026-05-31 first slice, PR #113 VERIFIED) | process-truthfulness × context-persistence | **✅ CLOSED 2026-06-02 — all (a)-(f)+C2 DONE** | First slice shipped: KB-curator reframe + `tests/kb_drift_scan.py` (C1 broken-wikilink / C2 dangling-§-pointer / C3 spec-status-enum, all path-contained) + `docs/kb-layout.md` extraction + librarian §KB curator (single `auto_safe` autonomy rule). Explicit anti-goals deferred as follow-ups: **(a) curator trigger-model** — ✅ **DONE 2026-06-01 — PR #117, v1.25.0, VERIFIED.** Surface = `/kb-audit` skill (explicit opt-in, grouped C1–C4 output, report-only) + a single non-blocking `### KB drift — <project>` line folded into `/feature status` (session-start fold rejected: anti-nag + static hook can't run code; skill-only rejected: repeats the very friction). Backbone = `--summary` render mode on `kb_drift_scan.py` (pure presentation; behavioral pin mutation-confirmed). Spec `design/2026-06-01-kb-curator-invocation-surface.md`; spec-audit dual_model 3 iters (X1-X6), code-audit dual_model 2 iters (X1 pin-false-green, mutation-confirmed). **(b) status-drift check** — ✅ **DONE 2026-05-31 — PR #116, v1.24.0, VERIFIED** (realized OFFLINE, NOT git). Spec `design/2026-05-31-kb-drift-status-drift-check.md`. `C4_status_drift` flags a pre-code-audit spec (APPROVED/AUDIT_PASSED) carrying a code-audit completion record (non-null `code_audit_evidence` OR a col-0 `code audit passed`/zero-diff Log marker) → status left stale. Git was REJECTED at spec-audit (squash-blind — today's drift was a squash-merge, not a main-ancestor — and breaks the scanner's offline invariant); the frontmatter/Log signal catches the real incident exactly. spec-audit dual_model 3 iters (X1 IN_PROGRESS-FP → X2/X3 propagation+coverage → clean); code-audit dual_model 0C/0H mutation-confirmed. Real-vault C4=0 (structural). **(c) concluded-but-not-ARCHIVED research-note check** — ✅ **DONE 2026-06-02 — PR #120, v1.25.3, VERIFIED. Filed check REJECTED; shipped C5-R instead — CLOSES THE #76 CLUSTER.** Rule #9 + converged /investigate (Claude+Codex, 2 rounds) killed the filed premise: ARCHIVED is unused (0 ARCHIVED notes vault-wide) with NO post-CONCLUDED convention trigger (`skills/research/SKILL.md`: archive optional/cheap/reversible) → flagging it = FP against workflow. All housekeeping variants rejected (concluded-not-ARCHIVED; C5′ ACTIVE-with-conclusion = 0 structural; C5″ CONCLUDED-missing-conclusion = 9/9 noise; cross-file queued→materialization = slug-rename FP + non-conservative; C5-Q scope-prose token = proven FP). **The one defensible survivor shipped: C5-R `C5_research_status_enum_violation`** — a `type: research` doc whose leading-frontmatter `status:` ∉ `{ACTIVE,CONCLUDED,ARCHIVED}` (or missing) → finding, auto_safe:false. Exact C3 analog (source-backed `docs/kb-layout.md:86`, single-file, offline), **type-scoped NOT path-scoped** (8 legacy `type: research-note` notes — 3 off-enum — deliberately skipped = documented conservative FN). Real-vault: C5:2 (0 FP), C1:180 C2:7 C3:0 C4:0 byte-unchanged. Spec `design/2026-06-02-kb-drift-c5-research-status-enum.md`; spec-audit dual_model 3 iters (X1 second-pin `check_kb_drift_summary_behavioral` hard-coded C1-C4 would break `Failed:0`→+row 8; X2 RED-mutation-sensitivity; X3 line-math over-claim→exact `line==4`+detail-substring pin), code-audit dual_model 0C/0H (6-mutation pin campaign all caught). **(d) X3 tightening** — ✅ **DONE 2026-06-02 — PR #119, v1.25.2, VERIFIED.** C1 path-qualified wikilinks now resolve via Obsidian-consistent COMPONENT-SUFFIX matching (not bare-stem): `[[a/Note]]` matches `x/a/Note.md` but `[[wrong/path/Note]]` (no real suffix) is flagged; relative `../.` resolve source-relative + conservative fallback. Design settled by /investigate convergence (the naive exact-root fix would FP valid suffix links; empirical 5-`../`-links sweep killed strict-..-reject). Spec `design/2026-06-01-kb-drift-c1-path-qualified-suffix.md`; spec-audit dual_model 3 iters (X1 6.1-unverifiable→REOPEN vacuous-witness→non-vacuous resolver-unit-witness; X2 stale-gate), code-audit dual_model 0C/0H (pin mutation-confirmed). Real-vault C1 byte-identical (no broken path-qualified link pre-existed in repos/ai-dev-team; catch pinned by fixtures). **Residual (below-floor MEDIUM, ACCEPTED):** degenerate slash-only `[[/]]`/`[[//]]` now resolve clean (`if not parts: return True`) where pre-fix flagged them — never-occurring input, 0 real-vault impact; optional one-line hardening (`return False` or a 5th known-limitations line) deferred LOW. Anchor: PR #113; spec `design/2026-05-31-librarian-kb-actualization.md` §3.6 anti-goals + code-findings X3 ACCEPTED rationale. **DOGFOOD 2026-05-31 (first real-vault run → PROMOTE (e)+(f) to P1): `python3 tests/kb_drift_scan.py <vault> --project ai-dev-team` → 328 scanned, 716 findings, but ~95%+ noise.** **(e) [P1, shipped-but-noisy] C1 matches `[[...]]` inside fenced/inline code AND prose examples** — 450/472 C1 findings are bash `[[ ]]` tests / POSIX `[[:space:]]` regex classes / `=~` snippets inside code blocks; the remaining ~22 are illustrative wikilinks in prose (e.g. the spec's own `[[future-note]]`/`[[Note.md]]` C1-discussion examples). True broken-wikilink count ≈ 0. Fix: strip fenced code blocks + inline-code spans before the `[[...]]` match (Obsidian doesn't render wikilinks in code); consider also skipping wikilinks inside the doc's own prose-quoted examples (harder — lower priority). The clean fixtures in PR #113 had no code blocks, so 3 dual-model code-audit iters missed this — production-cardinality-blindness class (the same class probe-F targets; ironic). **(f) [P1] C2 cross-repo pointers** — many of the 244 C2 are valid KB→plugin references (`skills/feature/SKILL.md §...`, `agents/cross-auditor.md §...`) flagged "target file not found" because the scanner resolves them KB-relative and the plugin repo is outside the vault. Decide: scope C2 to intra-KB pointers only, OR make plugin-repo-root resolvable, OR exclude cross-repo path prefixes. ~~Until (e)+(f) land, the scanner is not usable on the real KB.~~ **✅ (e)+(f) DONE 2026-05-31 — PR #115, v1.23.1, SHIPPED.** Spec `design/2026-05-31-kb-drift-scan-code-awareness.md` (spec-audit dual_model iter-2 0C/0H; code-audit dual_model iter-1 0C/0H). (e) single shared `fenced_line_mask` (CommonMark backtick/tilde, close ≥ opener, unclosed→EOF) consulted by both C1+C2 loops + C1-only inline-code strip. (f) C2 resolution SPLIT (not dropped): in-KB heading-missing → flag; out-of-vault real file (`../`-escape / abs-path) → flag (X5 false-clean lock); resolves-nowhere cross-repo → skip. Real-vault re-run **716 → 201**, zero code-block C1 leaks, zero resolves-nowhere cross-repo C2; residual = prose-example wikilinks outside code (documented anti-goal). **✅ #76 CLUSTER CLOSED 2026-06-02 — all follow-ups DONE: (a) trigger-model PR #117 / (b) status-drift PR #116 / (c) concluded-not-ARCHIVED→REJECTED+C5-R PR #120 / (d) X3 path-qualified PR #119 / (e)+(f) code-awareness PR #115 / C2 cross-repo PR #118.** **C2 CROSS-REPO BASENAME-COLLISION FP — ✅ DONE 2026-06-01, PR #118, v1.25.1, VERIFIED.** Surfaced by the #76(a) /kb-audit dogfood: 28 real-vault C2, 21 false (bare `CLAUDE.md`/`README.md` §-pointers meaning plugin-repo root docs collided with the vault-root same-named files via `cand_root=kb_root/target`). Design settled by /investigate convergence (target-class dispatch resolver). Spec `design/2026-06-01-kb-drift-c2-cross-repo-resolver.md`; spec-audit dual_model 3 iters (X1-X7; iter-1 single_model→re-spawned for policy; X6 CRITICAL N1/N2-coexistence caught only by the dual-model Codex half), code-audit dual_model 0C/0H. Real-vault C2 28→7 (21 collisions→0; 2 abs-path escapes + 5 genuine intra-KB retained; C1/C3/C4 unchanged). Remaining: (d) C1 X3 path-qualified tightening still deferred; below-floor abs-path-escape dedicated fixture optional. |
| **77** | Status-drift reconciliation + 3 never-materialized follow-up specs (surfaced by a 2026-05-31 freshness re-check of two "stale AUDIT_PASSED" specs) | process-truthfulness × context-persistence | **P2 — added 2026-05-31** | A `/feature status`-style scan flagged `2026-05-12-wap-helper-hardening` and `2026-05-12-pointer-integrity-and-single-source-via-delta-hardening` as actionable `AUDIT_PASSED`. Freshness re-check proved BOTH were **fully shipped to main ~2026-05-13** (core files `tests/workdoc_parity_check.py` + `tests/check_dangling_anchors.py` byte-identical to their branches; all pins present; smoke 547/0) — only the KB status fields were stale. Reconciled both → VERIFIED 2026-05-31; their leftover branches (`fix/2026-05-12-*`) are behind main and safe to delete. **This is a concrete live instance validating #76(b) status-drift-vs-git** — a curator check (spec marked AUDIT_PASSED while shipped) would have caught it automatically. **✅ RESOLVED 2026-05-31: #76(b) shipped as C4_status_drift (PR #116, v1.24.0) — realized OFFLINE (frontmatter/Log vs status), git rejected as squash-blind. C4 would now auto-flag exactly this incident class.** **Second loss class found:** the pointer-integrity Log promised 3 follow-up specs that were NEVER created (evaporated from Log narrative — durable queue is BACKLOG, not Log prose): **(i)** `pointer-integrity-doc-cleanup` — 7 doc-only dangling-§-anchor fixes + iter-2 X12-X21 spec-content corrections (likely LOW relevance now: the structural pin `check_no_dangling_section_anchor_references` already closes the CLASS, so verify whether the 7 individual surfaces are still dangling before speccing); **(ii)** `spec-audit-cap-banner-and-empirical-verification` — §3.5c "AWAITING banner on cap, not silent ACCEPT" + "audit claims MUST be empirically verified" (likely ALREADY codified as MISSION rules #9/#11 + the cap-banner that fires in /feature today — verify, then close as done-elsewhere if so); **(iii)** `wap-markdown-aware-parser` — CommonMark tokenizer to replace the asymmetric single-backtick inline-strip (WAP code-audit X5 ACCEPTED-deferred; latent, rare markdown surface, LOW). Action: assess (i)/(ii)/(iii) current relevance — most may already be moot — then either close or materialize the genuinely-open ones. **RELEVANCE VERDICT 2026-05-31:** (i) **OPEN-LOW** — the 8 dangling anchors are real but live in `tests/check_dangling_anchors.py` `KNOWN_RESIDUE` allowlist (class can't grow; these 8 remain as navigation hygiene); materialize a small spec eventually to fix them + shrink the allowlist to 0. (ii) **CLOSED-MOOT** — already codified: empirical-claim verification = MISSION rules #9 + #13 (same 2026-05-13 incident source); cap-banner-not-silent-ACCEPT = rule #11 phase-split + SKILL.md §3.5c. (iii) **PARKED-LOW** — rare-markdown edge, ACCEPTED-deferred at WAP code-audit. Two stale branches deleted 2026-05-31 (were local-only — never pushed to origin, confirming the work reached main via a non-branch path). |

### Convergence open question (D1 — RESOLVED 2026-04-25 → Codex position)

> **D1 — Tier 1 MISSION honesty PR: ship immediately with vague-future enforcement, OR only with a named Tier 3 spec queued?**

**RESOLVED 2026-04-25 → Codex position adopted.**

Strategic rationale (user-confirmed): #46 существует именно чтобы починить claim drift в MISSION.md. Claude position решала это введением нового claim drift («we'll enforce R3-R7 sometime»), self-inconsistent с задачей. Probe series E/F/G precedent = bound contracts с named follow-up; применить ту же discipline к enforcement = consistent. Reader signal от vague future = "rule dead" → R3-R7 silently optional → self-fulfilling prophecy.

**Operational consequence**: #47 (R3 weak-phrase check spec) added как named first Tier 3 slice. MISSION honesty quick-task BLOCKED-by-#47 — ship bundled, не sequentially-without-binding.

---

## P1: High impact

### ~~1. DRY для developer-агентов~~ ✅ DONE (2026-04-17)
Три агента (`developer-codex`, `developer-middle`, `developer-senior`) на 80% дублируют workflow (red/green/probe captures, commit, compliance-checker loop, git conventions, test quality section, linter rules). Любой фикс сейчас приходится применять в 3 местах — это уже привело к drift'у в предыдущих итерациях плагина.

**Решение:** вынести общий workflow в `skills/feature/references/developer-workflow.md`. Каждый агент остаётся только описанием *когда его выбирать* + ссылкой на shared workflow + своими уникальными правилами (Codex — MCP call parameters; Senior — implementation discipline; Middle — pattern-first rule).

**Ожидаемый результат:** каждый агент сокращается со ~100-160 строк до ~40-50. Single source of truth для workflow.

### ~~2. Smoke-test harness для плагина~~ ✅ DONE (2026-04-17)
Плагин не имеет автоматической проверки работоспособности. Прошлый спек (`2026-04-15-plugin-integrity-improvements`) появился именно потому, что функциональные регрессии обнаружились при ручном test-drive. Нужен скрипт `tests/smoke.sh`, который прогоняет mock-lifecycle end-to-end:
- Создаёт временный KB + mock project
- Имитирует `/feature new → approve → skip audit → verify (NO_TESTS) → keep`
- Проверяет что состояния спека переходят корректно
- Проверяет что `/feature status` видит спек
- Проверяет что SessionStart hook отдаёт корректный JSON

**Почему это P1:** плагин распространяется через marketplace — регрессия ломает всех пользователей сразу.

### ~~3. Troubleshooting секция в README~~ ✅ DONE (2026-04-17)
Типовые факапы при установке, которые сейчас никак не покрыты:
- Codex MCP не установлен → cross-audit падает
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` не выставлен → team-based агенты не работают
- SessionStart hook не срабатывает → нет ambient workflow
- Репо использует base-ветку не master/main (develop, trunk) → baseline check падает
- KB-директория существует, но `repos/<project>/` нет → первый `/feature new` падает на `mkdir`

### ~~26. Finalize DONE→VERIFIED status migration (drift cleanup)~~ ✅ DONE (2026-04-20) — PR #22

Миграция `DONE → VERIFIED` как терминального статуса спеки начата в feature-skill, но не докручена до конца. Проявляется в трёх местах:

- **D1 — `agents/librarian.md:63-75`** перечисляет `status: DRAFT | APPROVED | AUDIT_PASSED | IN_PROGRESS | DONE | DISCARDED`. Нет `SHIPPED`, `VERIFIED`, `BLOCKED`. `DONE` показан как нынешний терминал вместо legacy-синонима. Librarian — важный source-of-truth для любого агента, читающего KB-конвенции.
- **D2 — `skills/feature/SKILL.md:602-603`** (`/feature discard`) отказывает только на `DONE` и `DISCARDED`. `VERIFIED` (нынешний терминал) и `SHIPPED` (смёржено, открыт post-merge checklist) — не покрыты. Теоретически discard удалит ветку после merge, что пользователю не нужно.
- **D3 — `skills/feature/SKILL.md:687`** (`/feature checklist add`) отказывает на `VERIFIED / DISCARDED`, но не на legacy `DONE`. Тот же класс ошибки.

**Решение:**
- Обновить `librarian.md` enum: `DRAFT | APPROVED | AUDIT_PASSED | IN_PROGRESS | BLOCKED | SHIPPED | VERIFIED | DISCARDED`, с явной отметкой `DONE` как legacy-read-only синонима `VERIFIED`. Переписать transitions section под текущий state machine (включая SHIPPED и VERIFIED terminal paths).
- `/feature discard` — добавить `VERIFIED` и `SHIPPED` в refuse-list с разъяснением (SHIPPED уже смёржено; VERIFIED — полный terminal). Сообщения должны различать "revert the merge commit" (для смёрженных) vs "spec is already closed" (для VERIFIED).
- `/feature checklist add` — добавить `DONE` в refuse-list (наравне с `VERIFIED`).
- Запретить silent absence: smoke-assertion проверяет, что все четыре terminal/merged статусы (`DONE`, `VERIFIED`, `SHIPPED`, `DISCARDED`) упомянуты в соответствующих refuse-lists.

**No-regression constraint:** текущее поведение для валидных статусов (DRAFT/APPROVED/AUDIT_PASSED/IN_PROGRESS/BLOCKED) не меняется. Добавляются новые отказы — старые не убираются и не ослабляются. Смоковые тесты, которые сейчас проходят, должны продолжать проходить.

**Почему P1:** прямой функциональный гэп — discard на VERIFIED спеке делает вещь, которую пользователь явно не хочет; Librarian вводит в заблуждение внешние агенты, читающие его как конвенцию.

**Источник:** drift-and-dedupe audit 2026-04-20.

### ~~27. Remove orphaned `codex-implement.md`~~ ✅ DONE (2026-04-20) — PR #23

Файл `skills/feature/references/codex-implement.md` (36 строк) — альтернативный промпт-шаблон для Codex-разработчика. После landing'а `2026-04-17-dry-developer-agents.md` канонический шаблон живёт в `agents/developer-codex.md` (`## Codex Prompt Template`) и дополняется shared per-step protocol'ом в `skills/feature/references/developer-workflow.md`. `codex-implement.md` ни одним skill'ом и ни одним агентом не ссылается (grep по всему плагину = 0 попаданий); при правке промпта люди могут пропустить его и получить drift.

**Решение:**
- Удалить `skills/feature/references/codex-implement.md`.
- `tests/smoke.sh` уже проверяет существование остальных references — добавить отсутствующую assert'у (или расширить `references-sanity-check`) что `codex-implement.md` отсутствует (negative assertion на забытый re-add).
- Git log показывает legacy-происхождение файла — при необходимости сохранить копию в `docs/archive/` на один коммит, если нужна audit trail. Иначе — чистое удаление.

**No-regression constraint:** файл orphaned; его удаление не затрагивает ни один runtime-путь. Проверка: `grep -r codex-implement /Users/th13f/dev/personal/ai-dev-team` = пусто после удаления.

**Почему P1:** нулевой риск, мгновенный win по снижению неоднозначности источника истины.

**Источник:** drift-and-dedupe audit 2026-04-20.

### ~~28. Extract shared Phase 0 (KB discovery) reference~~ ✅ DONE (2026-04-20) — PR #24

Phase 0 (discovery `kb_path` и `project` через `.ai-dev-team.local.yml → .ai-dev-team.yml → memory → sibling → ask`) дублируется в 3 из 4 SKILL.md:
- `skills/feature/SKILL.md:43-69` — 30 строк, каноничная (обрабатывает `codex.model`, `codex.model_fast`, `codex.reasoning_effort`)
- `skills/cross-audit/SKILL.md:36-80` — 45 строк (тот же алгоритм + `github:` блок, явно запрещает `codex.model_fast`)
- `skills/research/SKILL.md:31-43` — 13 строк (сжатая форма, явно говорит "Identical to /feature Phase 0 — re-use", но всё равно дублирует шаги)
- `skills/investigate/SKILL.md` — вообще не имеет Phase 0 (проверить, должен ли быть для `--codebase` режима; либо отсутствие — осознанное решение)

Дрейф уже заметен: cross-audit явно говорит "never read `codex.model_fast`", feature говорит как его читать — но эти оговорки закопаны в 80+ строках дублирующегося текста.

**Решение:**
- Вынести общий алгоритм в `docs/kb-discovery.md` (или `skills/_shared/phase0.md` — выбрать где больше соответствует существующей конвенции `docs/user-input-banner-convention.md`). Содержит 11-шаговый алгоритм как единый источник истины.
- В нём же задокументировать per-skill extensions: feature читает `codex.model` + `codex.model_fast`; cross-audit читает `codex.model` + `github:` блок, запрещает `codex.model_fast`; research читает только `kb_path`/`project`; investigate — не читает Phase 0 (обосновать почему).
- Все 4 SKILL.md ссылаются одной строкой (по образцу banner-convention): `"KB discovery follows docs/kb-discovery.md. See §skill-specific extensions for this skill's config keys."`
- `tests/smoke.sh` — новая assertion: каждый SKILL.md содержит ссылку на `kb-discovery.md` + отсутствует inline-repeat алгоритма (grep-based: 11-шаговая последовательность должна встречаться в plugin ровно 1 раз, в shared reference).

**No-regression constraint:** поведение каждого skill'а в Phase 0 остаётся полностью идентичным — все fallback'и, все edge cases (malformed YAML, BOM, sibling heuristic, memory fall-back), все error-messages сохраняются **byte-for-byte**. Тестовая стратегия:
- Baseline: `tests/smoke.sh` фиксирует текущие Phase 0 инварианты (which skill reads which config key, какие prompt-строки появляются при sibling-confirm, при `.ai-dev-team.yml` save y/n).
- Pre-refactor: добавить недостающие assertions, если текущее покрытие неполное (иначе рефактор можно сломать незаметно).
- Post-refactor: те же самые assertions зелёные.

**Почему P1:** самый крупный единичный источник risk-of-drift в плагине (80+ строк дублирования). Выигрыш — -120 строк в SKILL.md, +1 shared doc, нулевой функциональный δ.

**Источник:** drift-and-dedupe audit 2026-04-20.

---

## P2: Medium impact

### ~~4. BLOCKED / ON_HOLD статус для спеков~~ ✅ DONE (2026-04-17)
Текущий state machine: `DRAFT → APPROVED → AUDIT_PASSED → IN_PROGRESS → DONE/DISCARDED`. Нет состояния для "начали, но ждём внешнюю зависимость" (другая команда фичу релизит, библиотека апдейтится, решение нужно от продукта). Сейчас такие спеки висят `IN_PROGRESS` и мешают в `/feature status`.

**Решение:** добавить `BLOCKED` (с обязательной записью в Log об условии разблокировки) + фильтр в `/feature status`.

### ~~5. `/feature continue` — помнить выбранного агента~~ ✅ DONE (2026-04-17)
Сейчас при resume skill каждый раз перепрашивает "which agent to use". Если работа уже шла через Codex — логично продолжить им же, если только пользователь не переключится явно.

**Решение:** хранить `last_agent` в спеке (поле frontmatter или в Log), предлагать его как default в continue mode.

### ~~6. Research skill~~ ✅ DONE (2026-04-17)
`librarian` знает путь `research/` и subtype'ы (`incident-investigation`, `math-model`, `competitive-analysis`, `exploration`). Но driver-скилла нет — для создания research-заметки надо руками копировать template и путь.

**Решение:** `/research new <title>` + `/research continue <path>` + статусы `ACTIVE/CONCLUDED/ARCHIVED`. Похоже на `/feature`, но без implementation-фазы (research не имеет checklist).

### ~~7. Мост `/investigate` → `/feature new`~~ ✅ DONE (2026-04-17)
Convergence report от `/investigate` содержит готовое дизайн-решение. Сейчас пользователь копирует его вручную в Context новой фичи.

**Решение:** `/feature new --from-investigation <path>` — автоматически подтягивает recommended approach + risk register в секцию Context.

### ~~8. `Stop` hook — warning о незакрытых спеках~~ ✅ DONE (2026-04-17)
Если сессия завершается с `IN_PROGRESS` спеком, где есть uncomittered изменения или красная compliance-проверка — напомнить пользователю, что work висит.

### ~~9. Compliance-checker — поддержка amend/merge commits~~ ✅ DONE (2026-04-17)
`spec-compliance-checker` делает `git diff <first_sha>^ <last_sha>` из `observed.commit_shas`. Если пользователь (или Codex) сделал `git commit --amend` или merge — SHA невалидный, чекер не находит коммит и фейлит.

**Решение:** хранить intervals (range tags) или commit messages; при невалидном SHA фоллбек на `git log --grep` или диапазон по дате.

### ~~15. Branch prefix по сути изменения, а не дефолтный `feature/`~~ ✅ DONE (2026-04-18)
Feature-skill жёстко шьёт `branch: feature/YYYY-MM-DD-<slug>` в spec-template и SKILL.md. Для чистого бага получается `feature/...`, хотя по conventional-prefix (feat/fix/refactor/ci/docs/test/chore) должно быть `fix/...`. Реальный кейс: недавний коммит в soroban-amm сидел на `feature/...`, хотя это был явный фикс — это ломает release-notes категоризацию и вводит в заблуждение reviewer'ов.

**Решение:**
- При `/feature new` спросить или вывести тип изменения (feat / fix / refactor / ...), подставить его в `branch:` spec-frontmatter и во все места SKILL.md где упоминается `feature/YYYY-MM-DD-<slug>`.
- Код-квалити правило в `code-quality-rules.md`: "branch prefix matches change nature".
- ai-dev-team CLAUDE.md уже содержит список префиксов — связать.

### ~~16. Tests в отдельных файлах, не inline в impl~~ ✅ DONE (2026-04-18 as R5)
Unit-тесты для smart-контрактов (Soroban, любой Rust) должны лежать в отдельном файле (`tests.rs` / `tests/` модуль), не `#[cfg(test)] mod tests` внизу impl-файла. Реальный кейс: `AquaToken/soroban-amm feature/2026-04-17-plane-l2-wordbitmap` — тесты inline, PR #159 — тесты вынесены. Inline-тесты раздувают contract-файл, мешают review, расходятся с project convention.

**Решение:** правило в `skills/feature/references/code-quality-rules.md` (и/или `developer-workflow.md`) — "place tests in a dedicated test file; never inline `#[cfg(test)] mod tests` in an implementation file". Уточнить, что это не Rust-idiom'овская рекомендация, а проектное правило — developer должен проверить convention репозитория (зеркалить существующий паттерн).

### ~~17. Сильные тесты вместо количества слабых~~ ✅ DONE (2026-04-18)
Реальный кейс: в `stellar-liquidator-py` найдены "слабые" тесты — проходят всегда, не ловят регрессий, дублируют язык контрактов (getter возвращает что сет'нули, функция не кидает при валидном входе, мок был вызван). Они дают зелёное CI и ложную уверенность, а при рефакторе ломаются первыми — чистый maintenance overhead без signal. Существующие правила `code-quality-rules.md` R1 (dead-code tests) и R2 (trust tiers) это не покрывают: они про тесты умершего кода и про "не верь fresh test'ам против intent", а не про **силу самого теста**.

**Решение:** добавить правило R3 "Test strength / signal-to-noise" в `skills/feature/references/code-quality-rules.md`. Критерии сильного теста (draft):
- падает, если удалить или перевернуть условие в production-коде (mutation-test stance)
- проверяет наблюдаемое поведение на границе, а не внутреннюю реализацию (не "метод вызвался с такими аргументами", а "результат по контракту")
- не дублирует то, что уже гарантирует тайп-чекер / ORM schema / framework

Прописать анти-паттерны (tautological assert, setter-getter round-trip, mock-call-counter как единственное assertion'ом, `assertIsNotNone` на возврат функции, которая никогда не возвращает None). Подсветить из developer-workflow чтобы агенты не заваливали спек слабыми тестами ради покрытия. Критерий: fresh test в green_capture должен объяснять **почему именно он ловит регрессию** (одной фразой в notes), иначе не считается.

### ~~18. Формализовать выбор developer-агента (codex / middle / senior)~~ ✅ DONE (2026-04-18)
Сейчас правила «кого звать» размазаны по описаниям агентов (`agents/developer-*.md`) и полагаются на Claude intuition в момент задачи. У конкурентных сетапов (Cursor+Composer+Codex+Claude) — явная маршрутизация по правилам сложности. Иногда в наших спеках senior берёт pattern-following таск, иногда codex получает ambiguous scope и буксует.

**Решение:** вынести эвристику выбора в один section в `skills/feature/SKILL.md` или `skills/feature/references/agent-routing.md`. Явные триггеры:
- `developer-senior` — cross-cutting refactor, new abstraction, security-touching, ambiguous scope, Soroban contract logic
- `developer-middle` — pattern-following (add endpoint by example, test by example), clear scope, minor refactor
- `developer-codex` (default) — spec has explicit file paths + clear requirements; well-specified tasks

Плюс checklist-gate в `/feature new` перед handoff к developer: который раздел триггеров совпал + rationale. Сейчас это implicit — хочется explicit traceability.

**Источник:** анализ сетапа Uladzimir Urbanovich (2026-04-17), где Cursor-агент сам роутит задачи между Composer Fast / Codex / Claude по правилам.

### ~~19. Multi-GitHub-account поддержка для PR-aware cross-audit~~ ✅ DONE (2026-04-18)
Спек `2026-04-17-pr-aware-cross-audit` вводит плотную интеграцию с `gh api` (PR discovery, publish findings). Но `gh auth` — это одна активная учётка на хост; у пользователя могут быть параллельные GitHub accounts (личный + корпоративный + GHE). Для git-операций это решается кастомным `~/.ssh/config` + разными SSH-ключами per host-alias. Для `gh api` — так не работает: оно ходит через `https://api.github.com` и берёт токен из единственного auth-контекста.

Варианты (из грубо простых в сложные):
- `gh auth switch --user <login>` / `--hostname <host>` перед каждым PR-mode запуском — пользователь руками перед командой.
- `GH_TOKEN` env-var override per invocation (`GH_TOKEN=... gh api ...`) — скилл может подхватить токен из env.
- Новая секция в `.ai-dev-team.local.yml`:
  ```yaml
  github:
    default_account: personal        # one of the accounts below
    accounts:
      personal:
        token_env: GH_TOKEN_PERSONAL  # skill reads this env var at runtime
      corp:
        token_env: GH_TOKEN_CORP
        host: github.company.com
  ```
  `/cross-audit pr <N> --account corp` → скилл выставляет `GH_HOST` / `GH_TOKEN` перед `gh api` вызовами. URL-форма `pr https://ghe.company.com/.../pull/<N>` автоматически роутится на `corp` через сопоставление хоста.

**Почему в бэклоге, а не в текущем спеке:** одна активная учётка (дефолт `gh auth status`) покрывает подавляющее большинство случаев. Multi-account — реальная боль, но для пользователей, которые уже профессионально работают с несколькими организациями. Решение в `.ai-dev-team.local.yml` требует доп. полей и preflight-логики, что раздувает текущий спек. Когда созреет потребность — сделать отдельной фичей.

**Источник:** пользовательский комментарий 2026-04-17, в контексте спека PR-aware cross-audit: «я это у себя решал с помощью разных ssh ключей и перегруженного ssh config файла, но в случае более плотной интеграции с github api нам надо будет придумать что-то другое».

### ~~20. Высоковидимый маркер для user-input промптов в skills~~ ✅ DONE (2026-04-17)
Пользователь возвращается в чат в середине flow, видит активность tool-use'ов и не сразу замечает, что на самом деле ждут его апрува/выбора. Такое случалось неоднократно (HARD GATE по спеку — самый частый кейс). Сейчас в SKILL.md у феты/аудита/investigate промпты-ответы просто заголовком `## ...` или inline-текстом в конце длинного status-update'а.

**Решение:** ввести единый visual convention для всех user-input промптов во всех skill'ах плагина:
- Горизонтальный разделитель `---` перед промптом.
- Стандартный баннер-заголовок `## ⏸ AWAITING YOUR INPUT` (или `## ⏸ APPROVAL REQUIRED` для HARD GATE).
- Конкретный bold-вопрос в самом конце (`**Approve to proceed?**`).
- Запретить inline-вопросы внутри абзаца или в конце длинного сообщения — они теряются при возврате в чат.
- **Negative rule (feedback 2026-04-17, позже по тому же спеку):** не ставить баннер, если нет реального вопроса. Чистый status-update (фоновый агент работает, ждём notification) — никакого `## ⏸ AWAITING YOUR INPUT`. Баннер на пустом месте подрывает доверие к самому механизму: в следующий раз пользователь проигнорирует настоящий approve.

### ~~21. Опциональный режим "Codex Fast" для developer-codex / cross-auditor~~ ✅ DONE (2026-04-18)
Пользователь рассматривает Codex Fast (faster variant — `gpt-5.3-codex-fast` или аналог) как опцию. Это быстрее и дешевле, но рассуждательная глубина ниже — не годится для sensitive кода (контракты, security), годится для хорошо-специфицированных шаблонных задач. Сейчас Codex-модель зашита через `.ai-dev-team.yml codex.model` (один глобальный выбор на проект).

**Задача:** продумать, как сделать Fast-режим **опциональным и выбираемым per-task**, а не глобальным. Варианты (брейнсторм):
- Per-step флаг в spec frontmatter / checklist: `- [ ] Step N: ... @fast` → feature-skill передаёт `codex_model: gpt-5.3-codex-fast` только для этого шага.
- Новое поле в `.ai-dev-team.yml`: `codex.model_fast: <model>` — включается через `/feature implement --fast` или агент-selection prompt "codex (normal) vs codex-fast".
- Эвристика по размеру allowed_scope / сложности step — fast для односрочного touch-and-go, normal для cross-file.
- Запретить Fast в cross-auditor (аудит требует глубокого рассуждения) — только developer-codex.

**Open questions:**
- Есть ли у Fast-варианта отдельный endpoint / auth, или просто другое имя модели?
- Как обрабатывать ситуацию, когда пользователь выбрал Fast, а step оказался сложнее ожидаемого (нужен fallback/escalate механизм)?
- Стоит ли UI-подсказка при выборе Fast ("этот step touches security-sensitive code — рекомендую normal")?

**Почему в бэклоге:** текущий один глобальный `codex.model` работает; Fast — оптимизация скорости/цены для подходящих задач. Нужно сначала понять, какие задачи реально подходят, и только потом делать механику выбора. Иначе рискуем перевести весь flow на Fast "по умолчанию" и потерять качество на тех степах, где рассуждение действительно нужно.

**Источник:** пользовательский комментарий 2026-04-17, в контексте текущего спека PR-aware cross-audit.

### ~~22. R4 — Test scope: core tests exercise the user-facing contract~~ ✅ DONE (2026-04-18 as R6)
R3 (#17) закрывает **силу** отдельного теста (ловит ли он регрессию). Ортогональный вопрос — **на каком уровне** тест прикладывается к системе. R4 это формализует.

Опирается на Vladimir Khorikov, *Unit Testing: Principles, Practices, and Patterns* (2020) — его framework почти 1:1 ложится на эмпирические наблюдения, которые привели к этому правилу. Используем его vocabulary как rationale.

#### Khorikov's 4 pillars of test value (обоснование R4)
Каждый тест оценивается по четырём независимым осям:
1. **Protection against regressions** — насколько тест способен поймать реальный баг.
2. **Resistance to refactoring** — насколько тест *не* ломается при изменении внутренней реализации, когда user-visible поведение не меняется.
3. **Fast feedback** — скорость прогона.
4. **Maintainability** — читабельность / сложность поддержки.

Ключевой инсайт: между (1) и (2) — **трейд-оф**. Тест, привязанный к внутренним коллабораторам (моки, прямые вызовы private-функций), может покрывать каждую строку кода и давать зелёное на любой мелочи — формально высокий (1), — но любая переработка внутрянки его ломает без реального регресса (низкий (2)). Обратно: тест, который ходит только через публичный контракт, ломается только когда действительно сломалось user-visible поведение — высокий (2), — и если контракт покрыт честно, то одновременно высокий (1). R4 это правило как раз про то, **как одновременно максимизировать (1) и (2)**.

(3) и (4) важны, но второстепенны: медленные тесты — тоже плохо, но это решается отдельно (in-process harness ниже), а maintainability автоматически получается выше, когда тестов меньше и они высокоуровневые.

#### Classical school — мок только out-of-process границы
Khorikov чётко делит школы: **Classical (Detroit)** vs **London (mockist)**. Правило R4 — Classical:
- Мокать нужно **только out-of-process зависимости** (сеть, внешний HTTP, брокер, stdout как боевой канал). Внутри процесса — реальные коллабораторы, реальные классы, реальная БД.
- Абстракции ради тестирования (seam'ы) вставляются **только на out-of-process границе**, иначе это mocking-theatre: создаёт иллюзию покрытия и ломает (2) resistance-to-refactoring.
- **Unit-тест** по Classical = "verifies a single unit of behavior, quickly, **in isolation from other tests**" (не от продакшн-кода). Изоляция — про параллельный запуск и отсутствие shared state, не про mock'и.

#### Принцип
Самые ценные тесты воспроизводят реальное пользовательское взаимодействие максимально близко к тому, как оно пойдёт в проде, **при минимуме out-of-process зависимостей в тест-ране**. Разделяем:
- **Что убираем из теста:** транспорт и отдельные процессы (веб-сервер, RPC-нода, брокер, docker-compose стек). Это оверхед без signal — те же code-path'ы работают и in-process.
- **Что оставляем реальным:** бизнес-слой, ORM, тестовую БД (Khorikov явно рекомендует real DB в integration-тестах, transaction rollback per test — не моки и не in-memory SQLite подмена).

Полученный тест — Khorikov-style integration test: высокие (1) и (2), приемлемые (3) и (4), покрывает одновременно и интерфейс, и боевые слои.

#### Эталонные реализации
- **Django REST API** → DRF `APIClient` / Django `Client`. Под капотом собирает `WSGIRequest` и вызывает view напрямую, не поднимая runserver/gunicorn. Авторизация — `client.force_authenticate(user)`; транзакции БД — реальные (`TestCase` оборачивает каждый тест в `atomic()` + rollback). **Трейд-оф:** WSGI-middlewares не выполняются (это осознанная цена за скорость и отсутствие отдельного процесса). Для того, что реально завязано на middleware (auth-заголовки, CORS preflight, rate-limit), — отдельный узкий тест; core-поток — через APIClient. **Это канонический Khorikov integration test**: реальная БД, реальный view, реальный serializer, реальный ORM; мок-граница — только там, где запрос уходит из процесса.
- **Смарт-контракт (Soroban)** → invoke через contract client в `Env::default()` / `Env::from_ledger_snapshot`. Env — in-process, никакой отдельной ноды; storage, auth, invocation идут через честный host-function stack. Для реалистичности — snapshot живой сети (balances, соседние контракты).
- **EVM-контракты** → `forge test --fork-url` на mainnet/testnet. Anvil/REVM поднимаются in-process внутри forge, не отдельный geth. Газ, storage layout, взаимодействия с живыми зависимостями — честные. Для симуляции интересующих нас стейтов — снимки позиций, pools, oracle-feeds.
- **Python-библиотека** → вызовы через публичный API пакета, никаких запусков subprocess'ов / docker'ов ради юнит-слоя.

**Общее правило:** тест бьёт в боевые слои (view/controller/contract-method, ORM, реальная тестовая БД-транзакция), но транспорт и отдельные процессы симулируются внутри того же процесса. Всё, что "поднимается как отдельный сервис" (веб-сервер, RPC-нода, брокер, реальный http-клиент против localhost:PORT), — запах: либо in-process аналог есть и надо его использовать, либо тест помечается как отдельная, дорогая категория (smoke / e2e), и их держат мало.

#### Иерархия (в terms Khorikov'а)
- **Core tests** — high-level, через публичный API / user-facing contract, с реалистичными данными. Одновременно высокие (1) protection-against-regressions и (2) resistance-to-refactoring. Обязаны падать если user-visible поведение сломалось.
- **Unit-тесты deep internals** — допустимы, но по Khorikov'у score'у обычно низкая (2): ломаются при рефакторинге без реального регресса. Маркируются соответственно (trust tiers — R2); не могут служить единственным источником confidence для core-контракта.

#### Обоснование (архитектурное)
Внутренняя реализация должна быть качественной, но в конечном итоге решает то, что видит пользователь. Идеальная внутрянка + недостаточный или кривой интерфейс — это **бо́льшая** проблема, чем шероховатая внутрянка при чистом интерфейсе. Тесты через user-facing contract ловят обе проблемы одновременно; тесты deep internals — только одну из двух.

#### Решение
- Добавить правило R4 "Test scope — core tests exercise the user-facing contract" в `skills/feature/references/code-quality-rules.md`. Три части (Rule / Why / How to apply):
  - **Rule**: core test exercises the system through its user-facing contract (HTTP endpoint, contract method, public API of a library) using an in-process harness that replaces only the out-of-process transport. Internal collaborators are real; only out-of-process dependencies may be substituted.
  - **Why**: Khorikov's 4-pillar framework — trade-off between (1) protection against regressions and (2) resistance to refactoring. Tests coupled to internal collaborators score high on (1) but collapse on (2); tests against the user-facing contract score high on both simultaneously. Cite Khorikov (2020) chs. 1, 4, 5, 7 as reference.
  - **How to apply**: per-stack guide (Django APIClient, Soroban contract client in Env, forge fork-test with snapshot, Python package API).
- В `skills/feature/references/developer-workflow.md` §Test Quality — строчка: "Core tests exercise the user-facing contract via an in-process harness (not through a spawned server/node). See R4 for the 4-pillar framework and per-stack guide."
- Связать с R2 trust tiers: core-статус теста = (тест ходит через user-facing contract via in-process harness) AND (тест не был добавлен на текущей ветке). Сейчас "core" = "не fresh"; добавить второе условие.
- Анти-паттерны для R4 (Khorikov-vocab):
  - **Overspecification** — assertion на communication (mock.assert_called_with) как единственное утверждение; тест ломается при рефакторинге без регресса → низкий (2).
  - **Leaking implementation** — тест импортирует приватный модуль / service-функцию, которая не является user-facing → низкий (2).
  - **Spawned-process smell** — тест поднимает runserver / geth / отдельный брокер там, где есть in-process аналог → пускает пожар в (3) и (4) без выигрыша в (1) и (2).
  - **In-memory substitution** — подмена реальной БД на in-memory SQLite / fake ORM ради скорости; Khorikov прямо против (тест теряет (1) на SQL-specific багах). Правильнее — реальная БД того же диалекта с rollback.
  - **Mock-heavy unit masquerading as integration** — название файла `test_integration.py`, но все dep'ы замоканы; нет ни одного реального слоя ниже SUT.

#### Почему отдельно от R3, а не сливаем
R3 про **силу отдельного теста** (signal vs noise одного assertion'а) — в Khorikov-терминах pillar (1) protection-against-regressions при фиксированном scope. R4 про **scope** — на каком уровне прикладываемся. Разные оси оценки, разные анти-паттерны, разные фиксы. В Khorikov'ой модели они обе нужны одновременно — сильный тест на слабом scope'е = unit на internal helper (формально сильный assertion, но ловит не то); слабый тест на правильном scope'е = tautological API test (бьёт через endpoint, но assertion бесполезен). R3 без R4 и наоборот — каждая половинка.

**Источник:** пользовательский эмпирический опыт (2026-04-18) + Vladimir Khorikov, *Unit Testing: Principles, Practices, and Patterns* (Manning, 2020).

Применить к:
- `skills/feature/SKILL.md` — HARD GATE approve, audit yes/skip, agent selection, handoff 4 options, scope-addition fork, BLOCKED unblock-check, discard confirmation.
- `skills/cross-audit/SKILL.md` — per-finding fix/accept/defer decision; add publish.md decision после спека #17 (этого).
- `skills/investigate/SKILL.md` — recommendation adopt / discard.
- `skills/research/SKILL.md` — subtype disambig.

**Почему P1/P2:** ошибка UX приводит к реальной потере минут/часов — пользователь ждёт ответа, я жду ответа, оба молчим. Исправление дешёвое (правка markdown-шаблонов в SKILL.md).

**Источник:** feedback 2026-04-17 по текущему спеку: «я несколько раз приходил в данный чат, видел что идет флоу в середине (как будто от меня ничего не нужно) и не с первого раза увидел что там на самом деле требуется мой апрув по спеке. надо увеличить видимость».

### ~~23. Retrofit Khorikov vocabulary в R1/R2 + §Test Quality~~ ✅ DONE (2026-04-18)
R4 (#22) и R3 (#17 Step 2 narrative) явно опираются на Khorikov's 4-pillar framework (Unit Testing: Principles, Practices, and Patterns, Manning 2020). R1 и R2, написанные раньше, не используют эту терминологию — у них свой язык ("dead code isn't kept alive by its own tests", "trust tiers"). Смысл при этом совпадает с Khorikov'ом:

- **R1 (dead-code tests)** = pillar (1) protection-against-regressions **без** соответствующего production-кода, который можно сломать → тест формально зелёный, но не защищает ничего. Khorikov называет это "no behaviour under test"; R1 формулирует через "no production consumer". Одна и та же мысль.
- **R2 (trust tiers: core vs fresh)** = **фактически** Khorikov'ое "tests as evidence" — fresh test = test-as-specification, не test-as-evidence; core test = test-as-evidence (потому что пережил рефакторинги и соответствует подтверждённому intent'у). В Khorikov'ой терминологии это pillar (2) resistance-to-refactoring в действии: core test прошёл сквозь N рефакторингов без изменений → высокий (2) подтверждён эмпирически, следовательно assertion'у можно верить. Fresh test ещё не прошёл этот фильтр.
- **§Test Quality в developer-workflow.md** — сейчас про "match existing structure / exact assertions / derived expected values / no time/random". Все четыре пункта можно переформулировать через pillars: exact assertions → (1); no time/random → (3) и (4); derived expected values → (2) и (4) — и тогда §Test Quality становится operational companion to R3/R4.

**Задача:**
- R1 — добавить "Why" абзаца ссылку на Khorikov ch. 7 (Humble Object + identification of what's testable); одна строчка "R1 = Khorikov's no-behaviour-under-test anti-pattern applied to the specific case of dead production code".
- R2 — добавить "Why" ссылку на pillar (2) resistance-to-refactoring как эмпирическую верификацию. Объяснить, почему core > fresh в trust'е — через "test has survived N refactorings without change → high (2) empirically confirmed".
- §Test Quality — переформулировать каждый пункт через pillar'ы (явно подписать: "supports pillar (X)").
- В preamble `code-quality-rules.md` добавить параграф "Shared framework" с кратким изложением 4 pillars и цитированием Khorikov — чтобы R1–R4 ссылались на один общий словарь, а не каждое правило заново объясняло.

**Почему в бэклоге, а не сливаем в R4:**
- R4 вводит *новое* правило — там Khorikov'а вводим свежим текстом, естественно.
- Ретрофит R1/R2/§Test Quality — это переработка *уже задеплоенных* правил. Нужна аккуратность: смысл не должен поехать, поведение compliance-checker'а не должно измениться. Отдельный спек с явным "no behavioural change, vocabulary only" диффом.
- R1/R2 стабильны и работают; ретрофит — unification, а не фикс бага.

**Приоритет:** P2 medium — unification даёт долгоиграющий выигрыш (новые правила R5, R6… будут писаться в одной терминологии; compliance-checker сможет reason'ить через одну модель), но не блокирует ничего.

**Источник:** пользовательское требование (2026-04-18): «формализовать свой опыт + Khorikov в скилы, которые будут применяться». R4 (#22) и R3 (#17) уже в Khorikov-словаре; retrofit замыкает круг.

### ~~24. Fixture-based self-test harness для `tests/smoke.sh` scoped assertions~~ ✅ DONE (2026-04-19)
В ходе iter-7 cross-audit спека #17 (R3 test strength) всплыл class-of-bug: любая section-scoped smoke-assertion, чья "proof of scoping" сводится к substring-presence grep'у на источник `tests/smoke.sh`, спуфится inert-текстом — комментарием, строковым литералом, heredoc'ом. Для R3 это означает, что Step 1 `passing_test_cmd` (инварианты invariant-2: canonical-line-freeze + `"$R3"` co-occurrence) строго говоря не доказывает, что (c) и (d) действительно читают из `"$R3"` — developer может написать whole-file-grep (c)(d) против `"$CQR"` и удовлетворить инвариант, разместив канонический текст в комментарии. В R3 это задокументировано как MEDIUM acknowledged-deferred (§3.6 Risks, Log entry iter-7); корректный структурный фикс — отдельный скилл-level рефакторинг:

**Задача:**
- Вынести body каждой section-scoped check из inline `check "<label>"` в именованную функцию в новом файле `tests/smoke-helpers.sh` (например `check_r3_section_has_tokens`, `check_dwf_section_has_sentence "$path" "$heading" "$sentence"`). `tests/smoke.sh` будет sourc'ить этот файл и вызывать функции.
- Создать набор fixture'ов `tests/fixtures/` — minimal markdown файлы, в которых целевые токены размещены в **неправильной** секции (например `r3-wrong-section.md`: `## Other Section` содержит `tautological`, а `## R3 — Test strength / signal-to-noise` — нет).
- Переписать `passing_test_cmd` каждой spec'и, которая сейчас полагается на smoke section-scoping: вместо "grep smoke.sh source for canonical line" exercise'ить extracted helper против fixture и ассертить non-zero exit. Это behavioral proof, а не substring-presence; inert text не может удовлетворить (code actually runs, wrong-section returns non-match, helper returns nonzero).
- Опциональный побочный фикс — тот же harness дешёво закрывает X14 MEDIUM (adjacent-duplicate-heading): fixture с двумя идентичными заголовками проверяет что `extract_md_section` first-match-wins.

**Почему это отдельный спек, а не часть R3:**
- Применимо ко всем section-scoped smoke assertion'ам (будущие R4, R5, R6…), не только к R3.
- Требует добавления инфраструктуры (`tests/smoke-helpers.sh` + `tests/fixtures/`) — это самостоятельное архитектурное решение на уровне smoke framework, не docs-only feature как R3.
- R3 уже сделан AUDIT_PASSED с явным acknowledgement этого gap'а; отдельный спек #24 закрывает gap для всей плагин-smoke поверхности.

**Критерий приёмки (draft):**
- `tests/smoke-helpers.sh` существует, имеет именованные функции для R3-scoped checks (и любых других scoped checks, которые уже есть в smoke.sh).
- `tests/fixtures/r3-wrong-section.md` + при необходимости fixtures для (e)(f)(g) wrong-section cases.
- R3 Step 1 `passing_test_cmd` перепианен: убраны canonical-line-freeze greps + `"$R3"` co-occurrence; вместо них — behavioral assertion'ы через fixture (ожидаемый non-match при правильной импл, ожидаемый match при whole-file-grep buggy impl). §3.2.1 Usage snippet обновлён под function-based invocation.
- Все label'ы (a)-(g) остаются frozen и продолжают проверяться на реальном contents — behavioral fixtures это дополнительный слой, не замена.
- iter-8 cross-audit R3 (retroactive) не должен поднять X19 re-open — inert-text spoof должен явно fail'ить на fixture.

**Severity / priority:** P2 medium-effort, medium-impact. Не блокер — R3 задеплоится и без #24, но как только #24 приземлится, имеет смысл сделать follow-up spec'ом "R3 Step 1 proof migration to #24 harness".

**Источник:** cross-audit iter-7 convergence (2026-04-18) по спеку `2026-04-17-test-strength-r3.md`. Детальный ход дискуссии и Option A vs Option B trade-off — в Log спека, iter-7 entry. Finding X19 HIGH → DEFERRED (этот backlog item).

### ~~25. Per-step `recommended_agent` field в spec-template + `/feature new` pre-tag prompt~~ ✅ DONE (2026-04-20)
Спек #18 (agent-routing) ввёл orchestrator-level routing matrix + canonical Log format `last_agent=<...>; rationale=<T-X#>`. Это закрывает decision-point "which agent implements this spec" в момент handoff. Ортогональный вопрос — **let the spec author pre-tag each checklist step** с рекомендуемым агентом, чтобы:
- спек-author (обычно человек или Claude в `/feature new`) мог сказать "Step 1 — pattern-following, Middle подойдёт; Step 2 — новая абстракция, нужен Senior"
- orchestrator в `continue` mode читал pre-tag и предлагал его как default для конкретного шага (сейчас default берётся только из последнего `last_agent=` в Log, что применимо на уровне спека в целом, не per-step)
- cross-auditor при review спека видел explicit routing intent и мог валидировать его против matrix triggers

**Задача:**
- `skills/feature/references/spec-template.md` — добавить опциональный суффикс `@<agent>` к checklist-item: `- [ ] Step N: <goal> @senior`. Grammar: `@senior` | `@middle` | `@codex` | (omit → орхестратор выбирает по matrix triggers на момент handoff).
- `skills/feature/SKILL.md` §"New → Step 2 write spec" — add guidance: "For each step, tag the recommended agent inline (`@senior`/`@middle`/`@codex`) if the step's nature clearly matches a routing trigger. Leave untagged if ambiguous — orchestrator will pick at handoff time."
- `skills/feature/SKILL.md` §"Implement → Agent selection" — when iterating over checklist steps, read `@<agent>` tag if present; if tag exists AND matches a valid trigger for that agent, use it as the default pre-fill in the agent-picker banner. Log rationale as `T-<tagged-agent-letter>0; notes=pre-tagged by spec author`.
- `agents/cross-auditor.md` spec-mode — add review check: "If steps are pre-tagged with `@<agent>`, verify the tag matches an anti-trigger of no other agent (i.e. the pre-tag is internally consistent with the routing matrix)."
- `tests/smoke.sh` — parse the spec-template to confirm the `@<agent>` grammar section exists; parse one test spec to confirm the orchestrator picks up the tag.

**Почему в бэклоге, а не сливать в #18:**
- #18 formalizes the orchestrator-level pick (one pick per spec handoff, logged once). Per-step pre-tagging is a spec-author-level concern that touches spec-template, SKILL.md spec-writing guidance, cross-auditor review prompt, and orchestrator's `continue`-mode pick flow. Four files, different users (spec author vs orchestrator vs auditor). Different feature.
- #18 ships with the matrix + `rationale=T-X#` contract; #25 layers pre-tag on top *once* the matrix is landed and stable.
- Pre-tag is opt-in — untagged checklist items remain valid under #18's orchestrator-level pick, so #25 is purely additive.

**Critère d'acceptance (draft):**
- `spec-template.md` grammar section covers `@senior|@middle|@codex` suffix and explicitly states untagged is valid.
- `/feature new` SKILL prompts for per-step agent tag but accepts "skip" (don't force).
- `/feature continue` reads the tag for the step it's resuming on and pre-fills the agent-picker.
- Cross-auditor spec-mode asserts pre-tag consistency with matrix.
- Smoke assertion: spec-template has the pre-tag grammar sentence (byte-exact via extract_md_section).

**Источник:** cross-audit iter-1 finding X7 (2026-04-18) on spec `2026-04-18-agent-routing.md` — RR2 originally cited BACKLOG #18's own orchestrator-level rationale-logging gate as the follow-up, but that's the same concern #18 already solves. Per-step pre-tag is a distinct concern, deferred here.

### ~~29. Consolidate git-conventions references~~ ✅ DONE (2026-04-20) — PR #26

Git-конвенции (feature branch naming `<type>/YYYY-MM-DD-<slug>`, base branch detection `master|main` с `prefer master`, small logical commits, no `Co-authored-by`, no pushing) описаны в трёх местах:
- `skills/feature/references/developer-workflow.md:108-148` — каноничная версия с pre-commit branch assertion (MANDATORY) и post-merge bug flow
- `skills/feature/SKILL.md:400-406` — короткая версия в §"Git conventions"
- `docs/AI_Dev_Team_Overview.md:115-121` — overview-level

Пока совпадают, но SKILL.md и Overview.md не упоминают pre-commit branch assertion (load-bearing rule в developer-workflow). Если правило ещё эволюционирует — поедут дальше.

**Решение:**
- `developer-workflow.md` остаётся каноничным (он уже "shared reference" для developer-агентов).
- `feature/SKILL.md:400-406` — сократить до ссылки на developer-workflow.md §"Git Workflow", оставив только feature-skill-специфичные элементы (4-option hand-off menu, baseline test interaction) — эти вещи не git-конвенции как таковые.
- `docs/AI_Dev_Team_Overview.md:115-121` — сократить до 3-строчного summary + ссылки на developer-workflow.md.
- `tests/smoke.sh` assertion: канонический текст pre-commit branch assertion встречается в плагине ровно 1 раз (в developer-workflow.md).

**No-regression constraint:** ни одно правило не убирается и не ослабляется; только переносится источник истины. Пользовательские flows (baseline test, hand-off) документируются там же, где сейчас — меняется только секция "Git conventions" внутри них.

**Почему P2:** меньший масштаб чем #28 (Phase 0), но та же архитектурная логика — один источник истины.

**Источник:** drift-and-dedupe audit 2026-04-20.

### ~~30. Dedupe trigger map~~ ✅ DONE (2026-04-20) — PR #27

Ambient trigger-map ("user says X → invoke skill Y") существует в 4 местах, с разной полнотой:
- `hooks/session-start` (инжектируется как SessionStart context) — **полная** версия: английские + русские варианты, scope-addition, verify, checklist triggers
- `docs/claude-md-snippet.md:33-45` — почти полная, RU variants, но форматирование отличается
- `README.md:85-90` "Ambient workflow" — **урезанная**, только 4 строки, нет RU, нет scope-addition/verify/checklist
- `CLAUDE.md` (в project CLAUDE.md consumer-проектов) — пользователь вручную копирует из snippet

README уже отстал. Пользователь, читающий только README, не знает про verify/checklist triggers.

**Решение:**
- `hooks/session-start` остаётся каноничным (он действительно инжектируется и влияет на поведение Claude в runtime).
- `docs/claude-md-snippet.md` — оставить как snippet для копирования в project CLAUDE.md, но пометить "current as of YYYY-MM-DD — source of truth is `hooks/session-start`".
- `README.md:85-90` — заменить полную таблицу на короткий список (~3 строки) + ссылку на `docs/claude-md-snippet.md` как "actionable version" и `hooks/session-start` как "authoritative version".
- `tests/smoke.sh` assertion: trigger-map key phrases (e.g. `"/feature new"`, `"/cross-audit"`, `"/investigate"`) встречаются в canonical source (session-start hook); snippet и README не расходятся с ним по набору триггеров.

**No-regression constraint:** runtime поведение hook'а не меняется (он и есть источник истины); меняется только презентация в docs.

**Почему P2:** пользовательский UX drift (README неполный) — небольшой, но cumulative.

**Источник:** drift-and-dedupe audit 2026-04-20.

### ~~31. Remove decorative "Adaptation by Project Type" from cross-audit SKILL~~ ✅ DONE (2026-04-20) — PR #28

`skills/cross-audit/SKILL.md:305-319` перечисляет focus areas по project type (smart contracts, backend, frontend, data pipelines) как декоративный раздел. Каноничный полный список — в `agents/cross-auditor.md:43-83` `## Mode Focus Areas`. SKILL-версия никуда не передаётся при диспатче — агент сам знает свои focus areas. Это чистое украшение, которое становится источником дрейфа (уже сейчас SKILL-версия короче и менее детальна).

**Решение:**
- Удалить блок `## Adaptation by Project Type` из `skills/cross-audit/SKILL.md`.
- Если хочется, чтобы пользователь SKILL-файла видел какие areas существуют — заменить на 2-строчный pointer: "Focus areas depend on detected project_type — see `agents/cross-auditor.md` §Mode Focus Areas for the canonical list."

**No-regression constraint:** блок не влияет на runtime dispatch (cross-auditor получает `project_type` и сам применяет focus areas). Удаление — чистый docs cleanup.

**Почему P2:** мелкий очевидный win, но даёт правильный сигнал читателям ("SKILL — оркестрация, agent — contract").

**Источник:** drift-and-dedupe audit 2026-04-20.

---

## P3: Low impact / nice-to-have

### ~~10. i18n для prompts~~ ✅ OBSOLETE (2026-04-17)
Hard-coded русские строки в skill prompts (`"Обнаружен KB: ... Использовать его?"`) — плохо для публичного marketplace. Вынести в `skills/<skill>/references/prompts.<lang>.md` или переключать по `$LANG`.

**Итог:** `grep -r '[А-Яа-я]' skills/ agents/ hooks/` возвращает пусто — все user-facing prompts уже в английском после прошлых рефакторов. Locale-switcher для плагина без не-английского контента = speculative infrastructure. Закрыто без кода; если когда-нибудь появятся локализованные строки — вернуться.

### ~~11. MEDIUM severity opt-in для `/cross-audit`~~ ✅ DONE (2026-04-17)
Сейчас cross-auditor жёстко собирает только CRITICAL/HIGH. Для мелких фич, где серьёзных багов нет, MEDIUM иногда полезен.

**Решение:** флаг `/cross-audit src/ --severity medium+`.

### ~~12. `/feature discard` как явная команда~~ ✅ DONE (2026-04-17)
Сейчас discard — только option 4 в handoff. Если решение "выбросить" принято до завершения implementation — нужно вручную удалять ветку + ставить статус.

### ~~13. Config-driven Codex model~~ ✅ DONE (2026-04-17)
README заставляет редактировать `~/.codex/config.toml`. Для plugin-пользователя было бы удобно переопределить через `.ai-dev-team.yml` (после базовой версии из текущего спека `plugin-hardening`):
```yaml
codex:
  model: gpt-5.4
  reasoning_effort: xhigh
```

### ~~14. Auto-generate `.ai-dev-team.yml` после первой KB discovery~~ ✅ DONE (2026-04-17)
После того, как пользователь подтвердил KB path через legacy-пути (memory / sibling heuristic), предложить сохранить в `.ai-dev-team.yml` для будущих сессий. Требует базовой поддержки чтения файла (текущий спек `plugin-hardening`).

### ~~32. Clarify `/investigate` vs `/research` in trigger map~~ ✅ DONE (2026-04-20) — PR #29

CLAUDE.md trigger map маршрутизирует "compare these options", "which is better", "tradeoffs between" → `/investigate`. При этом `/research new` имеет subtype `competitive-analysis` ("market / vendor / protocol comparison") — пользователь, буквально говорящий "competitive analysis X vs Y", может попасть в любой из двух flows.

Разграничение реальное: `/investigate` — **состязательный debate** двух моделей с convergence report; `/research new` — **свободные заметки**, длящиеся сессиями, без audit'ов. Но это различие нигде явно для пользователя не сформулировано.

**Решение:**
- В `hooks/session-start` и `docs/claude-md-snippet.md` trigger map — добавить 1-строчное уточнение: `"compare / which is better / tradeoffs → /investigate (adversarial debate, single-session); /research new competitive-analysis only when user wants free-form notes over multiple sessions."`
- В `skills/research/SKILL.md` → §subtype descriptions → для `competitive-analysis` добавить строку: "For decision-making comparisons with a recommendation at the end, use `/investigate` instead — it runs adversarial Claude+Codex debate and produces a convergence report."

**No-regression constraint:** обе skill'а остаются доступными; меняется только руководство по выбору. Тесты — grep smoke-assertion что новая строка-разграничение присутствует.

**Почему P3:** реальная боль редкая (пользователь обычно сам выбирает по контексту), но дешёво закрывается.

**Источник:** drift-and-dedupe audit 2026-04-20.

### ~~33. Document why `@codex-fast` is not a valid pre-tag~~ ✅ DONE (2026-04-20) — PR #29

`skills/feature/references/spec-template.md:77` и related validation в `skills/feature/SKILL.md` разрешают только `@codex`, `@senior`, `@middle` как per-step pre-tags; `@codex-fast` (или `@fast`) явно помечается как malformed с hard-stop. Codex Fast при этом — реальный отдельный dispatch path (option 1b в agent-selection). Причина запрета (Fast — выбор оркестратора, не свойство шага; скорость/стоимость перевешивает глубину только когда user явно выбрал на runtime) нигде не задокументирована.

**Решение:**
- Добавить 1–2 строки в `spec-template.md` секция `## 5. Implementation Checklist` под описание pre-tags: "Note: `@codex-fast` intentionally not supported — Fast is an orchestrator-time choice driven by user config (`codex.model_fast`), not a step property. A step that would benefit from Fast is still tagged `@codex` and routed to Fast only when the user selects option 1b at handoff."
- Та же заметка в `skills/feature/references/agent-routing.md` §"Codex Fast (opt-in)" — одной строкой.

**No-regression constraint:** валидация pre-tags не меняется; добавляется только reasoning-note.

**Почему P3:** предотвращает одну конкретную confusion-точку для spec authors.

**Источник:** drift-and-dedupe audit 2026-04-20.

### ~~34. Normalize `branch:` casing across docs~~ ✅ DONE (2026-04-20) — PR #29

Канонический YAML frontmatter key — `branch:` (lowercase, следует общей YAML-конвенции). Встречается в `spec-template.md`, `developer-workflow.md`, `spec-compliance-checker.md` — все lowercase.
В `skills/feature/SKILL.md:401` и `README.md:326` в прозе написано `Branch:` (capital B) — "as specified in spec `Branch:` field". Это стилистическая отсылка, но читатель может подумать, что в frontmatter тоже capital B.

**Решение:**
- Замена `Branch:` → `branch:` в prose-отсылках в `feature/SKILL.md` и `README.md`. Точечный edit.
- Smoke-assertion: `rg "['\"\`]Branch:" skills/ docs/ README.md` = пусто (только lowercase в prose).

**No-regression constraint:** семантически идентично; только презентация.

**Почему P3:** мелочь, 10-минутная правка.

**Источник:** drift-and-dedupe audit 2026-04-20.

### 36. Deploy prerequisites prompt — differentiate auto-deployed from genuinely-manual steps

Текущий prompt в `feature/SKILL.md` Prerequisites step (§New → Step 2) спрашивает open-ended: `"Any deploy prerequisites? One-off ops steps that must run after the merge before the feature works (migrations, worker restarts, cache reset). One per line. Empty input = none."`

В кандидатах, которые подсказывает skill, регулярно всплывают вещи, которые в стандартном backend-деплое делаются **автоматически** через CI/Ansible/k8s:
- перезапуск сервисов (gunicorn, celery workers, celery beat) — делается каждый deploy и так
- sync env vars — заливается через ansible/secret-manager
- reload config — side-effect рестарта

Юзер вынужден каждый раз отсеивать этот шум. Это создаёт впечатление "деплой совсем ручной", хотя реальных manual steps мало — миграции БД, data backfills, feature-flag flips, внешние сервисы, runtime-зависимые действия.

**Задача:** переработать prompt из вопроса "что добавить?" в infoblock + узкий вопрос о **действительно** manual steps. Варианты:

1. **Infoblock + narrow prompt:**
   ```
   Typical backend deploy auto-restarts services + syncs env vars via CI/Ansible.
   If this feature requires manual ops steps OUTSIDE that auto-flow (DB migration,
   cache invalidation, data backfill, feature flag flip, external service config,
   one-time script run), list them. One per line. Empty = none.
   ```
   Плюс — LLM-кандидаты, которые skill подсказывает, исключают auto-deployed вещи.

2. **Config-driven suppression:** section в `.ai-dev-team.yml`:
   ```yaml
   deploy:
     auto_restarts: true        # services always restart on deploy
     auto_env_sync: true        # env vars synced via CI/secret manager
     migration_tool: alembic    # informational; hints when migrations needed
   ```
   Если `auto_restarts: true`, skill даже не предлагает "restart X" как кандидата. Если `auto_env_sync: true`, env-var prompt подавляется полностью, заменяется info-line "New env vars <list> will be synced via your deploy flow — no action needed here."

3. **Feature-level detection:** skill анализирует diff — если появились новые env vars в code/settings, выводит их как info-block ("Feature references env vars X/Y — they'll be synced via deploy"), НЕ как obligations.

**Почему P3:** UX polish, не блокер; текущее поведение корректно (empty input работает). Но ощутимо шумит в каждом `/feature new`.

**Open questions:**
- Как skill определяет backend-type проекта (наличие Dockerfile? procfile? specific frameworks)? Дефолт — spec-author vs project-config?
- Kubernetes / serverless flow (AWS Lambda, Vercel) тоже auto-deploy env — config должен покрывать все common cases.
- Стоит ли §6.2 `deploy_prerequisites` переименовать в `manual_ops_steps` чтобы семантика имени отражала узкий scope?

**Источник:** пользовательский фидбек 2026-04-20 по текущему спеку bribe-payout-reconcile — prompt предложил "перезапустить Celery workers и beat" и "добавить env vars в prod config" как кандидатов, пользователь отметил "выглядит херня — deploy автоматический, эти шаги идут без обсуждения".

### 37. Feature skill: proactively read AGENTS.md / CLAUDE.md / repo conventions; never "developer's call" for placement decisions

Реальный кейс (2026-04-20, aquarius/soroban-amm session `22bcc6bc...`, spec X3 `plane.rs` findings fix): в target repo `AGENTS.md` явно указывает: "тесты в `src/test.rs`, хелперы в `testutils.rs`". Spec же был написан с формулой "developer's call" (где положить тесты — решает developer). Codex развернул inline `#[cfg(test)] mod` внутрь production-файла `plane.rs` — формально допустимо (R5 позволяет inline, если repo-convention такая), но фактически противоречит явной конвенции в AGENTS.md, которую spec не прочитал.

User отследил, agent признал ("я сам это разрешил в спеке... должен был директивно указать `test.rs`"). PR #159 в soroban-amm уже переносил inline → sibling tests.rs (причина вынесения R5 в `code-quality-rules.md`). R5 при этом **описывает** правило mirror-convention, но **не** enforce'ит его на этапе написания спека.

**Gap:** R5 discovery-команда (`grep -R "#[cfg(test)]" src/`) срабатывает на **implementation** этапе (developer перед написанием первого теста). К этому моменту spec уже утверждён. Если spec сам сказал "developer's call" — developer может сделать не тот выбор, и compliance-checker не отловит (R5 говорит mirror repo convention, inline в plane.rs формально тоже repo convention — repo-wide majority не очевиден).

Правильный уровень — **Research + Spec phase**. Feature skill Step 1 Research (читаем KB + codebase) должен проактивно проверить в target repo:
- `AGENTS.md` (если есть — это agent-directed conventions: test placement, branch naming, linting, commit style)
- `CLAUDE.md` (тот же класс информации, aimed at Claude)
- `README.md` → "Development" / "Contributing" секции
- `.github/CONTRIBUTING.md`

Если любой из них содержит **директивные** правила про test placement, module layout, branch naming, commit format — spec §2 Current State должен их дословно процитировать, а §5 Implementation Checklist — запрещать `"developer's call"` / `"at developer's discretion"` / любые ambiguous фразы для решений, уже зафиксированных в конвенциях.

**Задача:**
1. `skills/feature/SKILL.md` §New/Step 1 Research — добавить explicit bullet: "read AGENTS.md, CLAUDE.md, .github/CONTRIBUTING.md in target repo if they exist; lift any directive placement/naming/layout rules verbatim into spec §2.X Current State → 'Repo conventions' subsection."
2. `skills/feature/SKILL.md` §New/Step 2 write spec — добавить rule: "if §2 Current State lists a repo convention relevant to a checklist step (test placement, file layout, branch naming, commit style), §5 Implementation Checklist step MUST specify the exact placement/value — never 'developer's call' / 'at agent discretion'."
3. `agents/cross-auditor.md` spec-mode focus areas — добавить: "flag HIGH if §5 checklist contains placement/naming ambiguity (`at developer's discretion`, `developer's call`, `as you see fit` for files/modules/branches) AND the target repo has an `AGENTS.md`/`CLAUDE.md`/contributing doc with directive guidance on that topic that §2 did not quote."
4. Возможно новое правило R7 в `code-quality-rules.md` — "Repo-convention discovery precedes spec writing" с references к AGENTS.md/CLAUDE.md files. Альтернатива — расширить R5 "How to apply" #1 чтобы включить reading AGENTS.md before the grep-heuristic.
5. Negative fixture для smoke: spec с "developer's call" в §5 для test placement + fake `AGENTS.md` в fake-repo fixture говорящий противоречиво — cross-auditor-spec-mode helper должен reject.

**No-regression constraint:**
- Текущие spec'и которые не цитируют AGENTS.md — остаются валидны (grandfathered; только новые specs после landing'а нового правила должны соответствовать).
- R5 не меняется в своём core rule (mirror convention) — только discovery expands.

**Источник:** soroban-amm session 22bcc6bc Apr 20, user feedback ("Codex засунул их в `#[cfg(test)] mod` внутри `plane.rs`"); related prior incident — PR #159 soroban-amm moving inline→tests.rs, which triggered R5 in first place.

**Почему P2:** реальный недавний кейс (agent placed wrong), user caught manually. R5 closes part of the gap — R7 (or §New proactive discovery) closes the rest. Medium impact — agents working on repos without AGENTS.md получают benefit only through R5 mirror-grep, что уже есть.

### ~~35. Delete obsolete "`audit` replaced by cross-audit" migration note~~ ✅ DONE (2026-04-20) — PR #29

`README.md:262` содержит строку "Migration note: `audit` replaced by cross-audit." На момент 1.2.0 это легаси — никакой `audit` skill в плагине не существует уже давно, все invocations используют `/cross-audit`. Строка ничего не объясняет читателю 2026 года — просто историческое напоминание.

**Решение:**
- Удалить строку из README.md.
- При необходимости — сохранить один-коммит audit trail в git history; архивация в `docs/` не требуется.

**No-regression constraint:** нулевой функциональный эффект.

**Почему P3:** обрезание мёртвого текста.

**Источник:** drift-and-dedupe audit 2026-04-20.

### 38. G probe frozen-replay corpus + `failure_kind` enum sketch (for post-Foundation follow-up spec)

Foundation spec `design/2026-04-21-cross-audit-probes-foundation.md` §3.5 пинит G probe fingerprint `test_file + test_id/step_id + failure_kind`, но явно defer'ит enumeration of `failure_kind` values to the G-probe-specific follow-up spec. Вot enumeration + evidence pool, собранный из двух реальных сессий — готов к подбору будущим spec-автором без повторного сбора данных.

**Предлагаемый `failure_kind` enum** (8 значений, все с detection-rule sketch'ами):

| failure_kind | Detection rule sketch |
|---|---|
| `missing_red_proof` | Step's planned `failing_test_cmd` set, но `red_capture` отсутствует или не matches `expected_failure_pattern`. Уже частично пинит spec-template DONE rule — G формализует как blocking probe. |
| `compile_time_equivalent` | Два теста отличаются только argument values которые semantically identical (`limit=None` vs `limit=-1` когда код treats both as "no limit"). Detection: AST normalize + dedupe. |
| `fragmentation_covered_by_holistic` | Cluster of per-aspect tests + holistic/parity test, который covers те же aspects. Detection: name-cluster heuristic + coverage overlap. |
| `prose_duplicate` | Два теста с разными именами имеют semantically identical assertion paths (один implies другого). Detection: assertion-graph dominance. |
| `minimum_assertion_happy_path` | Test function has single assertion, trivially-true assertion, или только "no exception raised". Detection: AST count of load-bearing asserts. |
| `symmetric_pair_redundant` | ON/OFF или enabled/disabled pair где negative case adds zero signal. Detection: flag-parameterized pair with trivial inverse. |
| `format_output_parametrize_target` | N tests отличающихся только output format (text/json/csv) и не parametrized. Detection: body hash + output-format parameter detection. |
| `structural_only` | Test asserts "этот сценарий попал в bucket X" без verification конкретных значений/counter'ов в результате. Detection: absence of value-assertion on payload. |

**Evidence pool** для G's validation-gate (Foundation §3.6 корпус требует: 1 positive + 2 eligible-clean negatives):

*Positive case A — x3-plane-tick-search-l2* (session 2026-04-20): 6 тестов (2 unconstrained + 2 inclusive_limit + 2 exclusive_limit). Audit found 2 exclusive_limit tests had zero red-proof (returned None without L2); inclusive_limit tests compile-time equivalent to unconstrained (`limit=-1` == "no limit"). Classes: `missing_red_proof`, `compile_time_equivalent`. Redundancy 4/6.

*Positive case B — aqua-bribes PR #3* (session 2026-04-20/21 `d4692ea8-aca5-4679-85c0-65a54e782a73`): 54 теста добавлены, честный self-review post-hoc выявил ~40 load-bearing, ~8-10 weak/redundant (~250 строк). Classes покрытые этим одним PR: `fragmentation_covered_by_holistic` (6 per-aspect eligibility тестов покрыты holistic `_parity_with_task_pay_rewards`), `prose_duplicate` (`_does_not_raise` vs `_logs_sentry_and_persists` — persist implies no exception), `minimum_assertion_happy_path` (`_threshold_ok_when_all_paid`), `symmetric_pair_redundant` (sentry enabled/disabled pair), `format_output_parametrize_target` (3 теста на text/json/csv), `structural_only` (reconcile bucket classification без value verification). Redundancy 8-10/54 ≈ 15-19%.

Две сессии покрывают 6-7 из 8 предложенных `failure_kind` значений.

**Eligible-clean negatives** (G probe must NOT fire): соберутся при написании G spec'а — нужны ≥2 historical cases где тест genuinely load-bearing AND looks structurally similar to a weak candidate. Кандидаты: tests в ai-dev-team smoke suite (tests/smoke.sh) — disciplined и load-bearing несмотря на structural simplicity.

**Design constraint — exploratory vs permanent**: G probe должен fire'ить ТОЛЬКО на tests присутствующие в committed diff (не на exploratory/debugging tests написанные mid-session и pruned до commit). Operationally: probe читает `git diff <base>...HEAD`, не working-tree; tests с `_exploratory_` prefix ignored (convention signal); G probe spec должен явно call out этот boundary. Memory pointer: `feedback_new_tests_must_be_strong_and_non_redundant.md` reinforced 2026-04-21 с этим rule.

**Foundation compatibility**: G probe plug'ится в Foundation schema через `source: probe:G` в findings; fingerprint per §3.5; receipt JSON per §3.3 schema (trigger_input_hash = hash of test-diff slice + ASTs; probe_output_hash = hash of canonical finding envelope); mode kill-switch defaults `off` per §3.4; graduation via §3.6 validation-gate.

**No-regression constraint:** G probe ships в shadow mode; zero behavioral change на существующих audit'ах до explicit opt-in.

**Почему P2 (post-Foundation):** реальный incident evidence из 2 сессий уже собран; блокирует G probe spec только по capacity, не по data. Picked up when Foundation VERIFIED и user решит open G probe follow-up spec.

**Источник:** evidence из sessions 2026-04-20 (x3-plane-tick-search-l2) + 2026-04-20/21 (aqua-bribes PR #3); принципы test-strength в memory `feedback_new_tests_must_be_strong_and_non_redundant.md`.

### 39. Format-churn probe (WM-N candidate — PR-level format vs semantic ratio)

Реальный incident 2026-04-21, aqua-bribes PR #3: 10-строчный semantic change запустил formatter по всему файлу → ~10k строк diff'а. Semantic review невозможен. Даже при соблюдении "formatter only on changed lines" правила, cascade может быть такой, что format dominates semantic в PR.

Two-rule principle captured in memory `feedback_formatters_changed_lines_only.md`:
1. **File-level discipline**: formatters только на changed lines.
2. **PR-level balance**: ratio format:semantic должен оставаться reviewable (rough starting point ~2:1).

**Design sketch:** probe fires на PR audit time и flags когда ratio format-only lines к semantic lines в diff превышает threshold. Detection: AST-diff vs text-diff delta — lines visible в text-diff но absent из AST-diff are format-only.

**Два deployment mechanism'а** (complementary, не alternatives):
- Pre-commit / session-start hook в плагине — warn'ит author'а на build time, до открытия PR
- Full Foundation probe — emits findings на audit time (ships в shadow first per validation-gate)

**Evidence pool:**
- Positive: aqua-bribes PR #3 initial push до separate `refactor(format):` split. ~10k-line diff for 10 semantic lines.
- Eligible-clean negative candidates: genuine `refactor(format):` PRs где format-churn — заявленный intent (file-wide formatter adoption). Probe MUST NOT fire когда PR title/commit declares format intent.

**Foundation compatibility:** plug'ится через `source: probe:N`; trigger определяется commit-message convention + AST-diff heuristic.

**No-regression constraint:** probe ships в shadow mode; zero behavioral change до opt-in.

**Почему P2:** incident реальный, rule уже в memory. Не P1 потому что не блокирует Foundation или E/F/G specs — это orthogonal probe категории.

**Источник:** aqua-bribes PR #3 incident 2026-04-21; principle memory `feedback_formatters_changed_lines_only.md`. Bullet в convergence research note `research/cross-audit-strengthening/industry-scan-and-design.md` §9 Deferred list (WM-N candidate).

### 40. Librarian: add `backlog` document type + enforce creation-through-librarian rule

Gap discovered 2026-04-21 session: `BACKLOG.md` in `repos/<project>/` — plain-markdown living backlog с numbered items (1..N) — существует в нескольких проектах (`ai-dev-team/`, `evm-arbiter/`, `stellar-arbiter/`, `blend-liquidator/`) но отсутствует в `agents/librarian.md` Document Paths таблице. Librarian знает только `design/`, `security/`, `research/`, `postmortems/`.

В той же сессии агент создал параллельный `research/plugin-improvement-backlog.md` research note потому что librarian schema не знает о BACKLOG.md типе, и feature skill Phase 0 KB discovery scan'ит только `design/` (спеки), не поднимая BACKLOG-level documents. Duplicate был замечен user'ом и устранён (research note merged into BACKLOG.md, это items #38/#39).

**Задача:**
1. `agents/librarian.md` Document Paths table — добавить row: `| Backlog | <kb_root>/repos/<project>/BACKLOG.md |`.
2. `agents/librarian.md` Document Formats — добавить `### Backlog frontmatter` schema matching existing BACKLOG.md frontmatter (`title / project / type: backlog / created / tags`).
3. `agents/librarian.md` Responsibilities — добавить sentence про maintaining backlog numbering (next-id = max existing + 1), preserving historical items with `✅ DONE (date) — PR #N` strikethrough annotation (existing convention).
4. `agents/librarian.md` Rules — переформулировать "The only agent that creates new KB documents" с explicit mention что это включает editing BACKLOG.md items (добавление новых items должно идти через librarian чтобы обеспечить consistent numbering + proper priority section placement).
5. `skills/feature/SKILL.md`, `skills/research/SKILL.md`, `skills/investigate/SKILL.md` — на ideation-flow (когда user упоминает "plugin improvement" / "idea for future" / "бэклог" / "на будущее"), suggest adding to BACKLOG.md via librarian; не создавать parallel structures.
6. `skills/cross-audit/SKILL.md` — на audit findings которые suggest plugin-improvement rather than current-feature fix, опционально suggest spawning librarian to record as BACKLOG item.

**No-regression constraint:** existing BACKLOG.md items остаются как есть; numbering continues from current highest; feature skill flow не меняется для normal spec creation.

**Почему P2:** реальный миссы случались (session 2026-04-21 duplicated backlog); cheap fix (librarian doc update + skill pointer updates). Не P1 потому что BACKLOG.md continues to work without these fixes — просто выше friction для ideation capture.

**Источник:** duplicate observed 2026-04-21 session when adding items #38/#39.

### 41. Feature/research skill: scan BACKLOG.md in Phase 0 + optional "picked-up-by-spec" tracking

Complementary к #40 — ideation-side. Когда user запускает `/feature new <description>`, feature skill Phase 1 Research читает KB specs в `design/` но не BACKLOG.md. Если существует backlog item, схожий с new feature'ом, skill должен surface'ить это pre-draft чтобы:
- user мог сказать "да, это backlog #38, picked up", и spec получает `picked_up_from: BACKLOG.md#38` frontmatter hint
- duplicate prevention — если backlog item уже picked up by другим спеком, skill warn'ит

**Задача:**
1. `skills/feature/SKILL.md` Phase 1 Step 1 Research — добавить bullet: "Read `<kb>/repos/<project>/BACKLOG.md` (if exists); grep for items related to the feature description; если есть match, surface to user for confirmation."
2. `skills/feature/SKILL.md` — new optional frontmatter field `picked_up_from: BACKLOG.md#<N>` (single or list) для traceability.
3. Librarian — при create spec'а с `picked_up_from:` field'ом, добавляет `✅ PICKED UP BY <spec-path> YYYY-MM-DD` annotation рядом с backlog item.
4. `/feature status` — для specs с `picked_up_from:`, render column "From backlog" с item number и title.

**No-regression constraint:** backlog items без picked-up annotations продолжают работать; existing specs без `picked_up_from:` — grandfathered.

**Почему P3:** UX polish, не блокер. Ideation discovery уже работает через Obsidian search; этот задача — automation + provenance tracking.

**Источник:** complementary к #40.

### 42. Plugin coexistence with other Claude plugins + conditional activation

**Context (team rollout):** Plugin готовится к передаче команде. Team members имеют корпоративный Claude + Codex-as-MCP, но у некоторых уже установлены другие Claude плагины (например `obra/superpowers`). Сейчас `hooks/session-start` инжектит 68 строк markdown в **каждую** Claude сессию независимо от релевантности — три проблемы:

(a) **Irrelevant token cost.** В orthogonal проектах (не ai-dev-team) inject тратит tokens впустую + вносит нестыковки (trigger map про `/feature new` / `/cross-audit` неприменим, но модель начинает проверять "а не надо ли оформить спек").

(b) **Coexistence conflict.** Если user'у также установлен superpowers (117 lines inject) — суммарный overhead 185+ строк с частичным overlap правил ("use skills when applicable" велят оба плагина).

(c) **Global scope of behavior rules.** Наше правило "drive to completion without re-asking" сейчас действует глобально, но должно применяться только внутри active `/feature` / `/cross-audit` session; в других контекстах override'ит reasonable defaults хоста.

**Задача (три взаимно-поддерживающих изменения, один спек):**

1. **Conditional activation** — hook проверяет сигналы ai-dev-team-проекта перед инъектом:
   - `.ai-dev-team.yml` / `.ai-dev-team.local.yml` в target repo, ИЛИ
   - `reference_kb_<project>.md` в Claude memory, ИЛИ
   - `CLAUDE.md` в target repo упоминает `ai-dev-team` / `/feature` / `/cross-audit`.
   
   Ни один сигнал — emit `{}`, inject 0 tokens. В orthogonal проектах плагин dormant.

2. **Thin session-prompt + lazy skill bodies** (superpowers-style refactor):
   - Inject сжимается с ~68 до ~15-20 строк: только trigger map (русские и английские фразы — deterministic intent recognition, наш killer feature) + компактная meta-отсылка.
   - В skill bodies (lazy, loading при invoke) переносятся: session-start KB scan → `/feature`; confirmation cadence → каждый active-flow skill; workflow phases / key facts → `/feature` + `/cross-audit`; audit-findings handling → `/cross-audit`.
   - Тело inject выносится в `hooks/session-prompt.md` (sibling), hook = thin bash (cat + JSON-escape + emit). Redактирование markdown без bash `'\''` escaping noise.

3. **Scope-limited rules + priority declaration** (superpowers reference):
   - "Don't ask mid-flow" scope narrowed до "inside active `/feature` or `/cross-audit` session only"
   - Audit-findings handling scope: "when user references finding ID AND KB accessible"
   - Explicit priority order в inject: `user's CLAUDE.md > other plugins' rules > ai-dev-team rules > default`
   - Coexistence note: "complements other skill-system plugins' 'always use skills' with specific intent→skill mapping; doesn't duplicate or override"

**No-regression constraint:**
- Plugin продолжает работать 1:1 в существующих ai-dev-team-проектах
- `/feature`, `/cross-audit`, `/investigate` invoke-triggers сохраняются в thin inject
- KB-based behavior (IN_PROGRESS scan at /feature continue) сохраняется в skill body
- Существующие спеки + exec workdocs не мигрируются

**Validation-gate evidence:**
- Smoke: negative test — orthogonal проект без сигналов → hook emit `{}` (new fixture), positive test — с `.ai-dev-team.yml` → full inject (reuse existing)
- Integration: ai-dev-team проекты всё так же распознают "add X" / "нужно ещё Y" / "фича в проде" (existing trigger table assertions)
- Team-rollout: после рефактора проверить co-install с superpowers в sandbox session — no overlapping rule assertions, overall inject <~35 строк joint

**Почему P2 (не P1, не P3):**
- Real блокер для team rollout: без этого каждый member получит irrelevant inject в orthogonal проектах и overlapping rules при co-install с другими плагинами
- Не блокер single-user использования (автор уже работает OK)
- Не UX polish: конкретное measurable improvement (inject size -70%, scope of rules targeted, conflict handling explicit)

**Источник:** session 2026-04-21. Reference implementation — `obra/superpowers/hooks/session-start` + `skills/using-superpowers/SKILL.md` (thin meta + lazy skill bodies + priority declaration). Trigger для priority re-bump: пользователь передаёт плагин команде, coexistence стал блокирующим.

### 45. `/cross-audit` ref-to-ref scope (branch-vs-branch / tag-vs-tag) с auto-materialization

**Pain (real, observed 2026-04-23)**: пользователь попробовал `/cross-audit v2.0.2 vs v1.7.0` (на soroban-amm). Skill отклонил — current accepted scopes:
- path / subsystem (`liquidity_pool_concentrated/`)
- `pr <N>` для PR review
- путь к existing findings doc для re-audit
- `--diff` флаг — current branch vs base-branch

Tag-to-tag / branch-to-branch / arbitrary ref-to-ref диапазон отсутствует. Hack-обходом — `git checkout v2.0.2 && /cross-audit liquidity_pool_concentrated/` — теряется diff-context (что именно поменялось между двумя версиями), смешивается legacy + новые изменения; auditor смотрит на снимок, не на дельту.

**Use cases**:
1. **Pre-release audit** — "что изменилось между prod release и release candidate". `cross-audit v2.0.1..v2.0.2`.
2. **Long-running branch sync** — feature branch отстал от main на месяц; перед merge хочется audit'ить именно точечную дельту, не весь чек-аут.
3. **Retrospective release audit** — "что зашло в v1.7.0..v2.0.2"; в случае инцидента — позволяет узко сфокусироваться на интересующем диапазоне коммитов.
4. **Subsystem-by-subsystem split** — large diff (как 5664-record retroactive) → auditor stalls (600s watchdog, observed 2026-04-22). Ref-to-ref + path filter позволяет дробить scope: `cross-audit v2.0.2..main -- liquidity_pool_concentrated/`.

**Задача (sketch — конкретика на этапе spec)**:

1. Расширить `skills/cross-audit/SKILL.md` accepted scope формы:
   - `<refA>..<refB>` (two-dot range — `git diff refA refB`) — diff между двумя refs
   - `<refA>...<refB>` (three-dot range — `git diff refA...refB`) — diff от common ancestor (как у `/feature` `git diff <base>...HEAD`)
   - Optional path filter: `<refA>..<refB> -- <path>` (передаётся в `git diff`)
   - Refs могут быть branch / tag / commit SHA — всё что принимает git
2. Materialization strategy:
   - Default — audit on current checkout. Если refs не равны HEAD — warn + предложить материализовать.
   - `--materialize=worktree` опционально: создать temp worktree на refB (`git worktree add /tmp/cross-audit-<slug> <refB>`), audit в нём, cleanup на exit. Аналогично PR-mode pattern (cross-auditor уже умеет worktree per `agents/cross-auditor.md`).
   - `--materialize=branch <name>` — создать локальную branch на refB для interactive iteration (если auditor находит fix-кандидат, можно тут же commit'нуть, удобно для prep-work перед PR).
3. Cross-auditor `base_branch` параметр уже существует — расширить семантику: вместо implicit "main / master", принять любой ref, использовать в `git diff <base_branch>...HEAD` substituting accordingly.
4. Output naming — audit-slug должен включать ref-pair: `<refA>__<refB>-findings.md` (sanitize tag chars / slash → safe form).
5. Failure modes (handle explicitly):
   - One ref doesn't exist → fast-fail with clear message
   - refA == refB (empty diff) → "no changes between refs; nothing to audit" + exit success
   - Diverged refs (не linear) — выбрать `..` или `...` semantics; default `...` (common-ancestor) более интуитивно для PR-style review

**Subsystem-split mode** (related, может быть отдельным sub-spec): для больших diff'ов (>X файлов или >Y строк) — skill может сам предложить параллельный split по top-level dirs. Evidence: 600s watchdog stall на 10-file scope в Layer 1 dogfood (2026-04-22). Default для большого scope — split + parallel.

**Anti-goals**:
- Не делаем cross-repo diff (refA в одном репо, refB в другом) — out of scope для v1.
- Не строим UI для interactive ref-picking — CLI args only.
- Не делаем «automatic worktree» per default (риск засорить /tmp); материализация opt-in.

**Validation-gate evidence** (когда picked up):
- 1 positive: synthetic ref-pair с known diff → audit runs, findings = expected pattern.
- 1 negative: refA == refB → exit clean без audit.
- 1 ineligible: invalid ref (non-existent tag) → fast-fail with clear error.
- Live: audit `v1.5.0..v1.6.0` на самом ai-dev-team — рабочий self-test (probe E + F shipped в этом диапазоне).

**No-regression constraint**: existing scope forms (path / `pr <N>` / `--diff`) работают 1:1 без изменений.

**Почему P2**: реальный pain (попытка использования провалилась 2026-04-23), очевидный workflow gap. Не блокер для текущего L2 / L1-complement roadmap (audit coverage), но significantly расширяет применимость `/cross-audit` за пределы PR-flow и in-flight feature-flow. Subsystem-split — параллельно, частично решает 600s watchdog issue.

**Источник**: session 2026-04-23, попытка `/cross-audit v2.0.2 vs v1.7.0` на soroban-amm — skill отклонил, пользователь обходил через manual checkout + path-scoped audit.

### ~~44. Librarian effectiveness review — actual-vs-declared role~~ ✅ DONE (2026-04-26) — PR #51

**Resolution (Mode B)**: empirical audit over 2026-04-16..2026-04-25 (research note `<kb>/research/librarian-effectiveness-review/2026-04-25-actual-vs-declared-role.md`) found 0.54% delegation rate (1 spawn / 184 distinct KB-files in 20 sessions / 10 days), 100% frontmatter compliance on sampled specs, no functional violations. Mode A ruled out by data; user chose Mode B (narrow framing) over Mode C (delete) as the more conservative option. Shipped via PR #51:

- `agents/librarian.md` description + body reframed: 'Optional helper for KB layout discovery and MOC index maintenance. NOT a mandatory gateway.'
- `skills/research/SKILL.md` + `docs/AI_Dev_Team_Overview.md` cross-refs softened.
- 3 anti-drift smoke pins added (positive narrow-framing + negative anti-mandatory-claim + overview parity). Smoke 416 → 419.

Methodology validated for #46 generalisation: quantitative-grep (session JSONL) + qualitative-sample (KB compliance audit) + posture-decision (A/B/C matrix) + smoke-pin (anti-drift) — total ~1 hour. Below text retained as historical context.

---



**Observation (2026-04-22)**: librarian заявлен как "the only agent that creates new KB documents" (`agents/librarian.md` Rules), но в реальности orchestrator'ы + skill'ы + developer'ы пишут в KB напрямую, игнорируя делегирование. Этот паттерн повторяется сессию за сессией: create spec → edit MOC → add BACKLOG item → write research note → все через Edit/Write, не через librarian.

**В текущей session (2026-04-22) конкретно**:
- research note `direction-calibration/2026-04-22-...md` — написана orchestrator'ом напрямую
- spec `design/2026-04-22-mandatory-code-audit-phase.md` — напрямую
- exec workdoc — напрямую
- BACKLOG #43 — напрямую (librarian не вызван для numbering / priority section placement)
- MOC update — напрямую Edit

Ни один librarian spawn за session, притом что создано 5 KB-артефактов.

**Почему это происходит (гипотезы)**:
1. **Cost/latency**: spawn librarian = extra subagent turn + tokens. Для одной MOC-строки просто быстрее Edit напрямую.
2. **Context overhead**: librarian нужен full context "что именно писать" — часто больше токенов в инструкции чем в самой правке.
3. **Process afterthought**: "use librarian" — не reflexive thought; agent не помнит паттерн в момент принятия решения.
4. **SKILL.md wording soft**: `/feature new` / `/research new` говорят "spawn Librarian if you need to update MOC indexes" — treated as optional. Нет must-use.
5. **No feedback loop**: нет smoke assertion / hook, который блокирует direct KB write или напоминает "а librarian?".
6. **Rule lives only in agents/librarian.md**: orchestrator читает SKILL.md чаще; rule buried в agent doc до тех пор пока agent не вызван.

**Impact**:
- Document layout rules могут быть обойдены (как user и отметил): frontmatter поля пропущены, path convention забыт, MOC entry не добавлен, BACKLOG numbering drift.
- Librarian → de facto unused. Если он не load-bearing в реальности, why spend tokens on maintaining prompt + keeping it in agents/?
- `agents/librarian.md` detailed Document Paths / Document Formats — effectively unused documentation.

**Задача — двухэтапный review**:

**Этап 1 — audit actual usage за последние 2-4 недели**:
- Grep sessions history / git log: сколько Librarian spawn calls vs сколько KB артефактов создано.
- Manual audit sample KB files: compliance score per rule (frontmatter schema complete? path correct? MOC entry added? BACKLOG numbering monotonic?).
- Classify violations: (a) cosmetic (missing optional field), (b) functional (broken link, wrong path, missing MOC entry), (c) convention drift (BACKLOG numbering gap, wrong status enum value).

**Этап 2 — decide posture based on audit results**:

Три возможных mode'а, выбор зависит от этапа 1:

- **Mode A — Enforce delegation** (if violations are frequent + functional). Add hooks/smoke blocking direct KB writes outside librarian; tighten SKILL.md language "MUST spawn librarian" (not "may"); add PreToolUse hook that intercepts Edit/Write on `<kb>/repos/<project>/**` when target is a new file or specific paths (MOC.md, BACKLOG.md, design/, research/, security/) → prompts for librarian spawn.
- **Mode B — Accept reality** (if violations are rare + cosmetic). Reframe librarian as "optional helper for ambiguous cases" not "canonical gateway". Inline layout rules into orchestrator prompts (SKILL.md sections for each doc type with frontmatter templates copy-paste-ready). Smoke assertions check schema compliance on KB artifacts directly. Librarian exists for MOC-index-maintenance specifically (its genuinely hard case: read all files in a directory, build up-to-date index), not for routine creates.
- **Mode C — Delete librarian entirely** (if almost always bypassed AND violations are rare when bypassed, meaning convention is already internalized by orchestrator). Inline its rules into SKILL.md references. Remove `agents/librarian.md`. Savings: -1 agent prompt to maintain.

Моя интуитивная prior перед audit'ом: **mode B** — violations likely cosmetic (orchestrator mostly gets frontmatter right), librarian redundant for routine creates, but genuinely useful for MOC maintenance (read-many-files-then-write case). But this is guesswork until audit данные показывают.

**Связь с #43 (Librarian → Haiku) — blocks #43**:
- Этот review (#44) — blocker #43. Нет смысла оптимизировать агента на Haiku, если решение будет "удалить его полностью" (mode C) или "inline rules" (mode B частично). Если audit → mode A → тогда Haiku downgrade становится ещё более осмысленным (больше invocations = больше savings).
- Sequential: #44 first (audit + decision), then #43 (if still relevant).

**No-regression constraint**: existing specs + research notes + findings остаются as-is независимо от решения. Только изменяется ПРОЦЕСС CREATE.

**Почему P2 "подумать"**: pattern systemic, value murky, decision зависит от data (audit). Не блокер текущего Layer 1 / Layer 2 roadmap, но потенциально существенный clean-up при team rollout (#42).

**Источник**: session 2026-04-22 — user feedback после наблюдения что в пределах одной session было 5 KB creates без librarian spawn'а.

### 43. Downgrade librarian agent to Haiku (model tiering)

Librarian в основном делает structured output против жёстких schema'ов (frontmatter per doc-type, MOC entries, BACKLOG numbering, finding-doc templates). Это pattern-following work, не глубокое рассуждение. Текущая модель (`opus`, предполагается) — overspec для задачи.

**Precedent**: `agents/haiku-finding-scorer.md` уже на Haiku, делает bounded rubric-based scoring — работает. Industry-scan insight #5 (model tiering) прямо про это.

**Ожидаемый выигрыш**:
- Cost: ~10× дешевле Opus на librarian calls. Librarian invokes при каждом create spec / research / findings / MOC update — 10-20 вызовов в активный день. Накопительно ощутимо.
- Speed: заметно быстрее, особенно на MOC updates (мелкие structured edits не должны занимать Opus-latency).
- Aligns с mission axis-federation — cheap tier where deep reasoning не требуется.

**Риски + митигации**:
- Haiku хуже на cross-doc reasoning (дедупликация против existing entries, conflict resolution при ambiguous subtype/path). Митигация — orchestrator решает ambiguity ДО вызова librarian; librarian получает только explicit params (path, subtype, frontmatter values).
- Качество генерации свободной прозы (description поля в MOC, conclusion блоки) немного хуже. Митигация — tighten prompt'ы с explicit templates per doc-type + strict schema validation.
- Edge cases в subtype-picking — Haiku скорее guess'нет чем откажется. Митигация — если ambiguity, orchestrator обязательно спрашивает user'а; librarian не делает own judgment calls на subtype.

**Скоуп spec'а (когда picked up)**:
1. Изменить `model:` frontmatter в `agents/librarian.md` с текущего на `haiku` (модель `claude-haiku-4-5-20251001`).
2. Ужесточить librarian.md prompt: explicit frontmatter templates per doc-type (spec / research / findings / postmortem / backlog), strict "write only what's asked; do not infer subtypes" instruction, schema validation reminders.
3. Перевести orchestrator-side (feature / research / cross-audit skills) на явные param-передачу вместо полагания на librarian's judgment: subtype выбирается orchestrator'ом ДО вызова; path computed explicitly; frontmatter values pre-filled where possible.
4. Smoke assertions на shape generated frontmatter (если уже нет): valid YAML, required fields present, type enum match for each doc type.
5. Опционально — fallback pattern: если librarian Haiku возвращает malformed YAML или отсутствующее required field, orchestrator detects и re-spawns (1-retry policy); если стабильно плохо — escalate на Opus через config.

**Anti-goals**:
- Не усложнять — не делать двух-уровневый fallback mechanism в первой итерации. Сначала Haiku default + tight prompts; escalate path как follow-up если FP/quality rate окажется высокой.
- Не трогать `haiku-finding-scorer` — там уже Haiku и работает.
- Не трогать cross-auditor / investigator / developer-senior / spec-compliance-checker / verifier — это reasoning-heavy агенты.

**Validation-gate evidence**:
- До ship: 3-5 test cases на representative librarian tasks (create research note, create finding, append MOC entry, update BACKLOG numbering, create postmortem) — прогнать Haiku vs Opus side-by-side, сравнить structured output. Если Haiku matches на ≥90% critical fields — ok.
- После ship: monitor malformed-output rate первые 2 недели; если >10% re-spawn rate — re-evaluate.

**No-regression constraint**: all librarian consumers (feature skill create spec, research skill create note, cross-auditor findings writer, cross-audit finding doc create) продолжают работать 1:1. Только изменилась внутренняя model + ужесточился prompt.

**Почему P3 "подумать"**: не блокер текущего Layer 1 / Layer 2 roadmap'а (audit coverage). Но high-leverage operational efficiency win. Priority bump возможен если (a) замечаем что session cost растёт на librarian calls, (b) team rollout и multiple users делают cost visible, (c) появляется spec где librarian используется heavily (например backlog refactoring).

**Blocked by #44**: нет смысла оптимизировать модель если не решено ещё, что делать с ролью librarian в принципе (enforce / accept / delete). Ждёт audit результатов #44 → затем принимаем решение по Haiku.

**Источник**: session 2026-04-22 — user replay industry-scan insight #5 (model tiering) после конвергенции по self-sufficiency roadmap.

### 46. Plugin claims-vs-runtime audit pass (NEW — added 2026-04-25 per investigate convergence)

**Context**: Investigate convergence 2026-04-25 (Claude Opus xhigh + Codex GPT-5.5 xhigh, CONVERGED) выявил systemic class **"load-bearing by name only"** — компоненты, которые MISSION.md / SKILL.md / agent prompts заявляют как enforced, но runtime поведение не соответствует. Конкретные подтверждённые случаи:

- **MISSION.md:38** заявляет: "R1-R7 enforced compliance-checker'ом per step". Реально `agents/spec-compliance-checker.md:94-117` enforce'ит только R1/R2 (концерты по dead-code tests + trust tiers). R3/R5/R6/R7 — prompt-text only.
- **Smoke harness 401 assertions** смешивают behavioral checks (helper actually runs and exits non-zero), schema checks (frontmatter valid YAML), и prompt-text pins (byte-exact substring grep on prose). Без классификации reader не может оценить confidence: "401 assertions" звучит как 401 confidence units, реально = mix.
- **`agents/librarian.md`** заявляет: "the only agent that creates new KB documents". Observed: 0 librarian spawns / 5 KB-creates per session (#44 — pilot для этой методики).
- (вероятные дополнительные при audit'е): `verifier` scope ("never writes source code" — true но что ещё?), `haiku-finding-scorer` ("rubric-based scoring" — какие rubric items реально дискриминируют?), agent prompt MUSTs которые orchestrator игнорирует.

**Задача (single PR scope, NOT prompt rewrite)**:

1. **MISSION.md honesty edits** (Tier 1):
   - Line 38 narrow до R1/R2 enforcement claim ("only R1/R2 are enforced by `spec-compliance-checker.md` today; R3-R7 are convention-text only"). С пометкой что Tier 3 expansion есть в backlog (см. quick-task в P0).
   - Replace "Current binding constraint = audit coverage" formulation на active constraint set: "audit-coverage tail / rollout-isolation / process-truthfulness / rule-enforcement". Add re-evaluation cadence (every 5 shipped specs OR new escape incident).

2. **Smoke harness per-check classification** (`proves: behavioral|schema|prompt-text`):
   - Add `proves:` field per `check "<label>" <helper>` invocation в `tests/smoke.sh` (либо inline annotation, либо separate manifest mapping).
   - Suite-level summary reports counts по class (e.g. "behavioral: 130 / schema: 84 / prompt-text: 187").
   - Honest signal: prompt-text pins легко спуфятся inert text (как iter-7 R3 audit показал); behavioral assertions — load-bearing.

3. **Agent prompt MUST audit**:
   - Grep all `agents/*.md` for "MUST", "always", "never", "do NOT". Per claim, classify: (a) enforced by orchestrator/hook/smoke, (b) convention-text only, (c) self-policed by agent itself (no external check).
   - Surface (b) и (c) sets to MISSION.md as "documented but not gated" — set expectation honestly.

4. **Spec-compliance-checker scope name fix** (если audit подтверждает): rename agent или narrow description from "verifies observed matches planned intent" (which sounds R1-R7 covering) to explicit "enforces R1/R2 + workdoc DONE rule + git-conventions; R3-R7 are read-only references". (Optional — depends on Tier 1 honesty wording).

**Scope clarification**: `#46` is **audit + classification + honesty edits**, NOT a prompt rewrite. The fix is to make claims match reality, не наоборот.

**Critère d'acceptance**:
- MISSION.md honesty edits landed (Tier 1 minimum).
- Smoke harness per-check `proves:` annotation present (behavioral / schema / prompt-text classification).
- Agent prompt MUST audit produces categorisation table в одном из docs/ или MISSION.md "documented vs enforced" appendix.
- No false claim survives: every "X enforced" / "Y always" / "Z never" в MISSION + agent prompts либо has a runtime gate, либо marked "convention only".

**No-regression constraint**: existing assertions работают 1:1; only metadata + presentation changes. Helpers не переписываются. Agent prompts не теряют function — только narrow claim wording.

**Связь с D1 (convergence open question)**: Tier 1 honesty PR может ship либо сразу (Claude position), либо только когда named Tier 3 spec в backlog (Codex position — иначе vague future = ceremonial honesty). User decision required перед start.

**Почему P0 / next-default-move equiv**:
- Mission-level claim drift = highest leverage hit (per convergence).
- #44 — pilot методики на одном агенте (librarian); #46 — generalisation методики на весь plugin surface. Sequential: #44 first → #46 inherits the methodology.
- Закрывает "aqua-bribes-class" risk: agent заявляет "R3 enforced" → user trusts → spec audit doesn't catch weak test → escape. Real cost > UX polish (#36).

**Источник**: investigate convergence 2026-04-25; D1 disagreement still open; ADD verdict в convergence report explicitly.

### 48. Audit-blind-spot class — smoke harness env-stripping masks production-env interactions (evidence pool, P2 deferred)

**Pain (real, observed 2026-04-25):** smoke helpers invoke hooks/scripts via `env -i KEY=VAL... bash <script>`, which strips inherited shell state — `BASH_ENV`, `BASH_OPTS`, sourced startup-file shopts, locale env (`LANG`/`LC_ALL`/`LC_NUMERIC`), `TZ`. Production invocations inherit the user's full env; tests assert behavior in artificially clean env. The class is invisible to the existing harness because the harness IS the source of the strip.

**Canonical incident:** X1 in spec `2026-04-25-conditional-session-start-activation` (PR #47, iter-1 cross-audit). `hooks/session-start` memory-arm `ls "..."*.md >/dev/null 2>&1` was unsafe under inherited `nullglob` (false-positive activation in any orthogonal project) and `failglob` (bash-abort with no JSON, breaking the always-emit-valid-JSON contract). All 4 newly-added arm-isolation smoke helpers passed because `env -i` strips `BASH_ENV`; cross-auditor reproduced via `BASH_ENV=<file with shopt -s nullglob>` against the un-fixed hook. Fix: `compgen -G` + `shopt -u nullglob failglob` defense-in-depth + 2 BASH_ENV regression smokes. The fix closed the per-incident hole; the **class** remains uncovered for other env vectors.

**Generalises beyond X1 (vector inventory):**
- **`LANG` / `LC_*`** — affects `sort` collation, `grep -i` case-folding, locale-dependent regex, ICU-aware string ops in helpers / hooks. Test harness uses `env -i PATH=$PATH` → no `LANG` → C locale → potentially divergent from production where user has `LANG=ru_RU.UTF-8` / `LANG=zh_CN.UTF-8`.
- **`BASH_ENV`-sourced functions overriding builtins** (rare but possible: user `source ~/.bashrc` aliases `ls` with options that change exit semantics, or shadows a builtin used by the hook).
- **`shopt` settings** beyond null/failglob: `extglob`, `globstar`, `nocaseglob`, `dotglob` — any of these can change glob semantics for production code that uses globs.
- **`TZ`** — affects `date` formatting and epoch math in any script that timestamps output or compares times.
- **`HOME`** — already exercised partially (memory-arm gates on `${HOME:-}`), but not all env-shape variants tested.

**Probe candidate (when evidence pool grows ≥ 2 incidents):** "env-fuzz probe" — for each smoke helper that invokes a hook/script under test, run an extra invocation with a fixed set of "weird-env" presets (`LANG=C`, `LANG=ru_RU.UTF-8`, `BASH_ENV=<shopt -s nullglob>`, `BASH_ENV=<shopt -s failglob>`, `TZ=UTC`, `TZ=Asia/Tokyo`). Assert behavior identity across env presets, OR allow-list documented divergence in the spec. Property-style testing over the env-state space. Same shape as Probes E (diff-scope), F (cardinality), G (test redundancy) — bounded contract + CI-runnable.

**Why P2 (deferred), not P0 / P1:**
- Real evidence (X1 — HIGH severity, would have hit production for any user with `BASH_ENV` setup).
- Generalises beyond hook context — any plugin script with env-dependent behavior is at risk.
- Not actively blocking any feature (X1 already fixed in production via `compgen -G` + targeted smoke).
- **Probe inflation cost** — same caution as #38 (G probe) and #39 (N probe) deferral: do not graduate to a full probe series on a single incident. Wait for ≥ 2 incidents (or one cross-context incident in a non-hook script) before authoring a probe spec. Memory entry for the class: **TODO** (audit-blind-spot class candidate noted in spec Log of `2026-04-25-conditional-session-start-activation`; should be lifted to a `feedback_audit_class_*` memory file once second incident validates the class).

**No-regression constraint:** if probe is later authored, env-fuzz must be purely additive — existing smoke remains green; env-fuzz extras run under their own `--- env-fuzz probe ---` smoke section.

**Источник:** session 2026-04-25 PR #47 iter-1 cross-audit (X1 finding); spec Log of `2026-04-25-conditional-session-start-activation.md` captures rationale; user authorisation 2026-04-25 to log as evidence pool.

### 49. `/feature new` prompt-stack collapse — silent change_type inference + single handoff banner (R1 from cuts investigation 2026-04-26)

**Pain (real, observed multiple sessions, most recently stellar-arbiter session 2026-04-26):** `/feature new <description>` fires 4–5 banners in a row before approval gate: change_type, deploy_prerequisites, smoke_check, post-merge items, then spec approval. For typical code-only refactor/fix/feat specs the answers are inferable from description (~90% confidence) — banner-cadence violates `docs/confirmation-cadence.md` "drive to completion without re-asking" and the `docs/user-input-banner-convention.md:45` rule that banners are for forks where the agent *cannot proceed*.

**Two changes:**

1. **Silent change_type at high confidence.** Keyword match on description (case-insensitive, whole-word, from existing SKILL.md keyword→type table) + no contradicting keyword → auto-infer; Log line records `change_type=<type> (auto-inferred high-confidence; description contained "<token>")`. Low confidence (no match OR multiple types match) → existing banner stays. Wrong-inference recovery: `git branch -m` + 1-line frontmatter sed.

2. **Collapse deploy_prerequisites / smoke_check / post-merge into ONE handoff banner**, triggered by heuristic keywords in description: `deploy / restart / migration / cron / cache / registry / monitoring / bot / config`. Keyword present → single banner asks "looks operational — нужны post-merge items? [y/N]"; `y` expands into detailed prompt; `N` → spec body gets `<!-- no post-merge items -->` marker. Keyword absent → §3.3/§3.4/§8 marked optional, default empty. Spec-template §3.3-3.5 promoted to conditional (per cuts-investigation R1; matches the post-cut state needed for sub-cuts C7/C16/C17 if those land later).

**Files touched:**
- `skills/feature/SKILL.md:177-197` (change_type prompt) + deploy/smoke/post-merge prompt blocks
- `skills/feature/references/spec-template.md` — mark §3.3/§3.4/§8 conditional, add `<!-- no post-merge items -->` marker convention
- `tests/smoke.sh:1239` (banner-count pin) + `:1753` (banner-text pin) — update under new layout
- `docs/confirmation-cadence.md` — clause that high-conf inference suppressed banner
- Composite smoke assertion: if keyword X in description → spec template includes §3.3 (drift guard between rules and skill body)

**Why now (P1):**
- Single most-cited UX pain in real-session feedback (stellar-arbiter session 2026-04-26 P2 finding — "обязательные banner'ы для inferable полей").
- Closes pre-existing rule contradiction between `confirmation-cadence.md` and `user-input-banner-convention.md`.
- Cheap (~1 spec, ~1 PR, ~1 cross-audit round); no new abstraction; cuts ~15s + cognitive load per `/feature new`.
- Mission: banner-convention drift fix; not on active constraint set axis but corrects existing mission-level inconsistency.

**Risks (mitigations):**
- Wrong inference on `change_type` → cheap recovery path (rename branch + sed); Log line records rationale for audit.
- Keyword trigger misses real operational feature → user says "no post-merge needed" if false positive; default behaviour ask-when-keyword-present is conservative (favors more banners not fewer).
- Smoke baseline breaks → spec owns smoke pin updates in same commit.
- Drift between trigger keywords and template body → composite assertion enforces.

**Out of scope (separate spec if pursued):**
- `/feature new --quick <desc>` escape hatch with hard-guards (R2 from cuts-investigation; new feature, not collapse).
- Removing approval gate (load-bearing for team handoff trajectory).

**Источник:** investigate convergence 2026-04-26 (cuts session, R1 refine); pulls in P2/P2a from stellar-arbiter session 2026-04-26 friction report; user approved R1 explicitly 2026-04-26.

### 50. Investigate verified cut candidates — C4 librarian / C11 Codex Fast / C19 PR publish / C21 --probe-downgrade

**Pain (verified 2026-04-26 via grep over plugin source + KB specs):** four plugin subsystems exist with effectively zero production use, but each has a different rebuild-cost profile on team handoff. The first cuts-investigation (2026-04-26) overshot — Codex confidently flagged ~21 items as "empirical zero usage", verification overturned 9 of them. The remaining 4 below are honestly verified, but cutting them is a design decision that needs adversarial scrutiny per item, not a single-pass cut campaign.

**Per-candidate evidence:**

- **C4 — `agents/librarian.md` retire.** CLAUDE.md self-confesses 0.54% delegation rate; user's own research note `repos/ai-dev-team/research/librarian-effectiveness-review/2026-04-25-actual-vs-declared-role.md` empirically validates. Replacement mechanism: deterministic write-time validation + periodic tidy passes (already piloted Sonnet-tidy 2026-04-26 commit `bc41714`). Rebuild cost on team handoff: small (one spec to re-add agent if MOC volume justifies).

- ~~**C11 — Codex Fast dispatch variant.**~~ ✅ DONE (2026-04-27, PR #64) — cut per `design/2026-04-27-cut-codex-fast.md`; net −226 LOC + −17 smoke checks; 0 user-spec invocations confirmed. `T-CF*` rationale strings existed in plugin source (`agent-routing.md`, SKILL.md option 1b, smoke pins) and in the spec that built the feature (`design/2026-04-18-codex-fast-mode.md`), but **never appeared in any other spec's Log entries**. Built dispatch path, no real selections. Rebuild cost: small (spec to re-add when team workflow justifies).

- **C19 — Cross-audit PR publish subsystem.** `skills/cross-audit/references/publish.md` (169 lines) + standalone `/cross-audit publish` + `published_to:` schema + `hooks/lib/build_pr_files.sh` + PR-mode fixtures + smoke pins (~700 lines of plugin surface). `published_to:` records appear only in the spec that built the feature (`design/2026-04-17-pr-aware-cross-audit.md`); zero real PR-audit publishes recorded. **Specifically valuable for team handoff** (multiple devs running cross-audit on each other's PRs, posting findings as PR review comments) — strongest candidate to KEEP-FOR-TEAM despite zero solo usage. Rebuild cost: medium (full subsystem re-spec, fixtures, smoke).

- **C21 — `--probe-downgrade <id>=<mode>` CLI override.** Emergency override path for cross-audit probes; documented across multiple specs (`probe-e`, `probe-n`, `cross-audit-shared-invariants`, `ref-to-ref-scope`). Never invoked outside design docs themselves; YAML kill-switch (`cross_audit.probes.<id>.mode`) covers the same use case. Cuts an emergency safety valve. Rebuild cost: small.

**Investigation should answer per item:**
- Is "zero solo usage today" + "team rollout on roadmap" enough to KEEP-FOR-TEAM, or should we cut and rebuild on demand?
- For C19 specifically — what's the realistic scenario where team users would want PR-publish, and is the rebuild cost on first-such-need acceptable vs leaving 700 lines of unused infrastructure in the meantime?
- For C4 — librarian retirement was already implicitly accepted by the unified-format / write-time-validation direction (2026-04-26 design decision). Investigation could just confirm and write the retirement spec, no debate needed. Or pull librarian into the broader "drift-prevention mechanism" decision.
- Mission alignment per cut: rollout-isolation tail (C4, C19) vs verification (C21) vs ceremony reduction (C11).

**Why investigate before cut, not just cut:**
- Adversarial-debate confidence ≠ truth (lesson from 2026-04-26 cuts investigation: Codex flagged 21 cuts confidently, 9 were wrong). Each item needs explicit verification of the rebuild cost and the "team-someday-but-when" trajectory.
- Writing 4 separate cut specs is wasteful if 2 of them turn out to be KEEP-FOR-TEAM.
- Per-item investigation surfaces the genuine tradeoff (e.g. C19 has the strongest team-handoff case).

**Do NOT bundle as a single cut campaign.** The first cuts-investigation tried that and produced an over-eager 21-item list. Treat each subsystem as its own decision.

**Out of scope:**
- Items that were rejected as cut-candidates after verification (`investigation_source`, `follows_up`, `next_finding_id`, `start-soak`, `picked_up_from`, marketplace.json, etc.) — those are KEEP, no investigation needed.
- The R1-R6 refines from the same cuts-investigation — R1 already in BACKLOG #49; the rest are pure UX polish, defer until pain.

**Источник:** verified grep audit 2026-04-26 (4 candidates from initial 21-item cuts list survived per-item verification); user instruction 2026-04-26 to mark for investigate rather than cut directly.

### 51. Cross-auditor reliability — truncated agent return + missing findings file (parallel-session evidence pool)

**Pain (real, observed 2026-04-26 stellar-arbiter-rs session, parallel to ai-dev-team plugin work):** during a `feat/2026-04-26-mta-telemetry-restore` flow, cross-auditor agent was spawned as background task for code audit iter1 on a 7-commit diff (116.9k tokens, 8 steps Codex-implemented, verify PASS with 16 new tests / 145 total). Agent reported "completed" — but:

1. **Agent return value was truncated** (visible in screenshot: "Auditor return обрезан. Смотрю findings файл напрямую").
2. **Findings file at `<kb>/repos/<project>/security/<slug>-code-findings.md` was NOT written** — protocol violation per `agents/cross-auditor.md` Step 4 contract ("write TWO documents to the KB ... findings.md ... workdoc-iter<N>.md").
3. Orchestrator detected the violation and re-spawned cross-auditor with explicit instruction to write the file. Recovery succeeded but the contract was broken.

**Class — adversarial-debate convergence verifiability gap.** This is the third incident in a broader "cross-auditor unreliability" class:
- 2026-04-18 — `evm-arbiter/design/2026-04-18-honest-tx-lifecycle-reporting.md:320` — auditor stream stalled, self-audit substituted, status flipped to `AUDIT_PASSED`.
- 2026-04-25 — `evm-arbiter/design/2026-04-25-balancer-stable-coverage-and-yield-audit.md:396` — cross-auditor stalled twice, self-audit substituted, status flipped to `AUDIT_PASSED`.
- 2026-04-26 — stellar-arbiter-rs MTA telemetry restore — cross-auditor "completed" but truncated return + missing findings file. (Distinct failure mode from the prior two: NOT a stall — the agent ran to completion but its contract output was missing.)
- 2026-04-30 — `ai-dev-team/design/2026-04-30-shared-absence-helper-extraction.md` code-audit iter-1 — cross-auditor agent ran for 13 min / ~100k tokens, returned `status: completed` but final summary contained only an internal reasoning fragment ("`local paths=("$@")` under `set -u`…"). No `<kb>/repos/ai-dev-team/security/2026-04-30-shared-absence-helper-extraction-code-findings.md` produced. Worktree auto-cleaned (no changes). Same failure mode as the 2026-04-26 stellar-arbiter case (agent completes but contract output missing). Diff was small (5 files, +113/-27 lines). Orchestrator manually self-verified per `feedback_iter_2_audit_fallback.md` and recorded `code_audit_evidence: self_fallback`.

PR #59 (2026-04-26 Codex async dispatch fix) addressed the watchdog-stall root cause for the first two. **It does not address the third or fourth incident** — return truncation and missing-file are different failure modes (likely sub-agent token-budget exhaustion on large diffs / large finding counts, or harness-level transcript truncation between sub-agent return and parent-agent display). The 2026-04-30 fourth incident is the second observation of the contract-violated-but-no-stall pattern, raising urgency on the recovery automation question (file-existence check post-return + auto re-spawn) raised in §"Investigation should answer".

**Why this matters now:** the HARMFUL `audit_evidence:` enum (separate spec, queued P0 from 2026-04-26 release retrospective) was scoped to `dual_model | single_model | self_fallback | skipped`. This third incident widens the gap — `skipped` should additionally cover "ran but contract broken" (return truncated, findings file missing). Without this widening, the orchestrator's recovery path (re-spawn) hides the underlying reliability issue from any future audit-evidence stats.

**Investigation should answer:**
- Is the truncation harness-level (parent agent message clip) or sub-agent-level (sub-agent ran out of tokens / output budget mid-write)?
- Does the cross-auditor write order (findings file first, then return) actually hold under the failure mode? Or was the sub-agent killed before reaching the write step but after issuing a partial response that *looked* like a "complete" signal to the orchestrator?
- Is this correlated with diff size / finding count? Of the 3 incidents, what were the input sizes?
- Should the HARMFUL `audit_evidence:` enum include a `contract_violated` variant alongside `skipped`?
- Should the orchestrator (feature skill code-audit phase) verify the findings file exists on disk after cross-auditor returns, before recording the iteration Log marker? If file missing → re-spawn auto-trigger instead of relying on parent-agent eyeballing the truncated return?

**Out of scope for this entry:** fix the issue. This is evidence-pool framing — collect more incidents before deciding whether to author a probe-style detector or fold into HARMFUL `audit_evidence:` enum.

**Источник:** stellar-arbiter-rs parallel session 2026-04-26 (screenshot evidence captured by user); class anchored in 2 prior evm-arbiter incidents from 2026-04-18 and 2026-04-25; user instruction 2026-04-26 to mark for KB investigation.

**2026-05-13 update — incident #5 (cross-auditor spec mode) and incident #6 (developer-senior) from cap-banner-and-empirical-verification spec cycle:**

- **incident #5 — cross-auditor spec mode (iter-2 v1, 2026-05-13):** Agent returned `status: completed`; final emitted text was `"Let me continue audit while monitoring Codex via BashOutput."` — one mid-thought sentence. No inline 3-line EOF footer (`evidence_class:` + `evidence_blockers:` lines absent — contract violation per `agents/cross-auditor.md` §Spec-mode return contract). SendMessage rescue unavailable (harness `status: completed` closes the channel). Recovery: orchestrator spawned iter-2 v2 with hard ≤30 turn budget + narrow scope + named for SendMessage rescue; v2 returned cleanly with `evidence_class: dual_model`.

- **incident #6 — developer-senior implementation (Step 2 v1, 2026-05-13):** Final harness error `"API Error: Stream idle timeout — partial response received"` after 15 tool uses. On-disk state: working tree clean — no commit, no captures, no edits. Recovery: orchestrator spawned Step 2 v2 with explicit minimal-read protocol; v2 completed cleanly.

**Cumulative evidence pool as of 2026-05-14: 6 incidents across 4 weeks.** Incidents #3-#6 share the same fundamental failure mode: agent emits `status: completed` but contract artifact is absent or partial. PR #59 (2026-04-26) fixed the watchdog-stall root cause for incidents #1-#2 only.

**8-probe empirical sweep (2026-05-14) — key conclusions:**
1. Read tool has 25k-token cap with ERROR return — agents cannot silently overflow from a single Read call.
2. Cumulative reads ~100k tokens safe in 9 tool uses.
3. Tool-use count up to 31 safe with mostly-small returns.
4. Stream watchdog > 240s at pure xhigh think (no tools).
5. Mixed-tool workflow at 10 tool uses safe when prompt allows parallelization.
6. P5b + P8 both completed under near-identical conditions to v1 truncations — strong evidence both v1 instances were **transient/flake**, not deterministic from task structure.
7. Prescriptive serial step-by-step prompts may force serialization consuming more turns than open-ended prompts where the agent parallelizes naturally (P7 demonstrated this).
8. None of the orthogonal axes (read volume / tool count / think time / combined) deterministically reproduces truncation. Root cause: orchestrator trusts `status: completed` without artifact verification — the detection strategy is invariant regardless of secondary mechanism.

**Investigator R1+R2 convergence (2026-05-14):** Two-spec split converged: Spec A (cross-auditor contract gate automation — builds `hooks/lib/check_dispatch_response.py` runtime classifier + recovery prose at 3 surfaces / 6 callsites) + Spec B (senior contract gate + dispatch ledger, deferred). See full convergence narrative at `research/subagent-truncation-pattern/2026-05-14-recurrence.md` §5.

**Evidence-pool status (2026-05-14):** Investigation complete (8-probe sweep + R1/R2 convergence 2026-05-14); Spec A v2 in flight at `design/2026-05-15-cross-auditor-contract-gate-automation.md`.

### 52. `/feature continue` blind to multi-spec queues planned in research notes (session-handoff gap)

**Pain (real, observed 2026-04-27 ai-dev-team session, repro):** previous session (2026-04-26) closed with explicit handoff: PR A-1 SHIPPED + queue `PR A-2 (--from-investigation cut) / PR A-3 (T-CF Codex Fast cut) / PR A-4 (multi-GH-account cut) / HARMFUL audit_evidence: enum (P0)`. Queue documented in `research/release-retrospective/2026-04-26-zombie-cleanup-batch.md` § Cleanup execution plan + § HARMFUL. Next session opened with `/feature continue` — orchestrator scanned `design/`, found three parked specs (1 DRAFT superseded, 2 BLOCKED with unsatisfied conditions), reported "no spec is mid-implementation." The 4-item queue was invisible; user had to resurface it manually from chat memory.

**Root cause — skill scope by design:** `skills/feature/SKILL.md` § "Session resume — KB scan" + § "Continue mode" both read only `<kb>/repos/<project>/design/YYYY-MM-DD-*.md`. Research notes are out of scope. Memory pointers are out of scope unless they map to a specific spec file. Result: any planned-but-not-yet-materialized spec batch falls into a blind spot between "no spec exists" (would need `/feature new`) and "spec exists with non-terminal status" (would need `/feature continue`).

**Class — handoff-state truthfulness gap.** Adjacent to MISSION operational rule #9 (verify empirical claims) and #7 (honesty edits ship with named enforcement slice). The skill is honest about what it scans, but the user model assumes "continue picks up where we left off" — which fails when "where we left off" lives outside `design/`.

**Investigation should answer:**
- Is the right fix a session-end discipline rule (orchestrator MUST write a memory bridge entry like `next_session_queue:` listing planned spec slugs + source pointer) — or a skill extension (`/feature continue` ALSO scans `research/**/*.md` for `## Cleanup execution plan` / `## Queue` / `## Next steps` sections from CONCLUDED notes ≤ N days old) — or both?
- If discipline rule: where does it live? `/feature` skill end-of-flow? `/research` skill on `concluded` mode? CLAUDE.md? MISSION operational rule #11?
- If skill extension: what's the scan budget vs noise tradeoff (research/ has more files than design/)? Heuristic: only notes with `status: CONCLUDED` + a recognized queue heading + `created/updated` within last 14 days?
- Should `/feature status` also surface queued-but-not-started batches? (Currently it groups by spec status — has no concept of "planned spec.")
- Cross-cutting: does `/research` skill need a `--queue-spec <slug-list>` parameter so retrospective notes explicitly publish their successor specs in machine-readable form?

**Out of scope for this entry:** ship the fix. Evidence-pool framing — single observed incident, but class is plausible (any release retrospective / investigation that produces a multi-spec successor batch will hit this). Wait for 2nd incident before graduating to spec, OR fold into `/research` skill polish if the queue-publish mechanism is small enough to bundle.

**Mitigation meanwhile (manual):** at session-end when planning a multi-spec batch, write the queue into a memory bridge entry following the format from `MEMORY.md` § BRIDGE convention, with pointer to source research note. Next session's `/feature continue` won't auto-pick it up, but the memory will be auto-loaded into context, so the orchestrator can surface it during status scan.

**Источник:** ai-dev-team session 2026-04-27 (this conversation); previous session 2026-04-26 retrospective + handoff at `research/release-retrospective/2026-04-26-zombie-cleanup-batch.md`; user instruction 2026-04-27 to mark for KB / future work.

### 54. anchor-uniqueness + section-scope as first-class invariant for multi-pin smoke harnesses sharing canonical literals

**Pain (observed 2026-04-27/2026-04-28 in `2026-04-27-audit-evidence-enum` cross-audit, X10):** when several smoke pins share a canonical regex/string literal across the test file (production helper site + multiple meta-pin guards + explanatory comments), a structural-canary `grep -c <literal> tests/smoke.sh` against the file globally counts ALL occurrences. A mutation that ONLY affects the production-helper site still leaves the other occurrences intact — the canary's count stays > 0 and the test silently passes. The X9 fix in audit-evidence-enum scoped THAT meta-pin to the awk-extracted `_fixture_latest_code_audit_marker()` body (smoke.sh L4441-4449). Iter-6 cross-auditor of the same spec flagged this as an endemic pattern across smoke pins sharing canonical literals (X10): every meta-pin currently relying on a file-wide grep is potentially affected.

**Class — verification-rigor / structural-canary placement.** Different defect class from "recognition contract drift" (X9) and "literal/format brittleness" (X9r) — those are about WHAT the regex matches; this one is about HOW the meta-pin asserts "the production site (specifically) still uses the canonical literal". Cross-references:
- 2026-04-27-audit-evidence-enum.md X10 finding (iter-6 cross-auditor flag).
- 2026-04-28-orchestrator-delegation-and-stop-criteria.md §3.2 row 8 + §4 dependencies (this entry's source).
- The 2026-04-28 spec's own Step 7 meta-pin (`check_audit_iteration_hard_cap_recognition_mutation_protected` P3) was intentionally scoped to the awk-extracted `_fixture_latest_audit_iter_marker()` body following the X9 lesson — but the systematic sweep across ALL existing meta-pins is out of scope for that spec.

**Investigation should answer:**
- Inventory: which meta-pins in `tests/smoke.sh` use file-wide `grep -c <literal>` for structural-canary purposes? (Audit pass: any P3-style invariant inside a `*_mutation_protected` pin function.)
- Should the rule be codified as an R-rule (`code-quality-rules.md`) or a workflow rule (`developer-workflow.md`) or just a smoke-harness convention?
- Is there a generic `_fixture_assert_in_function_body <literal> <fn_name>` helper that could replace the current `awk '/^fn\(\)/,/^}/' | grep -cE ...` boilerplate uniformly?
- Does any existing pin satisfy the rule today by accident (literal globally unique → file-wide count == 1 == in-function count)? If so, those should be tightened to in-function scoping anyway, since global uniqueness is fragile (any future helper that mentions the same literal in a comment breaks the canary).

**Out of scope for this entry:** doing the sweep. This is a pure bookkeeping/follow-up entry; surfaces a class of weaknesses rather than committing to a fix. Wait for evidence-pool 1+ before graduating to spec OR fold into a generic smoke-harness-discipline pass.

**Mitigation meanwhile (manual):** when authoring a new mutation-protected meta-pin, scope structural-canary greps to `awk '/^fn\(\)/,/^}/' tests/smoke.sh | grep -cE <literal>` (the awk range form), NOT a file-wide `grep -c <literal> tests/smoke.sh`. The 2026-04-28 spec's Step 7 meta-pin is the current example.

**Источник:** iter-6 cross-auditor of `2026-04-27-audit-evidence-enum.md` (finding X10); the 2026-04-28 stop-criteria spec deferred this as a separate-class follow-up per its §3.6 Risks last row.

### 55. `hooks/stop-check` false-positive on worktrees / submodules / nested child repos

**Pain (observed 2026-05-25 ai-dev-team session, repro):** Stop hook fired with `Feature branch feat/2026-05-25-r2-positive has 1 commit(s) not yet pushed` while the parent repo's actual working tree was on `main`, clean. Root cause: a subagent (`spec-compliance-checker`) had `cd`'d into a child git repo at `.skill-bench/spec-compliance/cases/r2-positive/project/` for its `git diff` work; when Stop hook ran, `git rev-parse --show-toplevel` resolved that child repo's toplevel, not the parent's. The child repo was on a dated `feat/…` branch (because the bench fixture intentionally uses conventional-prefix branches to exercise the checker's branch convention), which matches `FEATURE_BRANCH_RE` in `hooks/stop-check` → hook fires → user gets a "merge / push / keep / discard" prompt for a sandbox branch that has no real handoff state.

**Class — cwd-vs-namespace conflation in hook detection.** Hook assumes "if cwd's toplevel is on a feat-branch, this IS the user's primary work in progress." False for: (a) git worktrees (`git worktree add` — `/cross-audit` Step 0 PR-materialize does this routinely, often on a dated feat-branch the PR was opened from), (b) git submodules (subagent dropping into a submodule on a feat-branch), (c) nested project layouts (`~/dev/parent/` and `~/dev/parent/vendor/lib-b/` both git repos), (d) bench harnesses / synthetic fixtures (this incident).

**Frequency in real flows:** primary repeat offender is `/cross-audit` Step 0 worktree materialization on PR feat-branches. 30-min per-repo debounce masks most user-visible repeats; the remaining noise is user-attention cost (interrupted reading flow + risk of attention fatigue making real warnings get ignored), not compute.

**Investigation should answer:**
- Is the fix a hook-side filter (e.g. compare `toplevel` against `$CLAUDE_PROJECT_DIR` / env-threaded primary-repo path → exit 0 on mismatch) or a hook-side enumeration (use `git worktree list --porcelain` to detect worktree vs primary, only fire when toplevel is the primary worktree)?
- Does the right primary-repo signal exist via env (`CLAUDE_PROJECT_DIR` looks promising), or does the hook need to walk the file tree from `$HOME` looking for the "owning" project? (Env is preferable — file-walk is fragile.)
- Should worktrees still fire the warning when they're on a real feat-branch (`/cross-audit` audit complete, user should clean up the worktree)? Argument both ways: noise vs. real reminder.
- Are submodules even a realistic vector here, or does our subagent flow not actually cd into submodules in practice? (Likely rare for ai-dev-team; document as theoretical class.)
- Confirm `Agent(isolation: "worktree", …)` auto-named branches `worktree-agent-<hash>` are already safe because the regex requires `\d{4}-\d{2}-\d{2}-` — but pre-checkout to a feat-branch defeats this.

**Out of scope for this entry:** ship the fix. Priority **P3** (low) — debounce blunts user-visible impact; remaining harm is attention-noise on the user side, not a workflow blocker.

**Mitigation meanwhile (manual):** ignore the warning when on `main` and the named branch is from a worktree / sandbox / vendored child repo. After bench harness runs or worktree cross-audits, optional `rm -rf` of the throwaway worktree clears the false-positive surface for the next session.

**Источник:** ai-dev-team session 2026-05-25 — spec-compliance-checker calibration bench (10 child repos under `.skill-bench/spec-compliance/cases/*/project/`, each on a dated feat-branch). False-positive confirmed via `pwd` (parent on `main`) + `git branch --contains` (branch only lives in the child repo).

---

### 75. R7 `enforced_by` flip → spec-compliance-checker deterministic gate (Rust v1) — DEFERRED pending recurrence

**Axis:** rule-enforcement. **Status: P2 deferred — promote after 1 recurrence post-`2026-06-02-r5-r7-test-placement-enforcement` ship.**

**Source:** `/investigate` convergence 2026-06-02 (Claude+Codex, CONVERGED 3 rounds). Ship 1/2a/2b (spec `design/2026-06-02-r5-r7-test-placement-enforcement.md`) close the R5/R6/R7 gap upstream (authoring reconciliation + spec-review LLM backstop + digest hygiene). This entry is the deferred **downstream deterministic gate** — the most expensive piece, held back because its blast radius covers only Rust in v1 and rewrites coupled hard-pins; wrong cost/benefit until upstream proves insufficient.

**Scope:** flip R7 `enforced_by: [none]` → `[spec-compliance-checker]` in `code-quality-rules.md` frontmatter, backed by a Rust-only deterministic helper script (mirror the R3 regex-detect model at `agents/spec-compliance-checker.md:146-160` + a helper invoked by exit code — NOT prompt-prose regex, which is LLM-judgment). Detection: inline `#[cfg(test)] mod tests` in a CHANGED production `.rs` file crossing `>=40 test-block-lines OR >=200 src-file-lines` (the R7 trivial-exception threshold, `code-quality-rules.md:305`). Verdict: DRIFT (helper-emitted or LLM-confirmed).

**Why deterministic-only-for-Rust:** R5/R6/R7 are multi-language; R6 (test scope) is semantic and NOT regex-detectable (stays convention-text/LLM — do NOT attempt). Python/TS placement stays semantic/LLM; Go satisfied by idiom. Only the Rust inline-`#[cfg(test)]`-block shape is mechanically detectable. Line-count threshold MUST be encoded to avoid false-positives on the trivial-module exception. The gate keys on inline-block shape, NOT private-import widening (a naive private-import gate over-flags R7-compliant sibling tests — the R6/R7 internal tension Codex raised).

**Recurrence trigger (promotion gate):** 1 observed instance, post-Ship-2, of a dev-agent shipping non-trivial inline Rust tests that BOTH 2a (authoring reconciliation) and 2b (spec-review backstop) failed to catch. The originating downstream-repo incident is instance 0; one post-fix recurrence confirms upstream insufficiency.

**Full acceptance criteria (when promoted):**
- helper script (Rust inline-test-block detector with `>=40`/`>=200` thresholds + brace-aware block parsing)
- Rust fixtures (clean / violation / trivial-exception-OK)
- R7 metadata flip `enforced_by: [none]` → `[spec-compliance-checker]` in `code-quality-rules.md`
- `R_RULE_GOLDEN_TABLE` update (`tests/smoke_rule_helpers.py:24` — R7 `["none"]` → `["spec-compliance-checker"]`)
- checker-description pin rewrite (`tests/smoke-helpers.sh:~4090` — byte-exact `'R5-R7 are convention-text'` no longer holds for R7)
- MISSION enforced-set-claim update (`tests/smoke-helpers.sh:~4100` — "R1, R2, R3" enforced-set claim extends)
- `agents/spec-compliance-checker.md:6` description update (R7 now gated)
- verdict/rules smoke pins for the new DRIFT path

**Anchor:** spec `2026-06-02-r5-r7-test-placement-enforcement.md` §1 + §3.1 DO-NOT-edit list; investigate convergence report 2026-06-02 (Ship 3 row + Risk Register).

---

### 76. Smoke-pin placement: canonical 3-edit protocol contradicts actual topical-clustering convention

**Axis:** code-quality conventions × process-truthfulness. **Status: ✅ DONE (2026-06-02) — PR #122 (option (a)).** CLAUDE.md §Testing step (1) rewritten to describe the real convention: define `check_<name>` adjacent to related existing pins (topical clustering) — `smoke-helpers.sh` default, `smoke.sh` where a rule-text cluster lives (R5/R6/R7 short-form digest pins). Doc-only, smoke 555/0. (Original P3 entry below retained for context.)

**Pain (observed 2026-06-02, `2026-06-02-r5-r7-test-placement-enforcement` spec-audit):** the pin-destination defect class recurred across **3 consecutive spec-audit iterations** (X1 §5 Step 1 / X5 §3.2 Changes table / X6 §2.2 line 59) — every surface that stated *where* a new smoke-pin function is DEFINED was independently wrong, and two surgical patches each missed a parallel surface until a §3.5c comprehensive sweep closed all 11. Root cause is a **convention contradiction**, not authoring sloppiness:

- **Canon** (CLAUDE.md §Testing, "Per-pin 3-edit protocol"): step (1) = "`check_<name>` function definition in `tests/smoke-helpers.sh`".
- **Reality**: the short-form digest pins live in `tests/smoke.sh`, clustered with their rule-text pins, NOT in `smoke-helpers.sh` — empirically: `check_developer_workflow_short_form_r5` defined+registered at `smoke.sh:2117/2145`, R6 sibling at `:2303/2323`; `check_developer_workflow_short_form_r3` IS in `smoke-helpers.sh:89`. So placement actually follows **topical clustering** (a pin lives next to the rule-section pins it extends), and both files hold check functions (`smoke-helpers.sh` ~299, `smoke.sh` ~214). There is no single canonical home; the protocol text asserts one that the codebase does not honor.

**Class — convention-vs-reality drift.** The canon reads as "always smoke-helpers.sh"; the codebase clusters by topic. Any spec author (or dev agent) who trusts the canon places a new short-form pin wrong, then trips over the adjacent "mirror the R5 sibling" instruction — exactly the X1→X5→X6 recurrence. The cost is per-spec authoring friction + repeated audit iterations, not a runtime bug.

**Decision space (pick one):**
- (a) **Canon → reality:** update CLAUDE.md §Testing step (1) to "define `check_<name>` adjacent to the related existing pins (topical clustering) — `smoke-helpers.sh` for the general helper pool, `smoke.sh` where a tight rule-text pin cluster already lives (e.g. R5/R6 short-form digest pins)". Cheapest; documents what already happens. Risk: weakens the "single home" simplicity.
- (b) **Reality → canon:** move the smoke.sh-resident short-form pins (R5/R6, and the new R7) into `smoke-helpers.sh` to match the canon literally. Larger diff; must preserve byte-exact registrations + section-scoping; re-cluster risk. Net simplification questionable (the topical cluster is arguably the better layout).
- (c) **Accept + document the exception narrowly** (lightest): leave both files as-is, add one sentence to CLAUDE.md §Testing noting the topical-clustering exception for digest/short-form pins, so future authors are not misled. (The `2026-06-02` spec already encodes this exception locally in its §2.2; this would lift it to the canonical doc.)

**Recommendation:** (a) or (c) — align the doc to the real convention rather than churn the harness. (b) only if a future de-bloat pass decides one-home-for-all is worth the move.

**Reactivation:** next time a new smoke-pin spec trips the same placement ambiguity (anti-n=1 already satisfied — X1/X5/X6 are 3 instances in one spec), or during any CLAUDE.md §Testing edit pass.

**Anchor:** `2026-06-02-r5-r7-test-placement-enforcement.md` §2.2 topical-cluster exception + §7 Log iter-1/2/3 entries; CLAUDE.md §Testing "Per-pin 3-edit protocol"; empirical pin locations `tests/smoke.sh:2117/2145/2303/2323`, `tests/smoke-helpers.sh:89`.

---

## Completed

См. `design/` для завершённых спеков с `status: DONE`.

- `2026-04-15-plugin-integrity-improvements.md` — 6 функциональных гапов, фикс.
- `2026-04-17-dry-developer-agents.md` — shared developer workflow reference; агенты -89 строк.
- `2026-04-17-smoke-test.md` — tests/smoke.sh, 28 автоматических проверок.
- `2026-04-17-readme-troubleshooting.md` — troubleshooting секция, 5 типовых failures.
- `2026-04-17-feature-skill-quality.md` — BLOCKED status + last_agent + /feature discard (P2 #4, #5, P3 #12).
- `2026-04-17-stop-hook-warning.md` — Stop hook warns about feature-branch work (P2 #8).
- `2026-04-17-cross-audit-severity.md` — `--severity high|medium+` flag (P3 #11).
- `2026-04-17-config-extensions.md` — codex.* overrides + autogen .ai-dev-team.yml (P3 #13, #14).
- `2026-04-17-compliance-commit-fallback.md` — SHA validation + grep fallback (P2 #9).
- `2026-04-17-feature-from-investigation.md` — --from-investigation seed bridge (P2 #7).
- `2026-04-17-research-skill.md` — /research skill, 5 modes, research-template.md (P2 #6).
- `2026-04-17-test-strength-r3.md` — R3 test-strength rule + 7 smoke assertions (P2 #17).
- `2026-04-18-agent-routing.md` — agent-routing matrix + `when_to_pick:` frontmatter + 8 smoke assertions (P2 #18).
- ~~`2026-04-18-multi-github-account.md` — `github:` config block + per-invocation `GH_TOKEN`/`GH_HOST` env prefix on 9 `gh` call sites + `gh_account_context:` audit→publish bridge + 37 smoke assertions (P2 #19).~~ ✅ **RETIRED 2026-04-27 — PR #65** (verified ZOMBIE per 2026-04-26 retrospective: 0 user repos with `default_account:`. Cut spec: `design/2026-04-27-cut-multi-gh-account.md`. Users with multi-account workflows migrate to shell-level tooling: `gh auth switch` / `direnv` / shell aliases.).
- `2026-04-17-user-input-banner.md` — high-visibility `## ⏸ AWAITING YOUR INPUT` banner convention across all skills (P2 #20).
- `2026-04-18-branch-prefix.md` — branch prefix derived from `change_type` frontmatter (feat/fix/refactor/…) instead of hardcoded `feature/` (P2 #15).
- `2026-04-18-r5-tests-in-separate-file.md` — R5 rule: tests live in dedicated files, not inline `#[cfg(test)] mod tests` in impl (P2 #16).
- `2026-04-18-r6-test-scope-user-facing-contract.md` — R6 Khorikov Classical scoping rule: core tests exercise user-facing contract via in-process harness (P2 #22, renamed R4→R6).
- `2026-04-18-khorikov-vocab-retrofit.md` — retrofit R1/R2 + §Test Quality with Khorikov 4-pillar vocabulary; shared-framework preamble (P2 #23).
- `2026-04-19-smoke-fixture-harness.md` — fixture-based self-test harness for `tests/smoke.sh` section-scoping; 19 audit iterations; +6 behavioral assertions (201→207) (P2 #24).
- `2026-04-20-per-step-agent-pretag.md` — per-step `@<agent>` pre-tagging in spec-template + SKILL.md + cross-auditor; 13 audit iterations; +5 smoke assertions (207→212) (P2 #25).
- 2026-04-25-drop-developer-middle.md — developer-middle agent dropped per investigate convergence 2026-04-25; routing collapses to Codex/Senior + Codex Fast variant.
