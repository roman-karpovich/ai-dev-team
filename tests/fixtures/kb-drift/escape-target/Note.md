# N6 escape-target (real out-of-vault file)

This file lives OUTSIDE every scanned root (`clean/`, `drift/`, `nested/`) so it
never perturbs another fixture's aggregate scan. It exists solely as N6's real
out-of-vault target: N6's `` `../../../../escape-target/Note.md` §H `` pointer
escapes the scanned `nested/` vault and resolves to THIS committed file, which
`is_file()` confirms → C2 "escapes vault containment". The `§H` heading is
deliberately ABSENT (the escape is flagged regardless of heading match).

## Other
