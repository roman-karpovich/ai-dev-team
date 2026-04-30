# Smoke Pin Classification

This rubric supports BACKLOG #61. Smoke classification entries live in
`tests/smoke-proves-manifest.txt` and key off the helper function name, not the
display label passed to `check`.

Use the mechanical decision tree below when adding a new manifest entry. Apply
rules in order; first match wins.

## Decision Tree

1. If the helper invokes a function or script at smoke time and asserts on the
   runtime result, classify it as `behavioral`.
2. If the helper checks structured file shape, frontmatter, JSON, YAML, required
   keys, or enum-like field values, classify it as `schema`.
3. If the helper scans prompt, skill, agent, or doc prose for fixed literal
   strings, classify it as `prompt-text`.
4. If none of these rules match, classify conservatively as `behavioral` and add
   a short manifest comment explaining why the helper is unusual.

## Classes

`behavioral` pins execute code, hooks, scripts, helper functions, or fixtures and
verify the observed runtime behavior. Example verified in the current manifest:
`check_codex_audit_dispatch_helper_positive`.

`schema` pins validate structured data or required file shape. They usually check
frontmatter, JSON, YAML, fixed key-value patterns, or required sections. Example
verified in the current manifest: `validate_plugin_json`.

`prompt-text` pins hold exact prose steady. They usually use literal grep checks
against `skills/**`, `agents/**`, or `docs/**`. Example verified in the current
manifest: `check_skill_bodies_have_migrated_content`.
