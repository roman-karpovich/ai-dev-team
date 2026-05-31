# Escaping References (out-of-vault traversal)

Regression lock for the path-containment class (X4/X5). When this fixture dir
is the scanned vault root, the references below `../`-escape it into the sibling
`clean/` fixture — which DOES contain a real `Note.md` with a real `Section One`
heading. Without a containment guard each would resolve to that out-of-vault
file and be silently treated as clean (false-clean). With containment they must
be REPORTED:

C1 — a `../`-escaping wikilink targeting a real out-of-vault note must NOT
resolve (broken wikilink, not silently clean): [[../clean/Note]]

C2 — a `../`-escaping section pointer whose target file AND heading both exist
out of vault must NOT resolve (dangling pointer, not silently clean):
`../clean/Note.md` §Section One
