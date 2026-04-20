## Adaptation by Project Type

Focus areas depend on detected `project_type` and audit mode — see `agents/cross-auditor.md` §Mode Focus Areas for the canonical per-mode list (`logic` / `security` / `full` / `spec`).

- **Smart Contracts / DeFi**: fund loss, reentrancy, access control, math precision
- **Backend Services**: input validation, injection, auth bypass, race conditions
- **Frontend**: XSS, CSRF, state management, API contract mismatches
- **Data Pipelines**: data loss, idempotency, schema evolution

---

## Iteration Loop
