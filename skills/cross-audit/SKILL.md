---
name: cross-audit
description: Iterative cross-audit with Claude + Codex working independently then consolidating findings. Runs in background — does not block the main conversation.
argument-hint: "<scope description OR path to existing findings doc> [--diff] [--mode logic|security|full] [--severity high|medium+]"
---

# Cross-Audit: Background Parallel Review

Cross-audit runs Claude (Opus) and Codex (GPT-5.5) as independent auditors, consolidates their findings into KB documents, then iterates until clean. **Runs in the background** so you can continue working.

/cross-audit runs in background — you can keep working while it runs

User-input prompt presentation in this skill follows the banner
convention in `docs/user-input-banner-convention.md` — the per-finding
decision fork in Phase 3 carries the `AWAITING YOUR INPUT` banner.

### Caveman activation in this flow

Caveman compression is mandatory in this flow. The wire prefix `[COMPRESSION:terse]` MUST be prepended to every subagent Task description and to every Codex MCP `developer-instructions:` field within this flow. Machine-output payloads (haiku scorer JSON, `render_findings` / `dedupe_findings` IO, parser inputs) are exempt per `skills/caveman/SKILL.md` §7.

## Argument Parsing

**Re-audit detection**: if `$ARGUMENTS` matches `*-findings.md` AND the file exists on disk → **re-audit iteration**. If it looks like a path but doesn't exist → error out and ask the user. Otherwise → **new audit**.

**PR-mode detection**: if `$ARGUMENTS` starts with `pr <N>`, `pr owner/repo#<N>`, or `pr <url>` → **PR audit**. Skip legacy scope parsing; run Phase 0.5 (below) to resolve `pr_repo` / `pr_url` / `pr_number` and fetch `pr_changed_files`. Three accepted input forms:
- `pr <N>` (bare number, e.g. `pr 472`) — resolve repo via `gh repo view --json nameWithOwner` in the caller's cwd; if cwd is not a gh-known repo, stop with remediation.
- `pr owner/repo#<N>` (e.g. `pr roman-karpovich/ai-dev-team#472`) — repo taken from the `owner/repo` prefix.
- `pr <url>` (e.g. `pr https://github.com/roman-karpovich/ai-dev-team/pull/472`) — repo and number parsed from the URL.

**Standalone publish**: `/cross-audit publish <slug> <ids>` is a second entry point that invokes the `publish` action against an existing findings doc resolved from `<slug>` (e.g. `2026-04-14-webhooks`). Skips Phases 0.5 / 1-2 / 3-fix; jumps straight into publish using the `pr_files` / `pr_head_oid` / `pr_url` persisted in findings frontmatter. See `references/publish.md` for the full recipe. Publish is orthogonal to the status state machine — it does NOT flip OPEN→FIXED.

**Ref-range detection**: if `$ARGUMENTS` contains `..` (literal two-dot) or `...` (literal three-dot) forming a `<refA>..<refB>` or `<refA>...<refB>` pattern AND both `<refA>` and `<refB>` resolve via `git rev-parse --verify <ref>` AND neither half is empty → **ref-range mode**. Optional path filter suffix `-- <path>` is preserved verbatim. Detection uses the literal `..` substring; disambiguation from path scopes containing `..` (e.g. `../sibling/`) relies on the rev-parse preflight — such paths fail to resolve and fall through to legacy scope parsing. Hard-stops: invalid ref (either half fails `git rev-parse --verify`) → error "ref does not exist: <ref>"; refA and refB resolve to the same SHA → error "no changes between refs". Two-dot (`..`) and three-dot (`...`) semantics follow `git diff` conventions — the operator is passed through verbatim. The ref-range resolver helper (`hooks/lib/cross_audit_resolve_range.sh`) is the single source of parsing + validation logic; call it in this branch and hard-stop on non-zero exit.

