# AI Dev Team for Claude Code

Structured AI development workflow for Claude Code. Specs, audit findings, and research live in a Knowledge Base (Obsidian vault). Code lives in source repos. Context never gets lost between sessions.

---

## Requirements

- **Claude Code** ≥ 2.1.32
- **Codex CLI** with `mcp-server` support — required for `cross-audit`, `investigate`, and `developer-codex`
- A Knowledge Base directory (any Markdown folder; Obsidian recommended)

---

## Install

### Option A — Plugin (recommended)

The plugin injects the workflow orientation into every Claude Code session globally — no per-project `CLAUDE.md` needed.

```bash
claude plugin marketplace add roman-karpovich/ai-dev-team
claude plugin install ai-dev-team
```

Then run `install.sh` to set up agents, skills, and Codex MCP:

```bash
git clone git@github.com:roman-karpovich/ai-dev-team.git
cd ai-dev-team
./install.sh
```

Restart Claude Code after install.

### Option B — CLAUDE.md snippet

If you prefer per-project setup (or plugins aren't available in your Claude Code version):

```bash
git clone git@github.com:roman-karpovich/ai-dev-team.git
cd ai-dev-team
./install.sh
```

`install.sh` offers to append the workflow snippet to your project's `CLAUDE.md`. You can also add it manually from `docs/claude-md-snippet.md`.

### What install.sh does

- Copies agents and skills to `~/.claude/`
- Enables agent teams in `~/.claude/settings.json`
- Registers the Codex MCP server if the `codex` CLI is available
- Offers to add the workflow snippet to your project's `CLAUDE.md`

Restart Claude Code after install.

### Codex MCP (manual)

If `install.sh` couldn't register Codex automatically:

```bash
claude mcp add codex -s user -- codex mcp-server
```

Model and reasoning effort come from `~/.codex/config.toml` — nothing is hardcoded in agents:

```toml
model = "gpt-5.4"
model_reasoning_effort = "xhigh"
```

To upgrade to a newer Codex model: update `config.toml` once, all agents pick it up.

---

## Ambient workflow

Add the snippet from `docs/claude-md-snippet.md` to your project's `CLAUDE.md`. After that, Claude knows when to use which skill automatically — no slash commands required:

| You say... | Claude does |
|---|---|
| "add retry logic", "implement X", "let's build Y" | `/feature new` |
| "continue", "where were we?", "resume..." | `/feature continue` |
| "review this", "audit src/", "check for bugs" | `/cross-audit` |
| "should we use X or Y?", "is this approach right?" | `/investigate` |

At session start, Claude proactively checks for in-progress specs and reports status before asking what to do next.

Slash commands still work if you prefer explicit control.

---

## How to use

### Starting a feature

```
/feature new add webhook delivery retries
```

What happens:
1. Claude reads the codebase and searches KB for relevant context
2. Writes a **spec** + **execution workdoc** (`design/workdocs/<slug>/exec.md`) with per-step planned evidence schema
3. **HARD GATE** — shows you the spec, waits for explicit approval before writing any code
4. Two-pass spec review: self-review (completeness check) + dual-model cross-audit of spec and workdoc
5. Baseline test — verifies the test suite is green before any new code
6. Developer implements step-by-step: failing test → implement → passing test → save captures → compliance check per step
7. Verifier runs the full test suite
8. Hand-off: choose from 4 options (merge locally / push+PR / keep / discard)

You always see the spec before a single line of code is written.

### Resuming in a new session

```
/feature continue
```

Without arguments: shows all in-progress specs and lets you pick one.

```
/feature continue kb/repos/my-project/design/2026-04-14-webhooks.md
```

With a path: jumps straight to that spec, reports current status, continues from the last unchecked step. No context recovery needed — everything lives in KB.

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

Re-audit after fixes (pass the findings file path):

```
/cross-audit kb/repos/my-project/security/2026-04-14-src-findings.md
```

Repeat until no CRITICAL or HIGH findings remain open. Typically 2–3 iterations.

Audit flags:
```
/cross-audit src/                         # full audit (logic + security)
/cross-audit src/ --mode logic            # logic only: correctness, edge cases, performance
/cross-audit src/ --mode security --diff  # security audit of recent changes only
```

Confidence levels in findings:
- **HIGH** — both Claude and Codex flagged it → fix
- **REVIEW** — only one flagged it → verify manually, possible false positive

### Investigating an architecture question

```
/investigate should we use optimistic locking or a queue for concurrent order updates?
```

Runs in the **background**. Claude (Opus) and Codex (GPT-5.4) debate through up to 3 rounds, challenging each other's positions. Returns a convergence report with key agreements, unresolved tensions, and a synthesized recommendation.

Use this before committing to a non-obvious design decision.

### Iterating on a feature mid-flight

You never need to start over. Everything lives in the spec and execution workdoc.

**Change the design before implementation starts:**
Edit the spec in Obsidian (or tell Claude what to change) → re-approve → Developer continues.

**Redo a specific step:**
```
/feature continue kb/repos/my-project/design/2026-04-14-webhooks.md
```
Then tell Claude: "rework step 3 — use exponential backoff instead of fixed intervals"

**Expand scope after partial implementation:**
Add steps to the spec checklist → approve → Developer picks up where the checklist left off.

### Research and investigations (without a spec)

For work that doesn't fit a feature — incident investigations, math modeling, competitive analysis:

```
create a research note in the KB for the auth performance regression we saw on 2026-04-13
```

Research notes live at `<kb>/repos/<project>/research/YYYY-MM-DD-<slug>.md`. Subtypes: `incident-investigation`, `math-model`, `competitive-analysis`, `exploration`. Statuses: `ACTIVE / CONCLUDED / ARCHIVED`.

---

## What's included

### Agents (`agents/`)

| Agent | Model | Role |
|-------|-------|------|
| `librarian` | Sonnet | KB management — search, create documents, update MOC indexes |
| `developer-codex` | Sonnet + Codex | **Default developer.** Delegates to Codex via MCP. Saves Claude tokens. |
| `developer-senior` | Opus | Complex tasks: ambiguous scope, new abstractions, security-sensitive code |
| `developer-middle` | Sonnet | Clear-scope tasks following existing patterns: endpoints, tests, functions by example |
| `spec-compliance-checker` | Sonnet | Runs after each implementation step. Verifies observed matches planned intent. Blocks on FAIL/DRIFT. |
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
        ├── design/
        │   ├── YYYY-MM-DD-<slug>.md      ← feature spec
        │   └── workdocs/
        │       └── <slug>/
        │           ├── exec.md           ← per-step planned/observed evidence
        │           └── captures/         ← test output files (red/green/probe)
        ├── security/                     ← audit findings + workdocs per iteration
        ├── research/                     ← investigations, models, exploratory work
        └── postmortems/                  ← completed incident reviews
```

The execution workdoc (`exec.md`) is created alongside every spec. It tracks:
- `planned`: goal, allowed_scope, test commands, expected output patterns, optional integration probe
- `observed`: actual files touched, commit SHAs, paths to capture files (filled during implementation)

A step is not done until `green_capture` exists and matches `expected_pass_pattern`.

---

## Updating

```bash
cd ~/path/to/ai-dev-team
git pull && ./install.sh
```
