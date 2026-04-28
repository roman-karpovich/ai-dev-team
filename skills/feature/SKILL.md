---
name: feature
description: >
  Spec-driven feature development with KB-centric workflow.
  Supports any project — discovers KB automatically from sibling directories.
  Manages full cycle: research, spec, implement, verify.
  Use when starting new features, resuming work on existing specs,
  or checking status of in-progress features.
argument-hint: "<new | continue | status> [feature description or spec path]"
user-invocable: true
---

# Feature Development Skill

Spec-driven development using a Knowledge Base (Obsidian vault) as persistent context.
Specs live in `<kb_root>/repos/<project>/design/` so context survives across sessions.

User-input prompt presentation follows the banner convention in
`docs/user-input-banner-convention.md`. Every real decision fork in this
skill uses the generic `AWAITING YOUR INPUT` banner (or the
`APPROVAL REQUIRED` variant for the HARD GATE); status updates do not
carry the banner.

## Modes

Parse `$ARGUMENTS` to determine the mode:

| Input | Mode | Action |
|-------|------|--------|
| `new <description>` or bare non-path description | **New** | Research codebase, write spec, get approval |
| `continue [spec-path]` | **Continue** | Resume from last checkpoint in spec |
| bare path to an existing `*.md` file (not prefixed with `new`) | **Continue** | Treat as `continue <spec-path>` |
| `status` or `status --all` | **Status** | Show actionable specs (or everything with `--all`) |
| `checklist <add\|done\|fail\|start-soak\|list> …` | **Checklist** | Manage post-merge items on a SHIPPED spec |
| `verify <spec-path>` | **Verify** | Auto-resolve blockers, flip to VERIFIED if every item is done |
| `extend <description>` | **Extend** | Append a new step to the active spec's Implementation Checklist + workdoc (scope addition) |
| `new <description> --follows-up <spec-path>` | **New (follow-up)** | Like **New**, but links the new spec to a prior one via `follows_up` |
| `discard [spec-path]` | **Discard** | Delete feature branch + set spec DISCARDED (explicit; not tied to hand-off) |

---

## Workflow phases overview

```
1. Research + write spec + exec workdoc  →  user approves spec (HARD GATE)
2. Spec self-review + cross-audit (Claude + Codex)  →  fix if CRITICAL/HIGH
3. Baseline test  →  implement step-by-step with compliance checks per step
4. Verify (full test suite)
5. Code audit (cross-auditor mode:full on diff — closed gate, per-finding triage)  →  hand-off (merge / PR / keep / discard)
```

## Confirmation cadence

Once agreed to a direction, drive to completion without re-asking. See `docs/confirmation-cadence.md`.

## Session resume — KB scan

At the beginning of any development session, before doing anything else:
1. Check Claude memory for the KB path for this project
2. If found: scan `<kb>/repos/<project>/design/` for specs with status IN_PROGRESS or AUDIT_PASSED
3. If in-progress work exists: summarise it (feature name, current phase, next step) and ask whether to continue or start something new
4. If nothing in progress: ask what the user wants to work on

Do this proactively — do not wait for the user to ask.

## Phase 0: KB Discovery

KB discovery algorithm (resolving `kb_path` and `project` via `.ai-dev-team.local.yml → .ai-dev-team.yml → memory → sibling → ask`) follows `docs/kb-discovery.md` — single source of truth.

### Feature-skill extensions

Feature skill reads `codex.model` and `codex.reasoning_effort` from the resolved config and passes them through to `developer-codex` / `cross-auditor`.

---

## New: Research + Spec

### Step 1 — Research

Read both KB and codebase before writing anything:

1. Ask Librarian agent (or read directly): `<kb_path>/repos/<project>/design/` for existing specs
2. Read any relevant KB docs: domain context, related project docs, glossary
3. Explore source code in the project directory: understand architecture, existing patterns, files that will change
4. Identify: reusable patterns, files to change, dependencies, risks, what already exists
5. Read AGENTS.md, CLAUDE.md, .github/CONTRIBUTING.md, and README.md §Development/§Contributing/§Testing in the target repo if they exist. Lift any directive placement / naming / layout / branch-style rules verbatim into spec §2 Current State as a 'Repo conventions' subsection (`### 2.X Repo conventions`).

### Step 2 — Write spec and initialize execution workdoc

You (the feature skill orchestrator) write both artifacts directly.

**Spec**: create at `<kb_path>/repos/<project>/design/YYYY-MM-DD-<slug>.md`. Create the directory if it doesn't exist. Use the template from `references/spec-template.md`. Key sections:
- **Context** — why this feature exists
- **Current State** — how the system works today (reference KB pages and source files)
- **Design** — changes table, data model, API, configuration
- **Branch** — `<type>/YYYY-MM-DD-<slug>` where `<type>` is the resolved `change_type` (see §3.6 R4 and the change-type prompt below — one of `feat / fix / refactor / ci / docs / test / chore`) (or specify different base if needed)
- **Implementation Checklist** — ordered, concrete steps (each is a reviewable behavioral unit)
- **Verification** — how to test end-to-end
- **Log** — append-only decisions and progress

**Repo-convention enforcement in §5**: if §2 lists a Repo conventions subsection that constrains a checklist step's decision (test placement, file layout, branch naming, commit style, linter format, language version), the corresponding §5 Implementation Checklist step MUST specify the exact placement/value — never 'developer's call' / 'at developer's discretion' / 'as you see fit' / 'at agent discretion'. Spec-mode cross-audit (see `agents/cross-auditor.md` §spec mode) flags such ambiguity as HIGH.

YAML frontmatter:
```yaml
---
title: <feature title>
project: <project>
type: spec
status: DRAFT
branch: <type>/YYYY-MM-DD-<slug>
change_type: <type>
created: YYYY-MM-DD
tags: [spec, <project>]
---
```

**Execution workdoc**: create at `<kb_path>/repos/<project>/design/workdocs/<slug>/exec.md`. Also create `captures/` directory (it will hold test output files written during implementation).

For each checklist step, write a `planned` block in exec.md:
```yaml
## Step N: <step title from checklist>

### Planned
goal: <one sentence — the observable behavioral change>
allowed_scope: <glob for files this step may touch, e.g. src/module/**>
failing_test_cmd: <command to run before implementation — empty if no test>
expected_failure_pattern: <substring expected in failure output>
passing_test_cmd: <command to run after implementation>
expected_pass_pattern: <substring expected in passing output>
integration_probe_cmd: (optional — command to confirm feature is reachable at runtime)
expected_probe_signal: (optional)

### Observed
actual_files_touched: []
commit_shas: []
red_capture: captures/step-NN-red.txt
green_capture: captures/step-NN-green.txt
probe_capture:
notes: ""
```

Leave all `observed` fields empty — the developer fills them during implementation.

Quick facts for implementation steps:
- Each implementation step requires evidence captures (failing test → implement → passing test → compliance check)
- A step is not done until green_capture exists and matches expected_pass_pattern

**Agent pre-tag (optional).** For each step in §5, optionally tag the recommended agent inline using the `@<agent>` suffix defined in `references/spec-template.md` §5 — leave untagged if the step's nature doesn't clearly match a single routing trigger.

**Change-type prompt.** Before the Prerequisites prompt, resolve the spec's `change_type`. Infer from the user's description (case-insensitive, first match wins; evaluate in this order):

1. `fix | bug | hotfix | regression | broken` → `fix`
2. `refactor | extract | rename | reorganize | restructure` → `refactor`
3. `docs | documentation | readme` → `docs`
4. `ci | workflow | github actions | gh actions | pipeline` → `ci`
5. `test | coverage | smoke | assertion` (when the primary subject is tests) → `test`
6. `chore | bump | deps` → `chore`
7. default → `feat`

Then confirm with the user via a banner prompt:

---
## ⏸ AWAITING YOUR INPUT

Inferred change type: **<type>**. Branch will be
`<type>/YYYY-MM-DD-<slug>`. Override with one of
`feat / fix / refactor / ci / docs / test / chore`, or accept.

**Change type?**

Empty answer → accept inferred value. Any of the seven literals → use that. Anything else → re-prompt with the same banner and an "invalid value" preamble. Write the resolved value into spec frontmatter as `change_type:` and substitute into the `branch:` field (e.g. `branch: feat/2026-04-18-my-slug`). Append to spec Log: `- YYYY-MM-DD: change_type=<type> (inferred|user-override)`.

**Prerequisites prompt.** Before moving to approval, ask the user:

---
## ⏸ AWAITING YOUR INPUT

Any deploy prerequisites? One-off ops steps that must run after the merge before the feature works (migrations, worker restarts, cache reset). One per line. Empty input = none.

**What are the deploy prerequisites?**

Write the answer into the YAML block in spec section `## 6.2 Deploy & manual verification` as `deploy_prerequisites`. Each non-empty line becomes one YAML-quoted list entry. Empty input maps to `deploy_prerequisites: []`.

