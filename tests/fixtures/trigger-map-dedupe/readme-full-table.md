## Ambient workflow

After install, Claude knows when to use which skill automatically — no slash commands required:

| You say... | Claude does |
|---|---|
| "add retry logic", "implement X", "let's build Y" | `/feature new` |
| "continue", "where were we?", "resume..." | `/feature continue` |
| "review this", "audit src/", "check for bugs" | `/cross-audit` |
| "should we use X or Y?", "is this approach right?" | `/investigate` |

The full trigger map — see [`hooks/session-start`](hooks/session-start) (authoritative) and [`docs/claude-md-snippet.md`](docs/claude-md-snippet.md) (portable).

<!--
Fixture carries BOTH required links AND all 4 core commands AND a full table.
It trips specifically on the row-count assertion (X4 audit finding) — links
and commands alone would not exercise it.
-->

---

## How to use
