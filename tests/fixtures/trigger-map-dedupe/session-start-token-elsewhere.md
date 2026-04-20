## AI Dev Team — Development Workflow (audit-fixture for X1)

### Skill trigger map

Recognise these intents and invoke the matching skill automatically:

| User says... | Action |
|---|---|
| "add X", "implement Y" | `/feature new <description>` |
| "continue", "resume" | `/feature continue` |
| "what's in progress?" | `/feature status` |
| "review this", "audit src/" | `/cross-audit <scope>` |
| "compare these options" | `/investigate <question>` |
| "also need X" | `/feature extend <desc>` |
| "verify feature X" | `/feature verify <spec>` |

### Key facts

- Post-merge blocker management is handled via `/feature checklist done <spec> <n>`
- `/feature continue` resumes from the last incomplete step — no context recovery needed

<!--
The trigger map table deliberately omits the post-merge checklist row, but the
token `/feature checklist` survives in the Key facts section. Exercises the
section-scoping fix (X1) — pre-fix whole-file grep would have accepted this.
-->
