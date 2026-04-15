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
| `new <description>` or bare description | **New** | Research codebase, write spec, get approval |
| `continue [spec-path]` | **Continue** | Resume from last checkpoint in spec |
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

Spawn `cross-auditor` subagent with:
- `scope`: `<spec_path>` (the spec file — cross-auditor will also read the execution workdoc)
- `mode`: `spec`
- `project`: `<project>`
- `audit_slug`: `<slug>-spec`
- `iteration`: 1
- (omit `kb_path` — spec mode does not write to KB)

In the spawn prompt, include the workdoc path explicitly so the auditor reviews both documents:
> "Also review the execution workdoc at `<workdoc_path>`. Check planned fields for completeness, coherence with the spec, and sound sequencing."

The cross-auditor returns findings inline (no KB writes in spec mode).

**If CRITICAL or HIGH findings:**
1. Present findings to user
2. Update spec/workdoc (user edits in Obsidian, or ask Claude to apply the fix)
3. Re-run Pass 1 self-review, then spawn cross-auditor again with `iteration: 2`
4. Repeat until no CRITICAL/HIGH remain
5. Set spec `status: AUDIT_PASSED`

**If no CRITICAL or HIGH findings:**
> "Spec review passed. Ready to proceed with implementation?"
Set spec `status: AUDIT_PASSED`.

**Skip**: user says "skip spec audit" or "proceed anyway" — skip both passes, keep `status: APPROVED`.

---

## Implement

### Baseline test

Before spawning any developer, run the **verifier** subagent on the base branch to establish a clean baseline:

```
project_path: <project_path>
task: "Run the full test suite on the current branch and report pass/fail. Do not modify any files."
```

- **All green**: proceed to agent selection.
- **Any failures**: stop. Report to user: "Baseline is not clean — N test(s) failing before any new code. Resolve these first or they'll be falsely attributed to the new feature."

This step is skipped if the project has no test suite (verifier will report "no tests found").

### Agent selection

Before starting implementation, ask the user which agent to use:

> **Which developer should implement this?**
> 1. **Codex (GPT-5.4 xhigh)** ← default — saves Claude tokens, corporate subscription, use aggressively
> 2. **Senior (Opus)** — only when Codex falls short: highly ambiguous scope, extensive codebase exploration needed, ultra-complex cross-cutting changes
> 3. **Middle (Sonnet)** — quick in-session fixes where spawning Codex is overkill (trivial one-liner changes, typos, small config edits)

**Rule of thumb**: prefer Codex unless the task requires broad live filesystem exploration or has genuinely ambiguous scope that Architect couldn't fully specify. When in doubt — try Codex first.

If the Architect tagged steps in the spec with a developer level, use that. Otherwise default to Codex.

#### Option 1: Senior (developer-senior agent)

Spawn `developer-senior` subagent with:
- `spec_path`: path to the spec file
- `workdoc_path`: `<kb_path>/repos/<project>/design/workdocs/<slug>/exec.md`
- `project_path`: path to the source repo
- `task`: "full spec" or specific steps

#### Option 2: Middle (developer-middle agent)

Spawn `developer-middle` subagent with:
- `spec_path`: path to the spec file
- `workdoc_path`: `<kb_path>/repos/<project>/design/workdocs/<slug>/exec.md`
- `project_path`: path to the source repo
- `task`: "full spec" or specific steps

#### Option 3: Codex (developer-codex agent)

Spawn `developer-codex` subagent with:
- `spec_path`: path to the spec file
- `workdoc_path`: `<kb_path>/repos/<project>/design/workdocs/<slug>/exec.md`
- `project_path`: path to the source repo
- `task`: steps to implement (works best when spec has explicit file paths and clear requirements)

### Git conventions (both agents)

- Work on feature branch: `feature/YYYY-MM-DD-<slug>` (or as specified in spec `Branch:` field)
- Confirm base branch with user if different from master or if unclear
- Small logical commits per checklist step
- No "Co-authored-by" in commit messages
- No pushing — user handles push and PR

---

## Verify

After implementation is complete, spawn the **verifier** subagent:

```
project_path: <project_path>
spec_path: <spec_path>
scope: <list of changed files from spec checklist>
```

- **PASS**: set spec status `DONE`. Proceed to Hand-off.
- **FAIL**: present failures to user. Spawn the developer again with: `rework: fix these test failures: <verifier report>`. Re-verify after fix.

---

## Hand-off

After verify passes, show the commit list and present exactly these 4 options:

```
git log --oneline <base>..<branch>

Implementation complete. What would you like to do?

1. Merge into <base-branch> locally
2. Push and open a PR
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

**Option 1 — Merge locally:**
```bash
git checkout <base-branch> && git pull && git merge <branch>
```
Run verifier once more on the merged result. If green: `git branch -d <branch>`.

**Option 2 — Push and PR:**
```bash
git push -u origin <branch>
gh pr create --draft --title "<feature title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets>

## Test plan
<verification steps from spec>

Spec: <spec_path>
EOF
)"
```

**Option 3 — Keep as-is:** Do nothing. Report the branch name.

**Option 4 — Discard:** Confirm first:
```
This will permanently delete branch <name> and all commits:
<commit list>

Type 'discard' to confirm.
```
On confirmation: `git checkout <base-branch> && git branch -D <branch>`.

---

## Continue mode

When resuming (`/feature continue` or `/feature <spec-path>`):

1. Run KB discovery (Phase 0)
2. Read the spec file
3. Report current state: phase, completed steps, next step, blockers
4. Ask which agent to use for remaining work
5. Proceed with the next unchecked step

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
