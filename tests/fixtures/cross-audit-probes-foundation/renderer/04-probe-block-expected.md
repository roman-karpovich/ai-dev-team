## Summary

| ID | Severity | Issue | Source | Mode | Confidence | Status |
|----|----------|-------|--------|------|------------|--------|
| X1 | HIGH | New test in step N claims failing_test_cmd but ships no red_capture | probe:G | block | 100 | OPEN |

## Details

### [X1] New test in step N claims failing_test_cmd but ships no red_capture
- **Severity**: HIGH
- **File**: tests/fixtures/new-feature/exec.md
- **Description**: Probe G detected step-N entry with failing_test_cmd declaration but no corresponding red_capture path under captures/.
- **Failure class / input domain**: 
- **Fix (advisory)**: Run the failing test once and save the output to captures/step-NN-red.txt before committing.
- **Sources**: [probe:G]
- **Mode at emit**: block
- **Blocking**: true
- **Probe receipt**: <kb>/security/probe-receipts/X1.json
- **Probe version**: g.1.0
- **Eligible reason**: step claims failing_test_cmd without accompanying red_capture path
- **Confidence**: 100
- **Status**: OPEN
