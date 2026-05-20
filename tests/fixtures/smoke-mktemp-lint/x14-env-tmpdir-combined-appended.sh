# X14 negative fixture (iter-6) — combined `env TMPDIR=...` prefix +
# appended segment. `d_co=$(env TMPDIR=/tmp mktemp -d)/co`. MUST FAIL the
# lint with appended-segment.
d_co=$(env TMPDIR=/tmp mktemp -d)/co
rm -rf "$(dirname "$d_co")"
