### Git conventions

Feature skill follows the plugin's canonical Git Workflow — see `skills/feature/references/developer-workflow.md` §Git Workflow. Key points relevant at hand-off: small logical commits per step, no `Co-authored-by`, no pushing (user owns push/PR). The canonical section includes the load-bearing pre-commit branch assertion and post-merge bug flow.

- **Feature dependencies**: if this feature depends on another in-flight feature, merge that feature's branch into this one directly. Do not route through staging

---

## Verify
