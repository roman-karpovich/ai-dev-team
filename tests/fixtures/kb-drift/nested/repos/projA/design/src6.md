# N6 nested-escape source

A `../`-escaping §-pointer. From `nested/repos/projA/design/` exactly four `../`
land on `tests/fixtures/kb-drift/`, so the target resolves to the REAL committed
file `escape-target/Note.md` OUTSIDE the scanned `nested/` root (but inside the
repo). Mirrors how `drift/escaping-refs.md` escapes into the sibling
`../clean/Note.md`. A real out-of-vault target → C2 "escapes vault containment".

see `../../../../escape-target/Note.md` §H
