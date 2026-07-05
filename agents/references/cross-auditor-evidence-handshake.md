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

For `mode: spec` and `mode: decision`, the cross-auditor does NOT write findings.md to disk; the consolidated findings are returned as inline output text to the caller (the feature skill for spec mode, standalone `/cross-audit` for decision mode). To preserve the orchestrator-readable handshake in these modes, the inline-return text MUST end with EXACTLY THREE physical lines, in this order, AT END-OF-RESPONSE (no trailing characters, no trailing prose, no trailing blank lines beyond the final line's `\n`):

```
# CROSS-AUDIT EVIDENCE FOOTER
evidence_class: <value>
evidence_blockers: <YAML-list>
```

The first of these three lines is the EVIDENCE FOOTER sentinel marker (the obfuscated form `CROSS-AUDIT-EVIDENCE-FOOTER` with hyphens substituted for the spaces — the canonical spaced literal lives ONLY in the fenced documentation block above, reserved for the actual three-line footer block at end-of-response). The sentinel is byte-exact and serves two roles: (a) it gives the orchestrator's parser an unambiguous lock to the actual footer (prevents example-echo lifting); (b) it visually demarcates the footer for human readers reviewing the audit response.

Examples illustrating the `evidence_class` and `evidence_blockers` value shapes (the cross-audit evidence footer comment line is omitted from these illustrations per the sentinel-obfuscation rule below — the canonical spaced literal lives ONLY in the fenced template above; the obfuscated form `CROSS-AUDIT-EVIDENCE-FOOTER` would precede each example pair when the agent actually emits the footer):

dual_model success — `evidence_class: dual_model` paired with `evidence_blockers: []` (empty list).

single_model fail-open — `evidence_class: single_model` paired with `evidence_blockers: ['codex audit unavailable: connection refused']`.

### Model attestation contract (`claude_model`)

Per spec `2026-06-10-fable-cross-auditor-attestation.md`. On every audit the cross-auditor ALSO emits a third honesty field, `claude_model:`, recording the exact Claude model ID that actually ran the Claude half. This guards against silent Fable→Opus fallback at spawn (quota outage): the orchestrator-side classifier validates the attested ID against the expected prefix and routes any mismatch to an explicit gate, never a silent fold. `claude_model:` is a SIBLING of `evidence_class:` — it is NOT one of the three pinned footer lines in spec mode.

**Source of truth — your OWN system prompt, never docs/examples.** Read the exact model ID from the line in your system prompt that reads "The exact model ID is `<id>`". Emit that `<id>` verbatim. NEVER copy a model ID from documentation, fenced examples, or any value shown in this reference — those are illustrative, not your runtime identity. If you cannot determine your model ID from your system prompt, emit the literal `claude_model: unknown` (an honest degraded signal that routes to the gate) rather than guessing or copying.

Two channels, mirroring the evidence handshake:

- **code/full mode**: one canonical `claude_model: <exact-model-id>` key in the leading frontmatter of `<audit_slug>-findings.md`, sibling of `evidence_class:`. Overwritten each iteration with the current run's model.
- **spec and decision modes**: ONE physical line `claude_model: <exact-model-id>` emitted **immediately preceding** the EVIDENCE FOOTER sentinel marker line. The three-line footer below the sentinel stays EXACTLY THREE physical lines — the pinned footer contract is untouched. Placing the attestation line immediately preceding the sentinel gives the consumer-side parser an unambiguous anchor (it reads the single line above the sentinel) and kills example-echo lifting, the same rationale as the EOF-adjacency anchor on the footer itself. In prose, the obfuscated sentinel form `CROSS-AUDIT-EVIDENCE-FOOTER` (hyphens for spaces) is used per the §Sentinel-obfuscation rule below; the attestation line sits one physical line above where that sentinel actually renders.

Example shapes (illustrative model IDs — emit YOUR OWN, never these): code/full frontmatter carries `claude_model: claude-fable-5` alongside `evidence_class: dual_model`; spec mode emits a single `claude_model: claude-fable-5` line immediately preceding the EVIDENCE FOOTER sentinel marker.

**Sentinel-obfuscation rule (self-anchoring carve-out)**: agents auditing `agents/cross-auditor.md` itself (cross-audits where this file appears in the diff scope OR is loaded as a focus area) MUST NOT reproduce the canonical spaced sentinel literal mid-prose. The canonical spaced literal is RESERVED for the actual three-line footer block at end-of-response (the fenced documentation example block above is the single producer-side authoritative documentation site for the canonical form). When the agent needs to quote, discuss, or reference the sentinel mid-prose, it MUST use one of these obfuscated forms: (i) the description `the EVIDENCE FOOTER sentinel marker`, (ii) the hyphenated literal `CROSS-AUDIT-EVIDENCE-FOOTER` (substituting hyphens for the spaces in the canonical form), (iii) the prose `the cross-audit evidence footer comment line`. This rule prevents the consumer-side EOF-adjacency parser (SKILL.md §spec-mode parser) from being fooled by mid-prose echoes when the cross-auditor reads its own source as part of an audit. The defense-in-depth rationale: keep the canonical form to the single fenced documentation site, route all other references through the obfuscated forms, eliminate ambiguity at the source.

The orchestrator parses by FIRST normalizing the captured return text to strip ALL trailing newlines (a transport-layer artifact — bash `$(cmd)` substitution strips them coincidentally, but file reads / `read -d ''` / MCP byte-exact transport preserve them and would shift the `tail -3` window off the real footer), THEN reading the LAST THREE physical lines via `tail -3` and asserting byte-exact full-line equality on the first-of-three against the canonical spaced sentinel literal (full-line equality, NOT substring), prefix-check on the second-of-three (`evidence_class: `), prefix-check on the third-of-three (`evidence_blockers: `). If the first-of-three byte-exact full-line equality check fails OR either prefix check fails, the orchestrator MUST treat the audit as `contract_violated` (cross-auditor return signal not parseable) and record the parse failure as a blocker — see SKILL.md §3.5b Contract-violation rule for the orchestrator-side read path. EOF-adjacency on `tail -3` closes two failure modes the prior shape missed: (a) **forgotten-footer-with-example-echo** — the agent omits the real footer but echoes documentation examples (such as the fenced example earlier in this section) in its prose; the byte-exact full-line equality check on the first-of-three at EOF-adjacent position fails when only mid-prose echoes exist and no real footer block lives at end-of-response; (b) **trailing-prose-after-real-footer** — the agent emits the real footer then appends a sentence (apology, summary); the trailing prose pushes the sentinel away from the EOF-adjacent slot, the first-of-three full-line equality check fails. Both modes route to `contract_violated` with blocker `'sentinel not at expected EOF-adjacent position'`. Adjacency-and-EOF enforcement on `tail -3` with byte-exact first-line full-line equality is the load-bearing property both modes require.

### Audited-HEAD attestation contract (`audited_head`)

Per spec `2026-07-05-audited-head-terminal-evidence-gates.md`. On file-backed audits the cross-auditor ALSO emits `audited_head:` — the commit OID the audit actually read — so the orchestrator can catch a stale audit (fix commits that land after the last audit round, which the terminal audit never saw). `audited_head:` is a SIBLING of `claude_model:` in the leading findings.md frontmatter and mirrors it 1:1 in placement and lifecycle.

**Channel — file-backed modes ONLY (`code`/`full`/`logic`/`security`).** One canonical `audited_head: <full commit oid>` key in the leading frontmatter of `<audit_slug>-findings.md`, sibling of `claude_model:`. Spec and decision modes emit NOTHING for this field: `audited_head` is NOT part of the inline-return footer contract, the spec/decision three-line footer stays byte-identical (zero migration), and a transient inline report carries no commit sign-off semantics. This is the deliberate asymmetry vs `claude_model`, which IS emitted in spec/decision mode (immediately preceding the sentinel).

**Source of truth — `git rev-parse HEAD` in the audit workspace.** Emit the exact OID output by `git rev-parse HEAD` run in the workspace the audit actually read: the worktree HEAD in materialized mode, the caller cwd HEAD in in-place mode. Overwritten each iteration with the current run's HEAD (same overwrite rule as `claude_model:`).

**Non-git carve-out.** When the audit workspace is NOT a git repo (the standalone non-git in-place path), `git rev-parse HEAD` cannot resolve — the `audited_head:` pin is OMITTED from the frontmatter entirely, and the standalone invocation correspondingly skips `--expected-head` so no false `HEAD_ATTESTATION_MISSING` fires. /feature callsites are always git-backed and are unaffected.

**No value-shape validation** (mirror of `claude_model`). The parser does not validate the OID shape; a malformed or wrong OID simply mismatches the orchestrator's expected HEAD and routes to the audited-HEAD gate, never a silent pass.
