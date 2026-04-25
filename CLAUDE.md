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
