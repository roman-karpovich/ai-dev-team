# Cross-auditor: Step 0 (PR mode only) + Step 0.5 — Probe dispatch

This file holds the canonical content for the `## Step 0 (PR mode only): Materialize PR content into the skill-materialized PR worktree` and `## Step 0.5: Probe dispatch (runs inside materialized worktree)` sections of `agents/cross-auditor.md`. The hub keeps a one-line pointer per spec 2026-05-10-cross-auditor-bloat-refactor §3.5; the body below was moved verbatim from the hub during Step 6 of that refactor, with three internal directional references rewritten per §3.5a + the Step 4 design decision sweep deliverable (each `Step 3 Consolidation` / `Step 3 stage 4.5` mention now points at the canonical reference file `agents/references/cross-auditor-step-3-pipeline.md`).

## Step 0 (PR mode only): Materialize PR content into the skill-materialized PR worktree

Runs only when `pr_number` is set. Skip entirely otherwise.

The caller's cwd is **not** a safe source of audit content — it may be on a different branch, have uncommitted work, or (for fork PRs) lack the fork head commits entirely. All PR audit content lives in the PR worktree provided via `working_directory` (skill-materialized).

1. Inside the PR worktree provided via `working_directory` (skill-materialized), before any file read, run `gh pr checkout`:

   ```
   gh pr checkout <pr_number> --detach --force --repo <pr_repo>
   ```

   `--detach` checks out the PR head commit without touching any branch ref (branch refs are shared across all worktrees of one repo, so a non-detached checkout could force-reset a branch the primary worktree holds); `--force` lets the checkout proceed over local state; `--repo <pr_repo>` makes `gh` fetch the fork remote automatically for fork PRs. The worktree HEAD is now the PR head commit (detached).
2. Verify the checkout landed on the expected commit:
   ```
   test "$(git rev-parse HEAD)" = "<pr_head_oid>"
   ```
   If not equal, hard-stop: the PR was force-pushed between Phase 0.5 and this checkout. Surface remediation "PR force-pushed since preflight; re-run `/cross-audit pr <N>` to refresh" and exit non-zero. Do not fall back to the local working copy.
3. Use `pr_changed_files[*].filename` verbatim as the "Files to audit" list (relative to this worktree). Do NOT call local `git diff`. Do NOT read any file from the caller's cwd in PR mode.
4. Build the `pr_files` list by resolving `is_submodule` per file inside this worktree. For each `pr_changed_files[]` entry, run `git ls-tree HEAD -- <filename>`:
   - mode `160000` (gitlink) → `is_submodule: true`
   - any other mode, or empty output (filename absent from the PR head tree) → `is_submodule: false`
   There is no patch-text fallback — the `--jq` projection in the skill's Phase 0.5 strips the raw `patch` text (spec X25). Writing is delegated to the pure shell helper `${CLAUDE_PLUGIN_ROOT}/hooks/lib/build_pr_files.sh`, which takes the `pr_changed_files` JSON on stdin and a single `--ls-tree-output <path>` pointing at the concatenated `git ls-tree HEAD -- <f1> <f2> ...` output, and emits the canonical YAML block on stdout. Agent prompt must invoke that exact helper path — tests/smoke.sh exercises the same path as a writer-contract golden diff.

   The helper's expected output shape (canonical key order) is:

   ```yaml
   pr_files:
     - filename: src/foo.rs
       status: modified
       previous_filename: null
       patch_present: true
       is_submodule: false
     - filename: vendor/submod
       status: modified
       previous_filename: null
       patch_present: false
       is_submodule: true
   ```

   Fields, in order: `filename:` / `status:` / `previous_filename:` / `patch_present:` / `is_submodule:`.

## Step 0.5: Probe dispatch (runs inside materialized worktree)

