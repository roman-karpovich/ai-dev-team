# CLAUDE.md — ai-dev-team

## Mission

**Плагин ai-dev-team помогает разработке с нескольких сторон — ideation, disciplined execution, quality verification, persistent context, codified code-quality conventions — чтобы сократить bug-escape rate, поднять dev velocity, не терять контекст между сессиями, и получать качественный код от dev-agent'ов.**

Концерны плагина — не абстрактное "качество", а конкретные pain points: lack of discipline, weak tests, lost context, research fragmentation, spec drift, review quality, custom nuances не схваченные dev-agent'ами.

Axes (федерация, не иерархия):
- **Ideation** — `/investigate`, `/research` (выбор направления, brainstorm)
- **Orchestration** — `/feature` spec-driven flow (discipline backbone)
- **Verification** — `/cross-audit` (Claude+Codex + deterministic probes)
- **Code-quality conventions** — `code-quality-rules.md` R1-R7 для dev-agent'ов
- **Context persistence** — KB vault (specs, findings, research)
- **Self-protection** — smoke harness + hooks

**Current binding constraint** = audit coverage (закрыть cross-audit blind spots через probes E/F/G/…). Salient после aqua-bribes incidents; когда probe series stabilises + team rollout happens, binding может сместиться к другому axis'у. Mission остаётся прежней.

Полная формулировка + success criteria + operational rules: `<kb>/repos/ai-dev-team/MISSION.md`.

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
