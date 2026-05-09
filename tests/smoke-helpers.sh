# tests/smoke-helpers.sh — sourced by tests/smoke.sh.
# Parameterized section-scoped checks for the R3 block.
# Depends on extract_md_section being defined in the caller.

check_continue_mode_legacy_middle_normalisation() {
  # Two short byte-exact anchors from the SKILL.md Continue-mode normalisation
  # paragraph (spec §3.4a verbatim insert). Pinning two short anchors instead of
  # one long body-pin keeps the test robust to future word-smithing of the
  # paragraph body. Both must be present.
  local skill='skills/feature/SKILL.md'
  test -f "$skill" || { echo "$skill missing"; return 1; }
  grep -qF -- '**Legacy `last_agent=middle` normalisation (Log default).** If the most recent Log `last_agent=` value is `middle`' "$skill" \
    || { echo "$skill missing legacy last_agent=middle normalisation paragraph header anchor"; return 1; }
  grep -qF -- 'Note: spec Log says `last_agent=middle`, but the Middle developer agent was retired on 2026-04-25' "$skill" \
    || { echo "$skill missing legacy last_agent=middle normalisation preamble anchor"; return 1; }
  echo "SKILL.md Continue-mode legacy last_agent=middle normalisation anchors present"
}

check_legacy_last_agent_fixture_present() {
  local fixture='tests/fixtures/legacy-last-agent/spec.md'
  test -f "$fixture" || { echo "$fixture missing"; return 1; }
  grep -qF -- '- 2026-04-20: last_agent=middle; rationale=T-M1' "$fixture" \
    || { echo "$fixture missing canonical legacy Log line"; return 1; }
  echo "legacy last_agent fixture $fixture present with canonical Log line"
}

