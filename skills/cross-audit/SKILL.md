---
name: cross-audit
description: Iterative cross-audit with Claude + Codex working independently then consolidating findings. Runs in background — does not block the main conversation.
argument-hint: "<scope description OR path to existing findings doc> [--diff] [--mode logic|security|full] [--severity high|medium+]"
---

# Cross-Audit: Background Parallel Review

Cross-audit runs Claude (Opus) and Codex (GPT-5.4) as independent auditors, consolidates their findings into KB documents, then iterates until clean. **Runs in the background** so you can continue working.

User-input prompt presentation in this skill follows the banner
convention in `docs/user-input-banner-convention.md` — the per-finding
decision fork in Phase 3 carries the `AWAITING YOUR INPUT` banner.

## Argument Parsing

**Re-audit detection**: if `$ARGUMENTS` matches `*-findings.md` AND the file exists on disk → **re-audit iteration**. If it looks like a path but doesn't exist → error out and ask the user. Otherwise → **new audit**.

**PR-mode detection**: if `$ARGUMENTS` starts with `pr <N>`, `pr owner/repo#<N>`, or `pr <url>` → **PR audit**. Skip legacy scope parsing; run Phase 0.5 (below) to resolve `pr_repo` / `pr_url` / `pr_number` and fetch `pr_changed_files`. Three accepted input forms:
- `pr <N>` (bare number, e.g. `pr 472`) — resolve repo via `gh repo view --json nameWithOwner` in the caller's cwd; if cwd is not a gh-known repo, stop with remediation.
- `pr owner/repo#<N>` (e.g. `pr roman-karpovich/ai-dev-team#472`) — repo taken from the `owner/repo` prefix.
- `pr <url>` (e.g. `pr https://github.com/roman-karpovich/ai-dev-team/pull/472`) — repo and number parsed from the URL.

**Standalone publish**: `/cross-audit publish <slug> <ids>` is a second entry point that invokes the `publish` action against an existing findings doc resolved from `<slug>` (e.g. `2026-04-14-webhooks`). Skips Phases 0.5 / 1-2 / 3-fix; jumps straight into publish using the `pr_files` / `pr_head_oid` / `pr_url` persisted in findings frontmatter. See `references/publish.md` for the full recipe. Publish is orthogonal to the status state machine — it does NOT flip OPEN→FIXED.

**Flags** (orthogonal to each other):
- `--diff` → scope the audit to files changed since `base_branch` (default: auto-detected repo default, falls back to `main`). Can combine with any mode: e.g. `--diff --mode logic` audits only changed files using logic focus areas.
- `--mode logic|security|full` → audit mode (default: `full`)
- `--severity high|medium+` → severity floor (default: `high`). `high` collects only CRITICAL/HIGH (current behavior). `medium+` also includes MEDIUM — useful for small features where serious findings are unlikely but nitpick-level review is still valuable.
- `--force-publish-stale` → (publish only) bypasses the force-push preflight when the current PR `headRefOid` has diverged from the audit-time `pr_head_oid`. Records the stale OID in `head_oid_at_publish` for audit trail. See `references/publish.md`.
- `--republish <ids>` → (publish only) forces re-posting IDs already present in a `published_to` record for the same PR URL. Adds a new record.

---

## Phase 0: KB Discovery (all modes)

1. Determine `project` and `kb_path` via config before using legacy discovery.
2. Read `.ai-dev-team.local.yml` first. `.ai-dev-team.local.yml` is the local override file, should be gitignored in the consumer repo, and `.ai-dev-team.local.yml overrides .ai-dev-team.yml`.
3. Read `.ai-dev-team.yml` second. Compact shared-config fallback anchor: `.ai-dev-team.yml → memory → sibling heuristic → ask`
4. Supported config shape:

