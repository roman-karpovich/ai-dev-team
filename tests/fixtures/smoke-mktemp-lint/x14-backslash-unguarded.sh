# X14 negative fixture (iter-6) — `\mktemp` (alias-bypassing backslash)
# prefix UNGUARDED. MUST FAIL the lint with `unguarded`.
d=$(\mktemp -d)
rm -rf "$d"
