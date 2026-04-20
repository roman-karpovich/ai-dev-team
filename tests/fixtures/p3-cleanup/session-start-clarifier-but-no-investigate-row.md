## AI Dev Team — Development Workflow (audit X1 fixture)

### Skill trigger map

Recognise these intents and invoke the matching skill automatically:

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

<!--
The '/investigate' row has been deliberately dropped from the table, but
the clarifier paragraph still mentions '/investigate' — the token survives
inside the §Skill trigger map section. Pre-X1-fix the helper used
whole-section grep and would have accepted this; the fix scopes the
8-target check to table rows only, so this fixture must now reject.
-->