Per spec 2026-04-21-probe-e-diff-scope-leak §3.5 (X2 resolution — dispatch pivoted from skill Phase 1.5 into this agent so probes read the Step-0-materialized PR worktree, not the caller's cwd). For spec/code mode (no PR), Step 0 is a no-op and Step 0.5 runs against `working_directory` (the content root — caller cwd in-place, or the materialized worktree for `--materialize`/`--worktree`).

Runs after Step 0 (PR materialization, if PR mode) and BEFORE Step 1 (Codex launch). Produces three in-memory outputs consumed later in `agents/references/cross-auditor-step-3-pipeline.md` §Step 3 Consolidation:

- `probe_receipts[]` — happy-path receipt_metadata dicts for degraded-mode synthesis backstop (Foundation §3.7 X18).
- `probe_findings[]` — canonical-payload findings with `mode_at_emit` attached (pre-ID allocation).
- `probe_failures_seed[]` — six-way fail-open entries (X4 + iter-2 X11 resolutions) with populated `probe_id` / `reason` / `remediation` triples.
- `probe_receipt_metadata_by_provisional_id{}` — side-map (iter-4 X19) keyed by `provisional_id` carrying `receipt_metadata` from Step 0.5 to `agents/references/cross-auditor-step-3-pipeline.md` §Step 3 stage 4.5 (dedupe/scorer strip unknown fields between stages).

Pseudocode (§3.5):

```
probe_receipts = []                                     # happy-path metadata dicts
probe_findings = []                                     # findings with canonical_payload, pre-ID
probe_failures_seed = []                                # fail-open entries (X20 — sole v1 artefact)
probe_receipt_metadata_by_provisional_id = {}           # side-map (X19)

for probe_id, mode in probe_modes.items():
  if mode == "off": continue                            # off-floor enforcement
  probe_script = f"${{CLAUDE_PLUGIN_ROOT}}/hooks/lib/probe_{probe_id}.sh"
  if not exists(probe_script):                          # fail-open class 1: script missing
    probe_failures_seed.append({
      "probe_id": probe_id,
      "reason": f"probe script {probe_script} not found",
      "remediation": "update ai-dev-team plugin or remove probe_modes entry",
    })
    continue
  input_json = build_probe_input(probe_id)
  # build_probe_input packs {diff, changed_python_files, changed_shell_files,
  # changed_yaml_files, repo_root, base_ref, audit_slug, mode}. Diff acquisition:
  # git diff <base_ref>...HEAD --name-only + -U0 hunks inside the worktree;
  # hunks parsed into diff.added_lines = {file: set-of-added-linenos}.
  try:
    output_raw = run(probe_script, stdin=input_json, timeout=60s)
  except TimeoutError as e:                             # fail-open class 2: timeout
    probe_failures_seed.append({
      "probe_id": probe_id,
      "reason": f"probe exceeded 60s timeout: {str(e)[:200]}",
      "remediation": f"re-run /cross-audit; if persistent, shrink audit scope or file probe_{probe_id} performance bug",
    })
    continue
  except NonZeroExit as e:                              # fail-open class 3: non-zero (subsumes uncaught Python exceptions — interpreter exits non-zero)
    probe_failures_seed.append({
      "probe_id": probe_id,
      "reason": f"probe exited non-zero: {str(e)[:200]}",
      "remediation": f"re-run /cross-audit after checking probe_{probe_id} stderr logs",
    })
    continue
  try:
    result = json.loads(output_raw)
  except JSONDecodeError as e:                          # fail-open class 4: JSONDecode
    probe_failures_seed.append({
      "probe_id": probe_id,
      "reason": f"probe stdout not valid JSON: {str(e)[:200]}",
      "remediation": f"fix probe_{probe_id} to emit canonical JSON",
    })
    continue
  schema_ok, schema_err = validate_probe_output_schema(result)
  if not schema_ok:                                     # fail-open class 5: schema invalid
    probe_failures_seed.append({
      "probe_id": probe_id,
      "reason": f"probe output schema invalid: {schema_err}",
      "remediation": f"fix probe_{probe_id} to conform to §3.3 stdout shape",
    })
    continue
  # Happy path — transport metadata via side-map keyed by provisional_id (iter-4 X19).
  for f in result["findings"]:
    f["mode_at_emit"] = mode
    probe_receipt_metadata_by_provisional_id[f["provisional_id"]] = result["receipt_metadata"]
    probe_findings.append(f)
  probe_receipts.append(result["receipt_metadata"])
```

`validate_probe_output_schema(result)`: returns `(True, None)` iff `result` is an object with both `findings` (list) and `receipt_metadata` (object) keys; each `findings[]` element is an object carrying `provisional_id` (string), `sources` (list), `severity` (string), `title` (string), `file` (string), `description` (string), `fix` (string), `fingerprint_anchors` (object), `canonical_payload` (object); `receipt_metadata` carries `probe_id` (string), `probe_version` (string), `trigger_input_hash` (string), `scope_files_read` (list), `skipped_files` (list), `emitted_at` (string), `degraded_mode` (bool), `eligible_reason` (string). Any violation returns `(False, "<short error>")`.

**Fail-open coverage** (spec 2026-04-21-probe-e-diff-scope-leak §3.5): six classes explicitly handled as distinct branches — probe-script-missing, TimeoutError, NonZeroExit (subsumes uncaught Python exceptions — the interpreter exits non-zero), JSONDecodeError, schema validation failure, receipt-write IOError/OSError (class 6 lives later in `agents/references/cross-auditor-step-3-pipeline.md` §Step 3 stage 4.5). Each class synthesizes a `probe_failures_seed[]` entry with a populated `probe_id` / `reason` / `remediation` triple. The renderer's existing hard-stop on malformed `probe_failures[]` (Foundation §3.3 X10) is the backstop — Step 0.5 MUST emit fully-populated string triples.
