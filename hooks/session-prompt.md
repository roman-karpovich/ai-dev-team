## AI Dev Team — Development Workflow

KB lives in <kb>/repos/<project>/. Full workflow + flows: invoke /feature, /cross-audit, /research, /investigate per the trigger map below.

### Skill trigger map

Recognise these intents and invoke the matching skill automatically — do not wait for the user to type a slash command:

| User says... | Action |
|---|---|
| "add X", "implement Y", "I need feature...", "let's build Z", "create a..." | `/feature new <description>` |
| "continue", "resume", "where were we?", "pick up from..." | `/feature continue` |
| "what's in progress?", "what are we working on?", "status", "show specs", "what's pending?" | `/feature status` |
| "review this", "check for bugs", "find bugs", "security check", "code review", "audit src/", "is this safe?" | `/cross-audit <scope>` |
| "should we use X or Y?", "is this the right approach?", "compare these options", "which is better", "tradeoffs between", "brainstorm" | `/investigate <question>` |
| "also need X", "нужно ещё Y", "кстати, забыли про Z", "one more thing", "by the way", "ещё одна доработка" (while inside an active spec) | Prompt: extend current spec (`/feature extend <desc>`) or split into follow-up (`/feature new <desc> --follows-up <spec>`). Never silently absorb. |
| "фича X стабильна в проде", "закрой чеклист по X", "verify feature X" | `/feature verify <spec>` |
| "blocker N выполнен", "деплой залит", "action item done", "soak started" | `/feature checklist <done\|start-soak> <spec> <n>` |
| "audit the KB", "check KB drift", "kb hygiene", "broken wikilinks", "проверь КБ на дрейф" | `/kb-audit [--project <name>]` |

Disambiguation: "compare / which is better / tradeoffs" → `/investigate` (adversarial Claude+Codex debate, single-session, convergence report with a recommendation). Use `/research new competitive-analysis` only when the user wants free-form notes accumulated over multiple sessions, not a decision.

### Key fact

- KB path is saved in Claude memory after first session — not asked again

### Coexistence

Priority when multiple plugins' rules apply: user's CLAUDE.md > other plugins' rules > ai-dev-team rules > default Claude behavior.
ai-dev-team's intent→skill mapping (above) complements other skill-system plugins' generic "use skills" guidance — it does not duplicate or override.
