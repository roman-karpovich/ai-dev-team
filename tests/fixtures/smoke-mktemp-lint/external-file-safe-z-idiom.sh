# X13 positive control (z_postcheck dialect) — the multi-line
# `[ -z "$VAR" ]` post-assignment guard idiom used by tests/smoke.sh.
# Under the `z_postcheck` per-file dialect the lint MUST accept this as a
# real guard: the variable is checked immediately after the assignment and
# the failure path aborts. The variable name in the `[ -z ]` test matches
# the assignment LHS — the lint MUST verify this match so an unrelated
# `[ -z ]` line for a different variable does not falsely satisfy the
# guard.
tmpdir=$(mktemp -d 2>/dev/null || mktemp -d -t 'ae_recognize')
if [ -z "$tmpdir" ] || [ ! -d "$tmpdir" ]; then
  echo "could not create temp dir"
  return 1
fi
rm -rf "$tmpdir"
