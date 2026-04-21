## Summary

| ID | Severity | Issue | Source | Mode | Confidence | Status |
|----|----------|-------|--------|------|------------|--------|
| X1 | CRITICAL | Missing input validation on /api/v1/deposit | claude+codex |  | 90 | OPEN |
| X2 | HIGH | Race condition in reward claim flow | claude |  | 85 | OPEN |

## Details

### [X1] Missing input validation on /api/v1/deposit
- **Severity**: CRITICAL
- **File**: src/api/deposit.py:42
- **Description**: Amount field not validated against account balance before persist call.
- **Fix**: Add balance-check guard before calling persist_deposit().
- **Sources**: [claude, codex]
- **Mode at emit**: 
- **Blocking**: false
- **Probe receipt**: null
- **Probe version**: null
- **Eligible reason**: null
- **Confidence**: 90
- **Status**: OPEN

### [X2] Race condition in reward claim flow
- **Severity**: HIGH
- **File**: src/rewards/claim.py:118
- **Description**: Two concurrent claim() calls can double-withdraw the pending reward.
- **Fix**: Wrap the read-modify-write in SELECT FOR UPDATE.
- **Sources**: [claude]
- **Mode at emit**: 
- **Blocking**: false
- **Probe receipt**: null
- **Probe version**: null
- **Eligible reason**: null
- **Confidence**: 85
- **Status**: OPEN
