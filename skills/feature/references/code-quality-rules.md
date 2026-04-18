# Code Quality Rules

Rules every developer agent (`developer-codex`, `developer-middle`, `developer-senior`) must
follow, and which `spec-compliance-checker` enforces. This file is append-only as new rules
land — keep existing rules stable so the compliance checker and developers stay in sync.

Each rule has three parts:

- **Rule** — one-line principle.
- **Why** — the failure mode the rule prevents. Drawn from real sessions.
- **How to apply** — concrete action during implementation.

User-input prompt presentation is governed by docs/user-input-banner-convention.md — violations block spec-review Pass 1.

---

## R1 — Dead code isn't kept alive by its own tests

**Rule**: when a step removes a feature, also remove any helper/utility whose only remaining
callers are its own tests. Delete the helper *and* those tests together.

**Why**: agents tend to preserve a utility because tests still reference it, then justify the
utility because tests pass. This creates a closed loop where code exists only to satisfy tests
that exist only to validate that code. The utility's production consumer is gone — both are
dead weight, and the passing tests create false confidence.

**How to apply**:

1. When a step removes or strips behaviour, list every symbol (function, class, constant) the
   removed code *called*.
2. For each such symbol, grep for callers outside `tests/`, `__tests__/`, `*_test.*`, etc. Count
   non-test callers.
3. If non-test callers == 0 and the symbol is not part of a documented public API
   (library export, API handler, CLI command), delete the symbol *and* every test that
   references it in the same commit.
4. If the symbol *is* part of a public API, leave it and note this in the step's spec Log
   entry ("kept X: part of public API").
5. Do not ask the user per-symbol — this is implementation cleanup. Report the deletions in
   the spec Log entry for the step.

---

## R2 — Trust tiers for tests

**Rule**: treat tests in two tiers when interpreting a test run.

- **Core tests** — tests not touched by the current spec's branch (established happy paths,
  pre-existing suites). A core test failing means the new code is wrong.
- **Fresh tests** — tests added or modified on the current feature branch, or any test
  referenced in workdoc `failing_test_cmd` / `passing_test_cmd`. These may encode the same
  misconception as the code they test.

**Why**: agents write a utility + tests, tests pass, agent treats green as proof of
correctness. When the user says "this is wrong", the agent looks at the fresh tests, decides
the logic must be right, and makes cosmetic changes that still miss the intent. The shitloop
locks in the wrong contract.

**How to apply**:

1. A fresh green test is evidence that code and test are mutually consistent — not that
   either matches intent. Intent lives in the spec (§1 Context, §3 Design, §6 Verification)
   and in the user's feedback, not in green CI.
2. When user feedback contradicts what a fresh test asserts, **do not** cite the fresh test
   as evidence against the feedback. Re-read the spec; if the test encodes the wrong
   contract, delete or rewrite the test alongside the code change. Never bend the fix to keep
   a fresh test green.
3. When a test run fails, classify failures by tier before diagnosing:
   - **Core failing** — two sub-cases, decide before changing anything:
     - *Spec modifies the behaviour this test asserts* (e.g. the spec explicitly changes a
       fee formula, a serialisation format, a return type). This is an **intended break** —
       core tests often compare against hardcoded constants and will fail legitimately. Verify
       the break is exactly the one the spec describes (same function, same operand, expected
       delta matches spec), update the constant/assertion, and log the update in the spec
       Log: `- YYYY-MM-DD: core test X updated — <before> → <after>, per spec §3.2`. Do not
       silently update a core test without a matching spec intent.
     - *Spec does not touch that behaviour* → production regression; fix the code, don't
       touch the test.
   - **Only fresh failing** → possibly the tests encoded the wrong contract; re-read intent
     before deciding whether to adjust code or tests.
4. Classify "fresh" by diff against the branch base:
   `git diff --name-only $(git merge-base HEAD main)..HEAD -- <test-globs>` (or `master`).
   Tests whose paths show up in that diff are fresh; everything else is core.
5. A core test that *was* modified on this branch is no longer pure core — once you update
   its assertion, it becomes fresh. Reviewers should scrutinise the update against the spec
   intent, not just the green capture.

---

## R3 — Test strength / signal-to-noise

**Rule**: every test must be capable of failing when the production behaviour it claims to
verify regresses. A test that cannot name a specific regression it would catch is weak —
rewrite the assertion or delete the test.