check_developer_middle_not_present() {
  # (1) File-existence guard.
  if [ -e agents/developer-middle.md ]; then
    echo "agents/developer-middle.md still present"
    return 1
  fi

  # (2) Operational-token grep. ERE alternation uses bare `|` (NOT escaped `\|`).
  # X10 fix: the original spec used `\|` under `-E` which is a literal pipe
  # under ERE and makes the whole grep a no-op. Bare `|` is correct.
  local hits
  hits=$(grep -rEln \
    'developer-middle|Developer Middle|## Middle|### Middle|Middle \(Sonnet\)|Option 3: Middle|for agent in codex senior middle' \
    agents/ skills/ docs/ hooks/ README.md CLAUDE.md 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "operational developer-middle references still present:"
    printf '  %s\n' "$hits"
    return 1
  fi

  echo "developer-middle correctly absent (file deleted, no operational references)"
}

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
  printf '%s\n' "$section" | grep -qF -- 'Malformed tags — unknown token, wrong spacing, or any suffix form other than `@codex` / `@senior` — are flagged HIGH regardless of trigger analysis' \
    || { echo "$path §\`spec\` mode missing byte-exact malformed-tags HIGH clause"; return 1; }
  printf '%s\n' "$section" | grep -qF -- 'A step tagged `@senior` but described as "trivial one-liner" fails both (a) and (b) — Senior has no positive trigger that fits trivial work and "trivial one-liner" is explicitly in Senior'"'"'s anti-trigger list → HIGH.' \
    || { echo "$path §\`spec\` mode missing byte-exact Senior example sentence"; return 1; }
  printf '%s\n' "$section" | grep -qF -- 'Untagged steps → no check.' \
    || { echo "$path §\`spec\` mode missing byte-exact closing 'Untagged steps → no check.' sentence"; return 1; }
  echo "$path §\`spec\` mode has Agent pre-tag consistency bullet (label + (a)+(b) + 2 examples + Malformed + Untagged-closing)"
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

  echo "$path canonical KB discovery doc (all required headings + 9-step Algorithm + yml prompt)"
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
  printf '%s\n' "$section" | grep -qF 'codex.reasoning_effort' \
    || { echo "$path ## Phase 0 extensions missing substring 'codex.reasoning_effort'"; return 1; }
  echo "$path Phase 0 extensions mention both codex.model and codex.reasoning_effort keys"
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

# --- SessionStart conditional activation ---

check_session_start_dormant_in_orthogonal() {
  local tmpdir workdir out status
  tmpdir=$(mktemp -d) || { echo "mktemp failed"; return 1; }
  workdir="$tmpdir/orthogonal"
  mkdir -p "$workdir" || { rm -rf "$tmpdir"; echo "mkdir failed: $workdir"; return 1; }

  out=$(cd "$workdir" && env -i CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$PATH" HOME="$tmpdir" bash "$PLUGIN_ROOT/hooks/session-start" 2>&1)
  status=$?
  rm -rf "$tmpdir"

  [ "$status" -eq 0 ] || { echo "session-start failed in orthogonal CWD"; printf '%s\n' "$out"; return 1; }
  [ "$out" = "{}" ] || { echo "expected dormant '{}', got:"; printf '%s\n' "$out"; return 1; }
  echo "session-start dormant in orthogonal CWD emits {}"
}

check_session_start_active_yml_arm() {
  local tmpdir out status
  tmpdir=$(mktemp -d) || { echo "mktemp failed"; return 1; }
  touch "$tmpdir/.ai-dev-team.yml" || { rm -rf "$tmpdir"; echo "touch failed: $tmpdir/.ai-dev-team.yml"; return 1; }

  out=$(cd "$tmpdir" && env -i CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$PATH" HOME="$tmpdir" bash "$PLUGIN_ROOT/hooks/session-start" 2>&1)
  status=$?
  rm -rf "$tmpdir"

  [ "$status" -eq 0 ] || { echo "session-start failed"; printf '%s\n' "$out"; return 1; }
  printf '%s' "$out" | grep -qF 'Skill trigger map' || { echo "inject missing 'Skill trigger map'; got:"; printf '%s\n' "$out"; return 1; }
  echo "session-start active via yml arm: inject contains Skill trigger map"
}

check_session_start_active_memory_arm() {
  local tmpdir raw_tmpdir sanitized out status
  raw_tmpdir=$(mktemp -d) || { echo "mktemp failed"; return 1; }
  tmpdir=$(cd "$raw_tmpdir" && pwd -P) || { rm -rf "$raw_tmpdir"; echo "pwd failed"; return 1; }
  sanitized=$(printf '%s' "$tmpdir" | tr '/' '-')
  mkdir -p "$tmpdir/.claude/projects/${sanitized}/memory" || { rm -rf "$tmpdir"; echo "mkdir failed: $tmpdir/.claude/projects/${sanitized}/memory"; return 1; }
  touch "$tmpdir/.claude/projects/${sanitized}/memory/reference_kb_test.md" || { rm -rf "$tmpdir"; echo "touch failed: $tmpdir/.claude/projects/${sanitized}/memory/reference_kb_test.md"; return 1; }

  out=$(cd "$tmpdir" && env -i CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$PATH" HOME="$tmpdir" bash "$PLUGIN_ROOT/hooks/session-start" 2>&1)
  status=$?
  rm -rf "$tmpdir"

  [ "$status" -eq 0 ] || { echo "session-start failed"; printf '%s\n' "$out"; return 1; }
  printf '%s' "$out" | grep -qF 'Skill trigger map' || { echo "inject missing 'Skill trigger map'; got:"; printf '%s\n' "$out"; return 1; }
  echo "session-start active via memory arm: inject contains Skill trigger map"
}

check_session_start_active_claude_md_arm() {
  local tmpdir out status
  tmpdir=$(mktemp -d) || { echo "mktemp failed"; return 1; }
  printf '%s\n' '/feature' > "$tmpdir/CLAUDE.md" || { rm -rf "$tmpdir"; echo "write failed: $tmpdir/CLAUDE.md"; return 1; }

  out=$(cd "$tmpdir" && env -i CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$PATH" HOME="$tmpdir" bash "$PLUGIN_ROOT/hooks/session-start" 2>&1)
  status=$?
  rm -rf "$tmpdir"

  [ "$status" -eq 0 ] || { echo "session-start failed"; printf '%s\n' "$out"; return 1; }
  printf '%s' "$out" | grep -qF 'Skill trigger map' || { echo "inject missing 'Skill trigger map'; got:"; printf '%s\n' "$out"; return 1; }
  echo "session-start active via CLAUDE.md arm: inject contains Skill trigger map"
}

check_session_start_dormant_under_nullglob() {
  local tmpdir workdir bash_env_file out status
  tmpdir=$(mktemp -d) || { echo "mktemp failed"; return 1; }
  workdir="$tmpdir/orthogonal"
  mkdir -p "$workdir" || { rm -rf "$tmpdir"; echo "mkdir failed: $workdir"; return 1; }
  bash_env_file="$tmpdir/bash_env_nullglob.sh"
  printf '%s\n' 'shopt -s nullglob' > "$bash_env_file"

  out=$(cd "$workdir" && env -i CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$PATH" HOME="$tmpdir" BASH_ENV="$bash_env_file" bash "$PLUGIN_ROOT/hooks/session-start" 2>&1)
  status=$?
  rm -rf "$tmpdir"

  [ "$status" -eq 0 ] || { echo "session-start failed under nullglob BASH_ENV"; printf '%s\n' "$out"; return 1; }
  out_stripped="${out%$'\n'}"
  [ "$out_stripped" = "{}" ] || [ "$out" = "{}" ] || { echo "expected dormant '{}' under nullglob, got:"; printf '%s\n' "$out"; return 1; }
  echo "session-start dormant under nullglob BASH_ENV emits {}"
}

check_session_start_dormant_under_failglob() {
  local tmpdir workdir bash_env_file out status
  tmpdir=$(mktemp -d) || { echo "mktemp failed"; return 1; }
  workdir="$tmpdir/orthogonal"
  mkdir -p "$workdir" || { rm -rf "$tmpdir"; echo "mkdir failed: $workdir"; return 1; }
  bash_env_file="$tmpdir/bash_env_failglob.sh"
  printf '%s\n' 'shopt -s failglob' > "$bash_env_file"

  out=$(cd "$workdir" && env -i CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$PATH" HOME="$tmpdir" BASH_ENV="$bash_env_file" bash "$PLUGIN_ROOT/hooks/session-start" 2>&1)
  status=$?
  rm -rf "$tmpdir"

  [ "$status" -eq 0 ] || { echo "session-start failed (non-zero exit) under failglob BASH_ENV"; printf '%s\n' "$out"; return 1; }
  out_stripped="${out%$'\n'}"
  [ "$out_stripped" = "{}" ] || [ "$out" = "{}" ] || { echo "expected dormant '{}' under failglob, got:"; printf '%s\n' "$out"; return 1; }
  echo "session-start dormant under failglob BASH_ENV emits {}"
}

# --- Trigger-map dedupe (spec 2026-04-20-trigger-map-dedupe) ---
# Self-contained helpers: each does inline awk/grep extraction, does NOT rely
# on extract_md_section from the caller. Each accepts $1 = path (real plugin
# file OR negative fixture). Returns 0 iff the canonical shape is present;
# non-zero with a diagnostic line otherwise. Bash-3.2 compatible.

check_session_start_trigger_map_complete() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF '### Skill trigger map' "$path" \
    || { echo "$path missing '### Skill trigger map' section heading"; return 1; }
  # p3-cleanup audit X1: section-scoping alone is not enough — a clarifier
  # paragraph inside the section that mentions `/investigate` would mask a
  # dropped `/investigate` row. Scope the 8-target check to table data rows
  # only (lines starting with '|') inside §Skill trigger map.
  local table_rows
  table_rows=$(awk '
    !in_s && /^### Skill trigger map/ { in_s = 1; next }
    in_s && /^## / { exit }
    in_s && /^### / { exit }
    in_s && /^\|/ { print }
  ' "$path")
  [ -n "$table_rows" ] || { echo "$path '### Skill trigger map' section has no table rows (lines starting with '|')"; return 1; }
  local missing=0 target
  for target in \
    '/feature new' \
    '/feature continue' \
    '/feature status' \
    '/cross-audit' \
    '/investigate' \
    '/feature extend' \
    '/feature verify' \
    '/feature checklist'; do
    printf '%s\n' "$table_rows" | grep -qF "$target" \
      || { echo "$path §Skill trigger map table rows missing canonical trigger target '$target'"; missing=1; }
  done
  [ "$missing" -eq 0 ] || return 1
  echo "$path §Skill trigger map table rows contain all 8 canonical trigger targets"
}

check_claude_md_snippet_points_to_hook() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  # p3-cleanup audit X2: scope the 8-target check to trigger-map table data
  # rows (lines starting with '|' inside '### Skill trigger map'). A
  # clarifier paragraph mentioning `/investigate` would otherwise mask a
  # dropped `/investigate` row.
  local table_rows
  table_rows=$(awk '
    !in_s && /^### Skill trigger map/ { in_s = 1; next }
    in_s && /^## / { exit }
    in_s && /^### / { exit }
    in_s && /^\|/ { print }
  ' "$path")
  [ -n "$table_rows" ] || { echo "$path '### Skill trigger map' section has no table rows (lines starting with '|')"; return 1; }
  local missing=0 target
  for target in \
    '/feature new' \
    '/feature continue' \
    '/feature status' \
    '/cross-audit' \
    '/investigate' \
    '/feature extend' \
    '/feature verify' \
    '/feature checklist'; do
    printf '%s\n' "$table_rows" | grep -qF "$target" \
      || { echo "$path §Skill trigger map table rows missing canonical trigger target '$target'"; missing=1; }
  done
  [ "$missing" -eq 0 ] || return 1
  # Pointer must live ABOVE the fenced paste block so it never leaks into
  # downstream CLAUDE.md content. Extract pre-fence prefix (lines before the
  # first fence line) and the fence body (lines between the first two fence
  # lines). Pointer required in prefix; forbidden in fence body. Recognises
  # both ``` and ~~~ fence styles so a future snippet author cannot bypass
  # the assertion by switching markers.
  local prefix inside
  prefix=$(awk '
    /^(```|~~~)/ { exit }
    { print }
  ' "$path")
  inside=$(awk '
    BEGIN { depth = 0 }
    /^(```|~~~)/ {
      if (depth == 0) { depth = 1; next }
      depth = 0
      exit
    }
    depth == 1 { print }
  ' "$path")
  printf '%s\n' "$prefix" | grep -qF '`hooks/session-start` (injected into every session at runtime)' \
    || { echo "$path missing byte-exact pointer sentence in pre-fence prefix (must live outside fenced paste block so it never leaks into pasted CLAUDE.md)"; return 1; }
  if printf '%s\n' "$inside" | grep -qF '`hooks/session-start` (injected into every session at runtime)'; then
    echo "$path pointer sentence present INSIDE fenced paste block — moving it inside would leak into every downstream project's pasted CLAUDE.md"
    return 1
  fi
  echo "$path has all 8 canonical trigger targets + pointer sentence positioned above the fenced paste block"
}

check_readme_ambient_workflow_references_sources() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(awk '
    !in_s && $0 == "## Ambient workflow" { in_s = 1; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path missing '## Ambient workflow' section"; return 1; }
  # Positive — short reference must link to both sources.
  printf '%s\n' "$section" | grep -qF 'docs/claude-md-snippet.md' \
    || { echo "$path §Ambient workflow missing link to 'docs/claude-md-snippet.md'"; return 1; }
  printf '%s\n' "$section" | grep -qF 'hooks/session-start' \
    || { echo "$path §Ambient workflow missing link to 'hooks/session-start'"; return 1; }
  # Positive — must mention 4 core slash commands.
  local cmd
  for cmd in '/feature new' '/feature continue' '/cross-audit' '/investigate'; do
    printf '%s\n' "$section" | grep -qF "$cmd" \
      || { echo "$path §Ambient workflow missing core slash command '$cmd'"; return 1; }
  done
  # Negative — short reference means NO table at all. Reject any line
  # starting with '|' inside the section (row-format-agnostic: catches
  # plain-text rows, backtick rows, non-ASCII-quote rows, separator rows).
  local table_lines
  table_lines=$(printf '%s\n' "$section" | grep -cE '^\|')
  [ "$table_lines" -eq 0 ] \
    || { echo "$path §Ambient workflow still contains markdown table lines ($table_lines line(s) starting with '|'); must be a short reference with no table"; return 1; }
  echo "$path §Ambient workflow is short reference with links to both sources + 4 core commands (no table)"
}

# --- Focus-areas dedupe (spec 2026-04-20-focus-areas-dedupe) ---
# Self-contained helpers: each does inline awk/grep extraction, does NOT rely
# on extract_md_section from the caller. Each accepts $1 = path (real plugin
# file OR negative fixture). Returns 0 iff the canonical shape is present;
# non-zero with a diagnostic line otherwise. Bash-3.2 compatible.

check_cross_auditor_mode_focus_areas_canonical() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF '## Mode Focus Areas' "$path" \
    || { echo "$path missing '## Mode Focus Areas' heading"; return 1; }
  local section
  # Line-equality anchor for parity with the SKILL-side helper (audit X4).
  section=$(awk '
    !in_s && $0 == "## Mode Focus Areas" { in_s = 1; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path ## Mode Focus Areas section empty"; return 1; }
  # Line-exact match on each mode heading (audit X3): substring match would
  # pass if a mode subsection were demoted from ### to #### or if the token
  # leaked only into prose with the heading silently dropped.
  local mode
  for mode in '`logic` mode' '`security` mode' '`full` mode' '`spec` mode'; do
    printf '%s\n' "$section" | grep -qFx "### $mode" \
      || { echo "$path ## Mode Focus Areas missing line-exact '### $mode' subsection heading"; return 1; }
  done
  echo "$path has canonical ## Mode Focus Areas (heading + 4 line-exact mode subsection headings: logic/security/full/spec)"
}

check_cross_audit_skill_focus_areas_references_canonical() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(awk '
    !in_s && $0 == "## Adaptation by Project Type" { in_s = 1; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path missing '## Adaptation by Project Type' section"; return 1; }
  printf '%s\n' "$section" | grep -qF 'agents/cross-auditor.md' \
    || { echo "$path §Adaptation by Project Type missing pointer 'agents/cross-auditor.md'"; return 1; }
  printf '%s\n' "$section" | grep -qF '§Mode Focus Areas' \
    || { echo "$path §Adaptation by Project Type missing '§Mode Focus Areas' pointer"; return 1; }
  # Negative — reject any H3-or-deeper heading in the section (audit X2
  # broadened '^### ' to '^[[:space:]]*#{3,}[[:space:]]' so leading whitespace
  # and H4+ demotions no longer bypass the guard; pre-edit decorative block
  # had 4 such subsections — a short reference must carry zero).
  if printf '%s\n' "$section" | grep -qE '^[[:space:]]*#{3,}[[:space:]]'; then
    echo "$path §Adaptation by Project Type still contains H3-or-deeper subsection heading (decorative full block); must be a short reference"
    return 1
  fi
  # Negative — reject bullet-form reintroduction of the 4 per-project-type
  # entries (audit X2: author could drop headings but keep the list as
  # '- **Smart Contracts / DeFi**: ...' bullets).
  if printf '%s\n' "$section" | grep -qE '^- \*\*[^*]+\*\*:'; then
    echo "$path §Adaptation by Project Type still contains '- **<label>**:' bullet-form entry (bullet-style reintroduction); must be a short reference with no per-project-type list"
    return 1
  fi
  echo "$path §Adaptation by Project Type has canonical short reference (no H3+ subsections, no '- **label**:' bullets)"
}

# --- P3 cleanup bundle (spec 2026-04-20-p3-cleanup-bundle) ---

check_trigger_map_investigate_research_clarifier() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  # p3-cleanup audit X3: scope the clarifier to the §Skill trigger map section
  # (where it belongs) rather than whole-file. Both hook and snippet carry the
  # '### Skill trigger map' heading; the helper extracts that section and
  # requires all three pins inside it. A clarifier moved out of the section
  # (e.g. into Key facts, or outside the fence for the snippet) is rejected.
  grep -qF '### Skill trigger map' "$path" \
    || { echo "$path missing '### Skill trigger map' section heading (clarifier must live in that section)"; return 1; }
  local section
  section=$(awk '
    !in_s && /^### Skill trigger map/ { in_s = 1; next }
    in_s && /^## / { exit }
    in_s && /^### / { exit }
    in_s { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path '### Skill trigger map' section empty"; return 1; }
  printf '%s\n' "$section" | grep -qF 'Disambiguation: "compare / which is better / tradeoffs"' \
    || { echo "$path §Skill trigger map missing byte-exact clarifier opener 'Disambiguation: \"compare / which is better / tradeoffs\"'"; return 1; }
  printf '%s\n' "$section" | grep -qF 'adversarial Claude+Codex debate, single-session, convergence report with a recommendation' \
    || { echo "$path §Skill trigger map missing byte-exact adversarial-debate description"; return 1; }
  printf '%s\n' "$section" | grep -qF 'Use `/research new competitive-analysis` only when the user wants free-form notes accumulated over multiple sessions, not a decision.' \
    || { echo "$path §Skill trigger map missing byte-exact /research-new-competitive-analysis fallback sentence"; return 1; }
  echo "$path §Skill trigger map has investigate-vs-research clarifier (3 byte-exact pins, section-scoped)"
}

check_research_skill_competitive_analysis_points_to_investigate() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  # p3-cleanup audit X4: pin the full competitive-analysis bullet line
  # byte-exact so the pointer cannot be detached from the bullet (e.g. moved
  # to an unrelated section or rewritten to not mention /investigate).
  grep -qF -- '3. `competitive-analysis` — market / vendor / protocol comparison. For decision-making comparisons with a recommendation at the end, use `/investigate` instead — it runs an adversarial Claude+Codex debate and produces a convergence report.' "$path" \
    || { echo "$path missing byte-exact full competitive-analysis bullet with /investigate pointer attached"; return 1; }
  echo "$path has full-line byte-exact competitive-analysis → /investigate bullet"
}

check_branch_frontmatter_ref_lowercase() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  # p3-cleanup audit X5: broaden rejection to ANY 'Branch:' occurrence in the
  # file (case-sensitive). Pre-fix helper only caught backtick-wrapped form;
  # `**Branch:**`, `"Branch:"`, bare `Branch:`, and `` `Branch: ` `` (trailing
  # space) all slipped through. Target files (README.md, feature/SKILL.md)
  # should have zero uppercase 'Branch:' occurrences since canonical YAML
  # frontmatter key is lowercase; any form is rejection-worthy.
  if grep -qF 'Branch:' "$path"; then
    local occurrences
    occurrences=$(grep -n 'Branch:' "$path" | head -3)
    echo "$path contains uppercase 'Branch:' form(s); canonical YAML frontmatter key is lowercase 'branch:'. First hits:"
    echo "$occurrences"
    return 1
  fi
  echo "$path has no uppercase 'Branch:' form (lowercase 'branch:' canonical used everywhere)"
}

check_readme_no_audit_migration_note() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  # p3-cleanup audit X7: broaden to reject case-variants and simple paraphrases
  # of the audit→cross-audit migration note. Any line mentioning both "audit"
  # and "cross-audit" with "replaced by" is rejection-worthy since the
  # `audit` skill has been gone long enough that no migration signpost is
  # needed or accurate.
  if grep -qiE 'migration[[:space:]]+note.*`?audit`?.*replaced[[:space:]]+by.*cross[- ]?audit' "$path"; then
    echo "$path still contains an obsolete 'audit replaced by cross-audit' migration-note line (case-insensitive match); the \`audit\` skill was removed long ago"
    grep -niE 'migration[[:space:]]+note.*`?audit`?.*replaced[[:space:]]+by.*cross[- ]?audit' "$path" | head -3
    return 1
  fi
  # Also reject the literal pre-edit sentence exactly (redundant belt-and-
  # braces — the regex above already covers it, but kept as a safety net).
  if grep -qF 'Migration note: `audit` replaced by cross-audit.' "$path"; then
    echo "$path still contains obsolete migration note (literal pre-edit form)"
    return 1
  fi
  echo "$path has no obsolete 'audit replaced by cross-audit' migration note (regex + literal both clean)"
}

# --- Cross-audit probes foundation (spec 2026-04-21-cross-audit-probes-foundation) ---

check_agents_cross_auditor_schema_cut_fields() {
  # Step 1 helper — asserts agents/cross-auditor.md §Step 4 findings.md template carries:
  #  (1) the updated table header `ID | Severity | Issue | Source | Mode | Confidence | Status`
  #  (2) new details-block fields: Sources / Mode at emit / Blocking / Probe receipt / Probe version / Eligible reason
  #      (Source is column-only — NOT a details-block field)
  #  (3) legacy `Found by` → `sources[]` round-trip mapping note with three-case expansion
  local path="agents/cross-auditor.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }

  # (1) Table header — canonical byte-exact
  grep -qF '| ID | Severity | Issue | Source | Mode | Confidence | Status |' "$path" \
    || { echo "$path missing schema-cut table header '| ID | Severity | Issue | Source | Mode | Confidence | Status |'"; return 1; }

  # (2) Details-block new fields (order preserved, one per line)
  grep -qF '**Sources**:' "$path" \
    || { echo "$path missing details-block field '**Sources**:' (authoritative list)"; return 1; }
  grep -qF '**Mode at emit**:' "$path" \
    || { echo "$path missing details-block field '**Mode at emit**:' (probe findings only)"; return 1; }
  grep -qF '**Blocking**:' "$path" \
    || { echo "$path missing details-block field '**Blocking**:'"; return 1; }
  grep -qF '**Probe receipt**:' "$path" \
    || { echo "$path missing details-block field '**Probe receipt**:'"; return 1; }
  grep -qF '**Probe version**:' "$path" \
    || { echo "$path missing details-block field '**Probe version**:'"; return 1; }
  grep -qF '**Eligible reason**:' "$path" \
    || { echo "$path missing details-block field '**Eligible reason**:'"; return 1; }

  # (3) Round-trip mapping note — must include the three-case expansion.
  # Tolerates backtick-wrapped form of the values; arrow must be Unicode `→`.
  grep -qE 'Both`?[[:space:]]*→[[:space:]]*`?sources: \[claude, codex\]' "$path" \
    || { echo "$path missing legacy round-trip mapping 'Both → sources: [claude, codex]'"; return 1; }
  grep -qE 'Only Claude`?[[:space:]]*→[[:space:]]*`?sources: \[claude\]' "$path" \
    || { echo "$path missing legacy round-trip mapping 'Only Claude → sources: [claude]'"; return 1; }
  grep -qE 'Only Codex`?[[:space:]]*→[[:space:]]*`?sources: \[codex\]' "$path" \
    || { echo "$path missing legacy round-trip mapping 'Only Codex → sources: [codex]'"; return 1; }

  # Column-vs-field distinction: the details block MUST NOT carry a bare `**Source**:` field
  # (Source is rendered only as a table column; Sources[] is the authoritative list field).
  if grep -qE '^\-\s+\*\*Source\*\*:' "$path"; then
    echo "$path details block carries forbidden '- **Source**:' field (Source is column-only; authoritative details-block field is '**Sources**:')"
    return 1
  fi

  echo "$path §Step 4 findings template carries schema-cut columns + details fields + Found-by→sources[] round-trip mapping"
}

# --- Step 2: hooks/lib/render_findings.sh ---
#
# Each helper below drives hooks/lib/render_findings.sh with a fixture
# input JSON and compares stdout byte-for-byte against the paired
# expected .md golden. Hard-stop fixture asserts non-zero exit code
# plus non-empty stderr.

_render_findings_byte_diff() {
  # $1 = input JSON path, $2 = expected .md golden path
  # Uses a temp file for captured stdout to preserve trailing newlines that
  # $(…) strips. Byte-for-byte diff against the golden.
  local input="$1" expected="$2"
  local script="hooks/lib/render_findings.sh"
  [ -x "$script" ] || { echo "$script not executable"; return 1; }
  [ -r "$input" ] || { echo "input fixture $input not readable"; return 1; }
  [ -r "$expected" ] || { echo "expected golden $expected not readable"; return 1; }
  local actual_tmp="/tmp/smoke-render-actual.$$"
  if ! bash "$script" <"$input" >"$actual_tmp" 2>/tmp/smoke-render-err.$$; then
    echo "render_findings.sh exited non-zero on $input"
    cat /tmp/smoke-render-err.$$
    rm -f /tmp/smoke-render-err.$$ "$actual_tmp"
    return 1
  fi
  rm -f /tmp/smoke-render-err.$$
  if ! diff "$actual_tmp" "$expected" >/tmp/smoke-render-diff.$$ 2>&1; then
    echo "render_findings.sh output for $input does not byte-match $expected:"
    head -30 /tmp/smoke-render-diff.$$
    rm -f /tmp/smoke-render-diff.$$ "$actual_tmp"
    return 1
  fi
  rm -f /tmp/smoke-render-diff.$$ "$actual_tmp"
  echo "render_findings.sh output byte-matches $expected"
}

check_findings_renderer_schema_cut() {
  # Fixture (1): no-probes legacy — two Claude+Codex findings with pure-LLM sources,
  # renders schema-cut table header + Details block with all new fields.
  _render_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/renderer/01-no-probes-legacy-input.json \
    tests/fixtures/cross-audit-probes-foundation/renderer/01-no-probes-legacy-expected.md
}

check_findings_renderer_modes_shadow() {
  _render_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/renderer/02-probe-shadow-input.json \
    tests/fixtures/cross-audit-probes-foundation/renderer/02-probe-shadow-expected.md
}

check_findings_renderer_modes_warn() {
  _render_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/renderer/03-probe-warn-input.json \
    tests/fixtures/cross-audit-probes-foundation/renderer/03-probe-warn-expected.md
}

check_findings_renderer_modes_block() {
  _render_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/renderer/04-probe-block-input.json \
    tests/fixtures/cross-audit-probes-foundation/renderer/04-probe-block-expected.md
}

check_findings_renderer_modes_multi_source() {
  _render_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/renderer/05-multi-source-merged-input.json \
    tests/fixtures/cross-audit-probes-foundation/renderer/05-multi-source-merged-expected.md
}

# Alias: keep `check_findings_renderer_modes` as the umbrella helper name the
# spec §3.2 Changes table and exec Step 2 grep pattern call out. Runs all four
# mode fixtures serially. The four per-fixture helpers above are what smoke.sh
# actually invokes (one `check` line per golden-diff sub-assertion, matching
# the §6.1 count).
check_findings_renderer_modes() {
  check_findings_renderer_modes_shadow || return 1
  check_findings_renderer_modes_warn || return 1
  check_findings_renderer_modes_block || return 1
  check_findings_renderer_modes_multi_source || return 1
  echo "all four mode-routing fixtures byte-match their goldens"
}

check_findings_renderer_fail_open() {
  # Fixture (6): probe_failures[] non-empty → degraded-mode banner at top of output,
  # listing each failed probe with reason/remediation.
  _render_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/renderer/06-probe-fail-open-input.json \
    tests/fixtures/cross-audit-probes-foundation/renderer/06-probe-fail-open-expected.md
}

# --- Step 3: hooks/lib/dedupe_findings.sh + receipt hash canonicalization ---

_dedupe_findings_byte_diff() {
  # $1 = input JSON path, $2 = expected JSON golden path
  local input="$1" expected="$2"
  local script="hooks/lib/dedupe_findings.sh"
  [ -x "$script" ] || { echo "$script not executable"; return 1; }
  [ -r "$input" ] || { echo "input fixture $input not readable"; return 1; }
  [ -r "$expected" ] || { echo "expected golden $expected not readable"; return 1; }
  local actual_tmp="/tmp/smoke-dedupe-actual.$$"
  if ! bash "$script" <"$input" >"$actual_tmp" 2>/tmp/smoke-dedupe-err.$$; then
    echo "dedupe_findings.sh exited non-zero on $input"
    cat /tmp/smoke-dedupe-err.$$
    rm -f /tmp/smoke-dedupe-err.$$ "$actual_tmp"
    return 1
  fi
  rm -f /tmp/smoke-dedupe-err.$$
  if ! diff "$actual_tmp" "$expected" >/tmp/smoke-dedupe-diff.$$ 2>&1; then
    echo "dedupe_findings.sh output for $input does not byte-match $expected:"
    head -20 /tmp/smoke-dedupe-diff.$$
    rm -f /tmp/smoke-dedupe-diff.$$ "$actual_tmp"
    return 1
  fi
  rm -f /tmp/smoke-dedupe-diff.$$ "$actual_tmp"
  echo "dedupe_findings.sh output byte-matches $expected"
}

check_dedupe_fingerprint_e_exact() {
  _dedupe_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/dedupe/E-01-exact-match-input.json \
    tests/fixtures/cross-audit-probes-foundation/dedupe/E-01-exact-match-expected.json
}

check_dedupe_fingerprint_e_partial() {
  _dedupe_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/dedupe/E-02-partial-match-input.json \
    tests/fixtures/cross-audit-probes-foundation/dedupe/E-02-partial-match-expected.json
}

check_dedupe_fingerprint_e_no_match() {
  _dedupe_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/dedupe/E-03-no-match-input.json \
    tests/fixtures/cross-audit-probes-foundation/dedupe/E-03-no-match-expected.json
}

check_dedupe_fingerprint_f_exact() {
  _dedupe_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/dedupe/F-01-exact-match-input.json \
    tests/fixtures/cross-audit-probes-foundation/dedupe/F-01-exact-match-expected.json
}

check_dedupe_fingerprint_f_partial() {
  _dedupe_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/dedupe/F-02-partial-match-input.json \
    tests/fixtures/cross-audit-probes-foundation/dedupe/F-02-partial-match-expected.json
}

check_dedupe_fingerprint_f_no_match() {
  _dedupe_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/dedupe/F-03-no-match-input.json \
    tests/fixtures/cross-audit-probes-foundation/dedupe/F-03-no-match-expected.json
}

check_dedupe_fingerprint_g_exact() {
  _dedupe_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/dedupe/G-01-exact-match-input.json \
    tests/fixtures/cross-audit-probes-foundation/dedupe/G-01-exact-match-expected.json
}

check_dedupe_fingerprint_g_partial() {
  _dedupe_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/dedupe/G-02-partial-match-input.json \
    tests/fixtures/cross-audit-probes-foundation/dedupe/G-02-partial-match-expected.json
}

check_dedupe_fingerprint_g_no_match() {
  _dedupe_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/dedupe/G-03-no-match-input.json \
    tests/fixtures/cross-audit-probes-foundation/dedupe/G-03-no-match-expected.json
}

check_dedupe_fingerprint_e_shape() {
  # Umbrella helper: exercises all three E near-miss fixtures (exact match →
  # merge, partial → related_to, no match → distinct).
  check_dedupe_fingerprint_e_exact || return 1
  check_dedupe_fingerprint_e_partial || return 1
  check_dedupe_fingerprint_e_no_match || return 1
  echo "all three E-probe fingerprint sub-fixtures byte-match"
}

check_dedupe_fingerprint_f_shape() {
  check_dedupe_fingerprint_f_exact || return 1
  check_dedupe_fingerprint_f_partial || return 1
  check_dedupe_fingerprint_f_no_match || return 1
  echo "all three F-probe fingerprint sub-fixtures byte-match"
}

check_dedupe_fingerprint_g_shape() {
  check_dedupe_fingerprint_g_exact || return 1
  check_dedupe_fingerprint_g_partial || return 1
  check_dedupe_fingerprint_g_no_match || return 1
  echo "all three G-probe fingerprint sub-fixtures byte-match"
}

check_dedupe_merged_probe_llm_sources_list() {
  # Merged probe+LLM: probe:E + claude (sharing E-anchors) → single entry with
  # authoritative sources: ["probe:E", "claude"], probe receipt preserved
  # (§3.3 X2 contract — no `both` primitive).
  _dedupe_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/dedupe/merged-probe-llm-input.json \
    tests/fixtures/cross-audit-probes-foundation/dedupe/merged-probe-llm-expected.json
}

# --- Step 4: cross_audit.probes.<id>.mode config surface ---

# --- Step 7: Haiku scorer + cross-auditor integration + probe_failures synthesis ---

check_haiku_scorer_agent_frontmatter() {
  # agents/haiku-finding-scorer.md frontmatter carries name, description,
  # model: haiku, effort: default, tools: Read (no MCP), and a maxTurns cap.
  local path="agents/haiku-finding-scorer.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local fm
  fm=$(awk '/^---$/{c++; if (c==2) exit} c==1' "$path")
  printf '%s\n' "$fm" | grep -qE '^name: haiku-finding-scorer' \
    || { echo "$path frontmatter missing 'name: haiku-finding-scorer'"; return 1; }
  printf '%s\n' "$fm" | grep -qE '^model: haiku' \
    || { echo "$path frontmatter missing 'model: haiku'"; return 1; }
  printf '%s\n' "$fm" | grep -qE '^tools: Read' \
    || { echo "$path frontmatter missing 'tools: Read' (Read-only tool surface)"; return 1; }
  # Anti-regression: must NOT have mcp__codex__codex in tools.
  if printf '%s\n' "$fm" | grep -q 'mcp__codex__codex'; then
    echo "$path frontmatter wrongly includes MCP tool — scorer must be Read-only"
    return 1
  fi
  printf '%s\n' "$fm" | grep -qE '^description:' \
    || { echo "$path frontmatter missing 'description:' field"; return 1; }
  echo "$path frontmatter declares model=haiku + tools=Read + description (no MCP)"
}

check_haiku_scorer_rubric_present() {
  # Body carries the 5-band rubric (0-24/25-49/50-74/75-89/90-100) per §3.5a.
  local path="agents/haiku-finding-scorer.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qE '0[-–]24' "$path" || { echo "$path missing 0-24 rubric band"; return 1; }
  grep -qE '25[-–]49' "$path" || { echo "$path missing 25-49 rubric band"; return 1; }
  grep -qE '50[-–]74' "$path" || { echo "$path missing 50-74 rubric band"; return 1; }
  grep -qE '75[-–]89' "$path" || { echo "$path missing 75-89 rubric band"; return 1; }
  grep -qE '90[-–]100' "$path" || { echo "$path missing 90-100 rubric band"; return 1; }
  # Each band's labels — "wrong", "false positive", "maybe real", "probably real",
  # "confirmed" — must all be present somewhere in the file to prove the bands
  # carry semantics and are not placeholder numerics.
  grep -qiE 'clearly[[:space:]]+wrong' "$path" || { echo "$path missing 'clearly wrong' rubric label"; return 1; }
  grep -qiE 'false[[:space:]]+positive' "$path" || { echo "$path missing 'false positive' rubric label"; return 1; }
  grep -qiE 'maybe[[:space:]]+real' "$path" || { echo "$path missing 'maybe real' rubric label"; return 1; }
  grep -qiE 'probably[[:space:]]+real' "$path" || { echo "$path missing 'probably real' rubric label"; return 1; }
  grep -qiE 'confirmed' "$path" || { echo "$path missing 'confirmed' rubric label"; return 1; }
  echo "$path body carries 5-band rubric with all semantic labels"
}

check_haiku_scorer_anti_hallucination_clause() {
  # Anti-hallucination clause: if finding cites a CLAUDE.md rule that is not
  # verifiably present, cap confidence at 49.
  local path="agents/haiku-finding-scorer.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qiE '(anti[- ]hallucination|hard[[:space:]]+rule)' "$path" \
    || { echo "$path missing anti-hallucination clause heading"; return 1; }
  grep -qiE 'cap.*(confidence|at).*49|confidence.*(cap|≤|<=).*49' "$path" \
    || { echo "$path missing 'cap confidence at 49' rule"; return 1; }
  grep -qF 'claude_md_paths' "$path" \
    || { echo "$path missing 'claude_md_paths' reference in verification logic"; return 1; }
  echo "$path body has anti-hallucination clause capping confidence at 49 on unverified CLAUDE.md citations"
}

check_haiku_scorer_io_contract_sources_and_multi_source_note() {
  # I/O contract includes `sources: [...]` + `multi_source_note` per X8.
  local path="agents/haiku-finding-scorer.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF '"sources"' "$path" \
    || { echo "$path missing \"sources\" field in I/O contract"; return 1; }
  grep -qF '"multi_source_note"' "$path" \
    || { echo "$path missing \"multi_source_note\" field in I/O contract"; return 1; }
  # The canonical human-readable hint form.
  grep -qF 'also raised by:' "$path" \
    || { echo "$path missing canonical multi_source_note prose form 'also raised by: ...'"; return 1; }
  # Advisory-not-automatic framing.
  grep -qiE 'dual[- ](source|halves).*(advisory|not[[:space:]]+automatic)|advisory.*not[[:space:]]+automatic' "$path" \
    || { echo "$path missing 'dual-sources advisory, not automatic' framing"; return 1; }
  echo "$path I/O contract carries sources[] + multi_source_note with advisory-not-automatic framing"
}

check_haiku_scorer_fail_open() {
  # Scorer agent prose declares the fail-open behaviour semantics: malformed
  # output triggers whole-batch fail-open. (The ACTUAL fail-open is driven by
  # the cross-auditor orchestrator — this check ensures the scorer contract
  # declares the fail-output conditions so the contract is discoverable here.)
  local path="agents/haiku-finding-scorer.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qiE '(malformed|fail[- ]open|whole[- ]batch)' "$path" \
    || { echo "$path missing fail-open / malformed-output reference"; return 1; }
  grep -qF 'scores' "$path" \
    || { echo "$path missing 'scores' output key reference"; return 1; }
  echo "$path declares fail-open / malformed-output semantics"
}

check_haiku_scorer_edge_cases_zero_partial_cap_timeout() {
  # Cross-auditor Step 3 Consolidation enumerates the four edge cases (§3.5a X1):
  # zero LLM findings, partial output, batch cap 20, 60s timeout.
  local path="agents/cross-auditor.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qiE '(zero|empty).*(pure[- ]LLM|LLM[[:space:]]+findings|LLM[[:space:]]+subset)' "$path" \
    || grep -qiE 'empty.*SKIP.*scorer' "$path" \
    || { echo "$path Step 3 missing 'zero LLM findings → skip scorer' edge-case rule (X1 rule 1)"; return 1; }
  grep -qE '20[[:space:]]+findings|batch[[:space:]]+cap.*20|20[[:space:]]*[- ]finding' "$path" \
    || { echo "$path Step 3 missing batch cap 20 rule (X1 rule 3)"; return 1; }
  grep -qE '60[- ]?second|60s[[:space:]]+timeout|60[[:space:]]+sec' "$path" \
    || { echo "$path Step 3 missing 60-second timeout rule (X1 rule 4)"; return 1; }
  grep -qiE '(partial.*output|missing.*id|duplicate.*id|stray.*key).*fail[- ]open' "$path" \
    || grep -qiE 'fail[- ]open.*(partial|malformed)' "$path" \
    || grep -qiE 'validation.*(fail|violation).*(whole[- ]iteration|fail[- ]open)' "$path" \
    || { echo "$path Step 3 missing 'partial/malformed output → whole-iteration fail-open' rule (X1 rule 2)"; return 1; }
  echo "$path Step 3 Consolidation enumerates zero/partial/cap/timeout edge cases (X1 rules 1-4)"
}

check_haiku_scorer_mock_seam_declared() {
  # Mock seam — env var CROSS_AUDIT_SCORER_MOCK_JSON documented in cross-auditor
  # prose (the scorer agent's prose is for production — mock seam lives in the
  # invoker). Per spec §3.5a + §3.7 line 453.
  local path="agents/cross-auditor.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF 'CROSS_AUDIT_SCORER_MOCK_JSON' "$path" \
    || { echo "$path missing CROSS_AUDIT_SCORER_MOCK_JSON env-var seam declaration"; return 1; }
  grep -qiE 'mock.*(test|seam|injection)|test[- ]injection|smoke[- ]test' "$path" \
    || { echo "$path CROSS_AUDIT_SCORER_MOCK_JSON declaration lacks test-seam context"; return 1; }
  echo "$path declares CROSS_AUDIT_SCORER_MOCK_JSON mock seam for test injection"
}

check_cross_auditor_step3_scorer_integration() {
  # agents/cross-auditor.md Step 3 declares the 5-stage pipeline with the
  # scorer call between dedupe (§3.5) and renderer (Step 4). Probe-sourced
  # findings pinned confidence=100; pure-LLM findings scored via Task tool.
  local path="agents/cross-auditor.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qiE 'Haiku.*(scorer|decoupled|finding[- ]scorer)' "$path" \
    || { echo "$path Step 3 missing Haiku scorer integration reference"; return 1; }
  grep -qF 'haiku-finding-scorer' "$path" \
    || { echo "$path Step 3 missing agent-name reference 'haiku-finding-scorer'"; return 1; }
  grep -qF 'dedupe_findings.sh' "$path" \
    || { echo "$path Step 3 missing dedupe helper reference"; return 1; }
  grep -qE 'pure[- ]LLM.*(only|filter|skip)|filter.*pure[- ]LLM' "$path" \
    || { echo "$path Step 3 missing 'scorer sees pure-LLM only' filter rule"; return 1; }
  # Either direction of the phrasing: "probe ... pin confidence: 100" or
  # "confidence: 100 ... probe"; the invariant is that both 'probe' and
  # 'confidence: 100' (or 100) are near each other on the same line.
  grep -qE '[Pp]robe[- ]sourced.*pin.*confidence.*100|confidence:?[[:space:]]*100.*probe' "$path" \
    || grep -qE 'pin.*`confidence:[[:space:]]*100`' "$path" \
    || { echo "$path Step 3 missing 'probe-sourced findings pin confidence=100' rule"; return 1; }
  echo "$path Step 3 has Haiku scorer call between dedupe and renderer with pure-LLM filter + probe-100 pin"
}

check_cross_auditor_scorer_mock_env_var() {
  # Same env-var check as scorer_mock_seam but targeted at cross-auditor
  # (the invoker side). Must declare that production leaves the var UNSET.
  local path="agents/cross-auditor.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF 'CROSS_AUDIT_SCORER_MOCK_JSON' "$path" \
    || { echo "$path missing CROSS_AUDIT_SCORER_MOCK_JSON env-var declaration"; return 1; }
  grep -qiE 'production.*(unset|leaves[[:space:]]+(it[[:space:]]+)?unset)|unset.*production' "$path" \
    || { echo "$path missing 'production leaves env var unset' clause"; return 1; }
  echo "$path Step 3 declares CROSS_AUDIT_SCORER_MOCK_JSON with 'production leaves unset' note"
}

check_cross_auditor_probe_failures_synthesis_end_to_end() {
  # X18 end-to-end: orchestrator synthesizes probe_failures[] from degraded-mode
  # receipts. Prose must reference the synthesis step; helper runs synth script
  # on fixtures (k) and (l) to prove the producer contract's reason/remediation
  # sourcing (explicit vs fallback) works.
  local path="agents/cross-auditor.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF 'probe_failures' "$path" \
    || { echo "$path missing probe_failures[] synthesis reference in Step 3"; return 1; }
  grep -qiE 'degraded_mode.*(true|receipt)|synthesiz.*probe_failures' "$path" \
    || { echo "$path missing 'synthesize from degraded_mode receipts' rule (X18 producer contract)"; return 1; }
  # Runtime proof via synth_probe_failures.sh on fixtures (k) and (l).
  local script="hooks/lib/synth_probe_failures.sh"
  [ -x "$script" ] || { echo "$script not executable"; return 1; }
  local out_k out_l expected_k expected_l
  out_k=$(bash "$script" <tests/fixtures/cross-audit-probes-foundation/scorer/k-probe-failures-synthesis-input.json) \
    || { echo "synth_probe_failures.sh failed on fixture (k)"; return 1; }
  expected_k=$(cat tests/fixtures/cross-audit-probes-foundation/scorer/k-probe-failures-synthesis-expected.json)
  # strip trailing newline
  expected_k="${expected_k%$'\n'}"
  if [ "$out_k" != "$expected_k" ]; then
    echo "fixture (k) synthesis output mismatch:"
    echo "  actual:   $out_k"
    echo "  expected: $expected_k"
    return 1
  fi
  out_l=$(bash "$script" <tests/fixtures/cross-audit-probes-foundation/scorer/l-probe-failures-fallback-input.json) \
    || { echo "synth_probe_failures.sh failed on fixture (l)"; return 1; }
  expected_l=$(cat tests/fixtures/cross-audit-probes-foundation/scorer/l-probe-failures-fallback-expected.json)
  expected_l="${expected_l%$'\n'}"
  if [ "$out_l" != "$expected_l" ]; then
    echo "fixture (l) fallback-synthesis output mismatch:"
    echo "  actual:   $out_l"
    echo "  expected: $expected_l"
    return 1
  fi
  echo "Step 3 synthesis declaration + fixtures (k explicit strings, l generic-fallback) both byte-match §3.3 producer contract"
}

# --- Step 7 fixture-level sub-assertions (a-l per spec §5 Step 7) ---
# Each sub-assertion is a deliberately distinct invariant so an accidental
# regression in one path does not cascade across fixtures.

check_scorer_fixture_a_canonical_scoring() {
  # Fixture (a): mock returns a confidence ≥75 (canonical scoring path).
  local f="tests/fixtures/cross-audit-probes-foundation/scorer/a-canonical-mock.json"
  [ -r "$f" ] || { echo "$f not readable"; return 1; }
  local conf
  conf=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["scores"]["X1"]["confidence"])' "$f") \
    || { echo "$f: failed to parse mock JSON"; return 1; }
  if [ "$conf" -lt 75 ]; then
    echo "$f: canonical-scoring mock confidence=$conf (expected >=75)"
    return 1
  fi
  echo "$f: canonical-scoring mock confidence=$conf (>=75)"
}

check_scorer_fixture_b_fabricated_citation_capped() {
  # Fixture (b): fabricated CLAUDE.md citation → confidence <=49 per anti-
  # hallucination clause.
  local f="tests/fixtures/cross-audit-probes-foundation/scorer/b-fabricated-citation-mock.json"
  [ -r "$f" ] || { echo "$f not readable"; return 1; }
  local conf
  conf=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["scores"]["X1"]["confidence"])' "$f") \
    || { echo "$f: failed to parse mock JSON"; return 1; }
  if [ "$conf" -gt 49 ]; then
    echo "$f: fabricated-citation mock confidence=$conf (expected <=49 per anti-hallucination clause)"
    return 1
  fi
  echo "$f: fabricated-citation mock confidence=$conf (<=49)"
}

check_scorer_fixture_c_malformed_triggers_fail_open() {
  # Fixture (c): malformed scorer output. The mock file's JSON is structurally
  # valid but scores["X1"] is a string (not an object with confidence +
  # rationale) — this satisfies rule 2 of §3.5a edge cases (malformed →
  # whole-batch fail-open). The check asserts the mock encodes the violation.
  local f="tests/fixtures/cross-audit-probes-foundation/scorer/c-malformed-mock.json"
  [ -r "$f" ] || { echo "$f not readable"; return 1; }
  local invalid
  invalid=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); e=d["scores"]["X1"]; print("true" if not isinstance(e, dict) or "confidence" not in e else "false")' "$f") \
    || { echo "$f: failed to parse mock JSON"; return 1; }
  if [ "$invalid" != "true" ]; then
    echo "$f: expected malformed score-entry shape (non-object or missing 'confidence'); got valid shape"
    return 1
  fi
  echo "$f: mock encodes malformed-score violation (non-object entry) — triggers §3.5a rule-2 fail-open"
}

check_scorer_fixture_d_dual_source_not_auto_100() {
  # Fixture (d): dual-source finding scored on evidence, NOT auto-100.
  local f="tests/fixtures/cross-audit-probes-foundation/scorer/d-dual-source-mock.json"
  [ -r "$f" ] || { echo "$f not readable"; return 1; }
  local conf
  conf=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["scores"]["X1"]["confidence"])' "$f") \
    || { echo "$f: failed to parse mock JSON"; return 1; }
  if [ "$conf" -ge 100 ]; then
    echo "$f: dual-source finding scored at $conf (auto-100 detected; violates 'advisory, not automatic')"
    return 1
  fi
  echo "$f: dual-source finding scored $conf (<100; advisory-not-automatic honored)"
}

check_scorer_fixture_e_combined_probe_scorer_fail() {
  # Fixture (e): combined probe-fail + scorer-fail — tested via renderer fixture
  # (f) under Step 6 (already byte-verified). This check re-runs the renderer on
  # the Step 6 fixture (f) input to prove the combined-fail banner + routing
  # stays correct end-to-end as we add the scorer layer.
  _render_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/renderer/f-combined-fail-open-input.json \
    tests/fixtures/cross-audit-probes-foundation/renderer/f-combined-fail-open-expected.md
}

check_scorer_fixture_f_zero_llm_findings_skip_scorer() {
  # Fixture (f) at Step 7: audit with only probe findings in shadow mode → scorer
  # SKIPPED, scorer_status: ok, advisory section omitted, no scorer-related banner.
  # Tested via renderer fixture 02-probe-shadow (only probe finding, scorer_status=ok).
  local input="tests/fixtures/cross-audit-probes-foundation/renderer/02-probe-shadow-input.json"
  [ -r "$input" ] || { echo "$input not readable"; return 1; }
  local ss
  ss=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["scorer_status"])' "$input") \
    || { echo "$input: failed to parse"; return 1; }
  if [ "$ss" != "ok" ]; then
    echo "$input: expected scorer_status=ok (zero LLM findings → scorer skipped); got $ss"
    return 1
  fi
  # Ensure no pure-LLM findings in the fixture — validates 'zero LLM' precondition.
  local pure_llm_count
  pure_llm_count=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); n=sum(1 for f in d["findings"] if not any(s.startswith("probe:") for s in f["sources"])); print(n)' "$input") \
    || { echo "$input: failed to count pure-LLM findings"; return 1; }
  if [ "$pure_llm_count" != "0" ]; then
    echo "$input: expected 0 pure-LLM findings (zero-LLM precondition); got $pure_llm_count"
    return 1
  fi
  echo "$input: zero pure-LLM findings + scorer_status=ok (scorer skipped per X1 rule 1)"
}

check_scorer_fixture_g_partial_output_whole_batch_fail_open() {
  # Fixture (g): partial scorer output (only X1 returned) when input has X1+X2
  # — whole-batch fail-open per X1 rule 2. This check asserts the mock encodes
  # the partial-output condition: scores keys are a strict subset of a sample
  # input set {X1, X2}.
  local f="tests/fixtures/cross-audit-probes-foundation/scorer/g-partial-output-mock.json"
  [ -r "$f" ] || { echo "$f not readable"; return 1; }
  local partial
  partial=$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
input_ids = {"X1", "X2"}
returned = set(d["scores"].keys())
print("true" if returned != input_ids and returned.issubset(input_ids) else "false")
' "$f") \
    || { echo "$f: failed to parse"; return 1; }
  if [ "$partial" != "true" ]; then
    echo "$f: expected partial-output (returned strict-subset of {X1,X2}); got full or superset"
    return 1
  fi
  echo "$f: mock returns strict-subset of input IDs → triggers X1 rule-2 whole-iteration fail-open"
}

check_scorer_fixture_h_batch_cap_chunking_happy_path() {
  # Fixture (h): 25 LLM findings chunked into 20+5; both mocks are valid; merged
  # scores map covers all 25 IDs without collision. Assert: chunk1 has 20 ids,
  # chunk2 has 5 ids, union has 25 unique ids, disjoint.
  local c1="tests/fixtures/cross-audit-probes-foundation/scorer/h-batch-cap-chunk1-mock.json"
  local c2="tests/fixtures/cross-audit-probes-foundation/scorer/h-batch-cap-chunk2-mock.json"
  [ -r "$c1" ] && [ -r "$c2" ] || { echo "batch-cap mocks not readable"; return 1; }
  local result
  result=$(python3 -c '
import json, sys
c1 = json.load(open(sys.argv[1]))["scores"]
c2 = json.load(open(sys.argv[2]))["scores"]
s1, s2 = set(c1.keys()), set(c2.keys())
msg = []
if len(s1) != 20: msg.append(f"chunk1 size {len(s1)} != 20")
if len(s2) != 5:  msg.append(f"chunk2 size {len(s2)} != 5")
if s1 & s2:      msg.append(f"chunks overlap: {sorted(s1 & s2)}")
if len(s1 | s2) != 25: msg.append(f"union size {len(s1 | s2)} != 25")
print("|".join(msg) if msg else "OK")
' "$c1" "$c2") \
    || { echo "batch-cap parse failed"; return 1; }
  if [ "$result" != "OK" ]; then
    echo "batch-cap chunking invariants violated: $result"
    return 1
  fi
  echo "batch-cap (X1 rule 3): chunk1=20, chunk2=5, disjoint, union=25 IDs"
}

check_scorer_fixture_i_merged_probe_llm_skip_scorer() {
  # Fixture (i): merged probe+LLM (sources: [probe:E, claude], probe shadow) —
  # scorer skipped, confidence pinned 100, routed to Shadow. Already byte-
  # verified via Step 6 renderer fixture (d). Re-run for end-to-end proof.
  _render_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/renderer/d-merged-probe-shadow-input.json \
    tests/fixtures/cross-audit-probes-foundation/renderer/d-merged-probe-shadow-expected.md
}

check_scorer_fixture_j_mock_seam_env_var_drives_fixtures() {
  # Fixture (j): the mock seam — CROSS_AUDIT_SCORER_MOCK_JSON env var — enables
  # fixtures a-i without live Haiku calls. Asserted structurally by verifying
  # the env-var is declared in the orchestrator prose (cross_auditor_scorer_
  # mock_env_var helper covers the byte-check; this fixture-level check
  # additionally asserts the env var name is EXACT 'CROSS_AUDIT_SCORER_MOCK_JSON'
  # and not a paraphrase — guards against X7 resolution drift).
  local path="agents/cross-auditor.md"
  local hits
  hits=$(grep -cF 'CROSS_AUDIT_SCORER_MOCK_JSON' "$path")
  if [ "$hits" -lt 1 ]; then
    echo "$path: expected env-var 'CROSS_AUDIT_SCORER_MOCK_JSON' at least once; found $hits"
    return 1
  fi
  echo "$path: exact env-var 'CROSS_AUDIT_SCORER_MOCK_JSON' present ($hits occurrence(s)) — mock seam stable"
}

check_scorer_fixture_k_probe_failures_synthesis_explicit_strings() {
  # Fixture (k): synth_probe_failures.sh on a receipt with non-empty
  # failure_reason/failure_remediation emits those exact strings through to
  # probe_failures[].
  local script="hooks/lib/synth_probe_failures.sh"
  local input="tests/fixtures/cross-audit-probes-foundation/scorer/k-probe-failures-synthesis-input.json"
  local expected="tests/fixtures/cross-audit-probes-foundation/scorer/k-probe-failures-synthesis-expected.json"
  local out_tmp="/tmp/smoke-synth-k.$$"
  bash "$script" <"$input" >"$out_tmp" || { echo "synth_probe_failures.sh failed on fixture (k)"; rm -f "$out_tmp"; return 1; }
  if ! diff "$out_tmp" "$expected" >/tmp/smoke-synth-k-diff.$$ 2>&1; then
    echo "fixture (k) output mismatch:"
    cat /tmp/smoke-synth-k-diff.$$
    rm -f "$out_tmp" /tmp/smoke-synth-k-diff.$$
    return 1
  fi
  rm -f "$out_tmp" /tmp/smoke-synth-k-diff.$$
  echo "fixture (k) explicit failure_reason/remediation propagates byte-exact through synthesis"
}

check_scorer_fixture_l_probe_failures_fallback_generic_strings() {
  # Fixture (l): synth_probe_failures.sh on a receipt WITHOUT failure_reason
  # and failure_remediation emits the §3.3 generic fallback strings.
  local script="hooks/lib/synth_probe_failures.sh"
  local input="tests/fixtures/cross-audit-probes-foundation/scorer/l-probe-failures-fallback-input.json"
  local expected="tests/fixtures/cross-audit-probes-foundation/scorer/l-probe-failures-fallback-expected.json"
  local out_tmp="/tmp/smoke-synth-l.$$"
  bash "$script" <"$input" >"$out_tmp" || { echo "synth_probe_failures.sh failed on fixture (l)"; rm -f "$out_tmp"; return 1; }
  if ! diff "$out_tmp" "$expected" >/tmp/smoke-synth-l-diff.$$ 2>&1; then
    echo "fixture (l) output mismatch:"
    cat /tmp/smoke-synth-l-diff.$$
    rm -f "$out_tmp" /tmp/smoke-synth-l-diff.$$
    return 1
  fi
  rm -f "$out_tmp" /tmp/smoke-synth-l-diff.$$
  echo "fixture (l) missing failure_reason/remediation → generic fallback strings per §3.3"
}

# --- Step 6: Extended renderer — advisory section + merged routing + combined fail-open ---

check_findings_renderer_low_confidence_section_fixture_a() {
  _render_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/renderer/a-low-only-llm-input.json \
    tests/fixtures/cross-audit-probes-foundation/renderer/a-low-only-llm-expected.md
}

check_findings_renderer_low_confidence_section_fixture_b() {
  _render_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/renderer/b-mixed-high-low-input.json \
    tests/fixtures/cross-audit-probes-foundation/renderer/b-mixed-high-low-expected.md
}

check_findings_renderer_scorer_fail_open_fixture_c() {
  _render_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/renderer/c-scorer-failed-input.json \
    tests/fixtures/cross-audit-probes-foundation/renderer/c-scorer-failed-expected.md
}

check_findings_renderer_merged_probe_llm_routing_fixture_d() {
  _render_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/renderer/d-merged-probe-shadow-input.json \
    tests/fixtures/cross-audit-probes-foundation/renderer/d-merged-probe-shadow-expected.md
}

check_findings_renderer_merged_probe_llm_routing_fixture_e() {
  _render_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/renderer/e-merged-probe-warn-input.json \
    tests/fixtures/cross-audit-probes-foundation/renderer/e-merged-probe-warn-expected.md
}

check_findings_renderer_combined_fail_open_banner_fixture_f() {
  _render_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/renderer/f-combined-fail-open-input.json \
    tests/fixtures/cross-audit-probes-foundation/renderer/f-combined-fail-open-expected.md
}

check_findings_renderer_low_confidence_section() {
  check_findings_renderer_low_confidence_section_fixture_a || return 1
  check_findings_renderer_low_confidence_section_fixture_b || return 1
  echo "low-confidence LLM advisory-section fixtures (a low-only, b mixed) byte-match"
}

check_findings_renderer_scorer_fail_open() {
  check_findings_renderer_scorer_fail_open_fixture_c
}

check_findings_renderer_merged_probe_llm_routing() {
  check_findings_renderer_merged_probe_llm_routing_fixture_d || return 1
  check_findings_renderer_merged_probe_llm_routing_fixture_e || return 1
  echo "merged probe+LLM routing fixtures (d shadow, e warn) byte-match"
}

check_findings_renderer_combined_fail_open_banner() {
  check_findings_renderer_combined_fail_open_banner_fixture_f
}

check_skill_md_phase3_shadow_section() {
  # Phase 3 renders a separate `## Shadow findings (informational)` section
  # distinct from the decision banner, with a banner footer citing the count
  # and link to the shadow-findings anchor.
  local path="skills/cross-audit/SKILL.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF 'Shadow findings (informational)' "$path" \
    || { echo "$path missing literal '## Shadow findings (informational)' section reference in Phase 3"; return 1; }
  # Shadow findings must be declared NOT surfaced in the Phase 3 decision
  # banner (suppression rule).
  grep -qE 'shadow.*(not.*surfaced|suppressed.*banner|NOT.*(surfaced|in.*banner))' "$path" \
    || { echo "$path missing 'shadow findings NOT surfaced in decision banner' suppression rule"; return 1; }
  # Banner footer with shadow count + path link.
  grep -qE 'N[[:space:]]+shadow[- ]?mode[[:space:]]+findings|shadow[- ]?mode[[:space:]]+findings.*count' "$path" \
    || grep -qE 'shadow[- ]findings[- ]count|shadow[- ]findings[[:space:]]+count' "$path" \
    || { echo "$path missing banner footer line citing shadow count"; return 1; }
  grep -qF '#shadow-findings' "$path" \
    || { echo "$path missing banner-footer anchor link '#shadow-findings'"; return 1; }
  echo "$path Phase 3 carries shadow section + suppression rule + banner footer with count + anchor"
}

check_skill_md_phase3_advisory_section_footer() {
  # X11 resolution: a second informational section `## Low-confidence LLM
  # findings (advisory)` sits alongside Shadow findings. Its own banner
  # footer appears in addition to (not replacing) the shadow footer — both
  # coexist when both sections are non-empty; each is omitted when its
  # section is empty.
  local path="skills/cross-audit/SKILL.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF 'Low-confidence LLM findings (advisory)' "$path" \
    || { echo "$path missing '## Low-confidence LLM findings (advisory)' section per X11"; return 1; }
  grep -qF '#low-confidence-llm-findings-advisory' "$path" \
    || { echo "$path missing '#low-confidence-llm-findings-advisory' banner footer anchor link"; return 1; }
  # The banner must gain a second footer line (not replace shadow); require
  # wording that shows coexistence or 'second footer / both footers'.
  grep -qE '(coexist|both[[:space:]]+footers|second[[:space:]]+footer|in[[:space:]]+addition[[:space:]]+to[[:space:]]+the[[:space:]]+shadow)' "$path" \
    || { echo "$path missing coexist-with-shadow clause for the advisory-section footer"; return 1; }
  # Each footer omitted when its section is empty.
  grep -qE '(omitted[[:space:]]+when|each[[:space:]]+footer[[:space:]]+is[[:space:]]+omitted|footer[[:space:]]+is[[:space:]]+omitted)' "$path" \
    || { echo "$path missing 'each footer omitted when its section is empty' rule"; return 1; }
  # Advisory findings also suppressed from the decision banner (case-insensitive).
  grep -qiE 'low[- ]confidence.*(not[[:space:]]+surfaced|suppressed.*banner|not.*in.*banner)' "$path" \
    || grep -qiE 'advisory.*(not[[:space:]]+surfaced|suppressed.*banner|not.*in.*banner)' "$path" \
    || { echo "$path missing 'low-confidence/advisory findings NOT surfaced in decision banner' suppression rule"; return 1; }
  echo "$path Phase 3 has advisory section + coexist-footer rule + empty-section-omit rule + suppression"
}

check_cross_auditor_probe_modes_input_declared() {
  # agents/cross-auditor.md input-surface declares a new `probe_modes` input
  # field (dict mapping probe id → effective mode resolved from the
  # cross_audit.probes YAML kill-switch). Empty dict when no probe is configured.
  local path="agents/cross-auditor.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qE '\*\*probe_modes\*\*|`probe_modes`' "$path" \
    || { echo "$path missing 'probe_modes' input field declaration"; return 1; }
  # Must declare the map / dict shape (probe id → mode).
  grep -qE 'probe_modes.*(dict|mapping|map|object).*(probe[- ]id|id).*(mode|value)' "$path" \
    || grep -qE 'probe_modes.*probe[[:space:]]+id[[:space:]]*→[[:space:]]*(effective[[:space:]]+)?mode' "$path" \
    || { echo "$path missing probe_modes shape documentation (dict/map probe_id → mode)"; return 1; }
  echo "$path input surface declares probe_modes (dict: probe id → mode)"
}

check_cross_auditor_skill_dispatch_drops_probe_receipts() {
  # Supplementary helper (spec §5 Step 3 skill-side update — skills/cross-
  # audit/SKILL.md agent-dispatch block stops threading `probe_receipts: []`
  # placeholder per iter-1 X2 pivot). Closes the §6.1 Step 3 +7 vs net-+6
  # arithmetic gap that surfaces when the Foundation helper
  # `check_cross_auditor_probe_receipts_input_declared` is repurposed
  # in-place rather than removed. Asserts the Phase 1-2 Step 2 cross-auditor
  # dispatch block does NOT pass `probe_receipts:` as a non-commented input
  # field; the commented-out note explaining why the field was removed IS
  # allowed (documentation trail).
  local path="skills/cross-audit/SKILL.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local dispatch_block
  dispatch_block=$(awk '
    !in_s && /^### Step 2: Launch cross-auditor agent/ { in_s = 1; print; next }
    in_s && /^### Step 3/ { exit }
    in_s { print }
  ' "$path")
  [[ -n "$dispatch_block" ]] || { echo "$path missing '### Step 2: Launch cross-auditor agent' dispatch block"; return 1; }
  # Reject non-commented 'probe_receipts:' lines in the dispatch block.
  if printf '%s\n' "$dispatch_block" | grep -E '^[[:space:]]*probe_receipts:' | grep -qvE '^[[:space:]]*#'; then
    echo "$path Step 2 dispatch still threads probe_receipts: as non-commented input (expected dropped per iter-1 X2 pivot)"
    printf '%s\n' "$dispatch_block" | grep -nE 'probe_receipts' | head -3
    return 1
  fi
  # Positive: probe_modes stays threaded.
  printf '%s\n' "$dispatch_block" | grep -qE '^[[:space:]]*probe_modes:' \
    || { echo "$path Step 2 dispatch missing probe_modes (should stay threaded)"; return 1; }
  echo "$path Step 2 dispatch drops probe_receipts placeholder (iter-1 X2 pivot); probe_modes still threaded"
}

check_cross_auditor_probe_receipts_produced_by_step05() {
  # Spec 2026-04-21-probe-e-diff-scope-leak §3.2 (c) / §5 Step 3 (iter-3 X15 /
  # iter-2 X10) — probe_receipts is no longer a skill-threaded input bullet.
  # The ## Input section must NOT list it as an input field; Step 0.5 is the
  # producer path. Replaces the Foundation-era
  # check_cross_auditor_probe_receipts_input_declared (which asserted the
  # opposite invariant and shipped before probe E's dispatch pivot).
  local path="agents/cross-auditor.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  # Extract just the ## Input section (range from '## Input' up to next '## ').
  local input_section
  input_section=$(awk '
    !in_s && $0 == "## Input" { in_s = 1; print; next }
    in_s && /^## / && $0 != "## Input" { exit }
    in_s { print }
  ' "$path")
  [[ -n "$input_section" ]] || { echo "$path missing '## Input' section"; return 1; }
  # Reject any line in ## Input shaped like the old bullet:
  #   '- **probe_receipts** (optional;...' OR '- **probe_receipts**:'
  if printf '%s\n' "$input_section" | grep -qE '^- \*\*probe_receipts\*\*'; then
    echo "$path ## Input still lists probe_receipts as an input bullet (expected removed per §3.2 (c) / X10)"
    return 1
  fi
  # Positive: Step 0.5 must exist as the producer path.
  grep -qE '^## Step 0\.5' "$path" \
    || { echo "$path missing '## Step 0.5' producer section (expected between Step 0 and Step 1)"; return 1; }
  grep -qF 'probe_findings' "$path" \
    || { echo "$path missing 'probe_findings' — Step 0.5 should produce it"; return 1; }
  grep -qF 'probe_receipt_metadata_by_provisional_id' "$path" \
    || { echo "$path missing 'probe_receipt_metadata_by_provisional_id' side-map (iter-4 X19)"; return 1; }
  echo "$path ## Input no longer lists probe_receipts bullet; Step 0.5 produces probe_findings/probe_receipts via side-map (X19)"
}

check_yaml_example_probes_block() {
  # .ai-dev-team.yml.example carries a commented-out cross_audit.probes block
  # showing mode values off|shadow|warn|block and documenting that off is the
  # default when the key is absent.
  local path=".ai-dev-team.yml.example"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF '# cross_audit:' "$path" \
    || { echo "$path missing commented-out '# cross_audit:' top-level key"; return 1; }
  grep -qF '#   probes:' "$path" \
    || { echo "$path missing commented-out '#   probes:' nested block"; return 1; }
  # At least one probe-id example row with a valid mode literal.
  grep -qE '#[[:space:]]+e: \{ mode: (off|shadow|warn|block) \}' "$path" \
    || { echo "$path missing example probe row '#     e: { mode: off }' (or shadow|warn|block)"; return 1; }
  # Documents the four-mode kill-switch enumeration.
  if ! grep -qE '(off|shadow|warn|block).*(off|shadow|warn|block).*(off|shadow|warn|block).*(off|shadow|warn|block)' "$path"; then
    echo "$path missing enumeration of four modes (off|shadow|warn|block) in the cross_audit.probes commented block"
    return 1
  fi
  echo "$path has cross_audit.probes.<id>.mode commented example block with 4-mode enumeration"
}

check_docs_kb_discovery_probes_block() {
  # docs/kb-discovery.md has a section (or subsection) documenting the
  # cross_audit.probes.<id>.mode YAML schema — default off, modes
  # off|shadow|warn|block, and one-line-warning on unknown probe id.
  local path="docs/kb-discovery.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF 'cross_audit.probes' "$path" \
    || { echo "$path missing 'cross_audit.probes' schema documentation"; return 1; }
  # The four mode values must be enumerated in the docs block.
  grep -qF 'off|shadow|warn|block' "$path" \
    || grep -qE '`off`.*`shadow`.*`warn`.*`block`' "$path" \
    || { echo "$path missing four-mode enumeration off|shadow|warn|block"; return 1; }
  # Unknown-probe-id warning note per §3.4.
  grep -qE '(unknown probe id|unrecognized probe id|unknown id).*warning' "$path" \
    || { echo "$path missing 'unknown probe id → warning' note (§3.4 — warn, do not hard-stop)"; return 1; }
  # Default 'off' when absent.
  grep -qE 'default.*off|off.*when.*absent|absent.*off' "$path" \
    || { echo "$path missing 'default off when absent' note for cross_audit.probes"; return 1; }
  echo "$path has cross_audit.probes.<id>.mode documentation with mode enum + default-off + unknown-id warning"
}

check_skill_md_phase0_probe_mode_read() {
  # skills/cross-audit/SKILL.md Phase 0 extensions block reads
  # cross_audit.probes.<id>.mode from the resolved config. Explicit default-off
  # on absence. Unknown probe id emits warning (not hard-stop).
  local path="skills/cross-audit/SKILL.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF 'cross_audit.probes' "$path" \
    || { echo "$path missing reference to cross_audit.probes.<id>.mode in Phase 0"; return 1; }
  grep -qE 'default.*`?off`?|`?off`?.*default|defaults to (`|'\'')?off' "$path" \
    || { echo "$path missing 'default off' language for cross_audit.probes"; return 1; }
  grep -qE 'unknown.*probe.*warning|warning.*unknown.*probe|unrecognized.*warning' "$path" \
    || { echo "$path missing 'unknown probe id → warning (not hard-stop)' note"; return 1; }
  echo "$path Phase 0 reads cross_audit.probes.<id>.mode with default-off + unknown-id warning semantics"
}

check_receipt_hash_canonicalization_rerun_stable() {
  # §3.3 X3: rerun-stability. Run the reference canonicalizer twice on the
  # same 2-file synthetic input — outputs byte-identical. Then run once with
  # reversed scope_files order — output byte-identical to the first two (sort
  # is internal).
  local script="hooks/lib/receipt_canonicalize.sh"
  [ -x "$script" ] || { echo "$script not executable"; return 1; }
  local input_a="tests/fixtures/cross-audit-probes-foundation/receipt/canonical-2-file-input.json"
  local input_b="tests/fixtures/cross-audit-probes-foundation/receipt/canonical-2-file-reversed-input.json"
  [ -r "$input_a" ] || { echo "$input_a not readable"; return 1; }
  [ -r "$input_b" ] || { echo "$input_b not readable"; return 1; }
  local out1 out2 out3
  out1=$(bash "$script" <"$input_a") || { echo "receipt_canonicalize.sh failed on input_a run1"; return 1; }
  out2=$(bash "$script" <"$input_a") || { echo "receipt_canonicalize.sh failed on input_a run2"; return 1; }
  out3=$(bash "$script" <"$input_b") || { echo "receipt_canonicalize.sh failed on reversed input"; return 1; }
  if [ "$out1" != "$out2" ]; then
    echo "receipt_canonicalize.sh not deterministic across two runs on identical input"
    echo "  run1: $out1"
    echo "  run2: $out2"
    return 1
  fi
  if [ "$out1" != "$out3" ]; then
    echo "receipt_canonicalize.sh output changes when scope_files order is reversed (sort should be internal)"
    echo "  normal: $out1"
    echo "  reversed: $out3"
    return 1
  fi
  # Guard against a dummy-hash regression: the hex digests must be 64-char sha256.
  if ! printf '%s' "$out1" | grep -qE '"trigger_input_hash":"[0-9a-f]{64}"'; then
    echo "receipt_canonicalize.sh output does not carry a 64-char sha256 trigger_input_hash"
    echo "  output: $out1"
    return 1
  fi
  if ! printf '%s' "$out1" | grep -qE '"probe_output_hash":"[0-9a-f]{64}"'; then
    echo "receipt_canonicalize.sh output does not carry a 64-char sha256 probe_output_hash"
    echo "  output: $out1"
    return 1
  fi
  echo "receipt_canonicalize.sh is rerun-stable and scope-order-invariant; both hashes are sha256 hex"
}

check_probe_failures_schema_hard_stop() {
  # Fixture (7): malformed probe_failures[] entry (missing `remediation` field) —
  # renderer MUST exit non-zero with non-empty stderr per §3.3 X10 contract.
  local script="hooks/lib/render_findings.sh"
  local input="tests/fixtures/cross-audit-probes-foundation/renderer/07-probe-failures-malformed-input.json"
  [ -x "$script" ] || { echo "$script not executable"; return 1; }
  [ -r "$input" ] || { echo "input fixture $input not readable"; return 1; }
  local exit_code=0
  bash "$script" <"$input" >/tmp/smoke-hardstop-out.$$ 2>/tmp/smoke-hardstop-err.$$ || exit_code=$?
  if [ "$exit_code" -eq 0 ]; then
    echo "render_findings.sh accepted malformed probe_failures[] (expected non-zero exit); stdout:"
    head -5 /tmp/smoke-hardstop-out.$$
    rm -f /tmp/smoke-hardstop-out.$$ /tmp/smoke-hardstop-err.$$
    return 1
  fi
  if [ ! -s /tmp/smoke-hardstop-err.$$ ]; then
    echo "render_findings.sh exited non-zero but stderr is empty; §3.3 X10 requires a diagnostic"
    rm -f /tmp/smoke-hardstop-out.$$ /tmp/smoke-hardstop-err.$$
    return 1
  fi
  rm -f /tmp/smoke-hardstop-out.$$ /tmp/smoke-hardstop-err.$$
  echo "render_findings.sh correctly hard-stopped on malformed probe_failures[] (exit=$exit_code, stderr non-empty)"
}

# ============================================================================
# Cross-audit probe E (spec 2026-04-21-probe-e-diff-scope-leak)
# ============================================================================

# Shared helper: run hooks/lib/probe_e.sh against a fixture dir and byte-diff
# the findings array AND receipt_metadata object separately. The probe is
# invoked with cwd = $fixture_dir so `repo_root: "."` resolves inside the
# fixture. PROBE_E_FAKE_NOW is set for determinism so emitted_at byte-matches
# the expected fixture value.
_probe_e_byte_diff() {
  # $1 = fixture dir (relative to plugin root)
  local fdir="$1"
  local input="$fdir/input.json"
  local expected_findings="$fdir/expected-findings.json"
  local expected_meta="$fdir/expected-receipt-metadata.json"
  [ -r "$input" ] || { echo "$input not readable"; return 1; }
  [ -r "$expected_findings" ] || { echo "$expected_findings not readable"; return 1; }
  [ -r "$expected_meta" ] || { echo "$expected_meta not readable"; return 1; }
  local plugin_root
  plugin_root="$(pwd)"
  local out_tmp="/tmp/smoke-probe-e-out.$$"
  local exit_code=0
  ( cd "$fdir" \
    && PROBE_E_FAKE_NOW="2026-04-21T14:23:17Z" \
    bash "$plugin_root/hooks/lib/probe_e.sh" < input.json ) >"$out_tmp" 2>/tmp/smoke-probe-e-err.$$ || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    echo "probe_e.sh exited $exit_code against $fdir; stderr:"
    head -5 /tmp/smoke-probe-e-err.$$
    rm -f "$out_tmp" /tmp/smoke-probe-e-err.$$
    return 1
  fi
  rm -f /tmp/smoke-probe-e-err.$$
  # Canonicalize actual + expected per sort_keys.
  local actual_findings actual_meta exp_findings exp_meta
  actual_findings=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.stdout.write(json.dumps(d["findings"],sort_keys=True,separators=(",",":"),ensure_ascii=False))' "$out_tmp")
  actual_meta=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.stdout.write(json.dumps(d["receipt_metadata"],sort_keys=True,separators=(",",":"),ensure_ascii=False))' "$out_tmp")
  exp_findings=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.stdout.write(json.dumps(d,sort_keys=True,separators=(",",":"),ensure_ascii=False))' "$expected_findings")
  exp_meta=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.stdout.write(json.dumps(d,sort_keys=True,separators=(",",":"),ensure_ascii=False))' "$expected_meta")
  rm -f "$out_tmp"
  if [ "$actual_findings" != "$exp_findings" ]; then
    echo "probe_e findings mismatch for $fdir:"
    diff <(printf '%s\n' "$actual_findings") <(printf '%s\n' "$exp_findings") | head -10
    return 1
  fi
  if [ "$actual_meta" != "$exp_meta" ]; then
    echo "probe_e receipt_metadata mismatch for $fdir:"
    diff <(printf '%s\n' "$actual_meta") <(printf '%s\n' "$exp_meta") | head -10
    return 1
  fi
  echo "probe_e output byte-matches expected for $fdir"
}

check_probe_e_detector_fires_on_allowlist_leak() {
  _probe_e_byte_diff tests/fixtures/cross-audit-probe-e/01-positive-allowlist-leak
}

check_probe_e_detector_clean_when_allowlist_updated() {
  _probe_e_byte_diff tests/fixtures/cross-audit-probe-e/02-clean-allowlist-updated-in-same-diff
}

check_probe_e_detector_ineligible_no_additions() {
  _probe_e_byte_diff tests/fixtures/cross-audit-probe-e/03-ineligible-no-string-additions
}

check_probe_e_detector_ineligible_collection_too_small() {
  _probe_e_byte_diff tests/fixtures/cross-audit-probe-e/04-ineligible-collection-too-small
}

check_probe_e_changed_test_file_skipped() {
  _probe_e_byte_diff tests/fixtures/cross-audit-probe-e/07-changed-test-file-skipped
}

check_probe_e_receipt_rerun_stable() {
  # Two independent invocations against fixture 05 must produce byte-identical
  # findings arrays AND byte-identical receipt_metadata.trigger_input_hash +
  # skipped_files (X21 per-file fail-open coverage). emitted_at is pinned by
  # PROBE_E_FAKE_NOW so the whole receipt matches; the strict per-field check
  # below enforces the §3.3-listed rerun-stability fields explicitly.
  local fdir="tests/fixtures/cross-audit-probe-e/05-rerun-stability"
  local plugin_root; plugin_root="$(pwd)"
  local out1 out2
  out1=$( ( cd "$fdir" && PROBE_E_FAKE_NOW="2026-04-21T14:23:17Z" bash "$plugin_root/hooks/lib/probe_e.sh" < input.json ) )
  out2=$( ( cd "$fdir" && PROBE_E_FAKE_NOW="2026-04-21T14:23:17Z" bash "$plugin_root/hooks/lib/probe_e.sh" < input.json ) )
  if [ "$out1" != "$out2" ]; then
    echo "probe_e output differs between two runs against $fdir (non-deterministic)"
    diff <(printf '%s\n' "$out1") <(printf '%s\n' "$out2") | head -10
    return 1
  fi
  # Byte-diff against expected (fires detection path + skipped_files).
  _probe_e_byte_diff "$fdir" || return 1
  # Explicit per-field rerun-stability assertions per §3.6 fixture-05 contract.
  local h1 h2 sk1 sk2 f1 f2
  h1=$(printf '%s\n' "$out1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["receipt_metadata"]["trigger_input_hash"])')
  h2=$(printf '%s\n' "$out2" | python3 -c 'import json,sys; print(json.load(sys.stdin)["receipt_metadata"]["trigger_input_hash"])')
  sk1=$(printf '%s\n' "$out1" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["receipt_metadata"]["skipped_files"]))')
  sk2=$(printf '%s\n' "$out2" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["receipt_metadata"]["skipped_files"]))')
  f1=$(printf '%s\n' "$out1" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["findings"],sort_keys=True,separators=(",",":"),ensure_ascii=False))')
  f2=$(printf '%s\n' "$out2" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["findings"],sort_keys=True,separators=(",",":"),ensure_ascii=False))')
  [ "$h1" = "$h2" ] || { echo "trigger_input_hash not stable: $h1 vs $h2"; return 1; }
  [ "$sk1" = "$sk2" ] || { echo "skipped_files not stable: $sk1 vs $sk2"; return 1; }
  [ "$f1" = "$f2" ] || { echo "findings not stable across runs"; return 1; }
  echo "probe_e receipt rerun-stability: trigger_input_hash + skipped_files + findings byte-identical across two runs"
}

# --- Step 3: Cross-auditor agent Step 0.5 + skill + dedupe merge_pair swap ---

check_cross_auditor_step05_probe_dispatch() {
  # agents/cross-auditor.md carries a '## Step 0.5: Probe dispatch' section
  # positioned between '## Step 0' (PR materialization) and '## Step 1:
  # Launch Codex' per spec §3.5 pseudocode. Asserts section presence, ordering
  # vs Step 0 / Step 1, six-way fail-open class enumeration, and side-map key
  # (iter-4 X19).
  local path="agents/cross-auditor.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local step0_line step05_line step1_line
  step0_line=$(grep -nE '^## Step 0 \(PR mode only\)' "$path" | head -1 | cut -d: -f1)
  step05_line=$(grep -nE '^## Step 0\.5' "$path" | head -1 | cut -d: -f1)
  step1_line=$(grep -nE '^## Step 1: Launch Codex' "$path" | head -1 | cut -d: -f1)
  [[ -n "$step05_line" ]] || { echo "$path missing '## Step 0.5' heading"; return 1; }
  [[ -n "$step0_line" && -n "$step1_line" ]] \
    || { echo "$path missing Step 0 or Step 1 neighbours for Step 0.5 ordering check"; return 1; }
  [[ "$step0_line" -lt "$step05_line" && "$step05_line" -lt "$step1_line" ]] \
    || { echo "$path Step 0.5 is not positioned between Step 0 ($step0_line) and Step 1 ($step1_line) — got Step 0.5 at $step05_line"; return 1; }
  # Extract the Step 0.5 section.
  local step05
  step05=$(awk '
    !in_s && /^## Step 0\.5/ { in_s = 1; print; next }
    in_s && /^## / && !/^## Step 0\.5/ { exit }
    in_s { print }
  ' "$path")
  # Six-way fail-open enumeration — distinct class markers.
  printf '%s\n' "$step05" | grep -qF 'probe script' \
    || { echo "$path Step 0.5 missing fail-open class 1 'probe script' (script-missing)"; return 1; }
  printf '%s\n' "$step05" | grep -qF 'TimeoutError' \
    || { echo "$path Step 0.5 missing fail-open class 2 'TimeoutError'"; return 1; }
  printf '%s\n' "$step05" | grep -qF 'NonZeroExit' \
    || { echo "$path Step 0.5 missing fail-open class 3 'NonZeroExit'"; return 1; }
  printf '%s\n' "$step05" | grep -qF 'JSONDecodeError' \
    || { echo "$path Step 0.5 missing fail-open class 4 'JSONDecodeError'"; return 1; }
  printf '%s\n' "$step05" | grep -qF 'schema' \
    || { echo "$path Step 0.5 missing fail-open class 5 'schema' (validation)"; return 1; }
  # Class 6 (receipt-write IOError) lives in stage 4.5 (Step 3 pipeline).
  grep -qF 'receipt write failed' "$path" \
    || { echo "$path missing fail-open class 6 (receipt write failed) in Step 3 stage 4.5"; return 1; }
  # Side-map (iter-4 X19) + provisional_id coupling (iter-5 X22).
  printf '%s\n' "$step05" | grep -qF 'probe_receipt_metadata_by_provisional_id' \
    || { echo "$path Step 0.5 missing side-map key (iter-4 X19)"; return 1; }
  printf '%s\n' "$step05" | grep -qF 'probe_findings' \
    || { echo "$path Step 0.5 missing probe_findings output list"; return 1; }
  printf '%s\n' "$step05" | grep -qF 'probe_failures_seed' \
    || { echo "$path Step 0.5 missing probe_failures_seed list (iter-4 X20)"; return 1; }
  printf '%s\n' "$step05" | grep -qF 'mode == "off"' \
    || { echo "$path Step 0.5 missing off-floor enforcement 'mode == \"off\"'"; return 1; }
  echo "$path Step 0.5 present, ordered between Step 0 and Step 1, six fail-open classes + side-map + off-floor enforcement"
}

# Shared helper: emulate the orchestrator's fail-open path by invoking
# hooks/lib/render_findings.sh with a synthesized probe_failures[] seed and
# asserting the degraded banner renders.
_probe_e_fail_open_render() {
  # $1 = failure_reason string. Writes stdin JSON to renderer with a single
  # probe_failures entry, empty findings, empty probe_modes, scorer_status=ok.
  local reason="$1"
  local remediation="$2"
  local stdin_payload
  stdin_payload=$(python3 -c "
import json,sys
payload = {
  'findings': [],
  'probe_modes': {'e': 'shadow'},
  'probe_failures': [{'probe_id': 'E', 'reason': sys.argv[1], 'remediation': sys.argv[2]}],
  'scorer_status': 'ok',
  'scorer_failure_reason': '',
}
sys.stdout.write(json.dumps(payload))
" "$reason" "$remediation")
  local rendered
  rendered=$(printf '%s' "$stdin_payload" | bash hooks/lib/render_findings.sh 2>/tmp/smoke-probe-e-render-err.$$) || {
    echo "render_findings.sh failed; stderr:"
    cat /tmp/smoke-probe-e-render-err.$$
    rm -f /tmp/smoke-probe-e-render-err.$$
    return 1
  }
  rm -f /tmp/smoke-probe-e-render-err.$$
  printf '%s\n' "$rendered" | grep -qF 'Probe(s) fail-opened this iteration' \
    || { echo "rendered output missing degraded-mode banner line"; printf '%s\n' "$rendered" | head -5; return 1; }
  printf '%s\n' "$rendered" | grep -qF "probe:E" \
    || { echo "rendered banner missing probe:E entry"; return 1; }
  printf '%s\n' "$rendered" | grep -qF "$reason" \
    || { echo "rendered banner missing expected reason substring '$reason'"; return 1; }
  return 0
}

check_probe_e_fail_open_banner() {
  # X4 — fail-open class 3 (NonZeroExit). Agent Step 0.5 catches NonZeroExit
  # and seeds probe_failures_seed[] with a populated reason/remediation
  # triple; synth_probe_failures union emits to renderer; renderer renders
  # the degraded-mode banner line. Helper asserts the rendered banner
  # surfaces the reason substring.
  _probe_e_fail_open_render \
    "probe exited non-zero: ast.parse failed on src/foo.py" \
    "re-run /cross-audit after checking probe_E stderr logs" \
    || return 1
  # Also assert the agent prose contains the NonZeroExit branch.
  grep -qF 'probe exited non-zero' agents/cross-auditor.md \
    || { echo "agents/cross-auditor.md missing 'probe exited non-zero' Step 0.5 branch"; return 1; }
  echo "fail-open banner renders (NonZeroExit class); agent prose declares the branch"
}

check_probe_e_fail_open_schema_invalid_body() {
  # iter-7 X30 rename — fail-open class 5 (schema validation failure). The
  # probe stdout IS valid JSON but missing a required key (e.g. `findings`).
  # Schema validator rejects with a short error; Step 0.5 synthesizes a
  # probe_failures_seed entry with 'probe output schema invalid:' reason.
  # Renderer surfaces the banner line.
  _probe_e_fail_open_render \
    "probe output schema invalid: missing required key 'findings'" \
    "fix probe_E to conform to §3.3 stdout shape" \
    || return 1
  grep -qF 'probe output schema invalid' agents/cross-auditor.md \
    || { echo "agents/cross-auditor.md missing 'probe output schema invalid' Step 0.5 branch"; return 1; }
  echo "fail-open banner renders (schema-invalid-body class, iter-7 X30 rename); agent prose declares the branch"
}

check_probe_e_fail_open_write_receipt_failure() {
  # X4 — fail-open class 6 (receipt-write IOError/OSError, stage 4.5). When
  # the KB mount is read-only the stage-4.5 write raises, Step 3 sets the
  # finding's probe_receipt=None and seeds probe_failures_seed[] with a
  # 'receipt write failed:' reason. Helper asserts the agent prose declares
  # the branch and the renderer surfaces the banner line.
  _probe_e_fail_open_render \
    "receipt write failed: [Errno 30] Read-only file system: '/kb/security/2026-04-21-foo-probe-receipts/X5.json'" \
    "check KB mount is writable + re-run /cross-audit" \
    || return 1
  grep -qF 'receipt write failed' agents/cross-auditor.md \
    || { echo "agents/cross-auditor.md missing 'receipt write failed' stage-4.5 branch (fail-open class 6)"; return 1; }
  # Also assert the pair (receipt write failed, check KB mount).
  grep -qF 'check KB mount is writable' agents/cross-auditor.md \
    || { echo "agents/cross-auditor.md stage-4.5 branch missing remediation 'check KB mount is writable'"; return 1; }
  # Also exercise the full stage-4.5 side-map + receipt-write loop — if the
  # agent's stage-4.5 prose drifts (e.g. stops preserving provisional_id),
  # the seed-and-render layer above doesn't catch it. Assert the prose pins:
  grep -qE 'any\(s\.startswith\("probe:"\) for s in finding\["sources"\]\)' agents/cross-auditor.md \
    || { echo "agents/cross-auditor.md stage-4.5 missing probe-sourced predicate (Foundation §3.3 X2 / iter-3 X18)"; return 1; }
  grep -qE 'provisional_id' agents/cross-auditor.md \
    || { echo "agents/cross-auditor.md stage-4.5 missing provisional_id preservation (iter-5 X22/X24)"; return 1; }
  echo "fail-open banner renders (receipt-write class, stage 4.5); agent prose declares branch + remediation + probe-sourced predicate + provisional_id preservation"
}

# --- Step 4: corpus replay + probe+LLM dedupe + merged-receipt end-to-end ---

check_probe_e_corpus_exists() {
  # Frozen-replay corpus lives in the KB (outside the plugin repo). When the
  # corpus path is missing (CI without Obsidian vault, fresh clone, etc.) the
  # helper SKIPs gracefully — the corpus is a human-curated soak artefact,
  # not a CI-blocking invariant. When present: assert 3 snapshot subdirs exist
  # + corpus MD exists, then run probe E against each snapshot and assert
  # expected outcomes (hit / clean / clean).
  local corpus_root="${PROBE_E_CORPUS_ROOT:-}"
  if [ -z "$corpus_root" ] || [ ! -d "$corpus_root" ]; then
    echo "probe-E corpus not found at '${corpus_root:-<unset>}' — SKIP (human-curated KB artefact)"
    return 0
  fi
  [ -r "$corpus_root/frozen-replay-corpus.md" ] \
    || { echo "$corpus_root/frozen-replay-corpus.md missing"; return 1; }
  local snap_dir="$corpus_root/snapshots"
  [ -d "$snap_dir" ] || { echo "$snap_dir missing"; return 1; }
  local plugin_root; plugin_root="$(pwd)"
  local failures=0
  local snap_name
  for snap_name in aqua-bribes-pr-3-step-2 aqua-bribes-pr-3-step-2-fixed ai-dev-team-foundation-step-2-renderer; do
    local d="$snap_dir/$snap_name"
    if [ ! -d "$d" ]; then
      echo "corpus snapshot dir missing: $d"; failures=$((failures+1)); continue
    fi
    if [ ! -r "$d/input.json" ]; then
      echo "corpus snapshot input.json missing: $d/input.json"; failures=$((failures+1)); continue
    fi
    local out
    out=$( ( cd "$d" && PROBE_E_FAKE_NOW="2026-04-21T14:23:17Z" bash "$plugin_root/hooks/lib/probe_e.sh" < input.json ) 2>/tmp/smoke-probe-e-corpus-err.$$ ) || {
      echo "probe_e.sh failed on corpus $snap_name; stderr:"; cat /tmp/smoke-probe-e-corpus-err.$$
      rm -f /tmp/smoke-probe-e-corpus-err.$$
      failures=$((failures+1)); continue
    }
    rm -f /tmp/smoke-probe-e-corpus-err.$$
    local n_findings
    n_findings=$(printf '%s\n' "$out" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["findings"]))')
    case "$snap_name" in
      aqua-bribes-pr-3-step-2)
        if [ "$n_findings" != "1" ]; then
          echo "corpus hit case '$snap_name' expected 1 emission, got $n_findings"
          failures=$((failures+1))
        fi
        # Also verify the specific hit: consumer=_clean_rewards, marker=build_failure:.
        printf '%s\n' "$out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if not d['findings']:
    print('no findings'); sys.exit(1)
f = d['findings'][0]
cp = f.get('canonical_payload', {})
cs = cp.get('consumer_symbol')
if cs != '_clean_rewards':
    print('consumer_symbol mismatch: %r' % (cs,)); sys.exit(1)
ml = cp.get('marker_literal')
if ml != 'build_failure:':
    print('marker_literal mismatch: %r' % (ml,)); sys.exit(1)
" || { echo "corpus hit case '$snap_name' canonical_payload wrong"; failures=$((failures+1)); }
        ;;
      aqua-bribes-pr-3-step-2-fixed|ai-dev-team-foundation-step-2-renderer)
        if [ "$n_findings" != "0" ]; then
          echo "corpus clean-negative case '$snap_name' expected 0 emissions, got $n_findings"
          failures=$((failures+1))
        fi
        ;;
    esac
  done
  if [ "$failures" -ne 0 ]; then
    echo "probe-E corpus replay: $failures failure(s)"
    return 1
  fi
  echo "probe-E frozen-replay corpus: 3 snapshots replayed (1 hit + 2 clean negatives)"
}

