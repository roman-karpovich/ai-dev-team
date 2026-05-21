# X12 negative fixture — guard regex word-substring bypass class 1.
# The X9 `guard` regex matched `\|\|.*\b(?:return|exit)\b` as a SUBSTRING
# anywhere after `||`. A non-aborting `|| echo return` satisfies the
# substring match but the `||` branch is just an `echo` whose argument is
# the WORD "return" — execution proceeds with VAR empty. The strengthened
# lint MUST flag this as unguarded (the abort statement must be at branch
# position 0, not embedded as a string token in an `echo`).
d_tmp=$(mktemp -d) || echo return
rm -rf "$d_tmp"
