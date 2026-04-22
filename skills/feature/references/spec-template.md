---
title: {Feature Title}
project: {project-name}
type: spec
status: DRAFT
branch: {change_type}/YYYY-MM-DD-{slug}
change_type: {change_type}
created: YYYY-MM-DD
# Populated on hand-off (Option 1/2/3). Null while feature is still in development.
shipped_at: null
# Optional: set when this spec was split off from another via `/feature new --follows-up`.
# Points at the prior spec relative to <kb_path>/repos/<project>/, e.g.
#   follows_up: design/2026-03-10-claim-fees-event.md
follows_up: null
# Optional: populated automatically when /feature new is called with --from-investigation
# investigation_source: research/YYYY-MM-DD-<topic>.md
tags: [spec, {project-name}]
---

## 1. Context

Why this feature is needed. Link to proposal, issue, or discussion.

## 2. Current State

How the system works today. Reference KB pages and source files.

## 3. Design

### 3.1 Overview

What changes and why. Keep it concise.

### 3.2 Changes

| File | Change | Reason |
|------|--------|--------|
| `path/to/file.py` | Add X | Because Y |

### 3.3 Data model changes

New or modified models, migrations, contract storage.

### 3.4 API changes

New or modified endpoints, contract interfaces.

### 3.5 Configuration

New env vars, settings, or constants.

### 3.6 Risks (from investigation)

Only present when the spec was seeded with `--from-investigation`. Holds the
`## Risk Register` table from the convergence report. Remove this section if
no investigation is linked.

| Risk | Source | Severity | Mitigation |
|------|--------|----------|------------|
| ...  | ...    | ...      | ...        |

## 4. Dependencies

External services, contracts, other repos involved.

## 5. Implementation Checklist

Ordered steps. Each is a concrete, reviewable unit of work — a behavioral change that can be verified independently.

For each step, the orchestrator initializes a corresponding `planned` block in the execution workdoc before implementation begins.

- [ ] Step 1: description @codex
- [ ] Step 2: description @senior
- [ ] Step 3: description @middle
- [ ] Step 4: description

**Agent pre-tag (optional).** Each step may carry an optional `@<agent>` suffix — accepted tokens are `@codex`, `@senior`, and `@middle`, each separated from the description by exactly one space at the end of the line. Tags are case-insensitive: the orchestrator lowercases the tag at read time, so `@SENIOR` and `@Senior` resolve to `@senior`. Canonical form is lowercase — authors should write lowercase. No other suffix forms (no `@codex-fast`, no `@agent=codex`, no `(agent: codex)`). Untagged steps remain valid and defer to the orchestrator's matrix-trigger flow at Agent selection time (and `last_agent=` in Continue mode).

**Why not `@codex-fast`?** Fast is an orchestrator-time dispatch choice driven by `codex.model_fast` in user config, not a step property. A step that would benefit from Fast is still tagged `@codex`; the orchestrator routes it to Fast only when the user selects option 1b at the agent-selection banner.

## 6.1 Automated verification

How to test the feature end-to-end after all steps are complete.

## 6.2 Deploy & manual verification

Document post-merge deploy prerequisites and the fastest manual smoke check in
the YAML block below. `deploy_prerequisites` is a list of strings.
`smoke_check` is either `null` or a mapping with `command` and `expected`.

```yaml
deploy_prerequisites: []
# List of one-off ops steps that must run after merge before the feature works.
# (migrations, worker restarts, cache invalidation, config reload)
# Each non-empty line becomes one YAML list entry.
# Empty list means no deploy prerequisites.

smoke_check: null
# Optional: single fastest command + expected output to verify the feature is alive post-deploy.
# Set to null if no meaningful quick check exists (e.g. pure internal refactor).
# command: curl -s https://staging.example.com/api/foo | jq -r .status
# expected: ok
```

## 7. Execution Workdoc