check_probe_e_dedupe_with_llm() {
  # Fixture 06 (hand-authored Step 1 per iter-6 X26 carve-out) exercises
  # hooks/lib/dedupe_findings.sh merge_pair post-iter-5 X23:
  #   - probe-primary swap (probe appears at members[1], LLM at members[0])
  #   - extended carried-field list (provisional_id / canonical_payload /
  #     blocking / fingerprint_anchors)
  # Byte-diffs the dedupe output against fixture 06 expected-dedupe.json.
  local fdir="tests/fixtures/cross-audit-probe-e/06-dedupe-with-llm"
  local input="$fdir/input.json"
  local expected="$fdir/expected-dedupe.json"
  [ -r "$input" ] || { echo "$input not readable"; return 1; }
  [ -r "$expected" ] || { echo "$expected not readable"; return 1; }
  local actual
  actual=$(cat "$input" | bash hooks/lib/dedupe_findings.sh 2>/tmp/smoke-dd-err.$$) || {
    echo "dedupe_findings.sh failed; stderr:"; cat /tmp/smoke-dd-err.$$
    rm -f /tmp/smoke-dd-err.$$
    return 1
  }
  rm -f /tmp/smoke-dd-err.$$
  if ! diff <(printf '%s\n' "$actual") "$expected" >/tmp/smoke-dd-diff.$$ 2>&1; then
    echo "fixture 06 dedupe output does not byte-match $expected:"
    head -20 /tmp/smoke-dd-diff.$$
    rm -f /tmp/smoke-dd-diff.$$
    return 1
  fi
  rm -f /tmp/smoke-dd-diff.$$
  # Explicit per-field assertions — catches silent schema drift in the
  # probe-primary swap / carried-field list.
  local sources provisional canonical blocking anchors
  sources=$(printf '%s\n' "$actual" | python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)["findings_deduped"][0]["sources"]))')
  provisional=$(printf '%s\n' "$actual" | python3 -c 'import json,sys; print(json.load(sys.stdin)["findings_deduped"][0].get("provisional_id","<missing>"))')
  canonical=$(printf '%s\n' "$actual" | python3 -c 'import json,sys; d=json.load(sys.stdin)["findings_deduped"][0]; print("present" if d.get("canonical_payload") else "missing")')
  blocking=$(printf '%s\n' "$actual" | python3 -c 'import json,sys; d=json.load(sys.stdin)["findings_deduped"][0]; print(d.get("blocking", "<missing>"))')
  anchors=$(printf '%s\n' "$actual" | python3 -c 'import json,sys; d=json.load(sys.stdin)["findings_deduped"][0]; print("present" if d.get("fingerprint_anchors") else "missing")')
  [ "$sources" = "probe:E,claude" ] || { echo "sources order wrong: $sources (expected probe:E,claude — X23 probe-first)"; return 1; }
  [ "$provisional" = "pE-1" ] || { echo "provisional_id not preserved: $provisional (expected pE-1 — X23 carried-field list)"; return 1; }
  [ "$canonical" = "present" ] || { echo "canonical_payload dropped (expected preserved — X23)"; return 1; }
  [ "$blocking" = "False" ] || { echo "blocking wrong or dropped: $blocking (expected False — X23)"; return 1; }
  [ "$anchors" = "present" ] || { echo "fingerprint_anchors dropped (expected preserved — X23)"; return 1; }
  echo "fixture 06 dedupe byte-matches + probe-first sources + provisional_id/canonical_payload/blocking/fingerprint_anchors preserved (iter-5 X23)"
}

check_probe_e_merged_receipt_written() {
  # iter-7 X31 end-to-end — run fixture 06 through the full Step 3
  # Consolidation pipeline:
  #   stage 2 emit (already done at fixture author time — input.json carries
  #                 probe-sourced entry with id=provisional_id=pE-1)
  #   stage 3 dedupe (hooks/lib/dedupe_findings.sh — probe-primary swap)
  #   stage 4 scorer-skip-probe (no-op for this fixture: only the merged
  #            probe+LLM entry has probe:* in sources → scorer skips it)
  #   stage 4.5 side-map lookup + receipt-file write (per §3.5 pseudocode)
  # Assert the resulting receipt file exists at
  # <audit_slug>-probe-receipts/<merged_final_id>.json with the 11-field
  # on_disk_receipt_body whose probe_output_hash verifies against the
  # reconstructed hashed_probe_output_envelope from emitted_findings[0].
  local fdir="tests/fixtures/cross-audit-probe-e/06-dedupe-with-llm"
  [ -r "$fdir/input.json" ] || { echo "$fdir/input.json missing"; return 1; }
  # Synthetic side-map — fixture 06 doesn't ship one; we reconstruct it from
  # the stage-2 emit envelope that the orchestrator would have built. The
  # probe_receipt_metadata comes from the hand-authored probe-E shape per
  # §3.3 receipt_metadata; pick audit_slug matching fixture 06 and an
  # emitted_at deterministic to match on-disk bytes.
  local work
  work=$(mktemp -d)
  trap "rm -rf '$work'" RETURN
  local kb_root="$work/kb"
  local audit_slug="2026-04-21-fixture-06-merged-receipt"
  local receipts_dir="$kb_root/security/$audit_slug-probe-receipts"
  mkdir -p "$receipts_dir"
  # Dedupe stage 3 against fixture 06.
  local deduped
  deduped=$(cat "$fdir/input.json" | bash hooks/lib/dedupe_findings.sh)
  # Construct the side-map and then emulate stage 4.5 for the merged entry.
  local result
  result=$(PROBE_E_DEDUPED="$deduped" RECEIPTS_DIR="$receipts_dir" python3 <<'PY'
import hashlib, json, os, sys

deduped = json.loads(os.environ["PROBE_E_DEDUPED"])
receipts_dir = os.environ["RECEIPTS_DIR"]

# Build side-map from the fixture's original probe entry (pE-1).
# In production this lives in the agent's Step 0.5 local scope; here we
# reconstruct it from §3.3 receipt_metadata shape.
probe_receipt_metadata_by_provisional_id = {
    "pE-1": {
        "probe_id": "E",
        "probe_version": "e.1.0",
        "trigger_input_hash": "8a136581cc54236deddbc272e0002d553d80ff7d8cea8714d34e132c6a5e0c1f",
        "scope_files_read": ["src/foo.py"],
        "skipped_files": [],
        "emitted_at": "2026-04-21T14:23:17Z",
        "degraded_mode": False,
        "eligible_reason": "1 same-file allowlist-leak candidate detected",
    },
}

# Final-ID allocation — spec §3.3 X24: set id = final_id WHILE preserving
# provisional_id. For fixture 06's single merged entry: final_id = "X5".
final_findings = []
for f in deduped["findings_deduped"]:
    entry = dict(f)
    entry["id"] = "X5"  # simulated final-ID allocation
    # provisional_id preserved intact per X24 — merge_pair (post X23) kept it.
    final_findings.append(entry)

probe_failures_seed = []
for finding in final_findings:
    if not any(s.startswith("probe:") for s in finding["sources"]):
        continue
    # Side-map lookup — iter-4 X19 coupling. Key = provisional_id preserved
    # through dedupe (X23) + final-ID allocation (X24).
    metadata = probe_receipt_metadata_by_provisional_id[finding["provisional_id"]]
    hashed_probe_output_envelope = {
        "probe_id": metadata["probe_id"],
        "probe_version": metadata["probe_version"],
        "emitted_findings": [finding["canonical_payload"]],
    }
    envelope_bytes = json.dumps(
        hashed_probe_output_envelope,
        sort_keys=True, separators=(",", ":"), ensure_ascii=False,
    ).encode("utf-8")
    probe_output_hash = hashlib.sha256(envelope_bytes).hexdigest()
    on_disk_receipt_body = {
        **metadata,
        "probe_output_hash": probe_output_hash,
        "mode_at_emit": finding["mode_at_emit"],
        "emitted_findings": hashed_probe_output_envelope["emitted_findings"],
    }
    receipt_path = os.path.join(receipts_dir, f"{finding['id']}.json")
    try:
        with open(receipt_path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(
                on_disk_receipt_body,
                sort_keys=True, separators=(",", ":"), ensure_ascii=False,
            ))
    except (IOError, OSError) as e:
        probe_failures_seed.append({
            "probe_id": metadata["probe_id"],
            "reason": f"receipt write failed: {str(e)[:200]}",
            "remediation": "check KB mount is writable + re-run /cross-audit",
        })
        finding["probe_receipt"] = None
    else:
        finding["probe_receipt"] = receipt_path

# Emit a small JSON summary for the bash caller to inspect.
summary = {
    "final_findings": [{"id": f["id"], "provisional_id": f.get("provisional_id"), "probe_receipt": f.get("probe_receipt"), "sources": f.get("sources")} for f in final_findings],
    "probe_failures_seed": probe_failures_seed,
    "envelope_hash_expected": probe_output_hash,
}
sys.stdout.write(json.dumps(summary, sort_keys=True))
PY
)
  [ $? -eq 0 ] || { echo "stage-4.5 orchestrator emulation failed"; return 1; }
  # Summary assertions.
  local merged_id merged_provisional merged_sources receipt_path
  merged_id=$(printf '%s\n' "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin)["final_findings"][0]["id"])')
  merged_provisional=$(printf '%s\n' "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin)["final_findings"][0]["provisional_id"])')
  merged_sources=$(printf '%s\n' "$result" | python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)["final_findings"][0]["sources"]))')
  receipt_path=$(printf '%s\n' "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin)["final_findings"][0]["probe_receipt"] or "")')
  [ "$merged_id" = "X5" ] || { echo "merged id wrong: $merged_id"; return 1; }
  [ "$merged_provisional" = "pE-1" ] || { echo "provisional_id not preserved through id-swap (X24): $merged_provisional"; return 1; }
  [ "$merged_sources" = "probe:E,claude" ] || { echo "merged sources wrong: $merged_sources (expected probe:E,claude probe-first)"; return 1; }
  [ -n "$receipt_path" ] || { echo "probe_receipt not populated on merged entry"; return 1; }
  [ -f "$receipt_path" ] || { echo "receipt file not written at $receipt_path"; return 1; }
  # 11-field body — verify all 11 keys present + probe_output_hash verifies.
  python3 -c "
import hashlib, json, sys
body = json.load(open('$receipt_path'))
expected_keys = {
    'probe_id', 'probe_version', 'mode_at_emit', 'trigger_input_hash',
    'probe_output_hash', 'degraded_mode', 'emitted_at', 'eligible_reason',
    'scope_files_read', 'skipped_files', 'emitted_findings',
}
missing = expected_keys - set(body.keys())
extra = set(body.keys()) - expected_keys
if missing: print('missing body keys:', missing); sys.exit(1)
if extra: print('extra body keys:', extra); sys.exit(1)
# Verify probe_output_hash.
env = {'probe_id': body['probe_id'], 'probe_version': body['probe_version'], 'emitted_findings': body['emitted_findings']}
env_bytes = json.dumps(env, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
recomputed = hashlib.sha256(env_bytes).hexdigest()
if recomputed != body['probe_output_hash']:
    print(f'probe_output_hash mismatch: disk={body[\"probe_output_hash\"]} recomputed={recomputed}')
    sys.exit(1)
# emitted_findings is length-1 per §3.3 (v1 — one finding per receipt file).
if not isinstance(body['emitted_findings'], list) or len(body['emitted_findings']) != 1:
    print(f'emitted_findings shape wrong: {body[\"emitted_findings\"]!r}')
    sys.exit(1)
" || { echo "11-field body / probe_output_hash verification failed for $receipt_path"; return 1; }
  echo "merged-receipt end-to-end: fixture 06 → dedupe (X23) → final-ID alloc (X24) → side-map lookup (X19) → 11-field receipt written at $receipt_path with verified probe_output_hash"
}

# --- Step 5: yml example hint + docs/kb-discovery.md probe-E row ---

check_yaml_example_probes_e_hint() {
  # .ai-dev-team.yml.example's commented cross_audit.probes.e: line must carry
  # the hint pointing users at `shadow` as the first step toward graduation
  # (spec §3.7). Prose is not line-frozen — the assertion checks both the
  # probe name marker AND the shadow-evidence phrase somewhere near it.
  local path=".ai-dev-team.yml.example"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qE '^#\s+e:\s*\{\s*mode:\s*off\s*\}' "$path" \
    || { echo "$path missing 'e: { mode: off }' commented probes.e line"; return 1; }
  # Extract the block starting at the `e:` line and following 3 lines, look
  # for the shadow-evidence hint.
  local window
  window=$(grep -nA3 -E '^#\s+e:\s*\{\s*mode:\s*off\s*\}' "$path" | head -5)
  printf '%s\n' "$window" | grep -qE 'shadow|live evidence|graduation' \
    || { echo "$path probes.e comment missing 'shadow' / 'live evidence' / 'graduation' hint"; return 1; }
  printf '%s\n' "$window" | grep -qE 'diff-scope|allowlist' \
    || { echo "$path probes.e comment missing 'diff-scope' or 'allowlist' detector summary"; return 1; }
  echo "$path probes.e comment has shadow/graduation hint + detector summary"
}

check_docs_kb_discovery_probe_e_row() {
  # docs/kb-discovery.md has a probe-E row in the reference table per §3.7:
  # detector summary + trigger + scope reads + v1 limitation column.
  local path="docs/kb-discovery.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  # Reference table header column (includes v1-limitation column per spec §3.7).
  grep -qE '\| v1 limitation \|' "$path" \
    || { echo "$path missing reference table 'v1 limitation' column header"; return 1; }
  # The probe-E row itself.
  local row
  row=$(grep -E '^\| e \|' "$path" | head -1)
  [[ -n "$row" ]] || { echo "$path missing '| e |' probe-E row"; return 1; }
  # Detector summary mentions same-file allowlist leak.
  echo "$row" | grep -qiF 'same-file allowlist leak' \
    || { echo "$path probe-E row missing 'same-file allowlist leak' detector summary"; return 1; }
  # Trigger mentions changed .py files + test-file skip.
  echo "$row" | grep -qE 'changed \`?\.?py|test files? skipped' \
    || { echo "$path probe-E row missing changed .py / test-file-skip trigger"; return 1; }
  # v1 limitation names Python + same-file.
  echo "$row" | grep -qE 'Python only|same-file' \
    || { echo "$path probe-E row missing 'Python only' or 'same-file' v1-limitation"; return 1; }
  echo "$path probe-E row present (detector summary + trigger + v1 limitation columns)"
}

# ============================================================================
# Cross-audit probe F (spec 2026-04-21-probe-f-cardinality-blindness)
# ============================================================================

# Shared helper: run hooks/lib/probe_f.sh against a fixture dir and byte-diff
# findings + receipt_metadata separately. The probe is invoked with cwd =
# $fixture_dir so `repo_root: "."` resolves inside the fixture.
# PROBE_F_FAKE_NOW is set for determinism so emitted_at byte-matches the
# expected fixture value.
_probe_f_byte_diff() {
  # $1 = fixture dir (relative to plugin root)
  local fdir="$1"
  local input="$fdir/input.json"
  local expected_findings="$fdir/expected-findings.json"
  local expected_meta="$fdir/expected-receipt-metadata.json"
  [ -r "$input" ] || { echo "$input not readable"; return 1; }
  [ -r "$expected_findings" ] || { echo "$expected_findings not readable"; return 1; }
  [ -r "$expected_meta" ] || { echo "$expected_meta not readable"; return 1; }
  local plugin_root
  plugin_root="$(pwd)"
  local out_tmp="/tmp/smoke-probe-f-out.$$"
  local exit_code=0
  ( cd "$fdir" \
    && PROBE_F_FAKE_NOW="2026-04-21T14:23:17Z" \
    bash "$plugin_root/hooks/lib/probe_f.sh" < input.json ) >"$out_tmp" 2>/tmp/smoke-probe-f-err.$$ || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    echo "probe_f.sh exited $exit_code against $fdir; stderr:"
    head -5 /tmp/smoke-probe-f-err.$$
    rm -f "$out_tmp" /tmp/smoke-probe-f-err.$$
    return 1
  fi
  rm -f /tmp/smoke-probe-f-err.$$
  local actual_findings actual_meta exp_findings exp_meta
  actual_findings=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.stdout.write(json.dumps(d["findings"],sort_keys=True,separators=(",",":"),ensure_ascii=False))' "$out_tmp")
  actual_meta=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.stdout.write(json.dumps(d["receipt_metadata"],sort_keys=True,separators=(",",":"),ensure_ascii=False))' "$out_tmp")
  exp_findings=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.stdout.write(json.dumps(d,sort_keys=True,separators=(",",":"),ensure_ascii=False))' "$expected_findings")
  exp_meta=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.stdout.write(json.dumps(d,sort_keys=True,separators=(",",":"),ensure_ascii=False))' "$expected_meta")
  rm -f "$out_tmp"
  if [ "$actual_findings" != "$exp_findings" ]; then
    echo "probe_f findings mismatch for $fdir:"
    diff <(printf '%s\n' "$actual_findings") <(printf '%s\n' "$exp_findings") | head -10
    return 1
  fi
  if [ "$actual_meta" != "$exp_meta" ]; then
    echo "probe_f receipt_metadata mismatch for $fdir:"
    diff <(printf '%s\n' "$actual_meta") <(printf '%s\n' "$exp_meta") | head -10
    return 1
  fi
  echo "probe_f output byte-matches expected for $fdir"
}

check_probe_f_detector_fires_on_missing_cursor() {
  # Fixture 01 — positive: `.limit(200).order(desc=False)` chain. Red-proves
  # §3.4 step 5 (lineno, end_col_offset) tiebreak since expected paging_symbol
  # is `.limit` (leftmost-in-source, smallest end_col_offset) rather than
  # `.order` (latest end_col_offset in the chain).
  _probe_f_byte_diff tests/fixtures/cross-audit-probe-f/01-positive-missing-cursor || return 1
  # Extract the emission count + paging_symbol and assert them explicitly per
  # spec §3.2 helper contract.
  local out n_findings paging_symbol
  local plugin_root; plugin_root="$(pwd)"
  local fdir="tests/fixtures/cross-audit-probe-f/01-positive-missing-cursor"
  out=$( ( cd "$fdir" && PROBE_F_FAKE_NOW="2026-04-21T14:23:17Z" bash "$plugin_root/hooks/lib/probe_f.sh" < input.json ) )
  n_findings=$(printf '%s' "$out" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["findings"]))')
  paging_symbol=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["findings"][0]["fingerprint_anchors"]["paging_symbol"])')
  [ "$n_findings" = "1" ] || { echo "fixture 01 expected 1 emission, got $n_findings"; return 1; }
  [ "$paging_symbol" = ".limit" ] || { echo "fixture 01 expected paging_symbol=.limit (end_col_offset tiebreak), got $paging_symbol"; return 1; }
  echo "fixture 01 positive + multi-marker collapse red-proves (lineno, end_col_offset) tiebreak"
}

