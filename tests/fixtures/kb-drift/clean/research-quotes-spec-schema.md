---
title: A Research Note Quoting the Spec Schema
project: fixture
type: research
status: ACTIVE
created: 2026-05-31
tags: [research, fixture]
---

# A Research Note Quoting the Spec Schema

This note documents the feature-spec frontmatter schema inside a fenced code
block. C3 must scope to the LEADING frontmatter only — the quoted `type: spec`
below must NOT misclassify this `type: research` / `status: ACTIVE` note as a
spec, and the body `status: DRAFT` must NOT be flagged. No C3 finding.

```yaml
type: spec
status: DRAFT
```
