## AI Dev Team — Development Workflow (mutated fixture)

### Skill trigger map

Recognise these intents and invoke the matching skill automatically:

| User says... | Action |
|---|---|
| "add X", "implement Y" | `/feature new <description>` |
| "continue", "resume" | `/feature continue` |
| "what's in progress?" | `/feature status` |
| "review this", "audit src/" | `/cross-audit <scope>` |
| "compare these options" | `/investigate <question>` |
| "also need X" | `/feature extend <desc>` |
| "verify feature X" | `/feature verify <spec>` |

<!--
Deliberately omits the eighth row (post-merge checklist trigger).
Exercises check_session_start_trigger_map_complete rejection path.
-->
