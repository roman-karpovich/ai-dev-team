# X15 negative fixture (iter-6) — brace-group `{ return 1; }` in pipeline
# position. The brace group's terminal `return` is structurally a real
# abort, but bash runs the WHOLE pipeline tail in a subshell, so the
# return doesn't reach the caller. MUST FAIL the lint.
d=$(mktemp -d) || { return 1; } | cat
rm -rf "$(dirname "$d")"
