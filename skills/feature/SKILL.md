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

### Step 2 — Write spec

You (the feature skill orchestrator) write the spec directly — you are the author and sole owner of the spec document. Spawn **Librarian** only if you need to update MOC indexes afterward.

Create the spec at `<kb_path>/repos/<project>/design/YYYY-MM-DD-<slug>.md`. Create the directory if it doesn't exist.

Use the template from `references/spec-template.md`. Key sections:
- **Context** — why this feature exists
- **Current State** — how the system works today (reference KB pages and source files)
- **Design** — changes table, data model, API, configuration
- **Branch** — `feature/YYYY-MM-DD-<slug>` (or specify different base if needed)
- **Implementation Checklist** — ordered, concrete steps (each is a reviewable unit)
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

### Step 3 — Get approval

Present a summary and wait for user approval before implementing. Never start implementation without explicit go-ahead. Set spec `status: APPROVED` after approval.

---

## Implement

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
- `project_path`: path to the source repo
- `task`: "full spec" or specific steps

#### Option 2: Middle (developer-middle agent)

Spawn `developer-middle` subagent with:
- `spec_path`: path to the spec file
- `project_path`: path to the source repo
- `task`: "full spec" or specific steps

#### Option 3: Codex (developer-codex agent)

Spawn `developer-codex` subagent with:
- `spec_path`: path to the spec file
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

After verify passes:

1. Present the commit list: `git log --oneline <base>..<branch>`
2. Ask user: "Ready to push? I'll run `git push -u origin <branch>` and open a PR draft."
3. On confirmation:
   - Push the branch
   - Offer to create PR: `gh pr create --draft --title "<feature title>" --body "Spec: <spec_path>"`
4. On decline: leave branch local, remind user the branch is ready.

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
