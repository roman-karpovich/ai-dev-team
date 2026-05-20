# X16 negative fixture (iter-6) — `# any text with || exit` inside a
# comment. MUST FAIL the lint with `unguarded`.
d=$(mktemp -d) # any text with || exit
rm -rf "$(dirname "$d")"
