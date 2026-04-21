## Low-confidence LLM findings (advisory)

| ID | Severity | Issue | Source | Mode | Confidence | Status |
|----|----------|-------|--------|------|------------|--------|
| X1 | HIGH | Possible race condition in retry queue | claude |  | 45 | OPEN |

## Details

### [X1] Possible race condition in retry queue
- **Severity**: HIGH
- **File**: src/stellar/retry.py:52
- **Description**: claude flagged a possible race but evidence is weak.
- **Fix**: Add a lock around the queue.push call.
- **Sources**: [claude]
- **Mode at emit**: 
- **Blocking**: false
- **Probe receipt**: null
- **Probe version**: null
- **Eligible reason**: null
- **Confidence**: 45
- **Status**: OPEN
