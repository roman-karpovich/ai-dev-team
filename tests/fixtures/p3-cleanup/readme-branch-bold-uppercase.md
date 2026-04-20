# README (audit X5 fixture — bold-wrapped uppercase Branch)

## Frontmatter reference

The feature skill auto-detects `master` or `main`. For a non-standard base, set the **Branch:** field in the spec frontmatter.

```yaml
**Branch:** feat/2026-04-17-my-feature
```

<!--
Pre-X5-fix, check_branch_frontmatter_ref_lowercase only rejected the
backtick-wrapped form `Branch:`. The fix broadens to reject ANY 'Branch:'
occurrence, so this fixture (using **Branch:** bold-wrapped) must now
reject.
-->
