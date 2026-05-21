# X14 negative fixture (iter-6) — `\mktemp` (alias-bypassing backslash)
# prefix + appended segment. `d_co=$(\mktemp -d)/co`. MUST FAIL the lint
# with appended-segment.
d_co=$(\mktemp -d)/co
rm -rf "$(dirname "$d_co")"
