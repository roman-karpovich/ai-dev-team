# Smoke Pin Classification

This rubric supports BACKLOG #61. Smoke classification entries live in
`tests/smoke-proves-manifest.txt` and key off the helper function name, not the
display label passed to `check`.

Use the mechanical decision tree below when adding a new manifest entry. Apply
rules in order; first match wins.

## Decision Tree

1. Does the helper invoke a **plugin component** (script, hook, helper from
   `hooks/`, `skills/`, `agents/`) at smoke time and assert on its runtime
   output / exit code / side effects? → `behavioral`
   The component being tested is *the system under test*, not a generic file
   parser the test happens to use to inspect a file. Smell test: helper body
   invokes something from the plugin's own runtime surface (`bash hooks/<X>`,
   `python3 hooks/<X>`, sourced helper from `hooks/lib/<X>.sh`, etc.) and
   verifies its result.

2. Does the helper inspect file structure — fields present, values match an
   enum, YAML well-formed, JSON parses, frontmatter or registration grammar
   intact? → `schema`
   May use `python3` / `jq` / `awk` / `grep` as a file inspector — but the
   runtime being verified is the file's structural integrity, not a plugin
   component's behavior.

3. Does the helper scan for literal strings in skill/agent prose? → `prompt-text`
   Smell test: `grep -F` / `grep -qF` against fixed substrings in `skills/**`,
   `agents/**`, `docs/**`.

4. If none of the above match: classify conservatively as `behavioral` and add a
   1-line manifest comment explaining the unusual case.

## Classes

**`behavioral`** — pin invokes a plugin component (script, hook, helper from
`hooks/`, `skills/`, `agents/`) and asserts on its runtime output / exit code /
side effects. Example: `check_codex_audit_dispatch_helper_positive` invokes
`hooks/lib/codex_audit_dispatch.sh` and asserts on its exit code → **behavioral**
(plugin component invoked).

**`schema`** — pin reads structure of a file or frontmatter: fields present,
values match an enum, YAML well-formed, JSON parses. May use `python3` / `jq` /
`awk` / `grep` as a file inspector — the runtime verified is file structural
integrity, not plugin behavior. Example: `validate_plugin_json` runs `python3` to
parse `.claude-plugin/plugin.json` and check that required keys are present →
**schema** (file structure inspected; python is the inspector tool, not the SUT).

**`prompt-text`** — pin holds exact prose steady via literal-string scans.
Example: `check_skill_bodies_have_migrated_content` greps for a literal string in
`skills/**`, `agents/**`, `docs/**` → **prompt-text** (literal-string scan).
