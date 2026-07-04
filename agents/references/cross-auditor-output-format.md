# Cross-auditor: Step 4 — Write Output Documents

This file holds the canonical content for the `## Step 4: Write Output Documents` section of `agents/cross-auditor.md`. The hub keeps the verbatim H2 plus a one-line pointer; this reference carries the findings.md template (frontmatter + H1 bullet block + Summary table + Details block), the workdoc-iterN.md template, the R-rule cluster gate emit contract, the Schema-cut column semantics, and the legacy `Found by` → `sources[]` round-trip mapping.

## Step 4: Write Output Documents

**`spec` and `decision` mode exception**: do NOT write files. Return the consolidated findings as your inline output message to the caller (the feature skill for spec mode, standalone `/cross-audit` for decision mode). Format as a readable markdown report with a summary table and details section — the same structure as findings.md, but returned as the agent response, not written to disk. Spec and decision audit findings are transient — no findings doc is persisted to disk.

**Spec mode re-audit**: if the feature skill runs a second spec audit (e.g. after fixing issues), the caller must pass `previously_fixed: [X1, X2, ...]` with the IDs from the prior inline report. Since spec mode does not persist findings to disk, the agent has no way to auto-detect which issues were already found and fixed. Without this list, the agent will re-report already-fixed issues.

For all other modes (`logic` / `security` / `full`), write TWO documents to the KB. If `kb_path` and `project` are provided:
- findings: `<kb_path>/repos/<project>/security/<audit_slug>-findings.md`
- workdoc: `<kb_path>/repos/<project>/security/<audit_slug>-workdoc-iter<N>.md` (N = iteration number)

Create `repos/<project>/security/` if it doesn't exist.

Each iteration produces a **new** workdoc file (iter1, iter2, …). This way previous iterations are preserved for reference but don't load into context unless needed. The findings file is always a single accumulating document.

### findings.md (persistent — merge with existing if re-audit)

If the findings file already exists (re-audit): read it, preserve all existing entries, then:
- For IDs in `previously_fixed` (currently FIXED): **verify the fix** — read the file:line from the finding detail and confirm the fix is actually present in the current code.
  - Fix confirmed → set status to `VERIFIED`
  - Fix absent, incomplete, or introduced a new problem → set status to `REOPENED`, append a note explaining what is still wrong
- For IDs in `accepted_ids`: leave their status unchanged (ACCEPTED stays ACCEPTED — do NOT flip to FIXED or VERIFIED)
- Append new findings with new IDs continuing the monotonic sequence

**PR mode only**: write `pr_number:` / `pr_repo:` / `pr_url:` / `pr_head_oid:` (all scalars) and the `pr_files:` list into the findings frontmatter on every audit iteration. These fields are the single source of truth for the publish action (`skills/cross-audit/references/publish.md`) and for the standalone `/cross-audit publish <slug> <ids>` entry point — publish runs in caller cwd (not a worktree) and never re-fetches them. `pr_files` is produced by `${CLAUDE_PLUGIN_ROOT}/hooks/lib/build_pr_files.sh` from the `pr_changed_files` input plus in-worktree `git ls-tree HEAD` output. On re-audit, overwrite these fields with the current audit's values (not append) — they describe the PR head at this iteration's audit time.

```markdown
---
title: Audit Findings — <scope>
project: <project>
type: audit-findings
mode: <logic|security|full>
iteration: N
created: YYYY-MM-DD
evidence_class: <value>
evidence_blockers: <YAML-list>
claude_model: <exact model id>
tags: [audit, <project>]
---

# Audit Findings: <scope>
- Date: YYYY-MM-DD
- Iteration: N
- Mode: <mode>
- Codex: OK | FAILED (<reason>)
- Status: IN PROGRESS
<!-- emitted only when project_type unset / non-allowlist — see `agents/references/cross-auditor-mode-focus.md` §R-rule cluster gate; the bullet is conditional, omitted when project_type resolves to an allowlist value -->
- R-rule cluster: NOT loaded — project_type was unset; security audit running on focus-areas-only fallback. Set project_type in spec frontmatter or .ai-dev-team.yml to activate.

## Summary

| ID | Severity | Issue | Source | Mode | Confidence | Status |
|----|----------|-------|--------|------|------------|--------|
| X1 | CRITICAL | ... | claude+codex |  | 90 | OPEN |
| X2 | HIGH | ... | claude |  | 60 | OPEN |

## Details

### [X1] <title>
- **Severity**: CRITICAL
- **Found by**: Both (high confidence)
- **File**: path:line
- **Description**: ...
- **Failure class / input domain**: <the class of inputs/states the failure belongs to — not just one observed example>
- **Fix (advisory)**: ...
- **Sources**: [claude, codex]
- **Mode at emit**: (probe findings only; blank for pure-LLM)
- **Blocking**: false
- **Probe receipt**: (probe findings only; null for pure-LLM)
- **Probe version**: (probe findings only; null for pure-LLM)
- **Eligible reason**: (probe findings only; null for pure-LLM)
- **Status**: OPEN
```

**`failure_class` (optional) + advisory `Fix`**: the details block carries `- **Failure class / input domain**: <class>` — the class of inputs/states the failure belongs to, not one observed example — rendered from the optional finding JSON key `failure_class` (string; rendered empty when the key is absent, so old producers and probe findings stay valid). The `- **Fix (advisory)**:` label marks the suggestion as ONE hypothesis: the remedy derives from the Description + failure class + the code, not from the suggestion's letter. The finding JSON `fix` key is UNCHANGED (render/dedupe parse it); only the rendered label carries `(advisory)`. Legacy findings docs written before this change keep the bare `- **Fix**:` label — nothing parses the label, so mixed `**Fix**:` / `**Fix (advisory)**:` labels across a re-audited findings doc are acceptable.

**R-rule cluster gate emit contract**: the conditional `- R-rule cluster: NOT loaded — ...` bullet shown in the H1 block above is a stable parsable token. It appears only when the cluster gate in `agents/references/cross-auditor-mode-focus.md` §R-rule cluster gate fires (`mode ∈ {security, full}` AND `project_type` unset or non-allowlist); when `project_type` resolves to an allowlist value, the bullet is omitted entirely. Grep-stable forms: the colonless prose-spec literal `R-rule cluster NOT loaded` matches the §R-rule cluster gate prose body; the colonized rendered-bullet literal `R-rule cluster: NOT loaded` matches the rendered findings document. Future tooling (`/feature status`, smoke pins) MAY parse either form.

**Schema-cut column semantics (see spec 2026-04-21-cross-audit-probes-foundation §3.3)**:
- `Source` is a **rendered display column** derived from the authoritative internal `sources[]` list — single element renders verbatim (`claude`, `codex`, `probe:E`), multiple elements render `+`-joined in the list's emission order (`claude+codex`, `probe:E+claude`). The details block carries `**Sources**: [...]` as the authoritative list field; `Source` is NEVER stored as a primitive and is NOT a details-block field.
- `Mode` column mirrors the per-finding `mode_at_emit` value for probe findings (`shadow | warn | block`); blank for pure-LLM findings.
- `Confidence` column semantics:
  - Probe-sourced findings (any `probe:*` in `sources[]`, including merged probe+LLM) pin `100` — deterministic emission; scorer is skipped.
  - Pure-LLM findings (no `probe:*` in `sources[]`) carry an integer 0–100 assigned by the Haiku finding-scorer.

**Legacy `Found by` → `sources[]` round-trip mapping**: when re-auditing a pre-schema-cut findings doc, the renderer maps the legacy `Found by` details value into the authoritative `sources[]` list using the three-case expansion:
- `Found by: Both` → `sources: [claude, codex]`
- `Found by: Only Claude` → `sources: [claude]`
- `Found by: Only Codex` → `sources: [codex]`

The `Source` display column is then re-rendered from `sources[]` (e.g. `claude+codex` for the `Both` case). The legacy literal `Both` string is never emitted as a current-mode value — it exists only as a read-only legacy-doc cell that the renderer migrates on first re-audit.

### workdoc-iterN.md (new file per iteration — previous iterations kept for reference)

File name: `<audit_slug>-workdoc-iter<N>.md`

```markdown
---
title: Audit Workdoc — <scope> (iter N)
project: <project>
type: audit-workdoc
iteration: N
created: YYYY-MM-DD
tags: [audit, workdoc, <project>]
previous_workdoc: <audit_slug>-workdoc-iter<N-1>.md
---

# Audit Work Log: <scope> — Iteration N
- Date: YYYY-MM-DD
- Mode: <mode>

## Files reviewed
- `path/file.rs` — reviewed
- ...

## Codex audit status
<summary of Codex output>

## Claude audit notes
<intermediate observations, what was checked>

## Consolidation notes
<how findings were merged, any disagreements between models>
```
