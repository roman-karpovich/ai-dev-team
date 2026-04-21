⚠️  Haiku finding-scorer unavailable (Task-tool response malformed — unknown finding ID in scores map). LLM findings retain legacy self-reported confidence labels mapped to pseudo-confidence — rerun /cross-audit when scorer is restored for full decoupled scoring.

## Summary

| ID | Severity | Issue | Source | Mode | Confidence | Status |
|----|----------|-------|--------|------|------------|--------|
| X1 | HIGH | Possible injection in log formatter | claude |  | 90 | OPEN |
| X2 | HIGH | Unclear retry backoff | codex |  | 60 | OPEN |

## Details

### [X1] Possible injection in log formatter
- **Severity**: HIGH
- **File**: src/logs/fmt.py:18
- **Description**: User-controlled input reaches format string.
- **Fix**: Use %s placeholder with explicit args.
- **Sources**: [claude]
- **Mode at emit**: 
- **Blocking**: false
- **Probe receipt**: null
- **Probe version**: null
- **Eligible reason**: null
- **Confidence**: 90
- **Legacy pseudo-confidence**: true
- **Status**: OPEN

### [X2] Unclear retry backoff
- **Severity**: HIGH
- **File**: src/net/retry.py:40
- **Description**: Backoff scheme uses a magic constant.
- **Fix**: Extract to settings.
- **Sources**: [codex]
- **Mode at emit**: 
- **Blocking**: false
- **Probe receipt**: null
- **Probe version**: null
- **Eligible reason**: null
- **Confidence**: 60
- **Legacy pseudo-confidence**: true
- **Status**: OPEN
