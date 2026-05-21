# X12 negative fixture — `command mktemp` invocation, unguarded.
# The X9 substitution regex hard-coded `\$\(\s*mktemp\b`; `command mktemp`
# starts with `command`, so the assign-from-mktemp was invisible. The
# strengthened lint MUST recognize the `command`-prefixed form via the
# shared `_MKTEMP` pattern and flag this as unguarded.
d_tmp=$(command mktemp -d)
rm -rf "$d_tmp"
