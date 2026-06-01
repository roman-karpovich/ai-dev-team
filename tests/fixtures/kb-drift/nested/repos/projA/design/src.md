# N1 collide-present source

A deep vault spec referencing its own PLUGIN-REPO root doc with a bare basename.
The vault-root bait `CLAUDE.md` exists (different headings) but the new resolver
resolves SOURCE-relative (`repos/projA/design/CLAUDE.md`, absent) → skip → 0 C2.
The old `cand_root = nested/CLAUDE.md` would have heading-mismatch-flagged this.

see `CLAUDE.md` §X
