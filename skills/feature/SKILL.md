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

## Modes

Parse `$ARGUMENTS` to determine the mode:

| Input | Mode | Action |
|-------|------|--------|
| `new <description>` or bare non-path description | **New** | Research codebase, write spec, get approval |
| `continue [spec-path]` | **Continue** | Resume from last checkpoint in spec |
| bare path to an existing `*.md` file (not prefixed with `new`) | **Continue** | Treat as `continue <spec-path>` |
| `status` | **Status** | Show all in-progress specs |

---

## Phase 0: KB Discovery (all modes)

1. **Determine `project` name** first: use the current repo directory name (or ask if ambiguous).
2. Check memory for `reference_kb_<project>.md`
3. If not found: look for a sibling directory containing "knowledge" in its name (`ls ../`)
   - Example: project at `~/dev/personal/arbiter/stellar-arbiter-rs` → look for `~/dev/personal/arbiter/*knowledge*`
4. If found: **confirm with user**: "Обнаружен KB: `<path>`. Использовать его?"
5. If not found: ask user for KB path or where to initialize a new vault
6. After confirmation: save `kb_path` and `project` name to memory (`reference_kb_<project>.md`)

---

## New: Research + Spec

### Step 1 — Research

Read both KB and codebase before writing anything:

1. Ask Librarian agent (or read directly): `<kb_path>/repos/<project>/design/` for existing specs
2. Read any relevant KB docs: domain context, related project docs, glossary
3. Explore source code in the project directory: understand architecture, existing patterns, files that will change
4. Identify: reusable patterns, files to change, dependencies, risks, what already exists

### Step 2 — Write spec and initialize execution workdoc

You (the feature skill orchestrator) write both artifacts directly.

**Spec**: create at `<kb_path>/repos/<project>/design/YYYY-MM-DD-<slug>.md`. Create the directory if it doesn't exist. Use the template from `references/spec-template.md`. Key sections:
- **Context** — why this feature exists
- **Current State** — how the system works today (reference KB pages and source files)
- **Design** — changes table, data model, API, configuration
- **Branch** — `feature/YYYY-MM-DD-<slug>` (or specify different base if needed)
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

Spawn **Librarian** only if you need to update MOC indexes afterward.

### Step 3 — Get approval

Present a summary and wait for user approval before implementing.

<HARD-GATE>
Do NOT spawn any developer agent, write any code, or take any implementation action until the user has explicitly approved the spec. This applies to every feature regardless of perceived simplicity. "It looks straightforward" is not approval.
</HARD-GATE>

Set spec `status: APPROVED` after explicit user approval.

### Step 3.5 — Spec review (two passes)

After approval, review the spec and execution workdoc before any code is written.

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
> "Spec review passed. Ready to proceed with implementation?"
Set spec `status: AUDIT_PASSED`.

**Skip**: user says "skip spec audit" or "proceed anyway" — skip both passes, set `status: AUDIT_PASSED`, append to Log: `"spec audit skipped by user"`. (Setting AUDIT_PASSED rather than keeping APPROVED ensures continue mode does not re-enter the audit loop on resume.)

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

> **Which developer should implement this?**
> 1. **Codex (GPT-5.4 xhigh)** ← default — saves Claude tokens, corporate subscription, use aggressively
> 2. **Senior (Opus)** — only when Codex falls short: highly ambiguous scope, extensive codebase exploration needed, ultra-complex cross-cutting changes
> 3. **Middle (Sonnet)** — quick in-session fixes where spawning Codex is overkill (trivial one-liner changes, typos, small config edits)

**Rule of thumb**: prefer Codex unless the task requires broad live filesystem exploration or has genuinely ambiguous scope that the feature spec couldn't fully specify. When in doubt — try Codex first.

If the feature spec tagged steps with a developer level, use that. Otherwise default to Codex.

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

#### Option 3: Middle (developer-middle agent)

Spawn `developer-middle` subagent with:
- `spec_path`: path to the spec file
- `workdoc_path`: `<kb_path>/repos/<project>/design/workdocs/<slug>/exec.md`
- `project_path`: path to the source repo
- `task`: "full spec" or specific steps

