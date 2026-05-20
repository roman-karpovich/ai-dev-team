# X14 negative fixture (iter-6) — `env` command prefix + appended segment.
# `d_co=$(env mktemp -d)/co` — on mktemp failure d_co=/co; a later
# `rm -rf "$(dirname "$d_co")"` resolves to `rm -rf /`. The structural
# defense bans the appended-segment shape outright whenever the
# substitution body contains the bare `mktemp` token — regardless of any
# preceding command prefix (env / TMPDIR= / eval / time / `\mktemp` / etc).
# MUST FAIL the lint with the appended-segment violation kind.
d_co=$(env mktemp -d)/co
rm -rf "$(dirname "$d_co")"
