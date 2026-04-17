# CLAUDE.md Snippet — AI Dev Team

Add this block to your project's `CLAUDE.md` to make the ai-dev-team workflow ambient.
Claude will guide you through the right skill based on what you say — no need to memorize commands.

---

## How to add

Paste the section between the `---` markers into your project's `CLAUDE.md`.

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

Don't wait for the user to type a slash command. If the intent matches, invoke the skill.

### Audit findings handling

If the user's request references an audit-findings document (a file under `<kb>/repos/<project>/security/`, or mentions specific finding IDs like "X3", "H1", "fix finding N", "fix audit item N"), do NOT dive into the code directly. First ask whether to formalize as a spec via `/feature new` or fix directly, and wait for the answer. If the user chooses spec, invoke `/feature new` citing the finding; if they choose direct fix, proceed without the flow.

Rationale: the spec-driven flow adds a baseline red test and compliance checks that catch the exact class of bug where a findings doc claims "FIXED" but the code is not. Trivial one-line fixes don't need this overhead, but the user decides — not Claude.

### Workflow phases (reference)

```
1. Research + write spec + exec workdoc  →  user approves spec (HARD GATE)
2. Spec self-review + cross-audit (Claude + Codex)  →  fix if CRITICAL/HIGH
3. Baseline test  →  implement step-by-step with compliance checks per step
4. Verify (full test suite)  →  hand-off (merge / PR / keep / discard)
```

### Key facts

- KB path is saved in Claude memory after first session — not asked again
- All context (specs, findings, decisions) lives in KB across sessions
- `/feature continue` resumes from the last incomplete step with no context recovery needed
- `/cross-audit` runs in background — you can keep working while it runs
- `/investigate` runs in background — adversarial Claude + Codex debate, returns convergence report
```