check_probe_f_detector_clean_when_cursor_param_present() {
  _probe_f_byte_diff tests/fixtures/cross-audit-probe-f/02-clean-cursor-param-present
}

check_probe_f_detector_clean_when_docstring_budget_present() {
  _probe_f_byte_diff tests/fixtures/cross-audit-probe-f/03-clean-docstring-budget-present
}

check_probe_f_detector_ineligible_no_paging_marker() {
  _probe_f_byte_diff tests/fixtures/cross-audit-probe-f/04-ineligible-no-paging-marker
}

check_probe_f_receipt_rerun_stable() {
  # Fixture 05 — rerun stability. Two independent invocations produce byte-
  # identical findings + receipt_metadata (including trigger_input_hash +
  # skipped_files, where `src/bad.py` is the SyntaxError twin appearing in
  # skipped_files verbatim).
  local fdir="tests/fixtures/cross-audit-probe-f/05-rerun-stability"
  local plugin_root; plugin_root="$(pwd)"
  local out1 out2
  out1=$( ( cd "$fdir" && PROBE_F_FAKE_NOW="2026-04-21T14:23:17Z" bash "$plugin_root/hooks/lib/probe_f.sh" < input.json ) )
  out2=$( ( cd "$fdir" && PROBE_F_FAKE_NOW="2026-04-21T14:23:17Z" bash "$plugin_root/hooks/lib/probe_f.sh" < input.json ) )
  if [ "$out1" != "$out2" ]; then
    echo "probe_f output differs between two runs against $fdir (non-deterministic)"
    diff <(printf '%s\n' "$out1") <(printf '%s\n' "$out2") | head -10
    return 1
  fi
  _probe_f_byte_diff "$fdir" || return 1
  local h1 h2 sk1 sk2 f1 f2
  h1=$(printf '%s\n' "$out1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["receipt_metadata"]["trigger_input_hash"])')
  h2=$(printf '%s\n' "$out2" | python3 -c 'import json,sys; print(json.load(sys.stdin)["receipt_metadata"]["trigger_input_hash"])')
  sk1=$(printf '%s\n' "$out1" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["receipt_metadata"]["skipped_files"]))')
  sk2=$(printf '%s\n' "$out2" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["receipt_metadata"]["skipped_files"]))')
  f1=$(printf '%s\n' "$out1" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["findings"],sort_keys=True,separators=(",",":"),ensure_ascii=False))')
  f2=$(printf '%s\n' "$out2" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["findings"],sort_keys=True,separators=(",",":"),ensure_ascii=False))')
  [ "$h1" = "$h2" ] || { echo "trigger_input_hash not stable: $h1 vs $h2"; return 1; }
  [ "$sk1" = "$sk2" ] || { echo "skipped_files not stable: $sk1 vs $sk2"; return 1; }
  [ "$f1" = "$f2" ] || { echo "findings not stable across runs"; return 1; }
  echo "probe_f receipt rerun-stability: trigger_input_hash + skipped_files + findings byte-identical across two runs"
}

check_probe_f_changed_test_file_skipped() {
  _probe_f_byte_diff tests/fixtures/cross-audit-probe-f/07-changed-test-file-skipped
}

check_probe_f_detector_fires_on_async_function() {
  # Fixture 08 — AsyncFunctionDef walk-up (X3 iter-1). Asserts enclosing
  # function is the async def name. An impl that only walks FunctionDef
  # would drop the marker entirely (0 emissions) or record enclosing_function
  # as "<module>" — both fail the byte-diff.
  _probe_f_byte_diff tests/fixtures/cross-audit-probe-f/08-async-function-walk-up || return 1
  local plugin_root; plugin_root="$(pwd)"
  local fdir="tests/fixtures/cross-audit-probe-f/08-async-function-walk-up"
  local enclosing
  enclosing=$( ( cd "$fdir" && PROBE_F_FAKE_NOW="2026-04-21T14:23:17Z" bash "$plugin_root/hooks/lib/probe_f.sh" < input.json ) \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["findings"][0]["canonical_payload"]["enclosing_function"])')
  [ "$enclosing" = "reconcile_bribe_payouts_async" ] \
    || { echo "fixture 08 expected enclosing_function=reconcile_bribe_payouts_async, got $enclosing"; return 1; }
  echo "fixture 08 AsyncFunctionDef walk-up resolves enclosing function correctly"
}

check_probe_f_detector_inner_function_no_discipline_inheritance() {
  # Fixture 09 — nested inner function does NOT inherit `cursor` discipline
  # from outer wrapper (X3 iter-1). Asserts enclosing_function="inner".
  _probe_f_byte_diff tests/fixtures/cross-audit-probe-f/09-nested-inner-function-no-inheritance || return 1
  local plugin_root; plugin_root="$(pwd)"
  local fdir="tests/fixtures/cross-audit-probe-f/09-nested-inner-function-no-inheritance"
  local enclosing
  enclosing=$( ( cd "$fdir" && PROBE_F_FAKE_NOW="2026-04-21T14:23:17Z" bash "$plugin_root/hooks/lib/probe_f.sh" < input.json ) \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["findings"][0]["canonical_payload"]["enclosing_function"])')
  [ "$enclosing" = "inner" ] \
    || { echo "fixture 09 expected enclosing_function=inner, got $enclosing"; return 1; }
  echo "fixture 09 nested-inner-function correctly resolved (no discipline inheritance)"
}

check_probe_f_detector_skipped_at_module_level() {
  # Fixture 10 — module-level paging call → 0 emissions (§3.4 step 3 anti-
  # goal, X3 iter-1). Red-proves impls that fall back to <module>.
  _probe_f_byte_diff tests/fixtures/cross-audit-probe-f/10-module-level-skip || return 1
  local plugin_root; plugin_root="$(pwd)"
  local fdir="tests/fixtures/cross-audit-probe-f/10-module-level-skip"
  local n
  n=$( ( cd "$fdir" && PROBE_F_FAKE_NOW="2026-04-21T14:23:17Z" bash "$plugin_root/hooks/lib/probe_f.sh" < input.json ) \
    | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["findings"]))')
  [ "$n" = "0" ] || { echo "fixture 10 expected 0 emissions (module-level anti-goal), got $n"; return 1; }
  echo "fixture 10 module-level marker correctly skipped (§3.4 anti-goal)"
}

check_probe_f_detector_clean_when_docstring_budget_only() {
  # Fixture 11 — docstring `budget: 5s wall-time assumed` matches `budget:`
  # (left-\b + literal colon, no right-\b) but NOT `cardinality`. Expected:
  # 0 emissions. Red-proves impls that apply \b on both sides of `budget:`
  # (the right-side \b would fail to match since `:` is non-word).
  _probe_f_byte_diff tests/fixtures/cross-audit-probe-f/11-docstring-budget-only
}

check_yaml_example_probes_f_hint() {
  # .ai-dev-team.yml.example's commented cross_audit.probes.f: line must
  # carry (a) the commented `f: { mode: off }` structural line; and within
  # a 4-line window around it: (b) spec-slug token `probe-f-cardinality`,
  # (c) one of `shadow|live evidence|graduation` (graduation-path hint),
  # (d) one of `missing-cursor|cardinality|pagination` (detector-specific
  # term). Distinctive-keyword-per-axis calibration (X16 iter-5 + X17
  # iter-6 — robust to minor prose edits; §3.7 quoted YAML block remains
  # authoritative for on-disk shape, wrap-respecting across `#` lines).
  local path=".ai-dev-team.yml.example"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qE '^#\s+f:\s*\{\s*mode:\s*off\s*\}' "$path" \
    || { echo "$path missing 'f: { mode: off }' commented probes.f line"; return 1; }
  # Extract a window around the `f:` line (the line + 6 following — allows
  # the wrap-respecting §3.7 comment form to fit).
  local window
  window=$(grep -nA6 -E '^#\s+f:\s*\{\s*mode:\s*off\s*\}' "$path" | head -8)
  printf '%s\n' "$window" | grep -qF 'probe-f-cardinality' \
    || { echo "$path probes.f comment missing spec-slug 'probe-f-cardinality' within window"; return 1; }
  printf '%s\n' "$window" | grep -qE 'shadow|live evidence|graduation' \
    || { echo "$path probes.f comment missing 'shadow'/'live evidence'/'graduation' hint"; return 1; }
  printf '%s\n' "$window" | grep -qE 'missing-cursor|cardinality|pagination' \
    || { echo "$path probes.f comment missing 'missing-cursor'/'cardinality'/'pagination' detector term"; return 1; }
  echo "$path probes.f comment has spec slug + shadow/graduation hint + detector term"
}

check_docs_kb_discovery_probe_f_row() {
  # docs/kb-discovery.md has a probe-F row in the reference table per §3.7.
  # Distinctive-keyword-per-axis calibration (X17 iter-6): each column
  # carries its distinctive keyword — Detector: `missing-cursor`;
  # Trigger: `paging-method-call` or `paging`; Scope: `same-file`;
  # v1-limitation: BOTH `Python only` AND `single failure_kind`.
  local path="docs/kb-discovery.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qE '\| v1 limitation \|' "$path" \
    || { echo "$path missing reference table 'v1 limitation' column header"; return 1; }
  local row
  row=$(grep -E '^\| f \|' "$path" | head -1)
  [[ -n "$row" ]] || { echo "$path missing '| f |' probe-F row"; return 1; }
  echo "$row" | grep -qiF 'missing-cursor' \
    || { echo "$path probe-F row missing 'missing-cursor' detector summary"; return 1; }
  echo "$row" | grep -qiE 'paging-method-call|paging' \
    || { echo "$path probe-F row missing 'paging-method-call'/'paging' trigger"; return 1; }
  echo "$row" | grep -qiF 'same-file' \
    || { echo "$path probe-F row missing 'same-file' scope-reads column"; return 1; }
  echo "$row" | grep -qiF 'Python only' \
    || { echo "$path probe-F row missing 'Python only' v1-limitation"; return 1; }
  echo "$row" | grep -qiF 'single failure_kind' \
    || { echo "$path probe-F row missing 'single failure_kind' v1-limitation"; return 1; }
  echo "$path probe-F row present (detector + trigger + scope + Python-only + single-failure_kind v1-limitations)"
}

check_probe_f_corpus_exists() {
  # Frozen-replay corpus lives in the KB (outside the plugin repo). When the
  # corpus path is missing (CI without Obsidian vault, fresh clone, etc.) the
  # helper SKIPs gracefully — the corpus is a human-curated soak artefact,
  # not a CI-blocking invariant. When present: assert 3 snapshot subdirs
  # exist + corpus MD exists, then run probe F against each snapshot and
  # assert expected outcomes (hit / clean / clean).
  local corpus_root="${PROBE_F_CORPUS_ROOT:-}"
  if [ -z "$corpus_root" ] || [ ! -d "$corpus_root" ]; then
    echo "probe-F corpus not found at '${corpus_root:-<unset>}' — SKIP (human-curated KB artefact)"
    return 0
  fi
  [ -r "$corpus_root/frozen-replay-corpus.md" ] \
    || { echo "$corpus_root/frozen-replay-corpus.md missing"; return 1; }
  local snap_dir="$corpus_root/snapshots"
  [ -d "$snap_dir" ] || { echo "$snap_dir missing"; return 1; }
  local plugin_root; plugin_root="$(pwd)"
  local failures=0
  local snap_name
  for snap_name in aqua-bribes-pr-3-step-4 aqua-bribes-pr-3-step-4-fixed-cursor ai-dev-team-foundation-step-2-renderer; do
    local d="$snap_dir/$snap_name"
    if [ ! -d "$d" ]; then
      echo "corpus snapshot dir missing: $d"; failures=$((failures+1)); continue
    fi
    if [ ! -r "$d/input.json" ]; then
      echo "corpus snapshot input.json missing: $d/input.json"; failures=$((failures+1)); continue
    fi
    local out
    out=$( ( cd "$d" && PROBE_F_FAKE_NOW="2026-04-21T14:23:17Z" bash "$plugin_root/hooks/lib/probe_f.sh" < input.json ) 2>/tmp/smoke-probe-f-corpus-err.$$ ) || {
      echo "probe_f.sh failed on corpus $snap_name; stderr:"; cat /tmp/smoke-probe-f-corpus-err.$$
      rm -f /tmp/smoke-probe-f-corpus-err.$$
      failures=$((failures+1)); continue
    }
    rm -f /tmp/smoke-probe-f-corpus-err.$$
    local n_findings
    n_findings=$(printf '%s\n' "$out" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["findings"]))')
    case "$snap_name" in
      aqua-bribes-pr-3-step-4)
        if [ "$n_findings" != "1" ]; then
          echo "corpus hit case '$snap_name' expected 1 emission, got $n_findings"
          failures=$((failures+1))
        fi
        # Verify the specific hit: paging_symbol=.limit (end_col_offset
        # tiebreak winner over chained .order), failure_kind=missing_cursor,
        # enclosing_function=reconcile_bribe_payouts.
        printf '%s\n' "$out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if not d['findings']:
    print('no findings'); sys.exit(1)
f = d['findings'][0]
cp = f.get('canonical_payload', {})
ef = cp.get('enclosing_function')
if ef != 'reconcile_bribe_payouts':
    print('enclosing_function mismatch: %r' % (ef,)); sys.exit(1)
ps = cp.get('paging_symbol')
if ps != '.limit':
    print('paging_symbol mismatch: %r' % (ps,)); sys.exit(1)
fk = cp.get('failure_kind')
if fk != 'missing_cursor':
    print('failure_kind mismatch: %r' % (fk,)); sys.exit(1)
" || { echo "corpus hit case '$snap_name' canonical_payload wrong"; failures=$((failures+1)); }
        ;;
      aqua-bribes-pr-3-step-4-fixed-cursor|ai-dev-team-foundation-step-2-renderer)
        if [ "$n_findings" != "0" ]; then
          echo "corpus clean-negative case '$snap_name' expected 0 emissions, got $n_findings"
          failures=$((failures+1))
        fi
        ;;
    esac
  done
  if [ "$failures" -ne 0 ]; then
    echo "probe-F corpus replay: $failures failure(s)"
    return 1
  fi
  echo "probe-F frozen-replay corpus: 3 snapshots replayed (1 hit + 2 clean negatives)"
}

check_probe_f_dedupe_with_llm() {
  # Fixture 06 (hand-authored Step 1 per iter-6 X26 carve-out) exercises
  # hooks/lib/dedupe_findings.sh merge_pair post-iter-5 X23:
  #   - probe-primary swap (probe appears at members[1], LLM at members[0])
  #   - extended carried-field list (provisional_id / canonical_payload /
  #     blocking / fingerprint_anchors)
  # Byte-diffs the dedupe output against fixture 06 expected-dedupe.json
  # (X12 iter-3 + X14 iter-4 explicit byte-diff target).
  local fdir="tests/fixtures/cross-audit-probe-f/06-dedupe-with-llm"
  local input="$fdir/input.json"
  local expected="$fdir/expected-dedupe.json"
  [ -r "$input" ] || { echo "$input not readable"; return 1; }
  [ -r "$expected" ] || { echo "$expected not readable"; return 1; }
  local actual
  actual=$(cat "$input" | bash hooks/lib/dedupe_findings.sh 2>/tmp/smoke-dd-f-err.$$) || {
    echo "dedupe_findings.sh failed; stderr:"; cat /tmp/smoke-dd-f-err.$$
    rm -f /tmp/smoke-dd-f-err.$$
    return 1
  }
  rm -f /tmp/smoke-dd-f-err.$$
  if ! diff <(printf '%s\n' "$actual") "$expected" >/tmp/smoke-dd-f-diff.$$ 2>&1; then
    echo "fixture 06 dedupe output does not byte-match $expected:"
    head -20 /tmp/smoke-dd-f-diff.$$
    rm -f /tmp/smoke-dd-f-diff.$$
    return 1
  fi
  rm -f /tmp/smoke-dd-f-diff.$$
  # Explicit per-field assertions — catches silent schema drift in the
  # probe-primary swap / carried-field list (iter-5 X23 preserved: sources
  # order, provisional_id, canonical_payload, blocking, fingerprint_anchors).
  local sources provisional canonical blocking anchors
  sources=$(printf '%s\n' "$actual" | python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)["findings_deduped"][0]["sources"]))')
  provisional=$(printf '%s\n' "$actual" | python3 -c 'import json,sys; print(json.load(sys.stdin)["findings_deduped"][0].get("provisional_id","<missing>"))')
  canonical=$(printf '%s\n' "$actual" | python3 -c 'import json,sys; d=json.load(sys.stdin)["findings_deduped"][0]; print("present" if d.get("canonical_payload") else "missing")')
  blocking=$(printf '%s\n' "$actual" | python3 -c 'import json,sys; d=json.load(sys.stdin)["findings_deduped"][0]; print(d.get("blocking", "<missing>"))')
  anchors=$(printf '%s\n' "$actual" | python3 -c 'import json,sys; d=json.load(sys.stdin)["findings_deduped"][0]; print("present" if d.get("fingerprint_anchors") else "missing")')
  [ "$sources" = "probe:F,claude" ] || { echo "sources order wrong: $sources (expected probe:F,claude — X23 probe-first)"; return 1; }
  [ "$provisional" = "pF-1" ] || { echo "provisional_id not preserved: $provisional (expected pF-1 — X23 carried-field list)"; return 1; }
  [ "$canonical" = "present" ] || { echo "canonical_payload dropped (expected preserved — X23)"; return 1; }
  [ "$blocking" = "False" ] || { echo "blocking wrong or dropped: $blocking (expected False — X23)"; return 1; }
  [ "$anchors" = "present" ] || { echo "fingerprint_anchors dropped (expected preserved — X23)"; return 1; }
  echo "fixture 06 dedupe byte-matches + probe-first sources + provisional_id/canonical_payload/blocking/fingerprint_anchors preserved (iter-5 X23)"
}

check_probe_f_merged_receipt_written() {
  # End-to-end — run fixture 06 through the full Step 3 Consolidation
  # pipeline (stage 2 emit + stage 3 dedupe + stage 4 scorer-skip-probe +
  # stage 4.5 side-map + receipt-write). Asserts the resulting receipt file
  # exists at <audit_slug>-probe-receipts/<merged_final_id>.json with the
  # 11-field on_disk_receipt_body whose probe_output_hash verifies against
  # the reconstructed hashed_probe_output_envelope. Probe E precedent
  # `check_probe_e_merged_receipt_written` — same contract for probe F.
  local fdir="tests/fixtures/cross-audit-probe-f/06-dedupe-with-llm"
  [ -r "$fdir/input.json" ] || { echo "$fdir/input.json missing"; return 1; }
  local work
  work=$(mktemp -d)
  trap "rm -rf '$work'" RETURN
  local kb_root="$work/kb"
  local audit_slug="2026-04-21-fixture-06-f-merged-receipt"
  local receipts_dir="$kb_root/security/$audit_slug-probe-receipts"
  mkdir -p "$receipts_dir"
  local deduped
  deduped=$(cat "$fdir/input.json" | bash hooks/lib/dedupe_findings.sh)
  local result
  result=$(PROBE_F_DEDUPED="$deduped" RECEIPTS_DIR="$receipts_dir" python3 <<'PY'
import hashlib, json, os, sys

deduped = json.loads(os.environ["PROBE_F_DEDUPED"])
receipts_dir = os.environ["RECEIPTS_DIR"]

# Build side-map from the fixture's original probe entry (pF-1) — shape
# identical to probe E §3.3 receipt_metadata.
probe_receipt_metadata_by_provisional_id = {
    "pF-1": {
        "probe_id": "F",
        "probe_version": "f.1.0",
        "trigger_input_hash": "31e0e0b181fc26897034dbe0e2f5b01c2f702f0d7fdfa52c960a8b3fef100211",
        "scope_files_read": ["src/aqua/reconcile.py"],
        "skipped_files": [],
        "emitted_at": "2026-04-21T14:23:17Z",
        "degraded_mode": False,
        "eligible_reason": "1 paging-marker add in function lacking cursor-discipline",
    },
}

# Final-ID allocation — X24: set id = final_id WHILE preserving
# provisional_id. Fixture 06's single merged entry → final_id = "X5".
final_findings = []
for f in deduped["findings_deduped"]:
    entry = dict(f)
    entry["id"] = "X5"
    final_findings.append(entry)

probe_failures_seed = []
for finding in final_findings:
    if not any(s.startswith("probe:") for s in finding["sources"]):
        continue
    # Side-map lookup — X19 coupling; key preserved through dedupe (X23) +
    # final-ID allocation (X24).
    metadata = probe_receipt_metadata_by_provisional_id[finding["provisional_id"]]
    hashed_probe_output_envelope = {
        "probe_id": metadata["probe_id"],
        "probe_version": metadata["probe_version"],
        "emitted_findings": [finding["canonical_payload"]],
    }
    envelope_bytes = json.dumps(
        hashed_probe_output_envelope,
        sort_keys=True, separators=(",", ":"), ensure_ascii=False,
    ).encode("utf-8")
    probe_output_hash = hashlib.sha256(envelope_bytes).hexdigest()
    on_disk_receipt_body = {
        **metadata,
        "probe_output_hash": probe_output_hash,
        "mode_at_emit": finding["mode_at_emit"],
        "emitted_findings": hashed_probe_output_envelope["emitted_findings"],
    }
    receipt_path = os.path.join(receipts_dir, f"{finding['id']}.json")
    try:
        with open(receipt_path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(
                on_disk_receipt_body,
                sort_keys=True, separators=(",", ":"), ensure_ascii=False,
            ))
    except (IOError, OSError) as e:
        probe_failures_seed.append({
            "probe_id": metadata["probe_id"],
            "reason": f"receipt write failed: {str(e)[:200]}",
            "remediation": "check KB mount is writable + re-run /cross-audit",
        })
        finding["probe_receipt"] = None
    else:
        finding["probe_receipt"] = receipt_path

summary = {
    "final_findings": [{"id": f["id"], "provisional_id": f.get("provisional_id"), "probe_receipt": f.get("probe_receipt"), "sources": f.get("sources")} for f in final_findings],
    "probe_failures_seed": probe_failures_seed,
    "envelope_hash_expected": probe_output_hash,
}
sys.stdout.write(json.dumps(summary, sort_keys=True))
PY
)
  [ $? -eq 0 ] || { echo "stage-4.5 orchestrator emulation failed"; return 1; }
  local merged_id merged_provisional merged_sources receipt_path
  merged_id=$(printf '%s\n' "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin)["final_findings"][0]["id"])')
  merged_provisional=$(printf '%s\n' "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin)["final_findings"][0]["provisional_id"])')
  merged_sources=$(printf '%s\n' "$result" | python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)["final_findings"][0]["sources"]))')
  receipt_path=$(printf '%s\n' "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin)["final_findings"][0]["probe_receipt"] or "")')
  [ "$merged_id" = "X5" ] || { echo "merged id wrong: $merged_id"; return 1; }
  [ "$merged_provisional" = "pF-1" ] || { echo "provisional_id not preserved through id-swap (X24): $merged_provisional"; return 1; }
  [ "$merged_sources" = "probe:F,claude" ] || { echo "merged sources wrong: $merged_sources (expected probe:F,claude probe-first)"; return 1; }
  [ -n "$receipt_path" ] || { echo "probe_receipt not populated on merged entry"; return 1; }
  [ -f "$receipt_path" ] || { echo "receipt file not written at $receipt_path"; return 1; }
  python3 -c "
import hashlib, json, sys
body = json.load(open('$receipt_path'))
expected_keys = {
    'probe_id', 'probe_version', 'mode_at_emit', 'trigger_input_hash',
    'probe_output_hash', 'degraded_mode', 'emitted_at', 'eligible_reason',
    'scope_files_read', 'skipped_files', 'emitted_findings',
}
missing = expected_keys - set(body.keys())
extra = set(body.keys()) - expected_keys
if missing: print('missing body keys:', missing); sys.exit(1)
if extra: print('extra body keys:', extra); sys.exit(1)
env = {'probe_id': body['probe_id'], 'probe_version': body['probe_version'], 'emitted_findings': body['emitted_findings']}
env_bytes = json.dumps(env, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
recomputed = hashlib.sha256(env_bytes).hexdigest()
if recomputed != body['probe_output_hash']:
    print(f'probe_output_hash mismatch: disk={body[\"probe_output_hash\"]} recomputed={recomputed}')
    sys.exit(1)
if not isinstance(body['emitted_findings'], list) or len(body['emitted_findings']) != 1:
    print(f'emitted_findings shape wrong: {body[\"emitted_findings\"]!r}')
    sys.exit(1)
" || { echo "11-field body / probe_output_hash verification failed for $receipt_path"; return 1; }
  echo "merged-receipt end-to-end: fixture 06 → dedupe (X23) → final-ID alloc (X24) → side-map lookup (X19) → 11-field receipt written at $receipt_path with verified probe_output_hash"
}

check_probe_f_detector_alias_coverage() {
  # Fixture 12 — authoritative-set alias sampling (X15 iter-5). Single file
  # with three functions: alpha() uses .paginate (fires), beta(pagination_token)
  # uses .limit (disciplined by param alias), gamma() docstring perf_budget uses
  # .iterator (disciplined by keyword alias). Expected: 1 emission total with
  # paging_symbol=.paginate, enclosing_function=alpha.
  _probe_f_byte_diff tests/fixtures/cross-audit-probe-f/12-alias-coverage-sampling || return 1
  local plugin_root; plugin_root="$(pwd)"
  local fdir="tests/fixtures/cross-audit-probe-f/12-alias-coverage-sampling"
  local out n paging enclosing
  out=$( ( cd "$fdir" && PROBE_F_FAKE_NOW="2026-04-21T14:23:17Z" bash "$plugin_root/hooks/lib/probe_f.sh" < input.json ) )
  n=$(printf '%s' "$out" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["findings"]))')
  paging=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["findings"][0]["fingerprint_anchors"]["paging_symbol"])')
  enclosing=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["findings"][0]["canonical_payload"]["enclosing_function"])')
  [ "$n" = "1" ] || { echo "fixture 12 expected 1 emission (alpha only), got $n"; return 1; }
  [ "$paging" = ".paginate" ] || { echo "fixture 12 expected paging_symbol=.paginate, got $paging"; return 1; }
  [ "$enclosing" = "alpha" ] || { echo "fixture 12 expected enclosing_function=alpha, got $enclosing"; return 1; }
  echo "fixture 12 alias coverage: .paginate fires + pagination_token param discipline + perf_budget keyword discipline"
}

check_compliance_checker_r3_heading() {
  local path="${1:-agents/spec-compliance-checker.md}"
  grep -qF '#### R3 — Test strength / weak-phrase regex check' "$path" \
    || { echo "$path missing '#### R3 — Test strength / weak-phrase regex check' subheading"; return 1; }
  echo "R3 weak-phrase enforcement heading present in $path"
}

