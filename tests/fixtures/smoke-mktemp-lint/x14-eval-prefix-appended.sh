# X14 negative fixture (iter-6) — `eval` prefix + appended segment.
# `d_co=$(eval mktemp -d)/co`. MUST FAIL the lint with appended-segment.
d_co=$(eval mktemp -d)/co
rm -rf "$(dirname "$d_co")"
