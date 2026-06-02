# KB Layout Reference

Canonical reference for the Knowledge Base (Obsidian vault) layout: document
paths, frontmatter schemas, and the spec status state-machine. Both the
orchestrator and the librarian agent consume this file. Moved out of
`agents/librarian.md` so the canonical content has a home that is not an agent
definition.

## Document Paths

Follows the same convention as aquarius-knowledge: each project has its own subfolder under `repos/`.

| Type | Path |
|------|------|
| Feature spec | `<kb_root>/repos/<project>/design/YYYY-MM-DD-<slug>.md` |
| Audit findings | `<kb_root>/repos/<project>/security/YYYY-MM-DD-<slug>-findings.md` |
| Audit workdoc | `<kb_root>/repos/<project>/security/YYYY-MM-DD-<slug>-workdoc-iter<N>.md` |
| Research note | `<kb_root>/repos/<project>/research/YYYY-MM-DD-<slug>.md` |
| Postmortem | `<kb_root>/repos/<project>/postmortems/YYYY-MM-DD-<slug>.md` |

Create subdirectories as needed (`repos/<project>/design/`, `repos/<project>/security/`, etc.).

## Document Formats

### Feature Spec frontmatter
```yaml
---
title: <feature title>
project: <project name>
type: spec
status: DRAFT | APPROVED | AUDIT_PASSED | IN_PROGRESS | BLOCKED | SHIPPED | VERIFIED | DISCARDED
created: YYYY-MM-DD
tags: [spec, <project>]
---
```

Valid transitions:
  DRAFT → APPROVED → AUDIT_PASSED → IN_PROGRESS → SHIPPED → VERIFIED
                                         ↕
                                     BLOCKED
  Any non-terminal → DISCARDED (explicit `/feature discard`).
  DONE: legacy read-only synonym of VERIFIED — accepted when reading older
  specs, never written by new transitions.

- `DRAFT`: spec written, not yet reviewed by user
- `APPROVED`: user approved the spec, spec audit not yet run
- `AUDIT_PASSED`: dual-model spec audit passed (or skipped), ready for implementation
- `IN_PROGRESS`: developer agent is actively implementing
- `BLOCKED`: work paused on an external dependency; unblock condition recorded in Log
- `SHIPPED`: feature merged, post-merge checklist still has open items; `/feature verify` closes it when all items resolve
- `VERIFIED`: terminal — feature complete, observed, all post-merge items resolved
- `DISCARDED`: work thrown away via explicit `/feature discard`; spec preserved for reference
- `DONE` *(legacy)*: read-only synonym of `VERIFIED` for specs predating 2026-04-17

### Audit Findings frontmatter
```yaml
---
title: Audit Findings — <scope>
project: <project name>
type: audit-findings
iteration: N
created: YYYY-MM-DD
tags: [audit, <project>]
---
```

### Audit Workdoc frontmatter
```yaml
---
title: Audit Workdoc — <scope> (iter N)
project: <project name>
type: audit-workdoc
iteration: N
created: YYYY-MM-DD
tags: [audit, workdoc, <project>]
---
```

### Research Note frontmatter
```yaml
---
title: <research title>
project: <project name>
type: research
subtype: incident-investigation | math-model | competitive-analysis | exploration
status: ACTIVE | CONCLUDED | ARCHIVED
created: YYYY-MM-DD
tags: [research, <project>]
---
```

Research notes are free-form. Use for: incident investigations before a postmortem is ready, mathematical modeling, competitive analysis, exploratory work without a clear spec.

## Index / MOC one-liner convention

An index or MOC page (a doc whose frontmatter `type:` is `index` or `moc`, or the per-vault `vault-index.md`) is a one-line-per-page map: read the index first, deep-read only what you need. Keep each entry to one sentence — in an index/MOC table, **no single summary cell** (and no list-entry) exceeds ~300 chars. Detail belongs on the page, not in the index row. The `/kb-audit` C6 check enforces this per-cell (it measures the longest single cell of a table row, not the whole-row total) and flags any cell or list-entry over the budget; the fix is a human/librarian call (summarize, move detail to the page) — it is reported, never auto-trimmed.
