# Developer-agent routing

One-paragraph preamble: this file is the source of truth for orchestrator
developer-agent selection during `/feature new` handoff and `/feature continue`
resume. Trigger IDs below (`T-C#`, `T-S#`, `T-M#`, `T-CF#`) are the only valid `rationale=` values in `last_agent=` Log entries.

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
- **T-S0**: no Codex trigger and no Middle trigger matched (fallback)
- **T-S1**: spec introduces a new abstraction or cross-cutting refactor
- **T-S2**: Soroban / smart-contract logic
- **T-S3**: security-sensitive code (auth, crypto, secret handling, contract authorization)
- **T-S4**: scope is ambiguous, design decisions emerge during implementation

**Anti-triggers** (don't pick Senior if):
- spec is fully prompt-specifiable and a pattern already exists (prefer Codex / Middle)
- task is a trivial one-liner (prefer Middle)

## Middle

**When to pick**: Middle developer for trivial in-session fixes and pattern-following tasks that would be overkill for Codex dispatch.

**Triggers**:
- **T-M1**: trivial in-session fix where spawning Codex is overkill (typo, one-line config, small refactor obvious from context)
- **T-M2**: pattern-following task by example (new endpoint mirroring an existing one) and the user wants a Claude-in-session turn, not a Codex dispatch

**Anti-triggers** (don't pick Middle if):
- task requires design judgment or new abstractions (prefer Senior)
- spec is wrong or contradictory (stop, report to user — see §Escalation)

## Codex Fast (opt-in)

**When to pick**: Dispatch variant of `developer-codex` using `codex.model_fast` — pick Fast when the step is well-specified, pattern-following, and low-risk, so reasoning depth can be traded for speed and cost.

**Triggers**:
- **T-CF1**: spec step is a mechanical content-floor edit or byte-exact doc update with explicit anchors (no design judgment required during implementation)
- **T-CF2**: pattern-following code change mirroring an existing, already-proven pattern (new endpoint/test/handler cloned verbatim from a sibling), with narrow scope and no cross-module reach

**Anti-triggers** (don't pick Codex Fast if):
- task is security-sensitive (auth, crypto, secret handling, contract authorization)
- task is cross-cutting (touches many layers or modules at once)
- task introduces a new-abstraction (new trait/interface/type the codebase has not seen before)

**Cross-auditor never consumes `codex.model_fast`.** Audit reasoning depth is non-negotiable; Fast is developer-codex-only.

`@codex-fast` is intentionally not a valid spec pre-tag: Fast is orchestrator-time dispatch driven by user config, not a step property. Tag `@codex`; the orchestrator picks Fast at the agent-selection banner.

## Rationale logging

Every time the orchestrator picks a developer agent (new spec or `continue`), append to the spec Log:

```
- YYYY-MM-DD: last_agent=<codex|senior|middle>; rationale=<T-X#>[; notes=<short>]
```

`rationale=` MUST be a trigger ID from one of the four agent sections above (including `Codex Fast`).
Use `T-S0` when none of Codex's or Middle's triggers matched (the fallback).
`notes=<short>` is optional and carries a one-phrase human-readable reason
(e.g. `notes=spec paths explicit but domain unusual`).

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

### Middle

- **condition**: design judgment required (new abstraction, cross-cutting, unclear scope emerges)
  **action**: Middle stops
  **target**: user
  **outcome**: re-spawn `developer-senior`
- **condition**: spec is wrong or contradictory
  **action**: Middle stops
  **target**: user
  **outcome**: report blocker (**no handoff** — spec needs correction)

### Senior

- **condition**: spec is wrong or contradictory
  **action**: Senior stops
  **target**: user
  **outcome**: report blocker (**no handoff**)
