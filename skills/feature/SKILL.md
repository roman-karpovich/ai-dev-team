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
| `new <description> --from-investigation <path>` | **New (seeded)** | Like **New**, but pre-seed the spec from a `/investigate` convergence report |
| `continue [spec-path]` | **Continue** | Resume from last checkpoint in spec |
| bare path to an existing `*.md` file (not prefixed with `new`) | **Continue** | Treat as `continue <spec-path>` |
| `status` or `status --all` | **Status** | Show actionable specs (or everything with `--all`) |
| `checklist <add\|done\|fail\|start-soak\|list> …` | **Checklist** | Manage post-merge items on a SHIPPED spec |
| `verify <spec-path>` | **Verify** | Auto-resolve blockers, flip to VERIFIED if every item is done |
| `extend <description>` | **Extend** | Append a new step to the active spec's Implementation Checklist + workdoc (scope addition) |
| `new <description> --follows-up <spec-path>` | **New (follow-up)** | Like **New**, but links the new spec to a prior one via `follows_up` |
| `discard [spec-path]` | **Discard** | Delete feature branch + set spec DISCARDED (explicit; not tied to hand-off) |

---

## Phase 0: KB Discovery (all modes)

1. Determine `project` and `kb_path` via config before using legacy discovery.
2. Read `.ai-dev-team.local.yml` first. `.ai-dev-team.local.yml` is the local override file, should be gitignored in the consumer repo, and `.ai-dev-team.local.yml overrides .ai-dev-team.yml`.
3. Read `.ai-dev-team.yml` second. Compact shared-config fallback anchor: `.ai-dev-team.yml → memory → sibling heuristic → ask`
4. Supported config shape:

```yaml
kb_path: /absolute/path/to/knowledge-base
project: my-project-name

# Optional Codex MCP overrides (propagate to developer-codex + cross-auditor)
codex:
  model: gpt-5.4          # omit to use ~/.codex/config.toml default
  reasoning_effort: xhigh  # minimal|low|medium|high|xhigh (default: xhigh)
```

5. Read top-level `kb_path` and `project` independently. `per-field resolution: local → shared → memory → sibling → ask, continue on per-file parse error`
6. If either config file is malformed, missing `kb_path`, or points at a non-existent directory: warn once for that file and continue to the next source in the chain. Do not abort the session on parse error.
7. When config is valid, skip confirmation prompt
8. When config is valid, do not write to memory
9. If config does not resolve a field, fall through to legacy discovery:
   - `kb_path`: check `memory/reference_kb_<project>.md`, then look for a sibling directory containing "knowledge" in its name (`ls ../`), then ask the user
   - `project`: use memory if available, otherwise use the current repo directory name, then ask if ambiguous
10. If no valid config resolved `kb_path` and a sibling KB is auto-discovered, confirm with the user before using it. After explicit confirmation in the legacy flow, save `kb_path` and `project` to memory (`reference_kb_<project>.md`).
11. After legacy discovery succeeds (step 9 or 10 resolved via memory / sibling / ask), if `.ai-dev-team.yml` does not exist in the repo root, prompt: **"Save `kb_path` and `project` to `.ai-dev-team.yml` so future sessions skip discovery? [Y/n]"**. On yes: write a file containing the resolved `kb_path` and `project` fields (copy-and-substitute from `.ai-dev-team.yml.example` if present). If the file exists but lacks one of these fields, print a one-line warning with the value to add — never overwrite user config automatically.
12. Also read `codex.model` and `codex.reasoning_effort` from the same config chain. When the feature skill dispatches to `developer-codex` or spawns `cross-auditor`, pass these through as `codex_model` and `codex_reasoning_effort` input params. If both are absent the agents use their built-in defaults. Also read `codex.model_fast` from the same config chain; it is forwarded as `codex_model` only when the user picks "Codex Fast" from the agent-selection menu. `cross-auditor` never receives `codex.model_fast`.

---

## New: Research + Spec

### Step 1 — Research

Read both KB and codebase before writing anything:

1. Ask Librarian agent (or read directly): `<kb_path>/repos/<project>/design/` for existing specs
2. Read any relevant KB docs: domain context, related project docs, glossary
3. Explore source code in the project directory: understand architecture, existing patterns, files that will change
4. Identify: reusable patterns, files to change, dependencies, risks, what already exists

#### Step 1a — Ingest `--from-investigation` (only if flag present)

When `--from-investigation <path>` is supplied, read the convergence report before the research pass. Resolve `<path>` in this order:

1. Absolute path → use as-is.
2. Relative to `<kb_path>/repos/<project>/research/`.
3. Relative to the current working directory.

If none resolves → stop and report: "Investigation file not found: `<path>`. Searched: <list of attempts>. Pass an absolute path or place the report under `research/`."

Parse the file for these H2 sections (tolerate minor heading variations; skip silently if a section is missing):

