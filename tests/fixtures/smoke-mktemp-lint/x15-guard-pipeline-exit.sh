# X15 negative fixture (iter-6) — same as pipeline-cat but with `exit 1`.
# `exit` in a pipeline stage runs in a subshell and does NOT terminate the
# outer caller. MUST FAIL the lint.
d=$(mktemp -d) || exit 1 | cat
rm -rf "$(dirname "$d")"
