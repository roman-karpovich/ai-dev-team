# X16 positive control (iter-6) — a real same-line `|| return 1` guard
# followed by a trailing `#` comment. MUST PASS the lint: the guard is
# REAL (outside the comment); the comment is stripped before the
# tokenizer sees it but the `||` and `return` are NOT inside the comment.
d=$(mktemp -d) || return 1 # cleanup later
rm -rf "$d"
