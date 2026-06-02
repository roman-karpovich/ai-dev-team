# Case Target

A note at `x/a/CaseTarget.md`. The CLEAN case witness `[[a/casetarget.md]]`
resolves here: normalization lowercases every component and strips a trailing
`.md`, so `("a","casetarget")` is a tuple-suffix of `("x","a","casetarget")`
regardless of the on-disk filename case.
