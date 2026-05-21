# X14 negative fixture (iter-6) — `env` prefix UNGUARDED (no appended
# segment, no `||` guard). Structurally identical to the X9 unguarded
# class but with a command prefix the iter-5 `_MKTEMP` pattern did not
# recognize. The extended `_MKTEMP` prefix vocabulary (env / TMPDIR= /
# LC_ALL= / eval / time / exec / builtin / command / \) admits this site
# to the assignment recognizer; the guard absence then triggers the
# unguarded violation. MUST FAIL the lint with the `unguarded` violation
# kind.
d=$(env mktemp -d)
rm -rf "$d"
