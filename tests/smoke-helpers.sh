# tests/smoke-helpers.sh — sourced by tests/smoke.sh.
# Parameterized section-scoped checks for the R3 block.
# Depends on extract_md_section being defined in the caller.

check_r3_rule_heading_present() {
  # $1 = path to code-quality-rules.md (or a fixture)
  local path="$1"
  grep -qF "## R3 — Test strength / signal-to-noise" "$path" \
    || { echo "$path missing '## R3 — Test strength / signal-to-noise' heading"; return 1; }
  echo "R3 heading present in $path"
}

check_r3_structure_triplet_present() {
  local path="$1"
  local R3
  R3=$(extract_md_section "$path" '## R3 — Test strength / signal-to-noise')
  printf '%s\n' "$R3" | grep -qF '**Rule**:' || { echo "R3 section in $path missing '**Rule**:' subheading"; return 1; }
  printf '%s\n' "$R3" | grep -qF '**Why**:' || { echo "R3 section in $path missing '**Why**:' subheading"; return 1; }
  printf '%s\n' "$R3" | grep -qF '**How to apply**:' || { echo "R3 section in $path missing '**How to apply**:' subheading"; return 1; }
  echo "R3 structure triplet (Rule/Why/How to apply) present in $path"
}

check_r3_anti_patterns_enumerated() {
  local path="$1"
  local R3
  R3=$(extract_md_section "$path" '## R3 — Test strength / signal-to-noise')
  printf '%s\n' "$R3" | grep -qiF 'tautological' || { echo "R3 section in $path missing 'tautological' anti-pattern token"; return 1; }
  printf '%s\n' "$R3" | grep -qiF 'setter-getter round-trip' || { echo "R3 section in $path missing 'setter-getter round-trip' anti-pattern token"; return 1; }
  printf '%s\n' "$R3" | grep -qiF 'mock-call-counter' || { echo "R3 section in $path missing 'mock-call-counter' anti-pattern token"; return 1; }
  printf '%s\n' "$R3" | grep -qiF 'assertIsNotNone' || { echo "R3 section in $path missing 'assertIsNotNone' anti-pattern token"; return 1; }
  printf '%s\n' "$R3" | grep -qiF 'type-checker' || { echo "R3 section in $path missing 'type-checker' anti-pattern token"; return 1; }
  echo "R3 anti-pattern tokens (5) all present in $path"
}

check_r3_notes_requirement_present() {
  local path="$1"
  local R3
  R3=$(extract_md_section "$path" '## R3 — Test strength / signal-to-noise')
  printf '%s\n' "$R3" | grep -qF 'Every fresh test must have a one-sentence note in `observed.notes` naming the regression it catches; if you cannot name it, the test is weak — rewrite or delete.' \
    || { echo "R3 section in $path missing byte-exact notes-requirement sentence"; return 1; }
  echo "R3 notes-requirement sentence present byte-exact in $path"
}

check_developer_workflow_short_form_r3() {
  local path="$1"
  extract_md_section "$path" '## Code Quality Rules' | \
    grep -E 'R3.*test strength.*code-quality-rules\.md|test strength.*R3.*code-quality-rules\.md' -q \
    || { echo "$path §Code Quality Rules missing single-line R3/test strength/code-quality-rules.md bullet"; return 1; }
  echo "$path §Code Quality Rules has R3 short-form bullet"
}

check_developer_workflow_test_quality_points_to_r3() {
  local path="$1"
  extract_md_section "$path" '## Test Quality' | \
    grep -qF 'For test strength (whether a test actually catches regressions), see R3 in `code-quality-rules.md`.' \
    || { echo "$path §Test Quality missing byte-exact R3 pointer sentence"; return 1; }
  echo "$path §Test Quality points to R3"
}

check_developer_workflow_observed_notes_requirement() {
  local path="$1"
  extract_md_section "$path" '## Per-step protocol' | \
    grep -qF 'If the step adds or modifies a fresh test, `observed.notes` must include a one-sentence description of the regression the test catches (see R3).' \
    || { echo "$path §Per-step protocol missing byte-exact observed.notes R3 sentence"; return 1; }
  echo "$path §Per-step protocol has observed.notes R3 requirement"
}

# --- Per-step agent pre-tag (spec 2026-04-20-per-step-agent-pretag) ---

