# Developer-agent routing

One-paragraph preamble: this file is the source of truth for orchestrator
developer-agent selection during `/feature new` handoff and `/feature continue`
resume. Trigger IDs below (`T-C#`, `T-S#`) are the only valid `rationale=` values in `last_agent=` Log entries.

## Codex (default)

**When to pick**: Default developer for well-specified pattern-following tasks with explicit file paths and concrete symbols.

**Triggers**:
- **T-C1**: spec has explicit file paths and concrete function/symbol names per step
- **T-C2**: task is well-specified and fits one or more pattern-following steps
- **T-C3**: scope is small-to-medium and does not require broad codebase exploration

**Anti-triggers** (don't pick Codex if):
- task requires broad live filesystem exploration the spec cannot fully enumerate
- scope is ambiguous and design decisions emerge during implementation
- cross-cutting refactor touching many layers

## Senior

**When to pick**: Senior developer for cross-cutting refactors, new abstractions, security-sensitive code, and ambiguous scope requiring design judgment.

**Triggers**:
- **T-S0**: no Codex trigger matched (fallback)
- **T-S1**: spec introduces a new abstraction or cross-cutting refactor
- **T-S2**: Soroban / smart-contract logic
- **T-S3**: security-sensitive code (auth, crypto, secret handling, contract authorization)
- **T-S4**: scope is ambiguous, design decisions emerge during implementation
- **T-S5**: ai-dev-team plugin work (project policy override per feedback_ai_dev_team_dev_senior_default.md)

**Anti-triggers** (don't pick Senior if):
- spec is fully prompt-specifiable and a pattern already exists (prefer Codex)
- task is a trivial one-liner (prefer Codex)

## Rationale logging

Every time the orchestrator picks a developer agent (new spec or `continue`), append to the spec Log:

```
- YYYY-MM-DD: last_agent=<codex|senior>; rationale=<T-X#>[; notes=<short>]
```

`rationale=` MUST be a trigger ID from one of the two agent sections above.
Use `T-S0` when none of Codex's triggers matched (the fallback).
`notes=<short>` is optional and carries a one-phrase human-readable reason
(e.g. `notes=spec paths explicit but domain unusual`).

Historical Log entries with `last_agent=middle` or `rationale=T-M*` are accepted as read-only legacy values; new entries MUST use the current enum. Continue-mode normalises a stale `middle` default to `codex` per SKILL.md §Continue mode (Legacy `last_agent=middle` normalisation paragraph).

## Escalation

Distinct from "picking" an agent at the start of a step: escalation fires
*during* a step, when the agent in flight decides it cannot complete and
another agent (or the user) must take over.

### Codex

- **condition**: 2 retries exhausted with clarified prompt
  **action**: Codex stops
  **target**: user
  **outcome**: suggest re-spawning `developer-senior`
- **condition**: task turns out to be cross-cutting or not fully prompt-specifiable
  **action**: Codex stops
  **target**: user
  **outcome**: suggest re-spawning `developer-senior`

### Senior

- **condition**: spec is wrong or contradictory
  **action**: Senior stops
  **target**: user
  **outcome**: report blocker (**no handoff**)
