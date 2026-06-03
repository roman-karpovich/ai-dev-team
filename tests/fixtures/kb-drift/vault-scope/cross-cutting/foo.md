# Cross-cutting note (non-repos top-level dir)

This file lives in a NON-repos top-level dir (`cross-cutting/`). A no-project
scan that walked `repos/*` only never reached it. With the whole-vault scope it
is scanned, and the broken wikilink below flags a C1 (the target resolves to
zero vault notes).

[[no-such-cross-cutting-note]]