check_spec_template_agent_pretag_grammar() {
  local path='skills/feature/references/spec-template.md'
  local section
  section=$(extract_md_section "$path" '## 5. Implementation Checklist')
  printf '%s\n' "$section" | grep -qF -- '- [ ] Step 1: description @codex' \
    || { echo "$path §5 missing byte-exact example line '- [ ] Step 1: description @codex'"; return 1; }
  printf '%s\n' "$section" | grep -qF -- '- [ ] Step 2: description @senior' \
    || { echo "$path §5 missing byte-exact example line '- [ ] Step 2: description @senior'"; return 1; }
  printf '%s\n' "$section" | grep -qF -- '- [ ] Step 3: description @middle' \
    || { echo "$path §5 missing byte-exact example line '- [ ] Step 3: description @middle'"; return 1; }
  printf '%s\n' "$section" | grep -qF -- '- [ ] Step 4: description' \
    || { echo "$path §5 missing byte-exact example line '- [ ] Step 4: description'"; return 1; }
  local marker_count
  marker_count=$(printf '%s\n' "$section" | grep -cF -- '**Agent pre-tag (optional).**')
  [[ "$marker_count" == "1" ]] \
    || { echo "$path §5 '**Agent pre-tag (optional).**' marker must appear exactly once (got $marker_count)"; return 1; }
  printf '%s\n' "$section" | grep -qF -- 'No other suffix forms (no `@codex-fast`, no `@agent=codex`, no `(agent: codex)`).' \
    || { echo "$path §5 missing byte-exact 'No other suffix forms …' sentence"; return 1; }
  printf '%s\n' "$section" | grep -qF -- 'the orchestrator lowercases the tag at read time' \
    || { echo "$path §5 missing byte-exact 'the orchestrator lowercases the tag at read time' clause"; return 1; }
  echo "$path §5 has @<agent> pre-tag grammar (4-line example + marker + 'No other suffix forms' + lowercase-normalization)"
}

check_skill_md_step2_pretag_guidance() {
  local path='skills/feature/SKILL.md'
  # Explicit anchor-presence guards (iter-5 X28 + iter-6 X30) — awk range mode
  # is silent on missing/out-of-order anchors, so assert both exist as
  # standalone greppable lines before extracting.
  grep -qF -- 'Leave all `observed` fields empty — the developer fills them during implementation.' "$path" \
    || { echo "$path missing start anchor 'Leave all \`observed\` fields empty — the developer fills them during implementation.'"; return 1; }
  grep -qF -- '**Change-type prompt.**' "$path" \
    || { echo "$path missing end anchor '**Change-type prompt.**'"; return 1; }
  local range
  range=$(awk '/^Leave all `observed` fields empty — the developer fills them during implementation\.$/,/^\*\*Change-type prompt\.\*\*/' "$path")
  printf '%s\n' "$range" | grep -qF -- 'optionally tag the recommended agent inline using the' \
    || { echo "$path §Step 2 insertion range missing byte-exact 'optionally tag the recommended agent inline using the' phrase"; return 1; }
  local marker_count
  marker_count=$(printf '%s\n' "$range" | grep -cF -- '**Agent pre-tag (optional).**')
  [[ "$marker_count" == "1" ]] \
    || { echo "$path §Step 2 insertion range '**Agent pre-tag (optional).**' marker must appear exactly once (got $marker_count)"; return 1; }
  echo "$path §Step 2 has pre-tag authoring guidance (awk-scoped between 'Leave all observed…' and '**Change-type prompt.**')"
}

