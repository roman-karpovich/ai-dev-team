## Shadow findings (informational)

| ID | Severity | Issue | Source | Mode | Confidence | Status |
|----|----------|-------|--------|------|------------|--------|
| X1 | HIGH | New build_failure: marker unread by _clean_rewards allowlist | probe:E+claude | shadow | 100 | OPEN |

## Details

### [X1] New build_failure: marker unread by _clean_rewards allowlist
- **Severity**: HIGH
- **File**: src/stellar/reconcile.py:142
- **Description**: Probe E + claude merged entry: build_failure marker not consumed.
- **Fix**: Add build_failure to _clean_rewards allowlist.
- **Sources**: [probe:E, claude]
- **Mode at emit**: shadow
- **Blocking**: false
- **Probe receipt**: <kb>/security/probe-receipts/X1.json
- **Probe version**: e.1.0
- **Eligible reason**: marker at reconcile.py:142
- **Confidence**: 100
- **Status**: OPEN
