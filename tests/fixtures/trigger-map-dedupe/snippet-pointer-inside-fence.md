# CLAUDE.md Snippet — AI Dev Team (audit-fixture for X2)

## How to add

Paste the section between the `---` markers into your project's `CLAUDE.md`.

---

~~~markdown
## Development Workflow

> **Trigger-map source of truth:** `hooks/session-start` (injected into every session at runtime). The table below is the portable paste-ready copy — kept current as of 2026-04-20; if it diverges from the hook, the hook wins at runtime.

### Skill trigger map

| User says... | Action |
|---|---|
| "add X", "implement Y" | `/feature new <description>` |
| "continue", "resume" | `/feature continue` |
| "what's in progress?" | `/feature status` |
| "review this", "audit src/" | `/cross-audit <scope>` |
| "compare these options" | `/investigate <question>` |
| "also need X" | `/feature extend <desc>` |
| "verify feature X" | `/feature verify <spec>` |
| "blocker N done" | `/feature checklist done <spec> <n>` |
~~~

<!--
Pointer is placed INSIDE the fenced paste block. Exercises the "must live
outside fence" assertion (X2) — pre-fix helper did whole-file grep and
accepted this variant, which would have leaked the pointer into every
downstream project's pasted CLAUDE.md.

Uses ~~~markdown fences instead of triple-backticks so this file can itself
be safely opened / parsed without the reader's renderer getting confused
about nested fences.
-->