```yaml
kb_path: /absolute/path/to/knowledge-base
project: my-project-name

# Optional Codex MCP overrides (propagate into cross-auditor)
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
11. After legacy discovery succeeds, if `.ai-dev-team.yml` does not exist in the repo root, prompt: **"Save `kb_path` and `project` to `.ai-dev-team.yml` so future sessions skip discovery? [Y/n]"**. On yes: write a file with the resolved fields (copy-and-substitute from `.ai-dev-team.yml.example` if present). If the file exists but lacks one of these fields, print a one-line warning — never overwrite user config automatically.
12. Also read `codex.model` and `codex.reasoning_effort`. Pass them into the cross-auditor dispatch as `codex_model` and `codex_reasoning_effort`. If absent, cross-auditor uses its built-in defaults.
13. Also read the optional `github:` block from `.ai-dev-team.local.yml` (account identities are personal, not team-shared — so this block lives in the local override file, not the team-shared `.ai-dev-team.yml`). Shape:

```yaml
github:
  default_account: personal
  accounts:
    personal:
      token_env: GH_TOKEN_PERSONAL
    corp:
      token_env: GH_TOKEN_CORP
      host: github.company.com
```

The block is optional. When present, it enables multi-account auth routing for PR-mode audits and publish: Phase 0.5 resolves one account per invocation and every subsequent `gh` call in the PR-audit surface is prefixed with `GH_TOKEN="${<token_env>}" GH_HOST="<host>"` so the credential is scoped to that subprocess without mutating global `gh auth` state. Resolution precedence (see Phase 0.5 for the full matrix):

`precedence: --account flag → URL host match → default_account → ambient gh auth`

When the `github:` block is absent, Phase 0.5 skips account resolution entirely and every `gh` call runs bare — existing single-account users are unaffected.

**New audit**: generate `audit_slug` = `YYYY-MM-DD-<scope-slug>`.
**Re-audit**: extract `audit_slug` from the existing findings doc filename — strip the path prefix and `-findings.md` suffix (e.g. `…/2026-04-14-workflow-definitions-findings.md` → `2026-04-14-workflow-definitions`). Do NOT regenerate from the current date; the slug must match the original to write to the same file.

---

## Phase 0.5: PR discovery (PR mode only)

Runs only when `$ARGUMENTS` selected the `pr <N>` / `pr owner/repo#<N>` / `pr <url>` form. Produces the five fields (`pr_number`, `pr_repo`, `pr_url`, `pr_head_oid`, `pr_changed_files`) that Phase 1-2 threads into the cross-auditor dispatch. Skipped entirely for non-PR audits — they still use the legacy `<scope>` path.

### Preflights (hard-stop on failure — never silent fallback)

1. **`gh` authentication**: `gh auth status`. Absent or unauthenticated → stop with remediation `gh auth login` / `gh auth refresh -s repo`. Never pretend the audit ran.
2. **REST rate budget**: `gh api rate_limit -q '.rate.remaining'`. If `remaining < 50`, stop with the output of `gh api rate_limit` (reset time included). Audit + publish together consume ≈3-5 REST calls.
3. **cwd-repo matches pr_repo**: once `pr_repo` is resolved (see below), run `gh repo view --json nameWithOwner -q '.nameWithOwner'` inside the caller's cwd. If that value ≠ `pr_repo`, stop with remediation "Run `/cross-audit pr <N>` from a clone of `<pr_repo>` (currently in `<cwd_repo>`)". Rationale: the cross-auditor's isolated worktree is derived from caller's cwd; `gh pr checkout` only succeeds when the local repo targets `pr_repo`.

### Resolve pr_number / pr_repo / pr_url / headRefOid

Parse the argument form:
- `pr <N>`: `pr_number = N`. Run `gh repo view --json nameWithOwner -q '.nameWithOwner'` in cwd → `pr_repo`. If cwd is not a gh-known repo, stop.
- `pr owner/repo#<N>`: split on `#` → `pr_repo`, `pr_number`.
- `pr <url>`: parse `https://github.com/<owner>/<repo>/pull/<N>` → `pr_repo`, `pr_number`.

