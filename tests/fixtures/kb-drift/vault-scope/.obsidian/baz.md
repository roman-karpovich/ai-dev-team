# Baz (excluded dot-dir)

This note lives under `.obsidian/` — a dot-directory EXCLUDED from the scan set
via the `startswith('.')` component rule. Its broken wikilink WOULD flag a C1 if
scanned, but the exclusion skips it.

[[no-such-dotdir-target]]
