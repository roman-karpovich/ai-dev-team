### Feature Spec frontmatter
```yaml
---
title: <feature title>
project: <project name>
type: spec
status: DRAFT | APPROVED | AUDIT_PASSED | IN_PROGRESS | DONE | DISCARDED
created: YYYY-MM-DD
tags: [spec, <project>]
---
```

Valid status transitions: `DRAFT → APPROVED → AUDIT_PASSED → IN_PROGRESS → DONE` or `IN_PROGRESS → DISCARDED` (user discarded work after verify)
- `DRAFT`: spec written, not yet reviewed by user
- `APPROVED`: user approved the spec, spec audit not yet run
- `AUDIT_PASSED`: dual-model spec audit passed (no CRITICAL/HIGH), ready for implementation
- `IN_PROGRESS`: developer agent is actively implementing
- `DONE`: all checklist steps complete, verification passed, work preserved (merged/pushed/kept)
- `DISCARDED`: user discarded the feature branch after verification; spec preserved for reference only

### Next section stub
