---
title: {Feature Title}
project: {project-name}
type: spec
status: DRAFT
branch: feature/YYYY-MM-DD-{slug}
created: YYYY-MM-DD
tags: [spec, {project-name}]
---

## 1. Context

Why this feature is needed. Link to proposal, issue, or discussion.

## 2. Current State

How the system works today. Reference KB pages and source files.

## 3. Design

### 3.1 Overview

What changes and why. Keep it concise.

### 3.2 Changes

| File | Change | Reason |
|------|--------|--------|
| `path/to/file.py` | Add X | Because Y |

### 3.3 Data model changes

New or modified models, migrations, contract storage.

### 3.4 API changes

New or modified endpoints, contract interfaces.

### 3.5 Configuration

New env vars, settings, or constants.

## 4. Dependencies

External services, contracts, other repos involved.

## 5. Implementation Checklist

Ordered steps. Each is a concrete, reviewable unit of work — a behavioral change that can be verified independently.

For each step, the orchestrator initializes a corresponding `planned` block in the execution workdoc before implementation begins.

- [ ] Step 1: description
- [ ] Step 2: description
- [ ] ...

## 6. Verification

How to test the feature end-to-end after all steps are complete.

## 7. Execution Workdoc

The execution workdoc lives at:
```
<kb>/repos/<project>/design/workdocs/<slug>/exec.md
```

It tracks per-step planned intent and observed evidence. The orchestrator initializes it alongside this spec (planned fields only). The developer fills observed fields during implementation.

### Workdoc step schema

Each checklist step has a corresponding entry in exec.md:

```yaml
## Step N: <step title>

### Planned
goal: one sentence describing the observable behavioral change
allowed_scope: glob pattern for files this step may touch (e.g. src/module/**)
failing_test_cmd: command that should fail before implementation (empty if no test)
expected_failure_pattern: substring expected in failure output
passing_test_cmd: command that should pass after implementation
expected_pass_pattern: substring expected in passing output
integration_probe_cmd: (optional) command to confirm feature is reachable at runtime
expected_probe_signal: (optional) substring expected from probe

### Observed
actual_files_touched: []
commit_shas: []
red_capture: captures/step-NN-red.txt
green_capture: captures/step-NN-green.txt
probe_capture: (if applicable)
notes: ""
```

**DONE rule**: a step is not done until `green_capture` exists with content matching `expected_pass_pattern`. No capture = not done.

## 8. Log

Append-only. Record decisions, blockers, and progress.

### YYYY-MM-DD

- Created spec