**Smoke check.** Then ask the user:

---
## ⏸ AWAITING YOUR INPUT

Fastest manual smoke check — command to run post-deploy to confirm the feature is alive. (Empty = no smoke check configured.)

**What command should the smoke check run?**

If the user leaves it empty, write `smoke_check: null` in `## 6.2 Deploy & manual verification` and skip the next question. If the user gives a command, write `smoke_check: {command: <verbatim command, YAML-quoted>, expected: <expected output, YAML-quoted>}` and ask:

---
## ⏸ AWAITING YOUR INPUT

Expected substring in the command output? (Empty = no explicit expectation; success is defined by exit code alone.)

**What substring should appear in the smoke-check output?**

If the user leaves the expected-output prompt empty, write `expected: ""`.

**Post-merge checklist seeding.** Before moving to approval, ask the user:

---
## ⏸ AWAITING YOUR INPUT

Any other post-merge obligations? Cross-team dependencies, blockers on other specs, soak periods. Deploy prereqs from §6.2 will be added automatically on hand-off.

**What post-merge obligations should be tracked?**

If the user names any, populate the `items:` YAML block in spec section `## 8. Post-merge checklist` following the schema in `references/spec-template.md`. If there are none, leave `items: []`. The checklist can be edited later via `/feature checklist`.

Spawn **Librarian** only if you need to update MOC indexes afterward.

### Step 3 — Get approval

Present a summary and wait for user approval before implementing.

<HARD-GATE>
Do NOT spawn any developer agent, write any code, or take any implementation action until the user has explicitly approved the spec. This applies to every feature regardless of perceived simplicity. "It looks straightforward" is not approval.
</HARD-GATE>

---
## ⏸ APPROVAL REQUIRED

The draft spec is ready for review at `<spec_path>`. No implementation, no developer spawn, no code edits happen before you approve.

- Approve → set `status: APPROVED`, continue to Step 3.5 spec review.
- Reject → return to drafting with your feedback.

**Approve to proceed?**

Set spec `status: APPROVED` after explicit user approval.

### Step 3.5 — Spec review (two passes)

After approval, immediately ask:

---
## ⏸ AWAITING YOUR INPUT

Run spec audit before implementation?

1. Yes — recommended if the spec involves external APIs, new business logic, or non-trivial data flows
2. Skip — for simple config/plumbing changes where you're confident in the spec

**Run spec audit?**

If the user chooses **Skip**: set `status: AUDIT_PASSED`, set `spec_audit_evidence: skipped` and `spec_audit_blockers: ['spec audit skipped by user']`, append to Log: `"spec audit skipped by user"`, proceed directly to Implement. (Setting AUDIT_PASSED rather than keeping APPROVED ensures continue mode does not re-enter the audit loop on resume.)

If the user chooses **Yes** (or gives no explicit answer): run both passes below.

---

Review the spec and execution workdoc before any code is written.

#### Pass 1: Self-review (orchestrator)

Before calling any agent, check both documents for basic completeness:

