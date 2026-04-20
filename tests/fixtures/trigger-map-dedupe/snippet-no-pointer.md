# CLAUDE.md Snippet — AI Dev Team (fixture without pointer)

## How to add

Paste the section between the `---` markers into your project's `CLAUDE.md`.

```markdown
## Development Workflow

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
| "blocker N done" | `/feature checklist <done\|start-soak> <spec> <n>` |
```

<!--
Deliberately omitting the source-of-truth pointer sentence.
Exercises check_claude_md_snippet_points_to_hook rejection path.
-->
