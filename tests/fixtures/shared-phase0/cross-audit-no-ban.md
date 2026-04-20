# cross-audit/SKILL.md — missing-ban fixture

This negative fixture simulates drift where the cross-audit Phase 0
"Never reads `codex.model_fast`" ban was silently removed. The
`check_cross_audit_phase0_bans_model_fast` helper must reject.

## Phase 0: KB Discovery (all modes)

KB discovery algorithm follows `docs/kb-discovery.md` — single source of truth.

### Cross-audit extensions

Cross-audit reads `codex.model` and `codex.reasoning_effort` from the resolved config and passes them into the cross-auditor dispatch. Also reads the optional `github:` block from `.ai-dev-team.local.yml` for multi-account PR auth.
