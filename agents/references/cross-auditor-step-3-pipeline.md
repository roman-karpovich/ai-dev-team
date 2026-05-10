# Cross-auditor: Step 3 — Consolidation

This file holds the canonical content for the `## Step 3: Consolidation` section of `agents/cross-auditor.md`. The hub keeps a one-line pointer per spec 2026-05-10-cross-auditor-bloat-refactor §3.5; the body below was moved verbatim from the hub during Step 4 of that refactor, with three cross-file directional references rewritten per §3.5a (sources at original L368/L371/L404).

## Step 3: Consolidation

After both audits complete, merge findings:

| Situation | Action |
|-----------|--------|
| Both found same issue | **HIGH CONFIDENCE** — definitely fix |
| Only Claude found it | REVIEW — could be false positive or deep insight |
| Only Codex found it | REVIEW — could be false positive or deep insight |
| Severity disagreement | Use the HIGHER severity |
| Contradicting assessments | Investigate the code yourself to determine who's right |

Do NOT filter out `previously_fixed` items before consolidation — they are verified in Step 4. Skip items from `accepted_ids` (ACCEPTED/DEFERRED — don't re-report these as new findings).

**Semantic suppression (re-audit only)**: if the findings file already exists, read all entries with status ACCEPTED or DEFERRED. Before assigning a new ID to a candidate finding, check if it describes the same issue as any ACCEPTED/DEFERRED entry (same file:line or same root cause). If so: skip it entirely — the user has already made a deliberate decision about that issue. Do not create a new ID for it.

### Step 3 pipeline (5 stages, per spec 2026-04-21-cross-audit-probes-foundation §3.5 + §3.5a + §3.7)

After Claude+Codex collection (Steps 1-2 (see `agents/cross-auditor.md` §Step 1 + §Step 2)), run the following five-stage pipeline before any findings.md write:

1. **Claude + Codex findings collected** — today's Step 1/2 output merges under legacy rules above.
2. **Probe findings appended (from Step 0.5 output)** — iterate over `probe_findings[]` produced by Step 0.5 (not a skill-threaded input — see `agents/cross-auditor.md` §Step 0.5). For each `finding_dict`, emit one combined-list entry with `id = finding_dict["provisional_id"]` AND `provisional_id = finding_dict["provisional_id"]` — the two keys hold the same string pre-allocation so `${CLAUDE_PLUGIN_ROOT}/hooks/lib/dedupe_findings.sh` (which dereferences `m["id"]` unconditionally) accepts the input (iter-5 X22). `sources: ["probe:" + metadata["probe_id"]]` where `metadata = probe_receipt_metadata_by_provisional_id[finding_dict["provisional_id"]]` (iter-4 X19 side-map lookup — NOT a field on the combined-list entry). `blocking` derived from `mode_at_emit` per iter-3 X13 rule (`shadow → false`, `warn → false`, `block → true`; receipt-level `degraded_mode: true` downgrades blocking to false at render time via `render_findings.sh`). Carry `severity`, `title`, `file`, `description`, `fix`, `fingerprint_anchors`, `canonical_payload` from `finding_dict`; carry `mode_at_emit`, `probe_version`, `eligible_reason` from `metadata`. Set `probe_receipt: None` — populated in stage 4.5 after final-ID allocation. No-op when `probe_findings[]` is empty.
3. **Structured dedupe via `${CLAUDE_PLUGIN_ROOT}/hooks/lib/dedupe_findings.sh`** — pipe the combined list through the helper. Probe+LLM entries with matching fingerprints merge into single entries carrying `sources: ["probe:<id>", "claude" | "codex"]` per §3.3 X2 contract. Partial matches get mutual `related_to[]` cross-references without merging.
4. **Haiku decoupled scoring via `haiku-finding-scorer` agent** (Task tool) — new in Foundation:
   - Filter the deduped list to **pure-LLM entries only** (no `probe:*` in `sources[]`). Probe-sourced findings (including merged probe+LLM) pin `confidence: 100` inline and skip the scorer entirely.
   - If the pure-LLM subset is **empty** (X1 rule 1): SKIP the scorer call entirely. Emit `scorer_status: ok` and no degraded-mode banner line. Renderer receives no scorer output.
   - Batch cap: **20 findings per Task-tool invocation** (X1 rule 3). If the pure-LLM subset has >20 entries, chunk into consecutive 20-finding batches preserving IDs; emit one Task-tool call per chunk; merge the returned `scores` maps (disjoint IDs by construction).
   - **60-second timeout per chunk** (X1 rule 4). Timeout → chunk failure → whole-iteration fail-open (rule 2 behaviour).
   - Invoke the Task tool with the `agents/haiku-finding-scorer.md` agent name. Pass the input JSON per the agent's I/O contract — `findings: [...]` with the pure-LLM subset (each carrying `sources`, `severity`, `file`, `line`, `description`, `fix_suggestion`, `diff_slice`, `multi_source_note`), plus `claude_md_paths: [...]` resolved inside the audit worktree.
   - `multi_source_note` (X8 contract): when `len(sources) >= 2`, set it to a string of form `"also raised by: <other source(s) joined by ', '>"` from the perspective of `sources[0]` (e.g. `sources: ["claude", "codex"]` → `"also raised by: codex"`). When `len(sources) == 1`, set it to `null`.
   - **Mock seam** (X7): when the environment variable `CROSS_AUDIT_SCORER_MOCK_JSON` is set to a filesystem path, **replace** the Task-tool invocation by reading that file's JSON as the scorer response. The mock file is treated EXACTLY as a real scorer response — subject to every validation rule below. Production invocations leave the env var unset.
   - **Validation rules** (X1 rule 2 — any violation triggers whole-iteration fail-open):
     - Response is valid JSON and a top-level object with a `scores` key.
     - `scores` is an object with EXACTLY one entry per finding ID sent in input — no missing IDs, no extras, no duplicates.
     - Each entry has an integer `confidence` in the range 0–100 and a non-empty string `rationale`.
     - No stray top-level keys.
   - On validation pass: merge each `scores[id].confidence` back onto the matching pure-LLM finding (write the `confidence` field; rationale is discarded — not persisted into findings.md).
   - On validation fail OR Task-tool error OR rate limit OR timeout: **whole-iteration fail-open**. Fall back to the legacy `HIGH`/`REVIEW` label and map:
     - HIGH (`len(sources) >= 2`) → `confidence: 90`
     - REVIEW (`len(sources) == 1`) → `confidence: 60`
     Set `legacy_pseudo_confidence: true` on each affected pure-LLM entry (NEVER on merged probe+LLM entries — probe pins `confidence: 100` independently). Emit `scorer_status: failed` + `scorer_failure_reason: "<reason>"` on renderer stdin. Renderer renders the degraded-mode banner's scorer-unavailable line; all pure-LLM entries land in Summary (advisory section suppressed under scorer-failed mode).
4.5. **Probe receipt files written (stage 4.5 — spec 2026-04-21-probe-e-diff-scope-leak §3.5 / X14 renumbering)** — runs between Foundation stage 4 (scorer) and Foundation stage 5 (probe_failures synthesis). After final finding-ID allocation, walk the deduped+scored `final_findings` list; for each finding that is probe-sourced, write its receipt file to disk at `<kb>/repos/<project>/security/<audit_slug>-probe-receipts/<finding_id>.json` per Foundation §3.3 per-finding contract (X1 resolution).

   - **Probe-sourced predicate** (Foundation §3.3 X2 / iter-3 X18): `any(s.startswith("probe:") for s in finding["sources"])`. NOT `sources[0]`-only — merged probe+LLM entries may reorder sources.
   - **Side-map lookup**: `metadata = probe_receipt_metadata_by_provisional_id[finding["provisional_id"]]`. `provisional_id` is guaranteed present here — stage 2 emit sets it alongside `id` (iter-5 X22); `${CLAUDE_PLUGIN_ROOT}/hooks/lib/dedupe_findings.sh merge_pair` preserves it through probe+LLM merges (iter-5 X23 carried-field list); stage 4.5 id-swap (iter-5 X24) sets `finding["id"] = <allocated_id>` WHILE preserving `finding["provisional_id"]` intact. Only stage 4.5 itself MAY drop `provisional_id` post-write; render does not consume it.
   - **`hashed_probe_output_envelope`** (3 fields, iter-3 X17 distinction): `{probe_id, probe_version, emitted_findings: [finding["canonical_payload"]]}`. sha256 of `json.dumps(envelope, sort_keys=True, separators=(",", ":"), ensure_ascii=False)` → `probe_output_hash`.
   - **`on_disk_receipt_body`** (11 fields per iter-4 X21 — `skipped_files` is the 11th body field, NOT in the hashed envelope): `{probe_id, probe_version, mode_at_emit, trigger_input_hash, probe_output_hash, degraded_mode, emitted_at, eligible_reason, scope_files_read, skipped_files, emitted_findings}`. Built as `{**metadata, probe_output_hash, mode_at_emit: finding["mode_at_emit"], emitted_findings: hashed_probe_output_envelope["emitted_findings"]}`. Serialized with the same `json.dumps` parameters as the hashed envelope; the written bytes differ because the body has 8 additional fields.
   - **Write path + fail-open class 6** (X4 resolution — sixth fail-open branch): `receipt_path = <kb>/repos/<project>/security/<audit_slug>-probe-receipts/<finding["id"]>.json`. On `IOError` / `OSError` during write, append an entry `{probe_id: metadata["probe_id"], reason: "receipt write failed: …", remediation: "check KB mount is writable + re-run /cross-audit"}` to `probe_failures_seed[]`; set `finding["probe_receipt"] = None` (finding stays in findings.md; degraded-mode banner line renders). On success: `finding["probe_receipt"] = receipt_path`.

5. **`probe_failures[]` synthesis from degraded-mode receipts** (X18 producer contract): walk `probe_receipts[]`; for each receipt with `degraded_mode: true`, emit one item `{probe_id, reason, remediation}` into `probe_failures[]`:
   - `reason` = receipt's optional `failure_reason` if set and non-empty string; otherwise generic fallback `"probe produced degraded_mode=true without surfacing reason/remediation strings"`.
   - `remediation` = receipt's optional `failure_remediation` if set and non-empty string; otherwise generic fallback `"check probe logs in <receipt path>; re-run when probe is fixed"`.
   Consumer (renderer, ${CLAUDE_PLUGIN_ROOT}/hooks/lib/render_findings.sh) hard-stops on malformed `probe_failures[]` per §3.3 X10 — orchestrator MUST emit all three required fields as non-empty strings.
   **Union with Step-0.5 / stage-4.5 seed** (spec 2026-04-21-probe-e-diff-scope-leak §3.5 / iter-4 X20): compose the final `probe_failures[]` as `synth_probe_failures(probe_receipts) + probe_failures_seed`. Probe E v1 has no happy-path `degraded_mode: true` receipts (every fail-open branch bails BEFORE `probe_receipts.append`), so the Foundation synthesis is a no-op for v1; the seed carries every fail-open entry. Forward-compat: future probes that emit `degraded_mode: true` alongside valid findings will be caught by the Foundation path.
6. **Render via `${CLAUDE_PLUGIN_ROOT}/hooks/lib/render_findings.sh`** — pipe `{findings: <scored+deduped>, probe_modes, probe_failures: <synthesized>, scorer_status, scorer_failure_reason}` through the helper. Helper output is the full findings.md body. Step 4 (`agents/references/cross-auditor-output-format.md`) writes the final file with frontmatter.