**Why**: Vladimir Khorikov's 4-pillar framework for unit tests (*Unit Testing: Principles,
Practices, and Patterns*, Manning 2020, chs. 1, 4, 5) evaluates a test on (1) protection
against regressions, (2) resistance to refactoring, (3) fast feedback, (4) maintainability.
The failure mode R3 targets is tests that *appear* to score high on pillar (1) — a green
line and a coverage percentage — while collapsing pillar (2): they break under any internal
rearrangement without catching real regressions. Weak tests create false confidence (the
agent reads green CI as "the contract holds") and pure maintenance drag (the test fails
during unrelated refactors, the team updates the assertion, and the next regression still
slips through). R3 forces the developer to name *what* the test catches, surfacing
tautological/shape-only assertions before they accumulate as green-CI ballast.

**How to apply**:

1. Before committing a new or modified test, write a one-sentence description of the
   regression it catches — a concrete behavioural change in production code that would make
   the assertion fail. Place it in `observed.notes` for the step.
2. If you cannot name the regression without restating the assertion itself, the test is
   weak. Rewrite the assertion to key off an observable behaviour, or delete the test.
3. Check the assertion against these anti-patterns — any one is a red flag:
   - **Tautological assertion** — the assertion restates the production code's own
     expression (e.g. `assert x == fn(x)` where `fn(x)` is `return x`, or asserting the
     object returned is the same object passed in). Violates pillar (1) because no
     production change this test is meant to guard can falsify it: the assertion and the
     code are the same statement.
   - **Setter-getter round-trip** — `obj.set_x(42); assert obj.get_x() == 42`. Violates
     pillar (2): the field name is the assertion, so any internal rename or field
     restructure breaks the test without a behavioural change; and violates pillar (1)
     because a real regression (e.g. the setter silently dropping a value on some branch)
     isn't exercised by the single trivial path.
   - **Mock-call-counter as sole assertion** — `assert mock.call_count == 1` with no
     assertion on the arguments or the observable effect. Violates pillar (2): the test
     breaks whenever the call site is refactored (inlined, memoised, batched), regardless
     of whether behaviour changed; pillar (1) protection is illusory because wrong arguments
     still satisfy the counter.
   - **`assertIsNotNone` (or `assert x is not None`) on a never-None return** — the
     function's type signature already guarantees non-None (no `Optional[...]`, no
     documented None path). Violates pillar (1): the assertion can only fail if the return
     type itself changes, which a type checker already flags; it catches no runtime
     regression.
   - **Duplicating type-checker or ORM-schema guarantees** — asserting a field exists on a
     dataclass, that a typed dict has the expected keys, or that an ORM row has the columns
     the schema defines. Violates pillars (1) and (4): type checkers, schema migrations,
     and CI lint catch these faster and more reliably; the test adds noise and breaks on
     harmless schema renames.
4. Every fresh test must have a one-sentence note in `observed.notes` naming the regression it catches; if you cannot name it, the test is weak — rewrite or delete.
   This is the behavioural trigger spec-compliance-checker keys off — an empty or vague
   note ("catches regression if the assertion breaks") does not satisfy R3.
5. Anti-pattern list is a floor, not a ceiling. When you spot a new weak-test shape in the
   wild, append it here with a one-line pillar-grounded rationale; do not mutate existing
   entries.

---

## R4 — Branch prefix matches change nature

**Rule**: the feature-branch prefix MUST equal the resolved `change_type` in the spec frontmatter. Concretely, branch name is `<change_type>/YYYY-MM-DD-<slug>` where `<change_type>` is one of the seven conventional prefixes (`feat / fix / refactor / ci / docs / test / chore`). Legacy `feature/…` is preserved only by the `stop-check` hook's eight-alternative regex for specs pre-dating this rule; it is NOT a valid value for new specs' `change_type`.