- No placeholder text (`{...}`, `TBD`, etc.) in spec or workdoc planned fields
- Every checklist step has a corresponding entry in exec.md with `planned.goal` and `planned.passing_test_cmd` at minimum
- `allowed_scope` is set for every step (not empty)
- No step depends on something defined in a later step
- `planned.failing_test_cmd` is either set or intentionally empty (not just forgotten — flag if the step's goal implies testable behavior)
- Spec `Verification` section describes concrete commands, not vague prose

If any check fails: fix the spec/workdoc directly (or ask the user for the missing information) before proceeding to Pass 2.

#### Pass 2: Cross-audit (dual-model)

Track `spec_audit_iteration` (start at 1, increment on each re-spawn). Track `spec_audit_fixed_ids` (list of finding IDs the user fixed — accumulate across rounds). Track `spec_audit_next_id` (integer — the next finding ID to allocate; start at 1, update to `highest_id_in_report + 1` after each round).

Spawn `cross-auditor` subagent with:
- `scope`: `<spec_path>` (the spec file)
- `workdoc_path`: `<workdoc_path>` (the execution workdoc)
- `mode`: `spec`
- `project`: `<project>`
- `audit_slug`: `<slug>-spec`
- `iteration`: `<spec_audit_iteration>`
- `working_directory`: `<cwd>`
- `previously_fixed`: `<spec_audit_fixed_ids>` (empty list on first pass)
- `next_finding_id`: `<spec_audit_next_id>` (ensures IDs don't collide across rounds when no findings doc exists)
- (omit `kb_path` — spec mode does not write to KB)

The cross-auditor returns findings inline (no KB writes in spec mode).

**If CRITICAL or HIGH findings:**
1. Present findings to user
2. Update spec/workdoc (user edits in Obsidian, or ask Claude to apply the fix)
3. Collect IDs of findings the user fixed → append to `spec_audit_fixed_ids`
4. Update `spec_audit_next_id` = highest finding ID in this round's report + 1
5. Increment `spec_audit_iteration`
5. Before re-spawn, see §3.5c Stop criteria — REOPEN findings or same-defect-class on 2+ iters trigger a comprehensive sweep AFTER `/compact` or via a fresh-context subagent; hard cap iter ≤ 5 unless an explicit §3.1c-regex Log line justifies the exception. Then re-run Pass 1 self-review and re-spawn cross-auditor with updated `iteration` and `previously_fixed`.
6. Repeat until no CRITICAL/HIGH remain
7. Set spec `status: AUDIT_PASSED`. Populate `spec_audit_evidence:` from the cross-auditor's final-iteration return signal per §3.5b READ path (spec-mode parses two adjacent final lines `evidence_class:` + `evidence_blockers:` from the inline return text). Copy `evidence_blockers:` verbatim into `spec_audit_blockers:` (parse-failure → `contract_violated` per §3.5b).

**If no CRITICAL or HIGH findings:**
> Spec review passed — the spec is saved to KB. Moving to implementation.
> 💡 Consider running `/compact` before implementation to trim conversation history.

Set spec `status: AUDIT_PASSED`. Populate `spec_audit_evidence:` from the cross-auditor's final-iteration return signal per §3.5b READ path. Copy `evidence_blockers:` verbatim into `spec_audit_blockers:` (parse-failure → `contract_violated` per §3.5b).

**Mid-flow skip**: if the user says "skip" or "proceed anyway" at any point during the audit — stop, set `status: AUDIT_PASSED`, set `spec_audit_evidence: skipped` and `spec_audit_blockers: ['spec audit skipped by user']`, append to Log: `"spec audit skipped by user"`.

### 3.5b Audit evidence

Per spec `2026-04-27-audit-evidence-enum.md`. Every audit-terminal site (spec audit AUDIT_PASSED + code-audit Log markers) records WHAT evidence backs the audit by populating two paired frontmatter fields: `*_audit_evidence:` (enum) and `*_audit_blockers:` (list of strings naming what blocked the dual-model gold standard, empty when `dual_model`).

**Enum values:**

- `dual_model` — both Claude and Codex halves of the cross-auditor returned findings (or both confirmed clean) — the gold standard.
- `single_model` — one half returned findings, the other half failed and the orchestrator proceeded under the documented fail-open rule (`agents/cross-auditor.md` Step 1 fail-open path).
- `self_fallback` — the cross-auditor agent itself could not complete (stall, timeout, MCP failure, premature merge) and the orchestrator performed manual self-verification per the iter-2 fallback rule (`feedback_iter_2_audit_fallback.md`). The cross-auditor never returns a usable signal in this case.
- `contract_violated` — the cross-auditor *ran* but its output contract is broken: (a) inline return (spec mode) missing/malformed `evidence_class:` or `evidence_blockers:` final lines; (b) any `evidence_blockers` list item fails YAML-safety scalar validation per cross-auditor's serialization rule; (c) code/full mode — the expected `<kb>/repos/<project>/security/<audit_slug>-findings.md` file is missing on disk after the agent returns. The cross-auditor never writes this value (by definition can't reliably self-diagnose); the orchestrator records it. Recovery (re-spawn, manual self-verify per `feedback_iter_2_audit_fallback.md`, or ship as-is) is a separate orchestrator decision that may further update the final evidence value.
- `skipped` — no audit was performed against findings: user clicked Skip on the spec-audit prompt, OR mid-flow "skip / proceed anyway" override, OR the code-audit zero-diff branch fired (`no auditable files in diff`).

**Reader semantics for `null` (legacy specs).** All pre-enum specs lack these fields. Readers (filters, smoke pins, analytical scripts) MUST treat `null` / missing as `legacy_unknown` — distinct from any enum value, NOT flagged as degraded, NOT compared against `dual_model` directly. The canonical degraded-flag predicate is `*_audit_evidence ∈ {single_model, self_fallback, contract_violated, skipped}`. The inverse "not equal to dual_model" form is forbidden because it would flag every legacy spec forever.

**Honesty-gate-not-approval-gate.** This subsection records evidence; the routine case introduces NO new mid-flow user banner per `feedback_ai_dev_team_repo_autonomy.md`. Future tooling (`/feature status`, smoke pins, future analysis) reads the field programmatically and surfaces degraded rows for human review out-of-band.

**`self_fallback` discipline remains user-enforced.** The iter-2 fallback memory `feedback_iter_2_audit_fallback.md` continues to define the six criteria for when manual self-verification is authorized. This subsection adds the honest record (the field) but NOT a machine-readable gate against criteria violations. The machine gate is a follow-up spec — see DRAFT `2026-04-27-self-fallback-machine-gate.md`. Recording a `self_fallback` value here means "I did manual review", NOT "the criteria were verified".

**Orchestrator READ path (handshake → spec frontmatter).** The cross-auditor transmits two sibling fields back to the orchestrator: `evidence_class:` (enum, `dual_model | single_model` only — cross-auditor never writes `self_fallback` / `contract_violated` / `skipped`) and `evidence_blockers:` (list).

- **Code/full mode (file-backed)** — production-file parser. The cross-auditor writes a findings.md with the two scalars in the leading top-of-file YAML frontmatter block (NO `### findings.md` heading anchor — that anchor only applies to smoke validation against the agent SOURCE template). The orchestrator reads from the produced findings.md as `awk '/^---$/{c++; next} c==1' <audit_slug>-findings.md | grep -E '^(evidence_class|evidence_blockers): '`. The production file's H1 is `# Audit Findings: <scope>`, not `### findings.md` — the production parser is unanchored on top-of-file YAML.
- **File-existence check (code/full mode only).** Before reading frontmatter, the orchestrator MUST check that `<kb>/repos/<project>/security/<audit_slug>-findings.md` exists on disk after the cross-auditor returns. If absent, record `*_audit_evidence: contract_violated` with blocker `'findings.md missing at <path>'` (use the resolved absolute or `<kb>`-relative path, sanitized per the Orchestrator blocker sanitization rule below) and skip the YAML extraction.
- **Spec mode (inline return)** — the cross-auditor's inline-return text MUST end with TWO adjacent literal final lines `evidence_class: <value>` and `evidence_blockers: <YAML-list>` on their own lines (no trailing prose). The orchestrator parses by reading the LAST two physical non-empty lines of the captured return text (`last_two=$(printf '%s\n' "$captured" | awk 'NF' | tail -2)`) and applying two prefix checks: the second of those two lines (the FINAL non-empty physical line of the response) MUST start with `evidence_blockers: `, and the first of the two (the immediately preceding non-empty physical line) MUST start with `evidence_class: `. If fewer than two non-empty lines exist OR either prefix check fails, the audit routes to `contract_violated` per the Contract-violation rule below. This stricter shape (last-two-physical-non-empty + prefix-check, replacing the older `grep -E … | tail -2` form) closes two failure modes the loose parser missed: (a) **forgotten-footer-with-example-echo** — agent omits the real footer but echoes documentation examples earlier in its prose, where `grep | tail -2` would lift the example text and treat the audit as clean; (b) **trailing-prose** — agent emits the real footer then appends a sentence (apology, summary), where the loose parser would still grab the right pair via `grep | tail -2` and the trailing-prose violation stays invisible. Adjacency-and-EOF enforcement is the load-bearing property both modes require.

**Contract-violation rule.** If the cross-auditor's return signal cannot be parsed (either footer line absent/malformed, OR any `evidence_blockers` list item fails YAML-safety scalar validation per cross-auditor's serialization rule: newline→space, `'`→`''`, 200-char cap, single-quoted form), OR (code/full mode only) the expected `<kb>/repos/<project>/security/<audit_slug>-findings.md` file is missing on disk after the agent returns, the orchestrator MUST record `*_audit_evidence: contract_violated` and the specific violation as a blocker (e.g. `'cross-auditor return missing evidence_class footer line'`, `'cross-auditor return malformed evidence_class footer'`, `'evidence_blockers entry failed YAML-safety validation'`, `'findings.md missing at <path>'`). Additionally, if the parsed `evidence_class` value is not exactly one of `dual_model | single_model` (the cross-auditor's binary emit allowlist — the agent never writes the orchestrator-only values, so any other token signals a buggy or regressed emitter; including empty/whitespace-only values, which pass the parser shape check but carry no signal), the orchestrator MUST also record `*_audit_evidence: contract_violated` with blocker `'cross-auditor emitted disallowed evidence_class value: <sanitized-value>'` (sanitize the offending value through the Orchestrator blocker sanitization rule below before embedding). Additionally, the orchestrator MUST validate the cross-field invariant between `evidence_class` and `evidence_blockers` per the cross-auditor emit contract (`agents/cross-auditor.md` §When to set L382-383): `evidence_class: dual_model` MUST pair with `evidence_blockers: []` (empty list); a non-empty list paired with `dual_model` routes to `*_audit_evidence: contract_violated` with blocker `'cross-auditor emitted dual_model with non-empty evidence_blockers: <sanitized-value>'`. `evidence_class: single_model` MUST pair with a non-empty `evidence_blockers` list; an empty list paired with `single_model` routes to `*_audit_evidence: contract_violated` with blocker `'cross-auditor emitted single_model with empty evidence_blockers'`. Both blocker phrasings pass through the Orchestrator blocker sanitization rule below before embedding in spec frontmatter.

The orchestrator's recovery action — re-spawn the cross-auditor, manually self-verify per `feedback_iter_2_audit_fallback.md` six criteria, or ship the unresolved label as-is — is a separate decision that MAY further update the final evidence value (re-spawn success → final `*_audit_evidence` reflects the successful retry's `evidence_class`; manual self-verify per six criteria → final `*_audit_evidence: self_fallback`). Automation of the recovery path is out of scope for this rule — see Q3 slice 2 (full reliability spec).

**Orchestrator blocker sanitization rule.** Every blocker string the orchestrator generates (file-existence-check `<path>`; `self_fallback` cause + tracking entry; explicit-Skip phrasing; Contract-violation example phrasings — including the disallowed-`evidence_class` value embedded per the X2 allowlist clause above) MUST pass through the same YAML-safety sanitizer as cross-auditor blockers (per `agents/cross-auditor.md` §YAML-safety serialization rule for blocker strings: newline→space; `'` → `''`; 200-char cap with `…` suffix when truncated; single-quoted YAML scalar form). The blocker emission path is symmetric on both sides of the handshake — without this symmetry, a path containing an apostrophe (e.g. `/Users/.../it's-a-spec/...`) emitted into the file-existence-check blocker via the `<path>` slot would corrupt the spec's YAML frontmatter and silently de-card the spec from every reader (Status mode, smoke pins, analytical scripts).

**Historical-event storage rule.** Prior `contract_violated` events that were superseded by a successful retry or manual self-verify are recorded in the spec Log ONLY (e.g. `- YYYY-MM-DD: spec audit retry — prior contract_violated event 'cross-auditor return missing evidence_class footer line' on iter-N; recovered iter-N+1`), NOT in `*_audit_blockers`. The `*_audit_blockers` list is tied to the FINAL `*_audit_evidence` value: `dual_model` keeps its `[]` invariant; `single_model` carries Codex-fail-open reasons; `contract_violated` carries the active violation phrasing; `self_fallback` carries the named cause + tracking entry; `skipped` carries the user-skip / zero-diff phrasing. Historical-event accumulation in `*_audit_blockers` is forbidden because it would erase the schema's "blockers describe what blocks the FINAL gold standard" semantics from the parent spec §3.1.

The orchestrator copies `evidence_blockers` from the handshake verbatim into `*_audit_blockers`, then prepends any orchestrator-side blockers (e.g. for `self_fallback`: the named cause + tracking entry; for zero-diff skip: `'no auditable files in diff'`; for explicit Skip: `'spec audit skipped by user'`).

### 3.5c Stop criteria

Per MISSION rule #11 (spec/code audit stop criteria) and MISSION rule #10 (orchestrator-delegation discipline) as the paired control. This subsection documents how the rules apply at orchestrator-runtime decision points after each cross-audit iteration. Applies to BOTH spec audit (§3.5 Pass 2) and code audit (§Code audit Pass 2) phases.

**Three signals direct the orchestrator to stop blind cross-auditor re-spawns and run a comprehensive sweep instead of a surgical retry:**