**Flags** (orthogonal to each other):
- `--diff` → scope the audit to files changed since `base_branch` (default: auto-detected repo default, falls back to `main`). Can combine with any mode: e.g. `--diff --mode logic` audits only changed files using logic focus areas.
- `--mode logic|security|full` → audit mode (default: `full`)
- `--severity high|medium+` → severity floor (default: `high`). `high` collects only CRITICAL/HIGH (current behavior). `medium+` also includes MEDIUM — useful for small features where serious findings are unlikely but nitpick-level review is still valuable.
- `--force-publish-stale` → (publish only) bypasses the force-push preflight when the current PR `headRefOid` has diverged from the audit-time `pr_head_oid`. Records the stale OID in `head_oid_at_publish` for audit trail. See `references/publish.md`.
- `--republish <ids>` → (publish only) forces re-posting IDs already present in a `published_to` record for the same PR URL. Adds a new record.
- `--materialize=worktree` → (ref-range mode only) create a temporary worktree at `refB` (`git worktree add /tmp/cross-audit-<audit_slug> <refB>`) so the cross-auditor reads file content from `refB` rather than the current working tree. Cleanup: `git worktree remove --force` + `rm -rf` at audit end (best-effort). Default off (no materialization). Anti-combinations: PR mode + `--materialize` → hard-stop ("PR mode already materializes via `gh pr checkout`; `--materialize` is for ref-range only"); non-ref-range scope + `--materialize` → warn ("`--materialize` is a no-op outside ref-range mode") and proceed.

**Removed-flag hard-fail** (per `docs/cut-spec-policy.md`). If `$ARGUMENTS` contains either of the flags below, hard-stop with the corresponding canonical error message — do NOT attempt to interpret the argument or silently drop it:

- `--probe-downgrade` → emit `ERROR: --probe-downgrade was removed in cut spec design/2026-04-26-cut-probe-downgrade.md. Read that spec for the migration path.`
- `--account` → emit `ERROR: --account was removed in cut spec design/2026-04-27-cut-multi-gh-account.md. Read that spec for the migration path.`

---

## Phase 0: KB Discovery

KB discovery algorithm (resolving `kb_path` and `project` via `.ai-dev-team.local.yml → .ai-dev-team.yml → memory → sibling → ask`) follows `docs/kb-discovery.md` — single source of truth.

### Cross-audit extensions

Cross-audit reads `codex.model` and `codex.reasoning_effort` from the resolved config and passes them into the cross-auditor dispatch.

#### `cross_audit.probes.<id>.mode` read (probes kill-switch)

Phase 0 also reads the optional `cross_audit.probes` block from the resolved config. Each probe id (`e`, `f`, `g`, and any future id) carries a four-mode kill-switch — `off | shadow | warn | block`. The resolved `probe_modes` dict (probe id → effective mode) is threaded into the cross-auditor dispatch in Phase 1-2.

- **Default off**: when `cross_audit.probes` is absent from the resolved config, OR a given probe id is missing under `cross_audit.probes`, the effective mode defaults to `off`. Absence is a user-declared floor, not a synthesized gap (per §3.4 X9 resolution).
- **Unknown probe id → warning, not hard-stop**: when the YAML names a probe id the plugin does not recognize (e.g. `h: { mode: shadow }`), emit a one-line warning `cross_audit.probes.<id>: unknown probe id, treated as off — ignored for this run` and continue. Probes are a forward-looking enum; new ids arrive in follow-up specs without needing a Foundation re-release. Unknown-id emissions never hard-stop Phase 0.
- **Mode enumeration**: the four allowed values are `off|shadow|warn|block`. Any other string emits the same one-line warning and falls back to `off`.

