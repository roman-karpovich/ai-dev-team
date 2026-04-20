# SKILL stub — stale pre-fix forms for negative-fixture testing

Verify passed. Moving to hand-off. Do **not** set `status: DONE` yet — wait until the user selects a preserving option (merge, push, or keep). Setting DONE before that means a discard would leave the spec permanently marked DONE with no surviving branch.

Works even when spec is in `IN_PROGRESS` — items can be anticipated during development. Refuses to add items to `VERIFIED` / `DISCARDED` specs.

5. Filter: by default, hide `VERIFIED` / `DONE`, `DISCARDED`, and `BLOCKED` (they are not actionable now).

3. **Spec is `VERIFIED` / `DONE`** — ask the banner below.

2. Refuse on `SHIPPED` / `VERIFIED` / `DONE` / `DISCARDED` — follow-up specs and post-merge action items are the right tools there.
