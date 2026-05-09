# CLAUDE.md — ai-dev-team

## Mission

**ai-dev-team helps development from multiple angles — ideation, disciplined execution, quality verification, persistent context, codified code-quality conventions — to reduce bug-escape rate, increase dev velocity, preserve context across sessions, and get quality code (not just "works") from dev-agents.**

The plugin targets concrete pain points, not abstract "quality": lack of discipline, weak tests, lost context, research fragmentation, spec drift, shallow review quality, custom project nuances dev-agents don't pick up on their own.

Axes (federation, not hierarchy):
- **Ideation** — `/investigate`, `/research` (direction picking, brainstorming)
- **Orchestration** — `/feature` spec-driven flow (the discipline backbone)
- **Verification** — `/cross-audit` (Claude+Codex halves + deterministic probes)
- **Code-quality conventions** — `skills/feature/references/code-quality-rules.md` R1-R7 for dev-agents
- **Context persistence** — KB vault (specs, findings, research) across sessions
- **Self-protection** — smoke harness + hooks

**Active constraint set** (post-convergence 2026-04-25): `audit-coverage tail / rollout-isolation / process-truthfulness / rule-enforcement`. Four parallel constraints competing for orchestrator attention; the single-binding framing ("audit coverage") was retired once E/F probes shipped. The mission itself stays the same.

Full formulation + success criteria + operational rules + per-constraint anchors: `<kb>/repos/ai-dev-team/MISSION.md` §Active constraint set.

## Testing

The project's test suite is the smoke harness at `tests/smoke.sh`:

```bash
bash tests/smoke.sh
```

Expected output ends with `Failed: 0` plus a per-class breakdown:
`Behavioral: <N> + Schema: <N> + Prompt-text: <N> + Unclassified: <N>`. Total = sum of those.

Per-pin 3-edit protocol when adding a new check:

1. Function definition: `check_<name>` in `tests/smoke-helpers.sh`.
2. Pin invocation: `check "<pin-slug>" check_<name>` registered in `tests/smoke.sh` adjacent to existing related pins.
3. Classification: a line in `tests/smoke-proves-manifest.txt` mapping the helper to a class (`behavioral` / `schema` / `prompt-text`).

Python3 is required (probes + smoke helpers use `python3` heredocs and a shared module at `tests/smoke_rule_helpers.py`).

## Contribution flow — PR-only, auto-merge

**Do not commit directly to `main`.** Every change goes through a pull request, which Claude
creates and merges without waiting for explicit per-step approval (the user has authorized this
for this repo). The flow:

1. **Branch** — `git checkout -b <type>/<short-name>` where `<type>` matches the conventional
   prefix (`feat`, `fix`, `ci`, `docs`, `refactor`, `test`, `chore`).
2. **Commit** — conventional title: `feat(scope): …`, `fix: …`, etc. No `Co-Authored-By`
   lines. Scope is optional but helps.
3. **Push** — `git push -u origin <branch>`.
4. **PR** — `gh pr create --title "<conventional title>" --body "<summary + test plan>"`.
   The `pr-auto-label` workflow picks the conventional prefix and applies the matching
   label (`feature` / `fix` / `ci` / `documentation` / `refactor` / `tests` / `chore`).
5. **Merge** — `gh pr merge <N> --squash --delete-branch`. Immediate merge; there is no
   branch protection or required review in this repo.
6. **Release (if version bumped)** — if the PR changes `version` in
   `.claude-plugin/plugin.json`, the `release-on-version-bump` workflow creates the tag
   and release automatically after merge. Nothing to do manually.

### Why

- Release notes are generated from PR titles and labels via `.github/release.yml`. Direct
  commits to `main` show up only in the `Full Changelog` footer, not in the categorized
  sections — they look ugly.
- Every change is traceable to a titled, labeled PR.

### Public-output hygiene (R8)

KB is internal documentation. Commit messages, PR titles, PR bodies, and PR review comments — in this repo and in any other repo touched by an `ai-dev-team` workflow — MUST NOT reference KB paths (`<kb>/...`), spec paths, workdoc paths, finding-file paths, audit slugs, or footers like "Spec: …" / "Audit trail: …" / "Workdoc: …". Describe changes in repo-internal terms (files, behaviour, tests). Default Claude Code PR-template sections that don't fit this repo's flow ("Test plan", "Generated with Claude Code" footer) are also omitted by user standing instruction. Full rule + cleanup discipline + cross-audit publish carve-out: R8 in `skills/feature/references/code-quality-rules.md`.

### When to skip the flow

Only when the user explicitly says so (e.g. "just push this to main"). Default is PR flow.

### Useful commands

```bash
# Full cycle from a dirty worktree
git checkout -b feat/my-change
git add … && git commit -m "feat(scope): …"
git push -u origin feat/my-change
gh pr create --title "feat(scope): …" --body "…"
gh pr merge <N> --squash --delete-branch
```
