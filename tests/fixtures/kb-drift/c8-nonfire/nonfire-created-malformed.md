---
title: Terminal spec, created malformed (nonfire-created-malformed)
project: fixture
type: spec
status: SHIPPED
created: not-a-date
tags: [spec, fixture]
---

# Terminal spec, created malformed

SHIPPED with BOTH evidence keys absent, but `created: not-a-date` is not a
well-formed ISO date — date.fromisoformat rejects it → skip (conservative FN) →
no C8.
