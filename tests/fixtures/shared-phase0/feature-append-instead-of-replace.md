# feature/SKILL.md — append-instead-of-replace fixture

This negative fixture simulates a drift where the new shared-doc reference
was ADDED but the old inline 9-step algorithm was NOT removed. The
`check_skill_phase0_no_inline_algorithm` helper must reject this state
regardless of the reference being present.

## Phase 0: KB Discovery (all modes)

KB discovery algorithm (resolving `kb_path` and `project` via `.ai-dev-team.local.yml → .ai-dev-team.yml → memory → sibling → ask`) follows `docs/kb-discovery.md` — single source of truth.

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
9. If config does not resolve a field, fall through to legacy discovery.

### Feature-skill extensions

Feature skill reads `codex.model`, `codex.model_fast`, and `codex.reasoning_effort` from the resolved config.
