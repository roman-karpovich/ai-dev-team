---
title: Terminal spec, spec_audit_evidence absent (fire-a)
project: fixture
type: spec
status: SHIPPED
code_audit_evidence: dual_model
created: 2026-07-01
tags: [spec, fixture]
---

# Terminal spec, spec_audit_evidence absent

SHIPPED + post-cutoff, but the `spec_audit_evidence:` key is absent while
`code_audit_evidence:` is enum-valid → C8 fires naming the missing key.