Then fetch PR metadata and capture `headRefOid`:

```
gh pr view <pr_number> --repo <pr_repo> \
  --json number,url,baseRefName,headRefName,headRefOid,headRepositoryOwner,headRepository,baseRepository
```

- Extract `.url` → `pr_url`, `.headRefOid` → `pr_head_oid`. Both are threaded into the cross-auditor input.
- `headRepositoryOwner` may differ from `baseRepository.owner` (fork PR). The cross-auditor materializes PR content via `gh pr checkout --force` which fetches the fork remote — fork PRs are first-class. Do NOT fall back to local `git diff`.

### Fetch pr_changed_files (authoritative, paginated)

GitHub's `/pulls/{N}/files` endpoint caps at 100 without pagination; `gh pr view --json files` silently truncates at 100. Always use the paginated REST endpoint with an explicit jq projection that preserves `status`, `previous_filename`, and `patch_present` (the raw `patch` text is stripped — `is_submodule` is resolved in the worktree, see `agents/cross-auditor.md`):

```
gh api "repos/<pr_repo>/pulls/<pr_number>/files" \
  --paginate \
  --jq '.[] | {filename, status, previous_filename, patch_present: (.patch != null)}'
```

Collect the resulting line-delimited JSON objects into the `pr_changed_files` list of objects (not strings). This list is the single source of truth for the audit's "Files to audit" and for publish routing.

### Dispatch into cross-auditor

In addition to the fields documented in Phase 1-2 below, thread:
- `pr_number: <N>`
- `pr_repo: <owner/repo>`
- `pr_url: <url>`
- `pr_head_oid: <sha>` — headRefOid captured above
- `pr_changed_files: [ {filename, status, previous_filename, patch_present}, ... ]`

The cross-auditor persists all five into findings frontmatter (plus a `pr_files` list with per-file `is_submodule` resolved inside the worktree). Publish reads those fields back from KB — it never re-runs Phase 0.5 itself.

---

## Phase 1-2: Background Audit + Consolidation

**DO NOT block the main conversation.** Dispatch to `cross-auditor` agent immediately.

### Step 1: Determine parameters

From `$ARGUMENTS` derive:
- **scope**: files/directories/feature area
- **mode**: `logic` | `security` | `full`
- **severity_floor**: `high` (default) | `medium+` — from `--severity` flag
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
severity_floor: [high|medium+]
codex_model: [from config, if set]
codex_reasoning_effort: [from config, if set]
kb_path: [kb_path]
project: [project]
audit_slug: [audit_slug]
iteration: [N]
base_branch: [branch, if diff mode]
previously_fixed: [list of IDs, if re-audit]
working_directory: [cwd]

[PR mode only — populated from Phase 0.5:]
pr_number: [N]
pr_repo: [owner/repo]
pr_url: [https://github.com/.../pull/N]
pr_head_oid: [headRefOid sha]
pr_changed_files: [ {filename, status, previous_filename, patch_present}, ... ]

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
3. **Stop and wait** for user decision per finding — present the banner below.

---
## ⏸ AWAITING YOUR INPUT

Cross-audit finished. Decide per finding:

- `fix X1 X3` — apply fixes
- `accept X2` — known issue, intentional
- `defer X4` — address later
- `fix all` — fix everything
- `publish X1 X3` — (PR mode only) post findings as GitHub PR review comments. Creates one `gh api` POST to `/repos/<pr_repo>/pulls/<N>/reviews` that bundles inline + body comments. `publish all` defaults to `OPEN` / `REOPENED` only. Publish is orthogonal to the status state machine — it does NOT flip OPEN→FIXED. See `references/publish.md` for the full recipe (force-push preflight, `pr_files` routing, failure matrix, `published_to` record schema).

**How should each finding be handled?**

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