### Git conventions

- **Base branch**: `master` or `main` — whichever exists in the repo (`git branch -r | grep -E 'origin/(master|main)$'`). Never cut from `staging`, `testnet`, `pre-prod`, or similar collection branches — those are staging dumps, not source of truth
- **Feature branch**: `feature/YYYY-MM-DD-<slug>` (or as specified in spec `Branch:` field)
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

- **PASS**: Proceed to Hand-off. Do **not** set `status: DONE` yet — wait until the user selects a preserving option (merge, push, or keep). Setting DONE before that means a discard would leave the spec permanently marked DONE with no surviving branch.
- **FAIL**: present failures to user. Analyze the verifier report to identify which checklist step(s) are responsible. Spawn the developer with `rework step N: fix test failure: <relevant excerpt>` for each affected step. Re-verify after fix.
- **NO_TESTS**: no test suite detected. If step-level captures (green_capture + compliance PASS) exist for all steps, treat as PASS. If any step lacks captures, ask the user for manual sign-off before proceeding. Log the absence of a project-level test suite.

---

## Hand-off

After verify passes, show the commit list and present exactly these 4 options:

```
git log --oneline <base>..<branch>

Implementation complete. What would you like to do?

1. Merge into <base-branch> locally
2. Push feature branch (I'll merge to staging and open a PR myself)
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

> Note: merging into `staging` / `testnet` / `pre-prod` for testing is a separate manual step the user handles. The plugin only merges into the base branch (`master` or `main`).

**Option 1 — Merge into base branch locally:**
```bash
git checkout <base-branch> && git pull && git merge <branch>
```
Run verifier once more on the merged result. If green: `git branch -d <branch>`. Set spec `status: DONE`.

**Option 2 — Push feature branch:**
```bash
git push -u origin <branch>
```
Report the branch name. Set spec `status: DONE`.

**Option 3 — Keep as-is:** Do nothing. Report the branch name. Set spec `status: DONE`.

**Option 4 — Discard:** Confirm first:
```
This will permanently delete branch <name> and all commits:
<commit list>

Type 'discard' to confirm.
```
On confirmation: `git checkout <base-branch> && git branch -D <branch>`. Set spec `status: DISCARDED`, append to Log: "feature discarded by user".

---

## Continue mode

When resuming (`/feature continue` or `/feature <spec-path>`):

1. Run KB discovery (Phase 0)
2. Read the spec file. Check the `status` field in frontmatter:
   - `DRAFT` → Spec not yet approved. Present it to the user and ask for approval. Resume from Step 3 (Get approval).
   - `APPROVED` → Resume from Step 3.5 (spec self-review → cross-audit).
   - `AUDIT_PASSED` → Resume from Implement (baseline test → agent selection → implementation).
   - `IN_PROGRESS` → Find the first unchecked `- [ ]` step. Resume from there. Ask which agent to use. If no unchecked step exists (all `[x]`): implementation is complete — run Verify.
   - `DONE` → Feature complete and already preserved. Report completion status and stop.
   - `DISCARDED` → Feature was discarded. Report this and stop.
3. Report current state: spec name, status, completed steps count, next step, any blockers from the Log section
4. Ask which agent to use for remaining work (only if resuming implementation)

---

## Status mode

1. Run KB discovery (Phase 0)
2. Find all specs: `<kb_path>/repos/*/design/YYYY-MM-DD-*.md`
3. Read status and checklist from each
4. Show summary:

```
| Spec | Project | Status | Progress | Branch |
|------|---------|--------|----------|--------|
| ... | ... | IN_PROGRESS | 3/7 steps | feature/... |
```

---

## Rules

- **Spec is source of truth.** Read at session start. Update as you work.
- **No implementation without approved spec.** Research and spec come first.
- **Log is append-only.** Never edit past entries.
- **One feature per spec.** Don't combine unrelated changes.
- **Specs in KB, code in source repos.**
- **Always confirm KB path** before using — even if auto-discovered.
- **Always offer agent choice** before implementation begins.
