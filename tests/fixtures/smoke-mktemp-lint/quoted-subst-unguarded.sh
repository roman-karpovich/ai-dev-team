# X9 negative fixture — quoted command substitution `VAR="$(mktemp ...)"`.
# The original weak `assign` regex hard-required `=$(`, so this standard
# bash idiom was invisible. The strengthened lint MUST flag it as unguarded.
d_tmp="$(mktemp -d)"
rm -rf "$(dirname "$d_tmp")"
