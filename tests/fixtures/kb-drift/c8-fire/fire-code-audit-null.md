---
title: Terminal spec, code_audit_evidence literal-null (fire-c)
project: fixture
type: spec
status: SHIPPED
spec_audit_evidence: dual_model
code_audit_evidence: null
created: 2026-05-01
tags: [spec, fixture]
---

# Terminal spec, code_audit_evidence literal-null

SHIPPED + post-cutoff. `code_audit_evidence: null` is the literal-null defect on
the code key while `spec_audit_evidence:` is enum-valid → C8 fires.
