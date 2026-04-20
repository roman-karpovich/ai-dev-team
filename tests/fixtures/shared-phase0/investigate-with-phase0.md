# investigate/SKILL.md — rogue Phase 0 fixture

This negative fixture simulates drift where investigate/SKILL.md accidentally
gains a `## Phase 0` heading. The `check_investigate_no_phase0` helper must
reject — investigate operates on cwd only and must never have Phase 0.

## When to use

- Architecture decisions
- Risk analysis

## Phase 0: KB Discovery

Rogue Phase 0 content that should never appear in investigate/SKILL.md.
