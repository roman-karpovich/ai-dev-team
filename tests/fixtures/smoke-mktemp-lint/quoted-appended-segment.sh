# X9 negative fixture — the exact X7 destructive shape rewritten with a
# closing quote between `)` and `/`: `d_co="$(mktemp -d)"/co`. The weak
# `appended` regex required `/` immediately after `)` and missed this.
d_co="$(mktemp -d)"/co
rm -rf "$(dirname "$d_co")"
