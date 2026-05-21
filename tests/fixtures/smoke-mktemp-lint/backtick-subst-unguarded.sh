# X9 negative fixture — backtick command substitution `VAR=`mktemp ...``.
# Backtick substitution is legal bash and equally capable of producing a
# poisoned path; the weak regexes hard-coded `$(` and missed it entirely.
d_tmp=`mktemp -d`
rm -rf "$d_tmp"