| Report section | Maps to spec section |
|---|---|
| `## Recommended Approach` | **Context** — embed as a blockquote labelled "Recommended approach (from investigation)" |
| `## Key Agreements` | **Current State** — embed as a blockquote labelled "Validated assumptions" |
| `## Open Questions` | **Context** — subheading `### Open Questions to resolve during implementation` |
| `## Risk Register` | **Design** — new subsection `### Risks (from investigation)` appended after the Changes table |

Record provenance:
- In spec frontmatter: `investigation_source: <path-relative-to-kb_path, or absolute>`.
- Append to spec Log: `- YYYY-MM-DD: spec seeded from investigation <path>`.

The seed is a starting point, not a replacement for research — still do steps 2–4 above before writing the design.

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

If the user chooses **Skip**: set `status: AUDIT_PASSED`, append to Log: `"spec audit skipped by user"`, proceed directly to Implement. (Setting AUDIT_PASSED rather than keeping APPROVED ensures continue mode does not re-enter the audit loop on resume.)

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
5. Re-run Pass 1 self-review, then re-spawn cross-auditor with updated `iteration` and `previously_fixed`
6. Repeat until no CRITICAL/HIGH remain
7. Set spec `status: AUDIT_PASSED`

**If no CRITICAL or HIGH findings:**
> Spec review passed — the spec is saved to KB. Moving to implementation.
> 💡 Consider running `/compact` before implementation to trim conversation history.

Set spec `status: AUDIT_PASSED`.

**Mid-flow skip**: if the user says "skip" or "proceed anyway" at any point during the audit — stop, set `status: AUDIT_PASSED`, append to Log: `"spec audit skipped by user"`.

---

## Implement

### Baseline test

Before spawning any developer, detect the base branch (`git branch -r | grep -E 'origin/(master|main)$'` — prefer `master` if both exist), ensure you are on it (or the branch specified in the spec `Branch:` field), then run the **verifier** subagent:

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

1. **Codex (GPT-5.4 xhigh)** ← default — saves Claude tokens, corporate subscription, use aggressively
1b. **Codex Fast** — faster/cheaper variant; only shown when `codex.model_fast` is configured.
2. **Senior (Opus)** — only when Codex falls short: highly ambiguous scope, extensive codebase exploration needed, ultra-complex cross-cutting changes
3. **Middle (Sonnet)** — quick in-session fixes where spawning Codex is overkill (trivial one-liner changes, typos, small config edits)

Render option 1b and the "#### Option 1b: Codex Fast (developer-codex agent)" subsection only when `codex.model_fast` resolved in Phase 0; when it is unset, omit both entirely (the menu reverts to three options).

**Which agent?**

If the feature spec tagged steps with a developer level, use that. Otherwise default to Codex.

**Remember the choice**: once the user has picked an agent, append to the spec Log per the canonical format in `skills/feature/references/agent-routing.md` §Rationale logging. Continue mode reads the most recent `last_agent=` entry from the Log and offers that as the default on resume (the user can still override).

#### Option 1: Codex (developer-codex agent)

Spawn `developer-codex` subagent with:
- `spec_path`: path to the spec file
- `workdoc_path`: `<kb_path>/repos/<project>/design/workdocs/<slug>/exec.md`
- `project_path`: path to the source repo
- `task`: steps to implement (works best when spec has explicit file paths and clear requirements)

#### Option 1b: Codex Fast (developer-codex agent)

Spawn `developer-codex` subagent with:
- `spec_path`: path to the spec file
- `workdoc_path`: `<kb_path>/repos/<project>/design/workdocs/<slug>/exec.md`
- `project_path`: path to the source repo
- `codex_model`: the value of `codex.model_fast` from config (not `codex.model`)
- `task`: steps to implement — Fast is for well-specified, pattern-following steps (see `skills/feature/references/agent-routing.md` § `Codex Fast (opt-in)`)

#### Option 2: Senior (developer-senior agent)

Spawn `developer-senior` subagent with:
- `spec_path`: path to the spec file
- `workdoc_path`: `<kb_path>/repos/<project>/design/workdocs/<slug>/exec.md`
- `project_path`: path to the source repo
- `task`: "full spec" or specific steps

#### Option 3: Middle (developer-middle agent)

Spawn `developer-middle` subagent with:
- `spec_path`: path to the spec file
- `workdoc_path`: `<kb_path>/repos/<project>/design/workdocs/<slug>/exec.md`
- `project_path`: path to the source repo
- `task`: "full spec" or specific steps

### Git conventions

