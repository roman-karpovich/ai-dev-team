# spec-template (audit X6 fixture — explanatory clauses but no actionable instruction)

## 5. Implementation Checklist

**Agent pre-tag (optional).** Each step may carry an optional `@<agent>` suffix — accepted tokens are `@codex` and `@senior`.

**Why not `@codex-fast`?** Fast is an orchestrator-time dispatch choice driven by `codex.model_fast` in user config, not a step property. The orchestrator can decide at runtime.

<!--
Pre-X6-fix, check_spec_template_codex_fast_rationale pinned the marker
line and two explanatory clauses. This fixture keeps all those (the marker
and 'orchestrator-time dispatch...driven by codex.model_fast...not a
step property' sentence) but removes the actionable instruction sentence
that tells authors what to do instead ('A step that would benefit from
Fast is still tagged `@codex`; the orchestrator routes it to Fast only
when the user selects option 1b at the agent-selection banner'). The
audit-fix adds a pin for the actionable-instruction sentence, so this
fixture must now reject.
-->
