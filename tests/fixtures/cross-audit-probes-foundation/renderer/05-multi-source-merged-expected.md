## Summary

| ID | Severity | Issue | Source | Mode | Confidence | Status |
|----|----------|-------|--------|------|------------|--------|
| X1 | HIGH | New build_failure: marker unread by _clean_rewards allowlist | probe:E+claude | warn | 100 | OPEN |

## Details

### [X1] New build_failure: marker unread by _clean_rewards allowlist
- **Severity**: HIGH
- **File**: src/stellar/reconcile.py:142
- **Description**: Probe E detected persisted-state marker 'build_failure:' added in diff; downstream consumer src/stellar/rewards.py:_clean_rewards allowlist does not include it. (Claude independently flagged the same gap.)
- **Fix**: Add 'build_failure' to the _clean_rewards allowlist in src/stellar/rewards.py.
- **Sources**: [probe:E, claude]
- **Mode at emit**: warn
- **Blocking**: false
- **Probe receipt**: <kb>/security/probe-receipts/X1.json
- **Probe version**: e.1.0
- **Eligible reason**: new persisted-state marker 'build_failure:' present in diff at reconcile.py:142
- **Confidence**: 100
- **Status**: OPEN