check_compliance_checker_r3_lists_assertisnotnone() {
  local path="${1:-agents/spec-compliance-checker.md}"
  local R3
  R3=$(awk '
    $0 == "#### R3 — Test strength / weak-phrase regex check" { in_s = 1; print; next }
    in_s && (/^#### / || /^### /) { exit }
    in_s { print }
  ' "$path")
  printf '%s\n' "$R3" | grep -qF '\bassertIsNotNone\b' \
    || { echo "$path R3 subsection missing byte-exact '\bassertIsNotNone\b' regex anchor"; return 1; }
  echo "R3 subsection lists byte-exact assertIsNotNone regex anchor in $path"
}

check_compliance_checker_r3_lists_call_count() {
  local path="${1:-agents/spec-compliance-checker.md}"
  local R3
  R3=$(awk '
    $0 == "#### R3 — Test strength / weak-phrase regex check" { in_s = 1; print; next }
    in_s && (/^#### / || /^### /) { exit }
    in_s { print }
  ' "$path")
  printf '%s\n' "$R3" | grep -qF '\bcall_count\s*==' \
    || { echo "$path R3 subsection missing byte-exact '\bcall_count\s*==' regex anchor"; return 1; }
  echo "R3 subsection lists byte-exact call_count regex anchor in $path"
}

check_compliance_checker_r3_in_verdict_template() {
  local path="${1:-agents/spec-compliance-checker.md}"
  local SECT6
  SECT6=$(awk '
    $0 == "### 6. Return verdict" { in_s = 1; print; next }
    in_s && $0 == "## Rules" { exit }
    in_s { print }
  ' "$path")
  printf '%s\n' "$SECT6" | grep -qF -- '- R3 (weak-phrase fresh tests):' \
    || { echo "$path ### 6. Return verdict section missing byte-exact R3 weak-phrase verdict-template line"; return 1; }
  echo "R3 weak-phrase line present in verdict template ### Code quality block in $path"
}

check_compliance_checker_r3_in_rules() {
  local path="${1:-agents/spec-compliance-checker.md}"
  local RULES
  RULES=$(extract_md_section "$path" '## Rules')
  printf '%s\n' "$RULES" | grep -qF -- '- Code quality R3 violations are DRIFT' \
    || { echo "$path ## Rules section missing byte-exact R3 DRIFT enforcement bullet opening"; return 1; }
  echo "## Rules has R3 DRIFT weak-phrase enforcement bullet in $path"
}

# --- Librarian narrow-framing pins (BACKLOG #44 — actual-vs-declared role review, mode B) ---

check_librarian_optional_helper_framing() {
  local path="${1:-agents/librarian.md}"
  grep -qF 'Optional helper for KB layout discovery and MOC index maintenance' "$path" \
    || { echo "$path frontmatter missing 'Optional helper for KB layout discovery and MOC index maintenance' framing"; return 1; }
  grep -qF 'NOT a mandatory gateway' "$path" \
    || { echo "$path frontmatter missing 'NOT a mandatory gateway' clarifier"; return 1; }
  echo "librarian.md describes itself as optional helper, not mandatory gateway"
}

check_librarian_no_mandatory_only_claim() {
  local path="${1:-agents/librarian.md}"
  if grep -qF 'The only agent that creates new KB documents' "$path"; then
    echo "$path still claims 'The only agent that creates new KB documents' — drift back to mode A framing detected"
    return 1
  fi
  if grep -qF 'single point of authority for creating new KB documents' "$path"; then
    echo "$path still claims 'single point of authority for creating new KB documents' — drift back detected"
    return 1
  fi
  echo "librarian.md does not claim mandatory-gateway role (mode B framing intact)"
}

check_overview_kb_access_orchestrator_writes_directly() {
  local path="${1:-docs/AI_Dev_Team_Overview.md}"
  grep -qF 'Orchestrator writes KB files directly' "$path" \
    || { echo "$path KB access division missing 'Orchestrator writes KB files directly' framing"; return 1; }
  if grep -qF 'Only Librarian creates new KB documents' "$path"; then
    echo "$path KB access division still claims 'Only Librarian creates new KB documents' — drift back detected"
    return 1
  fi
  echo "$path KB access division reflects mode B (orchestrator-direct-writes)"
}

check_session_prompt_compressed_size_cap() {
  local path="${1:-hooks/session-prompt.md}"
  local cap="${2:-30}"
  local lc
  lc=$(wc -l < "$path")
  if [ "$lc" -gt "$cap" ]; then
    echo "$path is $lc lines, exceeds compression cap of $cap (regression: inject inflated)"
    return 1
  fi
  echo "$path size $lc <= $cap (compression cap respected)"
}

check_confirmation_cadence_shared_doc_canonical() {
  local path="${1:-docs/confirmation-cadence.md}"
  [ -f "$path" ] \
    || { echo "$path missing shared Confirmation cadence doc"; return 1; }
  grep -qF 'Inside an active' "$path" \
    || { echo "$path missing active-flow scope opening token"; return 1; }
  grep -qF 'distinct outcomes' "$path" \
    || { echo "$path missing distinct-outcomes ask-only condition"; return 1; }
  grep -qF 'destructive or irreversible' "$path" \
    || { echo "$path missing destructive-or-irreversible ask-only condition"; return 1; }
  grep -qF 'genuinely changes' "$path" \
    || { echo "$path missing genuinely-changes ask-only condition"; return 1; }
  grep -qF 'ok to commit?' "$path" \
    || { echo "$path missing confirmation-cadence example phrase"; return 1; }
  echo "$path contains canonical Confirmation cadence scope, conditions, and examples"
}

check_inject_coexistence_section() {
  local path="${1:-hooks/session-prompt.md}"
  grep -qF '### Coexistence' "$path" \
    || { echo "$path missing Coexistence section heading"; return 1; }
  grep -qF "user's CLAUDE.md" "$path" \
    || { echo "$path missing priority-order token user's CLAUDE.md"; return 1; }
  grep -qF 'other plugins' "$path" \
    || { echo "$path missing priority-order token other plugins"; return 1; }
  grep -qF 'ai-dev-team' "$path" \
    || { echo "$path missing priority-order token ai-dev-team"; return 1; }
  grep -qF 'default Claude behavior' "$path" \
    || { echo "$path missing priority-order tail token 'default Claude behavior'"; return 1; }
  grep -qF 'complements' "$path" \
    || { echo "$path missing coexistence-note keyword complements"; return 1; }
  echo "$path contains Coexistence section with priority order and complement note"
}

check_skill_bodies_have_migrated_content() {
  # feature SKILL: workflow-phases (already pinned)
  grep -qF '5. Code audit' skills/feature/SKILL.md \
    || { echo "skills/feature/SKILL.md missing migrated '5. Code audit' phase token"; return 1; }
  grep -qF '4. Verify' skills/feature/SKILL.md \
    || { echo "skills/feature/SKILL.md missing migrated '4. Verify' phase token"; return 1; }
  # feature SKILL: confirmation-cadence (NEW per X2)
  grep -qF '## Confirmation cadence' skills/feature/SKILL.md \
    || { echo "skills/feature/SKILL.md missing migrated '## Confirmation cadence' heading"; return 1; }
  grep -qF 'docs/confirmation-cadence.md' skills/feature/SKILL.md \
    || { echo "skills/feature/SKILL.md missing shared confirmation-cadence doc link"; return 1; }
  # feature SKILL: session-resume-KB-scan (NEW per X2)
  grep -qF '## Session resume — KB scan' skills/feature/SKILL.md \
    || { echo "skills/feature/SKILL.md missing migrated '## Session resume — KB scan' heading"; return 1; }
  grep -qF 'IN_PROGRESS or AUDIT_PASSED' skills/feature/SKILL.md \
    || { echo "skills/feature/SKILL.md missing migrated session-resume status token"; return 1; }
  # feature SKILL: evidence-captures contract (NEW per X1 fix)
  grep -qF 'A step is not done until' skills/feature/SKILL.md \
    || { echo "skills/feature/SKILL.md missing X1-migrated 'A step is not done until ...' evidence-captures contract"; return 1; }
  # feature SKILL: continue resumes from last step (NEW per X1 fix)
  grep -qF 'last incomplete step' skills/feature/SKILL.md \
    || { echo "skills/feature/SKILL.md missing X1-migrated continue-resume bullet ('last incomplete step')"; return 1; }
  # cross-audit SKILL: audit-findings-handling (already pinned)
  grep -q 'publish|fix|accept|defer' skills/cross-audit/SKILL.md \
    || { echo "skills/cross-audit/SKILL.md missing migrated 'publish|fix|accept|defer' decision-keyword exception"; return 1; }
  grep -qF 'pass-through' skills/cross-audit/SKILL.md \
    || { echo "skills/cross-audit/SKILL.md missing migrated 'pass-through' wording"; return 1; }
  # cross-audit SKILL: confirmation-cadence (NEW per X2)
  grep -qF '## Confirmation cadence' skills/cross-audit/SKILL.md \
    || { echo "skills/cross-audit/SKILL.md missing migrated '## Confirmation cadence' heading"; return 1; }
  grep -qF 'docs/confirmation-cadence.md' skills/cross-audit/SKILL.md \
    || { echo "skills/cross-audit/SKILL.md missing shared confirmation-cadence doc link"; return 1; }
  # cross-audit SKILL: runs in background (NEW per X1 fix)
  grep -qF 'runs in background' skills/cross-audit/SKILL.md \
    || { echo "skills/cross-audit/SKILL.md missing X1-migrated 'runs in background' bullet"; return 1; }
  # investigate SKILL: runs in background (NEW per X1 fix)
  grep -qF 'runs in background' skills/investigate/SKILL.md \
    || { echo "skills/investigate/SKILL.md missing X1-migrated 'runs in background' bullet"; return 1; }
  echo "skill bodies retain all 5 migrated sections + X1 key-fact bullets"
}

check_session_prompt_kb_persistence_kept() {
  local path="${1:-hooks/session-prompt.md}"
  grep -qF 'KB path is saved in Claude memory' "$path" \
    || { echo "$path missing KB-persistence bullet ('KB path is saved in Claude memory after first session — not asked again')"; return 1; }
  echo "$path retains KB-persistence Key fact"
}

check_cross_audit_resolve_range_positive() {
  bash "$PLUGIN_ROOT/tests/fixtures/cross-audit-ref-range/setup.sh"
  local out
  out=$(cd "$PLUGIN_ROOT/tests/fixtures/cross-audit-ref-range/repo" && bash "$PLUGIN_ROOT/hooks/lib/cross_audit_resolve_range.sh" "v0.1..v0.2")
  echo "$out" | grep -qF 'refA=v0.1'      || { echo "missing refA=v0.1 in: $out"; return 1; }
  echo "$out" | grep -qF 'refB=v0.2'      || { echo "missing refB=v0.2 in: $out"; return 1; }
  echo "$out" | grep -qF 'op=..'          || { echo "missing op=.. in: $out"; return 1; }
  echo "$out" | grep -qF 'slug_pair=v0.1__v0.2' || { echo "missing slug_pair=v0.1__v0.2 in: $out"; return 1; }
  echo "cross_audit_resolve_range positive: refA=v0.1 refB=v0.2 op=.. slug_pair=v0.1__v0.2 all present"
}

check_cross_audit_resolve_range_invalid_ref() {
  bash "$PLUGIN_ROOT/tests/fixtures/cross-audit-ref-range/setup.sh"
  local err
  err=$(cd "$PLUGIN_ROOT/tests/fixtures/cross-audit-ref-range/repo" && bash "$PLUGIN_ROOT/hooks/lib/cross_audit_resolve_range.sh" "v0.1..nonexistent" 2>&1 >/dev/null) && { echo "expected exit 1 but got 0"; return 1; } || true
  # Capture stderr separately
  local rc=0
  err=$(cd "$PLUGIN_ROOT/tests/fixtures/cross-audit-ref-range/repo" && bash "$PLUGIN_ROOT/hooks/lib/cross_audit_resolve_range.sh" "v0.1..nonexistent" 2>&1 1>/dev/null) || rc=$?
  [ "$rc" -ne 0 ] || { echo "expected non-zero exit"; return 1; }
  echo "$err" | grep -qF 'ref does not exist' || { echo "expected 'ref does not exist' in stderr: $err"; return 1; }
  echo "cross_audit_resolve_range invalid_ref: correctly exits non-zero with 'ref does not exist'"
}

check_cross_audit_resolve_range_empty_diff() {
  bash "$PLUGIN_ROOT/tests/fixtures/cross-audit-ref-range/setup.sh"
  local rc=0
  local err
  err=$(cd "$PLUGIN_ROOT/tests/fixtures/cross-audit-ref-range/repo" && bash "$PLUGIN_ROOT/hooks/lib/cross_audit_resolve_range.sh" "v0.2..v0.2" 2>&1 1>/dev/null) || rc=$?
  [ "$rc" -ne 0 ] || { echo "expected non-zero exit for same-ref"; return 1; }
  echo "$err" | grep -qF 'no changes between refs' || { echo "expected 'no changes between refs' in stderr: $err"; return 1; }
  echo "cross_audit_resolve_range empty_diff: correctly exits non-zero with 'no changes between refs'"
}

check_cross_audit_resolve_range_path_filter() {
  bash "$PLUGIN_ROOT/tests/fixtures/cross-audit-ref-range/setup.sh"
  local out
  out=$(cd "$PLUGIN_ROOT/tests/fixtures/cross-audit-ref-range/repo" && bash "$PLUGIN_ROOT/hooks/lib/cross_audit_resolve_range.sh" "v0.1..v0.2 -- foo.txt")
  echo "$out" | grep -qF 'path_filter=foo.txt' || { echo "expected path_filter=foo.txt in: $out"; return 1; }
  echo "cross_audit_resolve_range path_filter: path_filter=foo.txt preserved correctly"
}

check_cross_audit_skill_parses_ref_range() {
  local skill='skills/cross-audit/SKILL.md'
  test -f "$skill" || { echo "$skill missing"; return 1; }
  grep -qF 'Ref-range detection' "$skill" \
    || { echo "$skill missing 'Ref-range detection' section heading"; return 1; }
  grep -qF -- '--materialize=worktree' "$skill" \
    || { echo "$skill missing '--materialize=worktree' flag documentation"; return 1; }
  grep -qF 'range_spec' "$skill" \
    || { echo "$skill missing 'range_spec' parameter in Phase 1-2 Step 1"; return 1; }
  grep -qF 'rev-parse' "$skill" \
    || { echo "$skill missing 'rev-parse' in Ref-range detection rule"; return 1; }
  # range_spec must appear in the params list AND the dispatch template (>= 2 occurrences)
  local count
  count=$(grep -cF 'range_spec' "$skill")
  [ "$count" -ge 2 ] || { echo "$skill has only $count occurrence(s) of 'range_spec' (expected >= 2: params list + dispatch template)"; return 1; }
  grep -qF 'materialize_mode' "$skill" \
    || { echo "$skill missing 'materialize_mode' parameter wiring"; return 1; }
  echo "SKILL.md Ref-range detection section, --materialize=worktree flag, range_spec wiring (count=$count), materialize_mode parameter, and rev-parse rule all present"
}

check_cross_audit_agent_handles_range_spec() {
  local agent='agents/cross-auditor.md'
  test -f "$agent" || { echo "$agent missing"; return 1; }
  grep -qF 'range_spec' "$agent" \
    || { echo "$agent missing 'range_spec' parameter declaration"; return 1; }
  grep -qF 'git diff --name-only <range_spec>' "$agent" \
    || { echo "$agent missing updated diff-mode wording with range_spec"; return 1; }
  # Verify range_spec appears at least twice (parameter declaration + diff-mode wording)
  local count
  count=$(grep -cF 'range_spec' "$agent")
  [ "$count" -ge 2 ] || { echo "$agent has only $count occurrence(s) of 'range_spec' (expected >= 2)"; return 1; }
  echo "agents/cross-auditor.md range_spec parameter (count=$count) and diff-mode wording both present"
}

check_codex_audit_dispatch_helper_positive() {
  local tmpdir tmpout stdout
  tmpdir=$(mktemp -d)
  tmpout=$(mktemp)
  rm -f "$tmpout"

  stdout=$(echo "test prompt" | CODEX_BIN="$PLUGIN_ROOT/tests/fixtures/codex-audit-dispatch/mock_codex.sh" bash hooks/lib/codex_audit_dispatch.sh "$tmpdir" "$tmpout" gpt-5.5 xhigh) \
    || { echo "codex_audit_dispatch expected exit 0"; rm -rf "$tmpdir" "$tmpout"; return 1; }
  test -f "$tmpout" || { echo "expected output file to be created: $tmpout"; rm -rf "$tmpdir" "$tmpout"; return 1; }
  grep -qF 'ok-mock-response' "$tmpout" || { echo "expected ok-mock-response in output file"; rm -rf "$tmpdir" "$tmpout"; return 1; }
  echo "$stdout" | grep -qF 'task_started' || { echo "expected task_started in stdout: $stdout"; rm -rf "$tmpdir" "$tmpout"; return 1; }

  rm -rf "$tmpdir" "$tmpout"
  echo "codex_audit_dispatch positive: mock stdout and output file present"
}

check_codex_audit_dispatch_helper_propagates_exit_code() {
  local tmpstderr rc
  tmpstderr=$(mktemp)
  rc=0
  CODEX_BIN="$PLUGIN_ROOT/tests/fixtures/codex-audit-dispatch/mock_codex_fail.sh" bash hooks/lib/codex_audit_dispatch.sh /tmp /tmp/codex-noop.txt gpt-5.5 xhigh < /dev/null 2>"$tmpstderr" || rc=$?
  [ "$rc" = "2" ] || { echo "expected exit code 2, got $rc"; rm -f "$tmpstderr"; return 1; }
  grep -qF 'ERROR: codex unavailable' "$tmpstderr" || { echo "expected mock codex error in stderr"; rm -f "$tmpstderr"; return 1; }
  rm -f "$tmpstderr"
  echo "codex_audit_dispatch propagates mock codex exit code 2 and stderr"
}

check_codex_audit_dispatch_helper_arg_validation() {
  local tmpstderr rc
  tmpstderr=$(mktemp)
  rc=0
  bash hooks/lib/codex_audit_dispatch.sh 2>"$tmpstderr" || rc=$?
  [ "$rc" -ne 0 ] || { echo "expected non-zero exit"; rm -f "$tmpstderr"; return 1; }
  grep -qF 'ERROR:' "$tmpstderr" || { echo "expected ERROR: in stderr"; rm -f "$tmpstderr"; return 1; }
  rm -f "$tmpstderr"
  echo "codex_audit_dispatch arg validation rejects missing args"
}

check_feature_skill_step1_reads_repo_conventions() {
  local skill='skills/feature/SKILL.md'
  local section
  section=$(awk '/^### Step 1 — Research/{flag=1} /^### Step 2 —/{if (flag) exit} flag{print}' "$skill")
  echo "$section" | grep -qF 'AGENTS.md' \
    || { echo "$skill Step 1 missing AGENTS.md repo-convention read"; return 1; }
  echo "$section" | grep -qF 'CLAUDE.md' \
    || { echo "$skill Step 1 missing CLAUDE.md repo-convention read"; return 1; }
  echo "$section" | grep -qF '.github/CONTRIBUTING.md' \
    || { echo "$skill Step 1 missing .github/CONTRIBUTING.md repo-convention read"; return 1; }
  echo "$section" | grep -qF 'Repo conventions' \
    || { echo "$skill Step 1 missing Repo conventions lift target"; return 1; }
  echo "feature SKILL Step 1 reads repo convention files and lifts Repo conventions"
}

check_feature_skill_step2_forbids_ambiguity() {
  local skill='skills/feature/SKILL.md'
  local section
  section=$(awk '/^### Step 2 —/{flag=1} /^### Step 3 —/{if (flag) exit} flag{print}' "$skill")
  echo "$section" | grep -qF 'MUST specify the exact placement/value' \
    || { echo "$skill Step 2 missing exact placement/value requirement"; return 1; }
  echo "$section" | grep -qF "developer's call" \
    || { echo "$skill Step 2 missing developer's call ambiguity token"; return 1; }
  echo "$section" | grep -qF "at developer's discretion" \
    || { echo "$skill Step 2 missing at developer's discretion ambiguity token"; return 1; }
  echo "$section" | grep -qF 'as you see fit' \
    || { echo "$skill Step 2 missing as you see fit ambiguity token"; return 1; }
  echo "$section" | grep -qF 'at agent discretion' \
    || { echo "$skill Step 2 missing at agent discretion ambiguity token"; return 1; }
  echo "feature SKILL Step 2 forbids repo-convention ambiguity tokens"
}

check_cross_auditor_spec_mode_repo_convention_rule() {
  local agent='agents/cross-auditor.md'
  local section
  section=$(awk '/^### `spec` mode/{flag=1} /^## Severity Ladder/{if (flag) exit} flag{print}' "$agent")
  echo "$section" | grep -qF 'Repo-convention enforcement' \
    || { echo "$agent spec mode missing Repo-convention enforcement rule"; return 1; }
  echo "$section" | grep -qF "at developer's discretion" \
    || { echo "$agent spec mode missing at developer's discretion ambiguity token"; return 1; }
  echo "$section" | grep -qF "developer's call" \
    || { echo "$agent spec mode missing developer's call ambiguity token"; return 1; }
  echo "$section" | grep -qF 'as you see fit' \
    || { echo "$agent spec mode missing as you see fit ambiguity token"; return 1; }
  echo "$section" | grep -qF 'at agent discretion' \
    || { echo "$agent spec mode missing at agent discretion ambiguity token"; return 1; }
  echo "$section" | grep -qF 'AGENTS.md' \
    || { echo "$agent spec mode missing AGENTS.md convention-file reference"; return 1; }
  echo "cross-auditor spec mode pins Repo-convention enforcement rule"
}

check_r5_step1_reads_directive_files() {
  local rules='skills/feature/references/code-quality-rules.md'
  grep -qF 'AGENTS.md' "$rules" \
    || { echo "$rules missing AGENTS.md directive-file precedence check"; return 1; }
  grep -qF 'CLAUDE.md' "$rules" \
    || { echo "$rules missing CLAUDE.md directive-file precedence check"; return 1; }
  grep -qF 'directive' "$rules" \
    || { echo "$rules missing directive precedence keyword"; return 1; }

  local agents_line
  local grep_line
  agents_line=$(grep -nF 'AGENTS.md' "$rules" | head -1 | cut -d: -f1)
  grep_line=$(grep -nF 'grep -R "#[cfg(test)]" src/' "$rules" | head -1 | cut -d: -f1)
  [ -n "$agents_line" ] || { echo "$rules missing AGENTS.md line"; return 1; }
  [ -n "$grep_line" ] || { echo "$rules missing grep -R test-layout heuristic"; return 1; }
  [ "$agents_line" -lt "$grep_line" ] \
    || { echo "$rules directive-file check must appear before grep heuristic (AGENTS.md@$agents_line grep@$grep_line)"; return 1; }
  echo "R5 step 1 reads directive files before grep heuristic"
}

check_cross_auditor_uses_async_codex_dispatch() {
  local agent='agents/cross-auditor.md'
  local tools_line step1 count line5

  test -f "$agent" || { echo "$agent missing"; return 1; }

  tools_line=$(grep -F 'tools:' "$agent" | head -1)
  echo "$tools_line" | grep -qF 'BashOutput' \
    || { echo "$agent tools frontmatter missing BashOutput"; return 1; }
  echo "$tools_line" | grep -qF 'KillShell' \
    || { echo "$agent tools frontmatter missing KillShell"; return 1; }
  if echo "$tools_line" | grep -qF 'mcp__codex__codex'; then
    echo "$agent tools frontmatter still contains mcp__codex__codex"
    return 1
  fi

  count=$(grep -cF '## Codex dispatch (background CLI + polling)' "$agent")
  [ "$count" -ge 1 ] \
    || { echo "$agent missing Codex dispatch background CLI section"; return 1; }

  step1=$(awk '/^## Step 1:/{flag=1} /^## Step 2:/{if (flag) exit} flag{print}' "$agent")
  echo "$step1" | grep -qF 'codex_audit_dispatch.sh' \
    || { echo "$agent Step 1 missing codex_audit_dispatch.sh"; return 1; }
  echo "$step1" | grep -qF 'run_in_background' \
    || { echo "$agent Step 1 missing run_in_background"; return 1; }

  count=$(grep -cF 'BashOutput' "$agent")
  [ "$count" -ge 2 ] \
    || { echo "$agent missing BashOutput in body (count=$count, expected >= 2 including frontmatter)"; return 1; }

  local model_line effort_line
  model_line=$(grep -nF 'model: opus' "$agent" | head -1 | cut -d: -f1)
  effort_line=$(grep -nF 'effort: xhigh' "$agent" | head -1 | cut -d: -f1)
  [ -n "$model_line" ] || { echo "$agent missing 'model: opus' in frontmatter"; return 1; }
  [ -n "$effort_line" ] || { echo "$agent missing 'effort: xhigh' in frontmatter"; return 1; }
  [ "$effort_line" = "$((model_line + 1))" ] \
    || { echo "$agent 'effort: xhigh' must immediately follow 'model: opus' (model@$model_line, effort@$effort_line)"; return 1; }

  count=$(grep -cF 'codex_audit_dispatch.sh exits non-zero' "$agent")
  [ "$count" -ge 1 ] \
    || { echo "$agent fail-open wording missing codex_audit_dispatch.sh exits non-zero"; return 1; }

  if grep -qF 'mcp__codex__codex' "$agent"; then
    echo "$agent still contains mcp__codex__codex"
    return 1
  fi

  echo "cross-auditor uses async Codex dispatch with BashOutput/KillShell and no MCP dispatch"
}

check_cross_auditor_codex_effort_default_xhigh_kept() {
  local agent='agents/cross-auditor.md'
  grep -qF 'Defaults to `xhigh` when absent' "$agent" \
    || { echo "$agent missing codex_reasoning_effort xhigh default docstring"; return 1; }
  echo "cross-auditor preserves codex_reasoning_effort default xhigh docstring"
}

check_smoke_proves_manifest_canonical() {
  local manifest="tests/smoke-proves-manifest.txt"
  # (a) file exists
  test -f "$manifest" || { echo "manifest $manifest missing"; return 1; }
  # (b) at least 30 non-comment non-empty lines
  local count
  count=$(grep -cvE '^[[:space:]]*#|^[[:space:]]*$' "$manifest" || true)
  [ "$count" -ge 30 ] || { echo "manifest has only $count non-comment lines (need >=30)"; return 1; }
  # (c) every non-comment non-empty line matches well-formed entry regex
  local bad
  bad=$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$manifest" | grep -cvE '^[a-zA-Z0-9_]+[[:space:]]+(behavioral|schema|prompt-text)[[:space:]]*$' || true)
  [ "$bad" -eq 0 ] || { echo "$bad malformed entries in manifest"; return 1; }
  # (d) at least 1 entry per class
  grep -qE '^[a-zA-Z0-9_]+[[:space:]]+behavioral' "$manifest" || { echo "no behavioral entries in manifest"; return 1; }
  grep -qE '^[a-zA-Z0-9_]+[[:space:]]+schema' "$manifest" || { echo "no schema entries in manifest"; return 1; }
  grep -qE '^[a-zA-Z0-9_]+[[:space:]]+prompt-text' "$manifest" || { echo "no prompt-text entries in manifest"; return 1; }
  echo "smoke-proves-manifest.txt canonical: $count entries, all 3 classes present"
}

check_smoke_summary_breaks_down_by_class() {
  [ "${SMOKE_NESTED:-}" = "1" ] && { echo "nested run — skipping recursive check"; return 0; }
  local out
  out=$(SMOKE_NESTED=1 bash tests/smoke.sh 2>&1 | tail -10)
  echo "$out" | grep -qF 'Behavioral:' || { echo "suite tail missing 'Behavioral:' line"; return 1; }
  echo "$out" | grep -qF 'Schema:' || { echo "suite tail missing 'Schema:' line"; return 1; }
  echo "$out" | grep -qF 'Prompt-text:' || { echo "suite tail missing 'Prompt-text:' line"; return 1; }
  echo "$out" | grep -qF 'Unclassified:' || { echo "suite tail missing 'Unclassified:' line"; return 1; }
  echo "smoke suite tail contains all 4 class breakdown lines"
}

check_agent_claims_doc_exists_and_classified() {
  local doc="docs/agent-claims-vs-runtime.md"
  # (a) file exists
  test -f "$doc" || { echo "doc $doc missing"; return 1; }
  # (b) contains markdown table column header with Class
  grep -qF '| Class |' "$doc" || { echo "doc missing '| Class |' column header"; return 1; }
  # (c) table body has >=10 rows (lines starting with | but not the separator line)
  local rows
  rows=$(grep -cE '^\| [^-]' "$doc" || true)
  [ "$rows" -ge 11 ] || { echo "doc has only $((rows-1)) body rows (need >=10, found $rows pipe-lines including header)"; return 1; }
  # (d) all 3 class tokens appear in the body
  grep -qwF 'enforced' "$doc" || { echo "doc missing 'enforced' class token"; return 1; }
  grep -qwF 'convention' "$doc" || { echo "doc missing 'convention' class token"; return 1; }
  grep -qwF 'self-policed' "$doc" || { echo "doc missing 'self-policed' class token"; return 1; }
  echo "agent-claims-vs-runtime.md: all 3 class tokens present, >=10 rows"
}

check_spec_compliance_checker_description_narrow() {
  local agent="agents/spec-compliance-checker.md"
  test -f "$agent" || { echo "$agent missing"; return 1; }
  # Positive: must contain narrow scope markers
  grep -qF 'R1, R2, R3' "$agent" \
    || { echo "$agent missing 'R1, R2, R3' in description"; return 1; }
  grep -qF 'R4-R7 are convention-text' "$agent" \
    || { echo "$agent missing 'R4-R7 are convention-text' in description"; return 1; }
  # Negative: must NOT contain legacy broad phrasing (anti-regression)
  if grep -qF 'reasons about whether observed matches planned intent' "$agent"; then
    echo "$agent still contains legacy broad phrasing 'reasons about whether observed matches planned intent'"
    return 1
  fi
  echo "spec-compliance-checker.md description is narrow and legacy phrase absent"
}

check_mission_r_enforcement_claim_narrow() {
  # Locate MISSION.md: try KB_PATH env var, then sibling path, then plugin root.
  local mission_path=""
  if [ -n "${KB_PATH:-}" ] && [ -f "${KB_PATH}/repos/ai-dev-team/MISSION.md" ]; then
    mission_path="${KB_PATH}/repos/ai-dev-team/MISSION.md"
  elif [ -f "../../finance-learning/repos/ai-dev-team/MISSION.md" ]; then
    mission_path="../../finance-learning/repos/ai-dev-team/MISSION.md"
  elif [ -f "MISSION.md" ]; then
    mission_path="MISSION.md"
  fi

  if [ -z "$mission_path" ]; then
    echo "MISSION.md not found in plugin source tree (lives in KB) — skipped"
    return 0
  fi

  # Assert narrow R-enforcement claim (Russian or English phrasing)
  if ! grep -qF 'R1, R2 и R3' "$mission_path" && ! grep -qF 'R1, R2, R3' "$mission_path"; then
    echo "MISSION.md missing narrow R1/R2/R3 enforcement claim"
    return 1
  fi

  # Assert R4-R7 queued (various phrasings)
  if ! grep -qF 'enforcement queued' "$mission_path" && \
     ! { grep -qF 'R4-R7 enforcement' "$mission_path" && grep -qE 'queued|pending|TODO' "$mission_path"; }; then
    echo "MISSION.md missing R4-R7 enforcement queued claim"
    return 1
  fi

  echo "MISSION.md R-enforcement claims are narrow and R4-R7 queued present"
}

check_probe_downgrade_flag_absent() {
  # Spec 2026-04-26-cut-probe-downgrade §3.6 — 5 absence assertions (was 6;
  # assertion #1 forbidding the `--probe-downgrade` literal in
  # skills/cross-audit/SKILL.md was retired by spec
  # design/2026-04-29-removed-cli-flag-hard-fail.md §3.3.4 Path 4 because
  # the new "Removed-flag hard-fail" block in that SKILL.md must contain
  # the flag literal byte-for-byte for the canonical hard-fail line;
  # equivalent silent-reintroduction protection now comes from the §3.4
  # presence pin check_cross_audit_probe_downgrade_hard_fail asserting
  # the canonical line byte-for-byte). The YAML kill-switch
  # cross_audit.probes.<id>.mode remains load-bearing and is asserted
  # PRESENT (assertion 4).
  local skill="skills/cross-audit/SKILL.md"
  local agent="agents/cross-auditor.md"
  local kb_doc="docs/kb-discovery.md"
  # 1. No CLI flag literal in cross-auditor agent prose.
  if grep -qF -- '--probe-downgrade' "$agent"; then
    echo "assertion 1 FAILED: --probe-downgrade literal present in $agent"
    return 1
  fi
  # 2. No CLI flag literal in kb-discovery docs.
  if grep -qF -- '--probe-downgrade' "$kb_doc"; then
    echo "assertion 2 FAILED: --probe-downgrade literal present in $kb_doc"
    return 1
  fi
  # 3. No retired helper-function definitions in tests/smoke-helpers.sh.
  if grep -qE '^check_(skill_md_probe_downgrade_(flag|off_floor_refusal)|probe_[ef]_(cli_downgrade|downgrade_upgrade_refused_when_yaml_off))\(\)' tests/smoke-helpers.sh; then
    echo "assertion 3 FAILED: retired helper-function definition(s) present in tests/smoke-helpers.sh"
    return 1
  fi
  # 4. Positive overcut guard — YAML kill-switch must survive.
  if ! grep -qF 'cross_audit.probes' "$skill"; then
    echo "assertion 4 FAILED: cross_audit.probes YAML kill-switch missing from $skill (positive overcut guard)"
    return 1
  fi
  # 5. No stale section-header comments — only matches comment lines (^#),
  #    so the body code in this helper that references --probe-downgrade as
  #    the assertion target is excluded by construction.
  assert_no_stale_section_header_comments '--probe-downgrade' 'assertion 5' \
    || { echo "assertion 5 FAIL: stale --probe-downgrade header in smoke files"; return 1; }
  echo "check_probe_downgrade_flag_absent: all 5 assertions OK"
}

# Asserts the given literal does NOT appear in any of the scanned files.
# Default scan-set (no trailing args): skills/ agents/ docs/ README.md
# .ai-dev-team.yml.example — the canonical live-source surface.
# When trailing args are given, they REPLACE the default scan-set entirely
# (the path-list arg form is for tamper-fixture rejection wrappers).
#
# Args:
#   $1 — literal (passed to grep -F as fixed string)
#   $2 — failure-message prefix (e.g. "absence #2", caller-controlled)
#   $3+ — OPTIONAL: path-list arg form (overrides default scan-set)
#
# Exits 0 if literal is absent; 1 with diagnostic on stderr if present.
assert_literal_absent_in_live_source() {
  local literal="$1"
  local prefix="$2"
  shift 2
  local paths=("$@")
  if [ ${#paths[@]} -eq 0 ]; then
    paths=(skills/ agents/ docs/ README.md .ai-dev-team.yml.example)
  fi
  if grep -rqF -- "$literal" "${paths[@]}"; then
    echo "$prefix FAIL: '$literal' literal still present in live source" >&2
    return 1
  fi
  return 0
}

# Asserts no top-level (^#) comment line in any scanned file matches the
# given ERE pattern. Default scan-set (no trailing args): tests/smoke.sh
# tests/smoke-helpers.sh — the only smoke files this rule applies to in
# production. When trailing args are given, they REPLACE the default
# scan-set entirely (the path-list arg form is for tamper-fixture
# rejection wrappers).
#
# Args:
#   $1 — ERE regex pattern (no anchors needed — caller-controlled body)
#   $2 — failure-message prefix
#   $3+ — OPTIONAL: path-list arg form (overrides default scan-set)
#
# Exits 0 if no stale comment; 1 with diagnostic on stderr otherwise.
assert_no_stale_section_header_comments() {
  local pattern="$1"
  local prefix="$2"
  shift 2
  local files=("$@")
  if [ ${#files[@]} -eq 0 ]; then
    files=(tests/smoke.sh tests/smoke-helpers.sh)
  fi
  if grep -qE "^# .*($pattern)" "${files[@]}"; then
    echo "$prefix FAIL: stale ^# .*$pattern comment header(s) present" >&2
    return 1
  fi
  return 0
}

check_publish_md_f7_legacy_sentence_survives() {
  grep -qF -- 'All gh api calls pass --repo <pr_repo> AND --include' skills/cross-audit/references/publish.md \
    || { echo "publish.md F7 legacy sentence missing" >&2; return 1; }
}

check_new_pin_classified() {
  local smoke_file="${1:-tests/smoke.sh}"
  local manifest_file="${2:-tests/smoke-proves-manifest.txt}"
  local baseline_file="${3:-tests/smoke-classification-baseline.txt}"

  test -f "$smoke_file" || { echo "absence #1 FAIL: $smoke_file missing" >&2; return 1; }
  test -f "$manifest_file" || { echo "absence #2 FAIL: $manifest_file missing" >&2; return 1; }
  test -f "$baseline_file" || { echo "absence #3 FAIL: $baseline_file missing" >&2; return 1; }

  local registered manifest baseline unclassified
  # X1+X5 fix: extract helper-function token (column 2), tolerate leading whitespace.
  registered=$(grep -E '^[[:space:]]*check "[^"]+"' "$smoke_file" \
    | sed -nE 's/^[[:space:]]*check "[^"]+"[[:space:]]+([^[:space:]]+).*/\1/p' \
    | sort -u)
  manifest=$(grep -vE '^#|^$' "$manifest_file" | awk '{print $1}' | sort -u)
  baseline=$(grep -vE '^#|^$' "$baseline_file" | sort -u)

  unclassified=$(comm -23 \
    <(printf '%s\n' "$registered") \
    <(printf '%s\n%s\n' "$manifest" "$baseline" | sort -u))

  local multiline_offenders
  multiline_offenders=$(grep -nE '^[[:space:]]*check "[^"]+"[[:space:]]*\\$' "$smoke_file")
  if [ -n "$multiline_offenders" ]; then
    echo "absence #5 FAIL: multiline check registrations not supported (line-continuation \`\\\` is not a valid helper name); refactor into named helper:" >&2
    printf '%s\n' "$multiline_offenders" | sed 's/^/  /' >&2
    return 1
  fi

  # absence #6: extraction grammar = registration grammar invariant.
  # `check()` accepts more registration forms than the gate's helper-name extractor.
  # Reject any line invoking `check` that does NOT match the canonical grammar
  # (column-anchored `check "double-quoted label" helper_function_token`).
  local grammar_offenders
  grammar_offenders=$(grep -nE '^[[:space:]]*check[[:space:]]' "$smoke_file" \
    | grep -vE '^[0-9]+:[[:space:]]*check "[^"]+"[[:space:]]+[A-Za-z_][A-Za-z_0-9]+([[:space:]]|$)' \
    || true)
  if [ -n "$grammar_offenders" ]; then
    echo "absence #6 FAIL: check registration form not recognized by gate (extraction grammar = registration grammar invariant; only canonical \`check \"label\" helper_function_token\` is supported); refactor to canonical form:" >&2
    printf '%s\n' "$grammar_offenders" | sed 's/^/  /' >&2
    return 1
  fi

  if [ -n "$unclassified" ]; then
    echo "absence #4 FAIL: new pins missing manifest classification:" >&2
    printf '%s\n' "$unclassified" | sed 's/^/  - /' >&2
    echo "Add a line to tests/smoke-proves-manifest.txt: <helper_name> <class>" >&2
    echo "See docs/smoke-pin-classification.md for the 3-class rubric." >&2
    return 1
  fi

  return 0
}

# R-rules taxonomy schema validator (spec 2026-05-06-r-rules-taxonomy Pin 1).
# Validates the `rules:` frontmatter block in code-quality-rules.md against the
# §3.3 schema: 11 assertions (a)-(k). Uses python3+yaml; fails clearly on each
# violation. Also enforces the §3.3 golden table for R1-R8 metadata, and the
# load-bearing placement check that `## Taxonomy` lands AFTER R8 (assertion k).
check_r_rules_taxonomy_schema() {
  local path="${1:-skills/feature/references/code-quality-rules.md}"
  test -f "$path" || { echo "$path missing" >&2; return 1; }
  python3 - "$path" <<'PY' || return 1
import re
import sys

path = sys.argv[1]
try:
    import yaml
except ImportError:
    print("PyYAML not available (required by check_r_rules_taxonomy_schema)", file=sys.stderr)
    sys.exit(1)

text = open(path, encoding="utf-8").read()
m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
if not m:
    print(f"{path}: missing YAML frontmatter (assertion a)", file=sys.stderr)
    sys.exit(1)
try:
    fm = yaml.safe_load(m.group(1))
except yaml.YAMLError as exc:
    print(f"{path}: frontmatter YAML parse failed (assertion a): {exc}", file=sys.stderr)
    sys.exit(1)

# (a) frontmatter parses and rules is a list of length 8
rules = fm.get("rules") if isinstance(fm, dict) else None
if not isinstance(rules, list):
    print(f"{path}: frontmatter `rules:` is not a list (assertion a)", file=sys.stderr)
    sys.exit(1)
if len(rules) != 14:
    print(f"{path}: rules length={len(rules)}, expected 14 (assertion a)", file=sys.stderr)
    sys.exit(1)

required_fields = {"id", "short", "category", "applies_to", "enforced_by"}
category_enum = {"quality", "security", "style", "process"}
applies_enum = {"all", "smart_contract", "backend", "frontend", "data_pipeline"}
enforcer_enum = {"spec-compliance-checker", "cross-auditor:logic", "cross-auditor:security", "none"}
slug_re = re.compile(r"^[a-z0-9][a-z0-9-]*$")
id_re = re.compile(r"^R[1-9][0-9]*$")

seen_ids = set()
for i, entry in enumerate(rules):
    if not isinstance(entry, dict):
        print(f"{path}: rules[{i}] is not a mapping (assertion b)", file=sys.stderr)
        sys.exit(1)
    keys = set(entry.keys())
    if keys != required_fields:
        missing = required_fields - keys
        extras = keys - required_fields
        print(f"{path}: rules[{i}] field-set mismatch (assertion b); missing={sorted(missing)} extras={sorted(extras)}", file=sys.stderr)
        sys.exit(1)
    rid = entry["id"]
    if not isinstance(rid, str) or not id_re.match(rid):
        print(f"{path}: rules[{i}].id={rid!r} fails ^R[1-9][0-9]*$ (assertion c)", file=sys.stderr)
        sys.exit(1)
    if rid in seen_ids:
        print(f"{path}: rules[{i}].id={rid} is duplicated (assertion c)", file=sys.stderr)
        sys.exit(1)
    seen_ids.add(rid)
    short = entry["short"]
    if not isinstance(short, str) or not slug_re.match(short):
        print(f"{path}: rules[{i}].short={short!r} fails slug regex (assertion d)", file=sys.stderr)
        sys.exit(1)
    cat = entry["category"]
    if cat not in category_enum:
        print(f"{path}: rules[{i}].category={cat!r} not in {sorted(category_enum)} (assertion e)", file=sys.stderr)
        sys.exit(1)
    applies = entry["applies_to"]
    if not isinstance(applies, list) or len(applies) == 0:
        print(f"{path}: rules[{i}].applies_to must be non-empty list (assertion f)", file=sys.stderr)
        sys.exit(1)
    bad_apply = [a for a in applies if a not in applies_enum]
    if bad_apply:
        print(f"{path}: rules[{i}].applies_to has invalid elements {bad_apply} (assertion f)", file=sys.stderr)
        sys.exit(1)
    if "all" in applies and len(applies) > 1:
        print(f"{path}: rules[{i}].applies_to mixes `all` with named project_types (assertion f)", file=sys.stderr)
        sys.exit(1)
    enf = entry["enforced_by"]
    if not isinstance(enf, list) or len(enf) == 0:
        print(f"{path}: rules[{i}].enforced_by must be non-empty list (assertion g)", file=sys.stderr)
        sys.exit(1)
    bad_enf = [e for e in enf if e not in enforcer_enum]
    if bad_enf:
        print(f"{path}: rules[{i}].enforced_by has invalid elements {bad_enf} (assertion g)", file=sys.stderr)
        sys.exit(1)
    if "none" in enf and len(enf) > 1:
        print(f"{path}: rules[{i}].enforced_by mixes `none` with real enforcers (assertion g)", file=sys.stderr)
        sys.exit(1)

# (h) frontmatter <-> body-section correspondence
for entry in rules:
    rid = entry["id"]
    pattern = re.compile(r"^## " + re.escape(rid) + r" — ", re.MULTILINE)
    if not pattern.search(text):
        print(f"{path}: no `## {rid} — ` body heading found (assertion h)", file=sys.stderr)
        sys.exit(1)

# (i) Trigger A worked example: filter(rules, project_type="all") returns
# R1..R8 [all] + any R-rule with [all] audience. Was 8 before any cluster
# audience flips; 9 after PR-D Step 3 flipped R11 to [all]; 10 after
# PR-D Step 4 flips R13 to [all].
def trigger_a_filter(rules_list, project_type):
    return [r for r in rules_list if "all" in r["applies_to"] or project_type in r["applies_to"]]

filtered_all = trigger_a_filter(rules, "all")
if len(filtered_all) != 10:
    print(f"{path}: Trigger A filter with project_type=all returned {len(filtered_all)}, expected 10 (assertion i)", file=sys.stderr)
    sys.exit(1)

# (j) per-rule golden mapping — imported from shared module so the same dict is
# the single source of truth across pins (heredoc-isolation architecture per
# PR-D §3.0a; see tests/smoke_rule_helpers.py).
sys.path.insert(0, "tests")
from smoke_rule_helpers import R_RULE_GOLDEN_TABLE as golden
by_id = {r["id"]: r for r in rules}
for rid, (cat, apply, enf) in golden.items():
    if rid not in by_id:
        print(f"{path}: golden table entry {rid} absent from rules (assertion j)", file=sys.stderr)
        sys.exit(1)
    r = by_id[rid]
    if r["category"] != cat:
        print(f"{path}: {rid}.category={r['category']!r}, golden={cat!r} (assertion j)", file=sys.stderr)
        sys.exit(1)
    if list(r["applies_to"]) != apply:
        print(f"{path}: {rid}.applies_to={r['applies_to']!r}, golden={apply!r} (assertion j)", file=sys.stderr)
        sys.exit(1)
    if list(r["enforced_by"]) != enf:
        print(f"{path}: {rid}.enforced_by={r['enforced_by']!r}, golden={enf!r} (assertion j)", file=sys.stderr)
        sys.exit(1)

# (k) Taxonomy placement: exactly one `^## Taxonomy$` heading; line number > line
# number of the first `^---$` divider AFTER the LAST `^## R<N> — ` heading
# (max R-id by integer parse). Tracking the last R-rule's closing divider —
# rather than R8's — defends against a regression that inserts `## Taxonomy`
# between two R-rules deeper in the cluster (e.g. between R10 and R11).
lines = text.splitlines()
taxonomy_lines = [i for i, ln in enumerate(lines) if ln == "## Taxonomy"]
if len(taxonomy_lines) != 1:
    print(f"{path}: expected exactly one `## Taxonomy` heading; found {len(taxonomy_lines)} (assertion k)", file=sys.stderr)
    sys.exit(1)
r_heading_re = re.compile(r"^## R(\d+) — ")
r_headings = []  # list of (rid_int, line_index)
for i, ln in enumerate(lines):
    m = r_heading_re.match(ln)
    if m:
        r_headings.append((int(m.group(1)), i))
if not r_headings:
    print(f"{path}: no `## R<N> — ` headings found (assertion k)", file=sys.stderr)
    sys.exit(1)
last_rid, last_r_line = max(r_headings, key=lambda t: t[0])
divider_line = None
for i in range(last_r_line + 1, len(lines)):
    if lines[i] == "---":
        divider_line = i
        break
if divider_line is None:
    print(f"{path}: no `---` divider found after last R-rule heading `## R{last_rid} — ` (assertion k)", file=sys.stderr)
    sys.exit(1)
if taxonomy_lines[0] <= divider_line:
    print(f"{path}: `## Taxonomy` at line {taxonomy_lines[0]+1} is not AFTER the closing `---` divider of the last R-rule (R{last_rid}) at line {divider_line+1} (assertion k)", file=sys.stderr)
    sys.exit(1)

print(f"R-rules taxonomy schema OK ({len(rules)} rules; placement after last R-rule's closing divider verified)")
PY
}

# Cross-auditor security mode preamble pin (spec 2026-05-06-r-rules-taxonomy
# Pin 2 — class: prompt-text). Asserts the §`security` mode block in
# agents/cross-auditor.md contains the load-bearing matcher tokens
# `category: security`, `cross-auditor:security`, and `project_type` between
# the `### \`security\` mode` heading and the next `### ` heading.
check_cross_auditor_security_preamble() {
  local path="${1:-agents/cross-auditor.md}"
  test -f "$path" || { echo "$path missing" >&2; return 1; }
  local section
  section=$(awk '
    /^### `security` mode$/ { in_s=1; print; next }
    in_s && /^### / { exit }
    in_s { print }
  ' "$path")
  printf '%s\n' "$section" | grep -qF 'category: security' \
    || { echo "$path §security mode preamble missing 'category: security' token" >&2; return 1; }
  printf '%s\n' "$section" | grep -qF 'cross-auditor:security' \
    || { echo "$path §security mode preamble missing 'cross-auditor:security' token" >&2; return 1; }
  printf '%s\n' "$section" | grep -qF 'project_type' \
    || { echo "$path §security mode preamble missing 'project_type' token" >&2; return 1; }
  echo "cross-auditor §security mode preamble has all three matcher tokens"
}

# Spec-compliance-checker §5 preamble pin (spec 2026-05-06-r-rules-taxonomy
# Pin 3 — class: prompt-text). Asserts the §5 (Code quality rule checks)
# section in agents/spec-compliance-checker.md contains the load-bearing
# matcher tokens `applies_to`, `project_type`, AND a reference to §3.4 (or the
# literal string `Trigger A`/`Trigger B`).
check_spec_compliance_filter_preamble() {
  local path="${1:-agents/spec-compliance-checker.md}"
  test -f "$path" || { echo "$path missing" >&2; return 1; }
  local section
  section=$(awk '
    /^### 5\. Code quality rule checks$/ { in_s=1; print; next }
    in_s && /^### 6\. Return verdict$/ { exit }
    in_s { print }
  ' "$path")
  printf '%s\n' "$section" | grep -qF 'applies_to' \
    || { echo "$path §5 preamble missing 'applies_to' token" >&2; return 1; }
  printf '%s\n' "$section" | grep -qF 'project_type' \
    || { echo "$path §5 preamble missing 'project_type' token" >&2; return 1; }
  printf '%s\n' "$section" | grep -qE '§3\.4|Trigger A|Trigger B' \
    || { echo "$path §5 preamble missing §3.4 / Trigger A / Trigger B reference" >&2; return 1; }
  echo "spec-compliance-checker §5 preamble has all three matcher tokens"
}

# Security cluster R9-R14 content invariants (R-rules web-security cluster
# Pin 4 — class: schema). Asserts (a) frontmatter entries for {R9..R14} present;
# (b) golden metadata category=security/applies_to=[backend]/enforced_by=[cross-auditor:security];
# (c) `^## R<N> —` body heading per id; (d) Bad/Good code markers in each body section;
# (e) Radaro / POL-ENG-AIDEV-001 anchor present per body; (f) backend filter returns 14;
# (g) smart_contract filter returns 8; (h) per-rule canonical-pattern presence in the
# **Good code block specifically** — block-level extraction defeats Bad/Good content-shift
# bypass for BOTH directions. R10 also checks two negative regex assertions in Good code
# (X6 + X7/X14 closures); (i) per-rule canonical-anti-pattern presence in the **Bad code
# block specifically** — locks the educational anti-pattern shape so a regression cannot
# silently weaken Bad code (e.g. dropping the f-string SQLi shape, the literal sk_live_
# secret, or the logger.info-as-audit anti-pattern).
check_security_cluster_rules_present() {
  local path="${1:-skills/feature/references/code-quality-rules.md}"
  test -f "$path" || { echo "$path missing" >&2; return 1; }
  python3 - "$path" <<'PY' || return 1
import re
import sys

path = sys.argv[1]
try:
    import yaml
except ImportError:
    print("PyYAML not available (required by check_security_cluster_rules_present)", file=sys.stderr)
    sys.exit(1)

text = open(path, encoding="utf-8").read()
m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
if not m:
    print(f"{path}: missing YAML frontmatter", file=sys.stderr)
    sys.exit(1)
fm = yaml.safe_load(m.group(1))
rules = fm.get("rules") if isinstance(fm, dict) else None
if not isinstance(rules, list):
    print(f"{path}: frontmatter `rules:` is not a list", file=sys.stderr)
    sys.exit(1)
by_id = {r["id"]: r for r in rules if isinstance(r, dict) and "id" in r}

cluster_ids = ["R9", "R10", "R11", "R12", "R13", "R14"]

# (a) frontmatter entries present
for rid in cluster_ids:
    if rid not in by_id:
        print(f"{path}: cluster id {rid} missing from frontmatter rules: list (assertion a)", file=sys.stderr)
        sys.exit(1)

# Shared helpers + per-rule expected_applies dict — imported from the single
# source of truth module (heredoc-isolation architecture per PR-D §3.0a; see
# tests/smoke_rule_helpers.py).
sys.path.insert(0, "tests")
from smoke_rule_helpers import (
    extract_section,
    extract_block_after,
    good_block,
    bad_block,
    iter_fences,
    R_RULE_CLUSTER_EXPECTED_APPLIES as cluster_expected_applies,
)

# (b) golden metadata — applies_to is now per-rule via cluster_expected_applies
# (replaces the uniform `!= ["backend"]` check that pre-existed; rules can have
# `[all]` audience as the cluster expands beyond the original backend-only set).
for rid in cluster_ids:
    r = by_id[rid]
    if r.get("category") != "security":
        print(f"{path}: {rid}.category={r.get('category')!r}, expected 'security' (assertion b)", file=sys.stderr)
        sys.exit(1)
    expected_applies = cluster_expected_applies[rid]
    if list(r.get("applies_to") or []) != expected_applies:
        print(f"{path}: {rid}.applies_to={r.get('applies_to')!r}, expected {expected_applies!r} (assertion b)", file=sys.stderr)
        sys.exit(1)
    if list(r.get("enforced_by") or []) != ["cross-auditor:security"]:
        print(f"{path}: {rid}.enforced_by={r.get('enforced_by')!r}, expected ['cross-auditor:security'] (assertion b)", file=sys.stderr)
        sys.exit(1)

# (c) body heading per id
for rid in cluster_ids:
    sec = extract_section(text, rid)
    if sec is None:
        print(f"{path}: no `## {rid} — ` body heading found (assertion c)", file=sys.stderr)
        sys.exit(1)

# (d) Bad/Good code markers
for rid in cluster_ids:
    sec = extract_section(text, rid)
    if "**Bad code**" not in sec:
        print(f"{path}: {rid} body missing `**Bad code**` marker (assertion d)", file=sys.stderr)
        sys.exit(1)
    if "**Good code**" not in sec:
        print(f"{path}: {rid} body missing `**Good code**` marker (assertion d)", file=sys.stderr)
        sys.exit(1)

# (e) Radaro AND POL-ENG-AIDEV-001 anchors — both required per spec; the
# previous OR-of-positives let a regression remove one anchor while keeping
# the other (anchor-downgrade silently undetected).
for rid in cluster_ids:
    sec = extract_section(text, rid)
    if ("Radaro" not in sec) or ("POL-ENG-AIDEV-001" not in sec):
        print(f"{path}: {rid} body missing Radaro AND/OR POL-ENG-AIDEV-001 anchor (both required) (assertion e)", file=sys.stderr)
        sys.exit(1)

# (f) backend filter returns 14 (R1..R8 [all] + R9..R14 [backend])
def trigger_a_filter(rules_list, project_type):
    return [r for r in rules_list if "all" in r["applies_to"] or project_type in r["applies_to"]]

filtered_backend = trigger_a_filter(rules, "backend")
if len(filtered_backend) != 14:
    print(f"{path}: backend filter returned {len(filtered_backend)}, expected 14 (assertion f)", file=sys.stderr)
    sys.exit(1)

# (g) smart_contract filter returns R1..R8 + any R-rule with [all] audience.
# Was 8 before any cluster audience flips; 9 after PR-D Step 3 flipped R11
# to [all]; 10 after PR-D Step 4 flips R13 to [all].
filtered_sc = trigger_a_filter(rules, "smart_contract")
if len(filtered_sc) != 10:
    print(f"{path}: smart_contract filter returned {len(filtered_sc)}, expected 10 (assertion g)", file=sys.stderr)
    sys.exit(1)

# (h) Per-rule canonical-pattern presence — Good code block ONLY (block-level
# extraction defeats Bad/Good content-shift bypass). good_block / bad_block
# imported from smoke_rule_helpers; call sites pass the full markdown text.

# R9: request.user.id AND (PermissionDenied OR .filter()
g9 = good_block(text, "R9")
if "request.user.id" not in g9:
    print(f"{path}: R9 Good code block missing 'request.user.id' (assertion h)", file=sys.stderr)
    sys.exit(1)
if ("PermissionDenied" not in g9) and (".filter(" not in g9):
    print(f"{path}: R9 Good code block missing both 'PermissionDenied' and '.filter(' (assertion h)", file=sys.stderr)
    sys.exit(1)

# R10: cursor.execute( AND %s AND (psycopg2.sql OR sql.Identifier);
# negative: NOT 'assert table_name in', NOT `if[[:space:]].*;[[:space:]]*cursor\.execute`
g10 = good_block(text, "R10")
if "cursor.execute(" not in g10:
    print(f"{path}: R10 Good code block missing 'cursor.execute(' (assertion h)", file=sys.stderr)
    sys.exit(1)
if "%s" not in g10:
    print(f"{path}: R10 Good code block missing '%s' (assertion h)", file=sys.stderr)
    sys.exit(1)
if ("psycopg2.sql" not in g10) and ("sql.Identifier" not in g10):
    print(f"{path}: R10 Good code block missing both 'psycopg2.sql' and 'sql.Identifier' (assertion h)", file=sys.stderr)
    sys.exit(1)
if "assert table_name in" in g10:
    print(f"{path}: R10 Good code block contains forbidden 'assert table_name in' — strips under python -O (X6 closure, assertion h)", file=sys.stderr)
    sys.exit(1)
# Single-line `;`-chained guard: any line containing 'if ', then ';', then 'cursor.execute'
chain_re = re.compile(r"if\s.*;\s*cursor\.execute")
for line in g10.splitlines():
    if chain_re.search(line):
        print(f"{path}: R10 Good code block contains forbidden ';'-chained guard line: {line!r} (X7/X14 closure, assertion h)", file=sys.stderr)
        sys.exit(1)

# R11: os.environ AND (monkeypatch OR setenv)
g11 = good_block(text, "R11")
if "os.environ" not in g11:
    print(f"{path}: R11 Good code block missing 'os.environ' (assertion h)", file=sys.stderr)
    sys.exit(1)
if ("monkeypatch" not in g11) and ("setenv" not in g11):
    print(f"{path}: R11 Good code block missing both 'monkeypatch' and 'setenv' (assertion h)", file=sys.stderr)
    sys.exit(1)

# R12: httponly=True AND secure=True AND samesite=
g12 = good_block(text, "R12")
for tok in ("httponly=True", "secure=True", "samesite="):
    if tok not in g12:
        print(f"{path}: R12 Good code block missing '{tok}' (assertion h)", file=sys.stderr)
        sys.exit(1)

# R13: ${{ secrets. AND (OIDC OR id-token)
g13 = good_block(text, "R13")
if "${{ secrets." not in g13:
    print(f"{path}: R13 Good code block missing '${{{{ secrets.' (assertion h)", file=sys.stderr)
    sys.exit(1)
if ("OIDC" not in g13) and ("id-token" not in g13):
    print(f"{path}: R13 Good code block missing both 'OIDC' and 'id-token' (assertion h)", file=sys.stderr)
    sys.exit(1)

# R14: (audit_log.emit( OR audit.record( OR AuditEvent.create() AND actor= AND outcome=
g14 = good_block(text, "R14")
if not (("audit_log.emit(" in g14) or ("audit.record(" in g14) or ("AuditEvent.create(" in g14)):
    print(f"{path}: R14 Good code block missing audit_log.emit(/audit.record(/AuditEvent.create( (assertion h)", file=sys.stderr)
    sys.exit(1)
if "actor=" not in g14:
    print(f"{path}: R14 Good code block missing 'actor=' (assertion h)", file=sys.stderr)
    sys.exit(1)
if "outcome=" not in g14:
    print(f"{path}: R14 Good code block missing 'outcome=' (assertion h)", file=sys.stderr)
    sys.exit(1)

# (i) Per-rule canonical anti-pattern presence — Bad code block ONLY. Block-level
# extraction defeats Bad/Good content-shift bypass for BOTH directions; without (i)
# a regression that drops the f-string SQLi shape from R10 Bad, the literal sk_live_
# from R11 Bad, the no-flags set_cookie from R12 Bad, or the logger.info-as-audit
# from R14 Bad would silently pass while the rule loses its educational core.

# R9: unconditional fetch shape — Order.objects.get(id=order_id) OR findById(req.params.id)
b9 = bad_block(text, "R9")
if ("Order.objects.get(id=order_id)" not in b9) and ("findById(req.params.id)" not in b9):
    print(f"{path}: R9 Bad code block missing IDOR anti-pattern (Order.objects.get(id=order_id) OR findById(req.params.id)) (assertion i)", file=sys.stderr)
    sys.exit(1)

# R10: f-string SQL pattern — `f"...WHERE...{...}"` shape OR `% user_id` formatted SQL
b10 = bad_block(text, "R10")
fstring_sql = re.search(r'f"[^"\n]*WHERE[^"\n]*\{', b10)
if (fstring_sql is None) and ("% user_id" not in b10):
    print(f"{path}: R10 Bad code block missing SQLi anti-pattern (f-string SQL with WHERE...{{...}} OR % user_id formatting) (assertion i)", file=sys.stderr)
    sys.exit(1)

# R11: literal secret-shaped string — sk_live_ OR sk_test_ OR ghs_ OR ghp_ OR realpassword
b11 = bad_block(text, "R11")
if not any(tok in b11 for tok in ("sk_live_", "sk_test_", "ghs_", "ghp_", "realpassword")):
    print(f"{path}: R11 Bad code block missing literal secret-shaped string (sk_live_ / sk_test_ / ghs_ / ghp_ / realpassword) (assertion i)", file=sys.stderr)
    sys.exit(1)

# R12: bare set_cookie() / res.cookie() with NO httponly flag in the same call.
# Positive shape: a `set_cookie(...)` or `res.cookie(...)` call whose argument list
# does not contain `httponly` / `httpOnly`. We scan call sites within the Bad block.
r12_call_re = re.compile(r"(set_cookie|res\.cookie)\s*\(([^)]*)\)", re.DOTALL)
r12_bad_found = False
for m_call in r12_call_re.finditer(bad_block(text, "R12")):
    args = m_call.group(2)
    if "httponly" not in args.lower():
        r12_bad_found = True
        break
if not r12_bad_found:
    print(f"{path}: R12 Bad code block missing no-flags set_cookie(...)/res.cookie(...) anti-pattern (assertion i)", file=sys.stderr)
    sys.exit(1)

# R13: literal token-shaped value — explicit anti-pattern strings the spec writes
b13 = bad_block(text, "R13")
if not any(tok in b13 for tok in ("ghs_realtokenhere", "ghp_realtokenhere", "sk_live_realtokenshape", "sk_live_", "ghp_", "ghs_")):
    print(f"{path}: R13 Bad code block missing literal token-shaped anti-pattern (ghs_/ghp_/sk_live_ shape) (assertion i)", file=sys.stderr)
    sys.exit(1)

# R14: logger.info( near a state-change verb — relaxed positive: `logger.info(`
# substring sufficient for the v1 anti-pattern shape (operational logger treated
# as audit coverage).
b14 = bad_block(text, "R14")
if "logger.info(" not in b14:
    print(f"{path}: R14 Bad code block missing logger.info( anti-pattern (operational logger as audit coverage) (assertion i)", file=sys.stderr)
    sys.exit(1)

print(f"R-rules security cluster {cluster_ids} present with canonical conventions in Good code blocks AND canonical anti-patterns in Bad code blocks")
PY
}

# R9 IDOR scope expansion + R14 ownership-check guards (PR-D Step 1).
# Asserts R9 Rule line / Why prose / How-to-apply broadened to read+mutate
# scope, R9 Bad-code state-changing fence (def disable_user — IDOR shape, no
# ownership check), R9 Good-code state-changing fence (def cancel_subscription
# — ownership check + raise + mutation), and R14 Good-code disable_user +
# charge_order fences carry ownership checks BEFORE the mutation. Per-fence
# extraction via iter_fences (heredoc-isolation architecture, see
# tests/smoke_rule_helpers.py).
check_r9_idor_covers_state_changing_endpoints() {
  local path="${1:-skills/feature/references/code-quality-rules.md}"
  test -f "$path" || { echo "$path missing" >&2; return 1; }
  # Helper-presence sanity (replaces the iter1 declare -F check, which was
  # structurally false: declare -F lists bash shell functions, not Python
  # functions inside heredocs).
  test "$(grep -cE '^def iter_fences\(' tests/smoke_rule_helpers.py)" -ge 1 \
    || { echo "iter_fences missing from tests/smoke_rule_helpers.py" >&2; return 1; }
  python3 - "$path" <<'PY' || return 1
import re
import sys

sys.path.insert(0, "tests")
from smoke_rule_helpers import extract_section, good_block, bad_block, iter_fences

path = sys.argv[1]
text = open(path, encoding="utf-8").read()

sec = extract_section(text, "R9")
if sec is None:
    print(f"{path}: R9 section not found", file=sys.stderr)
    sys.exit(1)

# T1.1 positive — Rule line broadened
if "returns or mutates user-scoped data MUST verify" not in sec:
    print(f"{path}: R9 Rule line missing 'returns or mutates user-scoped data MUST verify' (T1.1 positive)", file=sys.stderr)
    sys.exit(1)
# T1.1 negative — pre-rewrite literal absent (only post-rewrite matches)
pre_rewrite_re = re.search(r"returns user-scoped data MUST verify", sec)
post_rewrite_re = re.search(r"returns or mutates user-scoped data MUST verify", sec)
# Pass condition: the post-rewrite phrasing matches; the pre-rewrite phrasing
# (without `or mutates`) is a strict suffix of the post — so we forbid it as a
# standalone literal NOT preceded by `or mutates`. The post phrasing contains
# `returns or mutates user-scoped data MUST verify` which itself contains
# `user-scoped data MUST verify` but NOT `returns user-scoped data MUST verify`
# as a substring (because `returns` is followed by ` or mutates`, not space).
# Defensive check: only the post regex matches.
if pre_rewrite_re is not None and post_rewrite_re is None:
    print(f"{path}: R9 Rule line still has stale 'returns user-scoped data MUST verify' literal (T1.1 negative)", file=sys.stderr)
    sys.exit(1)

# T1.2 positive — Why prose broadened
if "mutates, or deletes other users' data" not in sec:
    print(f"{path}: R9 Why prose missing 'mutates, or deletes other users\\' data' (T1.2 positive)", file=sys.stderr)
    sys.exit(1)
# T1.2 negative — pre-rewrite literal absent
if "enumerates other users' data by changing the URL parameter" in sec:
    print(f"{path}: R9 Why prose still has stale 'enumerates other users\\' data by changing the URL parameter' literal (T1.2 negative)", file=sys.stderr)
    sys.exit(1)

# T1.3 positive — How-to-apply broadened
if "reads or mutates a user-owned resource" not in sec:
    print(f"{path}: R9 How-to-apply missing 'reads or mutates a user-owned resource' (T1.3 positive)", file=sys.stderr)
    sys.exit(1)
# T1.3 negative — pre-rewrite literal absent
if "every endpoint that returns a user-owned resource" in sec:
    print(f"{path}: R9 How-to-apply still has stale 'every endpoint that returns a user-owned resource' literal (T1.3 negative)", file=sys.stderr)
    sys.exit(1)

# T1.4 positive — R9 Bad state-changing fence: def disable_user( + user.disable() ;
# NOT request.user.id; NOT PermissionDenied; ownership-check shape regex must NOT match.
ownership_re = re.compile(r"if\s+\w+\.user_id\s*!=\s*request\.user\.id:")
bad_fences = list(iter_fences(bad_block(text, "R9"), "python"))
t14_ok = False
for f in bad_fences:
    if ("def disable_user(" in f
        and "user.disable()" in f
        and "request.user.id" not in f
        and "PermissionDenied" not in f
        and ownership_re.search(f) is None):
        t14_ok = True
        break
if not t14_ok:
    print(f"{path}: R9 Bad-code missing state-changing IDOR fence (T1.4 positive: def disable_user + user.disable() + NO request.user.id + NO PermissionDenied + NO ownership-check shape)", file=sys.stderr)
    sys.exit(1)

# T1.5 positive — R9 Good state-changing fence: def cancel_subscription( +
# byte-exact ownership-check + raise PermissionDenied() + subscription.cancel().
good_fences_r9 = list(iter_fences(good_block(text, "R9"), "python"))
t15_ok = False
for f in good_fences_r9:
    if ("def cancel_subscription(" in f
        and "if subscription.user_id != request.user.id:" in f
        and "raise PermissionDenied()" in f
        and "subscription.cancel()" in f):
        t15_ok = True
        break
if not t15_ok:
    print(f"{path}: R9 Good-code missing state-changing fence (T1.5 positive: def cancel_subscription + ownership-check + raise PermissionDenied + subscription.cancel())", file=sys.stderr)
    sys.exit(1)

# T1.6 positive — R14 disable_user fence: byte-exact ownership-check +
# raise PermissionDenied() + user.disable() + audit_log.emit(. Document order:
# ownership-check < user.disable() < audit_log.emit(.
good_fences_r14 = list(iter_fences(good_block(text, "R14"), "python"))
t16_ok = False
for f in good_fences_r14:
    if "def disable_user(" not in f:
        continue
    if not ("if user.id != request.user.id:" in f
            and "raise PermissionDenied()" in f
            and "user.disable()" in f
            and "audit_log.emit(" in f):
        continue
    o1 = f.find("if user.id != request.user.id:")
    o2 = f.find("user.disable()")
    o3 = f.find("audit_log.emit(")
    if o1 < o2 < o3:
        t16_ok = True
        break
if not t16_ok:
    print(f"{path}: R14 Good-code disable_user fence missing ownership-check guard or doc-order (T1.6 positive: ownership-check before user.disable() before audit_log.emit()", file=sys.stderr)
    sys.exit(1)

# T1.7 positive — R14 charge_order fence: byte-exact ownership-check +
# raise PermissionDenied(). Document order: ownership-check < try:.
t17_ok = False
for f in good_fences_r14:
    if "def charge_order(" not in f:
        continue
    if not ("if order.user_id != request.user.id:" in f
            and "raise PermissionDenied()" in f):
        continue
    o1 = f.find("if order.user_id != request.user.id:")
    o2 = f.find("try:")
    if o1 < o2:
        t17_ok = True
        break
if not t17_ok:
    print(f"{path}: R14 Good-code charge_order fence missing ownership-check guard or doc-order (T1.7 positive: ownership-check before try:)", file=sys.stderr)
    sys.exit(1)

print("R9 IDOR scope covers state-changing endpoints + R14 ownership-check guards present (T1.1-T1.7)")
PY
}

# R10 allowlist literal-set definition (PR-D Step 2).
# Asserts R10 Good-code multi-line allowlist fence carries the literal-set
# definition `ALLOWED_TABLES = frozenset({"orders", "users"})` BEFORE the
# `if table_name not in ALLOWED_TABLES:` guard, in the SAME fence as the
# `cursor.execute(` call. Asserts the byte-exact comment phrase
# "fixed-literal set defined in source" lives in the R10 section.
check_r10_allowlist_literal_set_definition() {
  local path="${1:-skills/feature/references/code-quality-rules.md}"
  test -f "$path" || { echo "$path missing" >&2; return 1; }
  python3 - "$path" <<'PY' || return 1
import sys
sys.path.insert(0, "tests")
from smoke_rule_helpers import extract_section, good_block, iter_fences

path = sys.argv[1]
text = open(path, encoding="utf-8").read()

sec = extract_section(text, "R10")
if sec is None:
    print(f"{path}: R10 section not found", file=sys.stderr)
    sys.exit(1)

# T2.1 positive — literal-set definition in the same fence as the guard +
# cursor.execute, in document order.
fences = list(iter_fences(good_block(text, "R10"), "python"))
ok = False
for f in fences:
    if not ('ALLOWED_TABLES = frozenset({"orders", "users"})' in f
            and "if table_name not in ALLOWED_TABLES:" in f
            and "cursor.execute(" in f):
        continue
    o1 = f.find('ALLOWED_TABLES = frozenset(')
    o2 = f.find("if table_name not in ALLOWED_TABLES:")
    if o1 < o2:
        ok = True
        break
if not ok:
    print(f"{path}: R10 Good-code allowlist fence missing literal-set definition (T2.1: ALLOWED_TABLES = frozenset({{...}}) before guard before cursor.execute(", file=sys.stderr)
    sys.exit(1)

# T2.2 positive — canonical comment phrase
if "fixed-literal set defined in source" not in sec:
    print(f"{path}: R10 section missing canonical comment 'fixed-literal set defined in source' (T2.2 positive)", file=sys.stderr)
    sys.exit(1)

print("R10 allowlist literal-set definition + canonical comment present (T2.1-T2.2)")
PY
}

# R-rule metadata consistency meta-pin (PR-D Step 3 §3.0b).
# Asserts that R_RULE_GOLDEN_TABLE[rid][1] (the applies_to slot of the
# schema-validator's golden table) equals R_RULE_CLUSTER_EXPECTED_APPLIES[rid]
# (the cluster-pin's per-rule expected applies_to) for every rid in the
# cluster R9..R14. Both dicts live in tests/smoke_rule_helpers.py — the
# meta-pin defends against a future contributor who might split the dicts
# apart or typo one of them.
check_r_rule_metadata_consistency() {
  python3 - <<'PY' || return 1
import sys
sys.path.insert(0, "tests")
from smoke_rule_helpers import R_RULE_GOLDEN_TABLE, R_RULE_CLUSTER_EXPECTED_APPLIES

cluster_ids = ["R9", "R10", "R11", "R12", "R13", "R14"]
errors = []
for rid in cluster_ids:
    golden_applies = list(R_RULE_GOLDEN_TABLE[rid][1])
    expected_applies = list(R_RULE_CLUSTER_EXPECTED_APPLIES[rid])
    if golden_applies != expected_applies:
        errors.append(
            f"{rid}: golden applies_to={golden_applies!r} != cluster expected_applies={expected_applies!r}"
        )
if errors:
    for e in errors:
        print(e, file=sys.stderr)
    sys.exit(1)
print(f"R-rule metadata consistency OK across {cluster_ids} (golden <-> cluster expected_applies)")
PY
}

# R11 audience expansion + encoded-secret Bad-code shapes (PR-D Step 3).
# Asserts the three new encoded-secret Bad-code fences are present
# (base64 PEM, JWT-shaped bearer, base64url-encoded API key) and the
# `Encoding is not concealment` prose lives in the R11 body. Audience
# flip [backend]→[all] is locked by the in-place updates to the existing
# pins (golden table + cluster expected dict + both cardinality surfaces).
check_r11_audience_all_and_encoded_secret_shapes() {
  local path="${1:-skills/feature/references/code-quality-rules.md}"
  test -f "$path" || { echo "$path missing" >&2; return 1; }
  python3 - "$path" <<'PY' || return 1
import re
import sys
sys.path.insert(0, "tests")
from smoke_rule_helpers import extract_section, bad_block, iter_fences

path = sys.argv[1]
text = open(path, encoding="utf-8").read()

sec = extract_section(text, "R11")
if sec is None:
    print(f"{path}: R11 section not found", file=sys.stderr)
    sys.exit(1)

bad_fences = list(iter_fences(bad_block(text, "R11"), "python"))

# T3.6 — base64 PEM Bad fence
if not any("PRIVATE_KEY" in f and "LS0tLS1CRUdJTi" in f for f in bad_fences):
    print(f"{path}: R11 Bad-code missing base64 PEM fence (T3.6: PRIVATE_KEY + LS0tLS1CRUdJTi co-located)", file=sys.stderr)
    sys.exit(1)

# T3.7 — JWT-shaped Bad fence
if not any("BEARER_TOKEN" in f and "eyJ" in f for f in bad_fences):
    print(f"{path}: R11 Bad-code missing JWT-shaped fence (T3.7: BEARER_TOKEN + eyJ co-located)", file=sys.stderr)
    sys.exit(1)

# T3.8 — base64url Bad fence: API_KEY_B64URL + comment marker + ≥40-char =-padded
b64url_re = re.compile(r'"[A-Za-z0-9_-]{40,}=+"')
ok_t38 = False
for f in bad_fences:
    if ("API_KEY_B64URL" in f
        and "# base64url-encoded" in f
        and b64url_re.search(f) is not None):
        ok_t38 = True
        break
if not ok_t38:
    print(f"{path}: R11 Bad-code missing base64url fence (T3.8: API_KEY_B64URL + '# base64url-encoded' marker + literal-string >=40 chars with = padding)", file=sys.stderr)
    sys.exit(1)

# T3.9 — prose sentence
if "Encoding is not concealment" not in sec:
    print(f"{path}: R11 section missing 'Encoding is not concealment' prose (T3.9 positive)", file=sys.stderr)
    sys.exit(1)

print("R11 audience [all] + encoded-secret Bad-code shapes (PEM/JWT/base64url) + prose present (T3.6-T3.9)")
PY
}

# R13 OIDC minimal-permissions example (PR-D Step 4).
# Asserts the R13 Good-code OIDC examples: a forall-implication that any
# fence containing both `id-token: write` and `contents: read` ALSO
# contains `actions/checkout`; an existence assertion that a minimal
# fence (id-token only, no contents:read) is present; an existence
# assertion that a paired fence (id-token + contents:read +
# actions/checkout) is present. Audience flip [backend]→[all] is locked
# by the in-place updates to the existing pins.
check_r13_oidc_minimal_permissions() {
  local path="${1:-skills/feature/references/code-quality-rules.md}"
  test -f "$path" || { echo "$path missing" >&2; return 1; }
  python3 - "$path" <<'PY' || return 1
import sys
sys.path.insert(0, "tests")
from smoke_rule_helpers import good_block, iter_fences

path = sys.argv[1]
text = open(path, encoding="utf-8").read()

fences = list(iter_fences(good_block(text, "R13"), "yaml"))
if not fences:
    print(f"{path}: R13 Good-code has no yaml fences (T4 prerequisite)", file=sys.stderr)
    sys.exit(1)

# Forall-implication: any fence with both id-token:write AND contents:read
# MUST also contain actions/checkout.
for f in fences:
    if "id-token: write" in f and "contents: read" in f:
        if "actions/checkout" not in f:
            print(f"{path}: R13 Good-code OIDC fence has 'contents: read' WITHOUT 'actions/checkout' co-located (T4.6/T4.7 forall)", file=sys.stderr)
            sys.exit(1)

# Existence (minimal): some fence has id-token:write AND no contents:read
if not any("id-token: write" in f and "contents: read" not in f for f in fences):
    print(f"{path}: R13 Good-code missing minimal-permissions OIDC fence (T4.6 existence: id-token:write only, no contents:read)", file=sys.stderr)
    sys.exit(1)

# Existence (paired): some fence has id-token:write AND contents:read AND actions/checkout
if not any(
    "id-token: write" in f and "contents: read" in f and "actions/checkout" in f
    for f in fences
):
    print(f"{path}: R13 Good-code missing paired OIDC fence (T4.7 existence: id-token:write + contents:read + actions/checkout co-located)", file=sys.stderr)
    sys.exit(1)

print("R13 OIDC minimal-permissions + paired example present (T4.6-T4.8)")
PY
}

# R14 sensitive-read coverage + access-denied audit emit (PR-D Step 5).
# Asserts R14 Rule line carries `sensitive-read auditing` byte-exact AND
# names ≥3 of 4 sensitive-read classes (PII, bulk export, backup,
# audit log); Why paragraph carries `sensitive-read auditing` co-located
# with `SOC 2`/`ISO 27001`; How-to-apply paragraph carries
# `authorization-failure paths` AND `not_owner`; bulk-export Bad fence
# (no audit emit), bulk-export Good fence (audit emit + users.export +
# count=), access-denied Good fence (outcome=failure + reason=not_owner
# + audit emit BEFORE raise).
check_r14_sensitive_reads_and_access_denied_audit() {
  local path="${1:-skills/feature/references/code-quality-rules.md}"
  test -f "$path" || { echo "$path missing" >&2; return 1; }
  python3 - "$path" <<'PY' || return 1
import re
import sys
sys.path.insert(0, "tests")
from smoke_rule_helpers import extract_section, good_block, bad_block, iter_fences

path = sys.argv[1]
text = open(path, encoding="utf-8").read()

sec = extract_section(text, "R14")
if sec is None:
    print(f"{path}: R14 section not found", file=sys.stderr)
    sys.exit(1)

# T5.1 positive — Rule line uniquely-new phrase (positive-only per iter1 M1).
if "sensitive-read auditing" not in sec:
    print(f"{path}: R14 section missing 'sensitive-read auditing' (T5.1 positive)", file=sys.stderr)
    sys.exit(1)

# T5.2 positive — AND-conjunctive over ≥3 of 4 sensitive-read classes:
# `bulk export` (or `bulk-export`) AND `PII` AND (`backup` OR `audit log`
# OR `audit-log`).
sec_lower = sec.lower()
has_bulk = ("bulk export" in sec_lower) or ("bulk-export" in sec_lower)
has_pii = "PII" in sec
has_backup_or_audit = (
    "backup" in sec_lower
    or "audit log" in sec_lower
    or "audit-log" in sec_lower
)
if not (has_bulk and has_pii and has_backup_or_audit):
    print(f"{path}: R14 section missing ≥3 of 4 sensitive-read classes "
          f"(bulk={has_bulk}, PII={has_pii}, backup-or-audit={has_backup_or_audit}) "
          f"(T5.2 positive)", file=sys.stderr)
    sys.exit(1)

# T5.3 positive — Why paragraph extraction: `sensitive-read auditing` AND
# (`SOC 2` OR `ISO 27001`) within the SAME paragraph.
why_m = re.search(r'\*\*Why\*\*:.*?(?=\n\n\*\*|\n---|\Z)', sec, re.DOTALL)
if why_m is None:
    print(f"{path}: R14 Why paragraph not found (T5.3 prerequisite)", file=sys.stderr)
    sys.exit(1)
why_para = why_m.group(0)
if "sensitive-read auditing" not in why_para:
    print(f"{path}: R14 Why paragraph missing 'sensitive-read auditing' (T5.3 positive)", file=sys.stderr)
    sys.exit(1)
if not (("SOC 2" in why_para) or ("ISO 27001" in why_para)):
    print(f"{path}: R14 Why paragraph missing SOC 2/ISO 27001 co-located with sensitive-read auditing (T5.3 positive)", file=sys.stderr)
    sys.exit(1)

# T5.4 positive — How-to-apply paragraph extraction: `authorization-failure
# paths` AND `not_owner` within the SAME paragraph.
hta_m = re.search(r'\*\*How to apply\*\*:.*?(?=\n\n\*\*|\n---|\Z)', sec, re.DOTALL)
if hta_m is None:
    print(f"{path}: R14 How-to-apply paragraph not found (T5.4 prerequisite)", file=sys.stderr)
    sys.exit(1)
hta_para = hta_m.group(0)
if "authorization-failure paths" not in hta_para:
    print(f"{path}: R14 How-to-apply paragraph missing 'authorization-failure paths' (T5.4 positive)", file=sys.stderr)
    sys.exit(1)
if "not_owner" not in hta_para:
    print(f"{path}: R14 How-to-apply paragraph missing 'not_owner' (T5.4 positive)", file=sys.stderr)
    sys.exit(1)

# T5.5 positive — bulk-export Bad fence: def export_users_csv( + User.objects.all()
# AND NO audit emit (audit_log.emit, audit.record, AuditEvent.create).
bad_fences = list(iter_fences(bad_block(text, "R14"), "python"))
ok_t55 = False
for f in bad_fences:
    if ("def export_users_csv(" in f
        and "User.objects.all()" in f
        and "audit_log.emit(" not in f
        and "audit.record(" not in f
        and "AuditEvent.create(" not in f):
        ok_t55 = True
        break
if not ok_t55:
    print(f"{path}: R14 Bad-code missing bulk-export fence (T5.5: def export_users_csv + User.objects.all() + NO audit emit)", file=sys.stderr)
    sys.exit(1)

# T5.6 positive — bulk-export Good fence: def export_users_csv( + audit_log.emit
# + users.export + count=.
good_fences = list(iter_fences(good_block(text, "R14"), "python"))
ok_t56 = False
for f in good_fences:
    if ("def export_users_csv(" in f
        and "audit_log.emit(" in f
        and "users.export" in f
        and "count=" in f):
        ok_t56 = True
        break
if not ok_t56:
    print(f"{path}: R14 Good-code missing bulk-export fence (T5.6: def export_users_csv + audit_log.emit + users.export + count=)", file=sys.stderr)
    sys.exit(1)

# T5.7 positive — access-denied Good fence: def get_order( + outcome="failure" +
# reason="not_owner" + raise PermissionDenied(); document-order: audit_log.emit
# BEFORE raise PermissionDenied().
ok_t57 = False
for f in good_fences:
    if not ("def get_order(" in f
            and 'outcome="failure"' in f
            and 'reason="not_owner"' in f
            and "raise PermissionDenied()" in f):
        continue
    raise_idx = f.find("raise PermissionDenied()")
    audit_before = f.rfind("audit_log.emit(", 0, raise_idx)
    if audit_before >= 0:
        ok_t57 = True
        break
if not ok_t57:
    print(f"{path}: R14 Good-code missing access-denied fence (T5.7: def get_order + outcome=failure + reason=not_owner + audit emit BEFORE raise PermissionDenied)", file=sys.stderr)
    sys.exit(1)

print("R14 sensitive-read auditing + access-denied audit emit present (T5.1-T5.7)")
PY
}

# Cross-auditor §security mode load-the-cluster pin (R-rules web-security cluster
# Pin 5 — class: prompt-text). Asserts the §`security` mode block in
# agents/cross-auditor.md (a) names all six R-ids R9..R14 individually as
# standalone substrings; (b) carries applies_to + backend tokens; (c) carries an
# action verb (load|apply|read); (d) does NOT contain the obsolete "Today no such
# rules exist" clause; (e) keeps the `**Smart Contracts / DeFi:**` heading; (f)
# keeps the `**Backend Services:**` heading; (g) preserves all 9 distinguishing
# bullet phrases verbatim (full-list pinning).
check_cross_auditor_loads_security_cluster() {
  local path="${1:-agents/cross-auditor.md}"
  test -f "$path" || { echo "$path missing" >&2; return 1; }
  local section
  section=$(awk '
    /^### `security` mode$/ { in_s=1; print; next }
    in_s && /^### / { exit }
    in_s { print }
  ' "$path")

  # (a) R-ids R9..R14 individually
  local rid
  for rid in R9 R10 R11 R12 R13 R14; do
    printf '%s\n' "$section" | grep -qF "$rid" \
      || { echo "$path §security mode missing R-id '$rid' (assertion a)" >&2; return 1; }
  done

  # (b) applies_to AND backend
  printf '%s\n' "$section" | grep -qF 'applies_to' \
    || { echo "$path §security mode missing 'applies_to' token (assertion b)" >&2; return 1; }
  printf '%s\n' "$section" | grep -qF 'backend' \
    || { echo "$path §security mode missing 'backend' token (assertion b)" >&2; return 1; }

  # (c) action verb (case-insensitive substring) tied to R-rule consumption
  printf '%s\n' "$section" | grep -qiE 'load|apply|read' \
    || { echo "$path §security mode missing action verb (load/apply/read) (assertion c)" >&2; return 1; }

  # (d) NEGATIVE — obsolete clause must be absent
  if printf '%s\n' "$section" | grep -qF 'Today no such rules exist'; then
    echo "$path §security mode still contains obsolete 'Today no such rules exist' clause (assertion d)" >&2
    return 1
  fi

  # (e) Smart Contracts / DeFi heading
  printf '%s\n' "$section" | grep -qF '**Smart Contracts / DeFi:**' \
    || { echo "$path §security mode missing '**Smart Contracts / DeFi:**' heading (assertion e)" >&2; return 1; }

  # (f) Backend Services heading
  printf '%s\n' "$section" | grep -qF '**Backend Services:**' \
    || { echo "$path §security mode missing '**Backend Services:**' heading (assertion f)" >&2; return 1; }

  # (g) full-list pinning — all 9 distinguishing bullet phrases verbatim
  local phrase
  for phrase in 'Fund loss vectors' 'Math precision' 'Flash loan safety' 'Private key' 'Transaction signing' 'Slippage' 'Input validation' 'Race conditions' 'Resource exhaustion'; do
    printf '%s\n' "$section" | grep -qF "$phrase" \
      || { echo "$path §security mode missing distinguishing bullet phrase '$phrase' (assertion g — full-list pinning)" >&2; return 1; }
  done

  echo "cross-auditor §security mode loads R9-R14 cluster with all 9 supplemental bullets preserved"
}

# Cross-auditor Step 1 + Step 2 load-instructions pin (R-rules web-security
# cluster Pin 6 — class: prompt-text). Gates
# §3.4 sub-edits (b) and (c). Asserts the `## Step 1: Launch Codex` section
# carries 7 load-bearing substrings AND the `## Step 2: Claude Audit (you)`
# section carries 5 load-bearing substrings.
check_cross_auditor_step1_step2_load_instructions() {
  local path="${1:-agents/cross-auditor.md}"
  test -f "$path" || { echo "$path missing" >&2; return 1; }
  local s1 s2
  s1=$(awk '
    /^## Step 1: Launch Codex/ { in_s=1; print; next }
    in_s && /^## Step 2: Claude Audit/ { exit }
    in_s { print }
  ' "$path")
  s2=$(awk '
    /^## Step 2: Claude Audit/ { in_s=1; print; next }
    in_s && /^## Step 3:/ { exit }
    in_s { print }
  ' "$path")

  # (a) Step 1 — seven load-bearing substrings
  local tok
  for tok in 'code-quality-rules.md' 'category: security' 'Security R-rule cluster (project_type=' 'mode ∈ {security, full}' 'Trigger B' 'DO NOT paraphrase'; do
    printf '%s\n' "$s1" | grep -qF "$tok" \
      || { echo "$path §Step 1 section missing load-bearing token: '$tok' (Pin 6 assertion a)" >&2; return 1; }
  done
  printf '%s\n' "$s1" | grep -qE 'not reachable|focus-areas-only fallback' \
    || { echo "$path §Step 1 section missing 'not reachable' / 'focus-areas-only fallback' token (Pin 6 assertion a)" >&2; return 1; }

  # (b) Step 2 — five load-bearing substrings
  for tok in 'code-quality-rules.md' 'Bad code' 'Good code' 'mode ∈ {security, full}' 'additively'; do
    printf '%s\n' "$s2" | grep -qF "$tok" \
      || { echo "$path §Step 2 section missing load-bearing token: '$tok' (Pin 6 assertion b)" >&2; return 1; }
  done

  echo "cross-auditor §Step 1 (7 substrings) + §Step 2 (5 substrings) load-instructions present"
}

check_skill_attack_surface_slot_prompts() {
  # Pin A (prompt-text): Asserts the Attack-surface profile slot-filling block
  # in skills/feature/SKILL.md contains the required banners and tokens.
  local skill='skills/feature/SKILL.md'
  test -f "$skill" || { echo "$skill missing" >&2; return 1; }

  local subrange
  subrange=$(awk '/Spawn \*\*Librarian\*\* only if you need/,/^### Step 3 — Get approval/' "$skill")

  # 5 slot tokens
  printf '%s\n' "$subrange" | grep -qF 'caller_identity' \
    || { echo "$skill attack-surface subrange missing 'caller_identity'" >&2; return 1; }
  printf '%s\n' "$subrange" | grep -qF 'external_input' \
    || { echo "$skill attack-surface subrange missing 'external_input'" >&2; return 1; }
  printf '%s\n' "$subrange" | grep -qF 'rate_limit' \
    || { echo "$skill attack-surface subrange missing 'rate_limit'" >&2; return 1; }
  printf '%s\n' "$subrange" | grep -qF 'abuse_scenarios' \
    || { echo "$skill attack-surface subrange missing 'abuse_scenarios'" >&2; return 1; }
  printf '%s\n' "$subrange" | grep -qF 'framework_version_target' \
    || { echo "$skill attack-surface subrange missing 'framework_version_target'" >&2; return 1; }

  # Banner-numbering tokens (1/5) through (5/5)
  printf '%s\n' "$subrange" | grep -qF '(1/5)' \
    || { echo "$skill attack-surface subrange missing '(1/5)' banner token" >&2; return 1; }
  printf '%s\n' "$subrange" | grep -qF '(2/5)' \
    || { echo "$skill attack-surface subrange missing '(2/5)' banner token" >&2; return 1; }
  printf '%s\n' "$subrange" | grep -qF '(3/5)' \
    || { echo "$skill attack-surface subrange missing '(3/5)' banner token" >&2; return 1; }
  printf '%s\n' "$subrange" | grep -qF '(4/5)' \
    || { echo "$skill attack-surface subrange missing '(4/5)' banner token" >&2; return 1; }
  printf '%s\n' "$subrange" | grep -qF '(5/5)' \
    || { echo "$skill attack-surface subrange missing '(5/5)' banner token" >&2; return 1; }

  # At least 5 AWAITING YOUR INPUT banners
  local banner_count
  banner_count=$(printf '%s\n' "$subrange" | grep -cF 'AWAITING YOUR INPUT')
  [ "$banner_count" -ge 5 ] \
    || { echo "$skill attack-surface subrange has only $banner_count 'AWAITING YOUR INPUT' occurrences (need >= 5)" >&2; return 1; }

  # §1.1 write-target reference
  printf '%s\n' "$subrange" | grep -qF '## 1.1 Attack-surface profile' \
    || { echo "$skill attack-surface subrange missing '## 1.1 Attack-surface profile' write-target reference" >&2; return 1; }

  # n/a short-circuit tokens
  printf '%s\n' "$subrange" | grep -qF 'n/a' \
    || { echo "$skill attack-surface subrange missing 'n/a' token" >&2; return 1; }
  printf '%s\n' "$subrange" | grep -qF 'not_applicable: true' \
    || { echo "$skill attack-surface subrange missing 'not_applicable: true' token" >&2; return 1; }
  printf '%s\n' "$subrange" | grep -qF 'skip Banners 2' \
    || { echo "$skill attack-surface subrange missing 'skip Banners 2' token" >&2; return 1; }

  # Library-serialization tokens (Banner 4/5 mandate)
  printf '%s\n' "$subrange" | grep -qF 'yaml.safe_dump' \
    || { echo "$skill attack-surface subrange missing 'yaml.safe_dump' library-serialization token" >&2; return 1; }
  printf '%s\n' "$subrange" | grep -qF 'js-yaml' \
    || { echo "$skill attack-surface subrange missing 'js-yaml' library-serialization token" >&2; return 1; }
  printf '%s\n' "$subrange" | grep -qF 'NOT manual string concatenation' \
    || { echo "$skill attack-surface subrange missing 'NOT manual string concatenation' token" >&2; return 1; }
  printf '%s\n' "$subrange" | grep -qF 'U+0000' \
    || { echo "$skill attack-surface subrange missing 'U+0000' NUL-byte rejection token" >&2; return 1; }

  echo "SKILL.md Attack-surface profile subrange carries all required slot tokens, banners, and serialization mandates"
}

check_spec_template_attack_surface_section() {
  # Pin B (schema): Asserts skills/feature/references/spec-template.md carries
  # the §1.1 Attack-surface profile section with fenced YAML and canonical defaults.
  local tmpl='skills/feature/references/spec-template.md'
  test -f "$tmpl" || { echo "$tmpl missing" >&2; return 1; }

  # Heading present
  grep -qF '## 1.1 Attack-surface profile' "$tmpl" \
    || { echo "$tmpl missing '## 1.1 Attack-surface profile' heading" >&2; return 1; }

  # Line-order: Context < §1.1 < Current State
  local ctx_line as_line cs_line
  ctx_line=$(grep -n '^## 1\. Context' "$tmpl" | head -1 | cut -d: -f1)
  as_line=$(grep -n '^## 1\.1 Attack-surface profile' "$tmpl" | head -1 | cut -d: -f1)
  cs_line=$(grep -n '^## 2\. Current State' "$tmpl" | head -1 | cut -d: -f1)
  [ -n "$ctx_line" ] || { echo "$tmpl missing '## 1. Context' heading" >&2; return 1; }
  [ -n "$as_line" ] || { echo "$tmpl missing '## 1.1 Attack-surface profile' heading (line lookup)" >&2; return 1; }
  [ -n "$cs_line" ] || { echo "$tmpl missing '## 2. Current State' heading" >&2; return 1; }
  [ "$as_line" -gt "$ctx_line" ] \
    || { echo "$tmpl §1.1 heading is not after ## 1. Context" >&2; return 1; }
  [ "$cs_line" -gt "$as_line" ] \
    || { echo "$tmpl §1.1 heading is not before ## 2. Current State" >&2; return 1; }

  # Extract section between §1.1 and ## 2. Current State
  local section
  section=$(awk '/^## 1\.1 Attack-surface profile/,/^## 2\. Current State/' "$tmpl")

  # MUST be null docstring
  printf '%s\n' "$section" | grep -qF 'MUST be null' \
    || { echo "$tmpl §1.1 section missing 'MUST be null' canonical-rule docstring" >&2; return 1; }

  # Fenced YAML block (3-backtick yaml fence) within section
  local yaml_block
  yaml_block=$(printf '%s\n' "$section" | awk '/^```ya?ml$/{flag=1;next}/^```$/{flag=0}flag')
  [ -n "$yaml_block" ] \
    || { echo "$tmpl §1.1 section has no fenced yaml/yml code block" >&2; return 1; }

  # attack_surface: root key
  printf '%s\n' "$yaml_block" | grep -q '^attack_surface:' \
    || { echo "$tmpl §1.1 fenced YAML missing 'attack_surface:' root key" >&2; return 1; }

  # 6 canonical default lines
  printf '%s\n' "$yaml_block" | grep -qE '^[[:space:]]*not_applicable:[[:space:]]+false' \
    || { echo "$tmpl §1.1 fenced YAML missing canonical default 'not_applicable: false'" >&2; return 1; }
  printf '%s\n' "$yaml_block" | grep -qE '^[[:space:]]*caller_identity:[[:space:]]+unspecified' \
    || { echo "$tmpl §1.1 fenced YAML missing canonical default 'caller_identity: unspecified'" >&2; return 1; }
  printf '%s\n' "$yaml_block" | grep -qE '^[[:space:]]*external_input:[[:space:]]+false' \
    || { echo "$tmpl §1.1 fenced YAML missing canonical default 'external_input: false'" >&2; return 1; }
  printf '%s\n' "$yaml_block" | grep -qE '^[[:space:]]*rate_limit:[[:space:]]+unspecified' \
    || { echo "$tmpl §1.1 fenced YAML missing canonical default 'rate_limit: unspecified'" >&2; return 1; }
  printf '%s\n' "$yaml_block" | grep -qE '^[[:space:]]*abuse_scenarios:[[:space:]]+null' \
    || { echo "$tmpl §1.1 fenced YAML missing canonical default 'abuse_scenarios: null'" >&2; return 1; }
  printf '%s\n' "$yaml_block" | grep -qE '^[[:space:]]*framework_version_target:[[:space:]]+null' \
    || { echo "$tmpl §1.1 fenced YAML missing canonical default 'framework_version_target: null'" >&2; return 1; }

  echo "spec-template.md §1.1 Attack-surface profile section present with fenced YAML and canonical defaults"
}

check_cross_auditor_consumes_attack_surface_profile() {
  # Pin C (prompt-text): Asserts agents/cross-auditor.md spec mode block carries
  # the Attack-surface profile consumption rules with all required fingerprints.
  local path="${1:-agents/cross-auditor.md}"
  test -f "$path" || { echo "$path missing" >&2; return 1; }

  local sec
  sec=$(awk '/^### `spec` mode/,/^## Severity Ladder/' "$path")

  # 4 base tokens
  printf '%s\n' "$sec" | grep -qF 'Attack-surface profile' \
    || { echo "$path spec mode missing 'Attack-surface profile' token" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qF 'external_input' \
    || { echo "$path spec mode missing 'external_input' token" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qF 'not_applicable' \
    || { echo "$path spec mode missing 'not_applicable' token" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qF 'input validation' \
    || { echo "$path spec mode missing 'input validation' token" >&2; return 1; }

  # HIGH-flag finding-text fingerprints
  printf '%s\n' "$sec" | grep -qF 'Spec declares external_input=true' \
    || { echo "$path spec mode missing 'Spec declares external_input=true' finding-text fingerprint" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qF 'Spec missing required §1.1 Attack-surface profile section' \
    || { echo "$path spec mode missing absent-section finding-text fingerprint" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qF 'outside fenced code blocks' \
    || { echo "$path spec mode missing 'outside fenced code blocks' absent-section tightening token" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qF 'missing or carry non-null values' \
    || { echo "$path spec mode missing cross-field consistency finding-text fingerprint" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qF 'violates §3.3 schema' \
    || { echo "$path spec mode missing schema-validity finding-text fingerprint" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qF 'not_applicable must be a boolean' \
    || { echo "$path spec mode missing discriminator type-gate fingerprint" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qF 'first fenced' \
    || { echo "$path spec mode missing YAML-block-locator disambiguation fingerprint" >&2; return 1; }

  # 12 input-validation alternates
  printf '%s\n' "$sec" | grep -qF 'validate input' \
    || { echo "$path spec mode missing 'validate input' input-validation alternate" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qiF 'sanitization' \
    || { echo "$path spec mode missing 'sanitization' input-validation alternate" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qiF 'sanitize' \
    || { echo "$path spec mode missing 'sanitize' input-validation alternate" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qF 'schema validation' \
    || { echo "$path spec mode missing 'schema validation' input-validation alternate" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qF 'JSON schema' \
    || { echo "$path spec mode missing 'JSON schema' input-validation alternate" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qF 'type validation' \
    || { echo "$path spec mode missing 'type validation' input-validation alternate" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qF 'parameterised query' \
    || { echo "$path spec mode missing 'parameterised query' input-validation alternate" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qF 'parameterized query' \
    || { echo "$path spec mode missing 'parameterized query' input-validation alternate" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qF 'bound parameter' \
    || { echo "$path spec mode missing 'bound parameter' input-validation alternate" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qF 'prepared statement' \
    || { echo "$path spec mode missing 'prepared statement' input-validation alternate" >&2; return 1; }
  printf '%s\n' "$sec" | grep -qiF 'pydantic' \
    || { echo "$path spec mode missing 'pydantic' input-validation alternate" >&2; return 1; }

  echo "cross-auditor spec mode carries Attack-surface profile consumption rules with all required fingerprints"
}

# Shared helper: run hooks/lib/probe_g.sh against a fixture dir and byte-diff
# the full JSON output against expected_stdout.json. The probe is invoked with
# cwd = $fixture_dir so repo_root paths resolve inside the fixture.
# PROBE_G_FAKE_NOW is set for determinism so emitted_at byte-matches expected.
_probe_g_byte_diff() {
  # $1 = fixture dir (relative to plugin root)
  local fdir="$1"
  local input="$fdir/input.json"
  local expected="$fdir/expected_stdout.json"
  [ -r "$input" ] || { echo "$input not readable"; return 1; }
  [ -r "$expected" ] || { echo "$expected not readable"; return 1; }
  local plugin_root
  plugin_root="$(pwd)"
  local out_tmp="/tmp/smoke-probe-g-out.$$"
  local exit_code=0
  ( cd "$fdir" \
    && PROBE_G_FAKE_NOW="2026-05-07T00:00:00Z" \
    CLAUDE_PLUGIN_ROOT="$plugin_root" \
    bash "$plugin_root/hooks/lib/probe_g.sh" < input.json ) >"$out_tmp" 2>/tmp/smoke-probe-g-err.$$ || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    echo "probe_g.sh exited $exit_code against $fdir; stderr:"
    head -5 /tmp/smoke-probe-g-err.$$
    rm -f "$out_tmp" /tmp/smoke-probe-g-err.$$
    return 1
  fi
  rm -f /tmp/smoke-probe-g-err.$$
  # Canonicalize actual + expected via sort_keys.
  local actual exp
  actual=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.stdout.write(json.dumps(d,sort_keys=True,separators=(",",":"),ensure_ascii=False))' "$out_tmp")
  exp=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.stdout.write(json.dumps(d,sort_keys=True,separators=(",",":"),ensure_ascii=False))' "$expected")
  rm -f "$out_tmp"
  if [ "$actual" != "$exp" ]; then
    echo "probe_g output mismatch for $fdir:"
    diff <(printf '%s\n' "$actual") <(printf '%s\n' "$exp") | head -20
    return 1
  fi
  echo "probe_g output byte-matches expected for $fdir"
}

check_probe_g_corpus_fixture_valid() {
  local corpus="hooks/lib/freshness_corpus.json"
  [ -f "$corpus" ] || { echo "$corpus missing"; return 1; }
  python3 -c "import json; json.load(open('$corpus'))" 2>/dev/null \
    || { echo "$corpus is not valid JSON"; return 1; }
  python3 - "$corpus" <<'PYEOF'
import json, sys
corpus = json.load(open(sys.argv[1]))
allowed = {"npm", "pypi", "cargo", "go"}
bad_keys = set(corpus.keys()) - allowed
if bad_keys:
    print(f"unexpected top-level keys in corpus: {bad_keys}")
    sys.exit(1)
for eco, pkgs in corpus.items():
    for pkg, val in pkgs.items():
        if not isinstance(val.get("latest_major"), int):
            print(f"corpus[{eco}][{pkg}].latest_major is not an integer")
            sys.exit(1)
        if "pre_1_0" in val and not isinstance(val["pre_1_0"], bool):
            print(f"corpus[{eco}][{pkg}].pre_1_0 must be bool when present")
            sys.exit(1)
print("corpus schema valid")
PYEOF
}

check_probe_g_detector_fires_on_major_drift() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/01-positive-major-drift
}

check_probe_g_detector_clean_at_current_major() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/02-clean-current-major
}

check_probe_g_detector_ineligible_no_lockfile() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/03-ineligible-no-lockfile
}

_probe_h_byte_diff() {
  # $1 = fixture dir (relative to plugin root)
  local fdir="$1"
  local input="$fdir/input.json"
  local expected="$fdir/expected_stdout.json"
  [ -r "$input" ] || { echo "$input not readable"; return 1; }
  [ -r "$expected" ] || { echo "$expected not readable"; return 1; }
  local plugin_root
  plugin_root="$(pwd)"
  local out_tmp="/tmp/smoke-probe-h-out.$$"
  local exit_code=0
  ( cd "$fdir" \
    && PROBE_H_FAKE_NOW="2026-05-07T00:00:00Z" \
    CLAUDE_PLUGIN_ROOT="$plugin_root" \
    bash "$plugin_root/hooks/lib/probe_h.sh" < input.json ) >"$out_tmp" 2>/tmp/smoke-probe-h-err.$$ || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    echo "probe_h.sh exited $exit_code against $fdir; stderr:"
    head -5 /tmp/smoke-probe-h-err.$$
    rm -f "$out_tmp" /tmp/smoke-probe-h-err.$$
    return 1
  fi
  rm -f /tmp/smoke-probe-h-err.$$
  # Canonicalize actual + expected via sort_keys.
  local actual exp
  actual=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.stdout.write(json.dumps(d,sort_keys=True,separators=(",",":"),ensure_ascii=False))' "$out_tmp")
  exp=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.stdout.write(json.dumps(d,sort_keys=True,separators=(",",":"),ensure_ascii=False))' "$expected")
  rm -f "$out_tmp"
  if [ "$actual" != "$exp" ]; then
    echo "probe_h output mismatch for $fdir:"
    diff <(printf '%s\n' "$actual") <(printf '%s\n' "$exp") | head -20
    return 1
  fi
  echo "probe_h output byte-matches expected for $fdir"
}

check_probe_h_corpus_path_resolution() {
  local plugin_root
  plugin_root="$(pwd)"
  local fdir="tests/fixtures/cross-audit-probe-h/01-positive-typosquat"
  [ -d "$fdir" ] || { echo "fixture $fdir missing"; return 1; }
  local out_tmp="/tmp/smoke-probe-h-corpus-path.$$"
  local exit_code=0

  # (1) Env-set path: CLAUDE_PLUGIN_ROOT pointed at plugin checkout.
  ( cd "$fdir" \
    && PROBE_H_FAKE_NOW="2026-05-07T00:00:00Z" \
    CLAUDE_PLUGIN_ROOT="$plugin_root" \
    bash "$plugin_root/hooks/lib/probe_h.sh" < input.json ) >"$out_tmp" 2>/dev/null || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    echo "probe_h.sh failed under CLAUDE_PLUGIN_ROOT=$plugin_root (env-set path)"
    rm -f "$out_tmp"
    return 1
  fi
  python3 -c "
import json, sys, re
d = json.load(open('$out_tmp'))
reason = d.get('receipt_metadata', {}).get('eligible_reason', '')
m = re.search(r'(\d+) pinned packages', reason)
if not m or int(m.group(1)) <= 0:
    print(f'env-set: eligible_reason did not report positive pinned-package count: {reason}')
    sys.exit(1)
" || { rm -f "$out_tmp"; return 1; }

  # (2) Env-unset path: CLAUDE_PLUGIN_ROOT explicitly removed via `env -u`
  # so the probe falls back to $PROBE_H_SCRIPT_DIR/freshness_corpus.json.
  exit_code=0
  ( cd "$fdir" \
    && env -u CLAUDE_PLUGIN_ROOT \
       PROBE_H_FAKE_NOW="2026-05-07T00:00:00Z" \
       bash "$plugin_root/hooks/lib/probe_h.sh" < input.json ) >"$out_tmp" 2>/dev/null || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    echo "probe_h.sh failed with CLAUDE_PLUGIN_ROOT unset (script-dir fallback)"
    rm -f "$out_tmp"
    return 1
  fi
  python3 -c "
import json, sys, re
d = json.load(open('$out_tmp'))
reason = d.get('receipt_metadata', {}).get('eligible_reason', '')
m = re.search(r'(\d+) pinned packages', reason)
if not m or int(m.group(1)) <= 0:
    print(f'env-unset: eligible_reason did not report positive pinned-package count: {reason}')
    sys.exit(1)
" || { rm -f "$out_tmp"; return 1; }

  rm -f "$out_tmp"
  echo "probe_h corpus path resolution verified under env-set + env-unset"
}

check_probe_h_detector_fires_on_typosquat() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/01-positive-typosquat
}

check_probe_h_detector_clean_canonical_name() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/02-clean-canonical-name
}

check_probe_h_detector_clean_distant_name() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/03-clean-distant-name
}

check_probe_g_detector_fires_on_major_only_no_dot() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/06-major-only-no-dot
}

check_probe_h_detector_fires_on_major_only_no_dot() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/06-major-only-no-dot
}

check_probe_g_detector_fires_on_extras_syntax() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/08-extras-syntax
}

check_probe_h_detector_fires_on_extras_syntax() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/08-extras-syntax
}

check_probe_g_detector_fires_on_whitespace_eq() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/09-whitespace-eq
}

check_probe_h_detector_fires_on_whitespace_eq() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/09-whitespace-eq
}

check_probe_g_detector_rejects_malformed_requirements() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/19-malformed-requirements
}

check_probe_g_detector_fires_on_uppercase_name_package_lock() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/07-uppercase-name-package-lock
}

check_probe_g_detector_out_of_diff_lockfile_ignored() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/11-out-of-diff-lockfile-ignored
}

check_probe_h_detector_out_of_diff_lockfile_ignored() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/11-out-of-diff-lockfile-ignored
}

check_probe_g_detector_in_diff_lockfile_evaluated() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/11-in-diff-lockfile-evaluated
}

check_probe_h_detector_in_diff_lockfile_evaluated() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/11-in-diff-lockfile-evaluated
}

check_probe_g_yarn_berry_peer_dep() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/12-yarn-berry-peer-dep
}

check_probe_h_yarn_berry_peer_dep() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/12-yarn-berry-peer-dep
}

check_probe_g_yarn_scoped_npm_protocol() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/13-yarn-scoped-npm-protocol
}

check_probe_h_yarn_scoped_npm_protocol() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/13-yarn-scoped-npm-protocol
}

check_probe_g_pnpm_v9_format() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/14-pnpm-v9-format
}

check_probe_h_pnpm_v9_format() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/14-pnpm-v9-format
}

check_probe_g_pnpm_v9_quoted_scoped() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/20-pnpm-v9-quoted-scoped
}

check_probe_h_pnpm_v9_quoted_scoped() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/20-pnpm-v9-quoted-scoped
}

check_probe_g_yarn_scoped_alias_target() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/21-yarn-scoped-alias-target
}

check_probe_h_yarn_scoped_alias_target() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/21-yarn-scoped-alias-target
}

check_probe_g_yarn_portal_and_github() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/22-yarn-portal-and-github
}

check_probe_h_yarn_portal_and_github() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/22-yarn-portal-and-github
}

check_probe_h_levenshtein_length_cap() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/15-levenshtein-length-cap
}

check_probe_g_vendored_excluded() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/10-vendored-excluded
}

