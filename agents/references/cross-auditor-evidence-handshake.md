# Cross-auditor: Audit evidence handshake

Canonical content for the §Audit evidence handshake section of `agents/cross-auditor.md`. Covers the two-channel `evidence_class:` + `evidence_blockers:` transmission contract (file-backed for code/full mode; inline three-line footer for spec mode), the binary emit allowlist, the YAML-safety serialization rule for blocker strings, the spec-mode return contract with sentinel marker + EOF-adjacent parser shape, and the §Sentinel-obfuscation rule (self-anchoring carve-out for cross-audits of this agent file).

## Audit evidence handshake (`evidence_class:` + `evidence_blockers:`)

Per spec `2026-04-27-audit-evidence-enum.md`. The cross-auditor transmits TWO sibling fields back to the orchestrator on every audit, in two channels (file-backed for code/full mode; inline footer for spec mode). The orchestrator copies these into the spec frontmatter at the audit-terminal site.

### When to set

The cross-auditor itself only ever emits one of two values for `evidence_class:` (binary on whether Codex's audit was usable):

- **`dual_model`** — Codex returned successfully AND Claude reviewed (the gold standard). Then `evidence_blockers: []` (empty list).
- **`single_model`** — the fail-open Codex-FAILED prepend banner fired (Claude-only). Extract the failure reason from the existing `⚠️ WARNING: Codex audit unavailable (<error reason>)` banner and emit `evidence_blockers: ['codex audit unavailable: <reason>']` — single-quoted YAML scalar form.

The cross-auditor NEVER writes `self_fallback`, `contract_violated`, or `skipped` — those values are exclusively orchestrator territory (set when the cross-auditor itself could not complete, violated its output contract, or was bypassed).

### YAML-safety serialization rule for blocker strings

Reason text extracted from Codex stderr can contain apostrophes, newlines, or other YAML-hostile characters. Before emitting `evidence_blockers:`, the cross-auditor MUST normalize each blocker string:

1. **Replace newlines** (`\n`, `\r`, `\r\n`) with a single space.
2. **Truncate to 199** characters (leaving 1 char headroom for the `…` ellipsis suffix). Append `…` if truncation occurred → resulting string ≤ 200 chars on the human-meaningful prefix.
3. **Escape single quotes** by doubling (`'` → `''`) — required for YAML single-quoted scalar style. The string MAY now exceed 200 chars after escaping (each `'` becomes 2 chars); this is acceptable because YAML single-quoted scalar style handles arbitrary length, and the truncation in step 2 already operates on the human-meaningful prefix BEFORE escapes are added, so `''` pairs are atomic (added as units, never split mid-escape).
4. **Emit in single-quoted YAML form** (`'sanitized text'`) inside the list literal: `evidence_blockers: ['codex audit unavailable: <sanitized-reason>']`.

This sanitize-blocker rule applies to every newline→space conversion site, every escape-single-quote site, and every truncate-to-199 site in this agent's blocker emission path.

### Spec-mode return contract (inline output)

For `mode: spec`, the cross-auditor does NOT write findings.md to disk; the consolidated findings are returned as inline output text to the calling feature skill. To preserve the orchestrator-readable handshake in this mode, the inline-return text MUST end with EXACTLY THREE physical lines, in this order, AT END-OF-RESPONSE (no trailing characters, no trailing prose, no trailing blank lines beyond the final line's `\n`):

```
# CROSS-AUDIT EVIDENCE FOOTER
evidence_class: <value>
evidence_blockers: <YAML-list>
```

The first of these three lines is the EVIDENCE FOOTER sentinel marker (the obfuscated form `CROSS-AUDIT-EVIDENCE-FOOTER` with hyphens substituted for the spaces — the canonical spaced literal lives ONLY in the fenced documentation block above, reserved for the actual three-line footer block at end-of-response). The sentinel is byte-exact and serves two roles: (a) it gives the orchestrator's parser an unambiguous lock to the actual footer (prevents example-echo lifting); (b) it visually demarcates the footer for human readers reviewing the audit response.

Examples illustrating the `evidence_class` and `evidence_blockers` value shapes (the cross-audit evidence footer comment line is omitted from these illustrations per the sentinel-obfuscation rule below — the canonical spaced literal lives ONLY in the fenced template above; the obfuscated form `CROSS-AUDIT-EVIDENCE-FOOTER` would precede each example pair when the agent actually emits the footer):

dual_model success — `evidence_class: dual_model` paired with `evidence_blockers: []` (empty list).

single_model fail-open — `evidence_class: single_model` paired with `evidence_blockers: ['codex audit unavailable: connection refused']`.

**Sentinel-obfuscation rule (self-anchoring carve-out)**: agents auditing `agents/cross-auditor.md` itself (cross-audits where this file appears in the diff scope OR is loaded as a focus area) MUST NOT reproduce the canonical spaced sentinel literal mid-prose. The canonical spaced literal is RESERVED for the actual three-line footer block at end-of-response (the fenced documentation example block above is the single producer-side authoritative documentation site for the canonical form). When the agent needs to quote, discuss, or reference the sentinel mid-prose, it MUST use one of these obfuscated forms: (i) the description `the EVIDENCE FOOTER sentinel marker`, (ii) the hyphenated literal `CROSS-AUDIT-EVIDENCE-FOOTER` (substituting hyphens for the spaces in the canonical form), (iii) the prose `the cross-audit evidence footer comment line`. This rule prevents the consumer-side EOF-adjacency parser (SKILL.md §spec-mode parser) from being fooled by mid-prose echoes when the cross-auditor reads its own source as part of an audit. The defense-in-depth rationale: keep the canonical form to the single fenced documentation site, route all other references through the obfuscated forms, eliminate ambiguity at the source.

The orchestrator parses by FIRST normalizing the captured return text to strip ALL trailing newlines (a transport-layer artifact — bash `$(cmd)` substitution strips them coincidentally, but file reads / `read -d ''` / MCP byte-exact transport preserve them and would shift the `tail -3` window off the real footer), THEN reading the LAST THREE physical lines via `tail -3` and asserting byte-exact full-line equality on the first-of-three against the canonical spaced sentinel literal (full-line equality, NOT substring), prefix-check on the second-of-three (`evidence_class: `), prefix-check on the third-of-three (`evidence_blockers: `). If the first-of-three byte-exact full-line equality check fails OR either prefix check fails, the orchestrator MUST treat the audit as `contract_violated` (cross-auditor return signal not parseable) and record the parse failure as a blocker — see SKILL.md §3.5b Contract-violation rule for the orchestrator-side read path. EOF-adjacency on `tail -3` closes two failure modes the prior shape missed: (a) **forgotten-footer-with-example-echo** — the agent omits the real footer but echoes documentation examples (such as the fenced example earlier in this section) in its prose; the byte-exact full-line equality check on the first-of-three at EOF-adjacent position fails when only mid-prose echoes exist and no real footer block lives at end-of-response; (b) **trailing-prose-after-real-footer** — the agent emits the real footer then appends a sentence (apology, summary); the trailing prose pushes the sentinel away from the EOF-adjacent slot, the first-of-three full-line equality check fails. Both modes route to `contract_violated` with blocker `'sentinel not at expected EOF-adjacent position'`. Adjacency-and-EOF enforcement on `tail -3` with byte-exact first-line full-line equality is the load-bearing property both modes require.