See `docs/kb-discovery.md` for the canonical YAML schema and `docs/kb-discovery.md` → "cross_audit.probes.<id>.mode kill-switch" for the full mode semantics (shadow section routing, blocking semantics, Phase 3 presentation).

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
- **range_spec**: for ref-range mode — the full diff range string passed verbatim to `git diff --name-only`, e.g. `v1.7.0...v2.0.2` or `v1.7.0..v2.0.2 -- subdir/`. Formatted by joining `<op>` with refA/refB: `<refA><op><refB>` (then appending ` -- <path_filter>` if path_filter is non-empty).
- **materialize_mode**: `worktree` when `--materialize=worktree` was given; unset otherwise.
- **previously_fixed**: if re-audit, extract from existing findings doc
- **project_type**: detect from codebase (smart_contract, backend, frontend, data_pipeline)
- **iteration**: 1 for new audit, N+1 for re-audit
- **kb_path**: from discovery above
- **project**: project name
- **audit_slug**: `YYYY-MM-DD-<scope-slug>` (new audit) or extracted from the existing findings filename (re-audit — see Phase 0). For ref-range mode: `YYYY-MM-DD-range-<sanitized-refA>__<sanitized-refB>` where sanitization replaces `[^a-zA-Z0-9._-]` with `-` and caps each half at 60 chars (produced by `cross_audit_resolve_range.sh`'s `slug_pair` output).

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
range_spec: [range_spec, if ref-range mode]
previously_fixed: [list of IDs, if re-audit]
working_directory: [cwd]

[PR mode only — populated from Phase 0.5:]
pr_number: [N]
pr_repo: [owner/repo]
pr_url: [https://github.com/.../pull/N]
pr_head_oid: [headRefOid sha]
pr_changed_files: [ {filename, status, previous_filename, patch_present}, ... ]

[Probe plumbing — populated from Phase 0:]
probe_modes: [dict mapping probe id → effective mode resolved from the cross_audit.probes YAML kill-switch; empty dict when no probe configured]
# probe_receipts is NO LONGER threaded by the skill — probe dispatch happens
# inside the cross-auditor agent at Step 0.5 (spec 2026-04-21-probe-e-diff-
# scope-leak §3.5 / X2); receipts are produced there.

[If re-audit: include the current findings doc path for context]
```

**Ref-range materialization** (when `materialize_mode == worktree`): before dispatching, create the worktree: `git worktree add /tmp/cross-audit-<audit_slug> <refB>`. Pass `working_directory: /tmp/cross-audit-<audit_slug>` to the cross-auditor. Register cleanup: after audit completion (or on error), run `git worktree remove --force /tmp/cross-audit-<audit_slug>` then `rm -rf /tmp/cross-audit-<audit_slug>` (best-effort — failure is logged, not fatal). When `materialize_mode` is unset and neither refA nor refB equals HEAD, emit one warning line before dispatch: "⚠️ Reading file content from current working tree (not from <refB>). Use `--materialize=worktree` for precise content at refB."

### Step 3: Inform the user

> Cross-audit running in background on **[scope]** (mode: [mode], iter [N]).
> Findings → `KB/repos/<project>/security/<slug>-findings.md`
> Continue working — I'll present results when both auditors finish.

---

## Phase 3: Present & Decide (foreground, interactive)

When cross-auditor completes:

0. **Apply the §3.4 recovery algorithm** to the agent's raw return before step 1 — this is callsite 5 of the 6 §3.4 recovery callsites (the standalone `/cross-audit` Phase 1-2 initial dispatch). The recovery algorithm body is canonical in `skills/feature/SKILL.md` §3.5b-2; the standalone-mode specifics are in the §Cross-auditor return-contract gate subsection below. Classifier output gates whether the findings.md read in step 1 proceeds, or the §3.4d standalone terminal banner fires.
1. Read the findings doc from KB
2. Present to user:
   - Count by severity and confidence
   - HIGH CONFIDENCE findings first (both auditors agreed)
   - REVIEW findings second (one auditor only)
3. **Stop and wait** for user decision per finding — present the banner below.

### Cross-auditor return-contract gate

Standalone `/cross-audit` runs the same return-contract recovery as the feature flow. After the cross-auditor returns (Phase 1-2 initial dispatch — callsite 5 — and Phase 5 re-audit re-spawn — callsite 6), the orchestrator:

1. **Captures the raw response atomically** to `<kb>/repos/<project>/security/<audit_slug>-contract-violation-iter<N>-attempt<M>.raw.txt` per the §3.5b-1 atomic-write protocol in `skills/feature/SKILL.md`.
2. **Invokes the classifier** — `invoke hooks/lib/check_dispatch_response.py --mode <spec|code|full> --raw-response-file <captured-.raw.txt-path> --audit-slug <slug> --iteration <N>` (plus `--findings-path <path>` for code/full mode). The `--project` flag is passed ONLY when KB-discovery resolution finds `.ai-dev-team.*yml project: ai-dev-team` — standalone callsites do not assume `ai-dev-team` otherwise.
3. **Writes a sidecar JSON** atomically at `<kb>/repos/<project>/security/<audit_slug>-contract-violation-iter<N>-attempt<M>.json` AFTER classification — standalone mode has no spec frontmatter to write `*_audit_evidence` into, so the **two-file pair** (`.raw.txt` + sidecar JSON) is the persistent record. The sidecar shape is **exit-code aware** — the orchestrator reads step 2's exit code first: on classifier exit 0/1 the `classifier_output` field is the classifier's stdout JSON and `classifier_exit` records `0`/`1`; on classifier exit 2 (crash — empty stdout, no JSON) `classifier_output` is `null`, `classifier_exit` is `2`, and `classifier_stderr` carries the classifier's stderr truncated to 1000 chars. The `raw_response` field carries the raw response embedded inline when its byte count ≤ 65536 (64 KiB), or `null` plus a `raw_response_path` reference otherwise (independent of the classifier exit code — the raw response is captured in step 1, before classification). On sidecar-write failure → capture-failure banner (the §3.5b-2c capture-failure banner in `skills/feature/SKILL.md`) and STOP.
4. **Branches on the classifier exit code** — the same four-way branch as the feature skills/feature/SKILL.md §3.5b-2 recovery algorithm (step 4), adapted for standalone mode (no spec frontmatter; the `.raw.txt` + sidecar JSON pair is the persistent record):
   - **Exit `2`** (classifier crash — empty stdout, no JSON; the classifier's own failure) → the **standalone classifier-crash banner** below. This is a single-attempt diagnostic — it does NOT use the two-attempt §3.4d template, because an exit-2 crash on the initial dispatch produced no classifier JSON to populate `attempt-1`/`attempt-2` with.
   - **Exit `0` AND `policy_gate: null`** → **PROCEED** to the findings.md read (step 1 above).
   - **Exit `0` AND `policy_gate: STOP_AND_DISCUSS`** (arises standalone when `--project ai-dev-team` was passed and the classification is `CLEAN_SINGLE`) → the **standalone project-policy gate banner** below.
   - **Exit `1`** (any of the 10 violation classifications) → enter the §3.5b-2b retry-outcome matrix (one bounded TRANSPORT retry). If the retry recovers (`CLEAN_DUAL`, or consumer-project `CLEAN_SINGLE`), PROCEED. If the retry is an unrecovered SAME-violation / DIFFERENT-violation, OR the retry's classifier itself crashes (classifier exit-2 on the retry — §3.5b-2b Matrix A's third terminal row), route to the §3.4d standalone terminal banner below. The retry's classifier-exit-2 outcome is NOT the same as an exit-2 on the INITIAL dispatch: an initial-dispatch crash produced no classifier JSON and uses the single-attempt classifier-crash banner above; a crash on the RETRY has an attempt-1 violation classification to present and routes to the two-attempt §3.4d banner.

#### Standalone classifier-crash banner

The classifier (`hooks/lib/check_dispatch_response.py`) exited 2 — its own failure, distinct from a contract violation (we cannot tell whether the cross-auditor's response was valid). Single attempt, no classifier JSON:

---
## ⏸ AWAITING YOUR INPUT

`hooks/lib/check_dispatch_response.py` exited 2 (classifier crash) on the cross-audit return. Stderr:

```
<classifier stderr verbatim, truncated to 1000 chars>
```

Raw response captured to `<raw-path-attempt-1>` for manual inspection. Options:

1. **Re-run the classifier with `--debug`** (full traceback to stderr; you diagnose) — no auto-retry.
2. **Manual review of the raw output** — read `<raw-path-attempt-1>`; if findings can be salvaged, paste manually into Phase 3 triage.
3. **Re-run `/cross-audit`** from scratch (treats the crash as a transient transport failure).

**Which option?**

---

#### Standalone project-policy gate banner

The classifier returned `CLEAN_SINGLE` with `policy_gate: STOP_AND_DISCUSS` — Claude-only audit (Codex stalled), and `--project ai-dev-team` resolved, so project policy `feedback_ai_dev_team_dual_model_cross_audit_always.md` requires dual-model evidence. Standalone has no spec frontmatter to write, so the options are expressed in standalone terms:

---
## ⏸ AWAITING YOUR INPUT

Cross-audit returned `CLEAN_SINGLE` — Claude-only audit (Codex stalled with reason: `<reason>`). For the ai-dev-team project, policy requires dual-model cross-audit evidence.

Options:

1. **Re-spawn cross-auditor** to retry Codex (may take 8-15 min; TRANSPORT retry). Re-spawn outcome governed by the §3.5b-2b Matrix B branch — `CLEAN_DUAL` recovers and the audit PROCEEDs; `CLEAN_SINGLE` again re-renders this banner; a violation routes to the §3.4d standalone terminal banner.
2. **Accept single_model** for this audit — proceed to Phase 3 triage with the Claude-only findings; the sidecar JSON records `CLEAN_SINGLE` as the audit evidence.
3. **Abandon this audit** — no findings recorded; consider escalating the Codex outage.

**Which option?**

---

#### §3.4d Standalone terminal banner

For the SAME-violation / DIFFERENT-violation / classifier-exit-2-on-retry branches of the §3.5b-2b retry-outcome matrix in standalone mode — i.e. an Exit-1 violation that the one bounded retry did NOT recover (no spec frontmatter — the `.raw.txt` + sidecar JSON pair is the persistent record). This is the standalone counterpart of the feature-mode §3.5b-2d terminal banner; both halves of the handshake terminate symmetrically. This banner is restricted to the unrecovered-after-retry case: it covers an Exit-2 classifier crash on the RETRY (attempt-1 still carries a violation classification to present), but an Exit-2 classifier crash on the INITIAL dispatch — which produced no attempt-1 classifier JSON — uses the standalone classifier-crash banner above, not this template.

---
## ⏸ AWAITING YOUR INPUT

Cross-audit contract violation — auto-respawn attempted, classifier output:
- attempt-1: `<initial-classification>` — `<initial-blocker>` (captures: `<raw-path-attempt-1>` + `<sidecar-path-attempt-1>`)
- attempt-2: `<retry-classification-or-crash>` — `<retry-blocker>` (captures: `<raw-path-attempt-2>` + `<sidecar-path-attempt-2>`)

When attempt-2 is a classifier crash, `<retry-classification-or-crash>` reads `classifier exit-2 (crash on retry)` and `<retry-blocker>` carries the §3.5b-2b Matrix A blocker `['<initial-blocker>'; 'classifier crash on retry: <stderr-excerpt>']`.

Options:
1. **Manual review of raw output** — read the sidecar JSON(s); if findings can be salvaged from the raw response, paste manually into Phase 3 triage.
2. **Re-run `/cross-audit`** with adjusted scope (smaller diff / different mode) to retry from scratch.
3. **Abandon this audit** — no findings recorded; consider whether the underlying truncation pattern needs a BACKLOG #51 incident update.

**Which option?**

---

### Shadow & low-confidence sections (informational, non-banner)

Per spec 2026-04-21-cross-audit-probes-foundation §3.5a + §3.8, findings.md carries up to three sections — `## Summary`, `## Shadow findings (informational)`, and `## Low-confidence LLM findings (advisory)`. Phase 3 renders each:

- `## Shadow findings (informational)`: probe findings with `mode_at_emit: shadow` (including merged probe+LLM findings whose probe half is in shadow per §3.5a routing cascade step 1). These are NOT surfaced in the decision banner — the user is not asked for a per-finding decision on them. They are rendered as read-only informational content in the findings doc.
- `## Low-confidence LLM findings (advisory)`: pure-LLM findings (no `probe:*` in `sources[]`) with `confidence < 80` (X11 resolution). These are also NOT surfaced in the decision banner; they live in findings.md for context and calibration review.
- Both sections are omitted from findings.md entirely when empty (the renderer handles this; skill relays the count only when the section has entries).

**Banner footer lines**: the decision banner gains up to two footer lines, each added by the skill at Phase 3 presentation time:

- Shadow footer (emitted when the shadow section has ≥1 entry): `N shadow-mode findings — see <findings_path>#shadow-findings`
- Advisory footer (emitted when the advisory section has ≥1 entry): `M low-confidence LLM findings (advisory) — see <findings_path>#low-confidence-llm-findings-advisory`

Both footers coexist when both sections are non-empty; each footer is omitted when its section is empty. Together these footers enforce §3.5a's miscalibration-risk mitigation (advisory entries stay visible even though they are suppressed from per-finding decisions).

---
## ⏸ AWAITING YOUR INPUT

Cross-audit finished. Decide per finding:

- `fix X1 X3` — apply fixes
- `accept X2` — known issue, intentional
- `defer X4` — address later
- `fix all` — fix everything
- `publish X1 X3` — (PR mode only) post findings as GitHub PR review comments. Creates one `gh api` POST to `/repos/<pr_repo>/pulls/<N>/reviews` that bundles inline + body comments. `publish all` defaults to `OPEN` / `REOPENED` only. Publish is orthogonal to the status state machine — it does NOT flip OPEN→FIXED. See `references/publish.md` for the full recipe (force-push preflight, `pr_files` routing, failure matrix, `published_to` record schema).

[If shadow section non-empty:] `N shadow-mode findings — see <findings_path>#shadow-findings`
[If advisory section non-empty:] `M low-confidence LLM findings (advisory) — see <findings_path>#low-confidence-llm-findings-advisory`

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
3a. **Apply the §3.4 recovery algorithm** to the re-spawn's classifier output before step 4 — this is callsite 6 of the 6 §3.4 recovery callsites (the standalone Phase 5 re-audit re-spawn). Per the §Cross-auditor return-contract gate subsection above: capture the raw return, invoke `hooks/lib/check_dispatch_response.py`, write the sidecar JSON, and branch on the classifier exit code. Classifier output gates whether fix-verification in step 4 proceeds, or the §3.4d standalone terminal banner fires.
4. Agent **verifies each fix** (reads file:line, confirms fix is present) and looks for new issues
   - Confirmed fixes → VERIFIED
   - Absent or broken fixes → REOPENED
5. On completion: findings doc updated, new workdoc-iter<N>.md created, present delta

### Convergence
- **COMPLETE** when no CRITICAL or HIGH findings remain OPEN or REOPENED
- Typically 2-4 iterations

---

## Audit findings handling

If the user's request references an audit-findings document (a file under `<kb>/repos/<project>/security/`, or mentions specific finding IDs like "X3", "H1", "починим N из findings", "fix audit item N"), do NOT dive into the code directly. First ask: "оформить как spec через `/feature new` или чинить напрямую?" — and wait for the answer. If the user chooses spec, invoke `/feature new` citing the finding. If they choose direct fix, proceed without the flow.

Rationale: the spec-driven flow adds a baseline red test and compliance checks that catch the exact class of bug where a findings doc claims "FIXED" but the code is not. Cheap one line fixes do not need this overhead, but the user should decide — not Claude.

Exception: lines starting with a decision keyword matching `publish|fix|accept|defer` (e.g. `publish X1 X3`, `fix H2`, `accept L4`, `defer M1`) inside an active `/cross-audit` Phase 3 loop are pass-through. Do NOT prompt "spec or direct fix?" in that case; the keyword-prefixed form is an in-flow decision, not a user-initiated finding reference.

## Confirmation cadence

Once agreed to a direction, drive to completion without re-asking. See `docs/confirmation-cadence.md`.

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

Focus areas depend on detected `project_type` and audit mode — see `agents/cross-auditor.md` §Mode Focus Areas for the canonical per-mode list (`logic` / `security` / `full` / `spec`). The SKILL orchestrator selects mode and project_type only; it does not dispatch the focus-areas list itself, so this file deliberately carries no subsections.
