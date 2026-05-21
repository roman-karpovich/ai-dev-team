# X16 negative fixture (iter-6) — a developer comment `# TODO add ||
# return when fixed` after an unguarded mktemp. The `||` and `return`
# tokens live inside the `#` comment; bash never sees them. MUST FAIL
# the lint with `unguarded`.
d=$(mktemp -d) # TODO || return when fixed
rm -rf "$(dirname "$d")"