**Why**: the repo's PR-auto-label workflow keys off the PR title's Conventional Commits prefix and `.github/release.yml` drives release-note categorisation from those labels. When a pure bug-fix lives on a `feature/…` branch the title-label link still works, but the branch name undermines the category at a glance during review — mis-routing categorisation signals, confusing reviewers, and hurting release-note quality. A real case (soroban-amm, cited in BACKLOG #15) made this concrete: a `fix`-labelled commit on a `feature/…` branch produced correct release-note copy but wrong visual grouping in the PR list. R4 removes the drift at its source by binding the branch prefix to the same `change_type` scalar the spec review already validates.

**How to apply**:

1. During `/feature new`, let the orchestrator infer `change_type` from the description (keyword buckets documented in `skills/feature/SKILL.md` §New/Step 2; default `feat`) and confirm it via the `AWAITING YOUR INPUT` banner. The resolved value goes into spec frontmatter as `change_type:` and is substituted into `branch:` to produce the canonical `<change_type>/YYYY-MM-DD-<slug>` form (e.g. `branch: fix/2026-04-18-my-slug`).
2. Before every `git commit`, run `git branch --show-current` and validate the current branch name matches `^(feat|fix|refactor|ci|docs|test|chore)/\d{4}-\d{2}-\d{2}-`. If it matches `^feature/` instead, the spec was written under the old convention — stop and either update the spec's `change_type` field (new work) or leave the legacy `feature/` branch alone (in-flight spec pre-dating this rule).
3. When a spec's scope shifts mid-flight (e.g. what started as a `feat` becomes a pure `fix` after scoping), open the spec, update `change_type:` in frontmatter, rename the branch (`git branch -m <new-prefix>/YYYY-MM-DD-<slug>`), and append a Log entry: `- YYYY-MM-DD: change_type: <old> → <new> (scope change)`. Do NOT silently keep the old branch prefix.
4. Reviewers verify `change_type` and the branch name agree in spec-review Pass 1. A mismatch is a review block, not a warning — fix it before APPROVED.

---

## R5 — Tests live in a dedicated file, not inline in the implementation

**Rule**: tests must live in a separate file from the code they cover; mirror the repo's existing test layout, and default to a dedicated test file when no convention exists or the repo is mixed.

**Why**: inline `#[cfg(test)] mod tests { … }` blocks at the bottom of a production `.rs` file are standard Rust — the language itself condones them — but at the scale of a multi-contract Soroban workspace (or any crate that accumulates dozens of tests per module) they bloat the implementation file, dilute `git blame` for real production edits, and hurt review by mixing assertion noise with contract logic. The cited incident is concrete: `AquaToken/soroban-amm` feature `feature/2026-04-17-plane-l2-wordbitmap` shipped with inline tests and was then cleaned up by PR #159, which re-extracted the tests into a sibling file — a round-trip that should not have been needed. Agents writing new code tend to append tests next to the symbol they just wrote because it is physically closest; without an explicit rule they will keep doing so even in repos whose existing modules all use `tests.rs`. R5 makes the expectation explicit and pins the decision to the target repo's existing convention rather than any individual agent's preference. This is a project rule, not a Rust idiom — mirror the convention of the target repo before deciding where tests live.

**How to apply**:

1. Before writing the first test in a module, discover the repo's existing test layout. Run `grep -R "#[cfg(test)]" src/` (or the `rg` equivalent `rg -F '#[cfg(test)]' src/`) and classify each hit: is the `#[cfg(test)]` block inside the production `.rs` file it tests (inline), or inside a sibling `tests.rs` / `foo_tests.rs` / `tests/` module (dedicated)? The pattern with the majority of hits is the repo convention — follow it.
2. If the repo convention is dedicated test files (the common soroban-amm case), create or extend a sibling `tests.rs` (or the existing `tests/` module) and put the new tests there. Do not append a new `#[cfg(test)] mod tests { … }` block to the production file just because it is closer; that creates a mixed-layout repo which forces future agents to re-run step 1.
3. If the repo is mixed or has no clear majority, default to a dedicated test file. Create `tests.rs` next to the module under test (or extend an existing `tests/` directory) and wire it up with `#[cfg(test)] mod tests;` in the parent module. Note the decision in the spec Log so reviewers can see which convention the branch established.
4. If the repo convention is explicitly inline (every `#[cfg(test)]` hit lives inside the production file), follow it — R5 is mirror-the-convention, not dedicated-file-always. Consistency with the existing codebase beats aesthetic preference.
5. Reviewers verify the layout matches the convention they see elsewhere in the repo. A mismatch (inline tests in a dedicated-file repo, or vice versa) is a review block, not a warning — fix it before APPROVED.

---
