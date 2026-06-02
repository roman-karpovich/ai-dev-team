# Developer Workflow (shared)

This reference defines the common workflow that every developer agent in this plugin (`developer-codex`, `developer-senior`) must follow. Each agent file describes only *when* to pick that agent and the *agent-specific* rules. The step-by-step protocol, evidence captures, test quality, spec updates, git workflow, and common rules live here so they stay in sync.

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
8. When your scope is complete: leave status: IN_PROGRESS. Do NOT set a terminal status. The feature-skill orchestrator owns the terminal transition (VERIFIED / SHIPPED, per §3.4a of feature/SKILL.md) after the verifier passes and the user picks a hand-off option.

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

**h. Commit** — one small logical commit per step. Concise imperative commit message. R8 hygiene applies (no KB refs / no `Co-authored-by`) — see R8 in `code-quality-rules.md`. Only stage files directly related to this step — never `git add -A` or `git add .`.

**i. Update `observed`** fields in the workdoc:

- `observed.actual_files_touched` — list of files changed in this commit
- `observed.commit_shas` — append the commit SHA (after committing, so the SHA exists). If you rework, **append** the new SHA — do not replace; keep the full history.
- `observed.commit_message_grep` (optional but recommended) — a regex the compliance checker can use to re-find the step's commits if the SHAs are ever invalidated. Use a stable stem like `"Step N"` or the step's title. If you `git commit --amend` or rebase, the old SHAs become unreachable — keep this field set so the compliance checker's tiered fallback can still diff the correct range.

If the step adds or modifies a fresh test, `observed.notes` must include a one-sentence description of the regression the test catches (see R3).

**j. Spawn `spec-compliance-checker`** subagent with: `spec_path`, `workdoc_path`, `step_number`, `project_path`.

- If the result is **PASS** → proceed to k.
- If the result is **FAIL** or **DRIFT** → fix every listed issue, re-run captures, re-commit, append the new SHA, then re-spawn the compliance checker. Continue only when PASS.

**k. Check off the step** in the spec checklist (`- [ ]` → `- [x]`) and append a terse note to the spec Log section (append-only, never edit past entries).

---

## Test Quality

When writing tests:

- **Match existing structure** *(pillar (4) maintainability)*: read 2–3 tests in the same file/directory first. Match their structure, naming, fixtures, and assertion style — do not invent a new pattern.
- **Exact assertions** *(pillar (1) protection against regressions)*: assert on specific values (`assert_eq!(x, 42)`), not vague checks (`> 0`, `is not None`). Vague checks miss regressions where the value changes but stays truthy.
- **Expected values** *(pillars (2) resistance to refactoring and (4) maintainability)*:
  - Trivially derivable from test inputs → express it: `assert_eq!(reserve, deposit1 + deposit2)`.
  - Complex formula → use an explicit constant; replicating complex logic risks copying the bug.
  - Named intermediate variables for call arguments/setup are fine; assertions themselves stay simple.
- **No flaky tests** *(pillars (3) fast feedback and (4) maintainability)*: freeze dates/times (freezegun, MockClock, `jest.useFakeTimers`), seed random values. A test that can fail on a Friday or after a year is a time bomb. If you cannot freeze a value, flag it as a design smell — don't write a fuzzy assertion.

For test strength (whether a test actually catches regressions), see R3 in `code-quality-rules.md`.
For test scope (what level the test is applied to — user-facing contract vs internal collaborators), see R6 in `code-quality-rules.md`.

---

## Spec Updates

Update the spec file directly during work:

- Check off completed steps: `- [ ]` → `- [x]` (only after compliance PASS).
- **Append** to the Log section (append-only): `- YYYY-MM-DD: <decision or note>`. Never edit past Log entries.
- Leave status: IN_PROGRESS when done — the feature-skill orchestrator owns the terminal transition (VERIFIED / SHIPPED, per §3.4a of feature/SKILL.md) after the verifier passes and the user picks a hand-off option.

---

## Git Workflow