The execution workdoc lives at:
```
<kb>/repos/<project>/design/workdocs/<slug>/exec.md
```

It tracks per-step planned intent and observed evidence. The orchestrator initializes it alongside this spec (planned fields only). The developer fills observed fields during implementation.

Code-audit findings raised by the mandatory code-audit phase (between Verify and Hand-off) persist separately to `<kb>/repos/<project>/security/<spec-slug>-code-findings.md`. They use the standard cross-audit finding state machine (`OPEN | FIXED | VERIFIED | REOPENED | ACCEPTED | DEFERRED`) — note that the feature flow routes false-positive triage through `ACCEPTED` with an explicit rationale rather than an `INVALID` verb, because the cross-auditor wire contract has no `invalid_ids` input slot. On each re-audit round the orchestrator does not manage `next_finding_id` explicitly; the cross-auditor auto-derives it from the highest existing `X<N>` id already recorded in that findings file, so new findings keep monotonically increasing without author bookkeeping.

### Workdoc step schema

Each checklist step has a corresponding entry in exec.md:

```yaml
## Step N: <step title>

### Planned
goal: one sentence describing the observable behavioral change
allowed_scope: glob pattern for files this step may touch (e.g. src/module/**)
failing_test_cmd: command that should fail before implementation (empty if no test)
expected_failure_pattern: substring expected in failure output
passing_test_cmd: command that should pass after implementation
expected_pass_pattern: substring expected in passing output
integration_probe_cmd: (optional) command to confirm feature is reachable at runtime
expected_probe_signal: (optional) substring expected from probe

### Observed
actual_files_touched: []
commit_shas: []
red_capture: captures/step-NN-red.txt
green_capture: captures/step-NN-green.txt
probe_capture: (if applicable)
notes: ""
```

**DONE rule**: a step is not done until `green_capture` exists with content matching `expected_pass_pattern`. No capture = not done.

## 8. Post-merge checklist

Items that must be resolved **after** the feature is merged before it can be
considered truly done. Managed by `/feature checklist` — do not hand-edit the
YAML block unless you know what you are doing.

Three types:

- **`action`** — a manual step the user must perform outside the repo (deploy a
  contract to mainnet, rotate a key, update an external dashboard, send an
  announcement).
- **`blocker`** — a dependency on another team or another spec. If
  `depends_on` points at a spec in the same project's design/ folder, the
  skill auto-resolves this item to `done` when that spec reaches `VERIFIED`.
  Cross-KB / cross-project dependencies are free-text only — resolve manually.
- **`soak`** — a passive observation period in staging or production. The
  timer does **not** start at merge; the user runs
  `/feature checklist start-soak <n>` once the change is actually live.

The spec moves to `SHIPPED` on hand-off if this list is non-empty, and to
`VERIFIED` via `/feature verify` once every item is `done`. A `failed` item
blocks verification — either mark it `done` with a justifying note, or open
a follow-up spec and add a new item describing the remediation.

```yaml
items: []
# Example items (delete before saving if the list is empty):
# - id: 1
#   type: action
#   description: Deploy contract v1.2 to Stellar mainnet
#   owner: user
#   status: pending       # pending | done | failed
#   notes: null           # required when status is failed
#   resolved_at: null     # YYYY-MM-DD, set when status leaves pending
# - id: 2
#   type: blocker
#   description: Frontend ships the new UI
#   owner: frontend-team
#   depends_on: design/2026-04-20-concentrated-ui.md  # same-project only; null for cross-KB
#   status: pending
#   notes: null
#   resolved_at: null
# - id: 3
#   type: soak
#   description: 7 days stable in prod
#   owner: user
#   duration_days: 7
#   started_at: null      # YYYY-MM-DD, set by `/feature checklist start-soak`
#   status: pending
#   notes: null
#   resolved_at: null
```

## 9. Log

Append-only. Record decisions, blockers, and progress.

### YYYY-MM-DD

- Created spec
