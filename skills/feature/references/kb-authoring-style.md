# KB Authoring Style — Caveman Convention

Default style for NEW KB docs (research notes, design specs, retros). Implements `skills/caveman/SKILL.md` §8 KB authoring convention.

## Scope

Applies to:

- New research notes authored under `<kb>/repos/<project>/research/`.
- New design specs authored under `<kb>/repos/<project>/design/`.
- New retros authored under `<kb>/repos/<project>/research/` (retrospective subtype).

Does NOT apply to:

- Existing KB corpus — no mass backfill. Rewrite case-by-case during related work only.
- Cross-audit findings (`<kb>/repos/<project>/security/<audit_slug>-findings.md`) — machine-generated; structured machine output per caveman §7.
- Execution workdocs YAML blocks, code blocks, frontmatter — structure-preserved per caveman §5.

Two contracts:

- Runtime contract — caveman §1-§7 — orchestrator chat / wire / artifact prose during active sessions.
- Authoring contract — caveman §8 + this doc — write-time discipline for NEW KB docs.

Convention rule: prose terse by default; preserve §2 anchors byte-exact; preserve §3 uncertainty markers; structure (frontmatter, headings, code blocks, tables) untouched.

## Worked examples

Three good/bad pairs. Same content. Prose-heavy form vs caveman-style form. Anchors + hedging preserved across both.

### Example 1 — retro paragraph

Bad (prose-heavy):

```markdown
On 2026-04-20 we ran into an issue where one of the legacy helper greps
was still being referenced by some operational tokens in the codebase
even though the file itself had been deleted. The cross-auditor agent
flagged this as a HIGH finding (X10) because the grep was using a
backslash-pipe under `-E` which, as it turns out, is a literal pipe
character under ERE rather than the alternation operator. This means
the regex probably never matched anything at all, so the check was
effectively a no-op. We should probably treat this as a class regression
and add an institutional-memory comment near the fix.
```

Good (caveman-style, same content):

```markdown
2026-04-20 — legacy helper grep still referenced by operational tokens
post file deletion. Cross-auditor flagged HIGH (X10): grep used
backslash-pipe under `-E` — literal pipe under ERE, not alternation.
Regex probably never matched; check effectively no-op. Should treat as
class regression; add institutional-memory comment near fix.
```

Anchors preserved: `X10`, `-E`, `ERE`, `2026-04-20`. Hedging preserved: `probably`, `should`, `effectively`.

### Example 2 — spec Design subsection

Bad (prose-heavy):

```markdown
The design here is to introduce a new helper function called
`check_kb_authoring_convention_wired` that will live in the
`tests/smoke-helpers.sh` file. This helper is going to verify that the
convention has been wired up correctly — specifically, that the §8
heading is present in `skills/caveman/SKILL.md`, that the new reference
file at `skills/feature/references/kb-authoring-style.md` exists and has
some non-trivial content, and that both wire-sites (`skills/research/SKILL.md`
and `skills/feature/SKILL.md`) cite the reference file in the correct
location. The helper might fail if any of those five assertions break,
which would catch wiring regressions cleanly.
```

Good (caveman-style, same content):

```markdown
Design: new helper `check_kb_authoring_convention_wired` in
`tests/smoke-helpers.sh`. Verifies convention wired:
§8 heading present in `skills/caveman/SKILL.md`;
`skills/feature/references/kb-authoring-style.md` exists + non-trivial;
both wire-sites (`skills/research/SKILL.md`, `skills/feature/SKILL.md`)
cite ref file at correct slot. Five assertions; helper might fail on
any — catches wiring regressions cleanly.
```

Anchors preserved: helper name, file paths, §8. Hedging preserved: `might`.

### Example 3 — research-note Notes entry

Bad (prose-heavy):

```markdown
We probably want to investigate whether the caveman compression rules
could possibly be applied at author-time to KB documents rather than only
at runtime when the orchestrator is dropping articles in chat. The
runtime form likely covers the @codex and @senior agent tags and the
workdoc keys, but the author-time form would need to apparently extend
to file paths and URLs as well, which may be uncertain.
```