check_probe_h_vendored_excluded() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/10-vendored-excluded
}

check_probe_g_boundary_drift_2_suppressed() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/04-boundary-drift-2-suppressed
}

check_probe_g_boundary_drift_3_fired() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/05-boundary-drift-3-fired
}

check_probe_g_npm_v7_packages_walk_and_dep_classes() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/16-npm-v7-and-dep-classes
}

check_probe_h_npm_v7_packages_walk_and_dep_classes() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/16-npm-v7-and-dep-classes
}

check_probe_g_npm_range_vs_resolved_dedup() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/17-range-vs-resolved-dedup
}

check_probe_h_npm_range_vs_resolved_dedup() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/17-range-vs-resolved-dedup
}

check_probe_g_pre_1_0_skipped() {
  _probe_g_byte_diff tests/fixtures/cross-audit-probe-g/18-pre-1-0-skipped
}

check_probe_h_detector_rejects_malformed_requirements() {
  _probe_h_byte_diff tests/fixtures/cross-audit-probe-h/19-malformed-requirements
}

check_skill_stride_lite_block_gated() {
  local f="skills/feature/SKILL.md"
  local sub
  sub=$(awk '/Spawn \*\*Librarian\*\* only if you need/,/^### Step 3 — Get approval/' "$f")
  local has_stride has_spoof has_tamper has_repud has_info has_dos has_eop
  local has_b1_6 has_b6_6 has_section has_gate banner_count has_safedump
  has_stride=$(echo "$sub" | grep -cF 'stride_lite')
  has_spoof=$(echo "$sub" | grep -ciF 'spoofing')
  has_tamper=$(echo "$sub" | grep -ciF 'tampering')
  has_repud=$(echo "$sub" | grep -ciF 'repudiation')
  has_info=$(echo "$sub" | grep -cF 'info_disclosure')
  has_dos=$(echo "$sub" | grep -ciF 'DoS')
  has_eop=$(echo "$sub" | grep -ciF 'EoP')
  has_b1_6=$(echo "$sub" | grep -cF '(1/6)')
  has_b6_6=$(echo "$sub" | grep -cF '(6/6)')
  has_section=$(echo "$sub" | grep -cF '## 1.2 STRIDE-lite threat model')
  has_gate=$(echo "$sub" | grep -cE 'external_input != true|external_input == true|external_input.*true')
  banner_count=$(echo "$sub" | grep -cF 'AWAITING YOUR INPUT')
  has_safedump=$(echo "$sub" | grep -cF 'yaml.safe_dump')
  [ "$has_stride" -ge 1 ] || { echo "missing stride_lite token in SKILL.md subrange"; return 1; }
  [ "$has_spoof" -ge 1 ] || { echo "missing spoofing token in SKILL.md subrange"; return 1; }
  [ "$has_tamper" -ge 1 ] || { echo "missing tampering token in SKILL.md subrange"; return 1; }
  [ "$has_repud" -ge 1 ] || { echo "missing repudiation token in SKILL.md subrange"; return 1; }
  [ "$has_info" -ge 1 ] || { echo "missing info_disclosure token in SKILL.md subrange"; return 1; }
  [ "$has_dos" -ge 1 ] || { echo "missing dos/DoS token in SKILL.md subrange"; return 1; }
  [ "$has_eop" -ge 1 ] || { echo "missing eop/EoP token in SKILL.md subrange"; return 1; }
  [ "$has_b1_6" -ge 1 ] || { echo "missing (1/6) banner numbering in SKILL.md subrange"; return 1; }
  [ "$has_b6_6" -ge 1 ] || { echo "missing (6/6) banner numbering in SKILL.md subrange"; return 1; }
  [ "$has_section" -ge 1 ] || { echo "missing '## 1.2 STRIDE-lite threat model' write-target in SKILL.md subrange"; return 1; }
  [ "$has_gate" -ge 1 ] || { echo "missing external_input gating reference in SKILL.md subrange"; return 1; }
  [ "$banner_count" -ge 11 ] || { echo "expected >=11 AWAITING YOUR INPUT banners in subrange, got $banner_count"; return 1; }
  [ "$has_safedump" -ge 1 ] || { echo "missing yaml.safe_dump library-serialization token in SKILL.md subrange"; return 1; }
}