1. **REOPEN finding** — the cross-auditor flags a sibling at a parallel surface of a previously-fixed defect class. Run a comprehensive sweep BEFORE the next iter — do not surgically patch the named surface and re-spawn.
2. **Same-defect-class continuation on 2+ consecutive iters** — comprehensive sweep covering ALL parallel surfaces of that class. Different IDs, same defect shape, two iters in a row = stop and sweep.
3. **Hard cap iter ≤ 5** for both spec audit and code audit. Cap exceeded only with explicit Log-line justification matching the §3.1c canonical regex `^- [0-9]{4}-[0-9]{2}-[0-9]{2}: (spec|code) audit iteration > 5 justified [—-] .+$`.

**Paired control with rule #10 — context refresh is mandatory.** The comprehensive sweep on REOPEN OR same-defect-class on 2+ iters MUST be performed AFTER `/compact` (working-memory reset) OR by spawning a fresh-context subagent (developer-senior or cross-auditor) that re-reads the artifact from disk. Polluted-orchestrator surgical retries are the failure mode this case study established (see `2026-04-27-audit-evidence-enum.md`). The orchestrator records WHICH refresh path was used in the spec Log:

- `- YYYY-MM-DD: REOPEN sweep — context refreshed via /compact`
- `- YYYY-MM-DD: REOPEN sweep — context refreshed via fresh @<agent>`

**Phase split — spec audit (§3.5 Pass 2) is gating, not hard-blocking.** On cap-with-comprehensive-sweep, the orchestrator MAY move to Implement after one final sweep. Defects remaining at iter-5 are recorded in the spec Log as known-residue rather than re-iterated forever. Verification-rigor residue, if any, is caught more efficiently by the code audit on the actual implementation than by an unbounded spec audit on abstract contract prose.

**Phase split — code audit (§Code audit Pass 2) preserves the closed gate.** The per-finding `fix` / `accept` / `defer` mechanism remains the only legitimate way to clear CRITICAL/HIGH findings. Stop criteria here means "stop blind re-spawning of the cross-auditor" — when the comprehensive sweep finds no new parallel surfaces, the residue is funneled through per-finding triage:

- `accept` with rationale (deliberate risk acceptance, or false-positive call with explanation),
- `defer` with follow-up spec slug (genuine future work the merge does not block on),

— **NOT skip-to-hand-off**. The iteration cap counts cross-auditor re-spawns. Funneling residue through per-finding triage IS the legitimate exit from the audit loop; the cap protects against the polluted-orchestrator-keeps-re-spawning failure mode, NOT against the closed gate itself.

