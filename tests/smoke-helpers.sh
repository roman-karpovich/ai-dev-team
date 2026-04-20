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
  # Inline extraction — first '## Discard mode' heading to next '## ' heading,
  # but skip '## ⏸ AWAITING YOUR INPUT' banners (they nest inside the mode).
  section=$(awk '
    !in_s && $0 == "## Discard mode" { in_s = 1; print; next }
    in_s && /^## ⏸ AWAITING YOUR INPUT/ { print; next }
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

# --- Shared Phase 0 / KB discovery (spec 2026-04-20-shared-phase0) ---
# Self-contained helpers: each does inline awk/grep extraction, does NOT rely
# on extract_md_section from the caller. Each accepts $1 = path (real plugin
# file OR negative fixture). Returns 0 iff the canonical shape is present;
# non-zero with a diagnostic line otherwise. Bash-3.2 compatible (no
# `declare -A`).

check_kb_discovery_doc_canonical() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }

  # Required top-level headings (byte-exact).
  grep -qF '# KB discovery — Phase 0 shared reference' "$path" \
    || { echo "$path missing top-level heading '# KB discovery — Phase 0 shared reference'"; return 1; }
  grep -qF '## Why this exists' "$path" \
    || { echo "$path missing '## Why this exists' section"; return 1; }
  grep -qF '## Precedence order' "$path" \
    || { echo "$path missing '## Precedence order' section"; return 1; }
  grep -qF '## Algorithm' "$path" \
    || { echo "$path missing '## Algorithm' section"; return 1; }
  grep -qF '## Post-discovery yml save prompt' "$path" \
    || { echo "$path missing '## Post-discovery yml save prompt' section"; return 1; }
  grep -qF '## Multi-account github: config block' "$path" \
    || { echo "$path missing '## Multi-account github: config block' section"; return 1; }
  grep -qF '## Skill extensions — read in addition to the core algorithm' "$path" \
    || { echo "$path missing '## Skill extensions — read in addition to the core algorithm' section"; return 1; }
  grep -qF '### feature skill' "$path" \
    || { echo "$path missing '### feature skill' extensions subsection"; return 1; }
  grep -qF '### cross-audit skill' "$path" \
    || { echo "$path missing '### cross-audit skill' extensions subsection"; return 1; }
  grep -qF '### research skill' "$path" \
    || { echo "$path missing '### research skill' extensions subsection"; return 1; }
  grep -qF '## Skills that do NOT use Phase 0' "$path" \
    || { echo "$path missing '## Skills that do NOT use Phase 0' section"; return 1; }

  # Algorithm section must contain the 9-step ordered list. Extract the
  # `## Algorithm` section (up to the next `## ` heading) and require
  # numbered items 1. through 9.
  local algo_section
  algo_section=$(awk '
    !in_s && $0 == "## Algorithm" { in_s = 1; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$path")
  local n
  for n in 1 2 3 4 5 6 7 8 9; do
    printf '%s\n' "$algo_section" | grep -qE "^${n}\\. " \
      || { echo "$path ## Algorithm section missing step '${n}.' in canonical 9-step list"; return 1; }
  done

  # Post-discovery prompt section must contain the byte-exact prompt text.
  local prompt_section
  prompt_section=$(awk '
    !in_s && $0 == "## Post-discovery yml save prompt" { in_s = 1; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$path")
  printf '%s\n' "$prompt_section" | grep -qF 'Save `kb_path` and `project` to `.ai-dev-team.yml` so future sessions skip discovery? [Y/n]' \
    || { echo "$path ## Post-discovery yml save prompt section missing byte-exact 'Save \`kb_path\` and \`project\` to \`.ai-dev-team.yml\` so future sessions skip discovery? [Y/n]' prompt"; return 1; }

  # Multi-account github: config block section must reproduce the YAML keys.
  local gh_section
  gh_section=$(awk '
    !in_s && /^## Multi-account github: config block/ { in_s = 1; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$path")
  printf '%s\n' "$gh_section" | grep -qE '^[[:space:]]*github:' \
    || { echo "$path ## Multi-account github: config block section missing 'github:' key"; return 1; }
  printf '%s\n' "$gh_section" | grep -qE '^[[:space:]]*default_account:' \
    || { echo "$path ## Multi-account github: config block section missing 'default_account:' key"; return 1; }
  printf '%s\n' "$gh_section" | grep -qE '^[[:space:]]*accounts:' \
    || { echo "$path ## Multi-account github: config block section missing 'accounts:' key"; return 1; }
  printf '%s\n' "$gh_section" | grep -qE '^[[:space:]]*token_env:' \
    || { echo "$path ## Multi-account github: config block section missing 'token_env:' key"; return 1; }

  echo "$path canonical KB discovery doc (all required headings + 9-step Algorithm + yml prompt + github: keys)"
}

check_skill_phase0_references_shared_doc() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(awk '
    !in_s && /^## Phase 0:/ { in_s = 1; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path missing '## Phase 0:' section"; return 1; }
  printf '%s\n' "$section" | grep -qF 'docs/kb-discovery.md' \
    || { echo "$path ## Phase 0 section missing pointer to 'docs/kb-discovery.md'"; return 1; }
  echo "$path Phase 0 references shared docs/kb-discovery.md"
}

check_skill_phase0_extensions_present() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(awk '
    !in_s && /^## Phase 0:/ { in_s = 1; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path missing '## Phase 0:' section"; return 1; }
  # Look for a ### extensions subheading within the Phase 0 section and
  # require at least one non-blank content line after it.
  local ext_heading_count
  ext_heading_count=$(printf '%s\n' "$section" | grep -cE '^### .*[Ee]xtensions')
  [ "$ext_heading_count" -ge 1 ] \
    || { echo "$path ## Phase 0 section missing '### …extensions' subheading"; return 1; }
  local ext_body
  ext_body=$(printf '%s\n' "$section" | awk '
    !in_e && /^### .*[Ee]xtensions/ { in_e = 1; next }
    in_e && /^### / { exit }
    in_e { print }
  ')
  # Require at least one non-empty content line in the extensions body.
  printf '%s\n' "$ext_body" | grep -qE '[^[:space:]]' \
    || { echo "$path ## Phase 0 '### …extensions' subsection is empty"; return 1; }
  echo "$path Phase 0 has non-empty '### …extensions' subsection"
}

check_skill_phase0_no_inline_algorithm() {
  # Rejects whenever the 9-step algorithm's canonical sequence of numbered
  # steps appears in the file, regardless of whether a docs/kb-discovery.md
  # reference is also present (append-instead-of-replace also rejected).
  # Heuristic: look for three canonical signposts from the old inline
  # algorithm; if all three are present in the file, reject.
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local hit1=0 hit2=0 hit3=0
  grep -qF 'Determine `project` and `kb_path` via config before using legacy discovery.' "$path" && hit1=1
  grep -qF 'Compact shared-config fallback anchor: `.ai-dev-team.yml → memory → sibling heuristic → ask`' "$path" && hit2=1
  grep -qF 'per-field resolution: local → shared → memory → sibling → ask, continue on per-file parse error' "$path" && hit3=1
  if [ "$hit1" = "1" ] && [ "$hit2" = "1" ] && [ "$hit3" = "1" ]; then
    echo "$path still contains inline 9-step Phase 0 algorithm (3 canonical signposts all present); must reference docs/kb-discovery.md instead"
    return 1
  fi
  echo "$path has no inline 9-step Phase 0 algorithm"
}

check_investigate_no_phase0() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  if grep -qE '^## Phase 0' "$path"; then
    echo "$path contains '## Phase 0' heading — investigate must NOT have a Phase 0 section"
    return 1
  fi
  echo "$path correctly has no ## Phase 0 heading"
}

check_feature_phase0_mentions_codex_keys() {
  # Helper #6 per spec §3.5 invariant 6 (X6 broadened): the feature Phase 0
  # extensions section must mention all three codex keys.
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(awk '
    !in_s && /^## Phase 0:/ { in_s = 1; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path missing '## Phase 0:' section"; return 1; }
  printf '%s\n' "$section" | grep -qF 'codex.model' \
    || { echo "$path ## Phase 0 extensions missing substring 'codex.model'"; return 1; }
  printf '%s\n' "$section" | grep -qF 'codex.model_fast' \
    || { echo "$path ## Phase 0 extensions missing substring 'codex.model_fast'"; return 1; }
  printf '%s\n' "$section" | grep -qF 'codex.reasoning_effort' \
    || { echo "$path ## Phase 0 extensions missing substring 'codex.reasoning_effort'"; return 1; }
  echo "$path Phase 0 extensions mention all three codex.* keys"
}

check_cross_audit_phase0_bans_model_fast() {
  # Helper #7 per spec §3.5 invariant 7: cross-audit/SKILL.md must contain the
  # byte-exact ban on codex.model_fast within its Phase 0 section.
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(awk '
    !in_s && /^## Phase 0:/ { in_s = 1; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path missing '## Phase 0:' section"; return 1; }
  printf '%s\n' "$section" | grep -qF 'Never reads `codex.model_fast`' \
    || { echo "$path ## Phase 0 section missing byte-exact ban 'Never reads \`codex.model_fast\`'"; return 1; }
  echo "$path Phase 0 has byte-exact 'Never reads \`codex.model_fast\`' ban"
}

# --- Git conventions dedupe (spec 2026-04-20-git-conventions-dedupe) ---
# Self-contained helpers: each does inline awk/grep extraction, does NOT rely
# on extract_md_section from the caller. Each accepts $1 = path (real plugin
# file OR negative fixture). Returns 0 iff the canonical shape is present;
# non-zero with a diagnostic line otherwise. Bash-3.2 compatible.

check_dev_workflow_git_canonical() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  # Required headings.
  grep -qF '## Git Workflow' "$path" \
    || { echo "$path missing '## Git Workflow' heading"; return 1; }
  grep -qF '### Pre-commit branch assertion (MANDATORY)' "$path" \
    || { echo "$path missing '### Pre-commit branch assertion (MANDATORY)' subsection"; return 1; }
  grep -qF '### Post-merge bug flow' "$path" \
    || { echo "$path missing '### Post-merge bug flow' subsection"; return 1; }
  # Load-bearing body pins — Pre-commit branch assertion rules 1/2/3.
  grep -qF 'Never on `main` or `master`.' "$path" \
    || { echo "$path §Pre-commit branch assertion missing rule-1 'Never on \`main\` or \`master\`.' pin"; return 1; }
  grep -qF 'Spec is authoritative.' "$path" \
    || { echo "$path §Pre-commit branch assertion missing rule-2 'Spec is authoritative.' pin"; return 1; }
  grep -qF 'No spec → still no main.' "$path" \
    || { echo "$path §Pre-commit branch assertion missing rule-3 'No spec → still no main.' pin"; return 1; }
  # Load-bearing body pins — Post-merge bug flow cases 1/2/3 + enforcement.
  grep -qF 'Spec still IN_PROGRESS, merge was a PR-squash with the feature branch deleted' "$path" \
    || { echo "$path §Post-merge bug flow missing case-1 opener 'Spec still IN_PROGRESS, merge was a PR-squash with the feature branch deleted' pin"; return 1; }
  grep -qF '**Spec is SHIPPED**' "$path" \
    || { echo "$path §Post-merge bug flow missing case-2 '**Spec is SHIPPED**' pin"; return 1; }
  grep -qF '**Spec is VERIFIED**' "$path" \
    || { echo "$path §Post-merge bug flow missing case-3 '**Spec is VERIFIED**' pin"; return 1; }
  grep -qF 'The checker enforces this:' "$path" \
    || { echo "$path §Post-merge bug flow missing final enforcement sentence 'The checker enforces this:' pin"; return 1; }
  echo "$path has canonical §Git Workflow (heading + Pre-commit assertion + Post-merge bug flow + body pins)"
}

check_feature_skill_git_references_canonical() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(awk '
    !in_s && $0 == "### Git conventions" { in_s = 1; next }
    in_s && /^## / { exit }
    in_s && /^### / { exit }
    in_s { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path missing '### Git conventions' section"; return 1; }
  printf '%s\n' "$section" | grep -qF 'skills/feature/references/developer-workflow.md' \
    || { echo "$path §Git conventions missing pointer 'skills/feature/references/developer-workflow.md'"; return 1; }
  printf '%s\n' "$section" | grep -qF '§Git Workflow' \
    || { echo "$path §Git conventions missing '§Git Workflow' pointer"; return 1; }
  printf '%s\n' "$section" | grep -qF 'small logical commits per step' \
    || { echo "$path §Git conventions missing 'small logical commits per step' phrase"; return 1; }
  printf '%s\n' "$section" | grep -qF 'no `Co-authored-by`' \
    || { echo "$path §Git conventions missing 'no \`Co-authored-by\`' phrase"; return 1; }
  printf '%s\n' "$section" | grep -qF 'no pushing' \
    || { echo "$path §Git conventions missing 'no pushing' phrase"; return 1; }
  printf '%s\n' "$section" | grep -qF 'The canonical section includes the load-bearing pre-commit branch assertion and post-merge bug flow.' \
    || { echo "$path §Git conventions missing byte-exact canonical-section sentence"; return 1; }
  # Negative — short reference only; reject any list-item bullet (prevents
  # hybrid reintroduction where canonical paragraph stays but stale bullets
  # are appended).
  if printf '%s\n' "$section" | grep -qE '^- '; then
    echo "$path §Git conventions contains bullet lines ('^- '); must be a short reference paragraph only"
    return 1
  fi
  echo "$path §Git conventions has canonical short reference to developer-workflow.md §Git Workflow (no bullets)"
}

check_overview_git_references_canonical() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(awk '
    !in_s && $0 == "## Git conventions for developers" { in_s = 1; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path missing '## Git conventions for developers' section"; return 1; }
  printf '%s\n' "$section" | grep -qF 'skills/feature/references/developer-workflow.md' \
    || { echo "$path §Git conventions for developers missing pointer 'skills/feature/references/developer-workflow.md'"; return 1; }
  printf '%s\n' "$section" | grep -qF '§Git Workflow' \
    || { echo "$path §Git conventions for developers missing '§Git Workflow' pointer"; return 1; }
  printf '%s\n' "$section" | grep -qF 'master` or `main`' \
    || { echo "$path §Git conventions for developers missing 'master\` or \`main\`' canonical detection"; return 1; }
  printf '%s\n' "$section" | grep -qF 'prefer master if both exist' \
    || { echo "$path §Git conventions for developers missing 'prefer master if both exist' clarifier"; return 1; }
  printf '%s\n' "$section" | grep -qF 'small logical commits' \
    || { echo "$path §Git conventions for developers missing 'small logical commits' phrase"; return 1; }
  printf '%s\n' "$section" | grep -qF 'no `Co-authored-by`' \
    || { echo "$path §Git conventions for developers missing 'no \`Co-authored-by\`' phrase"; return 1; }
  printf '%s\n' "$section" | grep -qF 'push/PR by user' \
    || { echo "$path §Git conventions for developers missing 'push/PR by user' phrase"; return 1; }
  # Negative — reject stale master-only drift.
  if printf '%s\n' "$section" | grep -qF 'Base branch is `master` unless spec says otherwise'; then
    echo "$path §Git conventions for developers still contains stale 'Base branch is \`master\` unless spec says otherwise' drift"
    return 1
  fi
  # Negative — short reference only; reject any list-item bullet (prevents
  # hybrid reintroduction where canonical sentence stays but stale bullets
  # are appended).
  if printf '%s\n' "$section" | grep -qE '^- '; then
    echo "$path §Git conventions for developers contains bullet lines ('^- '); must be a short reference paragraph only"
    return 1
  fi
  echo "$path §Git conventions for developers has canonical short reference to developer-workflow.md §Git Workflow (master-or-main, no drift, no bullets)"
}
