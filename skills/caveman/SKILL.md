---
name: caveman
description: Compression mode for ai-dev-team output. When active, the orchestrator drops articles, filler, hedging-as-decoration; preserves parser anchors and uncertainty semantics; prepends a wire prefix to subagent task descriptions; trims artifact prose without touching artifact structure.
argument-hint: "(skill is auto-activated by hooks/session-start when the project flag is absent; toggle via /caveman on|off|status)"
---

# Caveman: terse output across chat, wire, and artifacts

This skill is on-by-default for any project that does not have the suspend
flag set. To suspend for a project, run `/caveman off`. To re-enable, run
`/caveman on`. Status reported by `/caveman status`. Flag-path resolver and
hash live in `hooks/lib/caveman_paths.sh`; session-start injects this skill
into the orchestrator's context when the flag is absent for the current
project.

## 1. Compression contract (imperative)

When active, the orchestrator MUST:

1. Drop articles (`a`, `an`, `the`), copulas where unambiguous, filler
   phrases (`I think`, `let me`, `we will then`, `now`), narrative scene-
   setting, and ceremonial closers (`hope that helps`, `let me know`).
2. Keep clauses short. Prefer `verb noun` over `the verb of the noun`.
3. Use bullets / tables over prose paragraphs whenever the content is
   enumerable.
4. Preserve EVERY parser anchor listed in §2 byte-exact.
5. Preserve EVERY uncertainty marker per §3 (do NOT collapse a hedged
   claim into a bare assertion).
