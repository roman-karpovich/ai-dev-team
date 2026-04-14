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
| `feature` | `/feature continue <spec-path>` | Resume from last checkpoint in an existing spec |
| `feature` | `/feature status` | Show all in-progress specs across all projects |
| `cross-audit` | `/cross-audit <scope>` | Background dual-model audit (Claude + Codex), findings saved to KB |
| `cross-audit` | `/cross-audit <findings-path>` | Re-audit iteration: verify fixes, look for new issues |
| `investigate` | `/investigate <question>` | Background Claude vs Codex debate, returns convergence report |
| `audit` | `/audit <scope>` | Single-model iterative audit (use `cross-audit` instead) |

---

## KB setup

Skills discover the KB automatically:

1. Check Claude memory for a known KB path for the current project
2. Search for a sibling directory with "knowledge" in the name (e.g. `../project-knowledge/`)
3. Confirm with you before using

After confirmation the path is saved to memory — not asked again.

KB structure per project:

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

## Feature workflow

```
Phase 1 — Planning
  Lead writes spec → saves to KB → you approve
  ── mandatory checkpoint ──

Phase 2 — Implementation
  Developer (Codex by default) reads spec → feature branch → implements per checklist
  Small logical commits, no Co-authored-by

Phase 3 — Verification
  Verifier runs tests → PASS continues, FAIL goes back to developer

Phase 4 — Audit (background, parallel)
  cross-auditor logic + cross-auditor security (Claude + Codex each)
  4 independent perspectives → findings saved to KB
  ── mandatory checkpoint: fix / accept / defer per finding ──

Phase 5 — Fix
  Developer applies selected fixes

Phase 6 — Re-audit (diff only)
  Verifies fixes, checks for new issues

Phase 7 — Hand-off
  Lead presents commit list → git push + gh pr create on confirmation
```

---

## Audit modes

`/cross-audit` supports two independent flags:

- `--mode logic|security|full` — what to look for (default: `full`)
- `--diff` — scope to files changed since base branch (combine with any mode)

```bash
/cross-audit src/         --mode security        # full security audit
/cross-audit src/         --mode logic --diff    # logic audit of recent changes only
/cross-audit findings.md                         # re-audit iteration
```

Confidence levels:
- **HIGH** — both Claude and Codex found it → fix
- **REVIEW** — only one found it → verify manually, possible false positive

---

## Updating

```bash
cd ~/path/to/ai-dev-team
git pull && ./install.sh
```
