# AI Dev Team for Claude Code

A set of Claude Code agents and skills that implement a structured, KB-centric development workflow. Specs, audit findings, and research live in a Knowledge Base (Obsidian vault). Code lives in source repos. Context never gets lost between sessions.

**Read first:** [docs/AI_Dev_Team_Overview.md](docs/AI_Dev_Team_Overview.md) (Russian)

---

## What's included

### Agents (`agents/`)

| Agent | Model | Role |
|-------|-------|------|
| `librarian` | Sonnet | KB management — search, create documents, update indexes |
| `developer-codex` | Sonnet + GPT-5.4 | **Default developer.** Delegates to Codex via MCP |
| `developer-senior` | Opus | Complex tasks: ambiguous scope, cross-cutting, Soroban/contracts |
| `developer-middle` | Sonnet | Clear-scope tasks following existing patterns |
| `verifier` | Haiku | Runs test suite. Never writes code |
| `cross-auditor` | Opus + GPT-5.4 | Parallel Claude + Codex audit, consolidates findings |
| `investigator` | Opus + GPT-5.4 | Adversarial debate rounds for architecture decisions |

### Skills (`skills/`)

| Skill | Command | What it does |
|-------|---------|--------------|
| `feature` | `/feature new <desc>` | Full feature lifecycle: research → spec → implement → verify → hand-off |
| `cross-audit` | `/cross-audit <scope>` | Background dual-model audit, saves findings to KB |
| `investigate` | `/investigate <question>` | Background Claude vs Codex debate, returns convergence report |
| `audit` | `/audit <scope>` | Single-model iterative audit (legacy, use cross-audit instead) |

---

## Requirements

- **Claude Code** ≥ 2.1.32
- **Codex MCP** (`mcp__codex__codex`) configured in `~/.claude/settings.json` — required for `cross-audit`, `investigate`, and `developer-codex`
- **Obsidian** (optional) — KB works with any Markdown editor

---

## Install

```bash
git clone git@github.com:roman-karpovich/ai-dev-team.git
cd ai-dev-team
./install.sh
```

The script:
- Copies agents to `~/.claude/agents/`
- Copies skills to `~/.claude/skills/`
- Adds `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to `~/.claude/settings.json`
- Warns if Codex MCP is not configured

Restart Claude Code after install.

---

## KB setup

Each project needs a Knowledge Base directory. The skills discover it automatically:

1. Check Claude memory for a known KB path for this project
2. Search for a sibling directory with "knowledge" in the name (e.g. `../project-knowledge/`)
3. Prompt you to confirm or provide a path

KB structure per project:

```
<kb-root>/
└── repos/
    └── <project>/
        ├── design/       ← feature specs (YAML frontmatter)
        ├── security/     ← audit findings + workdocs
        ├── research/     ← investigations, models, exploratory work
        └── postmortems/  ← incident postmortems
```

---

## Typical workflow

```
/feature new add rate limiting to the API
  → spec written to KB, you approve
  → Codex implements on feature branch
  → verifier runs tests
  → you push and PR

/cross-audit src/api/ --mode security
  → Claude + Codex audit in parallel (background)
  → findings saved to KB
  → you decide: fix / accept / defer per finding

/investigate should we use optimistic locking or queues for this?
  → Claude vs Codex debate (background)
  → convergence report with recommendation
```

---

## Updating

```bash
cd ~/dev/private/ai-dev-team
git pull
./install.sh
```

---

## Codex MCP setup

```bash
claude mcp add codex -s user -- codex -m gpt-5.4 -c model_reasoning_effort="xhigh" mcp-server
```

This registers Codex as a user-level MCP server (available in all projects). Requires the `codex` CLI to be installed and authenticated.

Once configured, test with:
```
/investigate is 2+2=4?
```
You should see a background debate launch.