check_skill_md_agent_selection_tag_read() {
  local path='skills/feature/SKILL.md'
  # Explicit anchor-presence guards (iter-8 X34) — extract_md_section on
  # '### Agent selection' cuts off at '## ⏸ AWAITING YOUR INPUT' (SKILL.md:346)
  # which lies before the stub at SKILL.md:359. Use awk range-extraction instead
  # between '**Which agent?**' and '**Remember the choice**:' prefix.
  grep -qF -- '**Which agent?**' "$path" \
    || { echo "$path missing start anchor '**Which agent?**'"; return 1; }
  grep -qF -- '**Remember the choice**:' "$path" \
    || { echo "$path missing end anchor '**Remember the choice**:'"; return 1; }
  local range
  range=$(awk '/^\*\*Which agent\?\*\*$/,/^\*\*Remember the choice\*\*:/' "$path")
  printf '%s\n' "$range" | grep -qF -- "the tag is honored iff the step's description matches at least one positive trigger for the tagged agent AND no anti-trigger contradicts it" \
    || { echo "$path Agent-selection range missing byte-exact positive-trigger-gate sentence"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'one of `T-C1` / `T-C2` / `T-C3` for `@codex`' \
    || { echo "$path Agent-selection range missing byte-exact Codex rationale-ID enumeration"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'one of `T-S1` / `T-S2` / `T-S3` / `T-S4` for `@senior`' \
    || { echo "$path Agent-selection range missing byte-exact Senior rationale-ID enumeration"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'one of `T-M1` / `T-M2` for `@middle`' \
    || { echo "$path Agent-selection range missing byte-exact Middle rationale-ID enumeration"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'never `T-S0`' \
    || { echo "$path Agent-selection range missing 'never \`T-S0\`' clause"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'notes=pre-tagged by spec author' \
    || { echo "$path Agent-selection range missing 'notes=pre-tagged by spec author' clause"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'log rationale using the **actual matched positive trigger**' \
    || { echo "$path Agent-selection range missing byte-exact 'log rationale using the **actual matched positive trigger**' phrase"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'Log only after the user confirms the banner pick' \
    || { echo "$path Agent-selection range missing byte-exact 'Log only after the user confirms the banner pick' phrase"; return 1; }
  printf '%s\n' "$range" | grep -qF -- "if the user overrides the tagged default, log the final pick with its own rationale, not the tag's" \
    || { echo "$path Agent-selection range missing byte-exact user-override branch"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'treat as untagged and emit a one-line preamble warning above the banner noting the mismatch' \
    || { echo "$path Agent-selection range missing byte-exact mismatch-warning sentence"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'hard-stop with a banner asking the user to correct the checklist line before continuing' \
    || { echo "$path Agent-selection range missing byte-exact malformed-tag hard-stop phrase"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'case-insensitive; the orchestrator lowercases before matching' \
    || { echo "$path Agent-selection range missing byte-exact 'case-insensitive; the orchestrator lowercases before matching' phrase"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'Untagged steps → use the routing matrix triggers as today.' \
    || { echo "$path Agent-selection range missing byte-exact 'Untagged steps → use the routing matrix triggers as today.' sentence"; return 1; }
  echo "$path Agent-selection range has all §3.4 byte-frozen prose pins"
}

check_skill_md_continue_mode_tag_read() {
  local path='skills/feature/SKILL.md'
  # Explicit anchor-presence guards (iter-8 X34) — extract_md_section on
  # '## Continue mode' cuts off at '## ⏸ AWAITING YOUR INPUT' (SKILL.md:543)
  # which lies before the target append-site at SKILL.md:578 inside the second
  # banner. Use awk range-extraction between the stable first clause of
  # SKILL.md:578 and the '**Which developer (default is the' prefix on
  # SKILL.md:580.
  grep -qF -- 'Resuming implementation. Pick the developer for the remaining steps.' "$path" \
    || { echo "$path missing start anchor 'Resuming implementation. Pick the developer for the remaining steps.'"; return 1; }
  grep -qF -- '**Which developer (default is the' "$path" \
    || { echo "$path missing end anchor '**Which developer (default is the'"; return 1; }
  local range
  range=$(awk '/^Resuming implementation\. Pick the developer for the remaining steps\./,/^\*\*Which developer \(default is the/' "$path")
  printf '%s\n' "$range" | grep -qF -- 'and the tag would be honored by the §3.4 acceptance rule — positive trigger matches AND no anti-trigger contradicts' \
    || { echo "$path Continue-mode range missing byte-exact §3.4-acceptance gate phrase"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'Continue mode presents the tagged agent as the banner default, not the Log value' \
    || { echo "$path Continue-mode range missing byte-exact 'banner default, not the Log value' clause"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'A tag that §3.4 would reject is treated as untagged on resume too' \
    || { echo "$path Continue-mode range missing byte-exact rejection-fallback clause"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'Continue mode falls back to the `last_agent=` Log value and emits the same mismatch warning above the banner' \
    || { echo "$path Continue-mode range missing byte-exact 'falls back to the \`last_agent=\` Log value …' clause"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'malformed tag hard-stops on resume' \
    || { echo "$path Continue-mode range missing 'malformed tag hard-stops on resume' clause"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'first unchecked step' \
    || { echo "$path Continue-mode range missing 'first unchecked step' clause"; return 1; }
  printf '%s\n' "$range" | grep -qF -- 'this specific step' \
    || { echo "$path Continue-mode range missing 'this specific step' clause"; return 1; }
  echo "$path Continue-mode range has all §3.5 byte-frozen prose pins"
}

# --- DONE→VERIFIED migration (spec 2026-04-20-done-verified-migration) ---
# Self-contained helpers: each does inline awk extraction, does NOT rely on
# extract_md_section from the caller. Accepts $1 = path (real plugin file OR
# negative fixture). Returns 0 iff the canonical shape is present AND stale
# pre-fix text is absent; non-zero otherwise with one diagnostic line.

check_librarian_status_block_canonical() {
  local path="$1"
  local section
  # Inline extraction — first '### Feature Spec frontmatter' heading to next '### '.
  section=$(awk '
    !in_s && $0 == "### Feature Spec frontmatter" { in_s = 1; print; next }
    in_s && /^### / { exit }
    in_s { print }
  ' "$path")
  [[ -n "$section" ]] || { echo "$path missing '### Feature Spec frontmatter' section"; return 1; }

  # Positive: canonical enum line (8-status form).
  printf '%s\n' "$section" | grep -qF 'status: DRAFT | APPROVED | AUDIT_PASSED | IN_PROGRESS | BLOCKED | SHIPPED | VERIFIED | DISCARDED' \
    || { echo "$path §Feature Spec frontmatter missing canonical 8-status enum line"; return 1; }

  # Positive: transitions diagram anchor.
  printf '%s\n' "$section" | grep -qF 'DRAFT → APPROVED → AUDIT_PASSED → IN_PROGRESS → SHIPPED → VERIFIED' \
    || { echo "$path §Feature Spec frontmatter missing canonical transitions arrow"; return 1; }

  # Positive: BLOCKED ↕ glyph on its own line.
  printf '%s\n' "$section" | grep -qF '↕' \
    || { echo "$path §Feature Spec frontmatter missing BLOCKED bidirectional arrow glyph '↕'"; return 1; }
  printf '%s\n' "$section" | grep -qF 'BLOCKED' \
    || { echo "$path §Feature Spec frontmatter missing BLOCKED token in transitions block"; return 1; }

  # Positive: legacy DONE annotation sentence.
  printf '%s\n' "$section" | grep -qF 'DONE: legacy read-only synonym of VERIFIED' \
    || { echo "$path §Feature Spec frontmatter missing legacy DONE annotation sentence"; return 1; }

  # Positive: 9 description bullets, one unique signature each.
  printf '%s\n' "$section" | grep -qF 'spec written, not yet reviewed by user' \
    || { echo "$path §Feature Spec frontmatter missing DRAFT bullet signature"; return 1; }
  printf '%s\n' "$section" | grep -qF 'user approved the spec, spec audit not yet run' \
    || { echo "$path §Feature Spec frontmatter missing APPROVED bullet signature"; return 1; }
  printf '%s\n' "$section" | grep -qF 'dual-model spec audit passed (or skipped), ready for implementation' \
    || { echo "$path §Feature Spec frontmatter missing AUDIT_PASSED bullet signature"; return 1; }
  printf '%s\n' "$section" | grep -qF 'developer agent is actively implementing' \
    || { echo "$path §Feature Spec frontmatter missing IN_PROGRESS bullet signature"; return 1; }
  printf '%s\n' "$section" | grep -qF 'work paused on an external dependency; unblock condition recorded in Log' \
    || { echo "$path §Feature Spec frontmatter missing BLOCKED bullet signature"; return 1; }
  printf '%s\n' "$section" | grep -qF 'feature merged, post-merge checklist still has open items' \
    || { echo "$path §Feature Spec frontmatter missing SHIPPED bullet signature"; return 1; }
  printf '%s\n' "$section" | grep -qF 'terminal — feature complete, observed, all post-merge items resolved' \
    || { echo "$path §Feature Spec frontmatter missing VERIFIED bullet signature"; return 1; }
  printf '%s\n' "$section" | grep -qF 'work thrown away via explicit' \
    || { echo "$path §Feature Spec frontmatter missing DISCARDED bullet signature"; return 1; }
  printf '%s\n' "$section" | grep -qF 'read-only synonym of' \
    || { echo "$path §Feature Spec frontmatter missing DONE (legacy) bullet signature"; return 1; }

  # Negative: stale 6-status enum must be gone.
  if printf '%s\n' "$section" | grep -qF 'status: DRAFT | APPROVED | AUDIT_PASSED | IN_PROGRESS | DONE | DISCARDED'; then
    echo "$path §Feature Spec frontmatter still contains stale 6-status enum"
    return 1
  fi
  # Negative: stale transition arrow must be gone.
  if printf '%s\n' "$section" | grep -qF 'DRAFT → APPROVED → AUDIT_PASSED → IN_PROGRESS → DONE'; then
    echo "$path §Feature Spec frontmatter still contains stale '... → DONE' transition arrow"
    return 1
  fi
  # Negative: stale DONE terminal wording must be gone.
  if printf '%s\n' "$section" | grep -qF 'DONE`: all checklist steps complete, verification passed, work preserved'; then
    echo "$path §Feature Spec frontmatter still contains stale 'DONE: all checklist steps complete ...' wording"
    return 1
  fi

  # Structural: exactly 9 status-bullet lines matching ^- `[A-Z_]+`.
  local bullet_count
  bullet_count=$(printf '%s\n' "$section" | grep -cE '^- `[A-Z_]+`')
  [[ "$bullet_count" == "9" ]] \
    || { echo "$path §Feature Spec frontmatter expected exactly 9 status bullets, got $bullet_count"; return 1; }

  echo "$path §Feature Spec frontmatter has canonical 8-status enum + transitions + 9 bullets incl. legacy DONE"
}

check_discard_mode_refuses_verified_shipped() {
  local path="$1"
  local section
  # Inline extraction — first '## Discard mode' heading to next '## '.
  section=$(awk '
    !in_s && $0 == "## Discard mode" { in_s = 1; print; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$path")
  [[ -n "$section" ]] || { echo "$path missing '## Discard mode' section"; return 1; }

  # Positive: canonical refuse items 3, 4, 5.
  printf '%s\n' "$section" | grep -qF 'Refuse if `status: VERIFIED` (or legacy `DONE`)' \
    || { echo "$path §Discard mode missing item-3 signature 'Refuse if \`status: VERIFIED\` (or legacy \`DONE\`)'"; return 1; }
  printf '%s\n' "$section" | grep -qF 'Spec already verified; to undo, revert the merge commit(s) via git.' \
    || { echo "$path §Discard mode missing item-3 remediation sentence"; return 1; }
  printf '%s\n' "$section" | grep -qF 'Refuse if `status: SHIPPED`' \
    || { echo "$path §Discard mode missing item-4 signature 'Refuse if \`status: SHIPPED\`'"; return 1; }
  printf '%s\n' "$section" | grep -qF 'Spec already shipped. Use `/feature checklist` to manage open items' \
    || { echo "$path §Discard mode missing item-4 remediation sentence"; return 1; }
  printf '%s\n' "$section" | grep -qF 'Refuse if `status: DISCARDED` — already gone.' \
    || { echo "$path §Discard mode missing item-5 signature 'Refuse if \`status: DISCARDED\` — already gone.'"; return 1; }

  # Negative: stale item 3 must be gone.
  if printf '%s\n' "$section" | grep -qF 'Refuse if `status: DONE` — already merged, not something discard can undo.'; then
    echo "$path §Discard mode still contains stale 'Refuse if \`status: DONE\` — already merged ...' item"
    return 1
  fi

  # Structural: exactly 3 refuse items matching '^[0-9]+\. Refuse if `status:'.
  local refuse_count
  refuse_count=$(printf '%s\n' "$section" | grep -cE '^[0-9]+\. Refuse if `status:')
  [[ "$refuse_count" == "3" ]] \
    || { echo "$path §Discard mode expected exactly 3 refuse items, got $refuse_count"; return 1; }

  echo "$path §Discard mode has canonical 3-item refuse list (VERIFIED/SHIPPED/DISCARDED)"
}

check_feature_skill_no_active_done_writes() {
  local path="$1"
  [[ -r "$path" ]] || { echo "$path not readable"; return 1; }

  # Positive: §3.5 checklist add sentence.
  grep -qF 'Refuses to add items to `VERIFIED` (or legacy `DONE`) / `DISCARDED` specs.' "$path" \
    || { echo "$path missing §3.5 canonical checklist-add refuse sentence"; return 1; }

  # Positive: §3.6 post-verify paragraph — three key sentences byte-exact.
  grep -qF 'Do **not** set a terminal status (`VERIFIED` or `SHIPPED`) yet' "$path" \
    || { echo "$path missing §3.6 'Do **not** set a terminal status ...' clause"; return 1; }
  grep -qF '§3.4a applies the correct terminal (`VERIFIED` or `SHIPPED`) after hand-off' "$path" \
    || { echo "$path missing §3.6 '§3.4a applies the correct terminal ...' clause"; return 1; }
  grep -qF 'Setting a terminal before hand-off means a discard would leave the spec permanently marked terminal with no surviving branch' "$path" \
    || { echo "$path missing §3.6 'Setting a terminal before hand-off ...' clause"; return 1; }

  # Positive: §3.8 line 628 canonical form.
  grep -qF 'hide `VERIFIED` (or legacy `DONE`), `DISCARDED`, and `BLOCKED`' "$path" \
    || { echo "$path missing §3.8 line-628 'hide \`VERIFIED\` (or legacy \`DONE\`), \`DISCARDED\`, and \`BLOCKED\`' form"; return 1; }

  # Positive: §3.8 line 857 canonical form.
  grep -qF '**Spec is `VERIFIED` (or legacy `DONE`)**' "$path" \
    || { echo "$path missing §3.8 line-857 '**Spec is \`VERIFIED\` (or legacy \`DONE\`)**' form"; return 1; }

  # Positive: §3.8 line 877 canonical form.
  grep -qF 'Refuse on `SHIPPED` / `VERIFIED` (or legacy `DONE`) / `DISCARDED`' "$path" \
    || { echo "$path missing §3.8 line-877 'Refuse on \`SHIPPED\` / \`VERIFIED\` (or legacy \`DONE\`) / \`DISCARDED\`' form"; return 1; }

  # Negatives: each stale pre-fix form must be gone.
  if grep -qF 'set `status: DONE`' "$path"; then
    echo "$path still contains stale 'set \`status: DONE\`' write (guards §3.6 pre-fix)"
    return 1
  fi
  if grep -qF 'Refuses to add items to `VERIFIED` / `DISCARDED` specs.' "$path"; then
    echo "$path still contains stale §3.5 pre-fix sentence 'Refuses to add items to \`VERIFIED\` / \`DISCARDED\` specs.'"
    return 1
  fi
  if grep -qF 'hide `VERIFIED` / `DONE`, `DISCARDED`, and `BLOCKED`' "$path"; then
    echo "$path still contains stale §3.8 line-628 'hide \`VERIFIED\` / \`DONE\`, ...' form"
    return 1
  fi
  if grep -qF '**Spec is `VERIFIED` / `DONE`**' "$path"; then
    echo "$path still contains stale §3.8 line-857 '**Spec is \`VERIFIED\` / \`DONE\`**' form"
    return 1
  fi
  if grep -qF 'Refuse on `SHIPPED` / `VERIFIED` / `DONE` / `DISCARDED`' "$path"; then
    echo "$path still contains stale §3.8 line-877 'Refuse on \`SHIPPED\` / \`VERIFIED\` / \`DONE\` / \`DISCARDED\`' form"
    return 1
  fi

  echo "$path has canonical no-active-DONE-writes form (§3.5/§3.6/§3.8 all present, stale gone)"
}

check_developer_workflow_no_active_done_writes() {
  local path="$1"
  [[ -r "$path" ]] || { echo "$path not readable"; return 1; }

  # Positive — line 28 full replacement: three key phrases.
  grep -qF 'When your scope is complete: leave status: IN_PROGRESS.' "$path" \
    || { echo "$path missing line-28 preamble 'When your scope is complete: leave status: IN_PROGRESS.'"; return 1; }
  grep -qF 'Do NOT set a terminal status.' "$path" \
    || { echo "$path missing line-28 'Do NOT set a terminal status.' prohibition"; return 1; }
  grep -qF 'The feature-skill orchestrator owns the terminal transition (VERIFIED / SHIPPED, per §3.4a of feature/SKILL.md) after the verifier passes and the user picks a hand-off option.' "$path" \
    || { echo "$path missing line-28 shared sentence 'The feature-skill orchestrator owns the terminal transition ...'"; return 1; }

  # Positive — line 104 full replacement: single full-sentence check.
  grep -qF 'Leave status: IN_PROGRESS when done — the feature-skill orchestrator owns the terminal transition (VERIFIED / SHIPPED, per §3.4a of feature/SKILL.md) after the verifier passes and the user picks a hand-off option.' "$path" \
    || { echo "$path missing line-104 full-sentence canonical replacement"; return 1; }

  # Negatives.
  if grep -qF 'set status: DONE' "$path"; then
    echo "$path still contains stale 'set status: DONE' write"
    return 1
  fi
  if grep -qF 'owns the DONE transition' "$path"; then
    echo "$path still contains stale 'owns the DONE transition' phrase"
    return 1
  fi

  # Count: shared sentence must appear at least twice (once per paragraph).
  local shared_count
  shared_count=$(grep -cF 'owns the terminal transition (VERIFIED / SHIPPED, per §3.4a' "$path")
  [[ "$shared_count" -ge 2 ]] \
    || { echo "$path expected >=2 occurrences of shared 'owns the terminal transition (VERIFIED / SHIPPED, per §3.4a' sentence, got $shared_count"; return 1; }

  echo "$path has canonical no-active-DONE-writes form (line-28 + line-104 both present, stale gone)"
}

check_cross_auditor_pretag_consistency_check() {
  local path='agents/cross-auditor.md'
  local section
  section=$(extract_md_section "$path" '### `spec` mode')
  local label_count
  label_count=$(printf '%s\n' "$section" | grep -cF -- '**Agent pre-tag consistency**')
  [[ "$label_count" == "1" ]] \
    || { echo "$path §\`spec\` mode '**Agent pre-tag consistency**' label must appear exactly once (got $label_count)"; return 1; }
  printf '%s\n' "$section" | grep -qF -- 'match at least one positive trigger for the tagged agent in `skills/feature/references/agent-routing.md` AND (b) not contradict any anti-trigger of the tagged agent' \
    || { echo "$path §\`spec\` mode missing byte-exact (a)+(b) consistency rule incl. 'of the tagged agent'"; return 1; }
  printf '%s\n' "$section" | grep -qF -- 'A step tagged `@codex` but described as "ambiguous scope" / "cross-cutting refactor" / "broad live filesystem exploration" fails (b) → HIGH.' \
    || { echo "$path §\`spec\` mode missing byte-exact Codex example sentence"; return 1; }
  printf '%s\n' "$section" | grep -qF -- 'Malformed tags — unknown token, wrong spacing, or any suffix form other than `@codex` / `@senior` / `@middle` — are flagged HIGH regardless of trigger analysis' \
    || { echo "$path §\`spec\` mode missing byte-exact malformed-tags HIGH clause"; return 1; }
  printf '%s\n' "$section" | grep -qF -- 'A step tagged `@senior` but described as "trivial one-liner" fails both (a) and (b) — Senior has no positive trigger that fits trivial work and "trivial one-liner" is explicitly in Senior'"'"'s anti-trigger list → HIGH.' \
    || { echo "$path §\`spec\` mode missing byte-exact Senior example sentence"; return 1; }
  printf '%s\n' "$section" | grep -qF -- 'A step tagged `@middle` described as "new abstraction" / "design judgment required" fails (b) — both phrases match Middle'"'"'s anti-trigger list → HIGH.' \
    || { echo "$path §\`spec\` mode missing byte-exact Middle example sentence"; return 1; }
  printf '%s\n' "$section" | grep -qF -- 'Untagged steps → no check.' \
    || { echo "$path §\`spec\` mode missing byte-exact closing 'Untagged steps → no check.' sentence"; return 1; }
  echo "$path §\`spec\` mode has Agent pre-tag consistency bullet (label + (a)+(b) + 3 examples + Malformed + Untagged-closing)"
}
