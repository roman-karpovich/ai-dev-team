---
type: index
---
# Link into templates (resolution-index invariant)

This SCANNED root note links to the excluded `templates/bar.md` note. Because
the wikilink resolution index (all_md) stays whole-vault (unfiltered), the link
below resolves to the template note and must NOT raise a spurious C1 — proving
the build-dir exclusion applies to the SCAN set only, never the resolution
index.

[[bar]]

The `type: index` frontmatter above makes this file C6-eligible. The deliberate
C6-bloat row below proves the linker IS in the scan set (it raises exactly 1
C6_index_row_bloat) while `[[bar]]` stays the file's ONLY wikilink, so the
C1-leak discrimination (0 C1 — the link into the excluded dir resolves clean)
is preserved.

| Page | Summary |
|------|---------|
| L | eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee |
