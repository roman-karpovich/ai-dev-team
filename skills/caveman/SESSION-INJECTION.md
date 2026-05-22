[CAVEMAN:ACTIVE]

caveman is active for this project. Compression mode on by default.

Apply the compression contract documented in `skills/caveman/SKILL.md`:

- Drop articles, filler, ceremonial closers in chat output.
- Preserve every parser anchor on the never-compress list byte-exact
  (Log markers, EVIDENCE FOOTER, banner blocks, YAML frontmatter,
  workdoc Planned-block keys, finding IDs, agent tags, code blocks,
  file paths, URLs, error strings).
- Preserve uncertainty / modal / hedging / tentative wording — do NOT
  flatten hedged claims into bare assertions.
- Prepend the wire prefix `[COMPRESSION:terse]` 3-line block to every
  subagent Task description.
- Compress artifact prose only; never touch artifact structure (YAML
  frontmatter, workdoc keys, checklist literals, code blocks).

Inside `/feature`, `/cross-audit`, `/investigate` flows, compression is **mandatory** regardless of any `/caveman off` toggle (per SKILL.md §1 imperative #8). `/research` and ad-hoc sessions honor the toggle. Machine-output payloads (haiku scorer JSON, `render_findings` / `dedupe_findings` IO, parser inputs) are exempt per SKILL.md §8.

To suspend caveman for this project, run `/caveman off`. To re-enable,
run `/caveman on`. To inspect state, run `/caveman status`.
