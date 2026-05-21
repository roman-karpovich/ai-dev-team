# X15 negative fixture (iter-6) — background-job position with a trailing
# `; return 2` to mask the bug as "guarded". The `&` puts the `return 1`
# in the background; the synchronous `return 2` is a separate top-level
# statement (after `;`) that fires only after the `echo done` runs, which
# means the function continues past the failed mktemp before terminating.
# MUST FAIL the lint: an `&` between the abort keyword and the end of the
# branch defeats the abort regardless of any later sequential return.
d=$(mktemp -d) || return 1 & echo done; return 2
rm -rf "$(dirname "$d")"
