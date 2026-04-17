---
title: Audit Findings — pr-aware-cross-audit fixture
project: ai-dev-team
type: audit-findings
mode: full
iteration: 1
created: 2026-04-17
tags: [audit, ai-dev-team, fixture]
pr_number: 472
pr_repo: roman-karpovich/ai-dev-team
pr_url: https://github.com/roman-karpovich/ai-dev-team/pull/472
pr_head_oid: 1a2b3c4d5e6f7890abcdef1234567890abcdef12
pr_files:
  - filename: src/foo.rs
    status: modified
    previous_filename: null
    patch_present: true
    is_submodule: false
  - filename: src/bar.rs
    status: renamed
    previous_filename: src/bar_old.rs
    patch_present: false
    is_submodule: false
  - filename: src/baz.rs
    status: renamed
    previous_filename: src/baz_old.rs
    patch_present: true
    is_submodule: false
  - filename: assets/logo.png
    status: modified
    previous_filename: null
    patch_present: false
    is_submodule: false
  - filename: vendor/submod
    status: modified
    previous_filename: null
    patch_present: false
    is_submodule: true
  - filename: src/ambig.rs
    status: modified
    previous_filename: null
    patch_present: true
    is_submodule: false
---

# Audit Findings: pr-aware-cross-audit fixture
- Date: 2026-04-17
- Iteration: 1
- Mode: full
- Codex: OK
- Status: IN PROGRESS

## Summary

| ID | Severity | Issue | Claude | Codex | Confidence | Status |
|----|----------|-------|--------|-------|------------|--------|
| X1 | HIGH     | foo.rs inline-addressable bug  | x | x | HIGH    | OPEN     |
| X2 | HIGH     | baz.rs rename-with-edits bug   | x | x | HIGH    | OPEN     |
| X3 | HIGH     | bar.rs pure-rename concern     | x | - | REVIEW  | REOPENED |
| X4 | HIGH     | logo.png binary asset flag     | x | - | REVIEW  | ACCEPTED |
| X5 | HIGH     | vendor/submod submodule bump   | - | x | REVIEW  | DEFERRED |
| X6 | MEDIUM   | duplicate finding — dropped    | x | - | REVIEW  | INVALID  |
| X7 | HIGH     | foo.rs already-fixed           | x | x | HIGH    | FIXED    |
| X8 | HIGH     | foo.rs previously-fixed clean  | x | x | HIGH    | VERIFIED |

## Details

### [X1] foo.rs inline-addressable bug
- **Severity**: HIGH
- **Found by**: Both (high confidence)
- **File**: src/foo.rs:42
- **Description**: division by zero possible when amount < 1000
- **Fix**: guard with `if bonus == 0 { return base; }`
- **Status**: OPEN

### [X2] baz.rs rename-with-edits bug
- **Severity**: HIGH
- **Found by**: Both (high confidence)
- **File**: src/baz.rs:95
- **Description**: timeout doubled without justification
- **Fix**: revert timeout to 30 or document reason
- **Status**: OPEN

### [X3] bar.rs pure-rename concern
- **Severity**: HIGH
- **Found by**: Claude only
- **File**: src/bar.rs:1
- **Description**: pure rename; routing must send to body bucket
- **Fix**: N/A — pure rename has no line to anchor on
- **Status**: REOPENED

### [X4] logo.png binary asset flag
- **Severity**: HIGH
- **Found by**: Claude only
- **File**: assets/logo.png:1
- **Description**: binary file — body bucket
- **Fix**: revert or commit-message-document binary change
- **Status**: ACCEPTED

### [X5] vendor/submod submodule bump
- **Severity**: HIGH
- **Found by**: Codex only
- **File**: vendor/submod:1
- **Description**: submodule pointer bumped — body bucket
- **Fix**: verify submodule change is intentional
- **Status**: DEFERRED

### [X6] duplicate finding — dropped
- **Severity**: MEDIUM
- **Found by**: Claude only
- **File**: src/ambig.rs:1
- **Description**: per-file parser ambiguity — routing must fall back to body bucket
- **Fix**: N/A — false positive, invalid
- **Status**: INVALID

### [X7] foo.rs already-fixed
- **Severity**: HIGH
- **Found by**: Both (high confidence)
- **File**: src/foo.rs:10
- **Description**: previously fixed issue — must not appear in default `publish all`
- **Fix**: already applied
- **Status**: FIXED

### [X8] foo.rs previously-fixed clean
- **Severity**: HIGH
- **Found by**: Both (high confidence)
- **File**: src/foo.rs:20
- **Description**: previously verified fix — must not appear in default `publish all`
- **Fix**: already applied and verified
- **Status**: VERIFIED
