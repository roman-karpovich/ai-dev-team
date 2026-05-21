# X12 negative fixture — guard regex word-substring bypass class 1c.
# `|| echo failed; rm -rf "$VAR"; return 1` — the `return 1` is a separate
# top-level statement (`;`-separated) that runs AFTER the non-aborting
# `echo failed` and `rm -rf` in the `||` branch. The X9 substring match
# accepted this because the literal `return` appears somewhere after `||`,
# but the branch is NOT aborting at position 0. The strengthened lint MUST
# reject: the `||` branch's first statement must itself be an abort, or
# the branch must be a brace group `{ ...; return; }` whose FINAL
# statement is `return`/`exit`.
d_tmp=$(mktemp -d) || echo failed; rm -rf "$d_tmp"; return 1
