# Templates-analysis note (anti-over-exclusion — MUST be scanned)

This file lives under `templates-analysis/` — a CONTENT dir that embeds the
`templates` token but is NOT the build dir. The exclusion is whole-component
anchored (never substring), and `templates-analysis` has no leading digits and
a trailing `-analysis` suffix, so SCAN_EXCLUDE_RE.fullmatch rejects it. It MUST
be scanned: the broken wikilink below flags exactly 1 C1.

[[no-such-templates-analysis-target]]
