# Cross-auditor: Codex dispatch + Step 1 — Launch Codex

This file holds the canonical content for the `## Codex dispatch (background CLI + polling)` and `## Step 1: Launch Codex` sections of `agents/cross-auditor.md`. The hub keeps one-line pointers per spec 2026-05-10-cross-auditor-bloat-refactor §3.5; the body below was moved verbatim from the hub during Step 5 of that refactor, with two cross-file directional references rewritten per §3.5a (sources at original L309/L311).

## Codex dispatch (background CLI + polling)

Codex audits run via the `${CLAUDE_PLUGIN_ROOT}/hooks/lib/codex_audit_dispatch.sh` helper invoked through `Bash(run_in_background: true)`. This bypasses the Claude Code 600s stream watchdog (hardcoded, not configurable) that caused recurring stalls when using the blocking Codex MCP tool — Codex on `xhigh` reasoning takes 8-15 minutes wall-clock, exceeding the 600s window. Background bash launch returns a `shell_id_codex` immediately; polling `BashOutput(shell_id_codex)` resets the watchdog on each call while Codex thinks in the background.

**Polling discipline**: after launching Codex in background, proceed to Step 2 (Claude's own audit). Each Read/Grep/Glob/Bash tool call during Step 2 is itself a stream event that resets the watchdog, so the watchdog is naturally kept alive during active audit work. To be safe, call `BashOutput(shell_id_codex)` explicitly between significant blocks of Step 2 work and at the start of Step 3 Consolidation to flush any Codex output and confirm the shell is still running. Do NOT wait to poll only at the very end — if Codex finishes early, an explicit BashOutput poll between Step 2 sub-tasks lets you detect completion sooner.

**Fail-open**: if `codex_audit_dispatch.sh exits non-zero` (BashOutput status `failed` or non-zero exit code), capture the captured stderr as the error message, mark Codex status FAILED in the workdoc header, call `KillShell(shell_id_codex)` to clean up, then proceed with Claude-only audit.

**xhigh reasoning preserved** per user directive 2026-04-26: do NOT lower `codex_reasoning_effort`.

## Step 1: Launch Codex (background CLI dispatch — before your own deep review)

**IMPORTANT**: Launch Codex FIRST in the background so both audits run in parallel.

**Step 1a — Build the prompt text** using the appropriate template below (substitute all `[placeholders]`). For diff mode, first run `git diff --name-only <range_spec>` (or `<base_branch>...HEAD`) and include the resulting file list.

**Step 1b — Write prompt to a temp file and launch Codex in background**:
1. Write the prompt text to a temp file via `Bash`: `PROMPT_FILE=$(mktemp) && cat > "$PROMPT_FILE" << 'CODEX_PROMPT_EOF' ... CODEX_PROMPT_EOF`
2. Set `CODEX_MODEL` (from `codex_model` input if provided, else `gpt-5.5`) and `CODEX_EFFORT` (from `codex_reasoning_effort` if provided, else `xhigh`).
3. In **PR mode** (`pr_number` set), use the absolute path of this agent's isolated worktree post-`gh pr checkout` as `CODEX_WD`. In non-PR mode, use `working_directory`.
4. Set `OUTPUT_FILE` to a temp path: `OUTPUT_FILE=$(mktemp)`.
5. Launch via `Bash(run_in_background: true)`: `bash "${CLAUDE_PLUGIN_ROOT}/hooks/lib/codex_audit_dispatch.sh" "$CODEX_WD" "$OUTPUT_FILE" "$CODEX_MODEL" "$CODEX_EFFORT" < "$PROMPT_FILE"`
6. Save the returned `shell_id` as `shell_id_codex`.

**Step 1c — Proceed to Step 2**: Codex is now running in the background. Do NOT wait. Proceed immediately to your own audit (Step 2). Poll `BashOutput(shell_id_codex)` between significant blocks of Step 2 work and at the start of Step 3 to keep the watchdog alive and check progress.

When `mode ∈ {security, full}`, before assembling the prompt: parse the frontmatter `rules:` block in `skills/feature/references/code-quality-rules.md`.

Path resolution: when `${CLAUDE_PLUGIN_ROOT}` is set (always set in normal Claude Code execution per the plugin runtime contract), resolve UNCONDITIONALLY to `${CLAUDE_PLUGIN_ROOT}/skills/feature/references/code-quality-rules.md`. The env-var path always points at the plugin's own checkout, so target-repo shadowing is structurally impossible.

ONLY fall back to the relative path `skills/feature/references/code-quality-rules.md` when `${CLAUDE_PLUGIN_ROOT}` is unset (legacy / dev-mode invocation outside the plugin runtime), AND ONLY when `realpath` of the relative path resolves inside the ai-dev-team plugin checkout (i.e. the target repo IS the plugin — self-anchoring case verified at runtime, not assumed).

If both resolutions fail, emit the existing `⚠ code-quality-rules.md not reachable` warning and skip cluster load. The realpath check (step 2 of fallback) closes the case where `${CLAUDE_PLUGIN_ROOT}` is unset AND a target repo coincidentally has a `skills/feature/references/code-quality-rules.md` file at the same relative path — without realpath verification, the unset-env fallback would still load the wrong file.

Then branch on `project_type`:

- If `project_type` is set to one of `{smart_contract, backend, frontend, data_pipeline}`: filter for entries where `category: security` AND `enforced_by` contains `cross-auditor:security` AND `applies_to` includes `"all"` OR the active `project_type`, then for each matched entry read its body section (`## R<N> —` heading through the next `^---$` divider) and append the body verbatim to the Codex prompt under a new section `### Security R-rule cluster (project_type=<value>):` BEFORE the Files-to-audit list. Pass-through is verbatim — DO NOT paraphrase.
- If `project_type` is unset OR has a non-allowlist value: emit the degraded warning `⚠ R-rule cluster NOT loaded — project_type was unset; security audit running on focus-areas-only fallback. Set project_type in spec frontmatter or .ai-dev-team.yml to activate.` (byte-exact prose; rendered as a bullet at the locked H1 emit location — see "Warning emit location" below) AND normalize the active filter's project clause to `"all"` per `skills/feature/references/code-quality-rules.md` §Taxonomy Trigger A, then run the filter — rules with `applies_to: ["all"]` continue to load; rules with project-specific lists do not match because no specific project_type is set. NOT silent skip; NOT cluster bypass; the filter runs at the normalized scope.

**Warning emit location**: when the unset/non-allowlist branch above fires, render the warning as one additional bullet line in the findings.md H1 bullet block (the `- Date: / - Iteration: / - Mode: / - Codex: / - Status:` block in `agents/references/cross-auditor-output-format.md` §findings-doc emit contract template). Append immediately after the `- Status: IN PROGRESS` line, in the form `- R-rule cluster: NOT loaded — project_type was unset; security audit running on focus-areas-only fallback. Set project_type in spec frontmatter or .ai-dev-team.yml to activate.`. The bullet is conditional — emitted only when the gate fires; when `project_type` resolves to an allowlist value, the line is omitted entirely. The grep-stable substring `R-rule cluster NOT loaded` matches the prose-spec literal byte-exact; the rendered-bullet substring `R-rule cluster: NOT loaded` (with colon) matches the rendered-output form.

If the frontmatter parse fails (Trigger B), emit the stderr warning and load every body section regardless of filter; the Codex prompt receives the full set under the same heading. If `code-quality-rules.md` is not reachable at the env-var path (i.e. `${CLAUDE_PLUGIN_ROOT}` is set but the file is missing under it), emit the warning directly — no relative fallback when env is set, per the strict env-first precedence above. The relative-path fallback fires ONLY when `${CLAUDE_PLUGIN_ROOT}` is unset AND the relative-path-with-realpath check also fails. In either unreachable case, emit `⚠ code-quality-rules.md not reachable — applying focus-areas-only fallback per agents/references/cross-auditor-mode-focus.md §security mode bullet lists` and skip the cluster load.

**Code mode** Codex prompt template:
```
AUDIT of [scope] in [project].
Working directory: [working_directory]
Mode: [logic|security|full]
Focus: [paste relevant focus areas from mode]
Files to audit: [list paths — Codex reads them directly]
Previously fixed (skip these): [previously_fixed list]
[Severity ladder for mode]. Report [allowed_severities] only.
For each finding: file:line, description, concrete fix suggestion.
```

**Spec mode** Codex prompt template:
```
SPEC REVIEW of [spec_path] for project [project].
Working directory: [working_directory]
Mode: spec
Read the spec file at: [spec_path]
[If workdoc_path provided]: Also read the execution workdoc at: [workdoc_path]
  Review it for: completeness of planned fields, coherence with the spec, and sound step sequencing.
Focus areas: completeness, clarity, sequencing, correctness, dependency mapping, verification coverage, scope, risk
[Severity ladder for spec mode]. Report [allowed_severities] only.
For each finding: spec section/step reference, description, concrete fix suggestion.
```

For **diff mode**: scope the audit to changed files only.
When `range_spec` is set, run `git diff --name-only <range_spec>` (single shell-quoted string; may include `-- <path>` suffix). Otherwise when `base_branch` is set, run `git diff --name-only <base_branch>...HEAD` (legacy behavior).
Include the resulting file list as "Files to audit" in the prompt template above before writing the prompt to `$PROMPT_FILE`.

**Step 1 result at Step 3**: at the start of Step 3 Consolidation, poll `BashOutput(shell_id_codex)` until status is `completed`, `failed`, or `killed`. On `completed`: read `$OUTPUT_FILE` for Codex's final response. **If `codex_audit_dispatch.sh exits non-zero` (BashOutput status `failed` or non-zero exit code from polling)**: capture the stderr output, call `KillShell(shell_id_codex)`, mark Codex status FAILED in the workdoc header, proceed with Claude-only audit. Prepend to the consolidated findings: `⚠️ WARNING: Codex audit unavailable (<error reason>). All findings are single-source (Claude only). Re-run when Codex CLI dispatch is restored.`

<!-- end §Step 1 -->
