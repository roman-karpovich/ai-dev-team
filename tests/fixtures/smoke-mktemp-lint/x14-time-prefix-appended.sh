# X14 negative fixture (iter-6) — `time` prefix + appended segment.
# `d_co=$(time mktemp -d)/co`. MUST FAIL the lint with appended-segment.
d_co=$(time mktemp -d)/co
rm -rf "$(dirname "$d_co")"
