# Cross-auditor: Codex dispatch + Step 1 — Launch Codex

This file holds the canonical content for the `## Codex dispatch (background CLI + polling)` and `## Step 1: Launch Codex` sections of `agents/cross-auditor.md`. The hub keeps one-line pointers per spec 2026-05-10-cross-auditor-bloat-refactor §3.5; the body below was moved verbatim from the hub during Step 5 of that refactor, with two cross-file directional references rewritten per §3.5a (sources at original L309/L311).

## Codex dispatch (background CLI + polling)

Codex audits run via the `${CLAUDE_PLUGIN_ROOT}/hooks/lib/codex_audit_dispatch.sh` helper invoked through `Bash(run_in_background: true)`. This bypasses the Claude Code 600s stream watchdog (hardcoded, not configurable) that caused recurring stalls when using the blocking Codex MCP tool — Codex on `xhigh` reasoning takes 8-15 minutes wall-clock, exceeding the 600s window. Background bash launch returns a `shell_id_codex` immediately; polling `BashOutput(shell_id_codex)` resets the watchdog on each call while Codex thinks in the background.

**Polling discipline**: after launching Codex in background, proceed to Step 2 (Claude's own audit). Each Read/Grep/Glob/Bash tool call during Step 2 is itself a stream event that resets the watchdog, so the watchdog is naturally kept alive during active audit work. To be safe, call `BashOutput(shell_id_codex)` explicitly between significant blocks of Step 2 work and at the start of Step 3 Consolidation to flush any Codex output and confirm the shell is still running. Do NOT wait to poll only at the very end — if Codex finishes early, an explicit BashOutput poll between Step 2 sub-tasks lets you detect completion sooner.

**Fail-open**: if `codex_audit_dispatch.sh exits non-zero` (BashOutput status `failed` or non-zero exit code), capture the captured stderr as the error message, mark Codex status FAILED in the workdoc header, call `KillShell(shell_id_codex)` to clean up, then proceed with Claude-only audit.

**xhigh reasoning preserved** per user directive 2026-04-26: do NOT lower `codex_reasoning_effort`.

## Step 1: Launch Codex (background CLI dispatch — before your own deep review)

**IMPORTANT**: Launch Codex FIRST in the background so both audits run in parallel.

**Step 1a — Build the prompt text** using the appropriate template below (substitute all `[placeholders]`). For diff mode, first run `git diff --name-only <range_spec>` (or `<base_branch>...HEAD`) in `working_directory` (the content root — caller cwd in-place, or the skill-materialized worktree for PR/`--materialize`/`--worktree`), NOT the agent's spawn cwd, and include the resulting file list.

**Step 1b — Write prompt to a temp file and launch Codex in background**:
1. Write the prompt text to a temp file via `Bash`: `PROMPT_FILE=$(mktemp) && cat > "$PROMPT_FILE" << 'CODEX_PROMPT_EOF' ... CODEX_PROMPT_EOF`
2. Set `CODEX_MODEL` (from `codex_model` input if provided, else `gpt-5.5`) and `CODEX_EFFORT` (from `codex_reasoning_effort` if provided, else `xhigh`).
3. In **PR mode** (`pr_number` set), `working_directory` IS the skill-materialized PR worktree (post-`gh pr checkout`); use it as `CODEX_WD`. In non-PR mode, also use `working_directory`.
4. Set `OUTPUT_FILE` to a temp path: `OUTPUT_FILE=$(mktemp)`.
5. Launch via `Bash(run_in_background: true)`: `bash "${CLAUDE_PLUGIN_ROOT}/hooks/lib/codex_audit_dispatch.sh" "$CODEX_WD" "$OUTPUT_FILE" "$CODEX_MODEL" "$CODEX_EFFORT" < "$PROMPT_FILE"`
6. Save the returned `shell_id` as `shell_id_codex`.

**Step 1c — Proceed to Step 2**: Codex is now running in the background. Do NOT wait. Proceed immediately to your own audit (Step 2). Poll `BashOutput(shell_id_codex)` between significant blocks of Step 2 work and at the start of Step 3 to keep the watchdog alive and check progress.

When `mode ∈ {security, full}`, before assembling the prompt: parse the frontmatter `rules:` block in `skills/feature/references/code-quality-rules.md`.

Path resolution: do NOT reason out the env-first precedence by hand — invoke the deterministic helper `bash "${CLAUDE_PLUGIN_ROOT}/hooks/lib/resolve_rule_path.sh"` (no args). Cite the env-anchored absolute path, never a bare relative `hooks/lib/...` form — the auditor's cwd during an audit is the target repo, so a bare path would let a target-repo script at the same path shadow the trusted plugin helper. It resolves the path to `code-quality-rules.md`, prints the resolved absolute path and exits `0` on success, or emits `⚠ code-quality-rules.md not reachable` to stderr and exits `3` when the file is unreachable. The helper implements strict env-first: when `${CLAUDE_PLUGIN_ROOT}` is set to an absolute path it resolves UNCONDITIONALLY to `${CLAUDE_PLUGIN_ROOT}/skills/feature/references/code-quality-rules.md` (the env-var path always points at the plugin's own checkout, so target-repo shadowing is structurally impossible); a set-but-empty or relative-path `${CLAUDE_PLUGIN_ROOT}` is treated as unreachable with no relative fallback.

