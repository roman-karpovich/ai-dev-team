# Cross-auditor: Mode Focus Areas

Canonical content for the `## Mode Focus Areas` section of `agents/cross-auditor.md`. Covers the four operating modes (`logic`, `security`, `full`, `spec`), the R-rule cluster gate that wires `code-quality-rules.md` into the security audit, the supplemental Smart Contracts / DeFi + Backend Services bullet lists, and the spec-mode rule body (Agent pre-tag consistency, Repo-convention enforcement, §1.1 Attack-surface profile schema validation, §1.2 STRIDE-lite gating).

## Mode Focus Areas

### `logic` mode
- Correctness: logic errors, edge cases, off-by-one, state machine bugs
- Conventions: naming, code style, project patterns
- Performance: hot-path bottlenecks, unnecessary allocations, O(n²) where O(1) exists
- Robustness: error handling, crash paths, resource leaks, missing timeouts
- Test coverage gaps

### `security` mode

When R-rules with `category: security` and `enforced_by` containing `cross-auditor:security` exist in `code-quality-rules.md`, those rules are the cluster source for the active `project_type` (filtered via the `applies_to` list per §Taxonomy / Trigger A in `code-quality-rules.md`; Trigger B — frontmatter parse failure — loads every body section verbatim with a stderr warning per the same §Taxonomy contract). For `project_type=backend`, the active cluster is R9, R10, R11, R12, R13, R14: load their body sections (Rule / Why / How to apply / Bad code / Good code) and treat them as the canonical bad-code patterns to flag and good-code conventions to verify. The Smart Contracts / DeFi and Backend Services bullet lists below stay as supplemental coverage — they cover defect classes (race conditions, deadlocks, DoS, oracle manipulation, etc.) not yet codified as R-rules; for any project_type they apply alongside the filtered R-rules, never as a replacement.

**Smart Contracts / DeFi:**
- Fund loss vectors, reentrancy, access control
- Math precision (overflow, rounding, fee calculations)
- Flash loan safety, MEV resistance
- Private key / seed handling
- Transaction signing correctness, replay protection
- Slippage and oracle manipulation

**Backend Services:**
- Input validation, injection, auth bypass
- Race conditions, deadlocks, data corruption
- Resource exhaustion, DoS vectors

### `full` mode
Run both `logic` and `security` focus areas in the same pass.

### `spec` mode

Reviews a **feature spec document** (not code) before implementation begins. The audit target is the spec file itself.

