# Example spec

## 1. Context

The §1.1 heading lives inside a 4-backtick ````markdown fence that itself
wraps a 3-backtick ```yaml block — mirroring spec-template.md §1.1. The
3-backtick lines are fence CONTENT of the open 4-backtick fence (they carry
no closer semantics for a 4-backtick fence), so the heading stays inside.

````markdown
## 1.1 Attack-surface profile

```yaml
attack_surface:
  not_applicable: true
```
````

## 2. Current State

Current state prose.
