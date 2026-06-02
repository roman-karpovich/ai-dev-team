# Relative no-FP-lock witness (CLEAN)

A `../`-relative wikilink that resolves source-relatively (Option B): from
`docs/`, [[../docs/findings]] resolves to `docs/findings.md`. A strict `..`-reject
would false-positive this — it must stay clean (zero C1 on this source).
