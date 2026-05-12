---
title: Synthetic fenced workdoc fixture
type: exec-workdoc-fixture
spec: spec.md
---

# Synthetic fenced workdoc fixture

## Step 1: Fence skip probe

### Planned
goal: Exercise parser handling of fenced markdown examples in planned blocks.
allowed_scope: tests/fixtures/workdoc-assertion-count-parity/**
passing_test_cmd: n=$((n+1))
expected_pass_pattern: "1"

```yaml
passing_test_cmd: echo bogus
expected_pass_pattern: "99"
```

### Observed
actual_files_touched: []
commit_shas: []
notes: ""
