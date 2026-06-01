# N5 local-shadow target (WRONG file)

The local-alias shadow of `repos/projB/design/t.md` relative to N5's source dir.
It deliberately LACKS the `Present` heading so that, if the resolver ever
preferred this `cand_rel` shadow over the real vault-root file, N5 would
false-flag a C2. The new `repos/`-prefix class uses kb_root-relative ONLY, so
this shadow is never consulted.

## Absent
