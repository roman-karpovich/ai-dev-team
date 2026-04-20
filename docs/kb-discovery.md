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

## Multi-account github: config block (cross-audit only, reference)

Cross-audit reads an optional `github:` block from `.ai-dev-team.local.yml` (account identities are personal, not team-shared — so this block lives in the local override file, not the team-shared `.ai-dev-team.yml`). Shape:

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

The block is optional. When present, it enables multi-account auth routing for PR-mode audits and publish: Phase 0.5 resolves one account per invocation and every subsequent `gh` call in the PR-audit surface is prefixed with `GH_TOKEN="${<token_env>}" GH_HOST="<host>"` so the credential is scoped to that subprocess without mutating global `gh auth` state. Resolution precedence (see cross-audit/SKILL.md Phase 0.5 for the full matrix):

`precedence: --account flag → URL host match → default_account → ambient gh auth`

When the `github:` block is absent, Phase 0.5 skips account resolution entirely and every `gh` call runs bare — existing single-account users are unaffected.

## Skill extensions — read in addition to the core algorithm

### feature skill

Feature skill reads `codex.model`, `codex.model_fast`, and `codex.reasoning_effort` from the resolved config and passes them through to `developer-codex` / `cross-auditor`. `codex.model_fast` is forwarded as `codex_model` only when the user picks "Codex Fast" from the agent-selection menu; `cross-auditor` never receives `codex.model_fast`.

### cross-audit skill

Cross-audit reads `codex.model` and `codex.reasoning_effort` from the resolved config and passes them into the cross-auditor dispatch. Never reads `codex.model_fast` — audit reasoning depth is non-negotiable, Fast is developer-codex-only. Also reads the optional `github:` block from `.ai-dev-team.local.yml` for multi-account PR auth; see the "Multi-account github: config block" section above for the YAML schema and cross-audit/SKILL.md Phase 0.5 for the full account-resolution ladder.

### research skill

Research skill reads only `kb_path` and `project` from the resolved config. No codex.* reads, no LLM dispatch.

## Skills that do NOT use Phase 0

- investigate — operates on caller's cwd via Codex MCP; no kb_path input, no KB writes.
