# X14 negative fixture (iter-6) — `LC_ALL=C` env-var prefix + appended
# segment. `d_co=$(LC_ALL=C mktemp -d)/co`. MUST FAIL the lint with
# appended-segment.
d_co=$(LC_ALL=C mktemp -d)/co
rm -rf "$(dirname "$d_co")"
