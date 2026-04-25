## AI Dev Team — Development Workflow

This session has the ai-dev-team workflow available. The workflow is spec-driven with a persistent Knowledge Base (KB). Specs, audit findings, and research live in the KB; code lives in source repos.

### Session start behavior

At the beginning of any development session, before doing anything else:
1. Check Claude memory for the KB path for this project
2. If found: scan `<kb>/repos/<project>/design/` for specs with status IN_PROGRESS or AUDIT_PASSED
3. If in-progress work exists: summarise it (feature name, current phase, next step) and ask whether to continue or start something new
4. If nothing in progress: ask what the user wants to work on

Do this proactively — do not wait for the user to ask.

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

Disambiguation: "compare / which is better / tradeoffs" → `/investigate` (adversarial Claude+Codex debate, single-session, convergence report with a recommendation). Use `/research new competitive-analysis` only when the user wants free-form notes accumulated over multiple sessions, not a decision.

### Audit findings handling

If the user's request references an audit-findings document (a file under `<kb>/repos/<project>/security/`, or mentions specific finding IDs like "X3", "H1", "починим N из findings", "fix audit item N"), do NOT dive into the code directly. First ask: "оформить как spec через `/feature new` или чинить напрямую?" — and wait for the answer. If the user chooses spec, invoke `/feature new` citing the finding. If they choose direct fix, proceed without the flow.

Rationale: the spec-driven flow adds a baseline red test and compliance checks that catch the exact class of bug where a findings doc claims "FIXED" but the code is not. Cheap one line fixes do not need this overhead, but the user should decide — not Claude.

Exception: lines starting with a decision keyword matching `publish|fix|accept|defer` (e.g. `publish X1 X3`, `fix H2`, `accept L4`, `defer M1`) inside an active `/cross-audit` Phase 3 loop are pass-through. Do NOT prompt "spec or direct fix?" in that case; the keyword-prefixed form is an in-flow decision, not a user-initiated finding reference.

### Confirmation cadence

Once the user agrees to a direction, drive the task to completion without re-asking at each intermediate step. Do NOT ask mid-flow questions like "ok to commit?", "shall I push?", "ready to open the PR?", "continue with X?", "go with Y?" — if the user already said yes to the plan, just do it and report results.

Ask only when:
- there is a real fork with distinct outcomes (A vs B vs C, or the decision is non-obvious and the user's preference matters)
- the action is destructive or irreversible outside the local repo (force-push to main, `rm -rf`, deleting remote branches, sending messages to external systems, modifying shared infra)
- something genuinely changes during execution (scope balloons, an unexpected fork appears, surprising state on disk)

Status updates during execution are fine and encouraged — just do not turn them into yes/no questions.

### Workflow phases (reference)

```
1. Research + write spec + exec workdoc  →  user approves spec (HARD GATE)
2. Spec self-review + cross-audit (Claude + Codex)  →  fix if CRITICAL/HIGH
3. Baseline test  →  implement step-by-step with compliance checks per step
4. Verify (full test suite)
5. Code audit (cross-auditor mode:full on diff — closed gate, per-finding triage)  →  hand-off (merge / PR / keep / discard)
```

### Key facts

- KB path is saved in Claude memory after first session — not asked again
- All context (specs, findings, decisions) lives in KB across sessions
- `/feature continue` resumes from the last incomplete step — no context recovery needed
- `/cross-audit` runs in background — you can keep working while it runs
- `/investigate` runs in background — adversarial Claude + Codex debate, returns convergence report
- Each implementation step requires evidence captures (failing test → implement → passing test → compliance check)
- A step is not done until green_capture exists and matches expected_pass_pattern
