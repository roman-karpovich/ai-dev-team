# X9 negative fixture — the `|| :` no-op is the same failure-swallowing
# non-guard as `|| true`. A real guard's `||` branch must contain `return`
# or `exit` and actually abort.
d_tmp=$(mktemp -d) || :
rm -rf "$d_tmp"
