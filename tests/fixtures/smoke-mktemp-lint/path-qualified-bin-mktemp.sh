# X12 negative fixture — path-qualified `mktemp` invocation, appended segment.
# The X9 substitution regex hard-coded `\$\(\s*mktemp\b` at the start, so
# `$(/bin/mktemp -d)` was invisible — `/bin/mktemp` starts with `/bin`, not
# `mktemp`. The destructive shape `=$(/bin/mktemp -d)/co` collapses to the
# literal `/co` on mktemp failure exactly like the X7 shape. The
# strengthened lint MUST recognize path-prefixed mktemp via a shared
# `_MKTEMP` pattern and flag this appended-segment.
d_co=$(/bin/mktemp -d)/co
rm -rf "$(dirname "$d_co")"
