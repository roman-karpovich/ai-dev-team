# Developer Workflow (shared)

This reference defines the common workflow that every developer agent in this plugin (`developer-codex`, `developer-middle`, `developer-senior`) must follow. Each agent file describes only *when* to pick that agent and the *agent-specific* rules. The step-by-step protocol, evidence captures, test quality, spec updates, git workflow, and common rules live here so they stay in sync.

---

## Input

Every developer agent receives in its prompt:

- **spec_path** — absolute path to the spec file in the KB
- **workdoc_path** — absolute path to the execution workdoc (`exec.md`). The workdoc carries `planned` fields per step; you fill the `observed` fields as you work.
- **project_path** — absolute path to the source repo
- **task** — what to implement: `"full spec"`, `"step N only"`, `"steps N-M"`, or `"rework step N: <feedback>"`
- **context** — optional notes from the user or a previous agent

---

## Workflow

1. **Read the spec** from `spec_path`. Understand: Context, Current State, Design, checklist, constraints.
2. **Read the execution workdoc** from `workdoc_path`. Read the `planned` block for every step in your scope before writing any code.
3. **Set spec `status: IN_PROGRESS`** in the spec frontmatter before writing any code. Never start if `status: DRAFT` — the spec has not been approved.
4. **Identify your scope**: which checklist steps to work on, based on `task`.
5. **Read relevant source files** before writing. Understand existing patterns, style, dependencies.
6. **For each step in order** — follow the Per-step protocol below.
7. **Blockers**: if you cannot proceed (ambiguity, missing dependency, spec contradiction), stop and report to the user. Append a brief note to the spec Log. Do NOT guess and expand scope silently.
8. **When your scope is complete**: leave `status: IN_PROGRESS`. Do NOT set `status: DONE`. The feature-skill orchestrator owns the DONE transition after the verifier passes.

---

## Per-step protocol

For each step, execute steps a–k in order. A step is not complete until step k says it is.

**a. Read the step's `planned` block** in the workdoc.

**b. Red capture** — two valid approaches:

- *Test-first*: if `planned.failing_test_cmd` is set and the test already exists, run it before implementing. Save stdout+stderr to `<dirname(workdoc_path)>/captures/step-NN-red.txt`.
- *Fix-first (retrospective red)*: if writing the test in isolation is impractical, write the fix and the test together, then `git stash` the fix, run the test, save output to `captures/step-NN-red.txt`, then `git stash pop`.

Either way, a red capture is required — it proves the test has real signal. Update `observed.red_capture` to point at the file.

**c. Implement the change** (or `git stash pop` the already-written fix), staying inside `planned.allowed_scope`. Never modify files outside the allowed scope.

**d. Run `planned.passing_test_cmd`** from `project_path`. Save stdout+stderr to `<dirname(workdoc_path)>/captures/step-NN-green.txt`. Update `observed.green_capture`.

**e. Verify** the green capture contains `planned.expected_pass_pattern`. If not, the step is not green — debug before continuing.

**f. Probe (optional)**: if `planned.integration_probe_cmd` is set, run it from `project_path`, save output to `captures/step-NN-probe.txt`, update `observed.probe_capture`. Verify the probe output contains `planned.expected_probe_signal`.

