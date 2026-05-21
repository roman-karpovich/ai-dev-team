# X12 negative fixture — multi-assignment per line, first unguarded.
# `local foo=$(mktemp -d); local bar=$(mktemp -d) || return 1` — the line
# has TWO assignments from mktemp and only ONE guard. The X9 lint did a
# line-level decision (`assign.search(line) and guard.search(line)`),
# which sees "some assign + some guard" on this line and passes. But the
# first call's `$foo` is empty on mktemp failure — the destructive shape.
# The strengthened lint MUST be assignment-aware: split the line on
# top-level `;` and re-apply assign/guard per segment.
local foo=$(mktemp -d); local bar=$(mktemp -d) || return 1
rm -rf "$foo" "$bar"
