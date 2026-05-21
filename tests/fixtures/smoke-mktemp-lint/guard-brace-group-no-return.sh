# X12 negative fixture — a brace-group `||` branch with NO terminal abort.
# `|| { echo failed; }` — the brace group's final statement is an `echo`,
# not `return`/`exit`. Execution proceeds with VAR empty. The strengthened
# lint MUST flag this; the brace-group guard form is real only when the
# FINAL statement inside the braces is `return` or `exit`.
d_tmp=$(mktemp -d) || { echo failed; }
rm -rf "$d_tmp"