**g. Linter** — run and fix warnings **introduced by your changes** (do not fix pre-existing warnings in code you didn't touch — that's someone else's technical debt):

- Rust: `cargo fmt` (always), then `cargo clippy` on changed packages
- Python: `ruff format .` (always), `ruff check <changed files>`
- Go: `gofmt -w <changed files>`, `go vet ./...`
- JS/TS: `prettier --write <changed files>`, `eslint <changed files> --fix`

Check the project's Makefile / config to confirm which linter is in use. If there is no linter configured for the language, skip.

**h. Commit** — one small logical commit per step. Concise imperative commit message. **No `Co-authored-by` lines.** Only stage files directly related to this step — never `git add -A` or `git add .`.

**i. Update `observed`** fields in the workdoc:

- `observed.actual_files_touched` — list of files changed in this commit
- `observed.commit_shas` — append the commit SHA (after committing, so the SHA exists). If you rework, **append** the new SHA — do not replace; keep the full history.

**j. Spawn `spec-compliance-checker`** subagent with: `spec_path`, `workdoc_path`, `step_number`, `project_path`.

- If the result is **PASS** → proceed to k.
- If the result is **FAIL** or **DRIFT** → fix every listed issue, re-run captures, re-commit, append the new SHA, then re-spawn the compliance checker. Continue only when PASS.

**k. Check off the step** in the spec checklist (`- [ ]` → `- [x]`) and append a terse note to the spec Log section (append-only, never edit past entries).

---

## Test Quality

When writing tests:

- **Match existing structure**: read 2–3 tests in the same file/directory first. Match their structure, naming, fixtures, and assertion style — do not invent a new pattern.
- **Exact assertions**: assert on specific values (`assert_eq!(x, 42)`), not vague checks (`> 0`, `is not None`). Vague checks miss regressions where the value changes but stays truthy.
- **Expected values**:
  - Trivially derivable from test inputs → express it: `assert_eq!(reserve, deposit1 + deposit2)`.
  - Complex formula → use an explicit constant; replicating complex logic risks copying the bug.
  - Named intermediate variables for call arguments/setup are fine; assertions themselves stay simple.
- **No flaky tests**: freeze dates/times (freezegun, MockClock, `jest.useFakeTimers`), seed random values. A test that can fail on a Friday or after a year is a time bomb. If you cannot freeze a value, flag it as a design smell — don't write a fuzzy assertion.

---

## Spec Updates

Update the spec file directly during work:

- Check off completed steps: `- [ ]` → `- [x]` (only after compliance PASS).
- **Append** to the Log section (append-only): `- YYYY-MM-DD: <decision or note>`. Never edit past Log entries.
- Leave `status: IN_PROGRESS` when done — the feature-skill orchestrator owns the DONE transition after the verifier passes.

---

## Git Workflow

- **Feature branch** — never commit to `master` / `main` directly. Branch name: `feature/<YYYY-MM-DD-slug>` or whatever the spec `Branch:` field specifies.
- **Base branch detection** — `master` or `main`, whichever exists: `git branch -r | grep -E 'origin/(master|main)$'`. Prefer `master` if both exist. **Never** cut from `staging`, `testnet`, `pre-prod`, or any other collection branch — those are staging dumps, not the source of truth.
- **Feature dependencies** — if this feature depends on another in-flight feature, merge that feature's branch into this one directly (`git merge feature/other-slug`). Do not route through staging.
- **Branch already exists** — `git checkout <branch>` (don't re-create). If it exists on remote only: `git fetch` then checkout tracking.
- **Small logical commits** — one per checklist step (or coherent sub-task).
- **Commit messages** — concise, imperative mood. No `Co-authored-by` lines.
- **No push** — the user handles pushing, staging merge, and PR creation.

---

## Common Rules

- **Never start if `status: DRAFT`** — the spec has not been approved.
- **Stay in scope** — only modify files inside `planned.allowed_scope`. If the task genuinely needs to expand, stop and report; don't expand silently.
- **No speculative additions** — implement exactly what the spec says. No extra features, error handling, or abstractions.
- **Multi-agent safety** — if you notice changes in the worktree you didn't make, leave them alone; another agent may be working concurrently.
- **No comments on code you didn't write.** Only add a comment when the WHY is non-obvious.
- **Report blockers immediately** — don't guess, don't expand scope. A clear "I'm blocked by X" is worth more than an incorrect implementation.
- **If the spec is wrong or contradictory** — say so directly and stop. Don't build something you know is incorrect just to appear cooperative.
- **Don't narrate.** No "Now I'll implement...", no "Great, I've completed...". Make the change, write the capture, update the workdoc. Actions speak; the workdoc is the trace.
