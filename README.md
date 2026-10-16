# AI Dev Team

**A spec-first Claude Code plugin with cross-provider review: Claude builds, Codex audits, and every claim carries evidence.**

[![version](https://img.shields.io/github/v/tag/roman-karpovich/ai-dev-team?label=version&style=flat-square)](https://github.com/roman-karpovich/ai-dev-team/tags)
![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-d97757?style=flat-square)
![Codex](https://img.shields.io/badge/Codex-cross--review-412991?style=flat-square)
![status](https://img.shields.io/badge/status-retired-lightgrey?style=flat-square)

> **Status: retired.** v1 is frozen at v1.43.0 and no longer maintained. Its ideas continue in
> [ai-dev-team-v2](https://github.com/roman-karpovich/ai-dev-team-v2). The repository stays public
> as a working reference.

---

## Why

A model reviewing its own work shares its own blind spots. AI Dev Team puts a second model
from a different provider into the loop, and refuses to trust either of them without evidence:

- **Nothing is built before you approve a spec.** A hard gate stops all code until the plan is explicitly accepted.
- **Every step proves itself.** A failing test is captured before the change and a passing one after it; a step without a matching green capture is not done.
- **Two providers review the code independently.** Claude and Codex audit the same diff in parallel, and their findings are merged, scored and verified against the code.
- **Agreement is not evidence.** Two models agreeing can be a correlated hallucination, so an independent scorer rates findings and no high-severity claim ships without a verified `file:line`.
- **Context survives sessions.** Specs, execution logs, findings and research live in a Markdown knowledge base, so work resumes exactly where it stopped.

## How it works

```
/feature new <idea>
   │
   ├─ research the codebase and the knowledge base
   ├─ write spec + execution workdoc (planned evidence per step)
   ├─ ── HARD GATE ── you approve the spec ──────────────────────────
   ├─ spec review: self-review, then Claude × Codex audit of the spec
   ├─ baseline: the test suite must be green before any change
   │
   ├─ for each step:
   │     red capture → implement → green capture → lint → commit
   │     └─ compliance checker: scope, semantics, captures (can block)
   │
   ├─ full test suite
   ├─ code audit: Claude × Codex, iterate until no CRITICAL/HIGH is open
   └─ hand-off: merge locally · push + PR · keep · discard
```

Merging is not the finish line: a shipped spec becomes *verified* only after `/feature verify`
confirms it in reality.

## Cross-provider review

`/cross-audit` is the core of the plugin.

1. **Deterministic probes run first**, before any model: diff-scope leaks, cardinality blindness,
   dependency freshness and typosquatting. Each probe can be off, shadow, warn or block.
2. **Codex audits in the background** through `codex exec` in a read-only sandbox, so long
   high-effort runs are not cut off by the host's watchdog.
3. **Claude audits the same scope independently**, tracing data flows across boundaries and
   recording why any trace was skipped.
4. **Findings are consolidated:**
   - found by both models → high confidence; found by one → needs review;
   - severity disagreement → the higher severity wins; contradictions → the auditor reads the code;
   - fingerprint deduplication, with partial overlaps linked rather than merged.
5. **An independent scorer** (a third, smaller model) rates every model-only finding from 0 to 100.
   Model agreement alone does not raise the score; findings under 80 are reported as advisory.
6. **No CRITICAL or HIGH finding is emitted** unless its `file:line` claim was verified empirically.

Findings are append-only and follow a lifecycle:

```
OPEN → FIXED → VERIFIED
          └──→ REOPENED
OPEN → ACCEPTED | DEFERRED | INVALID
```

A re-audit checks each fix at its location. The loop ends when no CRITICAL or HIGH finding is
open, usually after two to four rounds, with a hard cap of five. A reopened finding, or the same
defect class two rounds in a row, forces a full sweep with fresh context.

If Codex is unavailable, the report says so (`single_model`) instead of pretending to be a dual review.

Other modes cover security, logic, spec and **decision** audits; the last one checks the premises
behind recorded decisions against the actual code, to catch rubber-stamping.

## Skills

| Skill | Command | What it does |
|---|---|---|
| `feature` | `/feature new <desc>` | Full lifecycle: research → spec → implement → verify → hand-off |
| | `/feature continue [spec]` | Resume from the last checkpoint |
| | `/feature status` · `checklist` · `verify` · `grill` | In-flight work, progress, post-merge verification, a pre-spec interview |
| `cross-audit` | `/cross-audit <scope> [--mode]` | Background Claude × Codex audit |
| | `/cross-audit <findings>` | Re-audit: verify fixes, look for regressions |
| `investigate` | `/investigate <question>` | Structured Claude vs Codex debate, up to five rounds; each side must concede the other's stronger arguments. Returns a convergence report |
| `research` | natural language | Research notes: incident investigations, math models, competitive analysis |
| `kb-audit` | `/kb-audit` | Report-only scan for knowledge-base drift: broken links, dangling references, stale statuses |
| `caveman` | always on | Compressed output that keeps parser anchors and uncertainty markers intact |
| `lore` | `/lore` | Retells the session as a short Warhammer 40K vignette. Pure flavour |

Skills trigger from plain conversation. A session-start hook teaches Claude when to use each one,
so slash commands are optional.

## Agents

| Agent | Model | Role |
|---|---|---|
| `developer-codex` | Sonnet + Codex | Default developer. Codex works in a fail-closed sandbox: it can change the repo and write test captures, but not the spec or the execution log it is judged against |
| `developer-senior` | Opus | Ambiguous scope, new abstractions, security-sensitive code |
| `spec-compliance-checker` | Sonnet | After every step: does what happened match what was planned? Blocks on FAIL or DRIFT |
| `verifier` | Haiku | Runs tests and builds; never writes source code |
| `cross-auditor` | Opus + Codex | The dual-provider audit described above |
| `haiku-finding-scorer` | Haiku | Independent 0–100 confidence for each finding |
| `investigator` | Opus + Codex | Multi-round adversarial debate on design questions |
| `librarian` | Sonnet | Optional helper for the knowledge base and its indexes |

The plugin never hardcodes a Codex model: it reads `~/.codex/config.toml`, so a model upgrade is a
one-line change.

## How the plugin tests itself

- **~650 smoke checks** in `tests/smoke.sh` over 674 fixtures, each classified as behavioural,
  schema or prompt-text. Shell and Python only, no network, no model calls.
- **Mutation-protected meta-checks** that fail if the checks they guard stop detecting a defect.
- **`v2/`**: a reference state machine for the next-generation verification design, with 13
  scenario traces and 17 adversarial mutants that the runner must reject.
- **`docs/agent-claims-vs-runtime.md`** separates what is enforced by code from what is only a
  convention the agents are asked to follow.
- 61 releases, from v1.0.2 to v1.43.0.

---

## Install

Requirements:

- Claude Code ≥ 2.1.32
- Codex CLI with `mcp-server` support (for `cross-audit`, `investigate` and `developer-codex`)
- A knowledge-base directory: any Markdown folder; Obsidian works well

```bash
claude plugin marketplace add roman-karpovich/ai-dev-team
claude plugin install ai-dev-team
```

Enable agent teams in `~/.claude/settings.json`:

```json
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
```

Register Codex:

```bash
claude mcp add codex -s user -- codex mcp-server
```

Set the Codex model and effort in `~/.codex/config.toml`, for example:

```toml
model = "gpt-5.6-sol"
model_reasoning_effort = "xhigh"
```

Restart Claude Code.

### Project config

Create `.ai-dev-team.yml` in the root of the project you work on:

```yaml
kb_path: /absolute/path/to/knowledge-base
project: my-project
# project_type: backend   # smart_contract | backend | frontend | data_pipeline
```

A personal `.ai-dev-team.local.yml` (add it to `.gitignore`) overrides the shared file.
Resolution order: `.ai-dev-team.local.yml` → `.ai-dev-team.yml` → memory → sibling directory → ask.
See `.ai-dev-team.yml.example` for all options, including Codex overrides and probe modes.

### Knowledge-base layout

```
<kb-root>/repos/<project>/
├── design/
│   ├── YYYY-MM-DD-<slug>.md     ← feature spec
│   └── workdocs/<slug>/
│       ├── exec.md              ← planned vs observed evidence per step
│       └── captures/            ← red / green / probe output
├── security/                    ← audit findings, one file per iteration
├── research/                    ← investigations, models, exploration
└── postmortems/
```

## Troubleshooting

**`codex unavailable` from `/cross-audit` or `/investigate`.** Codex MCP is not registered.
`claude mcp list` must show `codex`; if not, run the `claude mcp add` command above and restart.

**`cross-auditor` or `investigator` is skipped or "agent not found".** The agent-teams flag is
missing from `~/.claude/settings.json`.

**No "AI Dev Team" block at session start.** Check that the plugin is enabled (`claude plugin list`)
and that `bash <plugin-root>/hooks/session-start | python3 -m json.tool` prints JSON. If it does,
reinstall the plugin.

**Baseline fails on a repo whose base branch is not `main` or `master`.** Set `branch:` in the
spec frontmatter and check out the real base branch before running `/feature`.

## Development

```bash
bash tests/smoke.sh
```

Run it before every release; a version bump in `.claude-plugin/plugin.json` tags the release automatically.
