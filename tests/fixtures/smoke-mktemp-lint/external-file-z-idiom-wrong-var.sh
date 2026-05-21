# X13 negative fixture (z_postcheck dialect) — the `[ -z ]` test guards a
# DIFFERENT variable than the one assigned from mktemp. Even with the
# z_postcheck dialect active, the lint MUST flag this as unguarded: a
# `[ -z "$bar" ]` test cannot guard a `foo=$(mktemp -d)` assignment, and
# the existence of an unrelated `[ -z ]` line a few lines down must not
# accidentally satisfy the guard check.
foo=$(mktemp -d)
if [ -z "$bar" ]; then
  return 1
fi
rm -rf "$foo"