6. Prepend the wire prefix per §4 to every subagent Task description.
7. Apply the artifact boundary per §5 (compress prose, not structure).
8. When the orchestrator is operating inside `/feature`, `/cross-audit`, or `/investigate` flows, compression is mandatory regardless of the per-project suspend flag. `/caveman off` applies to **ad-hoc** sessions only (sessions not inside a flow skill). /research is exempt — long-form research notes are read narratively, so compression remains project-default for `/research` (suspend flag is honored). **Nesting and sequential composition**: mandatory-in-flow compression applies for the duration of any flow-skill invocation regardless of nesting (e.g. `/feature` → `/cross-audit` → `/investigator` keeps compression active throughout). Exiting the outermost active flow returns the session to flag-honoring state. Running `/research` within an active `/feature` session re-applies the flag-honoring rule for the `/research` portion only (the parent flow's compression resumes when `/research` completes).

## 2. Never-compress list — parser anchors

The never-compress list below enumerates byte-literals that MUST survive
caveman compression unchanged.

These literals MUST appear byte-exact wherever they would have appeared
in verbose mode. Do NOT rewrite, abbreviate, or paraphrase them.

### 2.1 Log markers — the Continue-mode dispatch keys

The 6 canonical Log-marker templates emitted by the feature skill and parsed
by the Continue-mode dispatcher (each appears on a single physical line, no
wrapping):

```
- YYYY-MM-DD: spec_audit_iteration=N
- YYYY-MM-DD: code audit iteration=N; fixed_ids=[...]; accepted_ids=[...]
- YYYY-MM-DD: code audit decisions recorded; iteration=N; pending_fixed=[...]; pending_accepted=[...]; pending_deferred=[...]
- YYYY-MM-DD: code audit passed; iteration=N; verified=[...], accepted=[...], deferred=[...]; evidence=<value>; blockers=[...]
- YYYY-MM-DD: code audit: no auditable files in diff; skipping
- YYYY-MM-DD: (spec|code) audit iteration > 5 justified — <reason>
```

Each template MUST survive compression byte-exact. Placeholders are `N`
(decimal integer), `[...]` (bracketed list contents), `<value>` (free-form
token), and `<reason>` (free-form prose). Mandatory punctuation: segments
within a marker are separated by semicolons (`; `), with one exception —
the `verified=[...], accepted=[...], deferred=[...]` triple inside template
#4 uses comma separators between its three sub-fields, then a semicolon
before `evidence=`. The `; skipping` suffix on template #5 and the
`> 5 justified — ` separator on template #6 are also mandatory byte-exact.

### 2.2 Cross-audit evidence footer

The three-line EOF-adjacent footer:

```
# CROSS-AUDIT EVIDENCE FOOTER
evidence_class: dual_model|single_model
evidence_blockers: [...]
```

`# CROSS-AUDIT EVIDENCE FOOTER`, `evidence_class:`, and
`evidence_blockers:` are parsed by `hooks/lib/check_dispatch_response.py`
and MUST appear verbatim.

### 2.3 Banner blocks — exact glyph + whitespace

```
## ⏸ AWAITING YOUR INPUT
```

```
## ⏸ APPROVAL REQUIRED
```

Scope of a banner = from the H2 line down to the next H2 / horizontal rule
/ EOF. Output the entire banner block byte-exact, including the `⏸` glyph
and surrounding whitespace.

### 2.4 YAML frontmatter, finding IDs, agent tags

- YAML frontmatter blocks in spec.md / workdoc.md / findings.md.
- Finding IDs of shape `X<N>` (e.g. `X1`, `X11`).
- Agent tags `@codex` and `@senior`.

### 2.5 Workdoc Planned-block keys + checklist literal

The keys `allowed_scope:`, `failing_test_cmd:`, `expected_failure_pattern:`,
`expected_pass_pattern:`, `passing_test_cmd:` and the spec checklist literal
`- [ ] Step N:` are parsed by the developer-workflow + compliance-checker.
They MUST appear unchanged.

### 2.6 Other byte-preserved categories

Branches (`feat/...`, `fix/...`), commands (shell, `gh`, `git`, `bash`),
code blocks (fenced or indented), file paths, URLs, error strings, and
quoted user text. Compression of these is strictly forbidden.

## 3. Uncertainty-preservation invariant

Caveman compresses prose, NOT epistemic posture. Modal verbs (`may`,
`might`, `could`, `should`), hedging adverbs (`possibly`, `likely`,
`probably`, `apparently`), tentative qualifiers (`approximate`, `roughly`,
`around`), and explicit confidence markers (`uncertain`, `unclear`,
`unconfirmed`) MUST be retained.

A sentence like "this might fail under heavy load" is NOT compressed to
"this fails under heavy load". The uncertainty is the load-bearing
content; dropping it changes meaning. Goodhart-proof rule: if removing a
word flips a hedged claim into a flat assertion, the word stays.

## 4. Wire prefix — subagent communication

When the orchestrator spawns a subagent via the Task tool while caveman
is active, the Task description MUST begin with the 3-line block:

```
[COMPRESSION:terse]
Apply ai-dev-team caveman compression rules to your output.
See: skills/caveman/SKILL.md
```

The literal token `[COMPRESSION:terse]` is the wire-channel marker. The
subagent inherits the compression contract via this prefix even when
the parent spawn instructions in `skills/feature/SKILL.md` or
`skills/cross-audit/SKILL.md` do not mention compression. The wire-prefix
rule applies regardless of which spawn site dispatches the subagent.

## 5. Artifact compression boundary — prose vs structure

Caveman compresses artifact prose. Caveman does NOT touch artifact
structure. Specifically:

| Artifact element | Compress? |
|------------------|-----------|
| Free-prose paragraphs in §Context, §Design, §Log, §Notes | YES |
| Bullet-list narrative items | YES (drop articles, shorten clauses) |
| YAML frontmatter keys + values | NO — structure-preserved |
| Workdoc Planned-block keys (`allowed_scope:` etc.) | NO |
| Spec §5 Implementation Checklist line literals | NO |
| Code blocks, command lines, file paths, URLs | NO |
| Tables (headers + cells) | YES on cell prose, NO on column structure |
| Banner blocks | NO — byte-exact per §2.3 |
| Cross-audit EVIDENCE FOOTER | NO — byte-exact per §2.2 |

The rule of thumb: if a parser, smoke pin, or downstream skill grep-Fs the
content, treat it as structure and leave it alone. If a human reads it
narratively, compress the prose while preserving the YAML / markdown
frontmatter scaffolding and bullet-list shape.

## 6. Suspend toggle — `/caveman off`

If an ad-hoc session needs verbose output (e.g. user training, demo
recording), run `/caveman off` to write the flag file for the current
project. The next ad-hoc session in that project starts verbose. Re-enable
with `/caveman on`. Inspect state with `/caveman status`.

**Flow skills override the suspend flag.** When the orchestrator is
operating inside `/feature`, `/cross-audit`, or `/investigate` (per §1
imperative #8), compression is mandatory regardless of `/caveman off`. The
flag controls **ad-hoc-session** behavior only. `/research` honors the flag
(long-form notes are exempt from flow-mandatory).

The slash command sources `hooks/lib/caveman_paths.sh` and uses the
resolver function `caveman_flag_path` so the command + hook agree on the
same flag path.

## 7. Quick reference

- Anchors that NEVER compress: §2 list. If a literal appears in §2, keep it
  byte-exact.
- Uncertainty NEVER compresses out (§3). A hedged claim stays hedged.
- `[COMPRESSION:terse]` is the wire prefix prepended to every Task
  description spawned during an active session.
- Artifact compression touches prose only; structure (YAML frontmatter,
  workdoc keys, checklist literals, code blocks) is byte-preserved.
- Toggle off with `/caveman off`; on with `/caveman on`; inspect with
  `/caveman status`.
- Machine-output payloads (haiku scorer JSON, render_findings /
  dedupe_findings IO, parser inputs) are EXEMPT from compression — see §8.

## 8. Machine-output precedence — payloads exempt

Caveman compression applies to chat / wire / artifact prose only. Caveman
does **not** apply to **structured machine payloads** generated by or
consumed by ai-dev-team tooling. The following data flows are EXEMPT —
payloads stay raw, byte-exact, and structurally unchanged:

| Site | Direction | Reason |
|------|-----------|--------|
| `hooks/lib/render_findings.sh` stdin JSON | input to renderer | Field values (`description`, `fix`) are read by the renderer as opaque strings; compression would corrupt them. |
| `hooks/lib/dedupe_findings.sh` stdin/stdout JSON | both directions | Dedupe fingerprint hashes the first-80-chars of `description`; compression alters fingerprint → silent dedup bypass. |
| `hooks/lib/check_dispatch_response.py` stdin | parser input | The parser validates `evidence_class:` / `evidence_blockers:` literal byte-shape. Compression of the cross-auditor return upstream would break the parser. |
| `haiku-finding-scorer` Task-prompt JSON | invocation input | Scorer reads field values verbatim per `agents/haiku-finding-scorer.md` rubric. |
| Cross-auditor `findings.md` body sections under canonical headings (`## Findings`, finding-ID blocks `### X1` etc.) | output | Structured by the §3.3 cross-audit-probes-foundation schema; downstream consumers grep-F these literals. |
| Any `printf '%s\n'` / `echo` output piped to a downstream parser within `hooks/` or `tests/` | output | Wire-protocol — receiver expects byte-exact format. |

Rule of thumb (same heuristic as §5 artifact compression but extended to
ad-hoc payloads): if a parser, smoke pin, dedup fingerprint, or downstream
tool grep-Fs the content, it is structured machine output — compression
rule does not apply.

When in doubt, the orchestrator MUST default to NOT compressing the
payload. The cost of an under-compressed JSON payload is zero (downstream
handles whitespace); the cost of corrupting a dedup fingerprint is silent
finding loss.
