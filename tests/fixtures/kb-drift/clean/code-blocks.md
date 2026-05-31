# Code Blocks (fenced) — no rendered wikilinks inside

Obsidian does not render `[[...]]` inside a fenced code block, so the bash
test expressions below are NOT C1 findings:

```bash
if [[ -n "$x" ]]; then echo set; fi
echo "$line" | grep -E "[[:space:]]+"
if [[ "$v" =~ ^[[:digit:]]+$ ]]; then :; fi
```
