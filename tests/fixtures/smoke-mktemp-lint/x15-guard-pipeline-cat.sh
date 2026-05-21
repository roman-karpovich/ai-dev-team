# X15 negative fixture (iter-6) — pipeline-position `return` in the `||`
# branch. Bash runs the pipeline's last stage in a subshell (and even with
# `pipefail` / lastpipe, the `return` here doesn't propagate to the
# caller's function — the function continues with d="" past the failed
# mktemp). MUST FAIL the lint: the abort branch must be a simple command
# with no pipeline (`|`) / background (`&`) continuation.
d=$(mktemp -d) || return 1 | cat
rm -rf "$(dirname "$d")"
