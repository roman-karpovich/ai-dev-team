# X14 negative fixture (iter-6) — appended-segment shape with a REAL
# `|| return` guard. STILL FAILS the lint per the structural defense:
# a real guard does not rescue the destructive shape, because the bug is
# the appended segment itself — a later `rm -rf "$(dirname "$d_co")"` on
# the assignment LHS resolves wrong regardless of whether the assignment
# itself was guarded (the guard only protects the assignment, not the
# downstream consumer of the now-poisoned LHS value). MUST FAIL the lint
# with appended-segment.
d_co=$(env mktemp -d)/co || return 1
rm -rf "$(dirname "$d_co")"
