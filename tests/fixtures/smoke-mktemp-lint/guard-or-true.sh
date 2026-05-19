# X9 negative fixture — a failure-swallowing `|| true` is NOT a real guard.
# The weak `guard` regex accepted any `||`; `|| true` swallows the mktemp
# failure and execution proceeds with VAR empty — the poisoned-path footgun.
d_tmp=$(mktemp -d) || true
rm -rf "$d_tmp"
