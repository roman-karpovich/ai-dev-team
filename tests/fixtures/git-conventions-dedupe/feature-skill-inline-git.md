### Git conventions

- **Base branch**: `master` or `main` — whichever exists in the repo (`git branch -r | grep -E 'origin/(master|main)$'`). Never cut from `staging`, `testnet`, `pre-prod`, or similar collection branches — those are staging dumps, not source of truth
- **Feature branch**: `<type>/YYYY-MM-DD-<slug>` — `<type>` is the spec's resolved `change_type` (one of `feat / fix / refactor / ci / docs / test / chore`); dated example: `feat/2026-04-17-my-feature` (or as specified in spec `Branch:` field; see R4 in `references/code-quality-rules.md`)
- **Feature dependencies**: if this feature depends on another in-flight feature, merge that feature's branch into this one directly. Do not route through staging
- Small logical commits per checklist step
- No "Co-authored-by" in commit messages
- No pushing — user handles pushing, staging merge, and PR

---

## Verify
