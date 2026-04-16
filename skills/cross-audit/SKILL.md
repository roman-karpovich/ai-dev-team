---
name: cross-audit
description: Iterative cross-audit with Claude + Codex working independently then consolidating findings. Runs in background — does not block the main conversation.
argument-hint: "<scope description OR path to existing findings doc> [--diff] [--mode logic|security|full]"
---

# Cross-Audit: Background Parallel Review

Cross-audit runs Claude (Opus) and Codex (GPT-5.4) as independent auditors, consolidates their findings into KB documents, then iterates until clean. **Runs in the background** so you can continue working.

## Argument Parsing

**Re-audit detection**: if `$ARGUMENTS` matches `*-findings.md` AND the file exists on disk → **re-audit iteration**. If it looks like a path but doesn't exist → error out and ask the user. Otherwise → **new audit**.

**Flags** (orthogonal to each other):
- `--diff` → scope the audit to files changed since `base_branch` (default: auto-detected repo default, falls back to `main`). Can combine with any mode: e.g. `--diff --mode logic` audits only changed files using logic focus areas.
- `--mode logic|security|full` → audit mode (default: `full`)

---

## Phase 0: KB Discovery (all modes)

1. Determine `project` and `kb_path` via config before using legacy discovery.
2. Read `.ai-dev-team.local.yml` first. `.ai-dev-team.local.yml` is the local override file, should be gitignored in the consumer repo, and `.ai-dev-team.local.yml overrides .ai-dev-team.yml`.
3. Read `.ai-dev-team.yml` second. Compact shared-config fallback anchor: `.ai-dev-team.yml → memory → sibling heuristic → ask`
4. Supported config shape:

```yaml
kb_path: /absolute/path/to/knowledge-base
project: my-project-name
```

5. Read top-level `kb_path` and `project` independently. `per-field resolution: local → shared → memory → sibling → ask, continue on per-file parse error`
6. If either config file is malformed, missing `kb_path`, or points at a non-existent directory: warn once for that file and continue to the next source in the chain. Do not abort the session on parse error.
7. When config is valid, skip confirmation prompt
8. When config is valid, do not write to memory
9. If config does not resolve a field, fall through to legacy discovery:
   - `kb_path`: check `memory/reference_kb_<project>.md`, then look for a sibling directory containing "knowledge" in its name (`ls ../`), then ask the user
   - `project`: use memory if available, otherwise use the current repo directory name, then ask if ambiguous
10. If no valid config resolved `kb_path` and a sibling KB is auto-discovered, confirm with the user before using it. After explicit confirmation in the legacy flow, save `kb_path` and `project` to memory (`reference_kb_<project>.md`).

**New audit**: generate `audit_slug` = `YYYY-MM-DD-<scope-slug>`.
**Re-audit**: extract `audit_slug` from the existing findings doc filename — strip the path prefix and `-findings.md` suffix (e.g. `…/2026-04-14-workflow-definitions-findings.md` → `2026-04-14-workflow-definitions`). Do NOT regenerate from the current date; the slug must match the original to write to the same file.

---

## Phase 1-2: Background Audit + Consolidation

**DO NOT block the main conversation.** Dispatch to `cross-auditor` agent immediately.

### Step 1: Determine parameters

From `$ARGUMENTS` derive:
- **scope**: files/directories/feature area
- **mode**: `logic` | `security` | `full`
- **base_branch**: for diff mode (default: auto-detected via `git symbolic-ref refs/remotes/origin/HEAD`, falls back to `main`)
- **previously_fixed**: if re-audit, extract from existing findings doc
- **project_type**: detect from codebase (smart_contract, backend, frontend, data_pipeline)
- **iteration**: 1 for new audit, N+1 for re-audit
- **kb_path**: from discovery above
- **project**: project name
- **audit_slug**: `YYYY-MM-DD-<scope-slug>` (new audit) or extracted from the existing findings filename (re-audit — see Phase 0)

### Step 2: Launch cross-auditor agent in background

```
Cross-audit the following scope.

scope: [derived scope]
project_type: [detected type]
mode: [logic|security|full]
kb_path: [kb_path]
project: [project]
audit_slug: [audit_slug]
iteration: [N]
base_branch: [branch, if diff mode]
previously_fixed: [list of IDs, if re-audit]
working_directory: [cwd]

[If re-audit: include the current findings doc path for context]
```

### Step 3: Inform the user

> Cross-audit running in background on **[scope]** (mode: [mode], iter [N]).
> Findings → `KB/repos/<project>/security/<slug>-findings.md`
> Continue working — I'll present results when both auditors finish.

---

## Phase 3: Present & Decide (foreground, interactive)

When cross-auditor completes:

1. Read the findings doc from KB
2. Present to user:
   - Count by severity and confidence
   - HIGH CONFIDENCE findings first (both auditors agreed)
   - REVIEW findings second (one auditor only)
3. **Stop and wait** for user decision per finding:
   - `fix X1 X3` — apply fixes
   - `accept X2` — known issue, intentional
   - `defer X4` — address later
   - `fix all` — fix everything

---

## Phase 4: Fix (foreground, interactive)

1. Update finding statuses in findings doc **before** writing any code:
   - `fix` targets: OPEN|REOPENED → FIXED
   - `accept` targets: OPEN|REOPENED → ACCEPTED
   - `defer` targets: OPEN|REOPENED → DEFERRED
2. Apply code fixes for the `fix` targets
3. Run build/tests to verify
4. Commit changes if user wants (small logical commits, no co-authored-by)

---

## Phase 5: Re-Audit (background)

When user invokes `/cross-audit <findings-doc-path>`:

1. Read the existing findings doc
2. Extract two separate lists:
   - `fixed_ids`: IDs with status `FIXED` (whether previously OPEN or REOPENED) — the auditor will verify these and flip to VERIFIED if confirmed
   - `accepted_ids`: IDs with status `ACCEPTED` or `DEFERRED` — skip re-reporting, preserve their status (do NOT flip to FIXED)
3. Launch cross-auditor with both lists: `previously_fixed: <fixed_ids>`, `accepted_ids: <accepted_ids>`
4. Agent **verifies each fix** (reads file:line, confirms fix is present) and looks for new issues
   - Confirmed fixes → VERIFIED
   - Absent or broken fixes → REOPENED
5. On completion: findings doc updated, new workdoc-iter<N>.md created, present delta

### Convergence
- **COMPLETE** when no CRITICAL or HIGH findings remain OPEN or REOPENED
- Typically 2-4 iterations

---

## Iteration Loop

```
/cross-audit <scope>              → Background: parallel audit, save to KB
  [user continues working...]
  [results arrive]
  user: "fix X1 X3, defer X2"    → Foreground: apply fixes
/cross-audit <findings-doc-path>  → Background: re-audit diff, update KB
  [results arrive]
  → Status: COMPLETE
```

---

## Adaptation by Project Type

### Smart Contracts / DeFi
- Fund loss, reentrancy, access control, math precision, flash loan safety, MEV resistance
- Key handling, tx signing, slippage, oracle manipulation

### Backend Services
- Input validation, injection, auth bypass, race conditions, resource exhaustion

### Frontend
- XSS, CSRF, injection, state management, API contract mismatches

### Data Pipelines
- Data loss, idempotency, schema evolution, monitoring blind spots
