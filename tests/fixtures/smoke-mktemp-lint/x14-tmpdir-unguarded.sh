# X14 negative fixture (iter-6) — inline `TMPDIR=...` env-var prefix
# UNGUARDED. MUST FAIL the lint with `unguarded`.
d=$(TMPDIR=/tmp mktemp -d)
rm -rf "$d"
