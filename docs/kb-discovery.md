# KB discovery — Phase 0 shared reference

## Why this exists

Phase 0 resolves two pieces of context that every KB-backed skill needs before it can read, write, or dispatch anything: `kb_path` (absolute path to the Obsidian vault) and `project` (the repo-scoped subdirectory under `<kb>/repos/`). These are user- and machine-specific, so the plugin resolves them through a deterministic fallback chain instead of hard-coding them. This document is the single source of truth for that chain; every participating skill's `SKILL.md` references it and layers only skill-specific extensions on top.

## Precedence order

Per-field resolution runs top-down and stops at the first source that yields a valid value:

`per-field resolution: local → shared → memory → sibling → ask, continue on per-file parse error`

Concretely, for each of `kb_path` and `project` independently:

1. `.ai-dev-team.local.yml` — local override, gitignored in the consumer repo. `.ai-dev-team.local.yml overrides .ai-dev-team.yml`.
2. `.ai-dev-team.yml` — team-shared fallback anchor: `.ai-dev-team.yml → memory → sibling heuristic → ask`.
3. Memory (`memory/reference_kb_<project>.md`).
4. Sibling directory heuristic — scan `ls ../` for a directory whose name contains "knowledge".
5. Ask the user.

If either config file is malformed, missing `kb_path`, or points at a non-existent directory: warn once for that file and continue to the next source in the chain. Do not abort the session on parse error.

## Algorithm

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
7. When config is valid, skip confirmation prompt.
8. When config is valid, do not write to memory.
9. If config does not resolve a field, fall through to legacy discovery:
   - `kb_path`: check `memory/reference_kb_<project>.md`, then look for a sibling directory containing "knowledge" in its name (`ls ../`), then ask the user.
   - `project`: use memory if available, otherwise use the current repo directory name, then ask if ambiguous.

If no valid config resolved `kb_path` and a sibling KB is auto-discovered, confirm with the user before using it. After explicit confirmation in the legacy flow, save `kb_path` and `project` to memory (`reference_kb_<project>.md`).

## Post-discovery yml save prompt

After legacy discovery succeeds (step 9 resolved via memory / sibling / ask), if `.ai-dev-team.yml` does not exist in the repo root, prompt: **"Save `kb_path` and `project` to `.ai-dev-team.yml` so future sessions skip discovery? [Y/n]"**. On yes: write a file containing the resolved `kb_path` and `project` fields (copy-and-substitute from `.ai-dev-team.yml.example` if present). If the file exists but lacks one of these fields, print a one-line warning with the value to add — never overwrite user config automatically.

## Skill extensions — read in addition to the core algorithm

### feature skill

Feature skill reads `codex.model` and `codex.reasoning_effort` from the resolved config and passes them through to `developer-codex` / `cross-auditor`.

### cross-audit skill

Cross-audit reads `codex.model` and `codex.reasoning_effort` from the resolved config and passes them into the cross-auditor dispatch.

#### `cross_audit.probes.<id>.mode` kill-switch

Cross-audit also reads an optional `cross_audit.probes` block from the resolved config (team-shared `.ai-dev-team.yml` is the usual home; `.ai-dev-team.local.yml` may override per-user). Each probe carries a four-mode kill-switch with allowed values `off|shadow|warn|block`. Shape:

```yaml
cross_audit:
  probes:
    e: { mode: off }
    f: { mode: off }
    g: { mode: off }
```

Semantics (per spec 2026-04-21-cross-audit-probes-foundation §3.4):

- **Default `off` when absent**: when `cross_audit.probes` is absent, or a given probe id is missing under it, the mode is `off`. Zero-config behaviour of `/cross-audit` is identical to today's; Foundation is invisible until a project opts in.
- **Unknown probe id → warning**: probes are a forward-looking enum. An unknown probe id emits a one-line warning and is treated as `off`. This is a warning, not a hard-stop — new probes can arrive in follow-up specs without needing a Foundation re-release.
- **Mode semantics**:
  - `off` — probe is not dispatched; receipts are not requested; findings are not rendered.
  - `shadow` — probe is dispatched; findings are rendered in `## Shadow findings (informational)` with `blocking: false`, NOT surfaced in the Phase 3 decision banner.
  - `warn` — probe is dispatched; findings are rendered in `## Summary` with `blocking: false`, surfaced in the Phase 3 banner as a regular finding.
  - `block` — probe is dispatched; findings are rendered in `## Summary` with `blocking: true`, surfaced in the Phase 3 banner with a `[BLOCKING]` prefix.

**Probe-mode reference table** (§3.7 — spec 2026-04-21-probe-e-diff-scope-leak). One row per probe currently shipping; new probes append rows in follow-up specs.

| Probe id | Detector (v1) | Trigger | Scope reads | v1 limitation |
|----------|---------------|---------|-------------|---------------|
| e | same-file allowlist leak | changed `.py` files in diff with string additions (test files skipped) | changed `.py` file full content at HEAD (same-file only) | Python only; same-file consumer detection only |
| f | missing-cursor pagination | changed `.py` files in diff with paging-method-call additions (test files skipped) | changed `.py` file full content at HEAD (same-file only) | Python only; single failure_kind (`missing_cursor`); no spec or test-fixture analysis; enclosing function required (no module-level) |

See `skills/cross-audit/SKILL.md` Phase 0 for the read sequence.

### research skill

Research skill reads only `kb_path` and `project` from the resolved config. No codex.* reads, no LLM dispatch.

## Skills that do NOT use Phase 0

- investigate — operates on caller's cwd via Codex MCP; no kb_path input, no KB writes.
