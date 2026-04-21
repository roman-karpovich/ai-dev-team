## Summary

| ID | Severity | Issue | Source | Mode | Confidence | Status |
|----|----------|-------|--------|------|------------|--------|
| X1 | HIGH | Paging .limit(200) on unbounded Horizon history | probe:F+codex | warn | 100 | OPEN |

## Details

### [X1] Paging .limit(200) on unbounded Horizon history
- **Severity**: HIGH
- **File**: src/stellar/reconcile.py:87
- **Description**: Probe F + codex merged entry: missing cursor on Horizon paging.
- **Fix**: Use cursor-paged iteration.
- **Sources**: [probe:F, codex]
- **Mode at emit**: warn
- **Blocking**: false
- **Probe receipt**: <kb>/security/probe-receipts/X1.json
- **Probe version**: f.1.0
- **Eligible reason**: paging symbol at reconcile.py:87
- **Confidence**: 100
- **Status**: OPEN
