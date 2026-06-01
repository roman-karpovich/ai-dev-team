# N5 repos-no-local-alias source

A `repos/`-prefixed pointer with a local shadow planted at
`repos/projA/design/repos/projB/design/t.md` (heading `Present` ABSENT) AND the
real `repos/projB/design/t.md` (heading `Present` PRESENT). The new resolver
heading-checks the REAL vault-root-relative file (Present → 0 C2), NOT the local
shadow. The old `cand_rel`-first resolver would have hit the shadow → false C2.

see `repos/projB/design/t.md` §Present
