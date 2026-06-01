# CLAUDE.md Snippet — AI Dev Team

Add this block to your project's `CLAUDE.md` to make the ai-dev-team workflow ambient.
Claude will guide you through the right skill based on what you say — no need to memorize commands.

---

## How to add

Paste the section between the `---` markers into your project's `CLAUDE.md`.

> **Trigger-map source of truth:** `hooks/session-start` (injected into every session at runtime). The table below is the portable paste-ready copy — kept current as of 2026-04-20; if it diverges from the hook, the hook wins at runtime.

---

```markdown
## Development Workflow

This project uses [ai-dev-team](https://github.com/roman-karpovich/ai-dev-team) — spec-driven
development with a persistent Knowledge Base. Specs, audit findings, and research live in the KB;
code lives here.

### Session start

At the beginning of any development session, before doing anything else:
1. Check Claude memory for the KB path for this project
2. If found: scan `<kb>/repos/<project>/design/` for specs with status IN_PROGRESS or AUDIT_PASSED
3. If in-progress work exists: summarise it (feature name, current phase, next step) and ask whether
   to continue or start something new
4. If nothing in progress: ask what the user wants to work on

Do this proactively — don't wait for the user to ask.

### Skill trigger map

Recognise these intents and invoke the matching skill automatically:

| User says... | Action |
|---|---|
| "add X", "implement Y", "I need feature...", "let's build Z", "create a..." | `/feature new <description>` |
| "continue", "resume", "where were we?", "pick up from..." | `/feature continue` |
| "what's in progress?", "what are we working on?", "status" | `/feature status` |
| "review this", "check for bugs", "audit src/", "is this safe?" | `/cross-audit <scope>` |
| "should we use X or Y?", "is this the right approach?", "compare these options" | `/investigate <question>` |
| "also need X", "one more thing", "нужно ещё Y" (while inside an active spec) | Prompt: extend (`/feature extend`) or split (`/feature new --follows-up`). No silent absorption. |
| "feature X is stable in prod", "verify feature X", "закрой чеклист" | `/feature verify <spec>` |
| "blocker N done", "deployed to mainnet", "soak started" | `/feature checklist <done\|start-soak> <spec> <n>` |
| "audit the KB", "check KB drift", "kb hygiene", "проверь КБ на дрейф" | `/kb-audit [--project <name>]` |

Disambiguation: "compare / which is better / tradeoffs" → `/investigate` (adversarial Claude+Codex debate, single-session, convergence report with a recommendation). Use `/research new competitive-analysis` only when the user wants free-form notes accumulated over multiple sessions, not a decision.

Don't wait for the user to type a slash command. If the intent matches, invoke the skill.

### Audit findings handling

If the user's request references an audit-findings document (a file under `<kb>/repos/<project>/security/`, or mentions specific finding IDs like "X3", "H1", "fix finding N", "fix audit item N"), do NOT dive into the code directly. First ask whether to formalize as a spec via `/feature new` or fix directly, and wait for the answer. If the user chooses spec, invoke `/feature new` citing the finding; if they choose direct fix, proceed without the flow.

Rationale: the spec-driven flow adds a baseline red test and compliance checks that catch the exact class of bug where a findings doc claims "FIXED" but the code is not. Trivial one-line fixes don't need this overhead, but the user decides — not Claude.

Exception: lines starting with a decision keyword matching `publish|fix|accept|defer` (e.g. `publish X1 X3`, `fix H2`, `accept L4`, `defer M1`) inside an active `/cross-audit` Phase 3 loop are pass-through. Do NOT prompt "spec or direct fix?" in that case; the keyword-prefixed form is an in-flow decision, not a user-initiated finding reference.

### Confirmation cadence

Inside an active `/feature` or `/cross-audit` flow: once the user agrees to a direction, drive the task to completion without re-asking at each intermediate step. Do NOT ask mid-flow questions like "ok to commit?", "shall I push?", "ready to open the PR?", "continue with X?", "go with Y?" — if the user already said yes to the plan, just do it and report results.

Ask only when: (a) there is a real fork with distinct outcomes and the user's preference matters; (b) the action is destructive or irreversible outside the local repo (force-push to main, `rm -rf`, deleting remote branches, messaging external systems, modifying shared infra); (c) something genuinely changes during execution (scope balloons, unexpected fork, surprising state on disk). Status updates during execution are fine — just don't turn them into yes/no questions.

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
- `/feature continue` resumes from the last incomplete step with no context recovery needed
- `/cross-audit` runs in background — you can keep working while it runs
- `/investigate` runs in background — adversarial Claude + Codex debate, returns convergence report
```
