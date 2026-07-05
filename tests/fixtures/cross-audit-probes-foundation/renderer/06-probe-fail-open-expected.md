⚠️  Probe(s) fail-opened this iteration — findings may be incomplete:
  - probe:E (reason: git diff returned non-zero in isolated worktree; remediation: re-run /cross-audit after checking out base branch cleanly)

## Summary

| ID | Severity | Issue | Source | Mode | Confidence | Status |
|----|----------|-------|--------|------|------------|--------|
| X1 | HIGH | SQL injection in GET /users search endpoint | claude+codex |  | 90 | OPEN |

## Details

### [X1] SQL injection in GET /users search endpoint
- **Severity**: HIGH
- **File**: src/api/users.py:67
- **Description**: search_query parameter is concatenated directly into the LIKE clause without parameterization.
- **Failure class / input domain**: 
- **Fix (advisory)**: Use parameterized query with bind variables.
- **Sources**: [claude, codex]
- **Mode at emit**: 
- **Blocking**: false
- **Probe receipt**: null
- **Probe version**: null
- **Eligible reason**: null
- **Confidence**: 90
- **Status**: OPEN