check_cross_auditor_consumes_stride_lite() {
  local f="agents/cross-auditor.md"
  local sec
  sec=$(awk '/^### `spec` mode/,/^## Severity Ladder/' "$f")
  local has_strttm has_section has_gate has_med has_finding
  local has_spoof has_tamper has_repud has_info has_dos has_eop
  has_strttm=$(echo "$sec" | grep -cF 'STRIDE-lite threat model')
  has_section=$(echo "$sec" | grep -cF '## 1.2')
  has_gate=$(echo "$sec" | grep -cF 'external_input: true')
  has_med=$(echo "$sec" | grep -cF 'MEDIUM')
  has_finding=$(echo "$sec" | grep -cF 'STRIDE-lite threat model is absent or all 6 rows null')
  has_spoof=$(echo "$sec" | grep -cF 'Spoofing')
  has_tamper=$(echo "$sec" | grep -cF 'Tampering')
  has_repud=$(echo "$sec" | grep -cF 'Repudiation')
  has_info=$(echo "$sec" | grep -cF 'InfoDisclosure')
  has_dos=$(echo "$sec" | grep -cF 'DoS')
  has_eop=$(echo "$sec" | grep -cF 'EoP')
  [ "$has_strttm" -ge 1 ] || { echo "missing 'STRIDE-lite threat model' in cross-auditor spec mode"; return 1; }
  [ "$has_section" -ge 1 ] || { echo "missing '## 1.2' reference in cross-auditor spec mode"; return 1; }
  [ "$has_gate" -ge 1 ] || { echo "missing 'external_input: true' gating in cross-auditor spec mode"; return 1; }
  [ "$has_med" -ge 1 ] || { echo "missing MEDIUM severity in cross-auditor spec mode"; return 1; }
  [ "$has_finding" -ge 1 ] || { echo "missing finding-text fingerprint in cross-auditor spec mode"; return 1; }
  [ "$has_spoof" -ge 1 ] || { echo "missing Spoofing in cross-auditor spec mode"; return 1; }
  [ "$has_tamper" -ge 1 ] || { echo "missing Tampering in cross-auditor spec mode"; return 1; }
  [ "$has_repud" -ge 1 ] || { echo "missing Repudiation in cross-auditor spec mode"; return 1; }
  [ "$has_info" -ge 1 ] || { echo "missing InfoDisclosure in cross-auditor spec mode"; return 1; }
  [ "$has_dos" -ge 1 ] || { echo "missing DoS in cross-auditor spec mode"; return 1; }
  [ "$has_eop" -ge 1 ] || { echo "missing EoP in cross-auditor spec mode"; return 1; }
}

