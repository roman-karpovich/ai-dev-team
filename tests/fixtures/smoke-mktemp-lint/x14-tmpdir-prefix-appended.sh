# X14 negative fixture (iter-6) — inline `TMPDIR=...` env-var assignment
# prefix + appended segment. `d_co=$(TMPDIR=/tmp mktemp -d)/co` —
# structurally identical destructive class. MUST FAIL the lint with the
# appended-segment violation kind regardless of the prefix.
d_co=$(TMPDIR=/tmp mktemp -d)/co
rm -rf "$(dirname "$d_co")"
