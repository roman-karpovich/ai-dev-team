---
title: Malformed-trailing-bracketed fixture — Continue-mode partial-write edge case (X7)
project: ai-dev-team-test-fixture
type: spec
status: IN_PROGRESS
change_type: feat
created: 2026-04-27
---

# Malformed-trailing-bracketed fixture (iter-4 X7)

Synthetic spec exercising the §3.7 partial-write edge case for the
**bracket-truncation** shape. The malformed-trailing fixture (sibling
directory) covers TEXT truncation (`code audit iter`); this fixture
covers a real-world Codex fail-open shape where a single_model marker
ends mid-quote with an internal `]` from an `[Errno NN]`-style stderr
token, no closing `]` for the outer `blockers=[...]` list.

The pre-iter-4 helper regex `blockers=\[.*\]` would silently accept the
truncated line as a complete marker because the internal `]` of
`[Errno 61]` satisfies `\]$`. The iter-4 regex
`blockers=\[(\[\]|[^][]|\[[^]]*\])*\]` correctly encodes the YAML list
grammar so truncated lines are rejected and the helper falls back to
the prior complete `iteration=1` marker per SKILL.md §3.7.

Target state: all implementation steps `[x]`; Log has one complete
`code audit iteration=1` marker followed by a truncated trailing line
with an unclosed `blockers=[...]` outer bracket and a closed internal
`[Errno 61]` token. Branch 4 semantics then fire (re-present
OPEN/REOPENED findings; no new cross-auditor spawn).

Expected routing:
- `_fixture_latest_code_audit_marker` returns the complete iteration=1
  marker (NOT the truncated trailing line).
- Latest-marker branch matches `code audit iteration=N`.

## 5. Implementation Checklist

- [x] Step 1: synthetic placeholder step (fixture only; does nothing).

## 9. Log

### 2026-04-27

- Created fixture.
- 2026-04-27: code audit iteration=1; fixed_ids=[]; accepted_ids=[]
- 2026-04-27: code audit passed; iteration=1; verified=[], accepted=[], deferred=[]; evidence=single_model; blockers=['codex audit unavailable: [Errno 61]