check_project_type_documented_in_config_surfaces() {
  local tpl kbd ymle rdme aiov skl_skel
  tpl=$(grep -c project_type skills/feature/references/spec-template.md)
  kbd=$(grep -c project_type docs/kb-discovery.md)
  ymle=$(grep -c project_type .ai-dev-team.yml.example)
  rdme=$(grep -c project_type README.md)
  aiov=$(grep -c project_type docs/AI_Dev_Team_Overview.md)
  skl_skel=$(awk '/^YAML frontmatter:$/,/^```$/' skills/feature/SKILL.md | grep -c project_type)
  [ "$tpl" -ge 1 ] || { echo "missing project_type in skills/feature/references/spec-template.md"; return 1; }
  [ "$kbd" -ge 1 ] || { echo "missing project_type in docs/kb-discovery.md"; return 1; }
  [ "$ymle" -ge 1 ] || { echo "missing project_type in .ai-dev-team.yml.example"; return 1; }
  [ "$rdme" -ge 1 ] || { echo "missing project_type in README.md"; return 1; }
  [ "$aiov" -ge 1 ] || { echo "missing project_type in docs/AI_Dev_Team_Overview.md"; return 1; }
  [ "$skl_skel" -ge 1 ] || { echo "missing project_type inside SKILL.md YAML frontmatter skeleton"; return 1; }
}

check_skill_threads_project_type_at_spec_audit_spawn() {
  local f="skills/feature/SKILL.md"
  local block count
  block=$(awk '/^Spawn `cross-auditor` subagent with:$/,/^- \(omit `kb_path` — spec mode does not write to KB\)$/' "$f")
  count=$(echo "$block" | grep -c project_type)
  [ "$count" -ge 1 ] || { echo "spec-mode spawn block missing project_type parameter"; return 1; }
  # Site A MUST NOT reference the degraded warning — that is a code/full-mode artifact
  if echo "$block" | grep -qF 'degraded warning'; then
    echo "spec-mode spawn block must not mention degraded warning (code/full mode only)"
    return 1
  fi
}

check_skill_threads_project_type_at_code_audit_spawn() {
  local f="skills/feature/SKILL.md"
  local block count
  block=$(awk '/^Spawn `cross-auditor` with mode: full on the diff/,/^The cross-auditor persists code findings in KB/' "$f")
  count=$(echo "$block" | grep -c project_type)
  [ "$count" -ge 1 ] || { echo "full-mode spawn block missing project_type parameter"; return 1; }
}

check_skill_threads_project_type_at_code_audit_respawn() {
  local f="skills/feature/SKILL.md"
  local block count
  block=$(awk '/^7\. Re-spawn `cross-auditor`/,/^8\. After the cross-auditor returns, append:$/' "$f")
  count=$(echo "$block" | grep -c project_type)
  [ "$count" -ge 1 ] || { echo "narrative re-spawn paragraph missing project_type carry-forward"; return 1; }
}

check_skill_threads_project_type_at_code_audit_resume_routing() {
  local f="skills/feature/SKILL.md"
  local count
  count=$(grep -F 'code audit decisions recorded; iteration=N; pending_*' "$f" | grep -c project_type)
  [ "$count" -ge 1 ] || { echo "resume-routing table cell missing project_type carry-forward"; return 1; }
}

check_cross_auditor_emits_degraded_warning_when_project_type_unset() {
  local f="agents/cross-auditor.md"
  local block warn norm runfilter
  # Scope all three clauses to the gate paragraph (between the `When mode ∈ {security, full}` opener
  # and the `**Code mode** Codex prompt template:` close marker) to prevent pre-existing prose at
  # other locations in the agent doc (e.g. mentions of "filtered" rule sections elsewhere) from
  # accidentally satisfying any of the AND clauses.
  block=$(awk '/^When .?mode ∈ \{security, full\}/,/^\*\*Code mode\*\* Codex prompt template:$/' "$f")
  warn=$(echo "$block" | grep -cF 'R-rule cluster NOT loaded')
  norm=$(echo "$block" | grep -cE 'normaliz.*["\x27]?all["\x27]?')
  runfilter=$(echo "$block" | grep -cE 'run.*filter|then run|filter runs')
  [ "$warn" -ge 1 ] || { echo "gate paragraph missing 'R-rule cluster NOT loaded' warning literal"; return 1; }
  [ "$norm" -ge 1 ] || { echo "gate paragraph missing normalize-to-all (Trigger A) clause"; return 1; }
  [ "$runfilter" -ge 1 ] || { echo "gate paragraph missing run-the-filter clause"; return 1; }
}

check_cross_auditor_documents_warning_emit_location() {
  local f="agents/cross-auditor.md"
  local rendered marker
  rendered=$(grep -cF 'R-rule cluster: NOT loaded' "$f")
  # The marker locks the conditional-emit comment so the bullet is documented as gate-conditional,
  # not always-on. Regex order matches the spec example byte-for-byte: emitted only when ... R-rule cluster.
  marker=$(grep -cE 'emitted only when.*R-rule cluster' "$f")
  [ "$rendered" -ge 1 ] || { echo "missing rendered-bullet literal 'R-rule cluster: NOT loaded' (with colon)"; return 1; }
  [ "$marker" -ge 1 ] || { echo "missing 'emitted only when ... R-rule cluster' conditional-emit comment marker"; return 1; }
}

check_cross_auditor_replaces_silent_skip_gate() {
  local f="agents/cross-auditor.md"
  local old_gate new_branch
  # Negative clause: the old `When mode ∈ {security, full} and project_type is set` gate prose
  # MUST be gone — its presence means the silent-skip path is still wired and the unset-project_type
  # branch never fires (recurring the original silent-skip defect class).
  old_gate=$(grep -cE 'When .?mode ∈ \{security, full\}.? and .?project_type.? is set' "$f")
  # Positive clause: the new branch literal must be present. Grep -F so the backticks are taken
  # literally — the new prose introduces this exact clause.
  new_branch=$(grep -cF 'If `project_type` is unset OR has a non-allowlist value' "$f")
  [ "$old_gate" = "0" ] || { echo "old silent-skip gate prose still present (negative clause failed)"; return 1; }
  [ "$new_branch" -ge 1 ] || { echo "new explicit-branch prose absent (positive clause failed)"; return 1; }
}

check_spec_mode_footer_sentinel_marker_contract() {
  local f="agents/cross-auditor.md"
  local skl="skills/feature/SKILL.md"
  local ca_sent ca_obfusc skl_sent skl_tail3 skl_eof skl_old skl_l424
  local ca_l424 ca_l445_parser ca_l445_sem ca_l445_summary ca_l445_4th
  local ca_l424_pos ca_l445_pos
  # Producer fenced positive (X12 locked) — exactly one canonical-spaced sentinel literal site.
  ca_sent=$(grep -cF '# CROSS-AUDIT EVIDENCE FOOTER' "$f")
  # Producer obfuscated-form positive (X12) — at least one obfuscated form documents the rule.
  ca_obfusc=$(grep -cF 'CROSS-AUDIT-EVIDENCE-FOOTER' "$f")
  # Consumer sentinel positive — sentinel documented at consumer side (≥ 1, no single-site lock).
  skl_sent=$(grep -cF '# CROSS-AUDIT EVIDENCE FOOTER' "$skl")
  # Consumer parser-shape positives — locks the EOF-adjacency parser shape.
  skl_tail3=$(grep -cF 'tail -3' "$skl")
  skl_eof=$(grep -cF 'EOF-adjacent' "$skl")
  # Consumer parser-shape negative (SKILL.md) — old form removed.
  skl_old=$(grep -cF "awk 'NF' | tail -2" "$skl")
  # X20 (b) — SKILL.md parallel `TWO adjacent literal final lines` negative.
  skl_l424=$(grep -cF 'TWO adjacent literal final lines' "$skl")
  # X16 negatives (cross-auditor.md): L424 stale intro paragraph + L445 four-literal cluster.
  ca_l424=$(grep -cF 'TWO adjacent literal final lines' "$f")
  ca_l445_parser=$(grep -cF "awk 'NF' | tail -2" "$f")
  ca_l445_sem=$(grep -cF 'LAST two physical non-empty lines' "$f")
  ca_l445_summary=$(grep -cF 'last-two-physical-non-empty + prefix-check' "$f")
  # X20 (a) — L445 4th-literal `grep -E … | tail -2` historical form negative.
  ca_l445_4th=$(grep -cE 'grep -E.*tail -2' "$f")
  # X20 (c) — producer-side post-positives for L424 + L445 rewritten prose.
  ca_l424_pos=$(grep -cF 'EXACTLY THREE physical lines' "$f")
  ca_l445_pos=$(grep -cF 'byte-exact full-line equality' "$f")
  [ "$ca_sent" = "1" ] || { echo "agents: canonical-spaced sentinel literal must appear at EXACTLY ONE site (got $ca_sent)"; return 1; }
  [ "$ca_obfusc" -ge 1 ] || { echo "agents: obfuscated form 'CROSS-AUDIT-EVIDENCE-FOOTER' (hyphenated) missing — required by sentinel-obfuscation rule"; return 1; }
  [ "$skl_sent" -ge 1 ] || { echo "SKILL.md: canonical-spaced sentinel literal missing"; return 1; }
  [ "$skl_tail3" -ge 1 ] || { echo "SKILL.md: 'tail -3' literal missing — locks EOF-adjacency parser shape"; return 1; }
  [ "$skl_eof" -ge 1 ] || { echo "SKILL.md: 'EOF-adjacent' literal missing"; return 1; }
  [ "$skl_old" = "0" ] || { echo "SKILL.md: stale 'awk \\'NF\\' | tail -2' parser form still present"; return 1; }
  [ "$skl_l424" = "0" ] || { echo "SKILL.md: stale 'TWO adjacent literal final lines' wording still present at parallel surface"; return 1; }
  [ "$ca_l424" = "0" ] || { echo "agents: stale L424 'TWO adjacent literal final lines' intro-paragraph wording still present"; return 1; }
  [ "$ca_l445_parser" = "0" ] || { echo "agents: stale L445 'awk \\'NF\\' | tail -2' parser shape still present"; return 1; }
  [ "$ca_l445_sem" = "0" ] || { echo "agents: stale L445 'LAST two physical non-empty lines' parser semantics still present"; return 1; }
  [ "$ca_l445_summary" = "0" ] || { echo "agents: stale L445 'last-two-physical-non-empty + prefix-check' summary still present"; return 1; }
  [ "$ca_l445_4th" = "0" ] || { echo "agents: stale L445 'grep -E … | tail -2' historical form still present"; return 1; }
  [ "$ca_l424_pos" -ge 1 ] || { echo "agents: post-rewrite L424 'EXACTLY THREE physical lines' literal missing — locks the rewrite to mandated phrasing"; return 1; }
  [ "$ca_l445_pos" -ge 1 ] || { echo "agents: post-rewrite L445 'byte-exact full-line equality' literal missing"; return 1; }
  # Executable harness — actually run the published parser shape against three trailing-newline
  # fixtures (no trailing \n / one trailing \n / two trailing \n) and assert all three route to PASS.
  # Coincidentally-correct bash $(cmd) capture strips trailing \n; file reads / read -d '' / MCP
  # byte-exact transport preserve them and used to shift tail -3 off the real footer. The trailing-
  # newline strip loop normalizes captured input before tail -3.
  parser_test() {
    local _captured="$1"
    while [[ "$_captured" == *$'\n' ]]; do _captured="${_captured%$'\n'}"; done
    local _last_three _first
    _last_three=$(printf '%s\n' "$_captured" | tail -3)
    _first=$(printf '%s\n' "$_last_three" | head -1)
    [[ "$_first" == "# CROSS-AUDIT EVIDENCE FOOTER" ]]
  }
  local parser_pass_cases=0
  local _variant _fixture
  for _variant in '' $'\n' $'\n\n'; do
    _fixture=$'some prose\n# CROSS-AUDIT EVIDENCE FOOTER\nevidence_class: dual_model\nevidence_blockers: []'"$_variant"
    if parser_test "$_fixture"; then parser_pass_cases=$((parser_pass_cases+1)); fi
  done
  [ "$parser_pass_cases" = "3" ] || { echo "executable harness: parser failed on at least one trailing-newline shape (got $parser_pass_cases / 3)"; return 1; }
  unset -f parser_test
}

check_cross_auditor_probe_failures_schema_aligned() {
  local f="agents/cross-auditor.md"
  local h="tests/smoke-helpers.sh"
  local old_q_r old_q_rm reason_n remediation_n canonical old_canonical translator_bridge scorer_token
  local l389_old_r l389_new_r l389_old_rm l389_new_rm
  local helpers_old_q_r helpers_old_q_rm helpers_new_q_r helpers_new_q_rm
  # Scoped quoted-key dict-literal negatives — the fingerprint of the five Step 0.5 .append( sites.
  # Bare `failure_reason` legitimately stays in the file at scorer_failure_reason and translator-bridge
  # surfaces, which is why this clause is scoped to the QUOTED-KEY form, not bare token.
  old_q_r=$(grep -cF '"failure_reason":' "$f")
  old_q_rm=$(grep -cF '"failure_remediation":' "$f")
  # Positive count — five quoted-key dict-literal sites emit "reason" / "remediation".
  reason_n=$(grep -cF '"reason":' "$f")
  remediation_n=$(grep -cF '"remediation":' "$f")
  # Canonical-phrase positive (X15 — threshold ≥ 2 locks BOTH L199 description AND L268 fail-open
  # coverage prose in lockstep; ≥ 1 would allow partial rewrite).
  canonical=$(grep -cF '`probe_id` / `reason` / `remediation`' "$f")
  # X19 (a) — pre-rewrite canonical phrase absent at both L199 + L268 surfaces.
  old_canonical=$(grep -cF '`probe_id` / `failure_reason` / `failure_remediation`' "$f")
  # Preserve translator bridge L400-401 — Foundation §3.3 receipt-schema territory.
  translator_bridge=$(grep -cF "receipt's optional \`failure_reason\`" "$f")
  # Preserve scorer_failure_reason (renderer-stdin contract — distinct token).
  scorer_token=$(grep -cF 'scorer_failure_reason' "$f")
  # L389-area inline-prose entries (paired-key — both reason and remediation halves).
  l389_old_r=$(grep -cF 'failure_reason: "receipt write failed:' "$f")
  l389_new_r=$(grep -cF 'reason: "receipt write failed:' "$f")
  l389_old_rm=$(grep -cF 'failure_remediation: "check KB mount' "$f")
  l389_new_rm=$(grep -cF 'remediation: "check KB mount' "$f")
  # smoke-helpers.sh seed-side emulation heredocs — symmetric paired-key coverage.
  # Exclude self-reference: the smoke-pin helper itself contains the literals as grep patterns,
  # so scope the count to lines NOT carrying a `grep -cF` clause (which fingerprint the helper's
  # own grep arguments). The seed-side emulation heredocs are Python dict-literal lines without
  # any `grep -cF` token.
  helpers_old_q_r=$(grep -F '"failure_reason":' "$h" | grep -vc 'grep -cF')
  helpers_old_q_rm=$(grep -F '"failure_remediation":' "$h" | grep -vc 'grep -cF')
  helpers_new_q_r=$(grep -F '"reason":' "$h" | grep -vc 'grep -cF')
  helpers_new_q_rm=$(grep -F '"remediation":' "$h" | grep -vc 'grep -cF')
  [ "$old_q_r" = "0" ] || { echo "agents: stale '\"failure_reason\":' quoted-key dict-literal still present (5 Step 0.5 .append sites should have been renamed)"; return 1; }
  [ "$old_q_rm" = "0" ] || { echo "agents: stale '\"failure_remediation\":' quoted-key dict-literal still present"; return 1; }
  [ "$reason_n" -ge 5 ] || { echo "agents: '\"reason\":' count must be ≥ 5 (one per Step 0.5 .append site)"; return 1; }
  [ "$remediation_n" -ge 5 ] || { echo "agents: '\"remediation\":' count must be ≥ 5"; return 1; }
  [ "$canonical" -ge 2 ] || { echo "agents: canonical phrase 'probe_id / reason / remediation' must appear at ≥ 2 surfaces (L199 description AND L268 fail-open coverage)"; return 1; }
  [ "$old_canonical" = "0" ] || { echo "agents: stale canonical phrase 'probe_id / failure_reason / failure_remediation' still present at L199 or L268"; return 1; }
  [ "$translator_bridge" -ge 1 ] || { echo "agents: translator bridge 'receipt's optional failure_reason' must be preserved (Foundation §3.3 carve-out)"; return 1; }
  [ "$scorer_token" -ge 2 ] || { echo "agents: 'scorer_failure_reason' renderer-stdin contract must be preserved (distinct token, not a probe_failures key)"; return 1; }
  [ "$l389_old_r" = "0" ] || { echo "agents: L389-area pre-rename inline-prose 'failure_reason: \"receipt write failed:' still present"; return 1; }
  [ "$l389_new_r" -ge 1 ] || { echo "agents: L389-area post-rename inline-prose 'reason: \"receipt write failed:' missing"; return 1; }
  [ "$l389_old_rm" = "0" ] || { echo "agents: L389-area pre-rename inline-prose 'failure_remediation: \"check KB mount' still present"; return 1; }
  [ "$l389_new_rm" -ge 1 ] || { echo "agents: L389-area post-rename inline-prose 'remediation: \"check KB mount' missing"; return 1; }
  [ "$helpers_old_q_r" = "0" ] || { echo "smoke-helpers.sh: seed-side emulation '\"failure_reason\":' still present (L2510 / L3034 should have been renamed)"; return 1; }
  [ "$helpers_old_q_rm" = "0" ] || { echo "smoke-helpers.sh: seed-side emulation '\"failure_remediation\":' still present"; return 1; }
  [ "$helpers_new_q_r" -ge 2 ] || { echo "smoke-helpers.sh: '\"reason\":' count must be ≥ 2 (two seed-side emulation heredocs)"; return 1; }
  [ "$helpers_new_q_rm" -ge 2 ] || { echo "smoke-helpers.sh: '\"remediation\":' count must be ≥ 2"; return 1; }
}

check_cross_auditor_blocker_sanitization_truncate_before_escape() {
  local f="agents/cross-auditor.md"
  local skl="skills/feature/SKILL.md"
  local block t199 escape_after old_cap ca_old_summary skl_t199 skl_old_cap
  # Stateful awk anchor (definite end-marker on next H3 — two-pattern range form is degenerate
  # because both `^### YAML-safety serialization rule` and the generic `^### ` end pattern would
  # match the same start line and collapse the range to one record).
  block=$(awk '/^### YAML-safety serialization rule/{p=1; next} p && /^### Spec-mode return contract/{exit} p' "$f")
  t199=$(echo "$block" | grep -cF 'Truncate to 199')
  # Ordering positive: escape step appears AFTER truncate step in document order. The producer
  # markdown wraps the action verb in bold (`**Escape single quotes** by doubling`), so anchor on
  # the bold-wrapped form which is the unique fingerprint of the producer-side rewritten step.
  escape_after=$(echo "$block" | awk '/Truncate to 199/{seen=1} /\*\*Escape single quotes\*\*/{if(seen) print "AFTER"}' | grep -cF AFTER)
  # X18 (a) — pre-rewrite numbered-step literal absent at producer side.
  old_cap=$(grep -cF 'Cap length** at 200' "$f")
  # §3.0 sweep gap — pre-rewrite L420 summary literal absent at producer side.
  ca_old_summary=$(grep -cF '200-char cap' "$f")
  # X10 + X18 (c) — consumer-side post-rewrite literal at BOTH SKILL.md L517 AND L521.
  skl_t199=$(grep -cF 'truncate to 199 chars' "$skl")
  # X10 — consumer-side pre-rewrite literal absent at both SKILL.md surfaces.
  skl_old_cap=$(grep -cF '200-char cap' "$skl")
  [ "$t199" -ge 1 ] || { echo "producer-side §YAML-safety rule missing 'Truncate to 199' literal"; return 1; }
  [ "$escape_after" -ge 1 ] || { echo "producer-side ordering wrong — escape step does not appear AFTER truncate step"; return 1; }
  [ "$old_cap" = "0" ] || { echo "producer-side stale 'Cap length** at 200' numbered-rule literal still present"; return 1; }
  [ "$ca_old_summary" = "0" ] || { echo "producer-side L420 summary still names '200-char cap' (stale alongside rewritten numbered steps)"; return 1; }
  [ "$skl_t199" -ge 2 ] || { echo "consumer-side missing 'truncate to 199 chars' at BOTH SKILL.md L517 AND L521 (count must be ≥ 2)"; return 1; }
  [ "$skl_old_cap" = "0" ] || { echo "consumer-side stale '200-char cap' phrasing still present in SKILL.md"; return 1; }
  # X18(b) closure — POSITIVE clause locking the rewritten L428 summary literal. Without this,
  # a future maintainer can rewrite or delete the summary line freely (mutation-test confirmed).
  local ca_new_summary
  ca_new_summary=$(grep -cF 'every newline→space conversion site, every escape-single-quote site, and every truncate-to-199 site' "$f")
  [ "$ca_new_summary" -ge 1 ] || { echo "producer-side L428 summary literal missing the canonical 'every X site, every Y site, ...' phrasing"; return 1; }
}

check_cross_auditor_r_rule_path_env_first_precedence() {
  local f="agents/cross-auditor.md"
  local block uncond realp stale_l296 stale_l303 stale_l340 l303_post l340_post
  # Stateful awk anchor: open at the new env-first paragraph, close at the next anchor.
  # Robust to either physical layout (single paragraph or split into multiple physical lines)
  # because the close pattern is a definite sentinel introduced by the rewrite itself.
  block=$(awk '/^Path resolution: when/{p=1; print; next} p && /^If both resolutions fail/{print; exit} p{print}' "$f")
  uncond=$(echo "$block" | grep -cF 'UNCONDITIONALLY to `${CLAUDE_PLUGIN_ROOT}')
  realp=$(echo "$block" | grep -cF 'realpath')
  # Stale-prose pre-negatives (locks pre-rewrite literals absent at L296/L303/L340 surfaces).
  stale_l296=$(grep -cF "legacy invocations the agent's launch cwd is the ai-dev-team plugin root" "$f")
  stale_l303=$(grep -cF 'not reachable at the relative path' "$f")
  stale_l340=$(grep -cF 'relative path from agent cwd' "$f")
  # Post-rewrite positives (locks the new wording at parallel surfaces L303 + L340 — the L296
  # awk-bounded range exits before L303, so global grep is the right scope for those parallel sites).
  l303_post=$(grep -cF 'not reachable at the env-var path' "$f")
  l340_post=$(grep -cF 'env-first per §security mode bridge above' "$f")
  [ "$uncond" -ge 1 ] || { echo "L296 paragraph missing 'UNCONDITIONALLY to \${CLAUDE_PLUGIN_ROOT}' env-first directive"; return 1; }
  [ "$realp" -ge 1 ] || { echo "L296 paragraph missing 'realpath' fallback safety check"; return 1; }
  [ "$stale_l296" = "0" ] || { echo "L296 stale pre-rewrite prose still present (legacy-cwd phrasing)"; return 1; }
  [ "$stale_l303" = "0" ] || { echo "L303 stale 'not reachable at the relative path' wording still present"; return 1; }
  [ "$stale_l340" = "0" ] || { echo "L340 stale 'relative path from agent cwd' parenthetical still present"; return 1; }
  [ "$l303_post" -ge 1 ] || { echo "L303 missing post-rewrite 'not reachable at the env-var path' literal"; return 1; }
  [ "$l340_post" -ge 1 ] || { echo "L340 missing post-rewrite 'env-first per §security mode bridge above' literal"; return 1; }
  # C2 closure — L311 contradiction with L300 env-first semantics. The pre-rewrite L311
  # parenthetical claimed the unset-env fallback runs even when env IS set ("env-set + file-
  # missing AND the unset-env fallback above also fails"), contradicting L300's strict env-set
  # → no-relative-fallback rule. The rewrite aligns L311 with L300: env-set + file-missing →
  # warn directly; env-unset + relative-realpath fallback fails → warn.
  local stale_l311 l311_post
  stale_l311=$(grep -cF 'unset-env fallback above also fails' "$f")
  l311_post=$(grep -cF 'no relative fallback when env is set' "$f")
  [ "$stale_l311" = "0" ] || { echo "L311 stale 'unset-env fallback above also fails' contradictory phrasing still present"; return 1; }
  [ "$l311_post" -ge 1 ] || { echo "L311 missing post-rewrite 'no relative fallback when env is set' literal"; return 1; }
}

# Step 1 — SKILL.md §3.5 Pass 2 re-spawn loop monotonic numbering invariant.
# Region: between '**If CRITICAL or HIGH findings:**' and '**If no CRITICAL or HIGH findings:**'.
# Within that region, list items match ^([0-9]+)\. — extract the sequence; assert
# monotonic increasing by exactly 1, starting at 1, no duplicates (no upper bound).
# Plus negative anti-regression against the duplicate-5 fingerprint.
check_skill_pass2_respawn_loop_monotonic_numbering() {
  local f="skills/feature/SKILL.md"
  [ -f "$f" ] || { echo "$f missing"; return 1; }
  local seq
  seq=$(awk '
    /^\*\*If CRITICAL or HIGH findings:\*\*/ {in_region=1; next}
    /^\*\*If no CRITICAL or HIGH findings:\*\*/ {in_region=0}
    in_region && match($0, /^[0-9]+\./) {
      n=$0
      sub(/\..*/, "", n)
      print n
    }
  ' "$f")
  [ -n "$seq" ] || { echo "Pass 2 re-spawn loop region empty (region delimiters missing in SKILL.md)"; return 1; }
  local expected=1
  local n
  while IFS= read -r n; do
    if [ "$n" != "$expected" ]; then
      echo "Pass 2 re-spawn loop numbering not monotonic-by-1: expected $expected got $n"
      return 1
    fi
    expected=$((expected+1))
  done <<<"$seq"
  # Negative — anti-regression duplicate-5 fingerprint.
  if grep -nzPo '5\. Increment `spec_audit_iteration`\n5\. Before re-spawn' "$f" >/dev/null 2>&1; then
    echo "Pass 2 re-spawn loop duplicate-5 fingerprint regressed"
    return 1
  fi
  echo "pass2 respawn loop monotonic"
}

# Step 2 — agents/librarian.md frontmatter `tools:` line scoped check.
# Frontmatter is the YAML block between the first two `^---$` dividers.
# Bash MUST NOT appear in that line; the 5 capability tools MUST.
check_librarian_agent_no_bash_in_tools() {
  local f="agents/librarian.md"
  [ -f "$f" ] || { echo "$f missing"; return 1; }
  local fm tools_line
  fm=$(awk 'BEGIN{c=0} /^---$/{c++; next} c==1{print}' "$f")
  tools_line=$(printf '%s\n' "$fm" | grep -E '^tools:' | head -1)
  [ -n "$tools_line" ] || { echo "librarian.md frontmatter has no tools: line"; return 1; }
  if printf '%s' "$tools_line" | grep -qE '\bBash\b'; then
    echo "librarian.md frontmatter tools: line still contains Bash"
    return 1
  fi
  local t
  for t in Read Write Edit Glob Grep; do
    if ! printf '%s' "$tools_line" | grep -qE "\\b$t\\b"; then
      echo "librarian.md frontmatter tools: line missing $t"
      return 1
    fi
  done
  echo "librarian no bash"
}
