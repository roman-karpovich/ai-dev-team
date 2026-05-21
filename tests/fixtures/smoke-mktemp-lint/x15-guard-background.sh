# X15 negative fixture (iter-6) — background-job position. `&` after a
# command runs it asynchronously; the function continues executing past
# the failed mktemp with d="". MUST FAIL the lint.
d=$(mktemp -d) || return 1 &
rm -rf "$(dirname "$d")"
