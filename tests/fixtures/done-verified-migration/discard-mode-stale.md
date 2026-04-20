## Discard mode

`/feature discard` aborts an in-flight feature and deletes its branch.

1. Resolve the target spec.
2. Show the commit list and branch name.
3. Refuse if `status: DONE` — already merged, not something discard can undo. Tell the user to revert the merge commit instead.
4. Refuse if `status: DISCARDED` — already gone.

## Next section stub