- **Base branch**: `master` or `main` — whichever exists in the repo (`git branch -r | grep -E 'origin/(master|main)$'`). Never cut from `staging`, `testnet`, `pre-prod`, or similar collection branches — those are staging dumps, not source of truth
- **Feature branch**: `<type>/YYYY-MM-DD-<slug>` — `<type>` is the spec's resolved `change_type` (one of `feat / fix / refactor / ci / docs / test / chore`); dated example: `feat/2026-04-17-my-feature` (or as specified in spec `Branch:` field; see R4 in `references/code-quality-rules.md`)
- **Feature dependencies**: if this feature depends on another in-flight feature, merge that feature's branch into this one directly. Do not route through staging
- Small logical commits per checklist step
- No "Co-authored-by" in commit messages
- No pushing — user handles pushing, staging merge, and PR

---

## Verify

After implementation is complete, spawn the **verifier** subagent:

```
project_path: <project_path>
spec_path: <spec_path>
scope: <list of changed files from spec checklist>
```

- **PASS**: All results are captured in the workdoc.
  > 💡 Consider running `/compact` before hand-off — implementation context is no longer needed.
  Verify passed. Moving to hand-off. Do **not** set `status: DONE` yet — wait until the user selects a preserving option (merge, push, or keep). Setting DONE before that means a discard would leave the spec permanently marked DONE with no surviving branch.
- **FAIL**: present failures to user. Analyze the verifier report to identify which checklist step(s) are responsible. Spawn the developer with `rework step N: fix test failure: <relevant excerpt>` for each affected step. Re-verify after fix.
- **NO_TESTS**: no test suite detected. If step-level captures (green_capture + compliance PASS) exist for all steps, treat as PASS. If any step lacks captures, ask the user for manual sign-off (see banner below). Log the absence of a project-level test suite.

---
## ⏸ AWAITING YOUR INPUT

No test suite was detected and one or more steps lack green captures. Manual sign-off is required before hand-off.

**Do you confirm implementation is complete?**

---

## Hand-off

After verify passes, run a two-phase hand-off seed before showing the
4-option menu. This is per-item reconciliation: re-read §6.2 on every
hand-off; only `deploy_prerequisites` participate in seeding. `smoke_check`
is never seeded into §8.

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

When resuming (`/feature continue` or `/feature <spec-path>`):

1. Run KB discovery (Phase 0)
2. Read the spec file. Check the `status` field in frontmatter:
   - `DRAFT` → Spec not yet approved. Present it to the user and ask for approval. Resume from Step 3 (Get approval).
   - `APPROVED` → Resume from Step 3.5 (spec self-review → cross-audit).
   - `AUDIT_PASSED` → Resume from Implement (baseline test → agent selection → implementation).
   - `IN_PROGRESS` → Find the first unchecked `- [ ]` step. Resume from there. Ask which agent to use. If no unchecked step exists (all `[x]`): implementation is complete — run Verify.
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

---
## ⏸ AWAITING YOUR INPUT

Resuming implementation. Pick the developer for the remaining steps. The most recent `last_agent=<codex|senior|middle>; rationale=<T-X#>` entry in the spec Log is offered as the default — press Enter to accept it, or name a different agent.

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

3. Refuse if `status: DONE` — already merged, not something discard can undo. Tell the user to revert the merge commit instead.
4. Refuse if `status: DISCARDED` — already gone.
5. Show the commit list and branch name, then ask for typed confirmation via the banner below.

```
git log --oneline <base>..<branch>
```

---
## ⏸ AWAITING YOUR INPUT

This will permanently delete branch `<branch>` and all commits listed above. There is no undo.

**Type the word `discard` to confirm — any other reply aborts. Confirm?**

6. On confirmation: `git checkout <base-branch> && git branch -D <branch>` (use `-D` — force, since the branch likely isn't merged into base). Set `status: DISCARDED`, append Log: `- YYYY-MM-DD: feature discarded by user`.
7. On any other answer: abort, leave state untouched.

---

## Status mode

1. Run KB discovery (Phase 0)
2. Find all specs: `<kb_path>/repos/*/design/YYYY-MM-DD-*.md`
3. Read status, implementation checklist, and post-merge checklist (section 8) from each
4. For every `SHIPPED` spec: run the auto-resolve pass (see Verify mode) so blockers pointing at now-verified specs collapse before we render
5. Filter: by default, hide `VERIFIED` / `DONE`, `DISCARDED`, and `BLOCKED` (they are not actionable now). Always show `SHIPPED`. If the argument is `status --all`, show every spec regardless of status.
6. Group the visible specs into named sections:

```
### Active
| Spec | Project | Status | Progress | Branch |
|------|---------|--------|----------|--------|
| ... | ... | IN_PROGRESS | 3/7 steps | <type>/... |

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
development. Refuses to add items to `VERIFIED` / `DISCARDED` specs.

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

3. **Spec is `VERIFIED` / `DONE`** — ask the banner below.

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
2. Refuse on `SHIPPED` / `VERIFIED` / `DONE` / `DISCARDED` — follow-up specs and post-merge action items are the right tools there (see *Scope addition mid-flow*).
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
