# X12 positive control — a brace-group guard whose FINAL statement is
# `return` (the multi-statement `|| { rm -rf ...; return 1; }` idiom used
# elsewhere in smoke-helpers.sh). MUST PASS the lint — this is a real
# aborting guard.
d_tmp=$(mktemp -d) || { rm -rf "$d_tmp"; return 1; }
rm -rf "$d_tmp"