- **Completeness**: are all edge cases and failure modes addressed?
- **Clarity**: each checklist step is atomic and unambiguous — a developer can implement it without guessing
- **Dependencies**: all files, external services, data structures, config keys explicitly named
- **Sequencing**: checklist steps in valid dependency order — no step depends on a later step
- **Correctness**: does the proposed design actually solve the stated problem?
- **Verification gaps**: will the verification steps actually detect a broken implementation?
- **Scope**: no hidden cross-cutting concerns, no missing inter-service impacts
- **Risk**: significant technical risks not mentioned in the spec
- **Agent pre-tag consistency** (if §5 steps carry `@<agent>` tags): each tag must (a) match at least one positive trigger for the tagged agent in `skills/feature/references/agent-routing.md` AND (b) not contradict any anti-trigger of the tagged agent (per that agent's own Anti-triggers list — iter-4 X24: only the tagged agent's anti-triggers apply, not other agents' positive triggers). A step tagged `@codex` but described as "ambiguous scope" / "cross-cutting refactor" / "broad live filesystem exploration" fails (b) → HIGH. A step tagged `@senior` but described as "trivial one-liner" fails both (a) and (b) — Senior has no positive trigger that fits trivial work and "trivial one-liner" is explicitly in Senior's anti-trigger list → HIGH. Malformed tags — unknown token, wrong spacing, or any suffix form other than `@codex` / `@senior` — are flagged HIGH regardless of trigger analysis (iter-3 X18). Untagged steps → no check.
- **Repo-convention enforcement**: HIGH if §5 contains placement/naming/layout ambiguity (literal substrings `at developer's discretion`, `developer's call`, `as you see fit`, `at agent discretion`) AND the target repo has any of `AGENTS.md` / `CLAUDE.md` / `.github/CONTRIBUTING.md` with directive guidance on the ambiguous topic that §2 did not quote. Verification: open the convention file, search for the topic keywords (test placement, branch naming, etc.); if the file carries an imperative on the topic and §2 has no Repo conventions subsection quoting it → HIGH. Untagged convention files (no AGENTS.md / CLAUDE.md / CONTRIBUTING.md present) → no flag.

- **Attack-surface profile**: read `## 1.1 Attack-surface profile` from the spec.
  - **Absent-section check**: the auditor MUST verify the section is a real top-level H2 outside fenced code blocks. Do NOT reason out the fence-parsing by hand — invoke the deterministic helper `bash "${CLAUDE_PLUGIN_ROOT}/hooks/lib/locate_section_outside_fences.sh" <spec-file> '^## 1\.1 Attack-surface profile$' '^## 1\. Context$' '^## 2\. Current State$'` (env-anchored absolute path, never a bare relative `hooks/lib/...` form — the auditor's cwd during an audit is the target repo, so a bare path would let a target-repo script at the same path shadow the trusted plugin helper). The helper locates a line matching the section pattern at column 0, NOT inside any 3-backtick or 4-backtick fenced code block, AND positioned after the first `^## 1\. Context$` line and before the first `^## 2\. Current State$` line. It exits `0` and prints `found` when a qualifying heading exists, `1` / `not-found` when it does not, and `2` (with a `⚠` stderr diagnostic) on an argument error — treat exit `2` as a tooling fault, NOT as a not-found result. Mere prose mentions or occurrences inside fenced examples (e.g. spec-template.md skeleton blocks) do NOT satisfy this requirement — the helper already excludes them. **YAML-block locator**: within the §1.1 section bounded by the validated heading and the next column-0 H1/H2 heading (or end-of-file), locate the FIRST fenced ` ```yaml ` or ` ```yml ` code block (the heading may be followed by prose paragraphs before the YAML fence — the locator skips prose and finds the first fenced YAML block). Parse only that fence's contents. If no such heading exists, OR no fenced ` ```yaml `/` ```yml ` block exists within the section, OR YAML parse fails, OR the parsed root is not a mapping with an `attack_surface:` key, flag HIGH with finding text "Spec missing required §1.1 Attack-surface profile section outside fenced code blocks — re-run /feature New slot prompts or add the block manually per spec-template.md" and skip subsequent checks.
  - **Schema-validity gate on `not_applicable` field itself** (X13 closure — type/presence check on the discriminator): the auditor MUST verify the parsed `attack_surface` is a YAML mapping AND the `not_applicable` field is present AND its value is a YAML boolean (`true` or `false`, NOT a string `"true"` / `"false"`, NOT `null`, NOT missing). If any invariant is violated, flag HIGH with finding text "Spec violates §3.3 schema — attack_surface.not_applicable must be a boolean (true | false), got <observed-shape>; re-run slot prompts or fix the YAML manually." Skip subsequent checks after this flag.
  - **Cross-field consistency check** (`not_applicable: true` direction): if `attack_surface.not_applicable: true`, validate that ALL FIVE sibling keys (`caller_identity`, `external_input`, `rate_limit`, `abuse_scenarios`, `framework_version_target`) are PRESENT in the parsed mapping AND each carries the YAML `null` value. If any sibling is missing OR carries a non-`null` value, flag HIGH with finding text "Spec sets attack_surface.not_applicable=true but other slots are missing or carry non-null values; per §3.3 canonical rule all five other fields MUST be present as literal null — re-run slot prompts or fix the YAML manually." Skip subsequent checks after this flag.
  - **Schema-validity check** (`not_applicable: false` direction — the inverse invariant): if `attack_surface.not_applicable: false`, validate the four required-non-null slots: (a) `caller_identity` is one of `{anonymous-public, authenticated-user, service-account, cron, webhook-external, mixed, unspecified}`; (b) `external_input` is boolean (`true` or `false`, NOT null); (c) `rate_limit` is one of `{per-ip, per-user, per-api-key, per-tenant, none, unspecified}`; (d) `abuse_scenarios` is either a string or `null`; (e) `framework_version_target` is either a string or `null`. If any required field is missing, null where non-null required, or carries an out-of-enum value, flag HIGH with finding text "Spec sets attack_surface.not_applicable=false but slot violates §3.3 schema (caller_identity/external_input/rate_limit must be non-null in-enum values); re-run /feature New slot prompts or fix the YAML manually." Skip the external_input check after this flag.
  - **not_applicable short-circuit**: if `attack_surface.not_applicable: true` AND the cross-field consistency check above passes, skip the external_input check (smart-contract / doc-only specs).
  - **external_input check**: if `attack_surface.external_input: true`, scan the `## 3. Design` section for any of the case-insensitive literal substrings `input validation`, `validate input`, `sanitization`, `sanitize`, `schema validation`, `JSON schema`, `type validation`, `parameterised query`, `parameterized query`, `bound parameter`, `prepared statement`, `pydantic`. **§3 Design locator**: locate the line matching `^## 3\. Design$` at column 0, NOT inside any 3-backtick or 4-backtick fenced code block; bound the section by the next column-0 H1/H2 heading or end-of-file. Within the section bounds, IGNORE all content inside fenced code blocks (3-backtick or 4-backtick) — only count substring matches in prose paragraphs, list items, and table cells outside fences. If NONE of those 12 substrings appears in the §3 Design prose (outside fenced code blocks), flag HIGH with finding text "Spec declares external_input=true (§1.1 attack_surface) but §3 Design (outside fenced code blocks) does not address input validation; specify the input-validation strategy in §3.X (sanitization library / schema-validation contract / parameterised-query enforcement / equivalent) before HARD-GATE approval."
  - Do NOT flag if `external_input: false` (no input-validation discussion required).
  - Do NOT extend this rule beyond the external_input axis without a follow-up spec — the other slots (caller_identity, rate_limit, abuse_scenarios, framework_version_target) inform reviewer judgement but do not produce automatic HIGH flags in v1.

- **STRIDE-lite threat model**: read `## 1.2 STRIDE-lite threat model` from the spec when `## 1.1 Attack-surface profile` carries `external_input: true`. If `external_input: false` (or `not_applicable: true`), skip this check (the §1.2 section is correctly absent on non-external-input specs). If `external_input: true` AND `## 1.2 STRIDE-lite threat model` section is absent OR all 6 row values are `null`, flag MEDIUM with finding text "Spec declares external_input=true (§1.1 attack_surface) but §1.2 STRIDE-lite threat model is absent or all 6 rows null; populate at least 2 rows (Spoofing/Tampering/Repudiation/InfoDisclosure/DoS/EoP) with 1-3 sentence mitigation prose, or document why STRIDE-lite is not applicable in §3 Design." MEDIUM (NOT HIGH) because STRIDE-lite is recommended, not mandatory — partial coverage is acceptable.

<!-- end §spec mode -->
