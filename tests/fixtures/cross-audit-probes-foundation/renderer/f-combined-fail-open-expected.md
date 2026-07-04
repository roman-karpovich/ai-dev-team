⚠️  Probe(s) fail-opened this iteration — findings may be incomplete:
  - probe:F (reason: git diff returned non-zero in isolated worktree; remediation: re-run /cross-audit after checking out base branch cleanly)
⚠️  Haiku finding-scorer unavailable (mock scorer JSON missing score for X2). LLM findings retain legacy self-reported confidence labels mapped to pseudo-confidence — rerun /cross-audit when scorer is restored for full decoupled scoring.

## Summary

| ID | Severity | Issue | Source | Mode | Confidence | Status |
|----|----------|-------|--------|------|------------|--------|
| X2 | HIGH | Race condition in rewards queue | claude |  | 90 | OPEN |

## Shadow findings (informational)

| ID | Severity | Issue | Source | Mode | Confidence | Status |
|----|----------|-------|--------|------|------------|--------|
| X1 | HIGH | Probe E shadow: build_failure marker unread | probe:E | shadow | 100 | OPEN |

## Details

### [X2] Race condition in rewards queue
- **Severity**: HIGH
- **File**: src/rewards/queue.py:33
- **Description**: Concurrent queue push without lock.
- **Failure class / input domain**: 
- **Fix (advisory)**: Serialize with mutex.
- **Sources**: [claude]
- **Mode at emit**: 
- **Blocking**: false
- **Probe receipt**: null
- **Probe version**: null
- **Eligible reason**: null
- **Confidence**: 90
- **Legacy pseudo-confidence**: true
- **Status**: OPEN

### [X1] Probe E shadow: build_failure marker unread
- **Severity**: HIGH
- **File**: src/stellar/reconcile.py:142
- **Description**: Probe E flagged the marker.
- **Failure class / input domain**: 
- **Fix (advisory)**: Add to allowlist.
- **Sources**: [probe:E]
- **Mode at emit**: shadow
- **Blocking**: false
- **Probe receipt**: <kb>/security/probe-receipts/X1.json
- **Probe version**: e.1.0
- **Eligible reason**: marker detected at reconcile.py:142
- **Confidence**: 100
- **Status**: OPEN
