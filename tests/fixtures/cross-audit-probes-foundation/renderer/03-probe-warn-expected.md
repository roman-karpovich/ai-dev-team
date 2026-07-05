## Summary

| ID | Severity | Issue | Source | Mode | Confidence | Status |
|----|----------|-------|--------|------|------------|--------|
| X1 | HIGH | Paging .limit(200) on unbounded Horizon history | probe:F | warn | 100 | OPEN |

## Details

### [X1] Paging .limit(200) on unbounded Horizon history
- **Severity**: HIGH
- **File**: src/stellar/reconcile.py:87
- **Description**: Probe F detected .limit(200).order(desc=False) on Horizon history without cursor; production cardinality is unbounded years of data.
- **Failure class / input domain**: 
- **Fix (advisory)**: Use cursor-paged iteration with an explicit upper bound.
- **Sources**: [probe:F]
- **Mode at emit**: warn
- **Blocking**: false
- **Probe receipt**: <kb>/security/probe-receipts/X1.json
- **Probe version**: f.1.0
- **Eligible reason**: paging call .limit(200) detected on Horizon history without cursor at reconcile.py:87
- **Confidence**: 100
- **Status**: OPEN
