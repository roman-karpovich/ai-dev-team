---
title: Terminal spec, spec_audit_evidence literal-null (fire-b)
project: fixture
type: spec
status: VERIFIED
spec_audit_evidence: null
code_audit_evidence: single_model
created: 2026-06-01
tags: [spec, fixture]
---

# Terminal spec, spec_audit_evidence literal-null

VERIFIED + post-cutoff. `spec_audit_evidence: null` is the literal-null defect
shape (an absence-only gate would miss it) → C8 fires naming literal-null.
