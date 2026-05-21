# X12 negative fixture — guard regex word-substring bypass class 1b.
# Same class as guard-word-substring-echo, but the `return` token lives
# inside a quoted string literal in an echo argument. The X9 substring
# match accepted it; the strengthened lint MUST reject — the `||` branch
# is an `echo`, not an aborting statement.
d_tmp=$(mktemp -d) || echo "see return"
rm -rf "$d_tmp"
