# Example spec

## 1. Context

This fixture is run with a <section-ere> crafted to match a backtick
fence-OPENER line. The opener below is a fence-delimiter line, so it must
NOT count as a section match — the helper distinguishes a section heading
from fence syntax.

```yaml
attack_surface:
  not_applicable: true
```

## 2. Current State

Current state prose, no column-0 backtick run outside a fence.
