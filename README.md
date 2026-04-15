# AI Dev Team for Claude Code

Structured AI development workflow for Claude Code. Specs, audit findings, and research live in a Knowledge Base (Obsidian vault). Code lives in source repos. Context never gets lost between sessions.

**Full overview:** [docs/AI_Dev_Team_Overview.md](docs/AI_Dev_Team_Overview.md)

---

## Requirements

- **Claude Code** ≥ 2.1.32
- **Codex CLI** with `mcp-server` support — required for `cross-audit`, `investigate`, and `developer-codex`
- A Knowledge Base directory (any Markdown folder; Obsidian recommended)

---

## Install

```bash
git clone git@github.com:roman-karpovich/ai-dev-team.git
cd ai-dev-team
./install.sh
```

The script copies agents and skills to `~/.claude/`, enables agent teams in `~/.claude/settings.json`, and registers the Codex MCP server if the `codex` CLI is available.

Restart Claude Code after install.

### Codex MCP (manual)

If `install.sh` couldn't register Codex automatically:

```bash
claude mcp add codex -s user -- codex mcp-server
```

Model and reasoning effort come from `~/.codex/config.toml` — nothing is hardcoded in agents. Set the model you want there:

```toml
model = "gpt-5.4"
model_reasoning_effort = "xhigh"
```

To upgrade to a newer Codex model: update `config.toml` once, all agents pick it up.

---

## How to use

### First session with a project

The first time you run any skill in a project, Claude will ask for the Knowledge Base path. You can:

- Point to an existing Obsidian vault: `~/dev/my-project-knowledge/`
- Let Claude search automatically (it looks for sibling directories with "knowledge" in the name)
- Create a new KB on the spot

The path is saved to memory — not asked again for that project.

### Starting a feature

```
/feature new add webhook delivery retries
```

What happens:
1. Claude reads the codebase and searches KB for relevant context
2. Writes a spec to `<kb>/repos/<project>/design/YYYY-MM-DD-<slug>.md`
3. **Stops and shows you the spec** — you review and approve (or ask for changes)
4. **Spec audit** — Claude + Codex review the spec for design problems (missing deps, ambiguous steps, ordering issues). Findings presented inline; you fix the spec or say "proceed anyway"
5. After audit passes: asks which developer to use (Codex by default)
6. Developer implements on a feature branch, marks checklist steps as it goes
7. Verifier runs tests
8. Asks if you want to push and open a PR

You always see the spec before a single line of code is written. The spec audit catches design problems before implementation begins.

### Resuming in a new session

```
/feature continue
```

Without arguments: shows all in-progress specs and lets you pick one.

```
/feature continue kb/repos/my-project/design/2026-04-14-webhooks.md
```

With a path: jumps straight to that spec, reports current status, continues from the last unchecked step.

### Checking what's in flight

```
/feature status
```

Shows a table of all specs across all projects: name, status, progress (N/M steps), branch.

### Running an audit

```
/cross-audit src/
```

Runs in the **background** — you can keep working. When done, presents findings by severity.

For each finding you decide:
- `fix X1 X3` — apply those fixes
- `accept X2` — known issue, intentional
- `defer X4` — address later
- `fix all` — fix everything

After fixes are applied, run the re-audit:

```
/cross-audit kb/repos/my-project/security/2026-04-14-src-findings.md
```

Repeat until no CRITICAL or HIGH findings remain open. Typically 2–3 iterations.

Audit flags:
```
/cross-audit src/               # full audit (logic + security)
/cross-audit src/ --mode logic  # logic only: correctness, edge cases, performance
/cross-audit src/ --mode security --diff  # security audit of recent changes only
```

Confidence levels in findings:
- **HIGH** — both Claude and Codex flagged it → fix
- **REVIEW** — only one flagged it → verify manually, possible false positive

### Investigating an architecture question

```
/investigate should we use optimistic locking or a queue for concurrent order updates?
```

Runs in the **background**. Claude (Opus) and Codex (GPT-5.4) debate through up to 3 rounds, challenging each other's positions. Returns a convergence report with:
- Key agreements (high-confidence conclusions)
- Unresolved tensions (genuine tradeoffs)
- A synthesized recommendation

Use this before committing to a non-obvious design decision.

### Iterating on a feature mid-flight

You never need to start over. Since everything lives in the spec:

**Change the design before implementation starts:**
Edit the spec in Obsidian (or tell Claude what to change) → re-approve → Developer continues.

**Redo a specific step:**
```
/feature continue kb/repos/my-project/design/2026-04-14-webhooks.md
```
Then tell Claude: "rework step 3 — use exponential backoff instead of fixed intervals"

**Expand scope after partial implementation:**
Tell Claude to add steps to the spec checklist → approve the updated spec → Developer picks up where the checklist left off.

### Research and investigations (without a spec)

For work that doesn't fit a feature — incident investigations, math modeling, competitive analysis:

Ask Claude to create a research note:
```
create a research note in the KB for investigating the memory leak we saw on 2026-04-13
```

Research notes live at `<kb>/repos/<project>/research/YYYY-MM-DD-<slug>.md` and have a `subtype` field (`incident-investigation`, `math-model`, `competitive-analysis`, `exploration`). Free-form structure; statuses: `ACTIVE / CONCLUDED / ARCHIVED`.

---

## What's included

### Agents (`agents/`)

| Agent | Model | Role |
|-------|-------|------|
| `librarian` | Sonnet | KB management — search, create documents, update MOC indexes |
| `developer-codex` | Sonnet + Codex | **Default developer.** Delegates to Codex via MCP. Saves Claude tokens. |
| `developer-senior` | Opus | Complex tasks: ambiguous scope, new abstractions, Soroban/contracts, security-sensitive code |
| `developer-middle` | Sonnet | Clear-scope tasks following existing patterns: endpoints, tests, functions by example |
| `verifier` | Haiku | Runs test suite and build checks. Never writes source code. |
| `cross-auditor` | Opus + Codex | Parallel Claude + Codex audit. Consolidates findings into KB. |
| `investigator` | Opus + Codex | Adversarial multi-round debate for architecture decisions. |

**Choosing a developer:**
```
Codex           ← default; spec has explicit file paths and clear requirements
developer-middle ← Codex overhead not worth it (small in-session edit)
developer-senior ← wide codebase exploration needed, or genuinely ambiguous scope
```

### Skills (`skills/`)

| Skill | Command | What it does |
|-------|---------|--------------|
| `feature` | `/feature new <desc>` | Full feature lifecycle: research → spec → implement → verify → hand-off |
| `feature` | `/feature continue [spec-path]` | Resume from last checkpoint in an existing spec |
| `feature` | `/feature status` | Show all in-progress specs across all projects |
| `cross-audit` | `/cross-audit <scope> [--mode] [--diff]` | Background dual-model audit, findings saved to KB |
| `cross-audit` | `/cross-audit <findings-path>` | Re-audit iteration: verify fixes, look for new issues |
| `investigate` | `/investigate <question>` | Background Claude vs Codex debate, returns convergence report |
| `audit` | `/audit <scope>` | Single-model iterative audit (use `cross-audit` instead) |

---

## KB structure

```
<kb-root>/
└── repos/
    └── <project>/
        ├── design/       ← feature specs (YAML frontmatter + checklist)
        ├── security/     ← audit findings (accumulates) + workdocs (per iteration)
        ├── research/     ← investigations, models, exploratory work
        └── postmortems/  ← completed incident reviews
```

---

## Updating

```bash
cd ~/path/to/ai-dev-team
git pull && ./install.sh
```
