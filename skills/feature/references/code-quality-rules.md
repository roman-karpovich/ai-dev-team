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
