# X16 negative fixture (iter-6) — `# || return` inside a shell comment is
# NOT a real guard. The lint's segment tokenizer must strip `#`-introduced
# comments before scanning for `||` guards, or the literal text inside the
# comment falsely satisfies the abort-keyword check. MUST FAIL the lint
# with `unguarded`.
d=$(mktemp -d) # || return
rm -rf "$(dirname "$d")"
