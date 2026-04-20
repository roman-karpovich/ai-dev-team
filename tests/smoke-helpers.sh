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