ONLY when `${CLAUDE_PLUGIN_ROOT}` is unset (legacy / dev-mode invocation outside the plugin runtime) does the helper consult the relative path `skills/feature/references/code-quality-rules.md`, AND only when a realpath-guarded `os.path.commonpath` containment test (computed from the helper's own location, not cwd) places it inside the ai-dev-team plugin checkout — so a target-repo shadow file at the same relative path is rejected. Every resolved row additionally requires the target be an existing readable regular file.

If both resolutions fail, emit the existing `⚠ code-quality-rules.md not reachable` warning and skip cluster load. The realpath check (step 2 of fallback) closes the case where `${CLAUDE_PLUGIN_ROOT}` is unset AND a target repo coincidentally has a `skills/feature/references/code-quality-rules.md` file at the same relative path — without realpath verification, the unset-env fallback would still load the wrong file.

Then branch on `project_type`:

- If `project_type` is set to one of `{smart_contract, backend, frontend, data_pipeline}`: filter for entries where `category: security` AND `enforced_by` contains `cross-auditor:security` AND `applies_to` includes `"all"` OR the active `project_type`, then for each matched entry read its body section (`## R<N> —` heading through the next `^---$` divider) and append the body verbatim to the Codex prompt under a new section `### Security R-rule cluster (project_type=<value>):` BEFORE the Files-to-audit list. Pass-through is verbatim — DO NOT paraphrase. Attest `rules_loaded: true` (filtered cluster loaded).
- If `project_type` is explicitly `none` (the declared-typeless literal — a YAML string, distinct from unset/`null`): normalize the active filter's project clause to `"all"` exactly as the unset branch does (rules with `applies_to: ["all"]` load; project-specific rules do not match), BUT emit the informational bullet `- R-rule cluster: all-scope (project_type=none declared)` at the H1 emit location (NOT the degraded warning bullet), and attest `rules_loaded: true`. The declaration is a standing, artifact-visible user acceptance of the typeless scope — it satisfies the degraded-rules acceptance criterion once in config, so it does NOT gate. This branch is consumed BEFORE the unset/non-allowlist catch-all below, so `none` never falls through to the degraded path.
- If `project_type` is unset OR has a non-allowlist value: emit the degraded warning `⚠ R-rule cluster NOT loaded — project_type was unset; security audit running on focus-areas-only fallback. Set project_type in spec frontmatter or .ai-dev-team.yml to activate.` (byte-exact prose; rendered as a bullet at the locked H1 emit location — see "Warning emit location" below) AND normalize the active filter's project clause to `"all"` per `skills/feature/references/code-quality-rules.md` §Taxonomy Trigger A, then run the filter — rules with `applies_to: ["all"]` continue to load; rules with project-specific lists do not match because no specific project_type is set. NOT silent skip; NOT cluster bypass; the filter runs at the normalized scope. Attest `rules_loaded: false` with `rules_reason: 'project_type unset — all-scope rules only, project-specific cluster not active'`.

**Warning emit location**: when the unset/non-allowlist branch above fires, render the warning as one additional bullet line in the findings.md H1 bullet block (the `- Date: / - Iteration: / - Mode: / - Codex: / - Status:` block in `agents/references/cross-auditor-output-format.md` §findings-doc emit contract template). Append immediately after the `- Status: IN PROGRESS` line, in the form `- R-rule cluster: NOT loaded — project_type was unset; security audit running on focus-areas-only fallback. Set project_type in spec frontmatter or .ai-dev-team.yml to activate.`. The bullet is conditional — emitted only when the gate fires; when `project_type` resolves to an allowlist value, the line is omitted entirely. The grep-stable substring `R-rule cluster NOT loaded` matches the prose-spec literal byte-exact; the rendered-bullet substring `R-rule cluster: NOT loaded` (with colon) matches the rendered-output form.

**`rules_loaded:` attestation emit** (file-backed `security`/`full` only): after resolving the branch above, emit exactly one canonical `rules_loaded: <true|false>` key into the leading findings.md frontmatter (sibling of `audited_head:`), per the truth table in `agents/references/cross-auditor-evidence-handshake.md` §Rules-loaded attestation contract — all five rows:

- allowlist `project_type` (filtered cluster loaded) → `rules_loaded: true` (no `rules_reason:`).
- Trigger B (frontmatter parse fail → EVERY body section loaded verbatim) → `rules_loaded: true` (no `rules_reason:`).
- explicit `project_type: none` (declared typeless) → `rules_loaded: true` (no `rules_reason:`).
- `project_type` unset / non-allowlist-non-`none` (normalized-`"all"` scope) → `rules_loaded: false` with `rules_reason: 'project_type unset — all-scope rules only, project-specific cluster not active'`.
- resolver exit 3 (`code-quality-rules.md not reachable` — NO rules loaded) → `rules_loaded: false` with `rules_reason: 'code-quality-rules.md not reachable'`.

Sanitize every `rules_reason:` value via the §YAML-safety serialization blocker rule (newline→space, truncate-to-199 + `…`, `'`→`''`, single-quoted) before emit; when `rules_loaded: true`, OMIT `rules_reason:` entirely. `logic` mode and spec/decision inline returns emit NEITHER key — the loader never runs there.

If the frontmatter parse fails (Trigger B), emit the stderr warning and load every body section regardless of filter; the Codex prompt receives the full set under the same heading. If `code-quality-rules.md` is not reachable at the env-var path (i.e. `${CLAUDE_PLUGIN_ROOT}` is set but the file is missing under it), emit the warning directly — no relative fallback when env is set, per the strict env-first precedence above. The relative-path fallback fires ONLY when `${CLAUDE_PLUGIN_ROOT}` is unset AND the relative-path-with-realpath check also fails. In either unreachable case, emit `⚠ code-quality-rules.md not reachable — applying focus-areas-only fallback per agents/references/cross-auditor-mode-focus.md §security mode bullet lists` and skip the cluster load.

**Code mode** Codex prompt template:
```
AUDIT of [scope] in [project].
Working directory: [working_directory]
Mode: [logic|security|full]
Focus: [paste relevant focus areas from mode, including the standing integration lenses (logic/security/full modes)]
Files to audit: [list paths — Codex reads them directly]
Previously fixed (skip these): [previously_fixed list]
[Severity ladder for mode]. Report [allowed_severities] only.
For each finding: file:line, description, failure class / input domain (the class of inputs/states, not one observed example), concrete fix suggestion (advisory — one hypothesis, not the contract).
Before reporting any finding, verify the file:line claim by re-reading the actual content at the named line. On mismatch, downgrade to MEDIUM with a 'verification mismatch' note or omit the finding entirely.
```

**Spec mode** Codex prompt template:
```
SPEC REVIEW of [spec_path] for project [project].
Working directory: [working_directory]
Mode: spec
Read the spec file at: [spec_path]
[If workdoc_path provided]: Also read the execution workdoc at: [workdoc_path]
  Review it for: completeness of planned fields, coherence with the spec, and sound step sequencing.
[If the spec carries grill_status: ran and a ## Decisions table]: consume the ## Decisions table as a backstop input. For each row, verify the evidence-ref citation RESOLVES — the cited path/line/literal actually exists (NOT semantic adequacy of the evidence, which stays the user's call). Inspect deferred branches (advisory — grill never gates). Report grill-overlap separately.
Codebase-grounded verification + numeric derivation (when the spec asserts concrete code referents, or its design rests on boundary math): do NOT reason about the spec in isolation — open the real code, verify what the spec claims, derive a number on contested boundary math. Three sub-parts:
- Codebase-grounded verification. For every concrete code referent the spec presents as ALREADY EXISTING — a file path, symbol/function name, constant/threshold value, config key, data-structure field, or claim about behavior the spec says is already in the codebase — OPEN the cited code and confirm it exists with the claimed name, value, and semantics. A claimed-existing referent absent from the code → HIGH (the design rests on a referent that isn't there). Referent present but value/semantics DIFFER from the spec's claim (e.g. spec assumes VOTING_PERIOD = 7 days, code says 10; spec assumes a function returns a sorted list, code does not) → HIGH if the design depends on the differing value/semantics, else MEDIUM. Create-carve-out: referents the spec proposes to CREATE — new files/symbols/constants/config keys the implementation will add (e.g. "§5 Step N: add check_foo to tests/helpers.sh", "create src/foo.ts") — are EXPECTED to be absent → do NOT flag their absence; only flag a to-be-created referent when the spec is internally inconsistent about it (a step uses a symbol an earlier step was meant to create but doesn't). The absent→HIGH rule applies ONLY to referents the spec treats as already existing.
- Numeric worked example. When the design rests on boundary math, rounding/precision, off-by-one interval semantics ([) vs (]), or accumulation across iterations/pagination, DERIVE a concrete numeric worked example at/near the boundary using the REAL constants from the code and confirm the design's claimed property holds. A failing derivation is a finding at the severity of the consequence (fund-loss / security → HIGH; correctness → HIGH or MEDIUM). "The design looks sound" without a computed example is insufficient on a contested numeric point.
- Bounding (no over-reach). Ground only claims the spec MAKES and math the design DEPENDS ON — NOT a demand that every spec cite code, nor a mandate to re-derive trivial arithmetic, nor a license to invent referents; a greenfield spec with no concrete code referents and no boundary math leaves this a near-no-op. Stay within the spec-mode severity ladder. DISTINCT from the grill-awareness evidence-ref RESOLVES line above (which covers only grilled ## Decisions citations), and OFFENSIVE — read code to FIND spec-vs-code mismatches — in contrast to the verify-before-report line below, which is DEFENSIVE de-hallucination of reported findings; both coexist.
Focus areas: completeness, clarity, sequencing, correctness, dependency mapping, verification coverage, scope, risk
[Severity ladder for spec mode]. Report [allowed_severities] only.
For each finding: spec section/step reference, description, failure class (the class of spec defects/cases the issue covers, not one example), concrete fix suggestion (advisory — one hypothesis, not the contract).
Before reporting any finding, verify the file:line claim by re-reading the actual content at the named line. On mismatch, downgrade to MEDIUM with a 'verification mismatch' note or omit the finding entirely.
```

**Decision mode** Codex prompt template (decision mode NEVER reads `agents/references/cross-auditor-mode-focus.md`; its entire focus comes from this template — the five clusters below REPLACE the spec-mode generic `Focus areas:` line):
```
DECISION-TRAIL AUDIT of [scope] for project [project].
Working directory: [working_directory]
Mode: decision
Read the audited spec file at: [scope] — its §1 Context/goal, §3 Design, §9 Log decision lines, and (if present) the grill `## Decisions` table.
[If workdoc_path provided]: Also read the execution workdoc at: [workdoc_path]
  Read it for planned/observed divergence — files touched outside `allowed_scope`, notes contradicting the step goal, `change_type_shift` not reflected in the spec §3/§9.
[For EACH findings_paths entry, when the list is non-empty]: Read the findings doc at that path — inspect accept/defer triage rationale (rubber-stamp cluster + the findings-portion of decision coherence). An empty/absent findings_paths list is not an error; audit whatever exists.
You are auditing the DECISION TRAIL of a completed /feature run (spec §9 Log, grill `## Decisions` table, workdoc planned/observed + `design_decision` fields, findings triage statuses, `*_audit_evidence` frontmatter) — NOT the code. Premise re-derivation OPENS and READS the source code under [working_directory] (no execution, no re-implementation) to test whether each recorded decision's premise behaves as assumed.
Decision focus clusters (decision coherence is the center; premise verification is the second layer):
1. Decision coherence (mode center). Two classes:
   (a) Local-optimum / crutch-stacking — a decision fixes the symptom at hand while eroding the architecture; signals: patches layered on one spot (same defect class across 2+ audit iterations, REOPEN sweeps, fixup pileups per step), workaround-on-workaround, `design_decision` entries of the "bypassed X because faster" shape. Flag the design-level flaw underneath, not the Nth patch.
   (b) Goal-trajectory divergence — the task was set toward X but the cumulative decision vector leads to Y; compare spec §1 Context/goal against the sum of Log decisions, scope-extensions, `change_type_shift`, and `design_decision` entries. Both classes HIGH when load-bearing.
2. Premise re-derivation (anti-oracle-bias), bounded. Every recorded decision is the implementer's HYPOTHESIS, not a verified fact. Three levels: (L1) the referent exists (extends the "citations resolve" check); (L2) the referent BEHAVES as the decision assumes — open and read the code, no execution, no re-implementation; (L3) a numeric worked-example only when the decision hinges on arithmetic/boundaries. L2 refuted with code evidence → CRITICAL; L2 unconfirmable from artifacts + code → HIGH (honest "false" vs "unproven" split).
3. Rubber-stamp detection. Deterministic signals, each cited by artifact line: degraded `*_audit_evidence` (`skipped` / `self_fallback` / `contract_violated` / `single_model`); `grill_status` null/skipped while high-risk signals are present (`external_input: true`, `project_type: smart_contract`, payment/auth/migration keywords); residue accepted at the iteration cap without a named residue; accept/defer of CRITICAL/HIGH findings with vacuous rationale; `attack-surface profile not applicable` on a spec with an evident network surface; all-defaults accumulation across banner decisions on a large feature.
4. Fork analysis. Decisions at real forks (multiple viable designs visible from the artifacts/code) with no recorded alternative or tradeoff.
5. Planned/observed divergence. Workdoc observed-vs-planned drift (files outside `allowed_scope`, notes contradicting the step goal, `change_type_shift`) not reflected in spec §3/§9 — a step-level feeder for the Decision-coherence crutch-stacking class.
Previously fixed (skip these): [previously_fixed list]
Severity ladder (decision mode):
- CRITICAL: a load-bearing decision resting on a demonstrably false premise (L2 refuted with code evidence) affecting shipped behavior.
- HIGH: decision-coherence classes 1a/1b at load-bearing scale; an unverified load-bearing premise (L2 unconfirmable); a rubber-stamped gate on a high-risk surface; vacuous accept/defer of a CRITICAL/HIGH finding (the only vacuous-rationale form that gates).
- MEDIUM: fork analysis (no recorded alternatives); all other vacuous-rationale forms; unlogged planned/observed drift; all-defaults accumulation.
Report [allowed_severities] only.
For each finding: artifact-line reference (spec §9 Log line / workdoc field / findings-doc ID), description, failure class (the class of decisions/cases the issue covers, not one example), concrete fix suggestion (advisory — one hypothesis, not the contract).
Before reporting any finding, verify the file:line claim by re-reading the actual content at the named line. On mismatch, downgrade to MEDIUM with a 'verification mismatch' note or omit the finding entirely.
```

### Diff-mode reading contract

For **diff mode**: the changed-file list defines WHICH files are in scope, NOT how much of each file to read.
When `range_spec` is set, run `git diff --name-only <range_spec>` (single shell-quoted string; may include `-- <path>` suffix) in `working_directory` (the content root — caller cwd in-place, or the skill-materialized worktree for PR/`--materialize`/`--worktree`), NOT the agent's spawn cwd. Otherwise when `base_branch` is set, run `git diff --name-only <base_branch>...HEAD` in `working_directory` (legacy behavior).
Include the resulting file list as "Files to audit" in the prompt template above before writing the prompt to `$PROMPT_FILE`.

When the audit is diff-scoped — `range_spec` set, `base_branch` set, OR PR mode (`pr_number` set, file list derived from `pr_changed_files` / `build_pr_files.sh`) — Step 1a MUST append the following block verbatim to the Codex prompt, immediately after the `Files to audit:` line of the Code-mode template. The Code-mode template is the only insertion point needed: it is the sole template carrying a diff-derived file list (spec/decision modes read documents, not diffs — no `Files to audit:` line exists there by design):

```
Diff-scope reading contract: the files listed above are the CHANGED set; they define WHICH files to audit, NOT how much of each to read. For every changed file, read the WHOLE file, not just the changed hunks. Identify and read the incumbent/replaced/bridged code path even when it lies outside the diff — the unchanged formula the new path must reproduce, framework autodiscovery/registration semantics no diff line shows, unchanged readers (serializers, APIs, reports) of rows the change writes. Differential reasoning against that incumbent is a REQUIRED part of the audit (Differential-vs-incumbent lens): state what the incumbent does, what the new path does, and whether they agree. Cite the incumbent files you read, including files outside the diff.
```

**Step 1 result at Step 3**: at the start of Step 3 Consolidation, poll `BashOutput(shell_id_codex)` until status is `completed`, `failed`, or `killed`. On `completed`: read `$OUTPUT_FILE` for Codex's final response. **If `codex_audit_dispatch.sh exits non-zero` (BashOutput status `failed` or non-zero exit code from polling)**: capture the stderr output, call `KillShell(shell_id_codex)`, mark Codex status FAILED in the workdoc header, proceed with Claude-only audit. Prepend to the consolidated findings: `⚠️ WARNING: Codex audit unavailable (<error reason>). All findings are single-source (Claude only). Re-run when Codex CLI dispatch is restored.`

<!-- end §Step 1 -->
