# X14 positive control (iter-6) — `env` prefix WITH a real `|| return`
# guard and NO appended segment. MUST PASS the lint: the prefix is
# admitted to the assignment recognizer (so the site is examined), and
# the same-line `|| return 1` guard is a real abort, so the assignment is
# correctly guarded.
d=$(env mktemp -d) || return 1
rm -rf "$d"