- **Feature branch** — never commit to `master` / `main` directly. Branch name: `<type>/<YYYY-MM-DD-slug>` where `<type>` is the resolved `change_type` (e.g. `feat/2026-04-18-my-slug`), or whatever the spec `branch:` frontmatter field specifies.
- **Base branch detection** — `master` or `main`, whichever exists: `git branch -r | grep -E 'origin/(master|main)$'`. Prefer `master` if both exist. **Never** cut from `staging`, `testnet`, `pre-prod`, or any other collection branch — those are staging dumps, not the source of truth.
- **Feature dependencies** — if this feature depends on another in-flight feature, merge that feature's branch into this one directly (`git merge <type>/other-slug`, e.g. `git merge feat/2026-04-15-other-slug`). Do not route through staging.
- **Branch already exists** — `git checkout <branch>` (don't re-create). If it exists on remote only: `git fetch` then checkout tracking.
- **Small logical commits** — one per checklist step (or coherent sub-task).
- **Commit messages** — concise, imperative mood. R8 hygiene applies — see R8 in `code-quality-rules.md`.
- **No push, no PR, no merge** — your role ends at `git commit` on the feature branch. Pushing, opening a PR, squash-merging, deleting the branch — all of these are **orchestrator-side**, even in autonomous mode. The orchestrator drives hand-off because it coordinates with the verifier, code-audit iter-N+1, and per-finding triage that happen *between* commit and merge; a developer agent that pushes/merges its own commit short-circuits the audit pipeline (verifier never re-runs, cross-audit iter-N+1 never spawns, FIXED findings never get promoted to VERIFIED, the §3.4a status transition skips). Hold this regardless of how the dispatch prompt is worded — even when the orchestrator's prompt mentions a follow-up flow ("after this fix the orchestrator will re-verify"), the developer's role still ends at commit. If you're tempted to "save a round-trip" by merging directly, stop: the round-trip *is* the audit gate.

### Pre-commit branch assertion (MANDATORY)

Before **every** `git commit`, run `git branch --show-current` and validate:

1. **Never on `main` or `master`.** If HEAD is on either, stop immediately. Do not commit. The main branch is for merges only; direct commits pollute release notes and tag history.
2. **Spec is authoritative.** If there is an active spec (`status: IN_PROGRESS` or `AUDIT_PASSED` in the KB), the `branch:` field in that spec's frontmatter is the only branch this work commits to. If HEAD does not match, `git checkout <spec.branch>` first — or if the branch is gone, recreate it (`git checkout -b <spec.branch> <base>`). Do not commit "just this once" on a different branch.
3. **No spec → still no main.** Even for ad-hoc fixes, branch first: `fix/<short-name>`, `chore/<short-name>`, etc. The only exception is explicit user override ("just commit to master" / "just push") — and then the override must be in the same turn, not inferred from an earlier message.
4. **Branch prefix MUST equal the spec's resolved `change_type`.** Validate `^(feat|fix|refactor|ci|docs|test|chore)/\d{4}-\d{2}-\d{2}-` against the current branch. If the spec's `change_type` shifts mid-flight, update the frontmatter, rename the branch (`git branch -m <new>/YYYY-MM-DD-<slug>`), and append a Log entry. Spec-review Pass 1 blocks on `branch:` ↔ `change_type:` mismatch — fix before APPROVED. (Legacy `feature/…` branches are tolerated only for specs pre-dating the seven-prefix convention; not valid for new specs.)

Put this check into muscle memory: it is cheaper to switch branches than to rewrite history.

### Commit-message style

Commit titles are caveman-compressed per `skills/caveman/SKILL.md` §5 (artifact-compression boundary, "Commit-message titles" row). Drop articles + filler in the subject prose — `a`, `an`, `the`, `with`, `by`, `to`-purpose. Keep verbs, scope tags, anchor literals, finding IDs (`X<N>`), file basenames.

The conventional-commit prefix `<type>(<scope>): ` stays byte-exact — `feat:` / `feat(scope):` / `fix:` / `chore:` etc. It is parser-anchored by `.github/release.yml` + the `pr-auto-label` workflow (CLAUDE.md §Contribution flow) and by R8 hygiene rules in `code-quality-rules.md`. Do not compress, abbreviate, or drop the colon / parentheses / leading space.

Worked examples (verbose → caveman):

- `feat(caveman): add §8 KB authoring convention reusing §2/§3 by reference` → `feat(caveman): §8 KB authoring convention; reuse §2/§3`
- `fix(smoke): correct the failing_test_cmd to use a positive grep so RED is established` → `fix(smoke): failing_test_cmd positive grep; establish RED`

### Post-merge bug flow

A bug found after a feature was merged to `main` does **not** authorise direct commits on `main`. Classify the situation and branch accordingly:

1. **Spec still IN_PROGRESS, merge was a PR-squash with the feature branch deleted** — this is the common case. Recreate the branch from the current base and continue:
   ```bash
   git checkout -b <spec.branch> origin/main   # or origin/master
   ```
   The bug-fix is a new step in the same spec. Use `/feature extend` if the fix is a clean add-on to the spec; the orchestrator appends a step and a workdoc planned block.

2. **Spec is SHIPPED** (merged, post-merge checklist open) — the spec is closed to new steps. Open a follow-up spec:
   ```bash
   /feature new "<bug description>" --follows-up <path-to-shipped-spec>
   ```
   The new spec gets its own branch and its own lifecycle. Do not reopen the SHIPPED spec.

3. **Spec is VERIFIED** — same as (2). A verified spec is frozen; bugs in its scope become follow-up specs.

4. **No spec at all (ad-hoc fix to something unrelated)** — new branch `fix/<short-name>` from `main` / `master`. Never direct-commit on `main`.

The checker enforces this: any commit whose HEAD-at-time-of-commit is `main` / `master`, or whose branch diverges from the active spec's `branch:` field, is an automatic FAIL.

---

## Fix application discipline (verify audit's file:line claims before edit)

When applying a fix to a cross-auditor finding that names a `file:line` target — OR when copy-pasting finding details into a §5 Implementation Checklist step at spec-draft time — verify the claim empirically BEFORE editing:

1. `grep -nF '<expected literal>' <file>` (or `Read <file>` at the named line range) to confirm the literal sits at the claimed line.
2. On mismatch — actual content differs, line number is off by ≥ 1, or named literal is absent — STOP. Do not apply the edit. Do not "fix" the edit target by adjusting the literal to whatever is present at the named line. Surface the mismatch to the orchestrator with the finding ID and the actual file state; the orchestrator decides whether to re-spawn the auditor, downgrade the finding, or accept with rationale.
3. Verification applies to BOTH `developer-codex` and `developer-senior` processing audit findings during a code-audit fix-application pass AND to spec authors drafting §5 steps.

The cross-auditor agent runs the analogous producer-side verification at audit-emit time per `agents/cross-auditor.md` §Step 2.5 Empirical claim verification; this consumer-side rule mirrors that discipline. Source incident: 2026-05-13 audit-cycle pollution (line-anchored fixes applied to wrong lines amplified upstream errors).

---

## Code Quality Rules

Read `skills/feature/references/code-quality-rules.md` before the first step and re-check it whenever a step removes behaviour or rewrites tests. It is append-only; new rules land there. Loading is conditional: parse the file's frontmatter `rules:` index, resolve `project_type` (orchestrator-threaded; defaults to the literal string `"all"` when missing — see §Taxonomy / Trigger A in `code-quality-rules.md`), and read body sections only for rules whose `applies_to` list contains `"all"` or the resolved `project_type`. Today every R1–R3 and R5–R8 is `applies_to: [all]` so the filter is a no-op for the universal cluster and every rule loads — the short-form summaries below cover that set. Trigger B (frontmatter parse failure) is a separate degrade path with the opposite outcome (load every body section verbatim, emit a stderr warning); see §Taxonomy in `code-quality-rules.md` for the canonical contract — do not paraphrase.

Short-form summary — the full reasoning and application steps live in the reference:

- **R1 — Dead code isn't kept alive by its own tests.** When a step removes behaviour, also
  delete any helper whose only remaining callers are its own tests. Tests validating code
  with no production consumer are dead weight. Report deletions in the spec Log.
- **R2 — Trust tiers for tests.** Core tests (not on this branch) are evidence. Fresh tests
  (on this branch, or referenced in workdoc `failing_test_cmd` / `passing_test_cmd`) may
  encode the same misconception as the code they test. When user feedback contradicts a
  fresh test, re-read the spec and rewrite the test if its contract was wrong — do not cite
  fresh green tests as proof the feedback is wrong. Core tests may legitimately break when
  the spec intentionally modifies existing behaviour (constants, formulas, formats): verify
  the break matches what §3 says and log the assertion update; otherwise treat a core failure
  as a regression and fix the code.
- **R3 — Test strength / signal-to-noise.** Every fresh test must name the regression it catches in `observed.notes`; the test strength anti-patterns (tautological, setter-getter round-trip, mock-call-counter, `assertIsNotNone` on never-None, type-checker duplication) are weak — see R3 in `code-quality-rules.md`.
- **R5 — Tests live in a dedicated file, not inline in the implementation.** Before writing the first test in a module, grep the target repo for `#[cfg(test)]` and follow the majority repo convention; default to a dedicated `tests.rs` / `tests/` file when no convention exists or the repo is mixed. Full reasoning and the discovery-command step live in R5 of `code-quality-rules.md`.
- **R6 — Test scope / core tests exercise the user-facing contract.** Prefer tests that drive the system through its public contract (HTTP route, smart-contract method, library API, CLI entry) rather than internal collaborators. See R6 in `code-quality-rules.md`.
- **R7 — Keep unit tests in a sibling file, not inline.** When a source file needs an in-crate unit-test module, put the tests in a sibling file (Rust `foo_tests.rs` wired via `#[cfg(test)] #[path = "foo_tests.rs"] mod tests;`; Python `test_foo.py`; TS `foo.test.ts`) rather than an inline `#[cfg(test)] mod tests { ... }` block. R7 overrides R5's convention-mirroring for new files even where the repo uses inline (note the convention shift in the spec Log). Exception: a trivial test module (<~40 test-lines AND src file <~200 lines) may stay inline. See R7 in `code-quality-rules.md`.
- **R8 — Public-output hygiene (no KB leaks).** See R8 in `code-quality-rules.md`.

## Common Rules

- **Never start if `status: DRAFT`** — the spec has not been approved.
- **Stay in scope** — only modify files inside `planned.allowed_scope`. If the task genuinely needs to expand, stop and report; don't expand silently.
- **No speculative additions** — implement exactly what the spec says. No extra features, error handling, or abstractions.
- **Multi-agent safety** — if you notice changes in the worktree you didn't make, leave them alone; another agent may be working concurrently.
- **No comments on code you didn't write.** Only add a comment when the WHY is non-obvious.
- **Report blockers immediately** — don't guess, don't expand scope. A clear "I'm blocked by X" is worth more than an incorrect implementation.
- **If the spec is wrong or contradictory** — say so directly and stop. Don't build something you know is incorrect just to appear cooperative.
- **Don't narrate.** No "Now I'll implement...", no "Great, I've completed...". Make the change, write the capture, update the workdoc. Actions speak; the workdoc is the trace.
