---
title: Malformed-trailing fixture — Continue-mode partial-write edge case
project: ai-dev-team-test-fixture
type: spec
status: IN_PROGRESS
change_type: feat
created: 2026-04-22
---

# Malformed-trailing fixture

Synthetic spec exercising the §3.7 partial-write edge case per
`skills/feature/SKILL.md` §Continue mode: "Malformed or truncated trailing
code-audit Log lines are ignored; fall back to the last complete
recognized marker above."

Target state: all implementation steps `[x]`; Log has one complete
`code audit iteration=1` marker followed by a truncated / malformed
trailing line (simulating a crash mid-write). The routing emulator
must ignore the malformed trailing line and fall back to the last
complete marker, which is the iteration=1 spawn completion. Branch 4
semantics then fire: re-present OPEN/REOPENED findings from the
findings file (no new cross-auditor spawn).

Expected routing:
- `_fixture_latest_code_audit_marker` returns the complete iteration=1
  marker (NOT the truncated trailing line).
- Latest-marker branch matches `code audit iteration=N`.
- Reconstructed previously_fixed=[] and accepted_ids=[] from the
  iteration=1 marker's fixed_ids / accepted_ids fields.

## 5. Implementation Checklist

- [x] Step 1: synthetic placeholder step (fixture only; does nothing).

## 9. Log

### 2026-04-22

- Created fixture.
- 2026-04-22: code audit iteration=1; fixed_ids=[]; accepted_ids=[]
- 2026-04-22: code audit iter