Good (caveman-style, same content):

```markdown
Probably investigate: caveman rules could possibly apply at author-time
to KB docs, not only runtime (orchestrator drops articles in chat).
Runtime form likely covers @codex + @senior tags + workdoc keys;
author-time form would apparently need to extend to file paths + URLs —
may be uncertain.
```

Anchors preserved: `@codex`, `@senior`. Hedging preserved: `probably`, `possibly`, `likely`, `apparently`, `may`, `uncertain`.

## Pre-commit checklist

Before committing a new KB doc, run all four items. Skip none — every item closes a known failure mode.

### 1. Anchor counts preserved

Caveman §2 enumerates byte-literal anchors that MUST survive. Two checks:

Structured-anchor occurrence count (agent tags + R/X-rule IDs only — coverage scope narrow on purpose). Non-decreasing invariant against pre-edit baseline. Canonical command (per spec §3.6a — bare `|` under `-E`, NOT `\|`):

```bash
grep -Eo '@codex|@senior|R[0-9]+|X[0-9]+' "$file" | wc -l
```

Visual checklist (NOT covered by the regex above): review the diff for deleted or altered

- file paths (e.g. `skills/feature/SKILL.md`),
- URLs,
- error strings,
- workdoc keys (`allowed_scope:`, `failing_test_cmd:`, `expected_failure_pattern:`, `expected_pass_pattern:`, `passing_test_cmd:`),
- spec checklist literal (`- [ ] Step N:`),
- Log markers (the six templates in caveman §2.1),
- banner blocks (`## ⏸ AWAITING YOUR INPUT`, `## ⏸ APPROVAL REQUIRED`),
- cross-audit EVIDENCE FOOTER lines.

Anything matching a §2 anchor literal MUST survive byte-exact. File-path formats vary too widely for a single regex without false-positive noise; visual diff-scan is honest for these categories per spec §3.6a delegation.

### 2. Uncertainty markers non-decreasing

Caveman §3 invariant: hedging is load-bearing, NOT decoration. Non-decreasing count against pre-edit baseline. Canonical command (per spec §3.6a — bare `|` under `-E`, NOT `\|`; `\|` under ERE is a literal pipe character + the regex never matches):

```bash
grep -Eow 'may|might|could|should|possibly|likely|probably|apparently|approximate|roughly|around|uncertain|unclear|unconfirmed' "$file" | wc -l
```

`wc -l` counts OCCURRENCES — two markers on one line count as 2, not 1. A sentence like "this might fail under heavy load" MUST NOT compress to "this fails under heavy load" — the hedging is the load-bearing content.

### 3. Structure untouched

Caveman §5 boundary: prose compresses, structure does not. Verify these survive byte-exact:

- YAML frontmatter — every key + value byte-exact, no key reordering, no value rewording.
- Markdown headings — every `^#+ ` line byte-exact (level + text).
- Code blocks — every fenced or indented code block byte-exact (content + fence type + language tag).
- Table column structure — header row + alignment row + column count untouched; cell prose may compress.
- Bullet-list shape — `-` / `*` markers preserved; nesting depth preserved; only narrative inside the bullet compresses.

If a parser, smoke pin, or downstream skill grep-Fs the content, treat it as structure and leave it alone.

### 4. Readable without decompression

The compressed doc MUST stand on its own. A human or dev-agent reads it directly; there is no "decompression" pass that restores articles or filler. Quick read-aloud check: can you understand the meaning + intent + uncertainty posture in one pass without mentally inserting words? If not, the compression went too far — back off until the prose stands alone.

Signs of over-compression:

- Strings of nouns with no verb — meaning becomes ambiguous.
- Lost antecedent — pronouns or demonstratives without a clear referent.
- Flipped polarity — a hedged claim collapsed into a flat assertion (violates item 2).
- Dropped logical connective — `because`, `therefore`, `however` removed when they carried the argument.

When in doubt, restore the word. Compression is a discipline, not a target.
