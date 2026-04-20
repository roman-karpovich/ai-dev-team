# CLAUDE.md Snippet — AI Dev Team (audit X2 fixture)

## How to add

Paste the section between the `---` markers into your project's `CLAUDE.md`.

> **Trigger-map source of truth:** `hooks/session-start` (injected into every session at runtime). The table below is the portable paste-ready copy — kept current as of 2026-04-20; if it diverges from the hook, the hook wins at runtime.

---

```markdown
## Development Workflow

### Skill trigger map

| User says... | Action |
|---|---|
| "add X", "implement Y" | `/feature new <description>` |
| "continue", "resume" | `/feature continue` |
| "what's in progress?" | `/feature status` |
| "review this", "audit src/" | `/cross-audit <scope>` |
| "also need X" | `/feature extend <desc>` |
| "verify feature X" | `/feature verify <spec>` |
| "blocker N done" | `/feature checklist done <spec> <n>` |

Disambiguation: "compare / which is better / tradeoffs" → `/investigate` (adversarial Claude+Codex debate, single-session, convergence report with a recommendation). Use `/research new competitive-analysis` only when the user wants free-form notes accumulated over multiple sessions, not a decision.
```

<!--
The '/investigate' row dropped from the trigger-map table, but the
clarifier paragraph still mentions '/investigate'. Pre-X2-fix the helper's
whole-file 8-target grep accepted this; the fix scopes to table rows inside
§Skill trigger map, so this fixture must now reject.
-->
