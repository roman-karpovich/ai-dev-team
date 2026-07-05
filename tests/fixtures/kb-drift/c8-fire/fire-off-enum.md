---
title: Terminal spec, off-enum evidence value (fire-d)
project: fixture
type: spec
status: VERIFIED
spec_audit_evidence: bogus_value
code_audit_evidence: dual_model
created: 2026-06-15
tags: [spec, fixture]
---

# Terminal spec, off-enum evidence value

VERIFIED + post-cutoff. `spec_audit_evidence: bogus_value` is off the 5-value
enum (not absent, not literal-null) → C8 fires naming the off-enum shape.
