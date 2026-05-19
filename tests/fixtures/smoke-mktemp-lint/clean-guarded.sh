# X9 positive control — correctly-guarded mktemp sites in all three legal
# substitution forms, each with a real `|| return` / `|| { ...; return; }`
# guard. The lint MUST NOT flag any of these.
d_one=$(mktemp -d) || return 1
d_two="$(mktemp -d)" || return 1
d_three=`mktemp -d` || { echo "mktemp failed"; return 1; }
d_four=$(mktemp -d) || { rm -rf "$d_one"; return 1; }
rm -rf "$d_one" "$d_two" "$d_three" "$d_four"