**Hard-cap escape hatch** (rule #11 §3.1c). When a spec legitimately needs > 5 iters (cross-cutting refactor with many surfaces, security-sensitive code where verification rigor IS the value, first-of-class spec introducing new design patterns), append a Log line matching the §3.1c canonical regex BEFORE iter-6 starts. Recognition is by ERE regex (NOT free-floating substring) — the regex requires BOL Log-entry prefix, phase token (`spec` or `code`), literal middle ` audit iteration > 5 justified`, mandatory space + dash (em-dash or ASCII hyphen) + space separator, and a non-empty reason tail. Empty tails fail to match.

---

## Implement

### Baseline test

Before spawning any developer, detect the base branch (`git branch -r | grep -E 'origin/(master|main)$'` — prefer `master` if both exist), ensure you are on it (or the branch specified in the spec `branch:` field), then run the **verifier** subagent:

```
project_path: <project_path>
```

- **PASS**: proceed to agent selection.
- **FAIL**: stop. Report to user: "Baseline is not clean — N test(s) failing before any new code. Resolve these first or they'll be falsely attributed to the new feature."
- **No test suite detected** (verifier detects no test config): skip this step and note it in the spec Log.

Note: verifier runs against the current checkout — make sure the base branch is checked out before calling it.

### Agent selection

Before starting implementation, ask the user which agent to use:

See `skills/feature/references/agent-routing.md` for routing triggers and the canonical Log format.

---
## ⏸ AWAITING YOUR INPUT

**Which developer should implement this?**

1. **Codex (GPT-5.5 xhigh)** ← default — saves Claude tokens, corporate subscription, use aggressively
2. **Senior (Opus)** — only when Codex falls short: highly ambiguous scope, extensive codebase exploration needed, ultra-complex cross-cutting changes

**Which agent?**

If the current checklist step in §5 carries a `@codex` or `@senior` suffix (case-insensitive; the orchestrator lowercases before matching), evaluate the tag against the routing matrix in `skills/feature/references/agent-routing.md`: the tag is honored iff the step's description matches at least one positive trigger for the tagged agent AND no anti-trigger contradicts it. On honored tag, pre-fill that agent as the banner default and log rationale using the **actual matched positive trigger** — one of `T-C1` / `T-C2` / `T-C3` for `@codex`, one of `T-S1` / `T-S2` / `T-S3` / `T-S4` for `@senior` (never `T-S0`, which is reserved for the fallback case where no positive trigger matched) — with `notes=pre-tagged by spec author` appended. Log only after the user confirms the banner pick (rationale-logging fires post-confirmation per the existing Agent-selection flow); if the user overrides the tagged default, log the final pick with its own rationale, not the tag's. On tag-trigger mismatch (tag present but positive-trigger check fails, or an anti-trigger hits), treat as untagged and emit a one-line preamble warning above the banner noting the mismatch. On malformed tag (unknown agent, wrong spacing, or any suffix form other than `@codex`/`@senior`), hard-stop with a banner asking the user to correct the checklist line before continuing — do NOT silently untag. Untagged steps → use the routing matrix triggers as today.

**Remember the choice**: once the user has picked an agent, append to the spec Log per the canonical format in `skills/feature/references/agent-routing.md` §Rationale logging. Continue mode reads the most recent `last_agent=` entry from the Log and offers that as the default on resume (the user can still override).

#### Option 1: Codex (developer-codex agent)

Spawn `developer-codex` subagent with:
- `spec_path`: path to the spec file
- `workdoc_path`: `<kb_path>/repos/<project>/design/workdocs/<slug>/exec.md`
- `project_path`: path to the source repo
- `task`: steps to implement (works best when spec has explicit file paths and clear requirements)

#### Option 2: Senior (developer-senior agent)

Spawn `developer-senior` subagent with:
- `spec_path`: path to the spec file
- `workdoc_path`: `<kb_path>/repos/<project>/design/workdocs/<slug>/exec.md`
- `project_path`: path to the source repo
- `task`: "full spec" or specific steps

### Git conventions

Feature skill follows the plugin's canonical Git Workflow — see `skills/feature/references/developer-workflow.md` §Git Workflow. Key points relevant at hand-off: small logical commits per step, no `Co-authored-by`, no pushing (user owns push/PR). The canonical section includes the load-bearing pre-commit branch assertion and post-merge bug flow.

---

## Verify

After implementation is complete, spawn the **verifier** subagent:

```
project_path: <project_path>
spec_path: <spec_path>
scope: <list of changed files from spec checklist>
```

- **PASS**: All results are captured in the workdoc.
  Verify passed. Moving to code audit. Do **not** set a terminal status (`VERIFIED` or `SHIPPED`) yet — wait until the user selects a preserving option (merge, push, or keep). §3.4a applies the correct terminal (`VERIFIED` or `SHIPPED`) after hand-off. Setting a terminal before hand-off means a discard would leave the spec permanently marked terminal with no surviving branch.
- **FAIL**: present failures to user. Analyze the verifier report to identify which checklist step(s) are responsible. Spawn the developer with `rework step N: fix test failure: <relevant excerpt>` for each affected step. Re-verify after fix.
- **NO_TESTS**: no test suite detected. If step-level captures (green_capture + compliance PASS) exist for all steps, treat as PASS. If any step lacks captures, ask the user for manual sign-off (see banner below). On sign-off, proceed to code audit. Log the absence of a project-level test suite.

---
## ⏸ AWAITING YOUR INPUT

No test suite was detected and one or more steps lack green captures. Manual sign-off is required before code audit.

**Do you confirm implementation is complete?**

---

## Code audit

After verify passes, run a mandatory code audit prior to hand-off. This is
a closed gate: every CRITICAL or HIGH finding must be triaged
per-finding as `fix`, `accept`, or `defer` before the flow can move on.
The only automatic bypass is the zero-diff case where the diff filter
finds no auditable files in diff.

#### Pass 1: Diff filter (orchestrator self-check)

Before calling any agent, resolve the base branch with:
```bash
base=$(git branch -r | grep -E 'origin/(master|main)$' | head -1 | sed 's|.*origin/||')
```

Then compute the candidate audit scope with:
```bash
git diff --name-only --diff-filter=AMRCT "origin/${base}...HEAD"
```

Use the post-filtered destination paths as the audit scope. Exclude
binary files and submodule gitlinks after the `git diff` call. If the
filtered result contains no auditable paths, append this Log marker and
write the matching spec frontmatter, then proceed directly to hand-off.

Log marker base form (anchor):

`- YYYY-MM-DD: code audit: no auditable files in diff; skipping`

Log marker extended template (per §3.5b — append `evidence=<value>; blockers=[...]` literals to the base form). For zero-diff this is always `evidence=skipped; blockers=['no auditable files in diff']`:

> `- YYYY-MM-DD: code audit: no auditable files in diff; skipping; evidence=skipped; blockers=['no auditable files in diff']`

Spec frontmatter write (immediately adjacent to the marker append): set `code_audit_evidence: skipped` and `code_audit_blockers: ['no auditable files in diff']`. Per §3.5b: zero-diff is folded into `skipped` because no audit ran against findings.

#### Pass 2: Cross-audit (dual-model)
Track `code_audit_iteration` (start at 1). Track
`code_audit_fixed_ids` and `code_audit_accepted_ids` (both empty on the
first round). For `next_finding_id`, do not keep a separate variable in
feature-skill state: on re-spawn, the cross-auditor auto-derives it
from the highest existing `X<N>` ID in the KB findings file.

Spawn `cross-auditor` with mode: full on the diff (dual-model). Parameters:
- `scope`: newline-joined auditable paths from Pass 1
- `mode`: `full`
- `audit_slug`: `<slug>-code`
- `iteration`: `<code_audit_iteration>`
- `previously_fixed`: `<code_audit_fixed_ids>`
- `accepted_ids`: `<code_audit_accepted_ids>`
- `kb_path`: `<kb_path>`
- `project`: `<project>`
- `working_directory`: `<cwd>`
- `base_branch`: `<base>`

The cross-auditor persists code findings in KB. After the cross-auditor
returns findings for round `N`, write this Log marker immediately. Do
not write it before the spawn call:

`- YYYY-MM-DD: code audit iteration=N; fixed_ids=[...]; accepted_ids=[...]`

The first round uses the same marker schema as every later round:
`fixed_ids=[]` and `accepted_ids=[]`. Post-return timing narrows the
crash window: the cross-auditor writes `<slug>-code-findings.md` and
`<slug>-code-workdoc-iterN.md` before it returns, so a crash between
the cross-auditor returning and the Log marker being written leaves
those KB artifacts on disk but no `iteration=N` Log line. Resume takes
the no-entry fresh-run branch and re-runs iteration N (so N=1 the
first time around); because the cross-auditor's persistence is
idempotent on `audit_slug` + `iteration` (findings merge by id,
per-iteration workdoc is rewritten in place), replaying the same
iteration converges to the same or a newer finding set. The guarantee
is **no findings lost**, not **no redone work** — a crashed iteration
may be replayed.

**If CRITICAL or HIGH findings with status `OPEN` or `REOPENED`
exist:**
1. Present the findings to the user grouped by severity.
2. Stop for per-finding triage. The user must choose an action for each
   finding; there is no phase-level bypass here.

---
## ⏸ AWAITING YOUR INPUT

Code audit found CRITICAL or HIGH findings. Reply with one action per
finding using `X<id> -> fix`, `X<id> -> accept: <reason>`, or
`X<id> -> defer: <reason>; spec=<follow-up-slug>`.

Use `accept` for deliberate risk acceptance and for false positives with
the rationale `false positive — both auditors erred: <explanation>`.

**Which action should be recorded for each finding?**

3. **Collect decisions.** For each finding, record the user's chosen
   action in memory and update the finding's status in the findings
   file at `<kb>/repos/<project>/<slug>-code-findings.md`. A single
   round may mix `fix`, `accept`, and `defer` across different IDs.
   **Do not spawn any developer yet — collection is pure bookkeeping
   before the checkpoint in step 4.**
   - `fix` -> `OPEN|REOPENED -> FIXED`. Record the finding as `FIXED`
     and add its id to `pending_fixed`. Developer spawn happens in
     step 5 (dispatch), after the checkpoint is on disk.
   - `accept` -> `OPEN|REOPENED -> ACCEPTED`. Require a reason note.
     Add the id to `pending_accepted`.
   - `defer` -> `OPEN|REOPENED -> DEFERRED`. Require a reason note
     plus a follow-up spec slug. Add the id to `pending_deferred`.
4. **Checkpoint.** After every finding in the round has a recorded
   action, append the crash-safe checkpoint marker **before any
   developer work starts**:

`- YYYY-MM-DD: code audit decisions recorded; iteration=N; pending_fixed=[...]; pending_accepted=[...]; pending_deferred=[...]`

   Treat `pending_accepted` and `pending_deferred` as the carry-forward
   suppression set for the next round. Both sets feed
   `code_audit_accepted_ids` on re-spawn. With this marker on disk,
   a crash between triage and developer work resumes cleanly — the
   decisions-recorded routing branch picks up from dispatch.

5. **Dispatch fix workers.** For each finding in `pending_fixed`,
   sequentially spawn the developer using the most recent
   `last_agent=` from the spec Log as the default (the user may
   override), with:
   `task: "rework: fix code-audit finding X<id> in <file>:<line> — <excerpt>. Suggested fix: <fix_suggestion>."`
   plus `spec_path`, `workdoc_path`, and `project_path`. Wait for each
   developer to confirm its commit before dispatching the next id. The
   finding's status stays `FIXED` (pre-verification) after the
   developer returns; re-audit in step 7 promotes `FIXED → VERIFIED`
   or reopens the finding.
6. **Re-run the `verifier` subagent** once every fix developer has
   returned.
   - `PASS`: continue to the next audit round.
   - `FAIL`: use the Verify FAIL rework loop, then re-run `verifier`.
     Once it returns `PASS`, continue to the next audit round.
   - `NO_TESTS`: use the Verify NO_TESTS manual sign-off rules, then
     continue.
7. Re-spawn `cross-auditor` with `iteration=N+1`,
   `previously_fixed=pending_fixed`, and
   `accepted_ids=(pending_accepted ∪ pending_deferred)`.
8. After the cross-auditor returns, append:
`- YYYY-MM-DD: code audit iteration=N+1; fixed_ids=[...]; accepted_ids=[...]`

9. Repeat the loop until no CRITICAL or HIGH findings remain in `OPEN`
   or `REOPENED`. `FIXED` findings count as clean only after a later
   audit round verifies them. Before re-spawn, see §3.5c Stop criteria
   — REOPEN findings or same-defect-class on 2+ iters trigger a
   comprehensive sweep (paired control with rule #10: AFTER `/compact`
   or via a fresh-context subagent); hard cap iter ≤ 5 (counts
   cross-auditor re-spawns) unless an explicit §3.1c-regex Log line
   justifies the exception; residue is funneled through per-finding
   `accept` / `defer` triage, NOT skip-to-hand-off.

**If there are no CRITICAL or HIGH findings, or all such findings have
been resolved:**
- Append the Log marker (extended template — `evidence=<value>; blockers=[...]`):
`- YYYY-MM-DD: code audit passed; iteration=N; verified=[...], accepted=[...], deferred=[...]; evidence=<value>; blockers=[...]`
- Spec frontmatter write (immediately adjacent to the marker append): set `code_audit_evidence:` from the cross-auditor's final-iteration return signal per §3.5b READ path (code/full mode parses both `evidence_class:` and `evidence_blockers:` from the leading top-of-file YAML frontmatter of the produced `<slug>-code-findings.md`). Copy `evidence_blockers:` verbatim into `code_audit_blockers:` (parse-failure → `contract_violated` per §3.5b).
- Completion here means no finding remains `OPEN` or `REOPENED`.
- `💡 Consider running `/compact` before the hand-off step.`
- Move to hand-off.

---

## Hand-off

After the code audit phase completes (either a `code audit passed` marker
or the zero-diff `code audit: no auditable files in diff; skipping`
marker has been appended to the Log), run a two-phase hand-off seed
before showing the 4-option menu. This is per-item reconciliation:
re-read §6.2 on every hand-off; only `deploy_prerequisites` participate
in seeding. `smoke_check` is never seeded into §8.

**Phase 1 — compute delta (before the 4-option menu, in memory only)**

1. Read §6.2 `deploy_prerequisites` via `§6.2 handling`. If the list is
   empty or §6.2 is absent, stage no §8 items and no seed Log entry.
2. Build the set of normalized descriptions already present in §8,
   regardless of item status or `source:` tag. `done`, `failed`, and
   `pending` all count for dedup.
3. For each prereq in order, compute its normalized form. If it already
   exists in the §8 set, skip it. Otherwise allocate the next id as
   `max(existing §8 id, 0) + 1 + staged_count`, and stage:
   ```yaml
   - id: <n>
     type: action
     description: <verbatim prereq string>
     owner: user
     source: §6.2:deploy_prerequisites
     status: pending
     notes: null
     resolved_at: null
   ```
4. Add each newly staged normalized description to the working set so
   in-batch duplicates are deduped too.
5. If `N = len(staged_items)` is greater than zero, stage the Log entry
   `- YYYY-MM-DD: auto-seeded N deploy prerequisites from §6.2 to §8`.
6. If §6.2 is malformed, emit the warning from `§6.2 handling`, stage no §8
   items, and instead stage the malformed Log entry
   `- YYYY-MM-DD: hand-off: §6.2 block malformed — seeding skipped, manual review required`.

After phase 1, show the commit list and present exactly these 4 options:

```
git log --oneline <base>..<branch>
```

---
## ⏸ AWAITING YOUR INPUT

Implementation complete. What would you like to do?

1. Merge into `<base-branch>` locally
2. Push feature branch (I'll merge to staging and open a PR myself)
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

**Which option?**

> Note: merging into `staging` / `testnet` / `pre-prod` for testing is a separate manual step the user handles. The plugin only merges into the base branch (`master` or `main`).

### §3.4a Post-handoff status transition

Phase 2 applies only after a preserving option succeeds. Set frontmatter
`shipped_at: YYYY-MM-DD` (today), then decide status via `§3.4a`:

- Malformed §6.2 → force `status: SHIPPED`, append the staged malformed Log
  line, and leave manual review required.
- Else if post-phase-2 §8 has any `pending` or `failed` item →
  `status: SHIPPED`.
- Else → `status: VERIFIED`.

`DONE` remains accepted as a legacy synonym of `VERIFIED` when reading older specs, but new transitions must write `VERIFIED`.

---

**Option 1 — Merge into base branch locally:**
```bash
git checkout <base-branch> && git pull && git merge <branch>
```
Run verifier once more on the merged result. If green, apply phase 2:
append staged §8 items, append the staged Log line if any, set `shipped_at`,
and decide status per `§3.4a`. **Do not delete the feature branch** — leave
the branch reference in place (useful for reflection and quick rollback).

**Option 2 — Push feature branch:**
```bash
git push -u origin <branch>
```
Report the branch name. After a clean push, apply phase 2: append staged §8
items, append the staged Log line if any, set `shipped_at`, and decide
status per `§3.4a`.

**Option 3 — Keep as-is:** Do nothing externally. Report the branch name.
Apply phase 2 unconditionally: append staged §8 items, append the staged Log
line if any, set `shipped_at`, and decide status per `§3.4a`.

**Option 4 — Discard:** discard the in-memory delta and delegate to the
Discard mode below (same flow as `/feature discard <spec-path>`). Any
failure path before a preserving option succeeds also discards the staged
delta with no spec mutation.

---

## Continue mode

/feature continue resumes from the last incomplete step — no context recovery needed

When resuming (`/feature continue` or `/feature <spec-path>`):

1. Run KB discovery (Phase 0)
2. Read the spec file. Check the `status` field in frontmatter:
   - `DRAFT` → Spec not yet approved. Present it to the user and ask for approval. Resume from Step 3 (Get approval).
   - `APPROVED` → Resume from Step 3.5 (spec self-review → cross-audit).
   - `AUDIT_PASSED` → Resume from Implement (baseline test → agent selection → implementation).
   - `IN_PROGRESS` → Find the first unchecked `- [ ]` step. Resume from there. Ask which agent to use. If no unchecked step exists (all `[x]`): implementation is complete — resume flow is Verify → Code audit → Hand-off. Code-audit entry depends on the most recent code-audit Log marker. Four marker kinds plus one no-entry routing branch — five resume paths total (`code audit passed`, `code audit: no auditable files in diff; skipping`, `code audit decisions recorded`, `code audit iteration=N`, plus the no-entry fresh-run branch). Route using the table below (read Log markers chronologically; use the most recent `code audit …` line):

     | Log state (most recent code-audit marker) | Routing decision |
     |---|---|
     | `code audit passed` | Skip straight to hand-off. Code audit already complete. |
     | `code audit: no auditable files in diff; skipping` | Skip to hand-off — deterministic empty-diff skip already applied. |
     | `code audit decisions recorded; iteration=N; pending_*` | Re-run the verifier, then re-spawn `cross-auditor` with `iteration=N+1`, `previously_fixed=pending_fixed`, and `accepted_ids=(pending_accepted ∪ pending_deferred)`. |
     | `code audit iteration=N` (without a later `decisions recorded` or `passed` marker) | Round N findings were returned but triage is pending — **do not** re-spawn the cross-auditor. Re-read the findings file at `<kb>/repos/<project>/<slug>-code-findings.md`, collect the findings whose status is `OPEN` or `REOPENED`, re-present them to the user, and resume the §Code audit triage loop from step 1 with those findings. |
     | No code-audit Log entry at all | Fresh code-audit run: re-run the verifier first to confirm the baseline is still green (defensive), then spawn `iteration=1` with `previously_fixed=[]` and `accepted_ids=[]`. |

     Malformed or truncated trailing code-audit Log lines are ignored; fall back to the last complete recognized marker above. If the only code-audit entry is unrecognized, treat it as no code-audit Log entry and take the fresh-run branch.
   - `BLOCKED` → Report the unblock condition from the most recent `BLOCKED — waiting on ...` Log entry and ask the banner below. If yes, revert status to the prior state (IN_PROGRESS or AUDIT_PASSED, whichever the Log indicates) and resume. If no, stop.

---
## ⏸ AWAITING YOUR INPUT

Spec is BLOCKED on `<condition from the most recent Log entry>`.

- Yes → resume work from the prior state.
- No → stop.

**Is the unblock condition now satisfied?**
   - `SHIPPED` → Feature is merged but post-merge checklist has open items. Run auto-resolve for `depends_on` blockers (see Verify mode), then, before rendering pending items, apply this Quick-check decision tree:
     1. Parse §6.2 via the parsing contract in `§6.2 handling` and read `smoke_check`. If `smoke_check` is null or missing, skip the banner and render pending items as usual. If §6.2 is malformed, also skip the banner and continue to pending-items render.
     2. Read §6.2 `deploy_prerequisites` and build the set of unresolved §8 items. Status is `pending` OR `failed`; both mean the operational work is not complete, and only `done` items drop out of the gate. For each prereq, compute its normalized form and compare it against each unresolved §8 item's normalized description, regardless of `source:` tag. If any normalized §6.2 prereq matches any unresolved §8 item's normalized description, render the deferred banner and skip the command:

        ```
        ⚡ Quick check: complete deploy prerequisites below first.
        ```

        The status-rule asymmetry with §3.4 is intentional and load-bearing: `failed` is still unresolved because the next action is to fix and retry, and filtering by `source:` alone is wrong because user-added §8 items without that tag still represent unresolved ops work.
     3. Otherwise render the live banner:

        ```
        ⚡ Quick check (from spec §6.2):
            <command>
            Expected: <expected>
        ```

        If `smoke_check.expected` is an empty string, omit the `Expected:` line entirely.
     4. Then show the checklist: open items grouped by type with owner and what's pending. Offer the user the obvious next move based on what is open — mark an action done, start a soak, run `/feature verify`, etc. Do not re-enter the implement loop.
   - `VERIFIED` (or legacy `DONE`) → Feature complete and observed. Report completion status and stop.
   - `DISCARDED` → Feature was discarded. Report this and stop.
3. Report current state: spec name, status, completed steps count, next step, any blockers from the Log section
4. Ask which agent to use for remaining work (only if resuming implementation). If the Log contains a `last_agent=...` entry, present it as the default in the banner below.

**Legacy `last_agent=middle` normalisation (Log default).** If the most recent Log `last_agent=` value is `middle` (a stale value from before the Middle developer agent was retired on 2026-04-25 — including the case where it is the only `last_agent=` entry), normalise the banner default to `codex` (the matrix default) and prefix the banner with this preamble line:

> Note: spec Log says `last_agent=middle`, but the Middle developer agent was retired on 2026-04-25; defaulting to `codex`. Pick a different agent if appropriate.

Pressing Enter then accepts `codex`, not `middle`. Older Log entries are ignored if a more recent `codex`/`senior` entry exists — Continue mode evaluates only the most recent `last_agent=` line. The normalisation does not mutate the Log; the legacy entry stays for audit history.

**Step-tag handling on resume (separate path — DO NOT conflate with the rule above).** If the next unchecked step in §5 carries an `@middle` tag (a stale tag from before the agent was retired), this is a tag-acceptance case, not a default-normalisation case. It hits the malformed-tag rule in `skills/feature/SKILL.md` Per-step pre-tag handling (the §"Per-step agent pre-tag" tag-acceptance narrative in this same SKILL.md) and **hard-stops** with the standard malformed-tag banner asking the user to correct the checklist line. It does NOT silently normalise. Distinct paths: Log default normalises silently with a preamble; step-tag hard-stops and demands a correction.

---
## ⏸ AWAITING YOUR INPUT

Resuming implementation. Pick the developer for the remaining steps. The most recent `last_agent=<codex|senior>; rationale=<T-X#>` entry in the spec Log is offered as the default — press Enter to accept it, or name a different agent. (If the first unchecked step carries an `@<agent>` tag in §5 and the tag would be honored by the §3.4 acceptance rule — positive trigger matches AND no anti-trigger contradicts — that tag overrides the spec-level `last_agent=` default for this specific step: Continue mode presents the tagged agent as the banner default, not the Log value. A tag that §3.4 would reject is treated as untagged on resume too: Continue mode falls back to the `last_agent=` Log value and emits the same mismatch warning above the banner. A malformed tag hard-stops on resume just as on fresh implement, per §3.3 malformed-tag handling.)

**Which developer (default is the `last_agent` from Log)?**

---

## Discard mode

Explicit discard outside hand-off. Use when the user decides mid-implementation (or on resume) to throw the feature away.

1. Run KB discovery (Phase 0).
2. Resolve the spec from `spec-path`. If no argument, prompt the user with the banner below and a list of IN_PROGRESS / AUDIT_PASSED / BLOCKED specs.

---
## ⏸ AWAITING YOUR INPUT

No spec-path was supplied to `/feature discard`. Pick one of the active specs below to discard, or reply `cancel` to abort.

`<numbered list of IN_PROGRESS / AUDIT_PASSED / BLOCKED specs>`

**Which spec should be discarded?**

3. Refuse if `status: VERIFIED` (or legacy `DONE`) — spec is closed. Tell the user: "Spec already verified; to undo, revert the merge commit(s) via git."
4. Refuse if `status: SHIPPED` — feature merged with an open post-merge checklist. Tell the user: "Spec already shipped. Use `/feature checklist` to manage open items, or revert the merge commit(s) if you need to roll back."
5. Refuse if `status: DISCARDED` — already gone.
6. Show the commit list and branch name, then ask for typed confirmation via the banner below.

```
git log --oneline <base>..<branch>
```

---
## ⏸ AWAITING YOUR INPUT

This will permanently delete branch `<branch>` and all commits listed above. There is no undo.

**Type the word `discard` to confirm — any other reply aborts. Confirm?**

7. On confirmation: `git checkout <base-branch> && git branch -D <branch>` (use `-D` — force, since the branch likely isn't merged into base). Set `status: DISCARDED`, append Log: `- YYYY-MM-DD: feature discarded by user`.
8. On any other answer: abort, leave state untouched.

---

## Status mode

1. Run KB discovery (Phase 0)
2. Find all specs: `<kb_path>/repos/*/design/YYYY-MM-DD-*.md`
3. Read status, implementation checklist, and post-merge checklist (section 8) from each
4. For every `SHIPPED` spec: run the auto-resolve pass (see Verify mode) so blockers pointing at now-verified specs collapse before we render
5. Filter: by default, hide `VERIFIED` (or legacy `DONE`), `DISCARDED`, and `BLOCKED` (they are not actionable now). Always show `SHIPPED`. If the argument is `status --all`, show every spec regardless of status.
6. Group the visible specs into named sections:

```
### Active
| Spec | Project | Status | Progress | Branch | Audit |
|------|---------|--------|----------|--------|-------|
| ... | ... | IN_PROGRESS | 3/7 steps | <type>/... | dual / dual |
| ... | ... | AUDIT_PASSED | 0/5 steps | <type>/... | ⚠ skipped / — |
| ... | ... | AUDIT_PASSED | 0/5 steps | <type>/... | ⚠ contract_violated / — |

### Shipped — awaiting your action
(SHIPPED with at least one pending `action` item, or any `failed` item.)

| Spec | Project | Open item | Since |
|------|---------|-----------|-------|
| ... | ... | action: Deploy v1.2 to mainnet | 2026-04-17 |

### Shipped — blocked on others
(SHIPPED where the only pending items are `blocker`s — manual or depends_on still unresolved.)

| Spec | Project | Blocked on |
|------|---------|------------|
| ... | ... | frontend-team: UI ships · depends_on: design/2026-04-20-ui.md |

### Shipped — soaking
(SHIPPED where the only pending items are `soak`s.)

| Spec | Project | Soak | Started | Remaining |
|------|---------|------|---------|-----------|
| ... | ... | 7 days stable in prod | 2026-04-18 | 5 days |
```

**Audit column rendering (per §3.5b):** the `Audit` column on the `### Active` table renders `<spec_audit_evidence> / <code_audit_evidence>` from the spec frontmatter. Render rules:

- `null` (legacy_unknown — pre-enum spec) → render `—` (em-dash). Do NOT flag.
- `dual_model` → render `dual`. Do NOT flag.
- Any of `single_model`, `self_fallback`, `contract_violated`, `skipped` → prepend a `⚠ ` warning glyph. The canonical degraded-flag predicate is `*_audit_evidence ∈ {single_model, self_fallback, contract_violated, skipped}` — apply this independently to `spec_audit_evidence` and to `code_audit_evidence`. Both fields use the same predicate.

Continue mode is unchanged — it routes a single resolved spec, not a row table, so there's nothing to flag there.

Omit any section that has no rows. If a SHIPPED spec has mixed pending types, place it in the most-actionable section (action → blocked → soaking, in that priority).

To move a spec to `BLOCKED` during development, append `- YYYY-MM-DD: BLOCKED — waiting on <condition>` to the spec Log and flip `status: BLOCKED`. Continue mode reads the most recent such Log entry and asks whether the condition is satisfied on resume. (Do not confuse this with a `blocker` *item* in the post-merge checklist — those belong to SHIPPED specs that are already merged.)

---

## Checklist mode

Manage the post-merge checklist of a `SHIPPED` spec. All actions mutate the
YAML block under `## 8. Post-merge checklist` in the spec file. All actions
also append a single line to the spec Log describing the change.

### `checklist add <spec-path> <type> "<desc>" [options]`

Append a new item. `<type>` ∈ `{action, blocker, soak}`. Allocate the next
integer `id` (max existing id + 1, or 1). Defaults: `status: pending`,
`owner: user`, `notes: null`, `resolved_at: null`.

Type-specific options:
- `action`: none required.
- `blocker`: `--owner=<team>` (defaults to `user`), `--depends-on=<path>` where
  path is relative to `<kb_path>/repos/<project>/` (e.g.
  `design/2026-04-20-ui.md`). If the path escapes the project or is cross-KB,
  leave `depends_on: null` — the item becomes manual-only.
- `soak`: `--duration-days=<N>` required; `started_at` stays `null` until
  `start-soak` is called.

Works even when spec is in `IN_PROGRESS` — items can be anticipated during
development. Refuses to add items to `VERIFIED` (or legacy `DONE`) / `DISCARDED` specs.

### `checklist done <spec-path> <n> [--note="..."]`

Set item `n` to `status: done`, `resolved_at: <today>`. Record the optional
note. Refuses if the item is already `done` / `failed`. Refuses for soak items
whose `started_at` is still `null` (start the soak first, or the entry is
pointless).

### `checklist fail <spec-path> <n> --note="..."`

Set item `n` to `status: failed`, `resolved_at: <today>`. The `--note` is
**required** — the note is the record of what went wrong. A `failed` item
blocks `/feature verify`; resolve it by (a) flipping back to `done` with a
justifying note after the underlying issue is handled, or (b) opening a
follow-up spec via `/feature new` and leaving the item failed while the
follow-up tracks the remediation.

### `checklist start-soak <spec-path> <n>`

Set `started_at: <today>` on a `soak` item. Refuses if the item is not type
`soak` or if `started_at` is already set.

### `checklist list [spec-path]`

Render the checklist for a single spec (spec-path given) or for every
`SHIPPED` spec in the KB (no argument). Group output by project and by item
status. This is what `/feature status` calls internally for the shipped
groups.

### Auto-resolve pass

Whenever any checklist command runs, and at the start of `/feature status`
and `/feature verify`, walk the spec's `blocker` items. For each item with
`status: pending` and a non-null `depends_on`:

1. Resolve the path to `<kb_path>/repos/<project>/<depends_on>`. If it does
   not exist: skip (manual-only) and note once.
2. Read that spec's frontmatter `status`. If `VERIFIED` (or legacy `DONE`):
   flip this item to `status: done`, `resolved_at: <today>`, append a Log
   line: `- YYYY-MM-DD: auto-resolved blocker #<id> — depends_on <path> is VERIFIED`.
3. Otherwise: leave pending.

Auto-resolve never reaches outside the project's own KB — cross-project
dependencies stay pending until the user flips them manually.

---

### §6.2 handling

Use this parsing contract everywhere §6.2 is read (hand-off seeder,
Continue-mode SHIPPED renderer, Verify mode) so behavior stays identical.

**Pre-parse normalization**
- Strip a leading UTF-8 BOM if present.
- Normalize CRLF and bare CR line endings to LF.
- Match fence info strings case-insensitively; accept `yml` as a synonym for
  `yaml`.
- Treat any tab-indented fenced content line as a parse failure; tabs are
  invalid YAML indentation here.
- If multiple `## 6.2 Deploy & manual verification` headings exist, the
  first one wins and later duplicates are ignored.

**Block discovery**
- Locate `## 6.2 Deploy & manual verification`.
- Within the region from that heading to the next H2 (or EOF), take the
  first fenced code block whose info string is `yaml`, `yml`, or empty
  (case-insensitive). Ignore prose outside the block.

**Keys and types**
- `deploy_prerequisites` MUST be a YAML sequence of scalar strings. Any other
  type is invalid.
- `smoke_check` MUST be null or a mapping with exactly `command` and
  `expected`, both scalar strings. Any other shape is invalid. These
  spellings all resolve to null case-insensitively: key absent, empty value,
  `null`, `Null`, `NULL`, `~`, `empty`, `absent`.
- Unknown top-level keys are ignored for forward-compat.

**Canonical empty cases**
- `deploy_prerequisites: []` means the seed pass is a no-op.
- `smoke_check: null` means the Continue-mode Quick-check banner is
  suppressed.
- If §6.2 is entirely missing, treat it as both empty cases above.

**Failure handling**
- Malformed §6.2 means no fenced block, unparseable YAML, tab-indented
  content, or invalid typing. Emit:
  `⚠️ §6.2 block is malformed in <spec-path>; skipping deploy-recommendations actions. Fix the YAML or remove §6.2.`
- Do not crash and do not mutate §8.
- Hand-off seeder: force `status: SHIPPED`, and append to Log:
  `- YYYY-MM-DD: hand-off: §6.2 block malformed — seeding skipped, manual review required`
- Continue-SHIPPED renderer: suppress the Quick-check banner and continue to
  pending-items render.
- Verify mode: before auto-resolve, refuse with
  `Verification refused: §6.2 block is malformed. Fix the YAML or remove §6.2, then re-run.`
  Do not run auto-resolve, do not tally, leave status `SHIPPED`, and append
  no Log entry.

**String normalization**
- Trim leading and trailing whitespace.
- Collapse runs of internal whitespace to a single space.
- Lowercase.
- Strip a trailing period or semicolon.

Comparison uses the normalized form. Storage keeps the original text.

---

## Verify mode

`/feature verify <spec-path>` — attempt to close the post-merge cycle.

1. Read spec frontmatter `status`. Accept only `SHIPPED`; refuse otherwise.
2. Before auto-resolve, read §6.2 via the parsing contract in `§6.2 handling`.
   If §6.2 is malformed, emit the warning, refuse verification with
   `Verification refused: §6.2 block is malformed. Fix the YAML or remove §6.2, then re-run.`
   Do not run auto-resolve, do not tally items, leave status `SHIPPED`
   unchanged, append no Log entry, and make no §8 mutation.
3. Run the auto-resolve pass (see above) so recent upstream verifications
   propagate before the check.
4. Tally items:
   - All `status: done` → flip spec `status: VERIFIED`, append Log
     `- YYYY-MM-DD: VERIFIED — all post-merge items closed`. Report success.
   - Any `failed` → refuse. Report each failed item with its note; tell the
     user to resolve via `checklist done <n> --note=...` or to open a
     follow-up spec.
   - Any `pending` → refuse. Report each pending item with what is
     outstanding (action description, blocker target, soak remaining days).

Verify does not advance soak timers automatically — if a soak's
`started_at + duration_days` has passed but the item is still `pending`, it
is treated as pending. The user runs `checklist done <n>` once they are
satisfied with the soak result (nothing blew up).

---

## Scope addition mid-flow

When the orchestrator is working inside a spec and the user introduces a new requirement that was not in the approved scope ("also need X", "нужно ещё Y", "забыли добавить Z", "ещё одна доработка", "one more thing", "by the way we should also…"), do **not** silently absorb it. Detect the intent and prompt a single fork.

**Intent phrases** (not exhaustive — the orchestrator should use judgement):
- "also need / also add / additionally / on top of that / one more thing / by the way / while we're at it / forgot to mention"
- "нужно ещё / также / кстати / забыли про / ещё одна доработка / дополнительно"

**Decision by context of the active spec:**

1. **Spec is `DRAFT` / `APPROVED` / `AUDIT_PASSED` / `IN_PROGRESS`** — ask exactly the banner below.

---
## ⏸ AWAITING YOUR INPUT

Scope addition detected. The current spec is still in flight.

- **Extend** → new step in the Implementation Checklist + matching `planned` block in the exec workdoc; spec stays in its current state. Runs `/feature extend <description>`.
- **Split** → separate follow-up spec linked via `follows_up`. Runs `/feature new <description> --follows-up <active-spec-path>`.

**Extend or split?**

2. **Spec is `SHIPPED`** — ask the banner below.

---
## ⏸ AWAITING YOUR INPUT

The spec is already merged. Do not re-open it for new implementation work. Two options:

- (a) post-merge action item (only if this is a manual step, not new code) — adds via `/feature checklist add <spec> action "<desc>"`.
- (b) new follow-up spec linked via `follows_up`.

**Which option — (a) or (b)?**

3. **Spec is `VERIFIED` (or legacy `DONE`)** — ask the banner below.

---
## ⏸ AWAITING YOUR INPUT

The spec is already verified and closed. A new follow-up spec (linked via `follows_up`) is the only option — VERIFIED never silently reverts to SHIPPED.

**Create the follow-up spec now?**

4. **No active spec / scope unclear** — fall through to the normal `/feature new` or `/feature continue` prompts from the trigger map. Do not invent an implicit extension.

Whichever option is chosen, append one Log line to the source spec documenting the decision ("scope extended — added step N: <desc>" / "follow-up spec created at <path>" / "post-merge action item N added: <desc>"). Silent scope creep is forbidden.

---

## Extend mode

`/feature extend <description>` — append a new step to a spec's Implementation Checklist and create the matching workdoc entry.

1. Resolve the target spec. If `$ARGUMENTS` contains a spec-path, use that; otherwise use the spec currently under discussion (ask if ambiguous).
2. Refuse on `SHIPPED` / `VERIFIED` (or legacy `DONE`) / `DISCARDED` — follow-up specs and post-merge action items are the right tools there (see *Scope addition mid-flow*).
3. If the spec is `DRAFT` / `APPROVED`, add the step via a normal spec edit in section `## 5. Implementation Checklist`; skip the workdoc write (no workdoc exists until `AUDIT_PASSED`).
4. If the spec is `AUDIT_PASSED` / `IN_PROGRESS`:
   - Append `- [ ] Step N: <description>` to the Implementation Checklist (N = next integer).
   - Append a matching `## Step N: <title>` block in the workdoc at `<kb_path>/repos/<project>/design/workdocs/<slug>/exec.md` with a `planned` block. Prompt the user for any of `goal` / `allowed_scope` / `passing_test_cmd` / `expected_pass_pattern` the description does not make obvious — these must be set before implementation starts. Leave `observed` empty.
   - Append to spec Log: `- YYYY-MM-DD: scope extended — added step N (<short description>)`.
5. Do **not** re-run the full audit loop. The existing audit covered the original scope; the new step gets its regular compliance check at implementation time. If the addition is substantial (new external API, new data model, cross-cutting), surface this and recommend `/feature new --follows-up` instead — it is a judgement call, not a hard rule.

### Follow-up specs (`--follows-up`)

`/feature new <description> --follows-up <prior-spec-path>` behaves like normal **New** except:

- Frontmatter is populated with `follows_up: <prior-spec-path>` (relative to `<kb_path>/repos/<project>/`, same convention as `depends_on`).
- One line is appended to the prior spec's Log: `- YYYY-MM-DD: follow-up spec created at <new-path>`.
- The new spec's **Context** section opens with a one-paragraph summary of what changed in the prior spec and why this work was split off (the orchestrator drafts it; the user may edit).
- `/feature status` renders the follow-up chain next to each spec row (`follows: <prior-slug>` / `followed-by: <new-slug>`) so the lineage is visible.

---

## Rules

- **Spec is source of truth.** Read at session start. Update as you work.
- **No implementation without approved spec.** Research and spec come first.
- **Log is append-only.** Never edit past entries.
- **One feature per spec.** Don't combine unrelated changes.
- **Specs in KB, code in source repos.**
- **Always offer agent choice** before implementation begins.
- **Merge ≠ done.** A spec with a non-empty post-merge checklist moves to
  `SHIPPED` on hand-off, not `VERIFIED`. Only `/feature verify` with every
  checklist item closed can reach `VERIFIED`.
- **No silent scope creep.** Every mid-flow scope addition must be explicit:
  a new step in the Implementation Checklist (extend), a post-merge action
  item (checklist add), or a linked follow-up spec (`--follows-up`). Record
  the decision in the source spec's Log.
