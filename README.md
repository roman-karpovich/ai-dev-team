# AI Dev Team for Claude Code

Structured AI development workflow for Claude Code. Specs, audit findings, and research live in a Knowledge Base (Obsidian vault). Code lives in source repos. Context never gets lost between sessions.

---

## Requirements

- **Claude Code** ≥ 2.1.32
- **Codex CLI** with `mcp-server` support — required for `cross-audit`, `investigate`, and `developer-codex`
- A Knowledge Base directory (any Markdown folder; Obsidian recommended)

---

## Install

```bash
claude plugin marketplace add roman-karpovich/ai-dev-team
claude plugin install ai-dev-team
```

Two one-time manual steps after install:

**1. Enable agent teams** — add to `~/.claude/settings.json`:
```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**2. Register Codex MCP** (required for `cross-audit`, `investigate`, `developer-codex`):
```bash
claude mcp add codex -s user -- codex mcp-server
```

Model and reasoning effort come from `~/.codex/config.toml`:
```toml
model = "gpt-5.5"
model_reasoning_effort = "xhigh"
```

Restart Claude Code after install.

## Project Config File (`.ai-dev-team.yml`)

The plugin reads an optional config file from the root of the project being worked on.

**Precedence:** `.ai-dev-team.local.yml` → `.ai-dev-team.yml` → memory → sibling heuristic → ask

### Plugin-repo dogfood

Plugin developers working on `ai-dev-team` itself use a personal `.ai-dev-team.local.yml` (already in this repo's `.gitignore`). Do not commit `.ai-dev-team.yml` to the plugin repo; each developer has their own KB.

To set your local path, create `.ai-dev-team.local.yml` in the plugin root:

```yaml
kb_path: /your/personal/kb/path
```

### Consumer-repo adoption

For projects using this plugin via the marketplace:

**To adopt team-shared config:** create `.ai-dev-team.yml` in your project root and commit it:

```yaml
kb_path: /absolute/path/to/knowledge-base
project: my-project-name
```

Committing `.ai-dev-team.yml` makes the KB path team-shared across all developers.

**To add a local override:** create `.ai-dev-team.local.yml` and add `.ai-dev-team.local.yml` to your project's `.gitignore`. The local file takes priority over the committed `.ai-dev-team.yml`. Without the `.gitignore` entry, your private KB path could accidentally be committed.

An example file is included with the plugin at `.ai-dev-team.yml.example`.

---

## Ambient workflow

After install, Claude knows when to use which skill automatically — no slash commands required. Core triggers: `/feature new` (add/implement/build), `/feature continue` (resume/where-were-we), `/cross-audit` (review/audit/check-for-bugs), `/investigate` (compare/tradeoffs/which-is-better).

The full trigger map — including Russian variants, scope-addition handling, `/feature status`, `/feature verify`, and `/feature checklist` — lives in two places. The authoritative copy is [`hooks/session-start`](hooks/session-start), injected into every session at runtime. The portable paste-ready copy for your project's `CLAUDE.md` is in [`docs/claude-md-snippet.md`](docs/claude-md-snippet.md).

At session start, Claude proactively checks for in-progress specs and reports status before asking what to do next. Slash commands still work if you prefer explicit control.

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

Auditing a pull request (including fork PRs):
```
/cross-audit pr 472                       # audit PR #472 in the current repo
/cross-audit pr owner/repo#472            # audit a PR in a different repo
```

In PR mode, the skill materializes the PR head (including fork contents) into an
isolated worktree, classifies changed files, and audits them. After reviewing the
consolidated findings, you decide per finding ID:

- `publish X1 X3` — post those findings as a GitHub PR review comment
- `fix H2` — apply the fix locally (same flow as non-PR audits)
- `accept L4` / `defer M1` — mark as intentional / deferred

`publish <ids>` opens a scoped PR review on the target PR via the GitHub API.
Rate-limit and permission errors are classified via response headers — see
`skills/cross-audit/references/publish.md` for the full recipe.

Confidence levels in findings:
- **HIGH** — both Claude and Codex flagged it → fix
- **REVIEW** — only one flagged it → verify manually, possible false positive

### Investigating an architecture question

```
/investigate should we use optimistic locking or a queue for concurrent order updates?
```

Runs in the **background**. Claude (Opus) and Codex (GPT-5.5) debate through up to 3 rounds, challenging each other's positions. Returns a convergence report with key agreements, unresolved tensions, and a synthesized recommendation.

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
claude plugin update ai-dev-team
```

---

## Troubleshooting

**`/cross-audit` or `/investigate` fails with "mcp not found" / "codex unavailable".**
Codex MCP isn't registered. Diagnose with `claude mcp list` — `codex` must appear. Fix:
```bash
claude mcp add codex -s user -- codex mcp-server
```
Restart Claude Code after registering.

**Team-based agents (`cross-auditor`, `investigator`) are silently skipped or "agent not found".**
The experimental agent-teams flag is missing. Check `~/.claude/settings.json` for:
```json
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
```
Restart Claude Code after adding.

**No ambient workflow context at the start of a session (no "AI Dev Team" block appears).**
The SessionStart hook isn't running. Diagnose:
```bash
claude plugin list              # ai-dev-team should be enabled
bash <plugin-root>/hooks/session-start | python3 -m json.tool   # should print JSON with trigger map
```
If the hook emits JSON correctly but Claude Code doesn't inject it, re-install the plugin (`claude plugin uninstall ai-dev-team && claude plugin install ai-dev-team`). If the hook errors, report the error in the plugin repo.

**Baseline test fails immediately — the repo uses `develop` / `trunk` / something other than `master` or `main`.**
The feature skill auto-detects `master` or `main`. For a non-standard base branch, set the `branch:` field in the spec frontmatter and reference the real base explicitly, e.g.:
```yaml
branch: feat/2026-04-17-my-feature  # cut from develop, not master — `feat/` here is one of the seven conventional prefixes (`feat / fix / refactor / ci / docs / test / chore`) and depends on the spec's `change_type`
```
Then check out the non-standard base before running `/feature`. A permanent fix is tracked in BACKLOG.

**`/feature new` fails on `mkdir` — KB root exists but `repos/<project>/` doesn't.**
The skill creates `<kb>/repos/<project>/design/` on first use, but a stricter filesystem (read-only mount, permission denied) can fail the `mkdir`. Fix manually:
```bash
mkdir -p <kb>/repos/<project>/design/workdocs
```
Then re-run `/feature new`.

---

## Maintainers

Before releasing a new version, run the smoke test locally:

```bash
bash tests/smoke.sh
```

It validates manifest integrity, agent frontmatter, skill structure, the SessionStart hook across env variants, post-edit-lint graceful-exit behaviour + shell-injection regression, the shared developer-workflow reference, and internal markdown links. No network, no Claude — just shell + python3.
