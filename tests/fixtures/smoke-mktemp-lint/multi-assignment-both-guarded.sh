# X12 positive control — multi-assignment per line, both segments guarded.
# `local foo=$(mktemp -d) || return 1; local bar=$(mktemp -d) || return 1`
# — TWO assignments + TWO guards, each in its own `;`-segment. MUST PASS
# the strengthened assignment-aware lint.
local foo=$(mktemp -d) || return 1; local bar=$(mktemp -d) || return 1
rm -rf "$foo" "$bar"
