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
  # Orchestrator-sole-writer contract (spec 2026-06-03-kb-parallel-write-protection):
  # the developer records the R3 regression in report.json `notes` (the
  # orchestrator copies it into observed.notes), not in observed.notes directly.
  extract_md_section "$path" '## Per-step protocol' | \
    grep -qF 'If the step adds or modifies a fresh test, `notes` MUST include a one-sentence description of the regression the test catches (see R3).' \
    || { echo "$path §Per-step protocol missing byte-exact report.json notes R3 sentence"; return 1; }
  echo "$path §Per-step protocol has report.json notes R3 requirement"
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
  grep -qF -- 'Leave all `observed` fields empty — the orchestrator fills `observed` from the developer'"'"'s `report.json` before spawning the compliance-checker (per §Implement; the developer never writes `exec.md` or the spec).' "$path" \
    || { echo "$path missing start anchor 'Leave all \`observed\` fields empty — the orchestrator fills \`observed\` from the developer'\''s \`report.json\` before spawning the compliance-checker ...'"; return 1; }
  grep -qF -- '**Change-type prompt.**' "$path" \
    || { echo "$path missing end anchor '**Change-type prompt.**'"; return 1; }
  local range
  # awk range start: stable single-quoted prefix (backticks/parens/apostrophe
  # in the full sentence make a double-quoted awk script unsafe — the grep -qF
  # guard above already pins the full byte-exact sentence; this prefix just
  # opens the range).
  range=$(awk '/^Leave all `observed` fields empty — the orchestrator fills/,/^\*\*Change-type prompt\.\*\*/' "$path")
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
  # Codex / Senior rationale-ID enumerations: rather than hard-pinning a
  # byte-exact ID string (which locks the SKILL.md prose to a STALE trigger
  # set whenever agent-routing.md gains a new T-S#/T-C# — exactly the X13
  # drift), DERIVE the expected ID list from agent-routing.md and assert
  # SKILL.md's §Agent selection enumeration matches it. A future T-S6/T-C4
  # added to agent-routing.md then forces this pin to fail until SKILL.md is
  # updated, instead of silently re-introducing the drift.
  local routing='skills/feature/references/agent-routing.md'
  [ -f "$routing" ] \
    || { echo "$path Agent-selection pin: agent-routing.md not found at $routing"; return 1; }
  # Positive Senior triggers are the `**T-S#**:` definition lines EXCLUDING
  # T-S0 (the fallback — never a pre-tag rationale). Codex triggers are all
  # `**T-C#**:` lines. extract_md_section-free: grep the bold-ID definitions.
  local codex_ids senior_ids codex_enum senior_enum
  codex_ids=$(grep -oE '^\- \*\*T-C[0-9]+\*\*' "$routing" | grep -oE 'T-C[0-9]+' | sort -u)
  senior_ids=$(grep -oE '^\- \*\*T-S[0-9]+\*\*' "$routing" | grep -oE 'T-S[0-9]+' | grep -v '^T-S0$' | sort -u)
  [ -n "$codex_ids" ] && [ -n "$senior_ids" ] \
    || { echo "$path Agent-selection pin: could not extract T-C#/T-S# IDs from agent-routing.md"; return 1; }
  # Build the expected `\`T-C1\` / \`T-C2\` / ...` enumeration string.
  codex_enum=$(printf '%s\n' "$codex_ids" | sed 's/.*/`&`/' | paste -sd'~' - | sed 's/~/ \/ /g')
  senior_enum=$(printf '%s\n' "$senior_ids" | sed 's/.*/`&`/' | paste -sd'~' - | sed 's/~/ \/ /g')
  printf '%s\n' "$range" | grep -qF -- "one of $codex_enum for \`@codex\`" \
    || { echo "$path Agent-selection range Codex rationale-ID enumeration drifted from agent-routing.md — expected 'one of $codex_enum for \`@codex\`'"; return 1; }
  printf '%s\n' "$range" | grep -qF -- "one of $senior_enum for \`@senior\`" \
    || { echo "$path Agent-selection range Senior rationale-ID enumeration drifted from agent-routing.md — expected 'one of $senior_enum for \`@senior\`'"; return 1; }
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

  # Positive — §Workflow scope-complete clause (orchestrator-sole-writer
  # contract, spec 2026-06-03-kb-parallel-write-protection): the developer
  # no longer writes any spec `status`; it returns report.json and the
  # orchestrator owns IN_PROGRESS + the terminal transition.
  grep -qF 'When your scope is complete: return the `report.json` pointer for each step. Do NOT write any spec `status`.' "$path" \
    || { echo "$path missing §Workflow scope-complete clause 'When your scope is complete: return the \`report.json\` pointer for each step. Do NOT write any spec \`status\`.'"; return 1; }
  grep -qF 'The orchestrator keeps the spec at `IN_PROGRESS` and owns the terminal transition (VERIFIED / SHIPPED, per §3.4a of feature/SKILL.md) after the verifier passes and the user picks a hand-off option.' "$path" \
    || { echo "$path missing §Workflow shared sentence 'The orchestrator keeps the spec at \`IN_PROGRESS\` and owns the terminal transition ...'"; return 1; }

  # Positive — §Spec Updates status clause: orchestrator owns status; dev never writes it.
  grep -qF 'The developer never writes `status`. The orchestrator keeps the spec at `IN_PROGRESS` during implementation and owns the terminal transition (VERIFIED / SHIPPED, per §3.4a of feature/SKILL.md) after the verifier passes and the user picks a hand-off option.' "$path" \
    || { echo "$path missing §Spec Updates status clause 'The developer never writes \`status\`. The orchestrator keeps the spec at \`IN_PROGRESS\` ...'"; return 1; }

  # Negatives.
  if grep -qF 'set status: DONE' "$path"; then
    echo "$path still contains stale 'set status: DONE' write"
    return 1
  fi
  if grep -qF 'owns the DONE transition' "$path"; then
    echo "$path still contains stale 'owns the DONE transition' phrase"
    return 1
  fi
  # Negative — the old dev-side "leave status: IN_PROGRESS" self-write
  # instruction must be gone (the developer no longer writes status).
  if grep -qF 'leave status: IN_PROGRESS' "$path"; then
    echo "$path still contains stale dev-side 'leave status: IN_PROGRESS' write instruction (status is orchestrator-owned now)"
    return 1
  fi

  # Count: shared sentence must appear at least twice (once per paragraph).
  local shared_count
  shared_count=$(grep -cF 'owns the terminal transition (VERIFIED / SHIPPED, per §3.4a' "$path")
  [[ "$shared_count" -ge 2 ]] \
    || { echo "$path expected >=2 occurrences of shared 'owns the terminal transition (VERIFIED / SHIPPED, per §3.4a' sentence, got $shared_count"; return 1; }

  echo "$path has canonical no-active-DONE-writes form (orchestrator owns status + terminal transition; dev writes none)"
}

check_cross_auditor_pretag_consistency_check() {
  local path='agents/references/cross-auditor-mode-focus.md'
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

# --- Orchestrator branch-guard (spec 2026-06-16-cross-auditor-worktree-branch-guard) ---
# Pins the §3.5d orchestrator branch-guard prose in skills/feature/SKILL.md. The
# guard wraps EVERY cross-auditor return in /feature (5 callsites). Strong enough
# to detect a BROKEN strict/ancestor split — NOT a generic "guard present once"
# check. A guard that uses merge-base --is-ancestor at callsites 1-4 (instead of
# strict equality), that drops ancestor-mode at callsite 5, that is anchored at
# fewer than 5 callsites, or that loses the step-4c / step-6 banner literals MUST
# fail this pin. Beyond the 5 anchor lines this pin ALSO validates the SHARED
# §3.5d ALGORITHM BODY (the definition lines, not the callsite anchors): the body
# `**Callsites 1-4**` rule MUST carry strict `HEAD == pre_spawn_head` and MUST NOT
# have mutated to merge-base --is-ancestor; the body `**Callsite 5 ONLY**` rule
# MUST NOT carry strict `HEAD == pre_spawn_head` (strict-injection into callsite 5
# would false-green legit append-only fixups) and MUST carry merge-base
# --is-ancestor; and the X1 Implement-phase expected_branch / not-main pre-spawn
# gate (callsites 2-5) MUST be present in both the precondition AND the continue-gate
# — validated SAME-LINE (line-extract each body line, assert the full predicate ON
# THAT line), NOT via title-level or file-wide-literal greps: gutting the precondition
# body MUST fail even though the not-main literal survives on the step-3 back-reference
# lines, and gutting the continue-gate body MUST fail even though its title phrase
# survives (X3). $1 = path (real SKILL.md OR negative fixture).
check_branch_guard_callsites() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  # (1) Guard prose anchored at all FIVE callsites (callsite 1..5).
  local n
  for n in 1 2 3 4 5; do
    grep -qF -- "**branch-guard (callsite ${n}" "$path" \
      || { echo "$path missing branch-guard callsite-${n} anchor"; return 1; }
  done
  # (2) Strict 'HEAD == pre_spawn_head' wording present for callsites 1-4, and
  #     each of those callsite lines MUST NOT carry the ancestor wording (an
  #     ancestor-mode-everywhere regression fails here). Per-callsite line extract.
  local line
  for n in 1 2 3 4; do
    line=$(grep -F -- "**branch-guard (callsite ${n}" "$path")
    printf '%s\n' "$line" | grep -qF -- 'HEAD == pre_spawn_head' \
      || { echo "$path callsite-${n} missing strict 'HEAD == pre_spawn_head' wording"; return 1; }
    if printf '%s\n' "$line" | grep -qF -- 'merge-base --is-ancestor'; then
      echo "$path callsite-${n} wrongly uses 'merge-base --is-ancestor' (callsites 1-4 are strict-equality)"
      return 1
    fi
  done
  # (3) Callsite-5 ANCHOR is ancestor-mode. The anchor line legitimately carries a
  #     CONTRAST back-reference "callsites 1-4 use strict `HEAD == pre_spawn_head`", so a
  #     naive strict-ABSENCE check would false-positive on the real file. Instead assert
  #     the FULL CONTIGUOUS mode-declaration clause verbatim — which pins ancestor-mode as
  #     the callsite-5 primary AND pins the strict mention as the contrastive back-ref in
  #     its exact position — then bound the strict mention to that single legit occurrence
  #     (count == 1). A strict-INJECTION into the callsite-5 anchor adds a SECOND strict
  #     occurrence outside the contiguous contrast span, so the count rises to 2 and fails
  #     (R2-class anchor strict-injection escape; the prior pin missed this on the anchor).
  line=$(grep -F -- "**branch-guard (callsite 5" "$path")
  printf '%s\n' "$line" | grep -qF -- 'callsite 5 ONLY uses `merge-base --is-ancestor`; callsites 1-4 use strict `HEAD == pre_spawn_head`' \
    || { echo "$path callsite-5 anchor missing the contiguous mode-declaration clause 'callsite 5 ONLY uses \`merge-base --is-ancestor\`; callsites 1-4 use strict \`HEAD == pre_spawn_head\`' (ancestor-mode primary + strict contrast back-ref)"; return 1; }
  local c5_strict
  c5_strict=$(printf '%s\n' "$line" | awk '{print gsub(/HEAD == pre_spawn_head/, "")}')
  [ "$c5_strict" = "1" ] \
    || { echo "$path callsite-5 anchor carries $c5_strict 'HEAD == pre_spawn_head' occurrences (expected exactly 1 — the legit contrast back-ref; a strict-injection into the ancestor-mode callsite-5 anchor adds a second and is a violation)"; return 1; }
  # (4) The no-auto-reset --hard base-divergence banner literal (step 6) AND the
  #     HEAD-moved-on-correct-branch hard-stop literal (step 4c). BOTH literals
  #     ALSO appear as descriptive back-references elsewhere (the step-4c literal
  #     is back-referenced at the callsite-5 anchor block, line ~918), so a
  #     file-wide grep would false-green on a gutted real definition (X4-class
  #     loose-substring escape). Line-extract each by its UNIQUE step-title locator
  #     and assert the literal ON THAT EXTRACTED DEFINITION LINE — the back-references
  #     live on other lines and cannot satisfy a per-line assertion.
  local step6 step4c
  step6=$(grep -F -- '**Local-base divergence is NOT auto-reset.**' "$path")
  [ -n "$step6" ] \
    || { echo "$path missing §3.5d step-6 title '**Local-base divergence is NOT auto-reset.**'"; return 1; }
  printf '%s\n' "$step6" | grep -qF -- 'no-auto-reset --hard base-divergence banner' \
    || { echo "$path step-6 definition line missing 'no-auto-reset --hard base-divergence banner' literal (gutted step-6; back-references elsewhere do NOT satisfy this)"; return 1; }
  step4c=$(grep -F -- '**(4c) Branch correct but HEAD check fails**' "$path")
  [ -n "$step4c" ] \
    || { echo "$path missing §3.5d step-4c title '**(4c) Branch correct but HEAD check fails**'"; return 1; }
  printf '%s\n' "$step4c" | grep -qF -- 'this is the **HEAD-moved-on-correct-branch hard-stop**' \
    || { echo "$path step-4c definition line missing contiguous 'this is the **HEAD-moved-on-correct-branch hard-stop**' clause (gutted step-4c; the callsite-5 back-reference does NOT satisfy this)"; return 1; }
  # (5) SHARED §3.5d BODY — callsites-1-4 algorithm rule (the '**Callsites 1-4**'
  #     definition line, NOT a callsite anchor) MUST carry strict
  #     'HEAD == pre_spawn_head' AND MUST NOT have mutated to ancestor-mode. This
  #     catches a body strict->ancestor mutation that the per-anchor checks above
  #     would miss (anchors and body are distinct lines).
  local body14
  body14=$(grep -F -- '**Callsites 1-4**' "$path")
  [ -n "$body14" ] \
    || { echo "$path missing §3.5d body '**Callsites 1-4**' rule line"; return 1; }
  printf '%s\n' "$body14" | grep -qF -- 'HEAD == pre_spawn_head' \
    || { echo "$path §3.5d body callsites-1-4 rule missing strict 'HEAD == pre_spawn_head'"; return 1; }
  if printf '%s\n' "$body14" | grep -qF -- 'merge-base --is-ancestor'; then
    echo "$path §3.5d body callsites-1-4 rule wrongly mutated to 'merge-base --is-ancestor' (must be strict-equality)"
    return 1
  fi
  # (6) SHARED §3.5d BODY — callsite-5 algorithm rule (the '**Callsite 5 ONLY**'
  #     definition line) MUST carry merge-base --is-ancestor AND MUST NOT carry
  #     strict 'HEAD == pre_spawn_head' (strict-ABSENCE — mirror of the callsite
  #     1-4 ancestor-absence check above). Injecting strict into callsite 5 would
  #     false-positive on legit append-only fixup commits, so it is a violation.
  local body5
  body5=$(grep -F -- '**Callsite 5 ONLY**' "$path")
  [ -n "$body5" ] \
    || { echo "$path missing §3.5d body '**Callsite 5 ONLY**' rule line"; return 1; }
  printf '%s\n' "$body5" | grep -qF -- 'merge-base --is-ancestor' \
    || { echo "$path §3.5d body callsite-5 rule missing 'merge-base --is-ancestor' (diff-audit ancestor-mode)"; return 1; }
  if printf '%s\n' "$body5" | grep -qF -- 'HEAD == pre_spawn_head'; then
    echo "$path §3.5d body callsite-5 rule wrongly carries strict 'HEAD == pre_spawn_head' (callsite 5 is ancestor-mode; strict would false-green append-only fixups)"
    return 1
  fi
  # (7) X1 Implement-phase pre-spawn PRECONDITION body line (callsites 2-5). DEFINITIVE
  #     fix for the X4 escape: 'pre_spawn_branch == expected_branch' appears TWICE on the
  #     precondition line (the REAL assert clause + a trailing descriptive back-reference
  #     "the enforced gate for the step-3 callsites-2-5 `pre_spawn_branch == expected_branch`
  #     invariant"). A loose same-line grep for that substring cannot tell them apart, so
  #     deleting the REAL assert term keeps the pin green (X4). Instead, extract the
  #     precondition line by its unique title locator and assert the FULL CONTIGUOUS
  #     real-assert clause verbatim as ONE grep -qF — the contiguous span
  #     "BEFORE the spawn, assert ... AND `pre_spawn_branch ∉ {main, master}`." is UNIQUE
  #     on the line (the back-reference is NOT contiguous-identical), so both the
  #     duplicate-substring (X4) and missing-leg escapes die. The contiguous clause carries
  #     BOTH legs (== expected_branch AND ∉ {main, master}); deleting either breaks the span.
  local precond
  precond=$(grep -F -- 'Implement-phase pre-spawn precondition (callsites 2-5 ONLY)' "$path")
  [ -n "$precond" ] \
    || { echo "$path missing X1 pre-spawn precondition title 'Implement-phase pre-spawn precondition (callsites 2-5 ONLY)'"; return 1; }
  printf '%s\n' "$precond" | grep -qF -- 'BEFORE the spawn, assert `pre_spawn_branch == expected_branch` AND `pre_spawn_branch ∉ {main, master}`.' \
    || { echo "$path X1 pre-spawn precondition body line missing the full contiguous real-assert clause 'BEFORE the spawn, assert \`pre_spawn_branch == expected_branch\` AND \`pre_spawn_branch ∉ {main, master}\`.' (gutted real assert; the same-line descriptive back-reference is NOT contiguous-identical and does NOT satisfy this)"; return 1; }
  # (8) CONTINUE-GATE body line (callsites 2-5). DEFINITIVE fix for the X5 escape: the
  #     gate's TITLE claims it "blocks on branch AND HEAD AND expected_branch", but the
  #     prior pin asserted ONLY the X1-added legs (expected_branch / not-main) and NOT the
  #     gate's PRIMARY legs (`branch != pre_spawn_branch` and the step-3 HEAD condition).
  #     Deleting those two primary legs from the line kept the pin green (X5) — re-opening
  #     the ORIGINAL incident class (cross-auditor leaves primary on main / HEAD moved) at
  #     the meta-test level. Instead, extract the continue-gate line by its unique title
  #     locator and assert the FULL CONTIGUOUS gate predicate verbatim as ONE grep -qF —
  #     a single span that enumerates ALL FOUR legs the title claims: the branch leg
  #     (branch != `pre_spawn_branch`), the HEAD leg (step-3 HEAD condition is unsatisfied),
  #     the expected_branch leg (!= `expected_branch`), and the not-main leg
  #     (`pre_spawn_branch ∈ {main, master}`). The contiguous span is UNIQUE on the line;
  #     deleting ANY leg breaks the span, so the missing-leg escape (X5) dies and the title
  #     can no longer survive a file-wide grep after the body is gutted.
  local contgate
  contgate=$(grep -F -- 'blocks on branch AND HEAD AND expected_branch' "$path")
  [ -n "$contgate" ] \
    || { echo "$path missing X1 continue-gate title 'blocks on branch AND HEAD AND expected_branch'"; return 1; }
  printf '%s\n' "$contgate" | grep -qF -- 'NEVER continue the per-step loop / Log / checkoff while ANY of: the branch != `pre_spawn_branch`; the callsite'"'"'s step-3 HEAD condition is unsatisfied; or (**callsites 2-5 ONLY**) `pre_spawn_branch` (and hence the current branch) != `expected_branch` OR `pre_spawn_branch ∈ {main, master}`.' \
    || { echo "$path continue-gate body line missing the full contiguous gate predicate enumerating ALL legs (branch != \`pre_spawn_branch\`; step-3 HEAD condition; != \`expected_branch\`; ∈ {main, master}) — gutting ANY leg (X5 missing-leg escape) or relying on the title alone does NOT satisfy this"; return 1; }
  echo "$path branch-guard anchored at 5 callsites; strict HEAD==pre_spawn_head for 1-4 (anchors + body); merge-base --is-ancestor for 5 only (anchors + body); callsite-5 strict-absence enforced; step-4c + step-6 banner literals asserted on their definition lines (not file-wide); pre-spawn precondition asserts the full contiguous real-assert clause verbatim (X4-proof); continue-gate asserts the full contiguous predicate enumerating ALL legs branch+HEAD+expected_branch+not-main verbatim (X5-proof)"
}

# --- Cross-auditor read-only-git contract (spec 2026-06-16-cross-auditor-worktree-branch-guard §3.2) ---
# Pins the defense-in-depth constraint in agents/cross-auditor.md that the agent
# treats the caller's PRIMARY working_directory as read-only for git state. Strong
# enough to catch a global-checkout-ban regression: the constraint MUST stay scoped
# to the primary working_directory AND preserve the PR-mode `gh pr checkout` carve-out
# (which runs in the skill-materialized PR worktree (via working_directory)). A wording regression to a blanket
# "no checkout anywhere" — which would break PR mode — MUST fail this pin. $1 = path
# (real cross-auditor.md OR negative fixture).
check_cross_auditor_read_only_git_contract() {
  local path="$1"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  # Extract the single constraint line carrying the load-bearing literal (one bullet).
  local line
  line=$(grep -F -- 'read-only for git state' "$path")
  # (1) The 'read-only for git state' constraint literal is present.
  [ -n "$line" ] \
    || { echo "$path missing §3.2 'read-only for git state' constraint literal"; return 1; }
  # (2) Same bullet scopes the constraint to the PRIMARY working_directory (so it is
  #     not a global ban) — keys on 'primary `working_directory`'.
  printf '%s\n' "$line" | grep -qF -- 'primary `working_directory`' \
    || { echo "$path §3.2 constraint not scoped to 'primary \`working_directory\`' (reads as a global git-state ban)"; return 1; }
  # (3) Same bullet preserves the PR-mode 'gh pr checkout' carve-out (so a blanket
  #     no-checkout regression — which would break PR mode — fails here).
  printf '%s\n' "$line" | grep -qF -- 'gh pr checkout' \
    || { echo "$path §3.2 constraint dropped the PR-mode 'gh pr checkout' carve-out (blanket no-checkout would break PR mode)"; return 1; }
  echo "$path §3.2 read-only-git contract: literal present, scoped to primary working_directory, PR-mode gh pr checkout carve-out preserved"
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
  for mode in '`logic` mode' '`security` mode' '`full` mode' '`spec` mode' '`decision` mode'; do
    printf '%s\n' "$section" | grep -qFx "### $mode" \
      || { echo "$path ## Mode Focus Areas missing line-exact '### $mode' subsection heading"; return 1; }
  done
  echo "$path has canonical ## Mode Focus Areas (heading + 5 line-exact mode subsection headings: logic/security/full/spec/decision)"
}

# prompt-text: the `### `decision` mode` section of cross-auditor-mode-focus.md
# must carry all five §3.1 decision-audit focus-cluster labels. The canonical
# structure helper above only pins the line-exact heading; this pin freezes the
# cluster CONTENT (labels-not-prose) so a decision section that silently dropped
# a cluster — e.g. rubber-stamp detection, the mode's deterministic backbone —
# cannot pass while the heading survives. Scopes to the section body so a stray
# anchor phrase elsewhere in the file cannot mask a missing cluster.
check_cross_auditor_decision_mode_focus_clusters() {
  local path="${1:-agents/references/cross-auditor-mode-focus.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(awk '
    !in_s && $0 == "### `decision` mode" { in_s = 1; next }
    in_s && /^#/ { exit }
    in_s { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path missing '### \`decision\` mode' section body"; return 1; }
  local anchor
  for anchor in 'Decision coherence' 'Premise re-derivation' 'Rubber-stamp' 'Fork analysis' 'Planned/observed'; do
    printf '%s\n' "$section" | grep -qF "$anchor" \
      || { echo "$path §decision mode missing focus-cluster anchor '$anchor'"; return 1; }
  done
  echo "$path §decision mode carries all 5 focus-cluster anchors (Decision coherence/Premise re-derivation/Rubber-stamp/Fork analysis/Planned/observed)"
}

# prompt-text: the standing integration-lens taxonomy (spec 2026-07-05-integration-lens-taxonomy).
# Pins the `### Integration lenses (standing — logic / security / full)` section of
# cross-auditor-mode-focus.md: line-exact heading, all 5 lens labels + the ADDITIVE rule +
# the differential-lens `explicit parity statement` clause (labels-not-prose, so rewording
# stays free while a dropped lens fails). Also freezes the wiring anchors — logic + security
# section bodies each carry the `Standing integration lenses` bullet, full body carries the
# `Integration lenses (standing)` reference (full-mode wiring pinned directly, not transitively).
# Codex-half parity: the `^Focus:` template line in cross-auditor-codex-dispatch.md must instruct
# pasting the standing integration lenses (template-line-scoped so a stray anchor elsewhere in the
# file cannot mask a template that dropped it). Section-scoped extraction mirrors the decision-mode
# cluster pin above; bash-3.2 compatible, awk line-equality section boundaries.
check_cross_auditor_integration_lenses_standing() {
  local path="${1:-agents/references/cross-auditor-mode-focus.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qFx '### Integration lenses (standing — logic / security / full)' "$path" \
    || { echo "$path missing line-exact '### Integration lenses (standing — logic / security / full)' heading"; return 1; }
  local section
  section=$(awk '
    !in_s && $0 == "### Integration lenses (standing — logic / security / full)" { in_s = 1; next }
    in_s && /^#/ { exit }
    in_s { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path missing '### Integration lenses (standing …)' section body"; return 1; }
  local anchor
  for anchor in '**Differential-vs-incumbent**' '**Under-issue / dropped work**' '**Runtime / framework wiring**' '**Read-side blast radius**' '**Flag-transition / migration edges**' 'Caller-supplied focus areas are ADDITIVE — they never replace the standing dimensions' 'explicit parity statement'; do
    printf '%s\n' "$section" | grep -qF "$anchor" \
      || { echo "$path §Integration lenses (standing) missing anchor '$anchor'"; return 1; }
  done
  # Wiring anchors, scoped to each mode's own section body so a stray reference cannot mask
  # a missing bullet. logic + security carry the `Standing integration lenses` bullet; full
  # carries the `Integration lenses (standing)` reference.
  local mode_body
  mode_body=$(awk '
    !in_s && $0 == "### `logic` mode" { in_s = 1; next }
    in_s && /^### / { exit }
    in_s { print }
  ' "$path")
  printf '%s\n' "$mode_body" | grep -qF 'Standing integration lenses' \
    || { echo "$path §\`logic\` mode missing 'Standing integration lenses' wiring bullet"; return 1; }
  mode_body=$(awk '
    !in_s && $0 == "### `security` mode" { in_s = 1; next }
    in_s && /^### / { exit }
    in_s { print }
  ' "$path")
  printf '%s\n' "$mode_body" | grep -qF 'Standing integration lenses' \
    || { echo "$path §\`security\` mode missing 'Standing integration lenses' wiring bullet"; return 1; }
  mode_body=$(awk '
    !in_s && $0 == "### `full` mode" { in_s = 1; next }
    in_s && /^### / { exit }
    in_s { print }
  ' "$path")
  printf '%s\n' "$mode_body" | grep -qF 'Integration lenses (standing)' \
    || { echo "$path §\`full\` mode missing 'Integration lenses (standing)' wiring reference"; return 1; }
  # Codex-half parity: the `Focus:` dispatch template line must instruct pasting the lenses.
  local dispatch="agents/references/cross-auditor-codex-dispatch.md"
  [ -r "$dispatch" ] || { echo "$dispatch not readable"; return 1; }
  grep -E '^Focus:' "$dispatch" | grep -qF 'including the standing integration lenses' \
    || { echo "$dispatch 'Focus:' template line missing 'including the standing integration lenses'"; return 1; }
  echo "$path §Integration lenses (standing) carries heading + 5 lens labels + ADDITIVE rule + parity statement; logic/security/full wiring pinned; codex-dispatch Focus line names the lenses"
}

# prompt-text: the reference-summary prose (line 3) must name FIVE operating
# modes now that `decision` is the fifth. Negative: the stale `four operating
# modes` literal must be gone. Positive: the updated prose must name `five
# operating modes`, so a bare deletion of the summary line cannot silently pass
# the negative grep (stale-prose pins need a positive anchor to keep signal).
check_cross_auditor_mode_focus_no_stale_four_modes() {
  local path="${1:-agents/references/cross-auditor-mode-focus.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  if grep -qF 'four operating modes' "$path"; then
    echo "$path still carries stale 'four operating modes' prose — decision mode makes it five"; return 1
  fi
  grep -qF 'five operating modes' "$path" \
    || { echo "$path missing 'five operating modes' summary prose"; return 1; }
  echo "$path summary names five operating modes (no stale 'four operating modes')"
}

# prompt-text: the cross-auditor hub (agents/cross-auditor.md) §Input mode enum
# must render `decision` as the fifth mode. Keys on the adjacency literal
# `` `spec` | `decision` `` so a regression that drops `decision` from the enum
# (or reorders it away from spec) fails — the rendered backtick-pipe form is the
# canonical wire contract D1 cites.
check_cross_auditor_mode_enum_names_decision() {
  local path="${1:-agents/cross-auditor.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF '`spec` | `decision`' "$path" \
    || { echo "$path §Input mode enum missing rendered '\`spec\` | \`decision\`' — decision must be the fifth mode"; return 1; }
  echo "$path §Input mode enum names decision (rendered '\`spec\` | \`decision\`')"
}

# prompt-text: the cross-auditor hub (agents/cross-auditor.md) must name the standing
# integration lenses (spec 2026-07-05-integration-lens-taxonomy). Two contracts: (1) the
# `## Mode Focus Areas` section body carries the `standing integration lenses` summary clause
# (section-scoped so a stray mention elsewhere cannot mask a summary that dropped it); (2) the
# apply-instruction line carries `mode ∈ {logic, security, full}` on the SAME line as
# `standing integration lenses` (the additive-scope clause), and the file carries the
# `never replace the standing dimensions` rule. Mirrors the decision-mode hub-pin precedent.
check_cross_auditor_hub_names_integration_lenses() {
  local path="${1:-agents/cross-auditor.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(awk '
    !in_s && $0 == "## Mode Focus Areas" { in_s = 1; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path missing '## Mode Focus Areas' section body"; return 1; }
  printf '%s\n' "$section" | grep -qF 'standing integration lenses' \
    || { echo "$path §Mode Focus Areas summary missing 'standing integration lenses' clause"; return 1; }
  grep -F 'mode ∈ {logic, security, full}' "$path" | grep -qF 'standing integration lenses' \
    || { echo "$path apply-instruction missing 'standing integration lenses' on the 'mode ∈ {logic, security, full}' line"; return 1; }
  grep -qF 'never replace the standing dimensions' "$path" \
    || { echo "$path missing 'never replace the standing dimensions' additive rule"; return 1; }
  echo "$path hub names the standing integration lenses (§Mode Focus Areas summary + apply-instruction additive clause on the 'mode ∈ {logic, security, full}' line + 'never replace the standing dimensions' rule)"
}

# prompt-text: the mode-dependent Severity Ladder in the cross-auditor hub must
# carry a `**decision mode:**` block AND the decision-mode default-floor note.
# Scopes to the block body (from the `**decision mode:**` header to the shared
# `**Severity floor behavior**` paragraph) and freezes the load-bearing per-level
# content — CRITICAL false-premise, HIGH vacuous accept/defer, MEDIUM fork
# analysis, LOW hygiene — plus the `medium+` default-floor rationale, so a block
# that silently dropped a severity level or the default-floor note cannot pass
# while the header survives (labels-not-prose, matching the mode-focus cluster pin).
check_cross_auditor_decision_severity_ladder() {
  local path="${1:-agents/cross-auditor.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(awk '
    !in_s && $0 == "**decision mode:**" { in_s = 1; print; next }
    in_s && /^\*\*Severity floor behavior\*\*/ { exit }
    in_s { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path §Severity Ladder missing '**decision mode:**' block"; return 1; }
  local anchor
  for anchor in 'demonstrably false premise' 'vacuous accept/defer of a CRITICAL/HIGH finding' 'fork analysis' 'hygiene' 'two of the five clusters go dark'; do
    printf '%s\n' "$section" | grep -qF "$anchor" \
      || { echo "$path §Severity Ladder decision block missing anchor '$anchor'"; return 1; }
  done
  echo "$path §Severity Ladder carries the decision-mode block (CRITICAL false-premise / HIGH vacuous-triage / MEDIUM fork / LOW hygiene + medium+ default floor)"
}

# prompt-text: the cross-auditor hub reference-summary line (:47) must name FIVE
# mode focus-areas now that `decision` is the fifth. Negative: the stale `four
# mode` literal must be gone. Positive: the updated prose must name `five mode`,
# so a bare deletion of the summary line cannot silently pass the negative grep
# (stale-prose pins need a positive anchor to keep signal). Distinct from the
# mode-focus.md `four operating modes` pin — different file, different literal.
check_cross_auditor_hub_no_stale_four_modes() {
  local path="${1:-agents/cross-auditor.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  if grep -qF 'four mode' "$path"; then
    echo "$path still carries stale 'four mode' prose — decision mode makes it five"; return 1
  fi
  grep -qF 'five mode' "$path" \
    || { echo "$path missing 'five mode' summary prose"; return 1; }
  echo "$path summary names five mode focus-areas (no stale 'four mode')"
}

# prompt-text: the Step 2.5 empirical-verification mode-symmetry line must name
# `decision` in its parenthetical mode list. The `four mode` negative pin above
# cannot see this line (it carries no `four` literal), so a positive pin isolates
# the symmetry line and asserts decision is present — a sweep that missed :134
# would otherwise ship silently (X18).
check_cross_auditor_mode_symmetry_names_decision() {
  local path="${1:-agents/cross-auditor.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -F 'symmetric across modes' "$path" | grep -qF 'decision' \
    || { echo "$path Step 2.5 mode-symmetry line does not name decision mode"; return 1; }
  echo "$path Step 2.5 empirical-verification mode-symmetry line names decision mode"
}

# prompt-text: the §Finding ID Format no-findings-doc exception must name BOTH spec
# AND decision mode. Decision mode also persists no findings doc and accepts
# next_finding_id (§Input :36 already reads "spec and decision modes"), so a
# spec-only exception literal routes decision re-audits to the default "read the
# highest existing ID in the findings doc" rule → ID reset/collision (audit X3).
# Scopes to the ## Finding ID Format section body so a stray 'decision' token
# elsewhere in the file cannot mask a spec-only exception header.
check_cross_auditor_finding_id_exception_names_decision() {
  local path="${1:-agents/cross-auditor.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(awk '
    /^## Finding ID Format/ { in_s = 1; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path missing ## Finding ID Format section"; return 1; }
  local exception
  exception=$(printf '%s\n' "$section" | grep -F 'mode exception')
  [ -n "$exception" ] || { echo "$path §Finding ID Format missing no-findings-doc 'mode exception' bullet"; return 1; }
  printf '%s\n' "$exception" | grep -qF 'decision' \
    || { echo "$path §Finding ID Format exception names only spec — decision mode also persists no findings doc + accepts next_finding_id (X3 ID-collision)"; return 1; }
  printf '%s\n' "$exception" | grep -qF 'Spec' \
    || { echo "$path §Finding ID Format exception no longer names spec"; return 1; }
  echo "$path §Finding ID Format no-findings-doc exception names both spec and decision mode"
}

# --- Decision-mode Codex dispatch + handshake pins (spec 2026-07-02-decision-audit-mode Step 3) ---
# Shared awk extractor semantics: the `**Decision mode** Codex prompt template:`
# fenced block. The three helpers below scope their greps to the block body so a
# stray token elsewhere in the file cannot mask a template that dropped a
# required anchor (X15/X17: real dual-model parity requires the Codex half carry
# the full decision focus, not a spec-mode clone).

# prompt-text: the decision-mode Codex prompt template must carry the `Mode: decision`
# literal AND all five §3.1 focus-cluster LABELS + the two deterministic rubber-stamp
# signal tokens (self_fallback / grill_status). labels-not-prose per audit X17 — a
# template carrying only `Mode: decision` while dropping the embedded clusters would
# hand Codex a spec-mode (wrong-question) audit, silently degrading the mode center
# to single-model.
check_cross_auditor_codex_decision_focus_anchors() {
  local path="${1:-agents/references/cross-auditor-codex-dispatch.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(awk '
    /^\*\*Decision mode\*\* Codex prompt template/ { grab=1; next }
    grab && /^```$/ { fence++; if (fence==2) exit; next }
    grab && fence==1 { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path missing **Decision mode** Codex prompt template fenced block"; return 1; }
  printf '%s\n' "$section" | grep -qF 'Mode: decision' \
    || { echo "$path decision template missing 'Mode: decision' literal"; return 1; }
  local anchor
  for anchor in 'Decision coherence' 'Premise re-derivation' 'Rubber-stamp' 'Fork analysis' 'Planned/observed' 'self_fallback' 'grill_status'; do
    printf '%s\n' "$section" | grep -qF "$anchor" \
      || { echo "$path decision template missing focus anchor '$anchor'"; return 1; }
  done
  echo "$path decision Codex template carries Mode: decision + 5 cluster labels + self_fallback/grill_status (labels-not-prose)"
}

# prompt-text: the decision-mode Codex template must instruct Codex to read the
# audited spec `[scope]`, the `[workdoc_path]`, and each `findings_paths` entry —
# without these reads the cluster-3 vacuous-triage and the cluster-1a
# findings-portion are unperformable (X20). Template-side findings_paths pin,
# DISTINCT from Step 4's SKILL-dispatch-block `findings_paths:` pin.
check_cross_auditor_codex_decision_reads_inputs() {
  local path="${1:-agents/references/cross-auditor-codex-dispatch.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(awk '
    /^\*\*Decision mode\*\* Codex prompt template/ { grab=1; next }
    grab && /^```$/ { fence++; if (fence==2) exit; next }
    grab && fence==1 { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path missing **Decision mode** Codex prompt template fenced block"; return 1; }
  local anchor
  for anchor in '[scope]' '[workdoc_path]' 'findings_paths'; do
    printf '%s\n' "$section" | grep -qF "$anchor" \
      || { echo "$path decision template does not instruct Codex to read '$anchor'"; return 1; }
  done
  echo "$path decision Codex template reads [scope]/[workdoc_path]/findings_paths"
}

# prompt-text: the decision-mode Codex template must carry the decision-mode
# severity ladder in place of the inherited `[Severity ladder for spec mode]`
# placeholder (X20). Negative: the spec-mode placeholder must be gone from the
# block. Positive: the ladder header + per-level content (false-premise /
# vacuous-triage / fork-analysis) present so a bare header cannot pass.
check_cross_auditor_codex_decision_ladder() {
  local path="${1:-agents/references/cross-auditor-codex-dispatch.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(awk '
    /^\*\*Decision mode\*\* Codex prompt template/ { grab=1; next }
    grab && /^```$/ { fence++; if (fence==2) exit; next }
    grab && fence==1 { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path missing **Decision mode** Codex prompt template fenced block"; return 1; }
  if printf '%s\n' "$section" | grep -qF '[Severity ladder for spec mode]'; then
    echo "$path decision template still carries the inherited '[Severity ladder for spec mode]' placeholder"; return 1
  fi
  printf '%s\n' "$section" | grep -qF 'Severity ladder (decision mode):' \
    || { echo "$path decision template missing 'Severity ladder (decision mode):' header — spec-mode placeholder not substituted"; return 1; }
  local anchor
  for anchor in 'demonstrably false premise' 'vacuous accept/defer of a CRITICAL/HIGH finding' 'fork analysis'; do
    printf '%s\n' "$section" | grep -qF "$anchor" \
      || { echo "$path decision template ladder missing per-level anchor '$anchor'"; return 1; }
  done
  echo "$path decision Codex template carries the decision-mode severity ladder (spec-mode placeholder substituted)"
}

# prompt-text: the Step-4 write-vs-inline contract (cross-auditor-output-format.md)
# no-write exception (~:7) must name decision mode AND generalize its caller
# parenthetical to the standalone `/cross-audit` (decision's caller). Without this
# the agent WRITES an orphaned findings doc for a decision-mode return (X12),
# contradicting §3.4/D3 and colliding with D6/R8.
check_cross_auditor_output_format_no_write_names_decision() {
  local path="${1:-agents/references/cross-auditor-output-format.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local excline
  excline=$(grep -F 'mode exception' "$path")
  [ -n "$excline" ] || { echo "$path missing Step-4 '... mode exception' no-write line"; return 1; }
  printf '%s\n' "$excline" | grep -qF 'decision' \
    || { echo "$path Step-4 no-write exception does not name decision mode"; return 1; }
  printf '%s\n' "$excline" | grep -qF 'standalone `/cross-audit`' \
    || { echo "$path Step-4 no-write exception caller parenthetical not generalized to standalone /cross-audit"; return 1; }
  echo "$path Step-4 no-write exception names decision (caller parenthetical generalized to standalone /cross-audit)"
}

# prompt-text: the evidence-handshake doc must name decision mode in BOTH the
# spec-scoped no-write clause (~:31) — with its caller phrase generalized off
# 'calling feature skill' to the standalone `/cross-audit` — AND the claude_model
# placement clause (~:56, the 'immediately preceding' the sentinel rule). Decision
# rides the spec-mode inline-footer channel; these two clauses were spec-only.
check_cross_auditor_handshake_names_decision() {
  local path="${1:-agents/references/cross-auditor-evidence-handshake.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  # (a) no-write clause (~:31) names decision + caller generalized to /cross-audit.
  local nowrite
  nowrite=$(grep -F 'does NOT write findings.md' "$path")
  [ -n "$nowrite" ] || { echo "$path missing no-write clause 'does NOT write findings.md'"; return 1; }
  printf '%s\n' "$nowrite" | grep -qF 'decision' \
    || { echo "$path no-write clause (~:31) does not name decision mode"; return 1; }
  printf '%s\n' "$nowrite" | grep -qF '/cross-audit' \
    || { echo "$path no-write clause (~:31) caller not generalized to standalone /cross-audit"; return 1; }
  # (b) claude_model placement clause (~:56) names decision on the 'immediately
  #     preceding' bullet (the sentinel-adjacency rule that model-attestation pins).
  grep -F 'immediately preceding' "$path" | grep -qF 'decision' \
    || { echo "$path claude_model placement clause (~:56) does not name decision mode"; return 1; }
  echo "$path handshake no-write (:31) + claude_model placement (:56) clauses name decision (caller generalized)"
}

# --- Decision-mode /cross-audit standalone-entry pins (spec 2026-07-02-decision-audit-mode Step 4) ---
# The nine helpers below pin skills/cross-audit/SKILL.md's decision-mode entry.
# Four of them scope their greps to the `### Decision mode` subsection (near the
# Flags block) or the `### Decision-mode return handling` Phase-3 subsection via
# the shared awk extractors below, so a stray token elsewhere cannot mask a
# subsection that dropped a required contract clause.
_skill_decision_mode_section() {
  # `### Decision mode` subsection body (Flags-adjacent), anchored within the
  # `## Argument Parsing` region. X6 REOPENED residual hardening — two extractor-
  # discrimination shapes the prior loose-prefix + first-match extractor left
  # GREEN on a gutted real carve-out:
  #   M1 (prefix-sibling H2): the region-open anchor is now the EXACT line
  #     `## Argument Parsing` (`/^## Argument Parsing$/`), so a decoy
  #     `## Argument Parsing <suffix>` placed above the real H2 can no longer open
  #     a false region and hand a decoy `### Decision mode` to the extractor. The
  #     real H2 still terminates any region a stray H2 opened (`inarg && /^## /`).
  #   M2 (in-region duplicate H3): the region is scanned to its close and the
  #     `### Decision mode` occurrences are COUNTED; the body is emitted only when
  #     EXACTLY ONE occurrence exists. A duplicate decoy `### Decision mode` placed
  #     before the real (gutted) one → count==2 → empty output → consumer pins RED.
  # Also still rejects the original decoy-outside-region shape (heading above the
  # region is never counted while inarg==0). Grab stops at the next `### ` heading
  # or `---` rule.
  awk '
    /^## Argument Parsing$/ { inarg=1; next }
    inarg && /^## / { inarg=0 }
    inarg && /^### Decision mode/ { count++; grab=1; buf=""; next }
    inarg && grab && /^### / { grab=0 }
    inarg && grab && /^---$/ { grab=0 }
    inarg && grab { buf = buf $0 "\n" }
    END { if (count == 1) printf "%s", buf }
  ' "$1"
}
_skill_decision_phase3_section() {
  # `### Decision-mode return handling` Phase-3 subsection body, anchored within
  # the `## Phase 3` region. X6 REOPENED residual hardening (same two shapes as
  # _skill_decision_mode_section):
  #   M1 (prefix-sibling H2): the region-open anchor is now the EXACT parent H2
  #     `## Phase 3: Present & Decide` (`/^## Phase 3: Present & Decide/`), so a
  #     decoy `## Phase 3.5 …` above the real H2 can no longer open a false region.
  #     (Prefix, not `$`-exact, because the real H2 carries a ` (foreground,
  #     interactive)` suffix — `## Phase 3.5` still fails the `Present & Decide`
  #     literal, and the real H2 terminates a decoy-opened region via `/^## /`.)
  #   M2 (in-region duplicate H3): `### Decision-mode return handling` occurrences
  #     inside the region are COUNTED; the body is emitted only when EXACTLY ONE
  #     exists. A duplicate decoy H3 before the real (gutted) one → count==2 →
  #     empty output → consumer pins RED.
  # Also still rejects the original decoy-outside-region shape. Grab stops at the
  # next `### ` heading.
  awk '
    /^## Phase 3: Present & Decide/ { inphase=1; next }
    inphase && /^## / { inphase=0 }
    inphase && /^### Decision-mode return handling/ { count++; grab=1; buf=""; next }
    inphase && grab && /^### / { grab=0 }
    inphase && grab { buf = buf $0 "\n" }
    END { if (count == 1) printf "%s", buf }
  ' "$1"
}
# Extract a single markdown bullet from a section body. $1 = section text, $2 = a
# bold-marker substring on the bullet's opening `- ` line (e.g. '**Report-only').
# Prints the bullet block: the opening line plus continuation lines up to the next
# sibling `- ` bullet, heading, or blank line. Used so load-bearing clauses are
# asserted CO-LOCATED within ONE bullet (X6 sweep-B) — independent tokens scattered
# across the section (a decoy or a partial gut) are not the contract.
_skill_decision_phase3_bullet() {
  printf '%s\n' "$1" | awk -v marker="$2" '
    !inb && index($0, marker) && /^- / { inb=1; print; next }
    inb && (/^- / || /^#/ || /^$/) { exit }
    inb { print }
  '
}
_skill_decision_launch_block() {
  # The `[Decision mode only ...]` sub-block INSIDE the Phase 1-2 Step 2 launch
  # template (the fenced dispatch block the skill actually threads at dispatch
  # time — not the `### Decision mode` reference subsection). Starts at the
  # `[Decision mode only` marker, stops at the next `[` sub-block marker or the
  # blank line that closes the block. This is what wires decision-mode params
  # into the live launch path; pinning it (not just the doc block) closes the
  # X2 coverage hole where a revert of that wiring stayed green.
  awk '
    /^\[Decision mode only/ { grab=1; next }
    grab && /^\[/ { exit }
    grab && /^$/ { exit }
    grab { print }
  ' "$1"
}

# prompt-text: the Flags block must expose `--mode decision` in the mode enum AND
# document the KB-spec-path scope form `/cross-audit <kb-spec-path> --mode decision`
# (decision is standalone-first — the reviewer audits a shipped /feature trail).
check_cross_audit_skill_decision_flag() {
  local path="${1:-skills/cross-audit/SKILL.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF -- '--mode logic|security|full|decision' "$path" \
    || { echo "$path --mode flag enum does not include decision"; return 1; }
  grep -qF '/cross-audit <kb-spec-path> --mode decision' "$path" \
    || { echo "$path missing decision-mode scope form '/cross-audit <kb-spec-path> --mode decision'"; return 1; }
  echo "$path Flags block documents --mode decision + KB-spec-path scope form"
}

# prompt-text: the `### Decision mode` subsection must carry the standalone
# slug-derivation rule (X21) — the date-prefix-strip formula, the derived
# workdoc_path, and the derived findings glob. Raw-basename resolution silently
# yields a non-existent workdoc dir + empty findings glob.
check_cross_audit_skill_decision_slug_derivation() {
  local path="${1:-skills/cross-audit/SKILL.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(_skill_decision_mode_section "$path")
  [ -n "$section" ] || { echo "$path missing '### Decision mode' subsection"; return 1; }
  printf '%s\n' "$section" | grep -qF 'feature_slug = basename(scope)' \
    || { echo "$path decision slug-derivation missing formula 'feature_slug = basename(scope)'"; return 1; }
  printf '%s\n' "$section" | grep -qF 'YYYY-MM-DD-' \
    || { echo "$path decision slug-derivation does not name the leading YYYY-MM-DD- prefix"; return 1; }
  printf '%s\n' "$section" | grep -qF 'date prefix' \
    || { echo "$path decision slug-derivation does not strip the date prefix"; return 1; }
  printf '%s\n' "$section" | grep -qF 'design/workdocs/<feature_slug>/exec.md' \
    || { echo "$path decision slug-derivation missing derived workdoc_path 'design/workdocs/<feature_slug>/exec.md'"; return 1; }
  printf '%s\n' "$section" | grep -qF 'security/<feature_slug>-*findings.md' \
    || { echo "$path decision slug-derivation missing derived findings glob 'security/<feature_slug>-*findings.md'"; return 1; }
  echo "$path decision subsection carries the date-prefix-strip slug-derivation rule (formula + workdoc + findings glob)"
}

# prompt-text: the one genuinely new dispatch param `findings_paths:` must be
# threaded in BOTH the `### Decision mode` reference subsection AND the Phase 1-2
# Step 2 launch template's `[Decision mode only ...]` block — the latter is the
# live dispatch path the skill actually threads. Template-side SKILL-dispatch pin,
# distinct from Step 3's Codex-template findings_paths pin. Pinning only the
# reference block (X2 coverage hole) let the launch-path wiring ship/revert green.
check_cross_audit_skill_decision_findings_paths_dispatch() {
  local path="${1:-skills/cross-audit/SKILL.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section launch
  section=$(_skill_decision_mode_section "$path")
  [ -n "$section" ] || { echo "$path missing '### Decision mode' subsection"; return 1; }
  printf '%s\n' "$section" | grep -qF 'findings_paths:' \
    || { echo "$path decision dispatch block does not thread 'findings_paths:'"; return 1; }
  launch=$(_skill_decision_launch_block "$path")
  [ -n "$launch" ] || { echo "$path missing Step 2 launch-template '[Decision mode only ...]' block"; return 1; }
  printf '%s\n' "$launch" | grep -qF 'findings_paths:' \
    || { echo "$path Step 2 launch template does not thread 'findings_paths:' for decision mode"; return 1; }
  echo "$path decision dispatch threads findings_paths: in both the doc subsection and the Step 2 launch template"
}

# prompt-text: the decision dispatch must thread `severity_floor` with the
# decision-mode DEFAULT of `medium+` (NOT the global `high`) — X13: a high floor
# takes two of the five focus clusters dark. Pinned in BOTH the `### Decision
# mode` reference subsection AND the Phase 1-2 Step 2 launch template's
# `[Decision mode only ...]` block (the live dispatch path) — pinning only the
# reference block (X2 coverage hole) let the launch-path wiring ship/revert green.
check_cross_audit_skill_decision_severity_floor() {
  local path="${1:-skills/cross-audit/SKILL.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section launch
  section=$(_skill_decision_mode_section "$path")
  [ -n "$section" ] || { echo "$path missing '### Decision mode' subsection"; return 1; }
  printf '%s\n' "$section" | grep -qF 'severity_floor' \
    || { echo "$path decision dispatch block does not thread 'severity_floor'"; return 1; }
  printf '%s\n' "$section" | grep -qF 'medium+' \
    || { echo "$path decision dispatch block does not name the medium+ floor"; return 1; }
  printf '%s\n' "$section" | grep -qiF 'default' \
    || { echo "$path decision dispatch block does not mark medium+ as the decision-mode DEFAULT"; return 1; }
  launch=$(_skill_decision_launch_block "$path")
  [ -n "$launch" ] || { echo "$path missing Step 2 launch-template '[Decision mode only ...]' block"; return 1; }
  printf '%s\n' "$launch" | grep -qF 'severity_floor' \
    || { echo "$path Step 2 launch template does not thread 'severity_floor' for decision mode"; return 1; }
  printf '%s\n' "$launch" | grep -qF 'medium+' \
    || { echo "$path Step 2 launch template does not name the medium+ decision default"; return 1; }
  printf '%s\n' "$launch" | grep -qiF 'default' \
    || { echo "$path Step 2 launch template does not mark medium+ as the decision-mode DEFAULT"; return 1; }
  echo "$path decision dispatch threads severity_floor+medium+ default in both the doc subsection and the Step 2 launch template"
}

# prompt-text: Phase 3 must carry a decision-mode branch that SKIPS the findings.md
# read and presents the inline findings from the agent return (decision writes no
# findings doc — spec-mode inline-footer channel). Both clauses are asserted
# CO-LOCATED in the single skip-findings bullet (X6 sweep-B): "skip the read AND
# present inline" is one contract, not two independent tokens a decoy/partial gut
# could satisfy separately. Extractor is `## Phase 3`-anchored (X6).
check_cross_audit_skill_decision_phase3_branch() {
  local path="${1:-skills/cross-audit/SKILL.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section bullet
  section=$(_skill_decision_phase3_section "$path")
  [ -n "$section" ] || { echo "$path missing '### Decision-mode return handling' Phase-3 subsection"; return 1; }
  bullet=$(_skill_decision_phase3_bullet "$section" '**Skip the findings')
  [ -n "$bullet" ] || { echo "$path Phase-3 decision branch missing the '**Skip the findings.md read.**' bullet"; return 1; }
  printf '%s\n' "$bullet" | grep -qF 'SKIP the findings.md read' \
    || { echo "$path Phase-3 skip-findings bullet does not SKIP the findings.md read"; return 1; }
  printf '%s\n' "$bullet" | grep -qF 'inline findings from the agent return' \
    || { echo "$path Phase-3 skip-findings bullet does not co-locate 'present inline findings from the agent return'"; return 1; }
  echo "$path Phase-3 decision branch skips findings.md read + presents inline findings (co-located in the skip bullet)"
}

# prompt-text: decision-mode returns must be classified via the spec channel —
# `check_dispatch_response.py --mode spec` (footer shape identical; no
# --findings-path). Pinned on one line carrying both tokens.
check_cross_audit_skill_decision_classifier_wiring() {
  local path="${1:-skills/cross-audit/SKILL.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -F 'check_dispatch_response.py --mode spec' "$path" | grep -qF 'decision' \
    || { echo "$path decision returns not wired to the check_dispatch_response.py --mode spec classifier channel"; return 1; }
  echo "$path wires decision returns via check_dispatch_response.py --mode spec channel"
}

# prompt-text: after the return-contract gate passes, the orchestrator appends ONE
# Log line to the audited spec §9 Log. Freeze the literal line shape; the severity
# counts come from the inline summary table, not the footer.
check_cross_audit_skill_decision_log_append() {
  local path="${1:-skills/cross-audit/SKILL.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF 'decision audit — <N> findings (crit=X high=Y med=Z); evidence=' "$path" \
    || { echo "$path missing orchestrator Log-append literal 'decision audit — <N> findings (crit=X high=Y med=Z); evidence='"; return 1; }
  echo "$path carries the orchestrator decision Log-append rule (literal frozen)"
}

# prompt-text: decision findings are NEVER published to a PR — they cite KB paths
# by nature and publishing KB paths violates R8. Both clauses asserted CO-LOCATED
# in the single no-publish bullet (X6 sweep-B): the R8 cite is the REASON for
# NEVER-published, so a scattered `R8` elsewhere in the section must not satisfy
# it. Extractor is `## Phase 3`-anchored (X6).
check_cross_audit_skill_decision_no_publish() {
  local path="${1:-skills/cross-audit/SKILL.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section bullet
  section=$(_skill_decision_phase3_section "$path")
  [ -n "$section" ] || { echo "$path missing '### Decision-mode return handling' Phase-3 subsection"; return 1; }
  bullet=$(_skill_decision_phase3_bullet "$section" '**No publish')
  [ -n "$bullet" ] || { echo "$path Phase-3 decision branch missing the '**No publish.**' bullet"; return 1; }
  printf '%s\n' "$bullet" | grep -qF 'NEVER published' \
    || { echo "$path Phase-3 no-publish bullet does not state decision findings are NEVER published"; return 1; }
  printf '%s\n' "$bullet" | grep -qF 'R8' \
    || { echo "$path Phase-3 no-publish bullet does not co-locate the R8 cite"; return 1; }
  echo "$path Phase-3 decision branch states the no-publish (R8) rule (co-located in the no-publish bullet)"
}

# prompt-text: decision mode is report-only — the Phase 3 step-3 per-finding
# triage banner (fix/accept/defer) and the Phase 4 findings-doc status mutation
# both target a findings doc decision mode never writes, so both do NOT apply
# (findings transient per grill D3; the §9 Log-append is the single persistence
# trace). The user acts by editing the audited spec / opening follow-ups. All
# three clauses ('per-finding' banner + 'Phase 4' mutation + 'do NOT apply') are
# asserted CO-LOCATED in the single report-only bullet (X6 sweep-B): the confirmed
# X4→X6 mutant scattered these tokens across a gutted section behind a decoy
# heading and the pre-X6 pin stayed GREEN. Extractor is `## Phase 3`-anchored (X6).
check_cross_audit_skill_decision_report_only() {
  local path="${1:-skills/cross-audit/SKILL.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section bullet
  section=$(_skill_decision_phase3_section "$path")
  [ -n "$section" ] || { echo "$path missing '### Decision-mode return handling' Phase-3 subsection"; return 1; }
  bullet=$(_skill_decision_phase3_bullet "$section" '**Report-only')
  [ -n "$bullet" ] || { echo "$path Phase-3 decision branch missing the '**Report-only …**' carve-out bullet"; return 1; }
  printf '%s\n' "$bullet" | grep -qiF 'per-finding' \
    || { echo "$path Phase-3 report-only bullet does not disable the per-finding triage banner"; return 1; }
  printf '%s\n' "$bullet" | grep -qF 'Phase 4' \
    || { echo "$path Phase-3 report-only bullet does not co-locate the Phase 4 status mutation"; return 1; }
  printf '%s\n' "$bullet" | grep -qF 'do NOT apply' \
    || { echo "$path Phase-3 report-only bullet missing co-located 'do NOT apply'"; return 1; }
  echo "$path Phase-3 decision branch is report-only (per-finding banner + Phase 4 mutation 'do NOT apply' co-located in one bullet)"
}

# prompt-text: SKILL prose-completeness — the dispatch-template mode placeholder
# names decision, the §Adaptation per-mode list names decision, and the
# argument-hint frontmatter names decision (the three stale-list sweep sites).
check_cross_audit_skill_decision_prose_complete() {
  local path="${1:-skills/cross-audit/SKILL.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF 'mode: [logic|security|full|decision]' "$path" \
    || { echo "$path dispatch-template mode placeholder is not '[logic|security|full|decision]'"; return 1; }
  grep -qF '`logic` / `security` / `full` / `spec` / `decision`' "$path" \
    || { echo "$path §Adaptation per-mode list does not name decision"; return 1; }
  local arghint
  arghint=$(grep -F 'argument-hint:' "$path")
  printf '%s\n' "$arghint" | grep -qF 'decision' \
    || { echo "$path argument-hint frontmatter does not name decision"; return 1; }
  echo "$path prose-complete: dispatch placeholder + per-mode list + argument-hint all name decision"
}

# prompt-text: the Phase 1-2 `### Step 3: Inform the user` launch banner must carry
# a decision-mode variant that DROPS the `Findings → …/security/<slug>-findings.md`
# line — decision writes no findings doc, so that path is a dangling reference —
# and states the return is inline instead (code-audit X5, sweep-A "mode-generic
# surface assumes a findings doc"). Scoped to the `### Step 3` section; the negative
# `Findings →` grep is confined to the decision-variant sub-block so the generic
# (logic/security/full) banner's own `Findings →` line does not mask a regression.
check_cross_audit_skill_decision_launch_banner() {
  local path="${1:-skills/cross-audit/SKILL.md}"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local section
  section=$(awk '
    /^### Step 3: Inform the user/ { grab=1; next }
    grab && /^## / { exit }
    grab && /^### / { exit }
    grab && /^---$/ { exit }
    grab { print }
  ' "$path")
  [ -n "$section" ] || { echo "$path missing '### Step 3: Inform the user' section"; return 1; }
  printf '%s\n' "$section" | grep -qF 'Decision mode (`--mode decision`) variant' \
    || { echo "$path Step 3 banner has no decision-mode variant (still unconditionally surfaces a Findings→ findings-doc line)"; return 1; }
  # Decision-variant sub-block: from the variant marker to end of section.
  local decvar
  decvar=$(printf '%s\n' "$section" | awk '/Decision mode \(`--mode decision`\) variant/ { grab=1 } grab { print }')
  printf '%s\n' "$decvar" | grep -qF 'return inline' \
    || { echo "$path Step 3 decision-mode variant does not state the return is inline"; return 1; }
  # Negative targets the emitted BANNER line (a `> Findings →` blockquote), not
  # the prose that tells the reader to drop it — the explanatory prose legitimately
  # names `Findings →`; a regression re-adds the `> Findings →` blockquote line.
  if printf '%s\n' "$decvar" | grep -qE '^> *Findings →'; then
    echo "$path Step 3 decision-mode variant still emits the '> Findings →' banner line (decision writes no findings doc — dangling path)"; return 1
  fi
  echo "$path Step 3 banner carries a decision-mode variant that drops the Findings→ banner line (inline return)"
}

# NEGATIVE (fixture-based): proves the `## Argument Parsing` / `## Phase 3`-anchored
# decision extractors reject a decoy heading placed OUTSIDE its canonical region
# (code-audit X6). The fixture carries decoy `### Decision mode` +
# `### Decision-mode return handling` headings above their parent `## ` regions
# (full carve-out text) and gutted REAL headings inside the regions. A pre-X6
# first-match extractor grabbed the decoys and every consumer check stayed GREEN on
# a gutted spec (the confirmed mutant). Post-X6 the anchored extractors grab the
# gutted real sections, so all four consumer checks MUST fail (return 1) on the
# fixture — this pin asserts none leaked GREEN.
check_cross_audit_skill_decision_phase3_decoy_rejected() {
  local fx='tests/fixtures/decision-phase3-decoy/skill-decoy.md'
  [ -r "$fx" ] || { echo "$fx decoy fixture not readable"; return 1; }
  local leaked=""
  check_cross_audit_skill_decision_slug_derivation "$fx" >/dev/null 2>&1 && leaked="$leaked slug_derivation"
  check_cross_audit_skill_decision_phase3_branch   "$fx" >/dev/null 2>&1 && leaked="$leaked phase3_branch"
  check_cross_audit_skill_decision_no_publish      "$fx" >/dev/null 2>&1 && leaked="$leaked no_publish"
  check_cross_audit_skill_decision_report_only     "$fx" >/dev/null 2>&1 && leaked="$leaked report_only"
  if [ -n "$leaked" ]; then
    echo "decoy fixture: decision check(s)$leaked passed on a gutted real section — a decoy heading outside its canonical region hijacked the extractor (X6 first-match regression)"
    return 1
  fi
  echo "decoy fixture: anchored extractors reject the decoy-outside-region gutted sections (slug_derivation/phase3_branch/no_publish/report_only all RED)"
}

# NEGATIVE (fixture-based): M1 prefix-sibling H2 (code-audit X6 REOPENED residual).
# A decoy H2 that SHARES A PREFIX with the real parent H2 (`## Argument Parsing
# (legacy)` / `## Phase 3.5 Decoy`) is placed ABOVE the real region carrying the
# full carve-out; the real in-region H3 is gutted. The EXACT-anchor extractors
# (`/^## Argument Parsing$/`, `/^## Phase 3: Present & Decide/`) MUST ignore the
# prefix-sibling decoy and grab the gutted real section, so all four consumer
# checks go RED. A pre-residual `/^## Argument Parsing/` + `/^## Phase 3/` anchor
# opened the decoy region and stayed GREEN (the reproduced M1 mutant).
check_cross_audit_skill_decision_m1_prefix_sibling_rejected() {
  local fx='tests/fixtures/decision-phase3-decoy/skill-decoy-m1.md'
  [ -r "$fx" ] || { echo "$fx M1 decoy fixture not readable"; return 1; }
  local leaked=""
  check_cross_audit_skill_decision_slug_derivation "$fx" >/dev/null 2>&1 && leaked="$leaked slug_derivation"
  check_cross_audit_skill_decision_phase3_branch   "$fx" >/dev/null 2>&1 && leaked="$leaked phase3_branch"
  check_cross_audit_skill_decision_no_publish      "$fx" >/dev/null 2>&1 && leaked="$leaked no_publish"
  check_cross_audit_skill_decision_report_only     "$fx" >/dev/null 2>&1 && leaked="$leaked report_only"
  if [ -n "$leaked" ]; then
    echo "M1 decoy fixture: decision check(s)$leaked passed on a gutted real section — a prefix-sibling decoy H2 hijacked the loose-anchor extractor (X6 M1 regression)"
    return 1
  fi
  echo "M1 decoy fixture: exact-anchor extractors ignore the prefix-sibling decoy H2 (slug_derivation/phase3_branch/no_publish/report_only all RED)"
}

# NEGATIVE (fixture-based): M2 in-region duplicate H3 (code-audit X6 REOPENED
# residual). A DUPLICATE decoy H3 (`### Decision mode` / `### Decision-mode return
# handling`) is placed INSIDE the exact parent region, BEFORE the real (gutted)
# H3, carrying the full carve-out a first-match grab would return. The
# uniqueness-guarded extractors COUNT the in-region H3 occurrences and emit
# nothing when the count != 1, so all four consumer checks go RED on the empty
# section. A pre-residual first-match extractor grabbed the decoy H3 and stayed
# GREEN (the reproduced M2 mutant).
check_cross_audit_skill_decision_m2_duplicate_h3_rejected() {
  local fx='tests/fixtures/decision-phase3-decoy/skill-decoy-m2.md'
  [ -r "$fx" ] || { echo "$fx M2 decoy fixture not readable"; return 1; }
  local leaked=""
  check_cross_audit_skill_decision_slug_derivation "$fx" >/dev/null 2>&1 && leaked="$leaked slug_derivation"
  check_cross_audit_skill_decision_phase3_branch   "$fx" >/dev/null 2>&1 && leaked="$leaked phase3_branch"
  check_cross_audit_skill_decision_no_publish      "$fx" >/dev/null 2>&1 && leaked="$leaked no_publish"
  check_cross_audit_skill_decision_report_only     "$fx" >/dev/null 2>&1 && leaked="$leaked report_only"
  if [ -n "$leaked" ]; then
    echo "M2 decoy fixture: decision check(s)$leaked passed on a gutted real section — a duplicate in-region decoy H3 was grabbed by the first-match extractor (X6 M2 regression)"
    return 1
  fi
  echo "M2 decoy fixture: uniqueness-guarded extractors reject the duplicate in-region H3 (slug_derivation/phase3_branch/no_publish/report_only all RED)"
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
  # Step 1 helper — asserts the §Step 4 findings.md template carries:
  #  (1) the updated table header `ID | Severity | Issue | Source | Mode | Confidence | Status`
  #  (2) new details-block fields: Sources / Mode at emit / Blocking / Probe receipt / Probe version / Eligible reason
  #      (Source is column-only — NOT a details-block field)
  #  (3) legacy `Found by` → `sources[]` round-trip mapping note with three-case expansion
  # The §Step 4 canonical body lives in agents/references/cross-auditor-output-format.md.
  local path="agents/references/cross-auditor-output-format.md"
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

check_findings_schema_failure_class() {
  # spec 2026-07-05-fix-dispatch-carries-failure Step 1 — asserts the §Step 4
  # details template in cross-auditor-output-format.md carries BOTH new literals:
  #  (1) the `- **Failure class / input domain**:` details-block field
  #  (2) the renamed advisory Fix label `- **Fix (advisory)**:`
  # Regression: reverting either literal (dropping the failure-class field, or
  # restoring the bare `**Fix**:` label) breaks the finding schema contract that
  # the renderer emits — this pin catches a template/renderer drift.
  local path="agents/references/cross-auditor-output-format.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF -- '- **Failure class / input domain**:' "$path" \
    || { echo "$path missing details-block field '- **Failure class / input domain**:'"; return 1; }
  grep -qF -- '- **Fix (advisory)**:' "$path" \
    || { echo "$path missing renamed advisory Fix label '- **Fix (advisory)**:'"; return 1; }
  echo "$path details template carries '**Failure class / input domain**:' + '**Fix (advisory)**:'"
}

check_codex_dispatch_emits_failure_class() {
  # spec 2026-07-05-fix-dispatch-carries-failure Step 2 — asserts the three
  # per-mode Codex prompt templates in cross-auditor-codex-dispatch.md each emit a
  # MODE-APPROPRIATE failure-class instruction while preserving their distinct
  # lead-in verbatim (code=file:line / spec=spec section/step reference /
  # decision=artifact-line reference). Each grep co-locates the lead-in and the
  # failure-class clause on one emission line (byte-exact through the clause).
  # Regression: a single find-replace that clobbered a mode lead-in, dropped a
  # template's failure-class clause, un-marked the suggestion advisory, or leaked
  # the code-only "input domain" wording into the spec/decision prompts breaks it.
  local path="agents/references/cross-auditor-codex-dispatch.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }

  grep -qF -- 'For each finding: file:line, description, failure class / input domain (the class of inputs/states, not one observed example),' "$path" \
    || { echo "$path code template missing 'file:line' lead-in + 'failure class / input domain' clause"; return 1; }
  grep -qF -- 'For each finding: spec section/step reference, description, failure class (the class of spec defects/cases the issue covers, not one example),' "$path" \
    || { echo "$path spec template missing 'spec section/step reference' lead-in + spec-defects failure-class clause"; return 1; }
  grep -qF -- 'For each finding: artifact-line reference (spec §9 Log line / workdoc field / findings-doc ID), description, failure class (the class of decisions/cases the issue covers, not one example),' "$path" \
    || { echo "$path decision template missing 'artifact-line reference (...)' lead-in + decisions failure-class clause"; return 1; }

  local adv
  adv=$(grep -cF 'concrete fix suggestion (advisory —' "$path")
  [ "$adv" = "3" ] || { echo "$path expected 3 advisory-marked fix-suggestion lines, found $adv"; return 1; }

  # "input domain" wording is code-runtime-only — must NOT leak into spec/decision.
  local idc
  idc=$(grep -cF 'input domain' "$path")
  [ "$idc" = "1" ] || { echo "$path expected 'input domain' exactly once (code template only), found $idc"; return 1; }

  echo "$path all three Codex templates emit mode-appropriate failure class; lead-ins survive; input-domain code-only"
}

check_claude_step2_mode_conditional_failure_class() {
  # spec 2026-07-05-fix-dispatch-carries-failure Step 2 — asserts cross-auditor.md
  # §Step 2 (mode-shared, no internal branch) carries the MODE-CONDITIONAL
  # failure-class sentence: "input domain" scoped to code/security/full, plus the
  # spec-defects and decisions phrasings + the advisory note. Regression: dropping
  # the sentence, or letting bare "input domain" apply to all modes (leaking
  # code-runtime wording into spec/decision audits), breaks this pin.
  local path="agents/cross-auditor.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }

  # Isolate the §Step 2 body (through the next '## Step 2.4' heading) so the
  # sentence is asserted in the mode-shared section, not elsewhere in the file.
  local sect
  sect=$(awk '/^## Step 2: Claude Audit/{f=1} f&&/^## Step 2\.4/{exit} f' "$path")
  [ -n "$sect" ] || { echo "$path §Step 2 section not found"; return 1; }

  printf '%s\n' "$sect" | grep -qF -- 'code/security/full findings as failure class / input domain (the class of inputs/states, not one observed example)' \
    || { echo "$path §Step 2 missing 'input domain' scoped to code/security/full"; return 1; }
  printf '%s\n' "$sect" | grep -qF -- 'spec findings as the class of spec defects/cases' \
    || { echo "$path §Step 2 missing spec-defects failure-class phrasing"; return 1; }
  printf '%s\n' "$sect" | grep -qF -- 'decision findings as the class of decisions/cases' \
    || { echo "$path §Step 2 missing decisions failure-class phrasing"; return 1; }
  printf '%s\n' "$sect" | grep -qF -- 'The fix suggestion is advisory' \
    || { echo "$path §Step 2 missing advisory fix-suggestion note"; return 1; }

  echo "$path §Step 2 carries mode-conditional failure-class sentence (input-domain scoped; spec/decision phrasings; advisory)"
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

check_renderer_failure_class_passthrough() {
  # spec 2026-07-05-fix-dispatch-carries-failure Step 1 — fixture-01's input JSON
  # carries a distinctive failure_class VALUE; the regenerated golden byte-matches
  # AND the rendered output must carry that literal value on the details line.
  # Byte-diff proves render_findings.sh passes f['failure_class'] through (not just
  # the label); the explicit value grep guards against a renderer that emits the
  # line but drops/empties the value.
  # Regression: rendering the failure-class value as empty (or hardcoding the
  # label without threading f.get('failure_class')) fails the value grep.
  _render_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/renderer/01-no-probes-legacy-input.json \
    tests/fixtures/cross-audit-probes-foundation/renderer/01-no-probes-legacy-expected.md || return 1
  local out
  out=$(bash hooks/lib/render_findings.sh \
    < tests/fixtures/cross-audit-probes-foundation/renderer/01-no-probes-legacy-input.json) \
    || { echo "render_findings.sh exited non-zero on fixture 01"; return 1; }
  printf '%s\n' "$out" | grep -qF -- '- **Failure class / input domain**: unparseable-numeric inputs: NaN/Infinity/negative' \
    || { echo "render_findings.sh dropped the distinctive failure_class VALUE from fixture-01 output"; return 1; }
  echo "render_findings.sh passes the distinctive failure_class VALUE through to the details block"
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

check_dedupe_failure_class_carry() {
  # spec 2026-07-05-fix-dispatch-carries-failure Step 1 — probe:E + claude merge
  # where ONLY the LLM member carries failure_class. The X23 swap makes the probe
  # member primary before dict(primary), so without merge_pair's explicit
  # `out["failure_class"] = primary.get(...) or secondary.get(...) or ""` carry
  # the LLM-side value is DROPPED. Byte-match asserts the merged entry retains it.
  # Regression: removing the carry line drops the value → byte-diff fails.
  _dedupe_findings_byte_diff \
    tests/fixtures/cross-audit-probes-foundation/dedupe/merged-probe-llm-failure-class-input.json \
    tests/fixtures/cross-audit-probes-foundation/dedupe/merged-probe-llm-failure-class-expected.json
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
  local path="agents/references/cross-auditor-step-3-pipeline.md"
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
  local path="agents/references/cross-auditor-step-3-pipeline.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF 'CROSS_AUDIT_SCORER_MOCK_JSON' "$path" \
    || { echo "$path missing CROSS_AUDIT_SCORER_MOCK_JSON env-var seam declaration"; return 1; }
  grep -qiE 'mock.*(test|seam|injection)|test[- ]injection|smoke[- ]test' "$path" \
    || { echo "$path CROSS_AUDIT_SCORER_MOCK_JSON declaration lacks test-seam context"; return 1; }
  echo "$path declares CROSS_AUDIT_SCORER_MOCK_JSON mock seam for test injection"
}

check_parse_scorer_response_helper() {
  # hooks/lib/parse_scorer_response.py — resilient extraction + validation of
  # haiku-finding-scorer responses. Behavioral test: invoke the helper across
  # extraction tiers (raw / fenced / first-brace) and validation rejection
  # cases (missing ID, stray top-level key, bad confidence, empty rationale,
  # unparseable garbage). Each case asserts on the exit code and stderr line.
  local helper="hooks/lib/parse_scorer_response.py"
  [ -x "$helper" ] || { echo "$helper not executable"; return 1; }

  local ok='{"scores":{"F1":{"confidence":42,"rationale":"ok"}}}'

  # Tier 1 — raw JSON parses, exit 0
  out=$(printf '%s' "$ok" | python3 "$helper" F1 2>/dev/null)
  rc=$?
  [ "$rc" = "0" ] && [ -n "$out" ] \
    || { echo "$helper: tier-1 raw JSON expected rc=0, got rc=$rc out='$out'"; return 1; }

  # Tier 2 — preamble + ```json fence, exit 0
  fenced=$'Now let me analyze each finding:\n\n**F1**: long analysis here\n\n```json\n'"$ok"$'\n```\n'
  rc=$(printf '%s' "$fenced" | python3 "$helper" F1 >/dev/null 2>&1; echo $?)
  [ "$rc" = "0" ] \
    || { echo "$helper: tier-2 fenced-with-preamble expected rc=0, got rc=$rc"; return 1; }

  # Tier 3 — first-{ to last-} fallback (no fences), exit 0
  brace="some preamble $ok trailing text"
  rc=$(printf '%s' "$brace" | python3 "$helper" F1 >/dev/null 2>&1; echo $?)
  [ "$rc" = "0" ] \
    || { echo "$helper: tier-3 first-brace fallback expected rc=0, got rc=$rc"; return 1; }

  # Validation — missing ID, exit 1, reason "missing IDs"
  err=$(printf '%s' "$ok" | python3 "$helper" F1 F2 2>&1 >/dev/null)
  rc=$?
  [ "$rc" = "1" ] && printf '%s' "$err" | grep -qF 'missing IDs' \
    || { echo "$helper: missing-ID expected rc=1 + 'missing IDs', got rc=$rc err='$err'"; return 1; }

  # Validation — stray top-level key, exit 1, reason "stray top-level keys"
  extra='{"scores":{"F1":{"confidence":42,"rationale":"ok"}},"extra":1}'
  err=$(printf '%s' "$extra" | python3 "$helper" F1 2>&1 >/dev/null)
  rc=$?
  [ "$rc" = "1" ] && printf '%s' "$err" | grep -qF 'stray top-level keys' \
    || { echo "$helper: stray-key expected rc=1 + 'stray top-level keys', got rc=$rc err='$err'"; return 1; }

  # Validation — bad confidence, exit 1, reason "integer in 0..100"
  badconf='{"scores":{"F1":{"confidence":200,"rationale":"ok"}}}'
  err=$(printf '%s' "$badconf" | python3 "$helper" F1 2>&1 >/dev/null)
  rc=$?
  [ "$rc" = "1" ] && printf '%s' "$err" | grep -qF 'integer in 0..100' \
    || { echo "$helper: bad-confidence expected rc=1 + 'integer in 0..100', got rc=$rc err='$err'"; return 1; }

  # Validation — empty rationale, exit 1, reason "rationale missing or empty"
  empty='{"scores":{"F1":{"confidence":42,"rationale":""}}}'
  err=$(printf '%s' "$empty" | python3 "$helper" F1 2>&1 >/dev/null)
  rc=$?
  [ "$rc" = "1" ] && printf '%s' "$err" | grep -qF 'rationale missing or empty' \
    || { echo "$helper: empty-rationale expected rc=1 + 'rationale missing or empty', got rc=$rc err='$err'"; return 1; }

  # Extraction — unparseable garbage, exit 1, reason "not parseable as JSON"
  err=$(printf '%s' 'just plain text no json anywhere' | python3 "$helper" F1 2>&1 >/dev/null)
  rc=$?
  [ "$rc" = "1" ] && printf '%s' "$err" | grep -qF 'not parseable as JSON' \
    || { echo "$helper: garbage expected rc=1 + 'not parseable as JSON', got rc=$rc err='$err'"; return 1; }

  echo "$helper: 3 extraction tiers + 5 validation rejections pass"
}

check_step3_pipeline_references_parse_scorer_response_helper() {
  # The Step 3 step 4 prose must reference parse_scorer_response.py as the
  # validation seam so the contract is single-sourced (helper enforces; prose
  # documents). Anchor regex matches the helper path AND the three-tier
  # description.
  local path="agents/references/cross-auditor-step-3-pipeline.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF 'parse_scorer_response.py' "$path" \
    || { echo "$path Step 3 missing parse_scorer_response.py helper reference"; return 1; }
  grep -qiE 'tier|raw.*fenced|fenced.*first[- ]brace|three.*extraction' "$path" \
    || { echo "$path Step 3 missing tier-extraction prose"; return 1; }
  echo "$path Step 3 step 4 delegates parsing to parse_scorer_response.py helper"
}

check_cross_auditor_step3_scorer_integration() {
  # agents/cross-auditor.md Step 3 declares the 5-stage pipeline with the
  # scorer call between dedupe (§3.5) and renderer (Step 4). Probe-sourced
  # findings pinned confidence=100; pure-LLM findings scored via Task tool.
  local path="agents/references/cross-auditor-step-3-pipeline.md"
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
  local path="agents/references/cross-auditor-step-3-pipeline.md"
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
  local path="agents/references/cross-auditor-step-3-pipeline.md"
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
  local path="agents/references/cross-auditor-step-3-pipeline.md"
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
  # producer path. Per Spec 2a Step 6, §Step 0.5 body content moved to
  # agents/references/cross-auditor-pr-and-probes.md while the pointer-stub H2
  # stays in the hub; the negative §Input assertion plus the H2-presence check
  # land on the hub, while the positive probe_findings /
  # probe_receipt_metadata_by_provisional_id literal checks land on the
  # reference file.
  local path="agents/cross-auditor.md"
  local ref="agents/references/cross-auditor-pr-and-probes.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  [ -r "$ref" ] || { echo "$ref not readable"; return 1; }
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
  # Positive: Step 0.5 H2 pointer-stub still anchors in the hub.
  grep -qE '^## Step 0\.5' "$path" \
    || { echo "$path missing '## Step 0.5' producer section (expected between Step 0 and Step 1)"; return 1; }
  # Positive: producer-side literals live in the reference file.
  grep -qF 'probe_findings' "$ref" \
    || { echo "$ref missing 'probe_findings' — Step 0.5 should produce it"; return 1; }
  grep -qF 'probe_receipt_metadata_by_provisional_id' "$ref" \
    || { echo "$ref missing 'probe_receipt_metadata_by_provisional_id' side-map (iter-4 X19)"; return 1; }
  echo "$path ## Input no longer lists probe_receipts bullet; $ref Step 0.5 produces probe_findings/probe_receipts via side-map (X19)"
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
  # Per Spec 2a Step 6, §Step 0 + §Step 0.5 body content moved to
  # agents/references/cross-auditor-pr-and-probes.md while pointer-stub H2 lines
  # remain in agents/cross-auditor.md. Hub asserts positional ordering of the
  # H2s (Step 0 < Step 0.5 < Step 1); reference asserts the canonical body
  # contract — six-way fail-open class enumeration, side-map key (iter-4 X19),
  # producer-side output lists, and off-floor enforcement.
  local path="agents/cross-auditor.md"
  local ref="agents/references/cross-auditor-pr-and-probes.md"
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  [ -r "$ref" ] || { echo "$ref not readable"; return 1; }
  local step0_line step05_line step1_line
  step0_line=$(grep -nE '^## Step 0 \(PR mode only\)' "$path" | head -1 | cut -d: -f1)
  step05_line=$(grep -nE '^## Step 0\.5' "$path" | head -1 | cut -d: -f1)
  step1_line=$(grep -nE '^## Step 1: Launch Codex' "$path" | head -1 | cut -d: -f1)
  [[ -n "$step05_line" ]] || { echo "$path missing '## Step 0.5' heading"; return 1; }
  [[ -n "$step0_line" && -n "$step1_line" ]] \
    || { echo "$path missing Step 0 or Step 1 neighbours for Step 0.5 ordering check"; return 1; }
  [[ "$step0_line" -lt "$step05_line" && "$step05_line" -lt "$step1_line" ]] \
    || { echo "$path Step 0.5 is not positioned between Step 0 ($step0_line) and Step 1 ($step1_line) — got Step 0.5 at $step05_line"; return 1; }
  # Extract the Step 0.5 section from the reference file.
  local step05
  step05=$(awk '
    !in_s && /^## Step 0\.5/ { in_s = 1; print; next }
    in_s && /^## / && !/^## Step 0\.5/ { exit }
    in_s { print }
  ' "$ref")
  # Six-way fail-open enumeration — distinct class markers.
  printf '%s\n' "$step05" | grep -qF 'probe script' \
    || { echo "$ref Step 0.5 missing fail-open class 1 'probe script' (script-missing)"; return 1; }
  printf '%s\n' "$step05" | grep -qF 'TimeoutError' \
    || { echo "$ref Step 0.5 missing fail-open class 2 'TimeoutError'"; return 1; }
  printf '%s\n' "$step05" | grep -qF 'NonZeroExit' \
    || { echo "$ref Step 0.5 missing fail-open class 3 'NonZeroExit'"; return 1; }
  printf '%s\n' "$step05" | grep -qF 'JSONDecodeError' \
    || { echo "$ref Step 0.5 missing fail-open class 4 'JSONDecodeError'"; return 1; }
  printf '%s\n' "$step05" | grep -qF 'schema' \
    || { echo "$ref Step 0.5 missing fail-open class 5 'schema' (validation)"; return 1; }
  # Class 6 (receipt-write IOError) lives in stage 4.5 (Step 3 pipeline) — moved
  # to agents/references/cross-auditor-step-3-pipeline.md per Spec 2a Step 4.
  grep -qF 'receipt write failed' agents/references/cross-auditor-step-3-pipeline.md \
    || { echo "agents/references/cross-auditor-step-3-pipeline.md missing fail-open class 6 (receipt write failed) in Step 3 stage 4.5"; return 1; }
  # Side-map (iter-4 X19) + provisional_id coupling (iter-5 X22).
  printf '%s\n' "$step05" | grep -qF 'probe_receipt_metadata_by_provisional_id' \
    || { echo "$ref Step 0.5 missing side-map key (iter-4 X19)"; return 1; }
  printf '%s\n' "$step05" | grep -qF 'probe_findings' \
    || { echo "$ref Step 0.5 missing probe_findings output list"; return 1; }
  printf '%s\n' "$step05" | grep -qF 'probe_failures_seed' \
    || { echo "$ref Step 0.5 missing probe_failures_seed list (iter-4 X20)"; return 1; }
  printf '%s\n' "$step05" | grep -qF 'mode == "off"' \
    || { echo "$ref Step 0.5 missing off-floor enforcement 'mode == \"off\"'"; return 1; }
  echo "cross-auditor Step 0.5 present (hub pointer-stub ordered between Step 0 and Step 1), six fail-open classes + side-map + off-floor enforcement on $ref"
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
  # Also assert the agent prose contains the NonZeroExit branch (Step 0.5
  # body moved to agents/references/cross-auditor-pr-and-probes.md per Spec 2a Step 6).
  grep -qF 'probe exited non-zero' agents/references/cross-auditor-pr-and-probes.md \
    || { echo "agents/references/cross-auditor-pr-and-probes.md missing 'probe exited non-zero' Step 0.5 branch"; return 1; }
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
  grep -qF 'probe output schema invalid' agents/references/cross-auditor-pr-and-probes.md \
    || { echo "agents/references/cross-auditor-pr-and-probes.md missing 'probe output schema invalid' Step 0.5 branch"; return 1; }
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
  grep -qF 'receipt write failed' agents/references/cross-auditor-step-3-pipeline.md \
    || { echo "agents/references/cross-auditor-step-3-pipeline.md missing 'receipt write failed' stage-4.5 branch (fail-open class 6)"; return 1; }
  # Also assert the pair (receipt write failed, check KB mount).
  grep -qF 'check KB mount is writable' agents/references/cross-auditor-step-3-pipeline.md \
    || { echo "agents/references/cross-auditor-step-3-pipeline.md stage-4.5 branch missing remediation 'check KB mount is writable'"; return 1; }
  # Also exercise the full stage-4.5 side-map + receipt-write loop — if the
  # agent's stage-4.5 prose drifts (e.g. stops preserving provisional_id),
  # the seed-and-render layer above doesn't catch it. Assert the prose pins:
  grep -qE 'any\(s\.startswith\("probe:"\) for s in finding\["sources"\]\)' agents/references/cross-auditor-step-3-pipeline.md \
    || { echo "agents/references/cross-auditor-step-3-pipeline.md stage-4.5 missing probe-sourced predicate (Foundation §3.3 X2 / iter-3 X18)"; return 1; }
  grep -qE 'provisional_id' agents/references/cross-auditor-step-3-pipeline.md \
    || { echo "agents/references/cross-auditor-step-3-pipeline.md stage-4.5 missing provisional_id preservation (iter-5 X22/X24)"; return 1; }
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
  work=$(mktemp -d) || return 1
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
  work=$(mktemp -d) || return 1
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

check_compliance_checker_wap_heading_present() {
  local path="${1:-agents/spec-compliance-checker.md}"
  grep -qF '#### WAP — Workdoc assertion-count parity (process-truthfulness)' "$path" \
    || { echo "$path missing '#### WAP — Workdoc assertion-count parity (process-truthfulness)' subheading"; return 1; }
  echo "WAP workdoc assertion-count parity heading present in $path"
}

check_compliance_checker_wap_lists_n_increment_anchor() {
  local path="${1:-agents/spec-compliance-checker.md}"
  local WAP
  WAP=$(awk '
    $0 == "#### WAP — Workdoc assertion-count parity (process-truthfulness)" { in_s = 1; print; next }
    in_s && (/^#### / || /^### /) { exit }
    in_s { print }
  ' "$path")
  printf '%s\n' "$WAP" | grep -qF 'n=$((n+1))' \
    || { echo "$path WAP subsection missing byte-exact 'n=\$((n+1))' anchor"; return 1; }
  echo "WAP subsection lists byte-exact n=\$((n+1)) anchor in $path"
}

check_compliance_checker_wap_lists_expected_pass_increments_anchor() {
  local path="${1:-agents/spec-compliance-checker.md}"
  local WAP
  WAP=$(awk '
    $0 == "#### WAP — Workdoc assertion-count parity (process-truthfulness)" { in_s = 1; print; next }
    in_s && (/^#### / || /^### /) { exit }
    in_s { print }
  ' "$path")
  printf '%s\n' "$WAP" | grep -qF 'expected_pass increments' \
    || { echo "$path WAP subsection missing byte-exact 'expected_pass increments' anchor"; return 1; }
  echo "WAP subsection lists byte-exact expected_pass increments anchor in $path"
}

check_compliance_checker_wap_in_verdict_template() {
  local path="${1:-agents/spec-compliance-checker.md}"
  local SECT6
  SECT6=$(awk '
    $0 == "### 6. Return verdict" { in_s = 1; print; next }
    in_s && $0 == "## Rules" { exit }
    in_s { print }
  ' "$path")
  printf '%s\n' "$SECT6" | grep -qF -- '- WAP (workdoc assertion-count parity):' \
    || { echo "$path ### 6. Return verdict section missing byte-exact WAP verdict-template line"; return 1; }
  echo "WAP line present in verdict template ### Code quality block in $path"
}

check_compliance_checker_wap_in_rules() {
  local path="${1:-agents/spec-compliance-checker.md}"
  local RULES
  RULES=$(awk '
    $0 == "## Rules" { in_s = 1; print; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$path")
  printf '%s\n' "$RULES" | grep -qF -- '- Code quality WAP violations are DRIFT' \
    || { echo "$path ## Rules section missing byte-exact WAP DRIFT enforcement bullet opening"; return 1; }
  echo "## Rules has WAP DRIFT enforcement bullet in $path"
}

# --- WAP (Workdoc Assertion-count Parity) helper behavioral pin (BACKLOG #63 — slice 1) ---

check_workdoc_parity_helper_detects_drift() {
  local helper='tests/workdoc_parity_check.py'
  local fixture_workdoc='tests/fixtures/workdoc-assertion-count-parity/workdoc.md'
  local fixture_spec='tests/fixtures/workdoc-assertion-count-parity/spec.md'

  [ -f "$helper" ] \
    || { echo "$helper missing — WAP helper not installed"; return 1; }
  [ -f "$fixture_workdoc" ] \
    || { echo "$fixture_workdoc missing — WAP fixture workdoc not installed"; return 1; }
  [ -f "$fixture_spec" ] \
    || { echo "$fixture_spec missing — WAP fixture spec not installed"; return 1; }

  local out rc
  out=$(python3 "$helper" "$fixture_workdoc" --spec "$fixture_spec" 2>&1)
  rc=$?

  [ "$rc" -eq 1 ] \
    || { echo "WAP helper expected exit 1 on DRIFT fixture, got $rc; output:"; printf '%s\n' "$out"; return 1; }

  printf '%s\n' "$out" | grep -qF "step 1 — OK" \
    || { echo "WAP helper output missing 'step 1 — OK'; output:"; printf '%s\n' "$out"; return 1; }
  printf '%s\n' "$out" | grep -qF "step 2 — DRIFT INV-1" \
    || { echo "WAP helper output missing 'step 2 — DRIFT INV-1'; output:"; printf '%s\n' "$out"; return 1; }
  printf '%s\n' "$out" | grep -qF "step 2 — DRIFT INV-2" \
    || { echo "WAP helper output missing 'step 2 — DRIFT INV-2'; output:"; printf '%s\n' "$out"; return 1; }
  printf '%s\n' "$out" | grep -qF "step 3 — N/A" \
    || { echo "WAP helper output missing 'step 3 — N/A'; output:"; printf '%s\n' "$out"; return 1; }

  echo "WAP helper detects INV-1 + INV-2 drift and N/A skip on synthetic fixture (exit=1)"
}

check_wap_inv2_drift_on_invalid_pattern() {
  local helper='tests/workdoc_parity_check.py'
  local workdoc='tests/fixtures/workdoc-assertion-count-parity/workdoc.md'
  local spec='tests/fixtures/workdoc-assertion-count-parity/spec.md'

  local out rc
  out=$(python3 "$helper" "$workdoc" --spec "$spec" --step 4 2>&1)
  rc=$?

  [ "$rc" -eq 1 ] \
    || { echo "expected exit 1, got $rc; output: $out"; return 1; }
  printf '%s\n' "$out" | grep -qF "DRIFT INV-2" \
    || { echo "missing DRIFT INV-2 in output: $out"; return 1; }
  printf '%s\n' "$out" | grep -qF "is not a pure integer" \
    || { echo "missing 'is not a pure integer' in output: $out"; return 1; }
  printf '%s\n' "$out" | grep -qF "cannot verify spec narrative" \
    || { echo "missing 'cannot verify spec narrative' in output: $out"; return 1; }

  echo "WAP INV-2 DRIFT emitted when workdoc expected_pass_pattern is non-integer but spec has parenthetical"
}

check_wap_step_not_found_exits_2() {
  local helper='tests/workdoc_parity_check.py'
  local workdoc='tests/fixtures/workdoc-assertion-count-parity/workdoc.md'
  local spec='tests/fixtures/workdoc-assertion-count-parity/spec.md'

  local stdout stderr rc
  stdout=$(python3 "$helper" "$workdoc" --spec "$spec" --step 99 2>/tmp/wap_step_not_found_stderr)
  rc=$?
  stderr=$(cat /tmp/wap_step_not_found_stderr); rm -f /tmp/wap_step_not_found_stderr

  [ "$rc" -eq 2 ] \
    || { echo "expected exit 2, got $rc; stderr: $stderr"; return 1; }
  [ -z "$stdout" ] \
    || { echo "expected empty stdout, got: $stdout"; return 1; }
  printf '%s\n' "$stderr" | grep -qF "not found in workdoc" \
    || { echo "missing 'not found in workdoc' in stderr: $stderr"; return 1; }
  printf '%s\n' "$stderr" | grep -qF "present steps are" \
    || { echo "missing 'present steps are' in stderr: $stderr"; return 1; }

  echo "WAP --step 99 emits stderr diagnostic and exits 2 with empty stdout"
}

check_wap_fence_skip_in_parser() {
  local helper='tests/workdoc_parity_check.py'
  local workdoc='tests/fixtures/workdoc-assertion-count-parity/workdoc-fenced.md'

  local out rc
  out=$(python3 "$helper" "$workdoc" 2>&1)
  rc=$?

  [ "$rc" -eq 0 ] \
    || { echo "expected exit 0 (no DRIFT), got $rc; output: $out"; return 1; }
  printf '%s\n' "$out" | grep -qF "OK" \
    || { echo "missing OK verdict in output: $out"; return 1; }
  printf '%s\n' "$out" | grep -qF "echo bogus" \
    && { echo "fenced bogus value leaked into output: $out"; return 1; }
  printf '%s\n' "$out" | grep -qF "99" \
    && { echo "fenced pattern value '99' leaked into output: $out"; return 1; }

  echo "WAP parser skips fenced-block overrides — real values used, fenced bogus values ignored"
}

check_wap_inv1_drift_on_zero_counter() {
  local helper='tests/workdoc_parity_check.py'
  local workdoc='tests/fixtures/workdoc-assertion-count-parity/workdoc.md'
  local spec='tests/fixtures/workdoc-assertion-count-parity/spec.md'

  local out rc
  out=$(python3 "$helper" "$workdoc" --spec "$spec" --step 5 2>&1)
  rc=$?

  [ "$rc" -eq 1 ] \
    || { echo "expected exit 1, got $rc; output: $out"; return 1; }
  printf '%s\n' "$out" | grep -qF "DRIFT INV-1" \
    || { echo "missing DRIFT INV-1 in output: $out"; return 1; }
  printf '%s\n' "$out" | grep -qF "declares 3 expected_pass increments" \
    || { echo "missing counter declaration in output: $out"; return 1; }
  printf '%s\n' "$out" | grep -qF "zero n=" \
    || { echo "missing 'zero n=' in output: $out"; return 1; }
  # Must NOT emit a contradictory OK line for the same step
  printf '%s\n' "$out" | grep -qF "step 5 — OK" \
    && { echo "contradictory OK emitted alongside DRIFT INV-1 for step 5: $out"; return 1; }

  echo "WAP INV-1 DRIFT emitted when spec declares counter but passing_test_cmd has zero n=\$((n+1)) occurrences"
}

check_wap_inv2_drift_on_unparseable_parenthetical() {
  local helper='tests/workdoc_parity_check.py'
  local workdoc='tests/fixtures/workdoc-assertion-count-parity/workdoc.md'
  local spec='tests/fixtures/workdoc-assertion-count-parity/spec.md'

  local out rc
  out=$(python3 "$helper" "$workdoc" --spec "$spec" --step 6 2>&1)
  rc=$?

  [ "$rc" -eq 1 ] \
    || { echo "expected exit 1, got $rc; output: $out"; return 1; }
  printf '%s\n' "$out" | grep -qF "DRIFT INV-2" \
    || { echo "missing DRIFT INV-2 in output: $out"; return 1; }
  printf '%s\n' "$out" | grep -qF "parenthetical present but unparseable" \
    || { echo "missing 'parenthetical present but unparseable' in output: $out"; return 1; }
  printf '%s\n' "$out" | grep -qF "three expected_pass increments" \
    || { echo "missing raw worded-numeral text in output: $out"; return 1; }

  echo "WAP INV-2 DRIFT emitted when spec parenthetical present but unparseable (worded numeral)"
}

check_wap_inv2_parses_non_canonical_spec_form() {
  local spec='tests/fixtures/workdoc-assertion-count-parity/spec-non-canonical.md'

  local out rc
  out=$(python3 -c "
import sys; sys.path.insert(0, 'tests')
from workdoc_parity_check import parse_spec_61_parentheticals
from pathlib import Path
r = parse_spec_61_parentheticals(Path('$spec'))
parens = r[0] if isinstance(r, tuple) else r
assert parens == {1: 2}, f'expected {{1: 2}}, got {parens!r}'
print('OK')
" 2>&1)
  rc=$?

  [ "$rc" -eq 0 ] \
    || { echo "expected exit 0, got $rc; output: $out"; return 1; }
  printf '%s\n' "$out" | grep -qF "OK" \
    || { echo "missing OK in output: $out"; return 1; }

  echo "WAP broadened parser recognises ### 6.1 H3 heading + plain Step N bullets, excludes Step 99 under sibling ### 6.2"
}

check_finding_claims_helper_flags_known_wrong_fixture() {
  # Strong R3-form behavioral pin: exercises tests/check_finding_claims.py
  # end-to-end against the synthetic known-wrong fixture at
  # tests/fixtures/cap-banner-empirical-verification/known-wrong-findings.md.
  # The fixture's five findings (X1-X5) are pre-verified against HEAD
  # d29b0cf — X1/X2/X3/X4 are deliberately wrong (MISMATCH / MISMATCH /
  # LINE-OUT-OF-RANGE / FILE-MISSING), X5 is a deliberately-correct
  # control. The pin asserts:
  #   (1) helper script + fixture both present,
  #   (2) helper exits NON-ZERO against the fixture (flagging the
  #       intentional wrongness — proves the verification logic actually
  #       runs, not just byte-anchors prose),
  #   (3) each diagnostic class (MISMATCH / LINE-OUT-OF-RANGE /
  #       FILE-MISSING) appears with its expected X-id,
  #   (4) the OK control (X5) is reported OK (proves the helper doesn't
  #       false-positive — a degenerate "always-flag" helper would fail
  #       this leg even though it satisfies leg #2 and leg #3).
  # Source: spec 2026-05-13-cap-banner-and-empirical-verification.md Step 6.
  local helper="tests/check_finding_claims.py"
  local fixture="tests/fixtures/cap-banner-empirical-verification/known-wrong-findings.md"
  [ -f "$helper" ] \
    || { echo "missing $helper"; return 1; }
  [ -f "$fixture" ] \
    || { echo "missing $fixture"; return 1; }

  local out rc
  out=$(python3 "$helper" "$fixture" 2>&1)
  rc=$?

  if [ "$rc" -eq 0 ]; then
    echo "expected helper to flag known-wrong fixture (exit non-zero), got rc=0"
    printf '%s\n' "$out"
    return 1
  fi

  printf '%s\n' "$out" | grep -qE '^X1: MISMATCH agents/cross-auditor\.md:99' \
    || { echo "missing X1 MISMATCH diagnostic for agents/cross-auditor.md:99"; printf '%s\n' "$out"; return 1; }
  printf '%s\n' "$out" | grep -qE '^X2: MISMATCH skills/feature/SKILL\.md:42' \
    || { echo "missing X2 MISMATCH diagnostic for skills/feature/SKILL.md:42"; printf '%s\n' "$out"; return 1; }
  printf '%s\n' "$out" | grep -qE '^X3: LINE-OUT-OF-RANGE agents/cross-auditor\.md:9999' \
    || { echo "missing X3 LINE-OUT-OF-RANGE diagnostic"; printf '%s\n' "$out"; return 1; }
  printf '%s\n' "$out" | grep -qE '^X4: FILE-MISSING nonexistent/path\.md' \
    || { echo "missing X4 FILE-MISSING diagnostic"; printf '%s\n' "$out"; return 1; }
  printf '%s\n' "$out" | grep -qE '^X5: OK agents/cross-auditor\.md:121' \
    || { echo "missing X5 OK diagnostic (control case — helper must not false-positive)"; printf '%s\n' "$out"; return 1; }
  printf '%s\n' "$out" | grep -qF 'Total: 5 findings, 4 mismatches' \
    || { echo "missing summary line 'Total: 5 findings, 4 mismatches'"; printf '%s\n' "$out"; return 1; }

  echo "check_finding_claims.py flags 4/5 known-wrong fixture findings (MISMATCH x2, LINE-OUT-OF-RANGE, FILE-MISSING); OK control verified"
}

check_finding_claims_helper_flags_malformed_no_file_line_fixture() {
  # Regression pin for code-audit X1 (2026-05-14): tests/check_finding_claims.py
  # used to silently skip H3 blocks whose `### [X<n>] <title>` heading was
  # parseable but whose body lacked the canonical `- **File**: <path>:<line>`
  # line. Net effect: a findings.md with `## Details` present but every
  # finding missing the File line returned exit 0 with "Total: 0 findings,
  # 0 mismatches" — defeating the empirical-verification gate precisely when
  # upstream auditor failure was most severe.
  #
  # X1 fix introduced the MALFORMED-FINDING diagnostic class: parse_findings
  # now returns (findings, parse_errors); main() prints one
  # `Xn: MALFORMED-FINDING <reason>` per parse error and counts each into the
  # mismatch tally so the exit code is 1. This pin asserts:
  #   (1) helper script + new fixture both present,
  #   (2) helper exits NON-ZERO against the malformed fixture,
  #   (3) each X-id (X1/X2/X3) appears with the MALFORMED-FINDING diagnostic
  #       and the canonical "missing `- **File**: <path>:<line>` line" reason,
  #   (4) the summary reports 0 findings + 3 mismatches (defends against a
  #       regression that drops parse-errors back to silent-skip but happens
  #       to surface some other mismatch class).
  # Source: code-audit iter-1 X1 (2026-05-14) on spec
  # 2026-05-13-cap-banner-and-empirical-verification.md Step 6.
  local helper="tests/check_finding_claims.py"
  local fixture="tests/fixtures/cap-banner-empirical-verification/malformed-no-file-line.md"
  [ -f "$helper" ] \
    || { echo "missing $helper"; return 1; }
  [ -f "$fixture" ] \
    || { echo "missing $fixture"; return 1; }

  local out rc
  out=$(python3 "$helper" "$fixture" 2>&1)
  rc=$?

  if [ "$rc" -eq 0 ]; then
    echo "expected helper to flag malformed-no-file-line fixture (exit non-zero), got rc=0"
    printf '%s\n' "$out"
    return 1
  fi

  printf '%s\n' "$out" | grep -qF 'X1: MALFORMED-FINDING missing `- **File**: <path>:<line>` line in Details body' \
    || { echo "missing X1 MALFORMED-FINDING diagnostic with canonical reason"; printf '%s\n' "$out"; return 1; }
  printf '%s\n' "$out" | grep -qF 'X2: MALFORMED-FINDING missing `- **File**: <path>:<line>` line in Details body' \
    || { echo "missing X2 MALFORMED-FINDING diagnostic with canonical reason"; printf '%s\n' "$out"; return 1; }
  printf '%s\n' "$out" | grep -qF 'X3: MALFORMED-FINDING missing `- **File**: <path>:<line>` line in Details body' \
    || { echo "missing X3 MALFORMED-FINDING diagnostic with canonical reason"; printf '%s\n' "$out"; return 1; }
  printf '%s\n' "$out" | grep -qF 'Total: 0 findings, 3 mismatches' \
    || { echo "missing summary line 'Total: 0 findings, 3 mismatches'"; printf '%s\n' "$out"; return 1; }

  echo "check_finding_claims.py flags 3/3 malformed (no-File-line) fixture blocks with MALFORMED-FINDING; exit 1"
}

check_no_dangling_section_anchor_references() {
  # Structural pin closing the pointer-rot defect class surfaced by
  # PR-92 retroactive audit (X1, X2, X3, X4, X5, X7, X8) — same shape
  # as the WAP-hardening "silent N/A" anti-pattern but on the doc-
  # navigation surface. Forward-only protection: scans the doc set
  # (cross-auditor.md + references/*.md + every skills/*/SKILL.md)
  # for `<file>.md` §<heading> pointers, asserts each resolves to a
  # real heading. Known residue (8 distinct anchors, 13 occurrences
  # across the doc set) is allowlisted; new dangling pointers and
  # stale-allowlist entries fail. Baseline=13 caps total occurrences.
  local out rc
  out=$(python3 tests/check_dangling_anchors.py --baseline 13 2>&1)
  rc=$?

  if [ "$rc" -ne 0 ]; then
    echo "dangling section-anchor pin failed (exit $rc):"
    printf '%s\n' "$out"
    return 1
  fi
  echo "no dangling §-anchor references beyond known residue (13 residue occurrences allowlisted)"
}

check_wap_inv2_no_drift_on_inline_code_in_paren() {
  # Regression pin for code-audit iter-2 X3: MALFORMED_PAREN_RE absorbed
  # backticks via `[^)]*`, causing false-positive DRIFT INV-2 on prose like
  # `(spec §6.1 parenthetical present but unparseable: `three expected_pass increments` (X6))`.
  # Fix strips inline-code spans before regex match. Pin asserts a
  # parenthetical wrapping only backticked content is NOT flagged malformed.

  local out rc
  out=$(python3 -c "
import sys; sys.path.insert(0, 'tests')
from workdoc_parity_check import parse_spec_61_parentheticals
from pathlib import Path
import tempfile, os
src = '# foo\n## 6.1 verification\n- **Step 1**: helper output reads (the literal \`expected_pass increment\` substring in backticks).\n'
f = tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False)
f.write(src); f.close()
r = parse_spec_61_parentheticals(Path(f.name)); os.unlink(f.name)
parens, malformed = r if isinstance(r, tuple) else (r, {})
assert 1 not in malformed, f'X3 regression: Step 1 falsely malformed: {malformed!r}'
assert 1 not in parens, f'unexpected paren match: {parens!r}'
print('OK no false DRIFT on inline-code parens')
" 2>&1)
  rc=$?

  [ "$rc" -eq 0 ] \
    || { echo "X3 regression: expected exit 0, got $rc; output: $out"; return 1; }
  printf '%s\n' "$out" | grep -qF "OK no false DRIFT on inline-code parens" \
    || { echo "missing OK marker; output: $out"; return 1; }

  echo "WAP MALFORMED_PAREN_RE pre-strips inline-code spans; no false DRIFT on backticked mentions"
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
  # range_spec parameter declaration lives in §Input on the hub; the diff-mode wording with
  # `git diff --name-only <range_spec>` lives in §Step 1 which moved to the codex-dispatch
  # reference per Spec 2a Step 5. The aggregate count must be ≥ 2 across both files.
  local agent='agents/cross-auditor.md'
  local agent_ref='agents/references/cross-auditor-codex-dispatch.md'
  test -f "$agent" || { echo "$agent missing"; return 1; }
  test -f "$agent_ref" || { echo "$agent_ref missing"; return 1; }
  grep -qF 'range_spec' "$agent" \
    || { echo "$agent missing 'range_spec' parameter declaration in §Input"; return 1; }
  grep -qF 'git diff --name-only <range_spec>' "$agent_ref" \
    || { echo "$agent_ref missing updated diff-mode wording with range_spec"; return 1; }
  # Verify range_spec appears at least twice across hub + ref (parameter declaration + diff-mode wording).
  local count
  count=$(( $(grep -cF 'range_spec' "$agent") + $(grep -cF 'range_spec' "$agent_ref") ))
  [ "$count" -ge 2 ] || { echo "agents/cross-auditor.md + ref together have only $count occurrence(s) of 'range_spec' (expected >= 2)"; return 1; }
  echo "agents/cross-auditor.md §Input + ref §Step 1 range_spec parameter (count=$count) and diff-mode wording both present"
}

check_codex_audit_dispatch_helper_positive() {
  local tmpdir tmpout stdout
  tmpdir=$(mktemp -d) || return 1
  tmpout=$(mktemp) || { rm -rf "$tmpdir"; return 1; }
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
  tmpstderr=$(mktemp) || return 1
  rc=0
  CODEX_BIN="$PLUGIN_ROOT/tests/fixtures/codex-audit-dispatch/mock_codex_fail.sh" bash hooks/lib/codex_audit_dispatch.sh /tmp /tmp/codex-noop.txt gpt-5.5 xhigh < /dev/null 2>"$tmpstderr" || rc=$?
  [ "$rc" = "2" ] || { echo "expected exit code 2, got $rc"; rm -f "$tmpstderr"; return 1; }
  grep -qF 'ERROR: codex unavailable' "$tmpstderr" || { echo "expected mock codex error in stderr"; rm -f "$tmpstderr"; return 1; }
  rm -f "$tmpstderr"
  echo "codex_audit_dispatch propagates mock codex exit code 2 and stderr"
}

check_codex_audit_dispatch_helper_arg_validation() {
  local tmpstderr rc
  tmpstderr=$(mktemp) || return 1
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

# Section-scoped (X3): the test-placement reconciliation instruction must be
# present in BOTH the `### Step 1 — Research` block AND the §5 Repo-convention
# enforcement paragraph. A global whole-file grep would pass green if only one
# surface carried the text — assert each surface independently.
check_feature_skill_test_placement_reconciliation() {
  local skill='skills/feature/SKILL.md'
  local step1 conv5
  step1=$(awk '/^### Step 1 — Research/{flag=1} /^### Step 2 —/{if (flag) exit} flag{print}' "$skill")
  echo "$step1" | grep -qE -- 'R5-R7|R5–R7|R7' \
    || { echo "$skill Step 1 reconciliation missing R5-R7/R7 reference"; return 1; }
  echo "$step1" | grep -qiE -- 'reconcile|reconciliation' \
    || { echo "$skill Step 1 reconciliation missing reconcile/reconciliation"; return 1; }
  echo "$step1" | grep -qF -- 'sibling' \
    || { echo "$skill Step 1 reconciliation missing sibling test-file token"; return 1; }
  echo "$step1" | grep -qiE -- 'convention shift|convention-shift' \
    || { echo "$skill Step 1 reconciliation missing convention shift token"; return 1; }
  echo "$step1" | grep -qF -- 'Log' \
    || { echo "$skill Step 1 reconciliation missing Log destination"; return 1; }

  conv5=$(awk '/^\*\*Repo-convention enforcement in §5\*\*:/{flag=1} flag{print} flag && /^$/{exit}' "$skill")
  [ -n "$conv5" ] || { echo "$skill §5 Repo-convention enforcement paragraph not found"; return 1; }
  echo "$conv5" | grep -qE -- 'R7' \
    || { echo "$skill §5 Repo-convention paragraph missing R7-wins requirement"; return 1; }
  echo "$conv5" | grep -qF -- 'sibling' \
    || { echo "$skill §5 Repo-convention paragraph missing sibling-path-in-allowed_scope requirement"; return 1; }
  echo "$conv5" | grep -qF -- 'allowed_scope' \
    || { echo "$skill §5 Repo-convention paragraph missing allowed_scope requirement"; return 1; }
  echo "$conv5" | grep -qiE -- 'convention shift|convention-shift' \
    || { echo "$skill §5 Repo-convention paragraph missing convention-shift Log requirement"; return 1; }
  echo "$conv5" | grep -qF -- 'Log' \
    || { echo "$skill §5 Repo-convention paragraph missing §7 Log destination"; return 1; }
  echo "feature SKILL test-placement reconciliation present in Step 1 AND §5 (R7 wins, sibling in allowed_scope, convention-shift Log)"
}

check_cross_auditor_spec_mode_repo_convention_rule() {
  local agent='agents/references/cross-auditor-mode-focus.md'
  local section
  section=$(awk '/^### `spec` mode/{flag=1} /^<!-- end §spec mode -->/{if (flag) exit} flag{print}' "$agent")
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

# Section-scoped: the NEW weaker-than-R7 rule must live in the `### `spec` mode`
# section and be distinct from the line-47 Repo-convention enforcement bullet.
# Anchors: R7, trivial exception (or the <~40/<~200 thresholds), inline, and at
# least one named weaker-shape token (pure helpers / category / #[cfg(test)] mod
# tests). De-fuzzes against paraphrase per spec §3.2.3.
check_cross_auditor_spec_mode_flags_weaker_r7_conventions() {
  local agent='agents/references/cross-auditor-mode-focus.md'
  local section
  section=$(awk '/^### `spec` mode/{flag=1} /^<!-- end §spec mode -->/{if (flag) exit} flag{print}' "$agent")
  echo "$section" | grep -qF 'Weaker-than-R7' \
    || { echo "$agent spec mode missing Weaker-than-R7 test-placement rule"; return 1; }
  echo "$section" | grep -qF 'R7' \
    || { echo "$agent spec mode weaker-R7 rule missing R7 reference"; return 1; }
  echo "$section" | grep -qE -- 'trivial exception|<~40|<~200' \
    || { echo "$agent spec mode weaker-R7 rule missing trivial-exception threshold"; return 1; }
  echo "$section" | grep -qF 'inline' \
    || { echo "$agent spec mode weaker-R7 rule missing inline token"; return 1; }
  echo "$section" | grep -qE -- 'pure helpers|category|#\[cfg\(test\)\] mod tests' \
    || { echo "$agent spec mode weaker-R7 rule missing a named weaker-shape token"; return 1; }
  echo "cross-auditor spec mode flags weaker-than-R7 test-placement conventions"
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
  local agent_ref='agents/references/cross-auditor-codex-dispatch.md'
  local tools_line step1 count line5

  test -f "$agent" || { echo "$agent missing"; return 1; }
  test -f "$agent_ref" || { echo "$agent_ref missing"; return 1; }

  tools_line=$(grep -F 'tools:' "$agent" | head -1)
  echo "$tools_line" | grep -qF 'BashOutput' \
    || { echo "$agent tools frontmatter missing BashOutput"; return 1; }
  echo "$tools_line" | grep -qF 'KillShell' \
    || { echo "$agent tools frontmatter missing KillShell"; return 1; }
  if echo "$tools_line" | grep -qF 'mcp__codex__codex'; then
    echo "$agent tools frontmatter still contains mcp__codex__codex"
    return 1
  fi

  # §Codex dispatch H2 byte-exact preserved as pointer-stub in hub per Spec 2a §3.5 X3.
  count=$(grep -cF '## Codex dispatch (background CLI + polling)' "$agent")
  [ "$count" -ge 1 ] \
    || { echo "$agent missing Codex dispatch background CLI section pointer-stub H2"; return 1; }

  # §Step 1 body content moved to agents/references/cross-auditor-codex-dispatch.md per Spec 2a Step 5.
  # End-bound is the sentinel '<!-- end §Step 1 -->' placed at end of §Step 1 in the reference file.
  step1=$(awk '/^## Step 1:/{flag=1} flag && /^<!-- end §Step 1 -->/{exit} flag{print}' "$agent_ref")
  echo "$step1" | grep -qF 'codex_audit_dispatch.sh' \
    || { echo "$agent_ref §Step 1 missing codex_audit_dispatch.sh"; return 1; }
  echo "$step1" | grep -qF 'run_in_background' \
    || { echo "$agent_ref §Step 1 missing run_in_background"; return 1; }

  # BashOutput body count moves to ref (frontmatter `tools:` line on hub still has BashOutput).
  count=$(grep -cF 'BashOutput' "$agent_ref")
  [ "$count" -ge 2 ] \
    || { echo "$agent_ref missing BashOutput in body (count=$count, expected >= 2)"; return 1; }

  local model_line effort_line
  model_line=$(grep -nF 'model: opus' "$agent" | head -1 | cut -d: -f1)
  effort_line=$(grep -nF 'effort: xhigh' "$agent" | head -1 | cut -d: -f1)
  [ -n "$model_line" ] || { echo "$agent missing 'model: opus' in frontmatter"; return 1; }
  [ -n "$effort_line" ] || { echo "$agent missing 'effort: xhigh' in frontmatter"; return 1; }
  [ "$effort_line" = "$((model_line + 1))" ] \
    || { echo "$agent 'effort: xhigh' must immediately follow 'model: opus' (model@$model_line, effort@$effort_line)"; return 1; }

  # Fail-open wording lives in §Codex dispatch + §Step 1 result paragraph — both moved to ref.
  count=$(grep -cF 'codex_audit_dispatch.sh exits non-zero' "$agent_ref")
  [ "$count" -ge 1 ] \
    || { echo "$agent_ref fail-open wording missing codex_audit_dispatch.sh exits non-zero"; return 1; }

  if grep -qF 'mcp__codex__codex' "$agent"; then
    echo "$agent still contains mcp__codex__codex"
    return 1
  fi
  if grep -qF 'mcp__codex__codex' "$agent_ref"; then
    echo "$agent_ref still contains mcp__codex__codex"
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

check_cross_auditor_model_attestation_contract() {
  local agent='agents/cross-auditor.md'
  local handshake='agents/references/cross-auditor-evidence-handshake.md'
  local outfmt='agents/references/cross-auditor-output-format.md'
  # (a) cross-auditor frontmatter pins the Claude model (Opus during the Fable
  #     global outage — see project_fable_global_outage; revert to fable when back).
  grep -qF 'model: opus' "$agent" \
    || { echo "$agent missing 'model: opus' in frontmatter (Fable outage override → Opus)"; return 1; }
  # (b) handshake doc carries the claude_model emit rule: sentinel-adjacency
  #     ('immediately preceding'), 'unknown' fallback, and system-prompt source.
  grep -qF 'immediately preceding' "$handshake" \
    || { echo "$handshake missing 'immediately preceding' (spec-mode claude_model sentinel-adjacency rule)"; return 1; }
  grep -qF 'claude_model: unknown' "$handshake" \
    || { echo "$handshake missing 'claude_model: unknown' fallback in attestation contract"; return 1; }
  grep -qF 'system prompt' "$handshake" \
    || { echo "$handshake missing system-prompt-source clause in attestation contract"; return 1; }
  # (c) output-format findings.md template carries the claude_model: frontmatter key.
  grep -qF 'claude_model:' "$outfmt" \
    || { echo "$outfmt findings.md template missing 'claude_model:' frontmatter key"; return 1; }
  # (d) the canonical spaced sentinel literal count in the handshake doc stays exactly 1
  #     (only the fenced template may carry it; mid-prose references use obfuscated forms).
  local ca_sent
  ca_sent=$(grep -cF '# CROSS-AUDIT EVIDENCE FOOTER' "$handshake")
  [ "$ca_sent" = "1" ] \
    || { echo "$handshake canonical-spaced sentinel literal must appear EXACTLY ONCE (got $ca_sent) — attestation prose must use obfuscated forms"; return 1; }
  echo "cross-auditor model-attestation contract OK (model: opus; claude_model emit rule + output-format key; sentinel count==1)"
}

# schema: the audited_head pin (spec 2026-07-05-audited-head-terminal-evidence-gates
# §3.2) is emitted into the findings.md frontmatter template, sibling of claude_model.
# Catches a defect where the emit target is dropped/renamed — the orchestrator hand-off
# gate then has no `audited_head:` to read and the stale-audit bypass reopens silently.
check_cross_auditor_audited_head_template() {
  local outfmt='agents/references/cross-auditor-output-format.md'
  test -f "$outfmt" || { echo "$outfmt missing"; return 1; }
  # (a) findings.md frontmatter template carries the audited_head: key (the emit
  #     target the /feature hand-off gate reads).
  grep -qE '^audited_head: ' "$outfmt" \
    || { echo "$outfmt findings.md template missing '^audited_head: ' frontmatter key"; return 1; }
  # (b) claude_model: sibling still present — the pin mirrors it 1:1; if the sibling
  #     vanished the mirror invariant this contract depends on is broken.
  grep -qF 'claude_model:' "$outfmt" \
    || { echo "$outfmt findings.md template missing sibling 'claude_model:' key"; return 1; }
  # (c) emit-contract note names the file-backed-only + non-git omission rules so a
  #     reader of the unconditional template line knows the key is conditional.
  grep -qF 'Non-git carve-out' "$outfmt" \
    || { echo "$outfmt missing 'Non-git carve-out' clause in audited_head emit contract"; return 1; }
  echo "cross-auditor audited_head template OK (frontmatter key present; claude_model sibling; non-git carve-out noted)"
}

# prompt-text: the §Audited-HEAD attestation contract section in the handshake doc
# documents the five load-bearing clauses of the emit contract. Each grep guards a
# distinct drift: dropping the file-backed-only clause would make the cross-auditor
# emit in spec/decision (footer migration); dropping the non-git carve-out would
# false-fire HEAD_ATTESTATION_MISSING on non-git in-place runs; dropping the
# no-shape-validation clause invites a spurious oid validator.
check_cross_auditor_audited_head_handshake() {
  local handshake='agents/references/cross-auditor-evidence-handshake.md'
  test -f "$handshake" || { echo "$handshake missing"; return 1; }
  # (a) the Audited-HEAD attestation contract section exists.
  grep -qF '### Audited-HEAD attestation contract' "$handshake" \
    || { echo "$handshake missing '### Audited-HEAD attestation contract' section"; return 1; }
  # (b) channel restriction: file-backed modes only.
  grep -qF 'file-backed modes ONLY' "$handshake" \
    || { echo "$handshake audited_head contract missing 'file-backed modes ONLY' channel clause"; return 1; }
  # (c) source of truth: git rev-parse HEAD in the audit workspace.
  grep -qF 'git rev-parse HEAD' "$handshake" \
    || { echo "$handshake audited_head contract missing 'git rev-parse HEAD' source-of-truth clause"; return 1; }
  # (d) spec/decision footer stays byte-identical (zero-migration asymmetry vs claude_model).
  grep -qF 'three-line footer stays byte-identical' "$handshake" \
    || { echo "$handshake audited_head contract missing spec/decision 'three-line footer stays byte-identical' untouched clause"; return 1; }
  # (e) non-git carve-out: pin OMITTED when workspace is not a git repo.
  grep -qF 'OMITTED from the frontmatter' "$handshake" \
    || { echo "$handshake audited_head contract missing non-git 'OMITTED from the frontmatter' carve-out"; return 1; }
  # (f) no value-shape validation (mirror of claude_model).
  grep -qF 'No value-shape validation' "$handshake" \
    || { echo "$handshake audited_head contract missing 'No value-shape validation' mirror clause"; return 1; }
  echo "cross-auditor audited_head handshake contract OK (section + file-backed-only + rev-parse source + byte-identical footer + non-git omission + no-shape-validation)"
}

# prompt-text: the §Rules-loaded attestation contract section in the handshake doc
# (spec 2026-07-05-degraded-run-rules-gate §3.1) documents the machine channel for the
# degraded-rules gate. Each grep guards a distinct drift: dropping the file-backed
# security/full-only channel clause would make the cross-auditor emit rules_loaded in
# logic/spec/decision (false MISSING fires); dropping the resolver-exit-3 truth-table
# row would lose the unreachable-file degraded case; dropping the MISSING-routing clause
# would let a malformed token silent-pass — the exact fail-open this spec closes.
check_cross_auditor_rules_loaded_handshake() {
  local handshake='agents/references/cross-auditor-evidence-handshake.md'
  test -f "$handshake" || { echo "$handshake missing"; return 1; }
  # (a) the Rules-loaded attestation contract section exists.
  grep -qF '### Rules-loaded attestation contract' "$handshake" \
    || { echo "$handshake missing '### Rules-loaded attestation contract' section"; return 1; }
  # (b) channel restriction: file-backed security/full only (loader-bearing modes).
  grep -qF 'file-backed `security`/`full` ONLY' "$handshake" \
    || { echo "$handshake rules_loaded contract missing 'file-backed security/full ONLY' channel clause"; return 1; }
  # (c) truth-table degraded row: resolver exit 3 unreachable → false + reason.
  grep -qF 'code-quality-rules.md not reachable' "$handshake" \
    || { echo "$handshake rules_loaded truth table missing 'code-quality-rules.md not reachable' (resolver exit 3 → false) row"; return 1; }
  # (d) MISSING-routing: a malformed token routes to the gate as MISSING, never a silent pass.
  grep -qF 'routes to the rules gate as MISSING' "$handshake" \
    || { echo "$handshake rules_loaded contract missing 'routes to the rules gate as MISSING' (never-silent-pass) clause"; return 1; }
  echo "cross-auditor rules_loaded handshake contract OK (section + file-backed-security/full-only + resolver-exit-3 row + MISSING-never-silent)"
}

# prompt-text: the three-way project_type branch in the codex-dispatch doc (spec §3.5)
# reworks the loader from allowlist/unset two-way to allowlist / explicit-none / unset-or-other.
# Guards: the declared-`none` branch bullet + its informational H1 bullet literal must exist
# (else `none` falls through to the degraded catch-all → the X1 100%-gate-on-typeless failure);
# both rules_loaded truth values must be wired into the attestation emit; the resolver-exit-3
# row must attest false with the reachability reason; and the pre-existing pinned unset-branch
# literal must stay byte-exact (the `none` branch is inserted as a separate PRECEDING bullet,
# never an infix edit of the pinned literal — semantics hold via branch ordering).
check_cross_auditor_rules_loaded_dispatch() {
  local f='agents/references/cross-auditor-codex-dispatch.md'
  test -f "$f" || { echo "$f missing"; return 1; }
  # (a) three-way branch: the explicit-none branch bullet precedes the unset catch-all.
  grep -qF 'If `project_type` is explicitly `none`' "$f" \
    || { echo "$f missing explicit-none project_type branch bullet"; return 1; }
  # (b) the none-declared informational bullet literal emitted at the H1 location.
  #     `--` ends option parsing so the leading '- ' bullet dash is taken literally.
  grep -qF -- '- R-rule cluster: all-scope (project_type=none declared)' "$f" \
    || { echo "$f missing '- R-rule cluster: all-scope (project_type=none declared)' none-declared bullet literal"; return 1; }
  # (c) attestation emit covers both truth values.
  grep -qF 'rules_loaded: true' "$f" \
    || { echo "$f missing 'rules_loaded: true' attestation emit branch"; return 1; }
  grep -qF 'rules_loaded: false' "$f" \
    || { echo "$f missing 'rules_loaded: false' attestation emit branch"; return 1; }
  # (d) resolver exit 3 unreachable row wired into the attestation emit with the reachability reason.
  grep -qF "rules_reason: 'code-quality-rules.md not reachable'" "$f" \
    || { echo "$f missing resolver-exit-3 rules_reason 'code-quality-rules.md not reachable' attestation row"; return 1; }
  # (e) pin-preservation: the unset-branch pinned literal stays byte-exact (branch ordering keeps semantics).
  grep -qF 'If `project_type` is unset OR has a non-allowlist value' "$f" \
    || { echo "$f pinned unset-branch literal 'If \`project_type\` is unset OR has a non-allowlist value' missing"; return 1; }
  echo "cross-auditor rules_loaded dispatch OK (three-way branch + none-declared bullet + true/false attestation + exit-3 row + pinned unset literal preserved)"
}

# prompt-text: the findings.md frontmatter template in the output-format doc (spec §3.5)
# gains the rules_loaded: machine-channel key (sibling of audited_head) + emit-contract note.
# Guards: dropping the frontmatter key removes the machine channel the /feature + standalone
# gates read; the audited_head sibling must remain (1:1 placement mirror); the emit-contract
# note must name the security/full-only scope + machine-channel-beside-human-bullet semantics.
check_cross_auditor_rules_loaded_template() {
  local outfmt='agents/references/cross-auditor-output-format.md'
  test -f "$outfmt" || { echo "$outfmt missing"; return 1; }
  # (a) findings.md frontmatter template carries the rules_loaded: key (sibling of audited_head).
  grep -qE '^rules_loaded: ' "$outfmt" \
    || { echo "$outfmt findings.md template missing '^rules_loaded: ' frontmatter key"; return 1; }
  # (b) audited_head: sibling still present — the pin mirrors it 1:1 in placement.
  grep -qE '^audited_head: ' "$outfmt" \
    || { echo "$outfmt findings.md template missing sibling '^audited_head: ' key"; return 1; }
  # (c) emit-contract note names the machine-channel-beside-human-bullet + security/full-only scope.
  grep -qF 'Rules-loaded pin emit contract' "$outfmt" \
    || { echo "$outfmt missing 'Rules-loaded pin emit contract' note"; return 1; }
  echo "cross-auditor rules_loaded template OK (frontmatter key + audited_head sibling + emit-contract note)"
}

# --- /feature audited-HEAD + terminal-evidence gates (spec
#     2026-07-05-audited-head-terminal-evidence-gates §3.2/§3.3, Step 4) ---

# prompt-text: the hand-off audited-HEAD gate (§3.2 #2) runs BEFORE the 4-option
# menu. Drops here would reopen the stale-audit bypass: a missing compare step
# lets fix commits after the last audit round ship unverified; a missing accept
# directive / re-audit option / zero-diff carve-out either makes the gate silent
# (violates #149 "never a silent pass") or fires it on a legit zero-diff skip.
check_feature_handoff_audited_head_gate() {
  local skill='skills/feature/SKILL.md'
  test -f "$skill" || { echo "$skill missing"; return 1; }
  # (a) compare step: named gate reading audited_head from the findings doc.
  grep -qF 'Audited-HEAD gate (before the 4-option menu)' "$skill" \
    || { echo "$skill missing hand-off 'Audited-HEAD gate (before the 4-option menu)' step"; return 1; }
  grep -qF '<slug>-code-findings.md' "$skill" \
    || { echo "$skill hand-off gate missing the '<slug>-code-findings.md' read source"; return 1; }
  # (b) banner: never-silent — accept directive (grep target of failing_test_cmd)
  #     + re-audit option.
  grep -qF 'audited-head mismatch accepted — audited=<oid|absent> head=<oid>: <reason>' "$skill" \
    || { echo "$skill hand-off gate missing the accept-with-justification Log directive"; return 1; }
  grep -qF 'Re-audit the delta' "$skill" \
    || { echo "$skill hand-off gate missing the 'Re-audit the delta' banner option"; return 1; }
  # (c) zero-diff carve-out: skip SILENTLY when no audit ran.
  grep -qF 'skip the gate SILENTLY' "$skill" \
    || { echo "$skill hand-off gate missing the zero-diff 'skip the gate SILENTLY' carve-out"; return 1; }
  echo "feature hand-off audited-HEAD gate OK (compare step + read source + accept directive + re-audit option + zero-diff carve-out)"
}

# prompt-text: the `code audit passed` Log marker (§3.2 marker extension) gains a
# trailing `; audited_head=<oid>` COPIED from the findings frontmatter, NOT
# re-derived at marker-write time. A drop of the template arm decouples the marker
# from the pinned oid; a drop of the copy rule invites a git rev-parse re-derive
# that would pin the wrong (marker-write-time) HEAD.
check_feature_code_audit_marker_audited_head() {
  local skill='skills/feature/SKILL.md'
  test -f "$skill" || { echo "$skill missing"; return 1; }
  grep -qF 'evidence=<value>; blockers=[...]; audited_head=<oid>' "$skill" \
    || { echo "$skill missing extended 'code audit passed' marker template with '; audited_head=<oid>'"; return 1; }
  grep -qF 'COPIED from the findings-frontmatter' "$skill" \
    || { echo "$skill marker oid-copy rule missing 'COPIED from the findings-frontmatter'"; return 1; }
  grep -qF 'NOT re-derived via' "$skill" \
    || { echo "$skill marker oid-copy rule missing 'NOT re-derived via' git rev-parse clause"; return 1; }
  echo "feature code-audit marker audited_head extension OK (template arm + oid-copy rule)"
}

# prompt-text: classifier callsites 2/3/4 (code-audit spawns) pass --expected-head;
# the spec-mode callsite 1 must NOT (the file-backed-only asymmetry — else every
# clean spec-audit run false-fires HEAD_ATTESTATION_MISSING); and head_gate never
# consumes the shared transport-retry budget (its re-audit banner option IS the
# retry — a semantic iteration, not a transport attempt).
check_feature_classifier_expected_head_callsites() {
  local skill='skills/feature/SKILL.md'
  test -f "$skill" || { echo "$skill missing"; return 1; }
  # (a) --expected-head invocation present at the code-audit callsites.
  grep -qF -- '--expected-head "$(git rev-parse HEAD)"' "$skill" \
    || { echo "$skill missing '--expected-head \"\$(git rev-parse HEAD)\"' classifier invocation"; return 1; }
  # (b) code/full-only restriction (callsites 2/3/4).
  grep -qF 'for code/full mode ONLY (callsites 2/3/4' "$skill" \
    || { echo "$skill missing the code/full-only (callsites 2/3/4) --expected-head restriction"; return 1; }
  # (c) callsite-1 (spec mode) absence.
  grep -qF 'the spec-mode callsite 1 passes NO head channel' "$skill" \
    || { echo "$skill missing the spec-mode callsite-1 'NO head channel' clause"; return 1; }
  # (d) no-transport-retry clause.
  grep -qF 'NEVER consumes the shared §3.5b-1 one-transport-retry budget' "$skill" \
    || { echo "$skill §3.5b-2f missing the head_gate no-transport-retry clause"; return 1; }
  echo "feature classifier --expected-head callsites OK (2/3/4 present + callsite-1 absent + no-transport-retry)"
}

# prompt-text: the §3.5b-2g degraded-rules gate is the machine gate #151 adds — a
# rules-not-loaded audit must NOT be recorded as a clean pass without explicit,
# logged user acceptance. Dropping the section heading removes the gate entirely
# (fail-open reopens); dropping either gate value collapses the two degradation
# shapes (attested-false vs absent/malformed) into a silent pass; dropping the
# no-auto-proceed clause invites an identical-params transport retry against the
# same broken environment; dropping the Log grammar loses the honest audit-trail
# record of every firing + chosen action.
check_feature_degraded_rules_gate() {
  local skill='skills/feature/SKILL.md'
  test -f "$skill" || { echo "$skill missing"; return 1; }
  # (a) section heading.
  grep -qF '##### 3.5b-2g Degraded-rules gate' "$skill" \
    || { echo "$skill missing the '##### 3.5b-2g Degraded-rules gate' section heading"; return 1; }
  # (b) both gate values.
  grep -qF 'RULES_NOT_LOADED' "$skill" \
    || { echo "$skill §3.5b-2g missing the RULES_NOT_LOADED gate value"; return 1; }
  grep -qF 'RULES_ATTESTATION_MISSING' "$skill" \
    || { echo "$skill §3.5b-2g missing the RULES_ATTESTATION_MISSING gate value"; return 1; }
  # (c) no-auto-proceed clause (environment condition — no identical-params retry).
  grep -qF 'No transport-retry, no auto-retry, NO auto-proceed' "$skill" \
    || { echo "$skill §3.5b-2g missing the 'No transport-retry, no auto-retry, NO auto-proceed' clause"; return 1; }
  # (d) banner option 1 (fix-environment-and-re-spawn — never a silent proceed).
  grep -qF 'Fix environment and re-spawn' "$skill" \
    || { echo "$skill §3.5b-2g missing the 'Fix environment and re-spawn' banner option"; return 1; }
  # (e) Log grammar literal (every firing AND chosen action).
  grep -qF -- '- YYYY-MM-DD: rules_gate — <value>; reason=<rules_reason|absent>; iter=<N>; action=<respawn|accepted|stopped>' "$skill" \
    || { echo "$skill §3.5b-2g missing the rules_gate Log grammar literal"; return 1; }
  echo "feature §3.5b-2g degraded-rules gate OK (heading + both values + no-auto-proceed + banner option 1 + Log grammar)"
}

# prompt-text: the §3.5b-2 step-4 exit-0 chain evaluates rules_gate FOURTH, after
# policy/model/head, and PROCEED requires all four null. Dropping the FOURTH-position
# literal drops rules_gate from the consumption chain (a non-null rules_gate would
# never be acted on → the audit proceeds degraded); dropping the all-four-null
# PROCEED literal decouples the proceed decision from the rules gate.
check_feature_exit0_chain_rules_fourth() {
  local skill='skills/feature/SKILL.md'
  test -f "$skill" || { echo "$skill missing"; return 1; }
  # (a) FOURTH-position chain literal.
  grep -qF 'per §3.5b-2g (rules_gate FOURTH)' "$skill" \
    || { echo "$skill exit-0 chain missing 'per §3.5b-2g (rules_gate FOURTH)'"; return 1; }
  # (b) all-four-null PROCEED literal (rules_gate: null is the last gate before PROCEED).
  grep -qF '`rules_gate: null` → **PROCEED**' "$skill" \
    || { echo "$skill exit-0 chain missing the '\`rules_gate: null\` → **PROCEED**' terminal"; return 1; }
  echo "feature exit-0 chain rules_gate-FOURTH OK (chain literal + all-four-null PROCEED)"
}

# prompt-text: classifier callsites 2/3/4 (code-audit spawns) pass
# --require-rules-loaded (feature code audits are mode: full — the R-rule loader
# always runs); the spec-mode callsite 1 passes NEITHER --expected-head NOR
# --require-rules-loaded (both are code/full-only — else a clean spec-audit run
# false-fires RULES_ATTESTATION_MISSING against an inline channel that carries no
# rules keys). Dropping the flag at any code-audit callsite reopens the fail-open
# (a degraded run is never gated); dropping the callsite-1 asymmetry clause invites
# passing the flag in spec mode.
check_feature_classifier_require_rules_callsites() {
  local skill='skills/feature/SKILL.md'
  test -f "$skill" || { echo "$skill missing"; return 1; }
  # (a) flag present at all.
  grep -qF -- '--require-rules-loaded' "$skill" \
    || { echo "$skill missing the '--require-rules-loaded' classifier flag"; return 1; }
  # (b) callsite 2 invocation carries it adjacent to --expected-head.
  grep -qF -- '--expected-head "$(git rev-parse HEAD)" --require-rules-loaded' "$skill" \
    || { echo "$skill callsite-2 invocation missing '--expected-head \"\$(git rev-parse HEAD)\" --require-rules-loaded'"; return 1; }
  # (c) callsite 3 prose carries it.
  grep -qF -- '`--require-rules-loaded` (callsite 3)' "$skill" \
    || { echo "$skill callsite-3 prose missing the '--require-rules-loaded (callsite 3)' clause"; return 1; }
  # (d) callsite 4 prose carries it.
  grep -qF -- '`--require-rules-loaded` (callsite 4)' "$skill" \
    || { echo "$skill callsite-4 prose missing the '--require-rules-loaded (callsite 4)' clause"; return 1; }
  # (e) callsite-1 asymmetry: spec mode passes neither flag.
  grep -qF 'spec-mode callsite 1 passes neither' "$skill" \
    || { echo "$skill missing the spec-mode callsite-1 'passes neither' asymmetry clause"; return 1; }
  echo "feature classifier --require-rules-loaded callsites OK (2/3/4 present + callsite-1 passes-neither asymmetry)"
}

# prompt-text: the §3.4a terminal-evidence refusal (§3.3) asserts BOTH audit-evidence
# keys are present with a 5-enum value before any SHIPPED/VERIFIED write; absent /
# literal-null / off-enum → never flip. Dropping any of {both keys, the 5-enum, the
# three defect shapes, the never-flip rule} reopens the silent-bypass class (#150).
check_feature_terminal_evidence_refusal() {
  local skill='skills/feature/SKILL.md'
  test -f "$skill" || { echo "$skill missing"; return 1; }
  grep -qF 'Terminal-evidence precondition (before any' "$skill" \
    || { echo "$skill §3.4a missing 'Terminal-evidence precondition (before any' status write"; return 1; }
  # both keys named.
  grep -qF 'spec_audit_evidence:' "$skill" \
    || { echo "$skill §3.4a refusal missing 'spec_audit_evidence:' key"; return 1; }
  grep -qF 'code_audit_evidence:' "$skill" \
    || { echo "$skill §3.4a refusal missing 'code_audit_evidence:' key"; return 1; }
  # 5-value enum.
  grep -qF '{dual_model, single_model, self_fallback, contract_violated, skipped}' "$skill" \
    || { echo "$skill §3.4a refusal missing the 5-value evidence enum"; return 1; }
  # three defect shapes.
  grep -qF 'absent / literal-null / off-enum' "$skill" \
    || { echo "$skill §3.4a refusal missing the three defect shapes 'absent / literal-null / off-enum'"; return 1; }
  # never-flip.
  grep -qF 'Never flip with absent keys.' "$skill" \
    || { echo "$skill §3.4a refusal missing the 'Never flip with absent keys.' rule"; return 1; }
  echo "feature §3.4a terminal-evidence refusal OK (both keys + 5-enum + three defect shapes + never-flip)"
}

# prompt-text: Verify mode gets the SAME terminal-evidence assertion as a precondition
# before its status: VERIFIED flip (§3.3 second site). Without it, a /feature verify
# on an evidence-less SHIPPED spec would silently reach VERIFIED — the exact incident
# class the §3.4a gate closes on the hand-off path.
check_feature_verify_terminal_evidence_precondition() {
  local skill='skills/feature/SKILL.md'
  test -f "$skill" || { echo "$skill missing"; return 1; }
  grep -qF 'terminal-evidence precondition first' "$skill" \
    || { echo "$skill Verify mode missing 'terminal-evidence precondition first' before the VERIFIED flip"; return 1; }
  echo "feature Verify-mode terminal-evidence precondition OK (asserted before the VERIFIED flip)"
}

# prompt-text: standalone /cross-audit audited-HEAD wiring (spec
# 2026-07-05-audited-head-terminal-evidence-gates §3.2 "Standalone — file-backed
# modes ONLY", Step 5). Six load-bearing clauses. Dropping the Phase 3 render line
# hides the attested HEAD from the user; dropping the file-backed-only restriction
# or the spec/decision abstention makes standalone pass --expected-head on spec/
# decision runs (false HEAD_ATTESTATION_MISSING on every clean run); dropping the
# non-git skip false-fires on non-git in-place runs; dropping the no-transport-retry
# clause lets head_gate burn the shared retry budget; dropping the workdoc
# persistence line loses the only POST-action record of the chosen gate action.
check_cross_audit_standalone_audited_head() {
  local skill='skills/cross-audit/SKILL.md'
  test -f "$skill" || { echo "$skill missing"; return 1; }
  # (a) Phase 3 render line, file-backed modes only.
  grep -qF 'Audited HEAD: <oid>' "$skill" \
    || { echo "$skill missing the Phase 3 'Audited HEAD: <oid>' render line"; return 1; }
  grep -qF 'file-backed modes ONLY' "$skill" \
    || { echo "$skill missing the '--expected-head' file-backed-modes-ONLY restriction"; return 1; }
  # (b) spec/decision abstention (the file-backed-only asymmetry vs --expected-claude-model).
  grep -qF 'standalone runs (`--mode spec`) NEVER pass' "$skill" \
    || { echo "$skill missing the spec/decision 'NEVER pass --expected-head' abstention clause"; return 1; }
  # (c) non-git in-place skip.
  grep -qF 'Non-git in-place file-backed runs likewise SKIP' "$skill" \
    || { echo "$skill missing the non-git in-place '--expected-head' skip clause"; return 1; }
  # (d) head_gate never consumes the transport-retry budget.
  grep -qF 'NEVER consumes the shared §3.5b-2b transport-retry budget' "$skill" \
    || { echo "$skill missing the head_gate no-transport-retry clause"; return 1; }
  # (e) standalone audited-HEAD gate banner present (re-audit / accept / stop).
  grep -qF 'Standalone audited-HEAD gate banner' "$skill" \
    || { echo "$skill missing the '#### Standalone audited-HEAD gate banner' section"; return 1; }
  # (f) workdoc persistence line (mirror of the model-gate rule — no new sidecar field).
  grep -qF 'Audited HEAD: <audited_head|absent> vs <expected>' "$skill" \
    || { echo "$skill missing the audited-HEAD workdoc persistence line"; return 1; }
  grep -qF 'no new sidecar field — mirror of the model-gate rule' "$skill" \
    || { echo "$skill missing the 'no new sidecar field — mirror of the model-gate rule' persistence clause"; return 1; }
  echo "cross-audit standalone audited-HEAD OK (Phase 3 render + file-backed-only + spec/decision abstain + non-git skip + no-transport-retry + banner + workdoc persistence)"
}

# prompt-text: standalone /cross-audit passes --require-rules-loaded for security/full
# modes ONLY — NARROWER than --expected-head (spec 2026-07-05-degraded-run-rules-gate
# §3.4). The R-rule cluster loader runs only in security/full, so logic NEVER passes
# the flag (else every clean logic audit false-fires RULES_ATTESTATION_MISSING); spec/
# decision never pass it either. Dropping the security/full-only header lets the flag
# leak onto logic/spec/decision runs (false-fire on clean audits); dropping the
# logic-never clause reopens the false-fire class; dropping the spec/decision-never
# clause passes the flag against the inline channel that carries no rules keys.
check_cross_audit_standalone_require_rules() {
  local skill='skills/cross-audit/SKILL.md'
  test -f "$skill" || { echo "$skill missing"; return 1; }
  # (a) flag present at all.
  grep -qF -- '--require-rules-loaded' "$skill" \
    || { echo "$skill missing the '--require-rules-loaded' classifier flag"; return 1; }
  # (b) security/full-only header, narrower than --expected-head.
  grep -qF 'standalone `security`/`full` modes ONLY (NARROWER than `--expected-head`)' "$skill" \
    || { echo "$skill missing the '--require-rules-loaded' security/full-only (NARROWER than --expected-head) header"; return 1; }
  # (c) logic-never clause (loader runs only in security/full).
  grep -qF 'false-fire `RULES_ATTESTATION_MISSING` on every clean logic audit' "$skill" \
    || { echo "$skill missing the logic-never 'false-fire RULES_ATTESTATION_MISSING on every clean logic audit' clause"; return 1; }
  # (d) spec/decision-never clause.
  grep -qF 'standalone runs (`--mode spec`) never pass it either' "$skill" \
    || { echo "$skill missing the spec/decision 'never pass it either' abstention clause"; return 1; }
  echo "cross-audit standalone --require-rules-loaded OK (flag + security/full-only header + logic-never + spec/decision-never)"
}

# prompt-text: standalone degraded-rules gate banner (spec §3.4) — the machine gate
# #151 adds to standalone /cross-audit. Dropping the section heading removes the gate
# entirely (fail-open reopens); dropping either gate value collapses the two
# degradation shapes (attested-false vs absent/malformed) into a silent pass; dropping
# the Fix-environment option loses the semantic-iteration recovery path (leaving only
# accept/stop); dropping the no-new-sidecar-field persistence clause invites an
# unimplementable post-seal sidecar write; dropping the workdoc line loses the only
# POST-action record of the chosen gate action.
check_cross_audit_standalone_degraded_rules_banner() {
  local skill='skills/cross-audit/SKILL.md'
  test -f "$skill" || { echo "$skill missing"; return 1; }
  # (a) banner section heading.
  grep -qF '#### Standalone degraded-rules gate banner' "$skill" \
    || { echo "$skill missing the '#### Standalone degraded-rules gate banner' section"; return 1; }
  # (b) both gate values.
  grep -qF 'RULES_NOT_LOADED' "$skill" \
    || { echo "$skill degraded-rules banner missing the RULES_NOT_LOADED gate value"; return 1; }
  grep -qF 'RULES_ATTESTATION_MISSING' "$skill" \
    || { echo "$skill degraded-rules banner missing the RULES_ATTESTATION_MISSING gate value"; return 1; }
  # (c) Fix-environment banner option.
  grep -qF 'Fix environment and re-audit' "$skill" \
    || { echo "$skill degraded-rules banner missing the 'Fix environment and re-audit' option"; return 1; }
  # (d) no-new-sidecar-field persistence clause (mirror of the head-gate rule).
  grep -qF 'no new sidecar field — mirror of the head-gate rule' "$skill" \
    || { echo "$skill degraded-rules banner missing the 'no new sidecar field — mirror of the head-gate rule' persistence clause"; return 1; }
  # (e) workdoc POST-action persistence line (literal starts with '- ' → -- guard).
  grep -qF -- '- Rules loaded: <rules_loaded|absent> (reason=<rules_reason|absent>)' "$skill" \
    || { echo "$skill degraded-rules banner missing the workdoc '- Rules loaded:' persistence line"; return 1; }
  echo "cross-audit standalone degraded-rules gate banner OK (heading + both values + Fix-environment option + no-new-sidecar persistence + workdoc line)"
}

# prompt-text: standalone recovered-clean re-entry paths re-evaluate rules_gate (X4).
# A transport retry cannot clear an environment condition, so a recovered-clean run
# MUST re-attest the same degradation and hit the same banner. The Exit-1 retry-
# recovery branch names rules_gate after head_gate; the policy-gate re-spawn Option 1
# names BOTH head_gate (repairing its pre-existing omission) AND rules_gate. Dropping
# either site's rules_gate re-evaluation lets a recovered-clean run bypass the gate
# (fail-open through the transport-retry back door); dropping the L326 head_gate
# repair re-opens the pre-existing audited-HEAD omission on that path.
check_cross_audit_standalone_recovered_clean_rules() {
  local skill='skills/cross-audit/SKILL.md'
  test -f "$skill" || { echo "$skill missing"; return 1; }
  # (a) Exit-1 retry-recovery branch names rules_gate re-attest.
  grep -qF 'a recovered-clean run re-attests the same degradation' "$skill" \
    || { echo "$skill Exit-1 recovery branch missing the rules_gate 're-attests the same degradation' re-entry literal"; return 1; }
  # (b) policy-gate re-spawn Option 1 repairs the pre-existing head_gate omission.
  grep -qF "repairing this option's pre-existing head_gate omission" "$skill" \
    || { echo "$skill policy re-spawn Option 1 missing the head_gate-omission-repair literal"; return 1; }
  # (c) policy-gate re-spawn Option 1 names rules_gate.
  grep -qF 'then the **degraded-rules gate** returns `rules_gate: null`' "$skill" \
    || { echo "$skill policy re-spawn Option 1 missing the rules_gate re-evaluation literal"; return 1; }
  echo "cross-audit standalone recovered-clean rules_gate re-entry OK (Exit-1 branch + policy re-spawn head_gate repair + rules_gate)"
}

check_model_attestation_skill_coupling() {
  local agent='agents/cross-auditor.md'
  local feat='skills/feature/SKILL.md'
  local standalone='skills/cross-audit/SKILL.md'
  test -f "$agent" || { echo "$agent missing"; return 1; }
  test -f "$feat" || { echo "$feat missing"; return 1; }
  test -f "$standalone" || { echo "$standalone missing"; return 1; }

  # (a) Bidirectional model<->flag coupling. Read cross-auditor frontmatter model
  #     value; if 'fable' the expected-flag prefix is claude-fable, if 'opus' the
  #     flag must be claude-opus or absent everywhere. No silent drift.
  local model_val expected_prefix
  model_val=$(sed -n 's/^model: *//p' "$agent" | head -1)
  if [ "$model_val" = "fable" ]; then
    expected_prefix='claude-fable'
  elif [ "$model_val" = "opus" ]; then
    expected_prefix='claude-opus'
  else
    echo "$agent unexpected model frontmatter value '$model_val' (expected fable or opus)"
    return 1
  fi

  # (b) Per file, count of RUNNABLE invocation lines == count of those also
  #     carrying --expected-claude-model <prefix>. The runnable matcher requires a
  #     verb prefix (python3 / invoke, optional backtick) so the §3.5b parser-id
  #     prose line (noun phrase, no verb) is excluded by construction. The bare
  #     matcher `check_dispatch_response.py --mode` is FORBIDDEN here — it would
  #     count the parser-id sentence. Empirical baseline: feature=3, standalone=1.
  local runnable_re='(python3|invoke) `?(hooks/lib/)?check_dispatch_response\.py --mode'
  local f n_run n_flag
  for f in "$feat:3" "$standalone:1"; do
    local file="${f%:*}" baseline="${f#*:}"
    n_run=$(grep -cE "$runnable_re" "$file")
    [ "$n_run" = "$baseline" ] \
      || { echo "$file runnable classifier-invocation count $n_run != expected baseline $baseline"; return 1; }
    n_flag=$(grep -E "$runnable_re" "$file" | grep -cF -- "--expected-claude-model $expected_prefix")
    [ "$n_flag" = "$n_run" ] \
      || { echo "$file: $n_flag of $n_run runnable invocations carry '--expected-claude-model $expected_prefix' (must equal — a flagless callsite literal remains)"; return 1; }
  done

  # (c) Standalone persistence: workdoc-line clause present, no resurrected
  #     model_gate_action sidecar-field clause (X12/X15 — the sidecar write was
  #     unimplementable; the post-action record is a workdoc-iterN line only).
  grep -qF -- '- Model attestation: ' "$standalone" \
    || { echo "$standalone missing standalone workdoc-line persistence clause '- Model attestation: '"; return 1; }
  if grep -qF 'model_gate_action' "$standalone"; then
    echo "$standalone reintroduces forbidden 'model_gate_action' sidecar-field clause (X15 — collides with no-overwrite seal)"
    return 1
  fi

  # (d) Feature SKILL.md carries the §3.5b-2e Log grammar literal.
  grep -qF 'model_degraded — cross-auditor attested' "$feat" \
    || { echo "$feat missing §3.5b-2e Log grammar literal 'model_degraded — cross-auditor attested'"; return 1; }

  echo "model-attestation skill coupling OK (model: $model_val -> $expected_prefix; feature 3/3 + standalone 1/1 flagged; workdoc-line clause present, no sidecar field; Log grammar present)"
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
  grep -qF 'R5-R7 are convention-text' "$agent" \
    || { echo "$agent missing 'R5-R7 are convention-text' in description"; return 1; }
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

  # (R4-R7 enforcement-queued sub-check retired 2026-05-25 alongside R4 retirement.
  # The MISSION.md claim itself is now stale — flagged as KB-side follow-up.)

  echo "MISSION.md R-enforcement claim is narrow"
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

# (a) frontmatter parses and rules is a list of length 14 (R1-R3, R5-R14, R16)
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
# the [all]-audience set. Was 8 before any cluster audience flips; 9 after
# PR-D Step 3 flipped R11 to [all]; 10 after PR-D Step 4 flipped R13 to [all];
# 11 after R15 added by 2026-05-13-cap-banner-and-empirical-verification;
# back to 9 after 2026-05-25 retirement of R4 and R15 (both were [all]);
# 10 after R16 (least-code-first-ladder, [all]) added 2026-06-16.
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
  local path="${1:-agents/references/cross-auditor-mode-focus.md}"
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

# (f) backend filter returns 14 (R1..R3 + R5..R8 [all] + R16 [all] + R9..R14 [backend]).
# Was 15 before 2026-05-25 retirement of R4 ([all]) and R15 ([all]);
# 14 after R16 (least-code-first-ladder, [all]) added 2026-06-16.
def trigger_a_filter(rules_list, project_type):
    return [r for r in rules_list if "all" in r["applies_to"] or project_type in r["applies_to"]]

filtered_backend = trigger_a_filter(rules, "backend")
if len(filtered_backend) != 14:
    print(f"{path}: backend filter returned {len(filtered_backend)}, expected 14 (assertion f)", file=sys.stderr)
    sys.exit(1)

# (g) smart_contract filter returns the [all]-audience set. Was 8 before any
# cluster audience flips; 9 after PR-D Step 3 flipped R11 to [all]; 10 after
# PR-D Step 4 flipped R13 to [all]; 11 after R15 was added by
# 2026-05-13-cap-banner-and-empirical-verification; back to 9 after
# 2026-05-25 retirement of R4 and R15; 10 after R16
# (least-code-first-ladder, [all]) added 2026-06-16.
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
  local path="${1:-agents/references/cross-auditor-mode-focus.md}"
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
# section carries 5 load-bearing substrings. Per Spec 2a Step 5 §3.3a row 3,
# §Step 1 moved to agents/references/cross-auditor-codex-dispatch.md while
# §Step 2 stays in the hub — helper split into two file-specific helpers
# (disposition (c)). The aggregate registration calls both halves so the
# 7-substring + 5-substring contract is fully enforced.
check_cross_auditor_step1_load_instructions() {
  local path="${1:-agents/references/cross-auditor-codex-dispatch.md}"
  test -f "$path" || { echo "$path missing" >&2; return 1; }
  # End-bound is the §Step 1 sentinel placed at end-of-section in the ref per Spec 2a Step 5.
  local s1
  s1=$(awk '
    /^## Step 1: Launch Codex/ { in_s=1; print; next }
    in_s && /^<!-- end §Step 1 -->/ { exit }
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

  echo "cross-auditor §Step 1 (7 substrings) load-instructions present in $path"
}

check_cross_auditor_step2_load_instructions() {
  local path="${1:-agents/cross-auditor.md}"
  test -f "$path" || { echo "$path missing" >&2; return 1; }
  local s2
  s2=$(awk '
    /^## Step 2: Claude Audit/ { in_s=1; print; next }
    in_s && /^## Step 3:/ { exit }
    in_s { print }
  ' "$path")

  # (b) Step 2 — five load-bearing substrings
  local tok
  for tok in 'code-quality-rules.md' 'Bad code' 'Good code' 'mode ∈ {security, full}' 'additively'; do
    printf '%s\n' "$s2" | grep -qF "$tok" \
      || { echo "$path §Step 2 section missing load-bearing token: '$tok' (Pin 6 assertion b)" >&2; return 1; }
  done

  echo "cross-auditor §Step 2 (5 substrings) load-instructions present in $path"
}

# Compatibility wrapper — calls both halves so existing pin registrations + the
# 7+5 substring contract continue to gate.
check_cross_auditor_step1_step2_load_instructions() {
  check_cross_auditor_step1_load_instructions "agents/references/cross-auditor-codex-dispatch.md" \
    || return 1
  check_cross_auditor_step2_load_instructions "agents/cross-auditor.md" \
    || return 1
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
  # Pin C (prompt-text): Asserts agents/references/cross-auditor-mode-focus.md spec mode block carries
  # the Attack-surface profile consumption rules with all required fingerprints.
  local path="${1:-agents/references/cross-auditor-mode-focus.md}"
  test -f "$path" || { echo "$path missing" >&2; return 1; }

  local sec
  sec=$(awk '/^### `spec` mode/,/^<!-- end §spec mode -->/' "$path")

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

check_locate_section_outside_fences_helper() {
  # behavioral: exercises hooks/lib/locate_section_outside_fences.sh against
  # the 10 §3.3a.1 fixtures plus the arg-error channel. Replaces the former
  # 'outside fenced code blocks' substring-grep — the fence-aware §1.1
  # detection logic now lives in a deterministic, fixture-tested helper.
  # The pin asserts the EXACT exit code per fixture (0 found / 1 not-found),
  # never merely "non-zero", so an exit-2 arg-error is never accepted as
  # not-found.
  local helper="hooks/lib/locate_section_outside_fences.sh"
  local fdir="tests/fixtures/locate-section-outside-fences"
  test -x "$helper" || test -f "$helper" || { echo "$helper missing"; return 1; }
  local s='^## 1\.1 Attack-surface profile$'
  local b1='^## 1\. Context$'
  local b2='^## 2\. Current State$'

  # _expect <expected-rc> <expected-stdout> <args...>
  _lsof_expect() {
    local want_rc="$1" want_out="$2"; shift 2
    local out rc
    out=$(bash "$helper" "$@" 2>/dev/null)
    rc=$?
    [ "$rc" -eq "$want_rc" ] \
      || { echo "locate helper: args [$*] expected exit $want_rc, got $rc"; return 1; }
    [ "$out" = "$want_out" ] \
      || { echo "locate helper: args [$*] expected stdout '$want_out', got '$out'"; return 1; }
    return 0
  }
  # _expect_argerr <args...> — exit 2, empty stdout, a ⚠ stderr diagnostic.
  _lsof_expect_argerr() {
    local out err rc
    out=$(bash "$helper" "$@" 2>/tmp/lsof-err.$$)
    rc=$?
    err=$(cat /tmp/lsof-err.$$); rm -f /tmp/lsof-err.$$
    [ "$rc" -eq 2 ] \
      || { echo "locate helper: args [$*] expected arg-error exit 2, got $rc"; return 1; }
    [ -z "$out" ] \
      || { echo "locate helper: args [$*] arg-error should have empty stdout, got '$out'"; return 1; }
    printf '%s' "$err" | grep -qF '⚠ locate_section_outside_fences:' \
      || { echo "locate helper: args [$*] arg-error missing ⚠ stderr diagnostic"; return 1; }
    return 0
  }

  # Found / not-found fixtures — exact exit code asserted.
  _lsof_expect 0 found "$fdir/outside/spec.md" "$s" || return 1
  _lsof_expect 0 found "$fdir/outside/spec.md" "$s" "$b1" "$b2" || return 1
  _lsof_expect 1 not-found "$fdir/inside-3bt/spec.md" "$s" || return 1
  _lsof_expect 1 not-found "$fdir/inside-4bt/spec.md" "$s" || return 1
  _lsof_expect 0 found "$fdir/outside-plus-fenced-dup/spec.md" "$s" || return 1
  _lsof_expect 1 not-found "$fdir/inside-4bt-markdown-info/spec.md" "$s" || return 1
  _lsof_expect 1 not-found "$fdir/longer-closer/spec.md" "$s" || return 1
  _lsof_expect 0 found "$fdir/crlf-outside/spec.md" "$s" || return 1
  _lsof_expect 1 not-found "$fdir/section-matches-fence-opener/spec.md" '^\x60{3,}' || return 1
  _lsof_expect 1 not-found "$fdir/misordered-after/spec.md" "$s" "$b1" "$b2" || return 1
  _lsof_expect 1 not-found "$fdir/misordered-before/spec.md" "$s" "$b1" "$b2" || return 1

  # Arg-error channel — every precedence check.
  _lsof_expect_argerr || return 1
  _lsof_expect_argerr onlyonearg || return 1
  _lsof_expect_argerr "$fdir/outside/spec.md" "$s" b3 b4 b5 || return 1
  _lsof_expect_argerr /nonexistent/spec.md "$s" || return 1
  _lsof_expect_argerr "$fdir/outside/spec.md" '' || return 1
  _lsof_expect_argerr "$fdir/outside/spec.md" '(' || return 1
  _lsof_expect_argerr /nonexistent/spec.md '(' || return 1
  _lsof_expect_argerr "$fdir/outside/spec.md" "$s" onlyonebound || return 1

  echo "locate_section_outside_fences.sh: 10 fixtures + arg-error channel match the §3.3a.1 decision table"
}

check_cross_auditor_mode_focus_names_locate_helper() {
  # prompt-text: guards the prose↔helper wiring — asserts
  # agents/references/cross-auditor-mode-focus.md §1.1 prose names the
  # locate_section_outside_fences.sh helper via the env-anchored ABSOLUTE
  # path. The cross-auditor's cwd during an audit is the target repo, so a
  # bare relative `hooks/lib/...` invocation would let an adversarial target
  # repo shadow the trusted plugin helper (X6) — assert the
  # ${CLAUDE_PLUGIN_ROOT}/hooks/lib/ prefix, not merely the basename, so a
  # regression to a relative path fails the smoke run.
  local f="agents/references/cross-auditor-mode-focus.md"
  test -f "$f" || { echo "$f missing"; return 1; }
  grep -qF '${CLAUDE_PLUGIN_ROOT}/hooks/lib/locate_section_outside_fences.sh' "$f" \
    || { echo "$f does not invoke locate_section_outside_fences.sh via the \${CLAUDE_PLUGIN_ROOT}/hooks/lib/ absolute prefix — bare-relative path is a target-repo shadowing vector (X6)" >&2; return 1; }
  echo "cross-auditor-mode-focus.md invokes locate_section_outside_fences.sh via the \${CLAUDE_PLUGIN_ROOT}/hooks/lib/ absolute path"
}

check_json_schema_lint_self_test() {
  # behavioral: exercises the pure-stdlib JSON-Schema validator
  # tests/lib/json_schema_lint.py against a known-VALID instance and one
  # known-INVALID instance per violation kind (wrong type / missing required /
  # bad enum / extra property under additionalProperties:false / bad array
  # item). A self-test with only a positive case proves nothing — each
  # negative case asserts the validator actually rejects the malformed shape.
  # Also covers X3 (JSON-type-aware enum equality — true must not match int 1)
  # and X4 (a misspelled schema keyword fails loud with exit 2).
  local lint="tests/lib/json_schema_lint.py"
  local schema="tests/fixtures/json-schema-lint/selftest.schema.json"
  test -f "$lint" || { echo "$lint missing"; return 1; }
  test -f "$schema" || { echo "$schema missing"; return 1; }

  # Positive: a valid instance exits 0.
  python3 "$lint" "$schema" tests/fixtures/json-schema-lint/valid.json >/dev/null 2>&1 \
    || { echo "validator rejected a known-valid instance"; return 1; }

  # Negative cases: each malformed instance exits 1 with a diagnostic.
  local kind out rc
  for kind in bad-type missing-required bad-enum extra-property bad-items; do
    out=$(python3 "$lint" "$schema" "tests/fixtures/json-schema-lint/$kind.json" 2>&1)
    rc=$?
    [ "$rc" -eq 1 ] \
      || { echo "validator did not exit 1 on '$kind' instance (got rc=$rc)"; return 1; }
    [ -n "$out" ] \
      || { echo "validator emitted no diagnostic on '$kind' instance"; return 1; }
  done

  # Usage error: wrong arg count exits 2.
  python3 "$lint" "$schema" >/dev/null 2>&1
  [ "$?" -eq 2 ] || { echo "validator did not exit 2 on a usage error"; return 1; }

  # X3 — JSON-type-aware enum equality. Python `==` collapses True/1, so an
  # integer-only enum {"enum":[1]} must still REJECT the JSON instance `true`
  # (exit 1), and a boolean-only enum {"enum":[true]} must REJECT `1`.
  local fdir="tests/fixtures/json-schema-lint"
  python3 "$lint" "$fdir/enum-int.schema.json" "$fdir/enum-int-instance.json" >/dev/null 2>&1
  [ "$?" -eq 1 ] || { echo "validator accepted JSON true for an integer-only enum [1] (X3 type collision)"; return 1; }
  python3 "$lint" "$fdir/enum-bool.schema.json" "$fdir/enum-bool-instance.json" >/dev/null 2>&1
  [ "$?" -eq 1 ] || { echo "validator accepted integer 1 for a boolean-only enum [true] (X3 type collision)"; return 1; }

  # X5 — the bool/int distinction must hold inside container enum members too.
  # _json_equal must recurse rather than delegate list/dict comparison to bare
  # Python `==` (which re-collapses True/1 at every nesting level). A list-valued
  # enum {"enum":[[1]]} must REJECT the JSON instance [true], and a dict-valued
  # enum {"enum":[{"x":1}]} must REJECT {"x":true}.
  python3 "$lint" "$fdir/enum-list.schema.json" "$fdir/enum-list-instance.json" >/dev/null 2>&1
  [ "$?" -eq 1 ] || { echo "validator accepted [true] for a list-valued enum [[1]] (X5 nested type collision)"; return 1; }
  python3 "$lint" "$fdir/enum-dict.schema.json" "$fdir/enum-dict-instance.json" >/dev/null 2>&1
  [ "$?" -eq 1 ] || { echo "validator accepted {\"x\":true} for a dict-valued enum [{\"x\":1}] (X5 nested type collision)"; return 1; }

  # X4 — a misspelled/unsupported schema keyword must fail loud (exit 2), not
  # silently no-op its gate.
  out=$(python3 "$lint" "$fdir/misspelled-keyword.schema.json" "$fdir/misspelled-keyword-instance.json" 2>&1)
  rc=$?
  [ "$rc" -eq 2 ] || { echo "validator did not exit 2 on a misspelled schema keyword (got rc=$rc) — X4 silent no-op"; return 1; }
  printf '%s' "$out" | grep -qF "addtionalProperties" \
    || { echo "validator exit-2 diagnostic does not name the offending keyword (X4)"; return 1; }

  # X8 — a malformed VALUE of a supported keyword must fail loud (exit 2), not
  # silently no-op its gate. additionalProperties:"false" (a string, not a
  # boolean) is never `is False`, so validate() would silently skip the
  # extra-property gate and accept an EXTRA key. The schema-walk value-type
  # check must reject it with exit 2 and the diagnostic must name the keyword.
  out=$(python3 "$lint" "$fdir/bad-additionalproperties.schema.json" "$fdir/bad-additionalproperties-instance.json" 2>&1)
  rc=$?
  [ "$rc" -eq 2 ] || { echo "validator did not exit 2 on a non-boolean additionalProperties (got rc=$rc) — X8 silent gate disable"; return 1; }
  printf '%s' "$out" | grep -qF "additionalProperties" \
    || { echo "validator exit-2 diagnostic does not name the offending keyword (X8)"; return 1; }

  # X8/X10 — the schema-walk added six keyword value-type-checks but only
  # additionalProperties had a negative fixture; the other five were unproven
  # gates (R3/R6). Each malformed-value schema below must fail loud with exit 2
  # and a diagnostic naming the offending keyword. The trailing instance file
  # is irrelevant — _walk_schema exits before instance validation runs.
  #   bad-required           required is a string, not a list
  #   bad-properties         properties is a string, not an object
  #   bad-enum-value         enum is an empty list
  #   bad-type-keyword       type is an unknown type-name string
  # X10 — _walk_schema must additionally recurse into properties member
  # subschemas and reject the Draft-07 tuple-form items list (validate() does
  # not implement tuple semantics — a malformed member or a tuple list would
  # otherwise emit zero diagnostics or mis-classify every array element):
  #   bad-properties-member  a properties member subschema is a non-object
  #   bad-items-tuple        items is a tuple-form list of per-position schemas
  local badschema badkw
  for badschema in bad-required:required bad-properties:properties \
                   bad-enum-value:enum bad-type-keyword:type \
                   bad-properties-member:properties bad-items-tuple:items; do
    badkw="${badschema##*:}"
    badschema="${badschema%%:*}"
    out=$(python3 "$lint" "$fdir/$badschema.schema.json" "$fdir/misspelled-keyword-instance.json" 2>&1)
    rc=$?
    [ "$rc" -eq 2 ] \
      || { echo "validator did not exit 2 on '$badschema' malformed-value schema (got rc=$rc) — X8/X10 silent gate disable"; return 1; }
    printf '%s' "$out" | grep -qF "$badkw" \
      || { echo "validator exit-2 diagnostic for '$badschema' does not name the offending keyword '$badkw'"; return 1; }
  done

  echo "json_schema_lint.py self-test: accepts valid, rejects every violation kind + X3 scalar enum type + X5 nested container enum type + X4 misspelled keyword + X8/X10 malformed keyword value (additionalProperties/required/properties/enum/type + nested properties member + tuple-form items)"
}

# Shared helper: run a cross-audit probe (probe_g.sh / probe_h.sh) against a
# fixture dir, structurally validate the live stdout against the
# probe-envelope JSON-Schema, then compare it with expected_stdout.json after
# stripping the closed non-deterministic field set.
#
# This replaces the former _probe_envelope_check / g _probe_envelope_check full h
# byte-diff helpers (X10): a raw byte-diff broke whenever input.json was
# reformatted, because receipt_metadata.trigger_input_hash = sha256(stdin)
# flips on any whitespace change with NO semantic regression. Here the volatile
# hash is stripped from BOTH sides before the value compare, so cosmetic input
# drift no longer breaks the pin; a structural regression is caught by the
# schema gate; a value/detection regression is caught by the hash-stripped
# compare against the frozen expected_stdout.json snapshot.
#
# Non-deterministic strip list — a CLOSED list: { receipt_metadata.trigger_input_hash }.
# emitted_at is NOT stripped — it is pinned deterministically by *_FAKE_NOW.
# A future non-deterministic receipt field would be added here with a rationale.
#
# Usage: _probe_envelope_check <fixture-dir> <probe>   where <probe> is g or h.
_probe_envelope_check() {
  local fdir="$1"
  local probe="$2"
  local input="$fdir/input.json"
  local expected="$fdir/expected_stdout.json"
  [ -r "$input" ] || { echo "$input not readable"; return 1; }
  [ -r "$expected" ] || { echo "$expected not readable"; return 1; }
  local probe_script fake_now_var
  case "$probe" in
    g) probe_script="probe_g.sh"; fake_now_var="PROBE_G_FAKE_NOW" ;;
    h) probe_script="probe_h.sh"; fake_now_var="PROBE_H_FAKE_NOW" ;;
    *) echo "_probe_envelope_check: unknown probe '$probe' (expected g or h)"; return 1 ;;
  esac
  local plugin_root
  plugin_root="$(pwd)"
  local schema="$plugin_root/tests/fixtures/probe-envelope.schema.json"
  [ -r "$schema" ] || { echo "probe-envelope schema $schema not readable"; return 1; }
  local out_tmp="/tmp/smoke-probe-${probe}-out.$$"
  local err_tmp="/tmp/smoke-probe-${probe}-err.$$"
  local exit_code=0
  ( cd "$fdir" \
    && env "$fake_now_var=2026-05-07T00:00:00Z" \
       CLAUDE_PLUGIN_ROOT="$plugin_root" \
    bash "$plugin_root/hooks/lib/$probe_script" < input.json ) >"$out_tmp" 2>"$err_tmp" || exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    echo "$probe_script exited $exit_code against $fdir; stderr:"
    head -5 "$err_tmp"
    rm -f "$out_tmp" "$err_tmp"
    return 1
  fi
  rm -f "$err_tmp"

  # (2) Structural gate: validate the live stdout against the envelope schema.
  local schema_err
  schema_err=$(python3 "$plugin_root/tests/lib/json_schema_lint.py" "$schema" "$out_tmp" 2>&1)
  if [ "$?" -ne 0 ]; then
    echo "$probe_script output for $fdir violates probe-envelope.schema.json:"
    printf '%s\n' "$schema_err" | head -10
    rm -f "$out_tmp"
    return 1
  fi

  # (3) Strip the closed non-deterministic field set, then canonical-compare.
  local actual exp
  actual=$(python3 - "$out_tmp" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
d.get("receipt_metadata", {}).pop("trigger_input_hash", None)
sys.stdout.write(json.dumps(d, sort_keys=True, separators=(",", ":"), ensure_ascii=False))
PYEOF
)
  exp=$(python3 - "$expected" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
d.get("receipt_metadata", {}).pop("trigger_input_hash", None)
sys.stdout.write(json.dumps(d, sort_keys=True, separators=(",", ":"), ensure_ascii=False))
PYEOF
)
  rm -f "$out_tmp"
  if [ "$actual" != "$exp" ]; then
    echo "probe_$probe hash-stripped output mismatch for $fdir:"
    diff <(printf '%s\n' "$actual") <(printf '%s\n' "$exp") | head -20
    return 1
  fi
  echo "probe_$probe output schema-conforms and hash-stripped-matches expected for $fdir"
}

# Shared helper: assert every expected_stdout.json under a probe fixture root
# conforms to the probe-envelope JSON-Schema. This is the structural-contract
# gate (schema class) — distinct from _probe_envelope_check, which additionally
# runs the probe and value-compares (behavioral).
_probe_fixtures_schema_conform() {
  local froot="$1"
  local schema="tests/fixtures/probe-envelope.schema.json"
  test -d "$froot" || { echo "$froot fixture root missing"; return 1; }
  test -f "$schema" || { echo "$schema missing"; return 1; }
  local count=0 expected out
  for expected in "$froot"/*/expected_stdout.json; do
    [ -f "$expected" ] || continue
    count=$((count + 1))
    out=$(python3 tests/lib/json_schema_lint.py "$schema" "$expected" 2>&1)
    if [ "$?" -ne 0 ]; then
      echo "$expected does not conform to probe-envelope.schema.json:"
      printf '%s\n' "$out" | head -10
      return 1
    fi
  done
  [ "$count" -gt 0 ] || { echo "no expected_stdout.json fixtures found under $froot"; return 1; }
  echo "all $count expected_stdout.json fixtures under $froot conform to probe-envelope.schema.json"
}

check_probe_g_fixtures_schema_conform() {
  _probe_fixtures_schema_conform tests/fixtures/cross-audit-probe-g
}

check_probe_h_fixtures_schema_conform() {
  _probe_fixtures_schema_conform tests/fixtures/cross-audit-probe-h
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
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/01-positive-major-drift g
}

check_probe_g_detector_clean_at_current_major() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/02-clean-current-major g
}

check_probe_g_detector_ineligible_no_lockfile() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/03-ineligible-no-lockfile g
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
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/01-positive-typosquat h
}

check_probe_h_detector_clean_canonical_name() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/02-clean-canonical-name h
}

check_probe_h_detector_clean_distant_name() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/03-clean-distant-name h
}

check_probe_g_detector_fires_on_major_only_no_dot() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/06-major-only-no-dot g
}

check_probe_h_detector_fires_on_major_only_no_dot() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/06-major-only-no-dot h
}

check_probe_g_detector_fires_on_extras_syntax() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/08-extras-syntax g
}

check_probe_h_detector_fires_on_extras_syntax() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/08-extras-syntax h
}

check_probe_g_detector_fires_on_whitespace_eq() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/09-whitespace-eq g
}

check_probe_h_detector_fires_on_whitespace_eq() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/09-whitespace-eq h
}

check_probe_g_detector_rejects_malformed_requirements() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/19-malformed-requirements g
}

check_probe_g_detector_fires_on_uppercase_name_package_lock() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/07-uppercase-name-package-lock g
}

check_probe_g_detector_out_of_diff_lockfile_ignored() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/11-out-of-diff-lockfile-ignored g
}

check_probe_h_detector_out_of_diff_lockfile_ignored() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/11-out-of-diff-lockfile-ignored h
}

check_probe_g_detector_in_diff_lockfile_evaluated() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/11-in-diff-lockfile-evaluated g
}

check_probe_h_detector_in_diff_lockfile_evaluated() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/11-in-diff-lockfile-evaluated h
}

check_probe_g_yarn_berry_peer_dep() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/12-yarn-berry-peer-dep g
}

check_probe_h_yarn_berry_peer_dep() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/12-yarn-berry-peer-dep h
}

check_probe_g_yarn_scoped_npm_protocol() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/13-yarn-scoped-npm-protocol g
}

check_probe_h_yarn_scoped_npm_protocol() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/13-yarn-scoped-npm-protocol h
}

check_probe_g_pnpm_v9_format() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/14-pnpm-v9-format g
}

check_probe_h_pnpm_v9_format() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/14-pnpm-v9-format h
}

check_probe_g_pnpm_v9_quoted_scoped() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/20-pnpm-v9-quoted-scoped g
}

check_probe_h_pnpm_v9_quoted_scoped() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/20-pnpm-v9-quoted-scoped h
}

check_probe_g_yarn_scoped_alias_target() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/21-yarn-scoped-alias-target g
}

check_probe_h_yarn_scoped_alias_target() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/21-yarn-scoped-alias-target h
}

check_probe_g_yarn_portal_and_github() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/22-yarn-portal-and-github g
}

check_probe_h_yarn_portal_and_github() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/22-yarn-portal-and-github h
}

check_probe_h_levenshtein_length_cap() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/15-levenshtein-length-cap h
}

check_probe_g_vendored_excluded() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/10-vendored-excluded g
}

check_probe_h_vendored_excluded() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/10-vendored-excluded h
}

check_probe_g_boundary_drift_2_suppressed() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/04-boundary-drift-2-suppressed g
}

check_probe_g_boundary_drift_3_fired() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/05-boundary-drift-3-fired g
}

check_probe_g_npm_v7_packages_walk_and_dep_classes() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/16-npm-v7-and-dep-classes g
}

check_probe_h_npm_v7_packages_walk_and_dep_classes() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/16-npm-v7-and-dep-classes h
}

check_probe_g_npm_range_vs_resolved_dedup() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/17-range-vs-resolved-dedup g
}

check_probe_h_npm_range_vs_resolved_dedup() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/17-range-vs-resolved-dedup h
}

check_probe_g_pre_1_0_skipped() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-g/18-pre-1-0-skipped g
}

check_probe_h_detector_rejects_malformed_requirements() {
  _probe_envelope_check tests/fixtures/cross-audit-probe-h/19-malformed-requirements h
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
  local f="agents/references/cross-auditor-mode-focus.md"
  local sec
  sec=$(awk '/^### `spec` mode/,/^<!-- end §spec mode -->/' "$f")
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
  block=$(awk '/^Spawn `cross-auditor` subagent with the \*\*same parameter block as the initial full-mode spawn/,/^The cross-auditor returns findings inline \(no KB writes in spec mode\)\.$/' "$f")
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
  # §Step 1 moved to agents/references/cross-auditor-codex-dispatch.md per Spec 2a Step 5 §3.3a row 6
  # (path-swap-only — both awk bounds co-located in the destination file post-Step-5).
  local f="agents/references/cross-auditor-codex-dispatch.md"
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
  # §Step 1 moved to agents/references/cross-auditor-codex-dispatch.md per Spec 2a Step 5.
  local f="agents/references/cross-auditor-codex-dispatch.md"
  local rendered marker
  rendered=$(grep -cF 'R-rule cluster: NOT loaded' "$f")
  # The marker locks the conditional-emit comment so the bullet is documented as gate-conditional,
  # not always-on. Regex order matches the spec example byte-for-byte: emitted only when ... R-rule cluster.
  marker=$(grep -cE 'emitted only when.*R-rule cluster' "$f")
  [ "$rendered" -ge 1 ] || { echo "missing rendered-bullet literal 'R-rule cluster: NOT loaded' (with colon)"; return 1; }
  [ "$marker" -ge 1 ] || { echo "missing 'emitted only when ... R-rule cluster' conditional-emit comment marker"; return 1; }
}

check_cross_auditor_replaces_silent_skip_gate() {
  # §Step 1 moved to agents/references/cross-auditor-codex-dispatch.md per Spec 2a Step 5.
  local f="agents/references/cross-auditor-codex-dispatch.md"
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
  local f="agents/references/cross-auditor-evidence-handshake.md"
  local skl="skills/feature/SKILL.md"
  local ca_sent ca_obfusc skl_sent skl_delegate skl_eof skl_old skl_l424
  local ca_l424 ca_l445_parser ca_l445_sem ca_l445_summary ca_l445_4th
  local ca_l424_pos ca_l445_pos
  # Producer fenced positive (X12 locked) — exactly one canonical-spaced sentinel literal site.
  ca_sent=$(grep -cF '# CROSS-AUDIT EVIDENCE FOOTER' "$f")
  # Producer obfuscated-form positive (X12) — at least one obfuscated form documents the rule.
  ca_obfusc=$(grep -cF 'CROSS-AUDIT-EVIDENCE-FOOTER' "$f")
  # Consumer parser positive (code-audit iter-1 X3 reconciliation) — SKILL.md
  # §3.5b spec-mode READ path delegates to the runtime classifier, which is the
  # single authoritative consumer-side parser. The superseded inline `tail -3`
  # shell snippet was removed; `check_dispatch_response.py` distinguishes the
  # newline-unsafe defect from a plain missing footer (a literal `tail -3`
  # cannot). The producer doc still describes the `tail -3` shape as the
  # well-formed-footer reference; the executable parser-shape harness moved to
  # the classifier's own smoke pin (check_dispatch_response_classification).
  skl_delegate=$(grep -cF 'hooks/lib/check_dispatch_response.py --mode spec' "$skl")
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
  [ "$skl_delegate" -ge 1 ] || { echo "SKILL.md: §3.5b spec-mode READ path must delegate to 'hooks/lib/check_dispatch_response.py --mode spec' (X3 reconciliation — the classifier is the single authoritative consumer-side parser)"; return 1; }
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
  # Executable consumer-parser coverage (X3 reconciliation): the SKILL.md
  # §3.5b spec-mode READ path no longer carries an inline `tail -3` shell
  # snippet — the runtime classifier `hooks/lib/check_dispatch_response.py`
  # is the single authoritative consumer-side parser, and it is exercised
  # against the trailing-newline + sentinel-position fixture set by the
  # `check_dispatch_response_classification` behavioral pin. No separate
  # shell-shape harness here would add coverage (it would only re-test a
  # parser SKILL.md no longer publishes).
  echo "spec-mode footer sentinel-marker contract OK (consumer parser delegated to check_dispatch_response.py)"
}

check_cross_auditor_probe_failures_schema_aligned() {
  local f="agents/cross-auditor.md"
  local f_pr="agents/references/cross-auditor-pr-and-probes.md"
  local f_step3="agents/references/cross-auditor-step-3-pipeline.md"
  local h="tests/smoke-helpers.sh"
  local old_q_r old_q_rm reason_n remediation_n canonical old_canonical translator_bridge scorer_token
  local l389_old_r l389_new_r l389_old_rm l389_new_rm
  local helpers_old_q_r helpers_old_q_rm helpers_new_q_r helpers_new_q_rm
  # Scoped quoted-key dict-literal negatives — the fingerprint of the five Step 0.5 .append( sites.
  # Bare `failure_reason` legitimately stays at scorer_failure_reason and translator-bridge
  # surfaces, which is why this clause is scoped to the QUOTED-KEY form, not bare token. Per
  # Spec 2a Step 6 the five Step 0.5 .append() sites moved to
  # agents/references/cross-auditor-pr-and-probes.md; negatives must hold across hub + pr ref +
  # step3 ref to catch any reintroduction.
  old_q_r=$(( $(grep -cF '"failure_reason":' "$f") + $(grep -cF '"failure_reason":' "$f_pr") + $(grep -cF '"failure_reason":' "$f_step3") ))
  old_q_rm=$(( $(grep -cF '"failure_remediation":' "$f") + $(grep -cF '"failure_remediation":' "$f_pr") + $(grep -cF '"failure_remediation":' "$f_step3") ))
  # Positive count — five quoted-key dict-literal sites emit "reason" / "remediation"; they all
  # live in the pr-and-probes ref now (Step 0.5 pseudocode .append() blocks).
  reason_n=$(grep -cF '"reason":' "$f_pr")
  remediation_n=$(grep -cF '"remediation":' "$f_pr")
  # Canonical-phrase positive (X15 — threshold ≥ 2 locks BOTH the Step 0.5 description AND fail-open
  # coverage prose in lockstep; ≥ 1 would allow partial rewrite). Both surfaces moved to the
  # pr-and-probes ref at Step 6; the stage 5 synthesis surface stays in the step3 ref per Spec 2a Step 4.
  canonical=$(( $(grep -cF '`probe_id` / `reason` / `remediation`' "$f_pr") + $(grep -cF '`probe_id` / `reason` / `remediation`' "$f_step3") ))
  # X19 (a) — pre-rewrite canonical phrase absent across hub + pr ref + step3 ref.
  old_canonical=$(( $(grep -cF '`probe_id` / `failure_reason` / `failure_remediation`' "$f") + $(grep -cF '`probe_id` / `failure_reason` / `failure_remediation`' "$f_pr") + $(grep -cF '`probe_id` / `failure_reason` / `failure_remediation`' "$f_step3") ))
  # Preserve translator bridge L400-401 — Foundation §3.3 receipt-schema territory. Now lives in
  # references/cross-auditor-step-3-pipeline.md (stage 5 reason/remediation derivation) per Spec 2a Step 4.
  translator_bridge=$(grep -cF "receipt's optional \`failure_reason\`" "$f_step3")
  # Preserve scorer_failure_reason (renderer-stdin contract — distinct token). Now lives in the
  # Step-3 reference (Stage 4 Haiku scorer + Stage 6 renderer pipe payload) per Spec 2a Step 4.
  scorer_token=$(grep -cF 'scorer_failure_reason' "$f_step3")
  # L389-area inline-prose entries (paired-key — both reason and remediation halves) — moved into
  # the Step-3 reference (stage 4.5 fail-open class 6 prose) per Spec 2a Step 4.
  l389_old_r=$(grep -cF 'failure_reason: "receipt write failed:' "$f_step3")
  l389_new_r=$(grep -cF 'reason: "receipt write failed:' "$f_step3")
  l389_old_rm=$(grep -cF 'failure_remediation: "check KB mount' "$f_step3")
  l389_new_rm=$(grep -cF 'remediation: "check KB mount' "$f_step3")
  # smoke-helpers.sh seed-side emulation heredocs — symmetric paired-key coverage.
  # Exclude self-reference: the smoke-pin helper itself contains the literals as grep patterns,
  # so scope the count to lines NOT carrying a `grep -cF` clause (which fingerprint the helper's
  # own grep arguments). The seed-side emulation heredocs are Python dict-literal lines without
  # any `grep -cF` token.
  helpers_old_q_r=$(grep -F '"failure_reason":' "$h" | grep -vc 'grep -cF')
  helpers_old_q_rm=$(grep -F '"failure_remediation":' "$h" | grep -vc 'grep -cF')
  helpers_new_q_r=$(grep -F '"reason":' "$h" | grep -vc 'grep -cF')
  helpers_new_q_rm=$(grep -F '"remediation":' "$h" | grep -vc 'grep -cF')
  [ "$old_q_r" = "0" ] || { echo "agents: stale '\"failure_reason\":' quoted-key dict-literal still present across hub/pr-ref/step3-ref (5 Step 0.5 .append sites should have been renamed)"; return 1; }
  [ "$old_q_rm" = "0" ] || { echo "agents: stale '\"failure_remediation\":' quoted-key dict-literal still present"; return 1; }
  [ "$reason_n" -ge 5 ] || { echo "agents: '\"reason\":' count must be ≥ 5 in pr-and-probes ref (one per Step 0.5 .append site)"; return 1; }
  [ "$remediation_n" -ge 5 ] || { echo "agents: '\"remediation\":' count must be ≥ 5 in pr-and-probes ref"; return 1; }
  [ "$canonical" -ge 2 ] || { echo "agents: canonical phrase 'probe_id / reason / remediation' must appear at ≥ 2 surfaces (Step 0.5 description AND fail-open coverage)"; return 1; }
  [ "$old_canonical" = "0" ] || { echo "agents: stale canonical phrase 'probe_id / failure_reason / failure_remediation' still present"; return 1; }
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
  local f="agents/references/cross-auditor-evidence-handshake.md"
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
  # behavioral: the path-resolution logic that was 50+ lines of prose-grep on
  # stale/post-rewrite literals now lives in the deterministic helper
  # hooks/lib/resolve_rule_path.sh. This pin runs the helper across all nine
  # §3.3a.2 decision-table rows, asserting the EXACT exit code and the
  # ⚠ code-quality-rules.md not reachable stderr on each unreachable row.
  # The C2-closure anti-regression negatives (stale contradictory phrasing
  # stays removed) are RETAINED below.
  local plugin_root rel warn helper
  plugin_root="$(pwd)"
  # Absolute helper path — the row 6/7/9 sub-checks cd into other dirs.
  helper="$plugin_root/hooks/lib/resolve_rule_path.sh"
  test -x "$helper" || test -f "$helper" || { echo "$helper missing"; return 1; }
  rel='skills/feature/references/code-quality-rules.md'
  warn='code-quality-rules.md not reachable'

  # _rrp_resolved <expected-stdout-path> <env...> — exit 0, stdout = path, no warn.
  _rrp_resolved() {
    local want_path="$1"; shift
    local out err rc
    out=$("$@" bash "$helper" 2>/tmp/rrp-err.$$)
    rc=$?
    err=$(cat /tmp/rrp-err.$$); rm -f /tmp/rrp-err.$$
    [ "$rc" -eq 0 ] || { echo "resolver: [$*] expected resolved exit 0, got $rc"; return 1; }
    [ "$out" = "$want_path" ] || { echo "resolver: [$*] expected stdout '$want_path', got '$out'"; return 1; }
    printf '%s' "$err" | grep -qF "$warn" \
      && { echo "resolver: [$*] resolved row must not emit the unreachable warning"; return 1; }
    return 0
  }
  # _rrp_unreachable <env...> — exit 3, empty stdout, ⚠ warning on stderr.
  _rrp_unreachable() {
    local out err rc
    out=$("$@" bash "$helper" 2>/tmp/rrp-err.$$)
    rc=$?
    err=$(cat /tmp/rrp-err.$$); rm -f /tmp/rrp-err.$$
    [ "$rc" -eq 3 ] || { echo "resolver: [$*] expected unreachable exit 3, got $rc"; return 1; }
    [ -z "$out" ] || { echo "resolver: [$*] unreachable row must have empty stdout, got '$out'"; return 1; }
    printf '%s' "$err" | grep -qF "$warn" \
      || { echo "resolver: [$*] unreachable row missing '⚠ $warn' stderr"; return 1; }
    return 0
  }

  # Row 1 — env set to an absolute path with a readable regular-file rules file.
  _rrp_resolved "$plugin_root/$rel" env "CLAUDE_PLUGIN_ROOT=$plugin_root" || return 1

  # Row 2 — env set to an absolute path missing the rules file.
  local d_missing; d_missing=$(mktemp -d) || return 1
  _rrp_unreachable env "CLAUDE_PLUGIN_ROOT=$d_missing" || { rm -rf "$d_missing"; return 1; }
  # Row 2 variant — code-quality-rules.md exists but is a directory (not a regular file).
  local d_notreg; d_notreg=$(mktemp -d) || { rm -rf "$d_missing"; return 1; }
  mkdir -p "$d_notreg/$rel"
  _rrp_unreachable env "CLAUDE_PLUGIN_ROOT=$d_notreg" || { rm -rf "$d_missing" "$d_notreg"; return 1; }
  rm -rf "$d_missing" "$d_notreg"

  # Row 3 — env set to an absolute path, rules file is a regular file but chmod 000 unreadable.
  local d_unread; d_unread=$(mktemp -d) || return 1
  mkdir -p "$d_unread/$(dirname "$rel")"
  : > "$d_unread/$rel"; chmod 000 "$d_unread/$rel"
  _rrp_unreachable env "CLAUDE_PLUGIN_ROOT=$d_unread" \
    || { chmod 644 "$d_unread/$rel"; rm -rf "$d_unread"; return 1; }
  chmod 644 "$d_unread/$rel"; rm -rf "$d_unread"

  # Row 4 — env set to the empty string.
  _rrp_unreachable env "CLAUDE_PLUGIN_ROOT=" || return 1

  # Row 5 — env set to a relative path.
  _rrp_unreachable env "CLAUDE_PLUGIN_ROOT=relative/dir" || return 1

  # Row 6 — env unset, run from inside the plugin checkout (resolves inside + regular file + readable).
  ( cd "$plugin_root" && _rrp_resolved "$plugin_root/$rel" env -u CLAUDE_PLUGIN_ROOT ) || return 1

  # Row 7a — env unset, relative path resolves to a plain shadow file OUTSIDE the checkout.
  local d_shadow; d_shadow=$(mktemp -d) || return 1
  mkdir -p "$d_shadow/$(dirname "$rel")"; : > "$d_shadow/$rel"
  ( cd "$d_shadow" && _rrp_unreachable env -u CLAUDE_PLUGIN_ROOT ) \
    || { rm -rf "$d_shadow"; return 1; }
  rm -rf "$d_shadow"
  # Row 7b — env unset, sibling <root>-shadow dir whose path string-prefixes the checkout root.
  # A buggy string-prefix containment test would wrongly accept it; the separator-safe
  # commonpath guard rejects it. The checkout-root vs sibling-prefix relationship is
  # synthesized entirely inside a fresh mktemp -d parent — the script is copied into a
  # temp checkout "$sib_parent/plug" so BASH_SOURCE root computation resolves to it, and
  # the sibling "$sib_parent/plug-shadow" carries the relative target. NO real filesystem
  # path outside the temp tree is created or removed (the deterministic real
  # "<checkout>-shadow" path would clobber a developer's worktree/backup of that name).
  local sib_parent; sib_parent=$(mktemp -d) || return 1
  local sib_root="$sib_parent/plug"
  local sib_shadow="$sib_parent/plug-shadow"
  mkdir -p "$sib_root/hooks/lib"
  cp "$helper" "$sib_root/hooks/lib/"
  mkdir -p "$sib_shadow/$(dirname "$rel")"; : > "$sib_shadow/$rel"
  local r7b_out r7b_err r7b_rc
  r7b_out=$( cd "$sib_shadow" && env -u CLAUDE_PLUGIN_ROOT bash "$sib_root/hooks/lib/resolve_rule_path.sh" 2>/tmp/rrp-r7b.$$ )
  r7b_rc=$?
  r7b_err=$(cat /tmp/rrp-r7b.$$); rm -f /tmp/rrp-r7b.$$
  rm -rf "$sib_parent"
  [ "$r7b_rc" -eq 3 ] || { echo "resolver: row-7b (env-unset, sibling <root>-shadow prefix) expected exit 3, got $r7b_rc"; return 1; }
  [ -z "$r7b_out" ] || { echo "resolver: row-7b must have empty stdout, got '$r7b_out'"; return 1; }
  printf '%s' "$r7b_err" | grep -qF "$warn" \
    || { echo "resolver: row-7b missing '⚠ $warn' stderr"; return 1; }

  # Row 8 — env unset, relative target inside the checkout but chmod 000 unreadable.
  # The script is copied into a temp checkout so the BASH_SOURCE root computation
  # still resolves. Run the copied script directly (not via the $helper wrapper).
  # The temp checkout is a subdir of a guarded mktemp -d parent — the cleanup
  # rm -rf targets that parent variable directly, never `dirname` of a path
  # derived from an unchecked mktemp (the X1/X7 destructive class: on mktemp
  # failure an appended-segment path round-tripped through dirname resolves to
  # `/`, and a routine `bash tests/smoke.sh` runs `rm -rf /`).
  local d_co_parent; d_co_parent=$(mktemp -d) || return 1
  local d_co="$d_co_parent/co"
  mkdir -p "$d_co/hooks/lib" "$d_co/$(dirname "$rel")"
  cp "$helper" "$d_co/hooks/lib/"
  : > "$d_co/$rel"; chmod 000 "$d_co/$rel"
  local r8_out r8_err r8_rc
  r8_out=$( cd "$d_co" && env -u CLAUDE_PLUGIN_ROOT bash "$d_co/hooks/lib/resolve_rule_path.sh" 2>/tmp/rrp-r8.$$ )
  r8_rc=$?
  r8_err=$(cat /tmp/rrp-r8.$$); rm -f /tmp/rrp-r8.$$
  chmod 644 "$d_co/$rel"; rm -rf "$d_co_parent"
  [ "$r8_rc" -eq 3 ] || { echo "resolver: row-8 (env-unset, inside-but-unreadable) expected exit 3, got $r8_rc"; return 1; }
  [ -z "$r8_out" ] || { echo "resolver: row-8 must have empty stdout, got '$r8_out'"; return 1; }
  printf '%s' "$r8_err" | grep -qF "$warn" \
    || { echo "resolver: row-8 missing '⚠ $warn' stderr"; return 1; }

  # Row 9 — env unset, relative path does not resolve to any file.
  ( cd /tmp && _rrp_unreachable env -u CLAUDE_PLUGIN_ROOT ) || return 1

  # --- C2 closure (RETAINED anti-regression negatives) ---
  # The pre-rewrite L311 parenthetical claimed the unset-env fallback runs even
  # when env IS set, contradicting the strict env-first / no-relative-fallback
  # rule. The rewrite aligned the prose; these negatives guard that the removed
  # contradiction stays removed and the post-rewrite phrasing stays present.
  local f_ref="agents/references/cross-auditor-codex-dispatch.md"
  local stale_l311 l311_post
  stale_l311=$(grep -cF 'unset-env fallback above also fails' "$f_ref")
  l311_post=$(grep -cF 'no relative fallback when env is set' "$f_ref")
  [ "$stale_l311" = "0" ] || { echo "L311 stale 'unset-env fallback above also fails' contradictory phrasing still present"; return 1; }
  [ "$l311_post" -ge 1 ] || { echo "L311 missing post-rewrite 'no relative fallback when env is set' literal"; return 1; }

  echo "resolve_rule_path.sh: nine §3.3a.2 rows + retained C2-closure negatives all hold"
}

check_cross_auditor_codex_dispatch_names_resolve_helper() {
  # prompt-text: guards the prose↔helper wiring — asserts
  # agents/references/cross-auditor-codex-dispatch.md invokes the
  # resolve_rule_path.sh helper via the env-anchored ABSOLUTE path. The
  # cross-auditor's cwd during an audit is the target repo, so a bare
  # relative `hooks/lib/...` invocation would let an adversarial target repo
  # shadow the trusted plugin helper (X6) — assert the
  # ${CLAUDE_PLUGIN_ROOT}/hooks/lib/ prefix, not merely the basename, so a
  # regression to a relative path fails the smoke run.
  local f="agents/references/cross-auditor-codex-dispatch.md"
  test -f "$f" || { echo "$f missing"; return 1; }
  grep -qF '${CLAUDE_PLUGIN_ROOT}/hooks/lib/resolve_rule_path.sh' "$f" \
    || { echo "$f does not invoke resolve_rule_path.sh via the \${CLAUDE_PLUGIN_ROOT}/hooks/lib/ absolute prefix — bare-relative path is a target-repo shadowing vector (X6)" >&2; return 1; }
  echo "cross-auditor-codex-dispatch.md invokes resolve_rule_path.sh via the \${CLAUDE_PLUGIN_ROOT}/hooks/lib/ absolute path"
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

# Step 3 — hooks/hooks.json Stop hook timeout = 30 (was 5).
# JSON structural invariant via python3 dict-walk.
check_hooks_json_stop_timeout_30s() {
  local f="hooks/hooks.json"
  [ -f "$f" ] || { echo "$f missing"; return 1; }
  python3 - <<'PY' || return 1
import json, sys
data = json.load(open("hooks/hooks.json"))
stop = data["hooks"]["Stop"][0]["hooks"][0]
to = stop.get("timeout")
if to != 30:
    print(f"Stop hook timeout != 30 (got {to!r})")
    sys.exit(1)
PY
  echo "stop hook timeout 30"
}

# Step 4 — CLAUDE.md §Testing subsection presence + content + ordering invariant.
check_claude_md_has_testing_section() {
  local f="CLAUDE.md"
  [ -f "$f" ] || { echo "$f missing"; return 1; }
  if ! grep -qF '## Testing' "$f"; then
    echo "CLAUDE.md missing '## Testing' H2 heading"
    return 1
  fi
  # Bound the §Testing region (between '## Testing' and the next '^## ' heading).
  local region
  region=$(awk '/^## Testing$/{in_r=1; next} /^## /{in_r=0} in_r' "$f")
  [ -n "$region" ] || { echo "CLAUDE.md §Testing region empty"; return 1; }
  local anchor
  for anchor in 'bash tests/smoke.sh' 'Failed: 0' 'tests/smoke-helpers.sh' 'tests/smoke-proves-manifest.txt'; do
    if ! printf '%s' "$region" | grep -qF "$anchor"; then
      echo "CLAUDE.md §Testing region missing literal: $anchor"
      return 1
    fi
  done
  # Ordering invariant — '## Testing' < '## Contribution flow'.
  local testing_line cflow_line
  testing_line=$(awk '/^## Testing/{print NR; exit}' "$f")
  cflow_line=$(awk '/^## Contribution flow/{print NR; exit}' "$f")
  [ -n "$testing_line" ] || { echo "CLAUDE.md '## Testing' line not found"; return 1; }
  [ -n "$cflow_line" ] || { echo "CLAUDE.md '## Contribution flow' line not found"; return 1; }
  if [ "$testing_line" -ge "$cflow_line" ]; then
    echo "CLAUDE.md '## Testing' must precede '## Contribution flow' (testing@$testing_line cflow@$cflow_line)"
    return 1
  fi
  echo "CLAUDE.md testing section"
}

# Step 5 — R8 commit-message rule single-source.
# Per-site fingerprints (each empirically pre-fix, byte-exact post-fix). Canonical short-form
# at CLAUDE.md preserved unchanged. Five collapsed sites verified per-site.
check_r8_single_source() {
  local fail=0
  local codex="agents/developer-codex.md"
  local devwf="skills/feature/references/developer-workflow.md"
  local pub="skills/cross-audit/references/publish.md"
  local cqr="skills/feature/references/code-quality-rules.md"
  local claude="CLAUDE.md"
  for f in "$codex" "$devwf" "$pub" "$cqr" "$claude"; do
    [ -f "$f" ] || { echo "missing $f"; return 1; }
  done
  # Negative — pre-fix per-site fingerprints all gone.
  if grep -qF '**No KB references in the commit message** — no KB paths' "$codex"; then
    echo "developer-codex.md still has pre-fix R8 restatement"
    fail=1
  fi
  if grep -qF '**No `Co-authored-by` lines.** **No KB references** — KB paths' "$devwf"; then
    echo "developer-workflow.md L62 still has pre-fix R8 restatement"
    fail=1
  fi
  if grep -qF '**Commit messages** — concise, imperative mood. No `Co-authored-by` lines. **No KB references**' "$devwf"; then
    echo "developer-workflow.md L115 still has pre-fix R8 restatement"
    fail=1
  fi
  if grep -qF 'Finding bodies posted via this flow appear in the public PR review thread of `<pr_repo>`' "$pub"; then
    echo "publish.md still has pre-fix long R8 restatement"
    fail=1
  fi
  # Positive — canonical short-form preserved at CLAUDE.md.
  if ! grep -qF '### Public-output hygiene (R8)' "$claude"; then
    echo "CLAUDE.md missing canonical short-form heading '### Public-output hygiene (R8)'"
    fail=1
  fi
  if ! grep -qF 'MUST NOT reference KB paths (`<kb>/...`)' "$claude"; then
    echo "CLAUDE.md missing canonical short-form fingerprint 'MUST NOT reference KB paths (\`<kb>/...\`)'"
    fail=1
  fi
  # Positive — canonical R8 in code-quality-rules.md preserved (different phrasing by design).
  if ! grep -qF '## R8 — Public-output hygiene (no KB leaks)' "$cqr"; then
    echo "code-quality-rules.md missing canonical R8 heading"
    fail=1
  fi
  if ! grep -qF 'MUST NOT appear in any public artifact' "$cqr"; then
    echo "code-quality-rules.md missing canonical R8 fingerprint 'MUST NOT appear in any public artifact'"
    fail=1
  fi
  # Positive — CLAUDE.md relative-position invariant.
  local r8_line skip_line
  r8_line=$(awk '/^### Public-output hygiene/{print NR; exit}' "$claude")
  skip_line=$(awk '/^### When to skip the flow/{print NR; exit}' "$claude")
  [ -n "$r8_line" ] || { echo "CLAUDE.md '### Public-output hygiene' line not found"; fail=1; }
  [ -n "$skip_line" ] || { echo "CLAUDE.md '### When to skip the flow' line not found"; fail=1; }
  if [ -n "$r8_line" ] && [ -n "$skip_line" ] && [ "$r8_line" -ge "$skip_line" ]; then
    echo "CLAUDE.md '### Public-output hygiene' must precede '### When to skip the flow' (R8@$r8_line skip@$skip_line)"
    fail=1
  fi
  # Positive — per-site byte-exact pointers (iter2 iH2A correction).
  if ! grep -qF 'R8 hygiene applies — see R8 in `skills/feature/references/code-quality-rules.md`.' "$codex"; then
    echo "developer-codex.md missing byte-exact pointer literal"
    fail=1
  fi
  if ! grep -qF 'R8 hygiene applies (no KB refs / no `Co-authored-by`) — see R8 in `code-quality-rules.md`.' "$devwf"; then
    echo "developer-workflow.md L62-site missing byte-exact pointer literal"
    fail=1
  fi
  if ! grep -qF 'R8 hygiene applies — see R8 in `code-quality-rules.md`.' "$devwf"; then
    echo "developer-workflow.md L115-site missing byte-exact pointer literal"
    fail=1
  fi
  if ! grep -qF '**R8 — Public-output hygiene (no KB leaks).** See R8 in `code-quality-rules.md`.' "$devwf"; then
    echo "developer-workflow.md L172-site missing byte-exact peer-shaped pointer literal"
    fail=1
  fi
  if ! grep -qF '### Public-output hygiene (R8)' "$pub"; then
    echo "publish.md missing preserved heading anchor"
    fail=1
  fi
  if ! grep -qF 'R8 applies' "$pub"; then
    echo "publish.md missing 'R8 applies' pointer literal"
    fail=1
  fi
  if ! grep -qF 'code-quality-rules.md' "$pub"; then
    echo "publish.md missing pointer to code-quality-rules.md"
    fail=1
  fi
  # Positive — peer-list symmetry preserved at L172 site.
  if ! grep -qF '**R8 — Public-output hygiene (no KB leaks).**' "$devwf"; then
    echo "developer-workflow.md missing peer-list anchor '**R8 — Public-output hygiene (no KB leaks).**'"
    fail=1
  fi
  [ "$fail" = "0" ] || return 1
  echo "R8 single source"
}

# Step 6 — SKILL.md cross-auditor spawn parameter block single-source via delta.
# Canonical at §Code audit Pass 2 preserved with byte-exact backticks.
# Spec-audit Pass 2 spawn block rewritten as delta. Three pointer sites total post-fix.
check_skill_dispatch_param_block_single_source() {
  local f="skills/feature/SKILL.md"
  [ -f "$f" ] || { echo "$f missing"; return 1; }
  # Canonical preserved with byte-exact backticks.
  if ! grep -qF 'Spawn `cross-auditor` with mode: full on the diff (dual-model). Parameters:' "$f"; then
    echo "SKILL.md missing canonical Code-audit Pass 2 spawn header literal (with backticks)"
    return 1
  fi
  # Spec-mode delta presence.
  if ! grep -qF 'same parameter block as the initial full-mode spawn' "$f"; then
    echo "SKILL.md missing spec-mode delta phrase 'same parameter block as the initial full-mode spawn'"
    return 1
  fi
  # Exact-3 threshold post-fix (L460-region delta + L774 + L937-equivalent).
  local cnt
  cnt=$(grep -cF 'same parameter block as the initial full-mode spawn' "$f")
  if [ "$cnt" != "3" ]; then
    echo "SKILL.md 'same parameter block as the initial full-mode spawn' count != 3 (got $cnt)"
    return 1
  fi
  # Negative — spec-audit Pass 2 region no longer contains the pre-fix 12-line spawn block.
  # Bound: between '#### Pass 2: Cross-audit (dual-model)' and '**If CRITICAL or HIGH findings:**'.
  local p2_region
  p2_region=$(awk '/^#### Pass 2: Cross-audit \(dual-model\)/{in_r=1; next} /^\*\*If CRITICAL or HIGH findings:\*\*/{in_r=0} in_r' "$f")
  [ -n "$p2_region" ] || { echo "SKILL.md §3.5 Pass 2 region empty"; return 1; }
  if printf '%s' "$p2_region" | grep -qF -e '- `scope`: `<spec_path>` (the spec file)'; then
    echo "SKILL.md §3.5 Pass 2 region still contains pre-fix 12-line spawn block bullet"
    return 1
  fi
  echo "dispatch param single source"
}

# Step 7 — evidence_class binary emit allowlist single-source.
# Canonical at agents/cross-auditor.md L410-L417 preserved (heading + binary-allowlist line +
# orchestrator-only exclusion sentence). SKILL.md restatement at L511 collapsed; stale L382-383
# numeric ref at L517 stripped; cross-field invariant body preserved.
check_evidence_class_allowlist_single_source() {
  local skl="skills/feature/SKILL.md"
  local ca="agents/references/cross-auditor-evidence-handshake.md"
  [ -f "$skl" ] || { echo "$skl missing"; return 1; }
  [ -f "$ca" ] || { echo "$ca missing"; return 1; }
  # Positive — canonical preserved at cross-auditor.md.
  if ! grep -qF '### When to set' "$ca"; then
    echo "cross-auditor.md missing '### When to set' heading"
    return 1
  fi
  if ! grep -qF 'binary on whether Codex'\''s audit was usable' "$ca"; then
    echo "cross-auditor.md missing canonical binary-allowlist phrase 'binary on whether Codex'\''s audit was usable'"
    return 1
  fi
  if ! grep -qF 'The cross-auditor NEVER writes `self_fallback`, `contract_violated`, or `skipped`' "$ca"; then
    echo "cross-auditor.md missing canonical orchestrator-only exclusion sentence"
    return 1
  fi
  # Negative — SKILL.md backticked allowlist clause gone.
  if grep -qF 'cross-auditor never writes `self_fallback` / `contract_violated` / `skipped`' "$skl"; then
    echo "SKILL.md still contains backticked allowlist clause that must collapse to pointer"
    return 1
  fi
  # Negative — stale line ref gone.
  if grep -qF '§When to set L382-383' "$skl"; then
    echo "SKILL.md still contains stale '§When to set L382-383' line ref"
    return 1
  fi
  # Positive — pointer presence at L511 + L517 (≥ 2 sites).
  local p1 p2
  p1=$(grep -cF 'agents/cross-auditor.md' "$skl")
  p2=$(grep -cF '§When to set' "$skl")
  if [ "$p1" -lt 2 ]; then
    echo "SKILL.md must point at agents/cross-auditor.md from at least 2 sites (got $p1)"
    return 1
  fi
  if [ "$p2" -lt 2 ]; then
    echo "SKILL.md must reference §When to set from at least 2 sites (got $p2)"
    return 1
  fi
  # Positive — cross-field invariant body preserved.
  if ! grep -qF '`evidence_class: dual_model` MUST pair with `evidence_blockers: []`' "$skl"; then
    echo "SKILL.md missing cross-field invariant body 'evidence_class: dual_model MUST pair with evidence_blockers: []'"
    return 1
  fi
  if ! grep -qF '`evidence_class: single_model` MUST pair with a non-empty `evidence_blockers` list' "$skl"; then
    echo "SKILL.md missing cross-field invariant body 'evidence_class: single_model MUST pair with non-empty evidence_blockers'"
    return 1
  fi
  echo "evidence_class allowlist single source"
}

# Step 8 — EOF-adjacency / spec-mode parser single-source.
# Canonical at agents/references/cross-auditor-evidence-handshake.md preserved
# (heading + producer-side 'forgotten-footer-with-example-echo' token at the
# closing parser-rationale paragraph). SKILL.md §3.5b producer-prose duplicate
# stays collapsed to the doc pointer. Code-audit iter-1 X3 reconciliation:
# the §3.5b spec-mode READ path no longer carries the inline `tail -3` shell
# snippet — the runtime classifier `hooks/lib/check_dispatch_response.py` is
# the single authoritative consumer-side parser — so the four consumer-shell
# variable literals and the inline routing-blocker phrasing are no longer
# pinned here; the classifier-delegation prose is pinned instead.
check_eof_adjacency_parser_single_source() {
  local skl="skills/feature/SKILL.md"
  local ca="agents/references/cross-auditor-evidence-handshake.md"
  [ -f "$skl" ] || { echo "$skl missing"; return 1; }
  [ -f "$ca" ] || { echo "$ca missing"; return 1; }
  # Positive — canonical preserved at cross-auditor-evidence-handshake.md.
  if ! grep -qF '### Spec-mode return contract' "$ca"; then
    echo "cross-auditor-evidence-handshake.md missing '### Spec-mode return contract' heading"
    return 1
  fi
  if ! grep -qF 'forgotten-footer-with-example-echo' "$ca"; then
    echo "cross-auditor-evidence-handshake.md missing producer-side 'forgotten-footer-with-example-echo' token"
    return 1
  fi
  # Negative — SKILL.md duplicate prose gone (byte-exact SKILL.md-resident fingerprint).
  if grep -qF 'the prior parser shape, which stripped blank lines' "$skl"; then
    echo "SKILL.md still contains pre-fix duplicate-prose fingerprint 'the prior parser shape, which stripped blank lines'"
    return 1
  fi
  # Positive — UNIQUELY-NEW pointer to the producer-side contract present.
  if ! grep -qF 'parse per `agents/references/cross-auditor-evidence-handshake.md` §Spec-mode return contract' "$skl"; then
    echo "SKILL.md missing UNIQUELY-NEW pointer literal 'parse per agents/references/cross-auditor-evidence-handshake.md §Spec-mode return contract'"
    return 1
  fi
  # Positive (X3 reconciliation) — the §3.5b spec-mode READ path delegates the
  # consumer-side parser to the runtime classifier; the superseded inline
  # `tail -3` shell snippet was removed.
  if ! grep -qF 'hooks/lib/check_dispatch_response.py --mode spec' "$skl"; then
    echo "SKILL.md §3.5b spec-mode READ path must delegate to 'hooks/lib/check_dispatch_response.py --mode spec' (X3 reconciliation)"
    return 1
  fi
  echo "eof-adjacency parser single source (consumer parser delegated to classifier)"
}

# --- cap-banner + empirical-verification (spec 2026-05-13) Step 5 pins ---
# 3 pins anchoring the prose surfaces from Steps 1-3 of
# design/2026-05-13-cap-banner-and-empirical-verification.md:
#   Pin A — agents/cross-auditor.md + agents/references/cross-auditor-codex-dispatch.md
#           (Step 2.5 H2 + load-bearing invariant + 2 Codex prompt templates).
#   Pin B — skills/feature/SKILL.md §3.5c AWAITING-YOUR-INPUT cap-banner block.
#   Pin C — <kb>/repos/ai-dev-team/MISSION.md rule #11 amendment + new rule #13.
#   (Pin D — R15 frontmatter/body placement — retired 2026-05-25 alongside R15 itself.)

check_cross_auditor_empirical_verification_step_present() {
  local hub="agents/cross-auditor.md"
  local codex_ref="agents/references/cross-auditor-codex-dispatch.md"
  test -f "$hub" || { echo "$hub missing"; return 1; }
  test -f "$codex_ref" || { echo "$codex_ref missing"; return 1; }

  # Structural H2 anchor — column-0 heading literal.
  if ! grep -qxF '## Step 2.5: Empirical claim verification' "$hub"; then
    echo "$hub missing column-0 H2 '## Step 2.5: Empirical claim verification'"
    return 1
  fi

  # Load-bearing invariant — byte-exact substring (no backticks, no bold markers
  # in the asserted substring — the source line wraps it in **...** which leaves
  # this raw substring intact between the bold delimiters).
  local invariant='NEVER emit a HIGH or CRITICAL finding whose file:line claim has not been empirically verified at audit-emit time'
  if ! grep -qF "$invariant" "$hub"; then
    echo "$hub missing load-bearing invariant literal '$invariant'"
    return 1
  fi

  # Codex prompt verification line — must appear AT LEAST 2 times (one per
  # template: Code-mode + Spec-mode).
  local codex_line="Before reporting any finding, verify the file:line claim by re-reading the actual content at the named line. On mismatch, downgrade to MEDIUM with a 'verification mismatch' note or omit the finding entirely."
  local n
  n=$(grep -cF "$codex_line" "$codex_ref" || true)
  if [ "$n" -lt 2 ]; then
    echo "$codex_ref contains the verification-instruction line $n times, expected >= 2 (Code-mode + Spec-mode)"
    return 1
  fi

  echo "cross-auditor empirical-verification: Step 2.5 H2 + invariant + codex-dispatch verification line x$n OK"
}

check_skill_md_cap_banner_present() {
  local skl="skills/feature/SKILL.md"
  test -f "$skl" || { echo "$skl missing"; return 1; }

  # Slice §3.5c — from the subsection heading down to the next H2 `## Implement`.
  # Terminating on the next H2 (NOT on `^---$`) is load-bearing: the cap-banner
  # block itself contains internal `---` separators per the AWAITING YOUR INPUT
  # convention, so a `^---$` terminator would stop BEFORE reaching the banner.
  local section
  section=$(awk '/### 3.5c Stop criteria/,/^## Implement/' "$skl")
  if [ -z "$section" ]; then
    echo "$skl: awk range from '### 3.5c Stop criteria' to '^## Implement' produced empty output"
    return 1
  fi

  # Banner H2 — column-0 heading literal.
  if ! printf '%s\n' "$section" | grep -qxF '## ⏸ AWAITING YOUR INPUT'; then
    echo "$skl §3.5c missing column-0 H2 '## ⏸ AWAITING YOUR INPUT'"
    return 1
  fi

  # Banner title literal.
  if ! printf '%s\n' "$section" | grep -qF 'Audit iteration cap reached'; then
    echo "$skl §3.5c missing 'Audit iteration cap reached' banner title"
    return 1
  fi

  # 4 option literals — all must appear inside §3.5c.
  local opt
  for opt in 'Continue with justification' 'Accept residue with explicit sign-off' 'Scope-cut' 'Abandon'; do
    if ! printf '%s\n' "$section" | grep -qF "$opt"; then
      echo "$skl §3.5c missing banner option literal '$opt'"
      return 1
    fi
  done

  echo "SKILL.md §3.5c cap banner OK (H2 + title + 4 options inside §3.5c)"
}

check_mission_rule_11_amended_and_audit_claims_rule_present() {
  # MISSION.md lives in the KB, outside the plugin checkout. Resolve via the
  # same convention as check_mission_r_enforcement_claim_narrow above:
  # KB_PATH env var → sibling finance-learning path → plugin-root fallback.
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

  # Rule #13 anchor literal.
  if ! grep -qF 'Audit claims MUST be empirically verifiable' "$mission_path"; then
    echo "$mission_path missing rule #13 anchor 'Audit claims MUST be empirically verifiable'"
    return 1
  fi

  # Rule #11 amended phase-split clause — the AWAITING YOUR INPUT phase-split
  # reference. Both substrings must appear (one line carries both; we assert
  # presence rather than co-location to keep the pin robust to future wording
  # tweaks within the rule body).
  if ! grep -qF 'the orchestrator presents the' "$mission_path"; then
    echo "$mission_path missing rule #11 'the orchestrator presents the' phase-split prefix"
    return 1
  fi
  if ! grep -qF 'AWAITING YOUR INPUT' "$mission_path"; then
    echo "$mission_path missing 'AWAITING YOUR INPUT' banner reference"
    return 1
  fi
  if ! grep -qF 'cap banner per SKILL.md §3.5c' "$mission_path"; then
    echo "$mission_path missing 'cap banner per SKILL.md §3.5c' phrase"
    return 1
  fi

  # 2026-05-13 dated entry — count >= 1 (NOT exactly 1; rule #13 Source line
  # also contains this literal in the retrospective filename anchor).
  local n
  n=$(grep -cF '2026-05-13' "$mission_path" || true)
  if [ "$n" -lt 1 ]; then
    echo "$mission_path: '2026-05-13' literal count=$n, expected >= 1"
    return 1
  fi

  echo "MISSION rule #11 amended + rule #13 + 2026-05-13 entry (count=$n) OK"
}

# Behavioral pin for the cross-auditor return-contract classifier
# (`hooks/lib/check_dispatch_response.py`). Iterates every sub-fixture under
# tests/fixtures/cross-audit-contract-gate/*/*/ (27 directories per spec
# 2026-05-15-cross-auditor-contract-gate-automation §3.3.1 — 21 baseline +
# 6 X1 malformed-blockers sub-fixtures from code-audit iter-1), invokes the
# helper as a black box, and asserts:
#   (a) helper exit code matches meta.yml `expected_exit`;
#   (b) helper stdout JSON `classification` matches meta.yml
#       `expected_classification`;
#   (c) for CLEAN_DUAL / CLEAN_SINGLE fixtures: JSON `evidence_class` is
#       non-null and `blockers_yaml` is a valid YAML-list literal;
#   (d) the two policy-gate fixtures (invoked with / without
#       `--project ai-dev-team`) emit the correct `policy_gate` value.
check_dispatch_response_classification() {
  local helper="$PLUGIN_ROOT/hooks/lib/check_dispatch_response.py"
  local fixture_root="$PLUGIN_ROOT/tests/fixtures/cross-audit-contract-gate"
  if [ ! -f "$helper" ]; then
    echo "classifier helper missing: $helper"
    return 1
  fi
  if [ ! -d "$fixture_root" ]; then
    echo "fixture root missing: $fixture_root"
    return 1
  fi
  local d meta mode expected_class expected_exit project
  local expected_model_arg expected_model_gate expected_claude_model
  local require_rules_arg expected_rules_gate expected_rules_loaded expected_rules_reason
  local out_file rc got_class checked=0
  out_file=$(mktemp) || return 1
  for d in "$fixture_root"/*/*/; do
    meta="$d/meta.yml"
    if [ ! -f "$meta" ] || [ ! -f "$d/raw-response.txt" ]; then
      echo "sub-fixture $d missing meta.yml or raw-response.txt"
      rm -f "$out_file"
      return 1
    fi
    mode=$(sed -n 's/^mode: *//p' "$meta")
    expected_class=$(sed -n 's/^expected_classification: *//p' "$meta")
    expected_exit=$(sed -n 's/^expected_exit: *//p' "$meta")
    # Three OPTIONAL model-attestation meta keys (absent in the 43 legacy
    # fixtures). `expected_claude_model_arg` drives the `--expected-claude-model`
    # flag (threaded into ALL FOUR invocation arms via the `extra_args` shell
    # array below — a single-arm patch would silently under-test one mode);
    # `expected_model_gate` / `expected_claude_model` are asserted
    # UNCONDITIONALLY in the python block (absent -> null), so the flag cannot
    # leak into a legacy CLEAN fixture and silently return MISSING.
    expected_model_arg=$(sed -n 's/^expected_claude_model_arg: *//p' "$meta")
    expected_model_gate=$(sed -n 's/^expected_model_gate: *//p' "$meta")
    expected_claude_model=$(sed -n 's/^expected_claude_model: *//p' "$meta")
    # Three OPTIONAL audited-HEAD meta keys (spec 2026-07-05 §3.2; absent in the
    # legacy fixtures). `expected_head_arg` drives the `--expected-head` flag,
    # threaded into ALL invocation arms alongside the model flag; a single-arm
    # patch would silently under-test one mode. `expected_head_gate` /
    # `expected_audited_head` are asserted UNCONDITIONALLY in the python block
    # (absent -> null), so the flag cannot leak into a legacy CLEAN fixture and
    # silently return HEAD_ATTESTATION_MISSING.
    expected_head_arg=$(sed -n 's/^expected_head_arg: *//p' "$meta")
    expected_head_gate=$(sed -n 's/^expected_head_gate: *//p' "$meta")
    expected_audited_head=$(sed -n 's/^expected_audited_head: *//p' "$meta")
    # Four OPTIONAL rules-loaded meta keys (spec 2026-07-05 §3.2; absent in the
    # legacy fixtures). `require_rules_arg: true` drives the BARE value-less
    # `--require-rules-loaded` flag (UNLIKE the head/model value flags — no
    # "$val" companion), threaded into every invocation arm. `expected_rules_gate`
    # / `expected_rules_loaded` / `expected_rules_reason` are asserted
    # UNCONDITIONALLY in the python block (absent -> null), so the flag cannot
    # leak into a legacy CLEAN fixture and silently return RULES_ATTESTATION_MISSING.
    require_rules_arg=$(sed -n 's/^require_rules_arg: *//p' "$meta")
    expected_rules_gate=$(sed -n 's/^expected_rules_gate: *//p' "$meta")
    expected_rules_loaded=$(sed -n 's/^expected_rules_loaded: *//p' "$meta")
    expected_rules_reason=$(sed -n 's/^expected_rules_reason: *//p' "$meta")
    local extra_args=()
    if [ -n "$expected_model_arg" ]; then
      extra_args+=(--expected-claude-model "$expected_model_arg")
    fi
    if [ -n "$expected_head_arg" ]; then
      extra_args+=(--expected-head "$expected_head_arg")
    fi
    if [ "$require_rules_arg" = "true" ]; then
      extra_args+=(--require-rules-loaded)
    fi
    # Policy-gate fixtures: invoked WITH `--project ai-dev-team`. The
    # spec-mode CLEAN_SINGLE variant pins the isolated policy gate; the
    # code-mode `head-cofire` variant pins policy_gate + head_gate firing
    # simultaneously in one JSON (independent computation). Threaded into every
    # mode via `extra_args` — the consumer variant omits the flag.
    project=""
    case "$d" in
      *clean-single-policy-gate-ai-dev-team/*|*clean-single-policy-gate-head-cofire/*)
        project="ai-dev-team" ;;
    esac
    if [ -n "$project" ]; then
      extra_args+=(--project "$project")
    fi
    # findings-missing/code/ deliberately lacks findings.md — the (absent) path
    # is passed verbatim so the absence triggers FINDINGS_MISSING.
    if [ "$mode" = "code" ] || [ "$mode" = "full" ]; then
      python3 "$helper" --mode "$mode" \
        --raw-response-file "$d/raw-response.txt" \
        --audit-slug "fixture-$expected_class" --iteration 1 \
        --findings-path "$d/findings.md" \
        ${extra_args[@]+"${extra_args[@]}"} >"$out_file" 2>/dev/null
      rc=$?
    else
      python3 "$helper" --mode "$mode" \
        --raw-response-file "$d/raw-response.txt" \
        --audit-slug "fixture-$expected_class" --iteration 1 \
        ${extra_args[@]+"${extra_args[@]}"} >"$out_file" 2>/dev/null
      rc=$?
    fi
    if [ "$rc" != "$expected_exit" ]; then
      echo "sub-fixture $d: exit $rc, expected $expected_exit"
      rm -f "$out_file"
      return 1
    fi
    # Assert classification + (conditional) CLEAN_* + policy-gate fields via
    # python3 reading the JSON from a file (embedded newlines in the
    # newline-unsafe fixture mean a shell-variable round-trip would corrupt
    # the payload — read straight from disk).
    if ! python3 - "$out_file" "$expected_class" "$d" "$project" \
        "$expected_model_gate" "$expected_claude_model" \
        "$expected_head_gate" "$expected_audited_head" \
        "$expected_rules_gate" "$expected_rules_loaded" \
        "$expected_rules_reason" <<'PY'
import json
import sys

(out_file, expected_class, fixture_dir, project,
 expected_model_gate, expected_claude_model,
 expected_head_gate, expected_audited_head,
 expected_rules_gate, expected_rules_loaded,
 expected_rules_reason) = sys.argv[1:12]
try:
    with open(out_file, "r", encoding="utf-8") as fh:
        j = json.load(fh)
except (OSError, ValueError) as exc:
    print(f"sub-fixture {fixture_dir}: classifier output not valid JSON: "
          f"{exc}")
    sys.exit(1)

got = j.get("classification")
if got != expected_class:
    print(f"sub-fixture {fixture_dir}: classification {got!r}, "
          f"expected {expected_class!r}")
    sys.exit(1)

if expected_class in ("CLEAN_DUAL", "CLEAN_SINGLE"):
    if j.get("evidence_class") is None:
        print(f"sub-fixture {fixture_dir}: CLEAN_* but evidence_class is null")
        sys.exit(1)
    by = j.get("blockers_yaml")
    if not isinstance(by, str) or not (by.startswith("[")
                                       and by.endswith("]")):
        print(f"sub-fixture {fixture_dir}: blockers_yaml not a list literal: "
              f"{by!r}")
        sys.exit(1)

# Policy-gate assertion: ai-dev-team CLEAN_SINGLE -> STOP_AND_DISCUSS;
# consumer CLEAN_SINGLE -> null.
if "clean-single-policy-gate" in fixture_dir:
    pg = j.get("policy_gate")
    if project == "ai-dev-team":
        if pg != "STOP_AND_DISCUSS":
            print(f"sub-fixture {fixture_dir}: policy_gate {pg!r}, "
                  f"expected STOP_AND_DISCUSS")
            sys.exit(1)
    else:
        if pg is not None:
            print(f"sub-fixture {fixture_dir}: policy_gate {pg!r}, "
                  f"expected null")
            sys.exit(1)

# Model-attestation assertions (UNCONDITIONAL for every fixture, legacy
# included). The meta keys are optional shell vars: an empty string means the
# key was absent -> expected null. `expected_model_gate` guards against the
# flag leaking into legacy CLEAN fixtures (would silently return MISSING);
# `expected_claude_model` pins the informational parse value (an impl that
# computes model_gate but mis-emits claude_model is caught here).
want_gate = None if expected_model_gate in ("", "null") else expected_model_gate
got_gate = j.get("model_gate")
if got_gate != want_gate:
    print(f"sub-fixture {fixture_dir}: model_gate {got_gate!r}, "
          f"expected {want_gate!r}")
    sys.exit(1)

want_model = (None if expected_claude_model in ("", "null")
              else expected_claude_model)
got_model = j.get("claude_model")
if got_model != want_model:
    print(f"sub-fixture {fixture_dir}: claude_model {got_model!r}, "
          f"expected {want_model!r}")
    sys.exit(1)

# Audited-HEAD assertions (UNCONDITIONAL for every fixture, legacy included).
# The meta keys are optional shell vars: an empty string means the key was
# absent -> expected null. `expected_head_gate` guards against the flag leaking
# into legacy CLEAN fixtures (would silently return HEAD_ATTESTATION_MISSING)
# AND pins the co-fire independence (policy/model gate firing does NOT suppress
# head_gate); `expected_audited_head` pins the informational parse value (an
# impl that computes head_gate but mis-emits audited_head — or drops it on a
# violation classification — is caught here).
want_head_gate = (None if expected_head_gate in ("", "null")
                  else expected_head_gate)
got_head_gate = j.get("head_gate")
if got_head_gate != want_head_gate:
    print(f"sub-fixture {fixture_dir}: head_gate {got_head_gate!r}, "
          f"expected {want_head_gate!r}")
    sys.exit(1)

want_head = (None if expected_audited_head in ("", "null")
             else expected_audited_head)
got_head = j.get("audited_head")
if got_head != want_head:
    print(f"sub-fixture {fixture_dir}: audited_head {got_head!r}, "
          f"expected {want_head!r}")
    sys.exit(1)

# Rules-loaded assertions (UNCONDITIONAL for every fixture, legacy included).
# The meta keys are optional shell vars: an empty string means the key was
# absent -> expected null. `expected_rules_gate` guards against the flag leaking
# into legacy CLEAN fixtures (would silently return RULES_ATTESTATION_MISSING)
# AND pins the co-fire independence (policy/model/head gate firing does NOT
# suppress rules_gate); `expected_rules_loaded` / `expected_rules_reason` pin
# the informational parse values (an impl that computes rules_gate but mis-emits
# rules_loaded, or fails to unquote rules_reason, is caught here).
want_rules_gate = (None if expected_rules_gate in ("", "null")
                   else expected_rules_gate)
got_rules_gate = j.get("rules_gate")
if got_rules_gate != want_rules_gate:
    print(f"sub-fixture {fixture_dir}: rules_gate {got_rules_gate!r}, "
          f"expected {want_rules_gate!r}")
    sys.exit(1)

if expected_rules_loaded in ("", "null"):
    want_rules_loaded = None
elif expected_rules_loaded == "true":
    want_rules_loaded = True
elif expected_rules_loaded == "false":
    want_rules_loaded = False
else:
    want_rules_loaded = expected_rules_loaded
got_rules_loaded = j.get("rules_loaded")
if got_rules_loaded != want_rules_loaded:
    print(f"sub-fixture {fixture_dir}: rules_loaded {got_rules_loaded!r}, "
          f"expected {want_rules_loaded!r}")
    sys.exit(1)

want_rules_reason = (None if expected_rules_reason in ("", "null")
                     else expected_rules_reason)
got_rules_reason = j.get("rules_reason")
if got_rules_reason != want_rules_reason:
    print(f"sub-fixture {fixture_dir}: rules_reason {got_rules_reason!r}, "
          f"expected {want_rules_reason!r}")
    sys.exit(1)
PY
    then
      rm -f "$out_file"
      return 1
    fi
    checked=$((checked + 1))
  done
  rm -f "$out_file"
  if [ "$checked" != "70" ]; then
    echo "expected 70 sub-fixtures, checked $checked"
    return 1
  fi
  echo "dispatch-response classifier: 70/70 sub-fixtures classified correctly"
}

# Behavioral pin for the classifier's enum -> violation-blocker phrasing
# (code-audit iter-1 X2 fix). The §3.5b-2b retry-outcome matrix records the
# classifier JSON `violation_blocker` string in `*_audit_blockers` for a
# contract_violated outcome — so every one of the 10 violation classes MUST
# emit a specific, non-empty, canonical blocker string (and the 2 clean
# classes MUST emit `violation_blocker: null`). This pin is an INDEPENDENT
# oracle: the 10 expected (classification, violation_blocker) pairs below are
# hard-coded here, NOT derived from the classifier's VIOLATION_BLOCKERS dict,
# so a regression that silently changes a phrasing is caught.
check_dispatch_response_violation_blocker_mapping() {
  local helper="$PLUGIN_ROOT/hooks/lib/check_dispatch_response.py"
  local fxroot="$PLUGIN_ROOT/tests/fixtures/cross-audit-contract-gate"
  if [ ! -f "$helper" ]; then
    echo "classifier helper missing: $helper"
    return 1
  fi
  # Each row: <fixture-slug>/<mode> | <expected classification> |
  # <expected violation_blocker>. One fixture per violation class — the
  # mode is whichever the fixture provides. Three classes carry a templated
  # slot the classifier fills from the fixture's offending value:
  # FINDINGS_MISSING -> <path> (FINDINGS_MISSING_PATH sentinel below);
  # EVIDENCE_CLASS_DISALLOWED -> the sanitized disallowed evidence_class;
  # DUAL_MODEL_WITH_BLOCKERS -> the sanitized offending blockers_yaml literal.
  local rows='missing-footer/spec|MISSING_FOOTER|cross-auditor return missing evidence_class footer line
malformed-footer-evidence-class/spec|MALFORMED_FOOTER_EVIDENCE_CLASS|cross-auditor return malformed evidence_class footer
malformed-footer-evidence-blockers/spec|MALFORMED_FOOTER_EVIDENCE_BLOCKERS|cross-auditor return malformed evidence_blockers footer
findings-missing/code|FINDINGS_MISSING|FINDINGS_MISSING_PATH
findings-malformed/code|FINDINGS_MALFORMED|cross-auditor findings.md frontmatter malformed
blocker-yaml-unsafe-apostrophe/spec|BLOCKER_YAML_UNSAFE_APOSTROPHE|evidence_blockers entry failed YAML-safety validation: unescaped apostrophe
blocker-yaml-unsafe-newline/spec|BLOCKER_YAML_UNSAFE_NEWLINE|evidence_blockers entry failed YAML-safety validation: embedded newline
evidence-class-disallowed/spec|EVIDENCE_CLASS_DISALLOWED|cross-auditor emitted disallowed evidence_class value: contract_violated
dual-model-with-blockers/spec|DUAL_MODEL_WITH_BLOCKERS|cross-auditor emitted dual_model with non-empty evidence_blockers: ['"'"''"'"'something'"'"''"'"']
single-model-without-blockers/spec|SINGLE_MODEL_WITHOUT_BLOCKERS|cross-auditor emitted single_model with empty evidence_blockers'
  local out_file count=0 line slug mode expect_class expect_blocker
  out_file=$(mktemp) || return 1
  while IFS='|' read -r slug expect_class expect_blocker; do
    [ -z "$slug" ] && continue
    mode="${slug##*/}"
    local d="$fxroot/${slug%/*}/$mode/"
    if [ "$mode" = "code" ]; then
      if [ -f "${d}findings.md" ]; then
        python3 "$helper" --mode "$mode" \
          --raw-response-file "${d}raw-response.txt" --audit-slug fx \
          --iteration 1 --findings-path "${d}findings.md" \
          >"$out_file" 2>/dev/null
      else
        # findings-missing: pass the (absent) findings.md path verbatim so
        # the FINDINGS_MISSING <path> slot is filled deterministically.
        python3 "$helper" --mode "$mode" \
          --raw-response-file "${d}raw-response.txt" --audit-slug fx \
          --iteration 1 --findings-path "${d}findings.md" \
          >"$out_file" 2>/dev/null
      fi
    else
      python3 "$helper" --mode "$mode" \
        --raw-response-file "${d}raw-response.txt" --audit-slug fx \
        --iteration 1 >"$out_file" 2>/dev/null
    fi
    if ! python3 - "$out_file" "$expect_class" "$expect_blocker" "${d}findings.md" <<'PY'
import json
import sys

out_file, expect_class, expect_blocker, findings_path = sys.argv[1:5]
try:
    with open(out_file, "r", encoding="utf-8") as fh:
        j = json.load(fh)
except (OSError, ValueError) as exc:
    print(f"violation-blocker pin: classifier output not valid JSON for "
          f"{expect_class}: {exc}")
    sys.exit(1)
if j.get("classification") != expect_class:
    print(f"violation-blocker pin: classification {j.get('classification')!r}, "
          f"expected {expect_class!r}")
    sys.exit(1)
# FINDINGS_MISSING carries a <path> slot — expected is the resolved path.
if expect_blocker == "FINDINGS_MISSING_PATH":
    expect_blocker = f"findings.md missing at {findings_path}"
got = j.get("violation_blocker")
if got != expect_blocker:
    print(f"violation-blocker pin: {expect_class} violation_blocker {got!r}, "
          f"expected {expect_blocker!r}")
    sys.exit(1)
PY
    then
      rm -f "$out_file"
      return 1
    fi
    count=$((count + 1))
  done <<< "$rows"
  rm -f "$out_file"
  if [ "$count" != "10" ]; then
    echo "expected 10 violation classes pinned, checked $count"
    return 1
  fi
  echo "dispatch-response classifier: enum->violation_blocker mapping pinned for all 10 violation classes"
}

# Static lint: every `mktemp` invocation in the repo's shell scripts must be
# guarded and must never have a path segment appended to an unchecked
# `$(mktemp ...)`.
#
# This pin closes the destructive `rm -rf` class found multiple times in
# this file's lineage:
#   - X1 (iter-1): a deterministic real-path `rm -rf` triggered by `bash tests/smoke.sh`.
#   - X7 (iter-3): `d_co=$(mktemp -d)/co` with no success guard — on `mktemp`
#     failure `d_co` becomes the literal `/co`, and a downstream
#     `rm -rf "$(dirname "$d_co")"` resolves to `rm -rf /` during a routine
#     smoke run.
#   - X9 (iter-4): quoted/backtick assign forms + `|| true` non-guard bypassed
#     the original regex-cascade pin.
#   - X12 (iter-5): word-substring guard (`|| echo return`), path-qualified
#     mktemp (`$(/bin/mktemp -d)` and `$(command mktemp -d)`), and
#     multi-assignment-per-line (`a=$(mktemp); b=$(mktemp) || return 1`)
#     bypassed the X9-strengthened regexes.
#   - X13 (iter-5): pin scope was hardcoded to `tests/smoke-helpers.sh`;
#     other shell scripts (`tests/smoke.sh`, `hooks/lib/*.sh`) were not
#     subject to the regression backstop. The X1/X7 class could recur in
#     any of those files silently.
#
# What this lint scans for (the X1/X7 shape) is enumerated below as Shape A
# (appended-segment) and Shape B (unguarded assign-from-mktemp). The iter-5
# grammar redesign replaces the previous line-level regex-cascade with a
# per-segment scan: each line is split on top-level `;` (statement-
# separators, careful tokenizer honouring quotes / brace groups / parens
# so a `;` inside an `echo "see;comma"` string is NOT a separator) and each
# segment is independently checked for assign + guard. This rejects the
# X12 multi-assignment-per-line bypass. A shared `_MKTEMP` pattern matches
# bare `mktemp`, path-prefixed (`/usr/bin/mktemp`), and `command mktemp` —
# rejecting the X12 path-qualified bypass. The `||` guard is tokenized:
# a real guard's branch must be `return`/`exit` at branch position 0 (with
# an optional exit code) OR a brace group `{ ...; return|exit ...; }` whose
# FINAL statement is `return`/`exit` — rejecting the X12 word-substring
# bypass `|| echo return`, `|| echo "see return"`, and
# `|| echo failed; rm -rf "$d"; return 1` (the late `return` is a separate
# top-level statement, not in the `||` branch).
#
# Per-file safe-guard idiom dialect (Strategy A from the iter-5 X13 brief):
# `tests/smoke.sh` historically uses a two-line post-assignment guard idiom
#   tmpdir=$(mktemp -d 2>/dev/null || mktemp -d -t 'tag')
#   if [ -z "$tmpdir" ] || [ ! -d "$tmpdir" ]; then return 1; fi
# which is also a real guard for the same destructive class — the variable
# is checked for empty / non-directory immediately after the assignment and
# the failure path aborts. The lint accepts this idiom for files registered
# with the `z_postcheck` dialect. `tests/smoke-helpers.sh` and the
# `hooks/lib/*.sh` scripts use only the same-line `|| return` /
# `|| { ...; return; }` form (`same_line` dialect). The dialect is
# per-file: a future file that switches idioms must update its dialect
# in `_MKTEMP_LINT_SCOPE` below.
#
# _smoke_mktemp_lint_scan <file> [dialect] — single source of truth for the
# mktemp lint. dialect is `same_line` (default) or `z_postcheck`. Prints
# `ok` (exit 0) or the violation list (exit 1). Both the real pin and the
# lint's own self-test pin drive THIS function, so the negative fixtures
# exercise the exact grammar the real pin uses (R3/R6).
_smoke_mktemp_lint_scan() {
  SMOKE_LINT_TARGET="$1" SMOKE_LINT_DIALECT="${2:-same_line}" python3 <<'PY'
import os, re, sys

target = os.environ["SMOKE_LINT_TARGET"]
dialect = os.environ["SMOKE_LINT_DIALECT"]
with open(target, encoding="utf-8") as fh:
    lines = fh.readlines()

# Shared mktemp invocation pattern. Matches the bare `mktemp` token,
# optionally preceded by a run of bash command-prefix tokens that all
# legitimately execute mktemp:
#   - `env mktemp`, `eval mktemp`, `time mktemp`, `exec mktemp`,
#     `builtin mktemp`, `command mktemp`
#   - inline env-var assignments: `TMPDIR=/tmp mktemp`, `LC_ALL=C mktemp`,
#     and combinations (`env TMPDIR=/tmp mktemp`)
#   - alias-suppressing backslash: `\mktemp`
#   - explicit path: `/bin/mktemp`, `/usr/bin/mktemp`
# All these forms collapse to the same destructive poisoned-path shape on
# mktemp failure; the prefix vocabulary is admitted at the assignment
# recognizer level so the UNGUARDED-MKTEMP check (`VAR=$(<form>)` without
# a guard) catches each form. The APPENDED-SEGMENT check uses a DIFFERENT
# strategy (structural ban on `mktemp anywhere in subst body` + `/seg`
# after close) because the prefix vocabulary is unbounded in the wild;
# the structural anchor is the appended segment itself, not the prefix.
_MKTEMP_PREFIX_TOKEN = (
    r'(?:[A-Za-z_][A-Za-z0-9_]*=\S*|env|eval|time|exec|builtin|command)'
)
_MKTEMP_PREFIX = r'(?:' + _MKTEMP_PREFIX_TOKEN + r'\s+)*'
# `_MKTEMP_BODY` admits an optional path prefix (`/bin/mktemp`) AND an
# optional alias-suppressing backslash directly before `mktemp` (no
# whitespace between `\` and `mktemp` — bash treats `\mktemp` as one
# token).
_MKTEMP_BODY = r'(?:/[\w./-]+/)?\\?mktemp\b'
_MKTEMP = _MKTEMP_PREFIX + _MKTEMP_BODY

# A mktemp command substitution in either legal bash form:
#   - `$(...)` form (optionally surrounded by " or ' quotes)
#   - backtick `` `...` `` form (optionally quoted)
# The substitution body is `_MKTEMP` followed by any non-paren chars (or
# non-backtick chars in the backtick form).
_SUBST_DOLLAR = r'\$\(\s*' + _MKTEMP + r'[^()]*\)'
_SUBST_BACKTICK = r'`\s*' + _MKTEMP + r'[^`]*`'
_SUBST = r'(?:["\']?(?:' + _SUBST_DOLLAR + r'|' + _SUBST_BACKTICK + r')["\']?)'

# Shape A (iter-6 X14 structural defense): a path segment appended to a
# command substitution whose body contains the bare `mktemp` token
# ANYWHERE — regardless of preceding command-prefix tokens, regardless of
# any trailing `||` guard. The destructive class structurally requires
# (a) a substitution producing the mktemp output, (b) a `/seg` appended at
# substitution-close time; the prefix vocabulary the substitution body
# uses is irrelevant. The iter-5 `APPENDED` pattern required the body
# match `_MKTEMP` exactly, which the iter-6 X14 prefix-form bypass class
# evaded. The new shape: `$(...mktemp...)` or `` `...mktemp...` `` with
# `mktemp` as a whitespace-delimited token (also allowing a `/path/`
# prefix) followed (after the substitution close + optional quote) by
# `/`. A real `|| return` guard does NOT rescue this shape — the
# downstream `rm -rf "$(dirname "$VAR")"` still resolves to `/` because
# the appended segment poisons the LHS value regardless of whether the
# assignment was guarded.
# Inside the substitution body, the bare `mktemp` token may appear at the
# very start (`$(mktemp ...)`, `$(\mktemp ...)`) or after any
# whitespace-delimited prefix token run (`env mktemp`, `TMPDIR=/tmp
# mktemp`, etc). The simple, robust rule per the iter-6 structural-defense
# brief: a non-paren body that contains the `mktemp` token at a word
# boundary qualifies. The leading `(?:[^()]*?[\s/(])?` (lazy, optional)
# admits a prefix-token run or absence; the `mktemp\b` end-anchor ensures
# we don't accept identifier suffixes like `_mktemp`. The optional `\\?`
# absorbs the alias-suppression backslash.
_BARE_MKTEMP_IN_SUBST = r'(?:[^()]*?[\s/(])?\\?mktemp\b'
_APPENDED_SUBST_DOLLAR = (
    r'\$\(' + _BARE_MKTEMP_IN_SUBST + r'[^()]*\)'
)
# Backtick form: equivalent rule, but the open delimiter is a backtick
# (not `(`) and the body forbids backticks.
_BARE_MKTEMP_IN_BACKTICK = r'(?:[^`]*?[\s/`])?\\?mktemp\b'
_APPENDED_SUBST_BACKTICK = (
    r'`' + _BARE_MKTEMP_IN_BACKTICK + r'[^`]*`'
)
APPENDED = re.compile(
    r'(?:' + _APPENDED_SUBST_DOLLAR + r'|' + _APPENDED_SUBST_BACKTICK + r')["\']?/'
)

# Any assignment that captures mktemp output (quoted or unquoted, $() or
# backtick, with any prefix-vocabulary token admitted by `_MKTEMP`).
# Captures the LHS name so the post-assignment `[ -z ]` idiom recognizer
# can match the same variable later in the file.
ASSIGN = re.compile(
    r'(?:^|[;\s&|])([A-Za-z_][A-Za-z0-9_]*)='
    r'(?:["\']?\$\(\s*' + _MKTEMP + r'|["\']?`\s*' + _MKTEMP + r')'
)

# A `local`/`declare`/`readonly` prefix may sit between the `;` and the LHS
# of an assignment. We treat `local foo=$(mktemp ...)` the same as
# `foo=$(mktemp ...)` for guard purposes.
_KEYWORD_PREFIXES = ("local", "declare", "readonly", "export", "typeset")


def _strip_assign_prefix(segment):
    """Return the assignment-bearing tail of a segment.

    For `local foo=$(mktemp -d) || return 1` returns `foo=$(mktemp -d) || return 1`.
    For `foo=$(mktemp -d) || return 1` returns the same string unchanged.
    For a segment with no leading keyword, returns the input unchanged.
    """
    stripped = segment.lstrip()
    for kw in _KEYWORD_PREFIXES:
        if stripped.startswith(kw + " ") or stripped.startswith(kw + "\t"):
            return stripped[len(kw):].lstrip()
    return segment


def _strip_inline_comment(line):
    """Return `line` with any trailing `#`-introduced shell comment removed.

    iter-6 X16: a `#` outside single/double quotes AND outside `$(...)` /
    `` `...` `` / brace groups, when at line-start OR preceded by
    whitespace OR preceded by a shell metacharacter (`;`, `|`, `&`, `(`,
    `)`, `{`, `}`), starts a comment that runs to end-of-line. The lint
    parses each line for assign / guard; an unstripped `#` lets the
    literal `||` and `return` inside a comment falsely satisfy the abort
    check, even though bash never sees them.

    A `#` inside an unquoted word (`foo#bar`) is NOT a comment delimiter:
    it's part of the word. So the predicate is "previous char is none /
    whitespace / metachar".

    Heredoc bodies and `$'...'` ANSI-C strings are out of scope (X16
    finding tail flags them as latent risks; the current corpus does not
    exercise them).
    """
    n = len(line)
    i = 0
    prev = None  # the previous non-skipped character (None at line start)
    in_single = False
    in_double = False
    in_backtick = False
    paren_depth = 0
    brace_depth = 0
    metachars = ';|&(){}'
    while i < n:
        ch = line[i]
        if in_single:
            if ch == "'":
                in_single = False
            prev = ch
            i += 1
            continue
        if in_double:
            if ch == '\\' and i + 1 < n:
                # escaped char inside double quotes
                prev = line[i + 1]
                i += 2
                continue
            if ch == '"':
                in_double = False
            prev = ch
            i += 1
            continue
        if in_backtick:
            if ch == '`':
                in_backtick = False
            prev = ch
            i += 1
            continue
        if ch == "'":
            in_single = True
            prev = ch
            i += 1
            continue
        if ch == '"':
            in_double = True
            prev = ch
            i += 1
            continue
        if ch == '`':
            in_backtick = True
            prev = ch
            i += 1
            continue
        if ch == '\\' and i + 1 < n:
            # escaped char (e.g. `\#` is a literal `#`, not a comment start)
            prev = line[i + 1]
            i += 2
            continue
        if ch == '(':
            paren_depth += 1
            prev = ch
            i += 1
            continue
        if ch == ')':
            if paren_depth > 0:
                paren_depth -= 1
            prev = ch
            i += 1
            continue
        if ch == '{':
            brace_depth += 1
            prev = ch
            i += 1
            continue
        if ch == '}':
            if brace_depth > 0:
                brace_depth -= 1
            prev = ch
            i += 1
            continue
        if ch == '#' and paren_depth == 0 and brace_depth == 0:
            # word-boundary check: comment starts only at line-start, after
            # whitespace, or after a shell metacharacter.
            if prev is None or prev.isspace() or prev in metachars:
                return line[:i]
        prev = ch
        i += 1
    return line


def _split_top_level_semis(line):
    """Split a line on TOP-LEVEL `;` (statement-separators).

    A `;` inside single/double quotes, backticks, or a `{ }` / `( )` /
    `$( )` group is NOT a top-level separator. This is a careful tokenizer
    (not naive str.split(';')) because shell strings legitimately contain
    `;`-bearing prose (e.g. `echo "see; comma"`).

    Returns a list of (segment, start_offset_within_line) tuples so a
    violation in a non-first segment can be reported.
    """
    segments = []
    buf = []
    start = 0
    i = 0
    n = len(line)
    in_single = False
    in_double = False
    in_backtick = False
    paren_depth = 0
    brace_depth = 0
    while i < n:
        ch = line[i]
        if in_single:
            buf.append(ch)
            if ch == "'":
                in_single = False
            i += 1
            continue
        if in_double:
            buf.append(ch)
            if ch == '\\' and i + 1 < n:
                # consume the escaped char as part of the string
                buf.append(line[i + 1])
                i += 2
                continue
            if ch == '"':
                in_double = False
            i += 1
            continue
        if in_backtick:
            buf.append(ch)
            if ch == '`':
                in_backtick = False
            i += 1
            continue
        if ch == "'":
            in_single = True
            buf.append(ch)
            i += 1
            continue
        if ch == '"':
            in_double = True
            buf.append(ch)
            i += 1
            continue
        if ch == '`':
            in_backtick = True
            buf.append(ch)
            i += 1
            continue
        if ch == '(':
            paren_depth += 1
            buf.append(ch)
            i += 1
            continue
        if ch == ')':
            if paren_depth > 0:
                paren_depth -= 1
            buf.append(ch)
            i += 1
            continue
        if ch == '{':
            brace_depth += 1
            buf.append(ch)
            i += 1
            continue
        if ch == '}':
            if brace_depth > 0:
                brace_depth -= 1
            buf.append(ch)
            i += 1
            continue
        if ch == ';' and paren_depth == 0 and brace_depth == 0:
            segments.append(("".join(buf), start))
            buf = []
            i += 1
            start = i
            continue
        buf.append(ch)
        i += 1
    if buf or not segments:
        segments.append(("".join(buf), start))
    return segments


def _branch_has_pipeline_or_background(text):
    """Quote/brace-aware scan for an unquoted pipeline (`|` not `||`) or
    background (`&` not `&&`) operator before the first top-level `;` or
    end-of-text. Returns True if found.

    iter-6 X15: bash runs `return`/`exit` placed in a pipeline tail in a
    subshell and a `&`-background command asynchronously — in both cases
    the abort does NOT propagate to the outer function. A `||` branch
    that LOOKS like an abort (begins with `return`/`exit`) but contains
    `| <cmd>` or trails with `&` is therefore NOT a real guard. This
    check is the "simple-command position" gate: after `_guard_branch_aborts`
    confirms the abort keyword (or terminal-abort brace group), this
    scan must also pass.
    """
    n = len(text)
    i = 0
    in_single = False
    in_double = False
    in_backtick = False
    paren_depth = 0
    brace_depth = 0
    while i < n:
        ch = text[i]
        if in_single:
            if ch == "'":
                in_single = False
            i += 1
            continue
        if in_double:
            if ch == '\\' and i + 1 < n:
                i += 2
                continue
            if ch == '"':
                in_double = False
            i += 1
            continue
        if in_backtick:
            if ch == '`':
                in_backtick = False
            i += 1
            continue
        if ch == "'":
            in_single = True
            i += 1
            continue
        if ch == '"':
            in_double = True
            i += 1
            continue
        if ch == '`':
            in_backtick = True
            i += 1
            continue
        if ch == '\\' and i + 1 < n:
            # escaped char (e.g. `\|`, `\&`) — consume both, no metachar
            i += 2
            continue
        if ch == '(':
            paren_depth += 1
            i += 1
            continue
        if ch == ')':
            if paren_depth > 0:
                paren_depth -= 1
            i += 1
            continue
        if ch == '{':
            brace_depth += 1
            i += 1
            continue
        if ch == '}':
            if brace_depth > 0:
                brace_depth -= 1
            i += 1
            continue
        if paren_depth == 0 and brace_depth == 0:
            if ch == ';':
                # top-level `;` ends the current statement; no
                # pipeline/background found in the abort statement.
                return False
            if ch == '|':
                # `||` is two chars — not a pipeline. Otherwise single
                # `|` is a pipeline operator.
                if i + 1 < n and text[i + 1] == '|':
                    i += 2
                    continue
                return True
            if ch == '&':
                # `&&` is two chars — short-circuit AND, not background.
                if i + 1 < n and text[i + 1] == '&':
                    i += 2
                    continue
                return True
        i += 1
    return False


def _guard_branch_aborts(branch):
    """Decide whether the text of a `||` branch is a real aborting guard.

    A real guard at branch position 0 is one of:
      - the keyword `return` (optionally followed by an exit code)
      - the keyword `exit`   (optionally followed by an exit code)
      - a brace group `{ ...; return|exit ... ; }` whose FINAL non-empty
        top-level statement is `return` or `exit`
    AND the abort statement must be in SIMPLE-COMMAND position — no
    unquoted `|` (pipeline) or `&` (background) before the next top-level
    `;` / end-of-branch (iter-6 X15: bash runs pipeline-tail/background
    statements in a subshell, so the abort does NOT reach the caller).

    All other forms (`echo return`, `echo "see return"`, `true`, `:`,
    `echo failed; return 1` with the `return` outside the branch,
    `return 1 | cat`, `return 1 &`) are NOT aborting guards: they let
    execution proceed with the assignment's VAR still empty, which is
    the destructive footgun the pin exists to forbid.
    """
    text = branch.strip()
    if not text:
        return False
    # iter-6 X15: pipeline or background in the branch defeats the abort
    # regardless of the keyword shape. Run this check first.
    if _branch_has_pipeline_or_background(text):
        return False
    # Brace-group form: `{ stmt; ...; stmt; }`
    if text.startswith('{'):
        # find the matching close brace honouring nested braces / quotes /
        # subshells. For our grammar, a careless approach is enough — bash
        # forbids unescaped `}` inside brace groups except inside strings
        # or subshells, which our top-level splitter handled before us. So
        # the matching close is simply the LAST `}` in the branch.
        close = text.rfind('}')
        if close == -1:
            return False
        inner = text[1:close].strip()
        # final statement: split inner on top-level `;` and inspect the
        # last non-empty piece.
        inner_segs = _split_top_level_semis(inner)
        # filter out trailing empty pieces (from a trailing `;` before `}`)
        nonempty = [s for s, _ in inner_segs if s.strip()]
        if not nonempty:
            return False
        final = nonempty[-1].strip()
        return _starts_with_abort_keyword(final)
    return _starts_with_abort_keyword(text)


_ABORT_KEYWORD = re.compile(r'^(return|exit)\b')


def _starts_with_abort_keyword(text):
    return bool(_ABORT_KEYWORD.match(text.strip()))


def _segment_has_real_guard(segment):
    """Decide whether a segment containing an mktemp assign also has a
    real `||` guard immediately after the substitution.

    Find the FIRST `||` after the mktemp substitution close and check its
    branch is an aborting statement (per `_guard_branch_aborts`). If there
    is no `||` after the substitution, this segment is unguarded.
    """
    # Find the substitution close position. We've already verified the
    # segment matches ASSIGN; find the closing `)` or backtick of the FIRST
    # mktemp substitution.
    # Look for `$(...mktemp...)` or `` `mktemp...` ``.
    m = re.search(r'\$\(\s*' + _MKTEMP + r'[^()]*\)', segment)
    if not m:
        m = re.search(r'`\s*' + _MKTEMP + r'[^`]*`', segment)
    if not m:
        return False  # no recognizable substitution — caller will treat as
                      # unguarded; consistent with the assign-but-no-subst
                      # impossibility for our grammar.
    after = segment[m.end():]
    # skip an optional closing quote
    if after.startswith('"') or after.startswith("'"):
        after = after[1:]
    # skip optional `/path` (this is the APPENDED shape — caller flags it
    # separately, but for guard-checking we still want to find the `||`)
    pos = 0
    while pos < len(after) and not after[pos].isspace() and after[pos] not in '|;)':
        if after[pos] in '"\'':
            # don't consume into a string; bail
            break
        pos += 1
    after = after[pos:]
    # find `||` (not `|`)
    i = 0
    while i < len(after):
        if after[i] == '|' and i + 1 < len(after) and after[i + 1] == '|':
            branch = after[i + 2:]
            return _guard_branch_aborts(branch)
        i += 1
    return False


# Per-file z_postcheck dialect (X13): a multi-line post-assignment guard.
#   VAR=$(mktemp -d ...)
#   if [ -z "$VAR" ] || [ ! -d "$VAR" ]; then ... return 1; fi
# OR the chained-and form `[ -z "$VAR" ] || [ ! -d "$VAR" ] && return 1`.
# Recognized only when the dialect is `z_postcheck`; the variable name in
# the `[ -z ]` test MUST match the assignment's LHS (so an unrelated
# `[ -z ]` line a few lines down does not accidentally "guard" a different
# assignment).
_Z_TEST = re.compile(
    r'\[\s+-z\s+"?\$\{?(?P<name>[A-Za-z_][A-Za-z0-9_]*)\}?"?\s+\]'
)


def _has_z_postcheck_for(lhs, line_idx, all_lines):
    """For dialect z_postcheck: scan up to 6 lines forward from line_idx
    looking for a `[ -z "$lhs" ]` test paired with an abort statement
    (return/exit) on the same line or within the next 5 lines.
    Returns True if the variable name in the test matches `lhs` AND an
    abort is reachable from the test.
    """
    if dialect != "z_postcheck":
        return False
    end = min(line_idx + 7, len(all_lines))
    for j in range(line_idx, end):
        line_j = all_lines[j]
        m = _Z_TEST.search(line_j)
        if not m:
            continue
        if m.group("name") != lhs:
            continue
        # found `[ -z "$lhs" ]`. Look for return/exit reachable from here:
        #   - `&& return` / `&& exit` on the same line
        #   - `then` on this line, abort statement on a following line
        #     (within 5 lines)
        for k in range(j, min(j + 6, len(all_lines))):
            line_k = all_lines[k]
            if re.search(r'&&\s*(return|exit)\b', line_k):
                return True
            if k > j:
                stripped_k = line_k.lstrip()
                if _ABORT_KEYWORD.match(stripped_k):
                    return True
    return False


violations = []
for n, raw in enumerate(lines, start=1):
    stripped = raw.lstrip()
    if stripped.startswith("#"):
        continue
    line = raw.rstrip("\n")
    # iter-6 X16: strip any trailing `#`-introduced shell comment before
    # tokenizing. A `# || return` inside a comment is NOT a real guard —
    # bash never sees it. Apply at the line level so both the APPENDED
    # check and the per-segment scan run on the comment-stripped line.
    line = _strip_inline_comment(line)
    # First: appended-segment is banned outright at the line level (even if
    # subsequently guarded, the `dirname -> /` footgun is structural). The
    # APPENDED regex looks for the substitution-close-then-`/` shape across
    # any segment of the line.
    if APPENDED.search(line):
        violations.append((n, "appended-segment", line.strip()))
        continue
    # Per-segment scan: split the line on top-level `;` and re-apply
    # assign/guard per segment. This rejects the X12 multi-assignment
    # bypass.
    for seg, _off in _split_top_level_semis(line):
        # iter-6 X16: also strip inline comments at the segment level
        # for defense-in-depth (a `#` inside a segment that survived the
        # line-level strip — e.g. a future heredoc-bypass shape — would
        # be caught here too).
        seg = _strip_inline_comment(seg)
        seg_tail = _strip_assign_prefix(seg)
        m = ASSIGN.search(seg_tail)
        if not m:
            continue
        # This segment has an assign-from-mktemp. Does it have a real
        # same-line guard?
        if _segment_has_real_guard(seg_tail):
            continue
        # No same-line guard — under the z_postcheck dialect, also accept a
        # multi-line `[ -z "$VAR" ]` post-assignment guard whose variable
        # name matches the assignment LHS.
        lhs = m.group(1)
        if _has_z_postcheck_for(lhs, n - 1, lines):
            continue
        # Unguarded.
        violations.append((n, "unguarded", line.strip()))
        # only one violation per line — break out
        break

if violations:
    print("UNGUARDED MKTEMP SITE(S) — destructive rm-rf class (X1/X7):")
    for n, kind, text in violations:
        print(f"  L{n} [{kind}]: {text}")
    sys.exit(1)
print("ok")
PY
}

# Per-file scope + dialect map (iter-5 X13). Every shell script in the repo
# is enumerated EXPLICITLY here (no `find` enumeration — bash 3.2
# compatible, deterministic, multi-agent-safe) along with the safe-guard
# idiom dialect its mktemp sites use:
#   - same_line:    only the same-line `|| return` / `|| { ...; return; }`
#                   guard form is accepted (smoke-helpers.sh, hooks/lib/*.sh).
#   - z_postcheck:  ALSO accept the multi-line `[ -z "$VAR" ] || [ ! -d
#                   "$VAR" ]` post-assignment guard idiom (tests/smoke.sh).
# To add a new in-scope shell script, append a row here. To switch a file's
# dialect, update its row (and add a fixture proving the new idiom is
# recognized).
_MKTEMP_LINT_SCOPE() {
  cat <<'EOF'
tests/smoke.sh z_postcheck
tests/smoke-helpers.sh same_line
tests/smoke-helpers-check-phase0-wiring.sh same_line
tests/smoke-helpers-check-wiring.sh same_line
hooks/lib/build_pr_files.sh same_line
hooks/lib/codex_audit_dispatch.sh same_line
hooks/lib/cross_audit_resolve_range.sh same_line
hooks/lib/dedupe_findings.sh same_line
hooks/lib/locate_section_outside_fences.sh same_line
hooks/lib/probe_e.sh same_line
hooks/lib/probe_f.sh same_line
hooks/lib/probe_g.sh same_line
hooks/lib/probe_h.sh same_line
hooks/lib/receipt_canonicalize.sh same_line
hooks/lib/render_findings.sh same_line
hooks/lib/resolve_rule_path.sh same_line
hooks/lib/synth_probe_failures.sh same_line
EOF
}

check_all_shell_scripts_mktemp_guarded() {
  local fail=0 scanned=0 target dialect
  while read -r target dialect; do
    [ -n "$target" ] || continue
    if [ ! -r "$target" ]; then
      echo "lint target missing: $target"; fail=1; continue
    fi
    scanned=$((scanned + 1))
    local report
    report=$(_smoke_mktemp_lint_scan "$target" "$dialect")
    local rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "$report"
      echo "lint: $target has an unguarded or path-appended mktemp — see lines above"
      fail=1
    fi
  done <<EOF
$(_MKTEMP_LINT_SCOPE)
EOF
  if [ "$scanned" -lt 2 ]; then
    echo "lint scope regression: only $scanned files scanned — expected the multi-file enumeration"
    return 1
  fi
  [ "$fail" -eq 0 ] || return 1
  echo "lint: all mktemp sites across $scanned shell scripts are guarded; no path-appended \$(mktemp ...)"
}

# behavioral: the mktemp lint's own correctness self-test. A lint pin with no
# negative case proves nothing (R3/R6). The negative fixtures span three
# generations of bypass classes plus the X13 dialect regression detector:
#   - X9 (iter-4) evading shapes: quoted/backtick subst, )"/seg appended,
#     || true / || : non-guards.
#   - X12 (iter-5) evading shapes: word-substring guard (`|| echo return`,
#     `|| echo "see return"`, `|| echo failed; rm -rf; return 1` with the
#     late-return as a separate top-level statement, `|| { echo failed; }`
#     with no terminal return in the brace group); path-qualified mktemp
#     (`$(/bin/mktemp -d)`, `$(command mktemp -d)`); multi-assignment-per-
#     line (first unguarded).
#   - X13 (iter-5) idiom recognition: the z_postcheck multi-line
#     `[ -z "$VAR" ]` post-assignment guard MUST be accepted when the
#     variable name matches the assignment LHS, and REJECTED when the
#     variable name does not match.
# Plus positive controls: clean-guarded (X9), guard-brace-group-valid (X12
# brace-group guard with final return), multi-assignment-both-guarded
# (X12 per-segment positive case), external-file-safe-z-idiom (X13
# z_postcheck positive control). Plus a scope regression detector: assert
# the enumeration includes `tests/smoke.sh` (the canonical external scan
# target) so a future regression dropping multi-file scope fails the pin.
check_all_shell_scripts_mktemp_lint_self_test() {
  local fdir="tests/fixtures/smoke-mktemp-lint"
  test -d "$fdir" || { echo "$fdir fixture dir missing"; return 1; }
  local kind out rc

  # X9 negative fixtures (same_line dialect).
  for kind in quoted-subst-unguarded backtick-subst-unguarded \
              quoted-appended-segment guard-or-true guard-or-colon; do
    local fx="$fdir/$kind.sh"
    test -f "$fx" || { echo "$fx fixture missing"; return 1; }
    out=$(_smoke_mktemp_lint_scan "$fx" same_line 2>&1)
    rc=$?
    [ "$rc" -eq 1 ] \
      || { echo "mktemp lint did NOT flag '$kind' (got rc=$rc) — X9 evading shape slipped through"; return 1; }
    printf '%s' "$out" | grep -qE 'unguarded|appended-segment' \
      || { echo "mktemp lint emitted no violation kind for '$kind'"; return 1; }
  done

  # X12 negative fixtures (same_line dialect).
  for kind in guard-word-substring-echo guard-word-substring-quoted \
              guard-word-substring-late-return guard-brace-group-no-return \
              path-qualified-bin-mktemp path-qualified-command-mktemp \
              multi-assignment-first-unguarded; do
    local fx="$fdir/$kind.sh"
    test -f "$fx" || { echo "$fx fixture missing"; return 1; }
    out=$(_smoke_mktemp_lint_scan "$fx" same_line 2>&1)
    rc=$?
    [ "$rc" -eq 1 ] \
      || { echo "mktemp lint did NOT flag '$kind' (got rc=$rc) — X12 evading shape slipped through"; return 1; }
    printf '%s' "$out" | grep -qE 'unguarded|appended-segment' \
      || { echo "mktemp lint emitted no violation kind for '$kind'"; return 1; }
  done

  # X14 negative fixtures (iter-6, same_line dialect) — appended-segment
  # structural defense MUST flag the mktemp-inside-subst-body + appended-
  # `/seg` shape regardless of preceding prefix tokens (env / TMPDIR= /
  # eval / time / `\mktemp` / LC_ALL= / combined) and regardless of any
  # trailing `||` guard (the structural shape destroys the LHS value
  # before the downstream `rm -rf "$(dirname "$VAR")"` ever runs).
  for kind in x14-env-prefix-appended x14-tmpdir-prefix-appended \
              x14-eval-prefix-appended x14-time-prefix-appended \
              x14-backslash-prefix-appended x14-lcall-prefix-appended \
              x14-env-tmpdir-combined-appended \
              x14-with-real-guard-still-fails; do
    local fx="$fdir/$kind.sh"
    test -f "$fx" || { echo "$fx fixture missing"; return 1; }
    out=$(_smoke_mktemp_lint_scan "$fx" same_line 2>&1)
    rc=$?
    [ "$rc" -eq 1 ] \
      || { echo "mktemp lint did NOT flag '$kind' (got rc=$rc) — X14 appended-segment structural defense slipped through"; return 1; }
    printf '%s' "$out" | grep -q 'appended-segment' \
      || { echo "mktemp lint did not emit appended-segment violation kind for '$kind'"; return 1; }
  done

  # X14 negative fixtures (iter-6, same_line dialect) — unguarded-mktemp
  # check MUST recognize the extended command-prefix vocabulary (env /
  # TMPDIR= / `\mktemp`) when the assignment is unguarded with no
  # appended segment.
  for kind in x14-env-unguarded x14-tmpdir-unguarded x14-backslash-unguarded; do
    local fx="$fdir/$kind.sh"
    test -f "$fx" || { echo "$fx fixture missing"; return 1; }
    out=$(_smoke_mktemp_lint_scan "$fx" same_line 2>&1)
    rc=$?
    [ "$rc" -eq 1 ] \
      || { echo "mktemp lint did NOT flag '$kind' (got rc=$rc) — X14 prefix-vocabulary unguarded shape slipped through"; return 1; }
    printf '%s' "$out" | grep -q 'unguarded' \
      || { echo "mktemp lint did not emit unguarded violation kind for '$kind'"; return 1; }
  done

  # X15 negative fixtures (iter-6, same_line dialect) — simple-command
  # guard discipline. Bash runs `return`/`exit` in a pipeline tail in a
  # subshell and a `&`-background command asynchronously; in both cases
  # the abort does NOT reach the caller. The `||` branch must be a simple
  # command with no unquoted `|` (pipeline) / `&` (background) before
  # the next top-level `;` / end-of-branch.
  for kind in x15-guard-pipeline-cat x15-guard-pipeline-exit \
              x15-guard-brace-pipeline x15-guard-background \
              x15-guard-background-then-fake-return; do
    local fx="$fdir/$kind.sh"
    test -f "$fx" || { echo "$fx fixture missing"; return 1; }
    out=$(_smoke_mktemp_lint_scan "$fx" same_line 2>&1)
    rc=$?
    [ "$rc" -eq 1 ] \
      || { echo "mktemp lint did NOT flag '$kind' (got rc=$rc) — X15 pipeline/background subshell evasion slipped through"; return 1; }
    printf '%s' "$out" | grep -q 'unguarded' \
      || { echo "mktemp lint did not emit unguarded violation kind for '$kind'"; return 1; }
  done

  # X16 negative fixtures (iter-6, same_line dialect) — shell-comment
  # stripping. A `#` outside quotes at a word boundary starts a comment
  # that runs to end-of-line; bash never sees the `||`/`return` tokens
  # inside it, so the lint's tokenizer must strip the comment before
  # parsing for guards.
  for kind in x16-comment-or-return x16-comment-todo-return \
              x16-comment-or-exit; do
    local fx="$fdir/$kind.sh"
    test -f "$fx" || { echo "$fx fixture missing"; return 1; }
    out=$(_smoke_mktemp_lint_scan "$fx" same_line 2>&1)
    rc=$?
    [ "$rc" -eq 1 ] \
      || { echo "mktemp lint did NOT flag '$kind' (got rc=$rc) — X16 comment-as-guard slipped through"; return 1; }
    printf '%s' "$out" | grep -q 'unguarded' \
      || { echo "mktemp lint did not emit unguarded violation kind for '$kind'"; return 1; }
  done

  # X13 negative fixture (z_postcheck dialect — variable name mismatch).
  for kind in external-file-z-idiom-wrong-var; do
    local fx="$fdir/$kind.sh"
    test -f "$fx" || { echo "$fx fixture missing"; return 1; }
    out=$(_smoke_mktemp_lint_scan "$fx" z_postcheck 2>&1)
    rc=$?
    [ "$rc" -eq 1 ] \
      || { echo "mktemp lint did NOT flag '$kind' (got rc=$rc) — X13 wrong-var idiom slipped through"; return 1; }
    printf '%s' "$out" | grep -qE 'unguarded' \
      || { echo "mktemp lint emitted no violation kind for '$kind'"; return 1; }
  done

  # Positive controls (same_line dialect). x14-env-guarded is the iter-6
  # control proving the extended prefix vocabulary still recognizes a
  # CORRECTLY-guarded prefixed mktemp (`env mktemp -d) || return 1`) as
  # guarded (no false positive on real guards).
  # x16-real-guard-with-trailing-comment is the iter-6 X16 positive
  # control proving the comment-strip does NOT remove a real `||` guard
  # that is BEFORE the trailing `#` comment.
  for ctl in clean-guarded guard-brace-group-valid multi-assignment-both-guarded \
             x14-env-guarded x16-real-guard-with-trailing-comment; do
    local fx="$fdir/$ctl.sh"
    test -f "$fx" || { echo "$fx fixture missing"; return 1; }
    _smoke_mktemp_lint_scan "$fx" same_line >/dev/null 2>&1 \
      || { echo "mktemp lint wrongly flagged correctly-guarded control '$ctl'"; return 1; }
  done

  # Positive control (z_postcheck dialect — multi-line idiom must pass).
  for ctl in external-file-safe-z-idiom; do
    local fx="$fdir/$ctl.sh"
    test -f "$fx" || { echo "$fx fixture missing"; return 1; }
    _smoke_mktemp_lint_scan "$fx" z_postcheck >/dev/null 2>&1 \
      || { echo "mktemp lint wrongly flagged z_postcheck control '$ctl'"; return 1; }
  done

  # X13 scope regression detector: the enumeration MUST include at least
  # one mktemp site OUTSIDE smoke-helpers.sh. Use tests/smoke.sh as the
  # canonical external scan target (8 mktemp sites, z_postcheck dialect).
  local scope_listing scope_outside
  scope_listing=$(_MKTEMP_LINT_SCOPE)
  printf '%s\n' "$scope_listing" | grep -qE '^tests/smoke\.sh\s+z_postcheck$' \
    || { echo "scope regression: tests/smoke.sh not enumerated in _MKTEMP_LINT_SCOPE"; return 1; }
  scope_outside=$(printf '%s\n' "$scope_listing" | grep -cvE '^(tests/smoke-helpers\.sh\s|$)')
  if [ "$scope_outside" -lt 1 ]; then
    echo "scope regression: enumeration contains $scope_outside entries outside tests/smoke-helpers.sh — expected at least 1"
    return 1
  fi
  # Behavioral assertion: re-run the lint against tests/smoke.sh with the
  # z_postcheck dialect; it MUST pass clean (proving the dialect actually
  # accepts the in-file multi-line `[ -z "$VAR" ]` post-assignment idiom).
  _smoke_mktemp_lint_scan tests/smoke.sh z_postcheck >/dev/null 2>&1 \
    || { echo "scope regression: tests/smoke.sh failed the z_postcheck dialect lint — the multi-line [ -z ] idiom is not being accepted"; return 1; }

  echo "mktemp lint self-test: every X9 + X12 + X14 + X15 + X16 evading shape flagged (X14 = appended-segment structural defense regardless of prefix/guard + extended unguarded prefix vocabulary; X15 = simple-command guard discipline rejecting pipeline/background false guards; X16 = shell-comment stripping rejecting comment-as-guard); clean controls pass (incl. x14-env-guarded and x16-real-guard-with-trailing-comment); X13 z_postcheck dialect accepts the multi-line [ -z ] idiom only when the variable name matches the assign LHS; scope enumeration includes tests/smoke.sh"
}

# --- Caveman compression skill (spec 2026-05-20-caveman-compression-skill) ---
# 9 pins. 4 behavioral (helper sourceable + hash correctness + active-default
# injection + suspended branch), 5 prompt-text (parser-anchor literals,
# uncertainty invariant proximity, wire-prefix proximity, artifact boundary
# proximity, slash-command semantics).

check_caveman_skill_parser_anchors_literal() {
  local f="skills/caveman/SKILL.md" missing="" anchor
  test -f "$f" || { echo "$f missing"; return 1; }
  for anchor in \
    'spec_audit_iteration=' \
    'code audit iteration=' \
    'code audit passed' \
    'code audit decisions recorded' \
    'code audit: no auditable files in diff' \
    '# CROSS-AUDIT EVIDENCE FOOTER' \
    'evidence_class:' \
    'evidence_blockers:' \
    '## ⏸ AWAITING YOUR INPUT' \
    '## ⏸ APPROVAL REQUIRED' \
    '@codex' \
    '@senior' \
    'X<N>' \
    '- [ ] Step N:' \
    'allowed_scope:' \
    'failing_test_cmd:' \
    'expected_failure_pattern:' \
    'expected_pass_pattern:' \
    'passing_test_cmd:'
  do
    grep -qF -- "$anchor" "$f" || missing="$missing|$anchor"
  done
  if [ -n "$missing" ]; then
    echo "$f missing parser-anchor literals: $missing"
    return 1
  fi
  echo "SKILL.md never-compress list cites every spec §2.2 parser-anchor literal"
}

check_caveman_log_marker_canonical_form() {
  # Scope strictly to §2.1 — the §2.x neighbours (banner blocks at §2.3,
  # cross-audit footer at §2.2, etc.) legitimately contain other byte
  # literals that would confuse the assertions below. The standard
  # `extract_md_section` helper at smoke.sh:113 terminates only on `^## `
  # (H2) and would over-extract §2.1 through §2.6; we need an H3-aware
  # terminator, hence the inline awk extractor.
  local f="skills/caveman/SKILL.md" section literal neg
  test -f "$f" || { echo "$f missing"; return 1; }
  section=$(awk -v hdr="### 2.1 Log markers — the Continue-mode dispatch keys" '
    !in_s && $0 == hdr { in_s = 1; print; next }
    in_s && /^### / { exit }
    in_s { print }
  ' "$f")
  if [ -z "$section" ]; then
    echo "$f: §2.1 Log markers section missing or empty"
    return 1
  fi
  # Positive assertions — each of the 12 distinguishing byte-literal
  # sequences from the 6 canonical templates (spec §3.3 / §3.4 #1-#8)
  # MUST appear within §2.1.
  for literal in \
    'spec_audit_iteration=' \
    'code audit iteration=' \
    'code audit decisions recorded; iteration=' \
    'code audit passed; iteration=' \
    'code audit: no auditable files in diff; skipping' \
    'audit iteration > 5 justified' \
    'verified=[...], accepted=[...], deferred=[...]' \
    '; evidence=' \
    '; blockers=[' \
    'pending_fixed=[' \
    'pending_accepted=[' \
    'pending_deferred=['
  do
    if ! printf "%s" "$section" | grep -qF -- "$literal"; then
      echo "FAIL_MISSING_CANONICAL:$literal"
      return 1
    fi
  done
  # Negative assertions — obsolete drift forms MUST NOT appear in §2.1.
  # Note: `audit iteration > 5` (cap-escape) is explicitly allowed via the
  # positive list above; the forbidden form is the literal `<N>` / `<M>`
  # placeholder shape that no current producer or consumer uses.
  if printf "%s" "$section" | grep -qF -- 'audit iteration <N>'; then
    echo "FAIL_DRIFT_SPACE_FORM:audit iteration <N>"
    return 1
  fi
  if printf "%s" "$section" | grep -qF -- 'attempt-<M>'; then
    echo "FAIL_DRIFT_ATTEMPT_FORM:attempt-<M>"
    return 1
  fi
  echo "SKILL.md §2.1 lists all 6 canonical Log-marker templates byte-exact"
}

check_caveman_skill_uncertainty_invariant_present() {
  # X3: section-scope the assertion to ## 3. so that deleting the §3 body
  # cannot pass via frontmatter / Quick-reference satisfaction.
  local f="skills/caveman/SKILL.md" section literal
  test -f "$f" || { echo "$f missing"; return 1; }
  section=$(extract_md_section "$f" '## 3. Uncertainty-preservation invariant')
  if [ -z "$section" ]; then
    echo "$f: ## 3. Uncertainty-preservation invariant section missing or empty"
    return 1
  fi
  # Load-bearing marker classes (frontmatter + Quick-ref do NOT contain these).
  for literal in \
    'Modal verbs' \
    'hedging adverbs' \
    'tentative qualifiers' \
    'explicit confidence markers' \
    'this might fail under heavy load' \
    'flat assertion'
  do
    if ! printf '%s' "$section" | grep -qF -- "$literal"; then
      echo "$f §3 missing load-bearing literal: $literal"
      return 1
    fi
  done
  # Goodhart-proof rule co-occurrence: 'Goodhart' and 'flat assertion' both in §3.
  if ! printf '%s' "$section" | grep -qF -- 'Goodhart'; then
    echo "$f §3 missing 'Goodhart' rule sentence"
    return 1
  fi
  echo "SKILL.md §3 uncertainty invariant: marker classes + negative example + Goodhart rule all present"
}

check_caveman_skill_wire_prefix_present() {
  local f="skills/caveman/SKILL.md" body
  test -f "$f" || { echo "$f missing"; return 1; }
  grep -qF '[COMPRESSION:terse]' "$f" || { echo "$f missing [COMPRESSION:terse] wire-prefix literal"; return 1; }
  # Assert co-occurrence with wire|subagent within 200 bytes of the prefix.
  # Use python3 for robust window scan (Bash-3.2 safe).
  if ! python3 - "$f" <<'PY'
import sys, re
path = sys.argv[1]
data = open(path, 'rb').read().decode('utf-8', errors='replace')
needle = '[COMPRESSION:terse]'
hits = [m.start() for m in re.finditer(re.escape(needle), data)]
ok = False
for h in hits:
    window = data[max(0, h-200):min(len(data), h+200+len(needle))]
    if re.search(r'wire|subagent', window, flags=re.IGNORECASE):
        ok = True
        break
sys.exit(0 if ok else 1)
PY
  then
    echo "$f: [COMPRESSION:terse] not within 200 bytes of 'wire' or 'subagent'"
    return 1
  fi
  echo "SKILL.md wire prefix [COMPRESSION:terse] documented in wire/subagent context"
}

check_caveman_skill_artifact_boundary_present() {
  # X4: section-scope the assertion to ## 5. so frontmatter / Quick-reference
  # cannot satisfy it by themselves. Assert each table row's left-column
  # literal co-occurs with its YES/NO classification on the same line.
  local f="skills/caveman/SKILL.md" section pattern
  test -f "$f" || { echo "$f missing"; return 1; }
  section=$(extract_md_section "$f" '## 5. Artifact compression boundary — prose vs structure')
  if [ -z "$section" ]; then
    echo "$f: ## 5. Artifact compression boundary section missing or empty"
    return 1
  fi
  # Per-row regex: left-column literal ... pipe ... classification literal.
  # Patterns are extended-regex; characters that look magic in ERE are escaped
  # where it matters (parentheses, dot). Each pattern must match on a single line.
  for pattern in \
    'Free-prose paragraphs.*\|.*YES' \
    'Bullet-list narrative items.*\|.*YES \(drop articles, shorten clauses\)' \
    'YAML frontmatter.*\|.*NO' \
    'Workdoc Planned-block keys.*\|.*NO' \
    'Spec .*Implementation Checklist.*\|.*NO' \
    'Code blocks.*\|.*NO' \
    'Tables.*\|.*YES on cell prose.*NO on column structure' \
    'Banner blocks.*\|.*NO' \
    'EVIDENCE FOOTER.*\|.*NO'
  do
    if ! printf '%s' "$section" | grep -qE -- "$pattern"; then
      echo "$f §5 missing table row matching: $pattern"
      return 1
    fi
  done
  # Rule-of-thumb sentence: parser/smoke-pin grep-Fs the content → treat as structure.
  if ! printf '%s' "$section" | grep -qF -- 'rule of thumb'; then
    echo "$f §5 missing 'rule of thumb' sentence"
    return 1
  fi
  if ! printf '%s' "$section" | grep -qE -- 'parser.*smoke.*grep|smoke.*pin.*grep'; then
    echo "$f §5 'rule of thumb' missing parser/smoke-pin grep semantics"
    return 1
  fi
  echo "SKILL.md §5 artifact-boundary: 9 table rows (left literal + YES/NO) + rule-of-thumb sentence all present"
}

# --- Caveman in-flow mandatory activation + machine-output precedence ---
# (spec 2026-05-22-caveman-in-flow-mandatory-activation)
# Post-strip 2026-05-24: toggle infrastructure removed; helper enforces always-on
# semantics across SKILL.md / SESSION-INJECTION.md / 4 flow skills / investigator.md.

check_caveman_in_flow_activation_documented() {
  local skill="skills/caveman/SKILL.md"
  local inj="skills/caveman/SESSION-INJECTION.md"
  local inv="agents/investigator.md"
  local f section6 section7

  for f in "$skill" "$inj" "$inv" \
           skills/feature/SKILL.md skills/cross-audit/SKILL.md \
           skills/investigate/SKILL.md skills/research/SKILL.md; do
    test -f "$f" || { echo "$f missing"; return 1; }
  done

  # Assertion #1 — §1 imperative #8 simplified (always-active language)
  grep -qF "Caveman compression is always active." "$skill" \
    || { echo "FAIL_MISSING_S1_IMPERATIVE_8"; return 1; }

  # Assertion #2 — §6 Quick reference (renumbered from §7) carries the see §7 cross-ref
  section6=$(extract_md_section "$skill" '## 6. Quick reference')
  printf '%s' "$section6" | grep -qF "see §7" \
    || { echo "FAIL_MISSING_S6_CROSSREF"; return 1; }

  # Assertion #3 — §7 Machine-output precedence heading + key literals (scoped to §7 body)
  section7=$(extract_md_section "$skill" '## 7. Machine-output precedence — payloads exempt')
  test -n "$section7" \
    || { echo "FAIL_MISSING_S7_HEADING"; return 1; }
  printf '%s' "$section7" | grep -qF "hooks/lib/render_findings.sh" \
    || { echo "FAIL_MISSING_S7_RENDER_FINDINGS"; return 1; }
  printf '%s' "$section7" | grep -qF "hooks/lib/dedupe_findings.sh" \
    || { echo "FAIL_MISSING_S7_DEDUPE_FINDINGS"; return 1; }
  printf '%s' "$section7" | grep -qF "haiku-finding-scorer" \
    || { echo "FAIL_MISSING_S7_HAIKU_SCORER"; return 1; }
  printf '%s' "$section7" | grep -qF "check_dispatch_response.py" \
    || { echo "FAIL_MISSING_S7_DISPATCH_PARSER"; return 1; }

  # Assertion #4 — SESSION-INJECTION.md mid-body paragraph + machine-output literal
  grep -qF "Inside \`/feature\`, \`/cross-audit\`, \`/investigate\`, \`/research\` flows, compression is **mandatory**" "$inj" \
    || { echo "FAIL_SESSION_INJECTION_MISSING_PARAGRAPH"; return 1; }
  grep -qF "Machine-output payloads" "$inj" \
    || { echo "FAIL_SESSION_INJECTION_MISSING_MACHINE_OUTPUT"; return 1; }

  # Assertion #5 — 4 flow skills (now includes /research) carry the heading + literals
  local fs
  for fs in skills/feature/SKILL.md skills/cross-audit/SKILL.md skills/investigate/SKILL.md skills/research/SKILL.md; do
    grep -qF "### Caveman activation in this flow" "$fs" \
      || { echo "FAIL_FLOW_SKILL_MISSING_HEADING:$fs"; return 1; }
    grep -qF "Caveman compression is mandatory in this flow." "$fs" \
      || { echo "FAIL_FLOW_SKILL_MISSING_MANDATORY_LITERAL:$fs"; return 1; }
    grep -qF "[COMPRESSION:terse]" "$fs" \
      || { echo "FAIL_FLOW_SKILL_MISSING_WIRE_PREFIX_LITERAL:$fs"; return 1; }
  done

  # Assertion #6 — investigator MCP unconditional wire-prefix block;
  # obsolete flag-conditional draft language must be absent.
  grep -qF "invoked from \`/investigate\` flow context" "$inv" \
    || { echo "FAIL_INVESTIGATOR_MISSING_FLOW_CONTEXT"; return 1; }
  grep -qF "unconditionally" "$inv" \
    || { echo "FAIL_INVESTIGATOR_MISSING_UNCONDITIONAL"; return 1; }
  grep -qF "Apply ai-dev-team caveman compression rules to your output" "$inv" \
    || { echo "FAIL_INVESTIGATOR_MISSING_WIRE_PREFIX_BODY"; return 1; }
  grep -qF "[COMPRESSION:terse]" "$inv" \
    || { echo "FAIL_INVESTIGATOR_MISSING_WIRE_PREFIX_LITERAL"; return 1; }
  if grep -qF "When caveman is active for the session" "$inv"; then
    echo "FAIL_INVESTIGATOR_OBSOLETE_CONDITIONAL_BLOCK"
    return 1
  fi

  echo "caveman in-flow mandatory activation + machine-output precedence documented across SKILL.md / SESSION-INJECTION.md / 4 flow skills / investigator.md (always-on, no toggle)"
}

check_kb_authoring_convention_wired() {
  grep -qE '^## 8\. ' "$PLUGIN_ROOT/skills/caveman/SKILL.md" \
    && [ -s "$PLUGIN_ROOT/skills/feature/references/kb-authoring-style.md" ] \
    && [ "$(wc -l < "$PLUGIN_ROOT/skills/feature/references/kb-authoring-style.md")" -ge 30 ] \
    && awk '/^### Step 3 — Create/,/^### Step 4/' "$PLUGIN_ROOT/skills/research/SKILL.md" | grep -qF 'kb-authoring-style.md' \
    && awk '/^You \(the feature skill orchestrator\) write both/,/^\*\*Spec\*\*: create at/' "$PLUGIN_ROOT/skills/feature/SKILL.md" | grep -qF 'kb-authoring-style.md'
}

# --- KB-drift scanner pins (spec 2026-05-31-librarian-kb-actualization) ---

# Behavioral: tests/kb_drift_scan.py against the clean + drift fixtures.
# Clean → exit 0 / no findings. Drift → exit 1 / each class token (C1/C2/C3/C4)
# present, with the autonomy-boundary invariants the curator relies on
# (C2/C3/C4 never auto_safe; C1 carries both an auto_safe:true and auto_safe:false).
# C4 status-drift: 2 drift fixtures (structured + Log-marker paths) flag, the 5
# clean status fixtures (incl. the IN_PROGRESS awaiting-hand-off case) stay clean.
# Also pins false-result regressions: C3 frontmatter-scoping (a research
# note quoting the spec schema in a ```yaml block is NOT flagged — clean
# fixture's research-quotes-spec-schema.md); the --project-typo false-clean
# (a nonexistent project subtree errors to stderr / exit 2, never exit 0); and
# the path-containment class — a `../`-escaping wikilink AND `../`-escaping
# §-pointer (drift fixture's escaping-refs.md, resolving to a real out-of-vault
# note) are REPORTED, not silently clean; and a `--project ../<x>` traversal
# errors to stderr / exit 2 (never an out-of-tree scan).
check_kb_drift_scan_behavioral() {
  local scanner="$PLUGIN_ROOT/tests/kb_drift_scan.py"
  local clean="$PLUGIN_ROOT/tests/fixtures/kb-drift/clean"
  local drift="$PLUGIN_ROOT/tests/fixtures/kb-drift/drift"
  local nested="$PLUGIN_ROOT/tests/fixtures/kb-drift/nested"
  local pathqual="$PLUGIN_ROOT/tests/fixtures/kb-drift/pathqual"
  [ -f "$scanner" ] || { echo "$scanner missing"; return 1; }
  [ -d "$clean" ] || { echo "$clean fixture dir missing"; return 1; }
  [ -d "$drift" ] || { echo "$drift fixture dir missing"; return 1; }
  [ -d "$nested" ] || { echo "$nested fixture dir missing"; return 1; }
  [ -d "$pathqual" ] || { echo "$pathqual fixture dir missing"; return 1; }
  python3 - "$scanner" "$clean" "$drift" "$nested" "$pathqual" <<'PYEOF'
import json, subprocess, sys, tempfile
from pathlib import Path
scanner, clean, drift, nested, pathqual = (
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
)

c = subprocess.run([sys.executable, scanner, clean], capture_output=True, text=True)
if c.returncode != 0:
    print(f"clean fixture: expected exit 0, got {c.returncode}")
    sys.exit(1)
cf = json.loads(c.stdout)["findings"]
if cf != []:
    print(f"clean fixture: expected no findings, got {cf}")
    sys.exit(1)
# X1 regression: the clean fixture's research note quotes `type: spec` /
# `status: DRAFT` inside a fenced ```yaml block. C3 must scope to the LEADING
# frontmatter only — that body quote must not yield a C3 finding (covered by
# findings == [] above, but assert the fixture is present so the proof can't
# silently vanish).
if not (Path(clean) / "research-quotes-spec-schema.md").is_file():
    print("clean fixture missing research-quotes-spec-schema.md (X1 frontmatter-scoping proof)")
    sys.exit(1)

# (e)+(f) code-awareness + cross-repo clean fixtures. The clean dir asserts
# findings == [] globally above; assert each new fixture is present so the
# code-awareness / C2-fence-skip / cross-repo proofs can't silently vanish, and
# re-scan each in isolation to pin that it alone yields ZERO findings (a global
# zero could otherwise mask a per-file regression that another file offsets).
code_aware_fixtures = {
    "code-blocks.md": "fenced bash [[ ]] / [[:space:]] / =~ — zero C1 (e1)",
    "inline-code.md": "inline `code [[x]]` span — zero C1 (e2)",
    "c2-pointer-in-fence.md": "backtick-wrapped `Missing.md` §Nope inside a fence — zero C2 (X2)",
    "fence-shapes.md": "tilde + longer-backtick fences with [[x]] — zero C1 (X4)",
    "cross-repo-pointer.md": "cross-repo `skills/...md` §heading pointer — not flagged (f)",
}
for fname, why in code_aware_fixtures.items():
    fp = Path(clean) / fname
    if not fp.is_file():
        print(f"clean fixture missing {fname} ({why})")
        sys.exit(1)
    with tempfile.TemporaryDirectory() as td:
        (Path(td) / fname).write_text(fp.read_text(encoding="utf-8"), encoding="utf-8")
        r = subprocess.run([sys.executable, scanner, td], capture_output=True, text=True)
        if r.returncode != 0:
            print(f"{fname}: expected exit 0 ({why}), got {r.returncode}; out={r.stdout!r}")
            sys.exit(1)
        ff = json.loads(r.stdout)["findings"]
        if ff != []:
            print(f"{fname}: expected zero findings ({why}), got {ff}")
            sys.exit(1)

# C4 anti-false-positive boundary (§3.2a). The five clean status fixtures each
# stay clean (already covered by the global findings == [] above, but each is
# re-scanned in isolation so a per-file C4 regression can't be masked by a
# global zero; the load-bearing cases c2/c3/c5 are the genuine FP traps). c5
# (IN_PROGRESS + null evidence + 'code audit passed' Log) is the awaiting-hand-
# off state — it differs from the drift Log-marker fixture ONLY in status, so
# its silence proves the status-gate distinguishes drift from awaiting-hand-off
# on the Log-marker path (X1).
c4_clean_fixtures = {
    "spec-draft-no-evidence.md": "DRAFT, no evidence, no terminal Log → no C4 (c1)",
    "spec-verified-with-evidence.md": "VERIFIED + evidence → terminal, no C4 (c2)",
    "spec-approved-null-evidence.md": "APPROVED + null evidence → pre-impl, no C4 (c3)",
    "spec-blocked-with-evidence.md": "BLOCKED + evidence → intentional hold, no C4 (c4)",
    "spec-in-progress-awaiting-handoff.md": "IN_PROGRESS + null evidence + 'code audit passed' Log → awaiting hand-off, no C4 (c5, the X1 fix)",
}
for fname, why in c4_clean_fixtures.items():
    fp = Path(clean) / fname
    if not fp.is_file():
        print(f"clean fixture missing {fname} ({why})")
        sys.exit(1)
    with tempfile.TemporaryDirectory() as td:
        (Path(td) / fname).write_text(fp.read_text(encoding="utf-8"), encoding="utf-8")
        r = subprocess.run([sys.executable, scanner, td], capture_output=True, text=True)
        if r.returncode != 0:
            print(f"{fname}: expected exit 0 ({why}), got {r.returncode}; out={r.stdout!r}")
            sys.exit(1)
        ff = json.loads(r.stdout)["findings"]
        if ff != []:
            print(f"{fname}: expected zero findings ({why}), got {ff}")
            sys.exit(1)

d = subprocess.run([sys.executable, scanner, drift], capture_output=True, text=True)
if d.returncode != 1:
    print(f"drift fixture: expected exit 1, got {d.returncode}")
    sys.exit(1)
F = json.loads(d.stdout)["findings"]
classes = {f["class"] for f in F}
want = {"C1_broken_wikilink", "C2_dangling_section_pointer", "C3_status_enum_violation", "C4_status_drift", "C5_research_status_enum_violation", "C6_index_row_bloat"}
if classes != want:
    print(f"drift fixture: expected class set {want}, got {classes}")
    sys.exit(1)
for f in F:
    if not ({"class", "file", "line", "detail", "auto_safe"} <= set(f)):
        print(f"finding missing required keys: {f}")
        sys.exit(1)
# Autonomy boundary: C2/C3/C4/C5/C6 are never auto_safe (a fix/flip/trim is a
# human call). Only C1 carries auto_safe:true on a unique correction.
for f in F:
    if f["class"] in ("C2_dangling_section_pointer", "C3_status_enum_violation", "C4_status_drift", "C5_research_status_enum_violation", "C6_index_row_bloat") and f["auto_safe"] is not False:
        print(f"C2/C3/C4/C5/C6 finding wrongly auto_safe: {f}")
        sys.exit(1)
# C1 correction-candidacy: both a unique (auto_safe:true) and a 0/multi (false).
c1 = [f["auto_safe"] for f in F if f["class"] == "C1_broken_wikilink"]
if True not in c1 or False not in c1:
    print(f"C1 findings must include both auto_safe true and false, got {c1}")
    sys.exit(1)

# C4 status-drift: TWO drift fixtures, one per signal path (total C4 == 2). d1
# (spec-status-drift-structured.md) fires via the structured frontmatter
# code_audit_evidence path; d2 (spec-status-drift-logmarker.md) fires via the
# legacy column-0 'code audit passed' Log marker (its evidence is null, so the
# structured path cannot fire — d2 positively pins TERMINAL_LOG_MARKER_RE, X3).
# d2 vs the clean c5 fixture differ ONLY in status (AUDIT_PASSED vs
# IN_PROGRESS), so the pair proves the status-gate distinguishes drift from
# awaiting-hand-off on the Log-marker path.
c4 = [f for f in F if f["class"] == "C4_status_drift"]
if len(c4) != 2:
    print(f"drift fixture: expected exactly 2 C4_status_drift findings (one per signal path), got {len(c4)}: {c4}")
    sys.exit(1)
c4_files = {f["file"] for f in c4}
if c4_files != {"spec-status-drift-structured.md", "spec-status-drift-logmarker.md"}:
    print(f"C4 findings must be on the structured + Log-marker drift fixtures, got {c4_files}")
    sys.exit(1)
if any(f["auto_safe"] is not False for f in c4):
    print(f"C4 findings must all be auto_safe:false, got {[f['auto_safe'] for f in c4]}")
    sys.exit(1)

# C5-R research-status enum violation (the C3 analog, type:research-scoped). TWO
# drift fixtures, asserted BY FIXTURE FILE (not aggregate): research-bad-status.md
# fires the off-enum path (status: OPEN ∉ {ACTIVE,CONCLUDED,ARCHIVED}) at the
# EXACT authored status-line number (file line 4 — `frontmatter[:start].count(\n)
# +2` = 2 preceding FM newlines + 2), with the enum detail substring;
# research-no-status.md fires the no-status path → line is None. Both
# auto_safe:false. The exact-line + detail + per-file attribution are what give
# the pin mutation-sensitivity (a broken count(\n)+2, a missing-status mishandle,
# or swapped fixture attribution flips it) — NOT the want-set update alone. The
# legacy type:research-note FP-guard under a research/ DIR segment is pinned by
# the clean-dir-zero assertion above (type-scope, not path-scope).
c5 = [f for f in F if f["class"] == "C5_research_status_enum_violation"]
if len(c5) != 2:
    print(f"drift fixture: expected exactly 2 C5_research_status_enum_violation findings, got {len(c5)}: {c5}")
    sys.exit(1)
c5_files = {f["file"] for f in c5}
if c5_files != {"research-bad-status.md", "research-no-status.md"}:
    print(f"C5 findings must be on the off-enum + no-status research fixtures, got {c5_files}")
    sys.exit(1)
if any(f["auto_safe"] is not False for f in c5):
    print(f"C5 findings must all be auto_safe:false, got {[f['auto_safe'] for f in c5]}")
    sys.exit(1)
c5_by_file = {f["file"]: f for f in c5}
c5_nostatus = c5_by_file["research-no-status.md"]
if c5_nostatus["line"] is not None:
    print(f"C5 research-no-status.md: expected line is None (no frontmatter status:), got {c5_nostatus['line']!r}")
    sys.exit(1)
c5_bad = c5_by_file["research-bad-status.md"]
if c5_bad["line"] != 4:
    print(f"C5 research-bad-status.md: expected line == 4 (the authored status: line), got {c5_bad['line']!r}")
    sys.exit(1)
if "status: OPEN not in accepted research-status enum" not in c5_bad["detail"]:
    print(f"C5 research-bad-status.md: detail must contain 'status: OPEN not in accepted research-status enum', got {c5_bad['detail']!r}")
    sys.exit(1)

# X5 regression (path containment — out-of-vault target): the drift fixture's
# escaping-refs.md carries a `../`-escaping wikilink AND `../`-escaping
# §-pointer whose targets resolve to a REAL note in the sibling clean/ fixture
# (out of the scanned vault). Without a kb_root containment guard both would
# resolve out-of-vault and be silently clean (false-clean). They MUST be
# reported as C1 broken + C2 dangling on escaping-refs.md.
if not (Path(drift) / "escaping-refs.md").is_file():
    print("drift fixture missing escaping-refs.md (X5 path-containment proof)")
    sys.exit(1)
esc = {f["class"] for f in F if f["file"] == "escaping-refs.md"}
if esc != {"C1_broken_wikilink", "C2_dangling_section_pointer"}:
    print(f"escaping-refs.md must yield BOTH C1 (escaping wikilink) and C2 "
          f"(escaping pointer) — out-of-vault targets must not be silently clean; got {esc}")
    sys.exit(1)

# X2 regression: a typo'd / nonexistent --project must error (exit 2), never a
# silent false-clean ({"scanned": 0, "findings": []} exit 0).
with tempfile.TemporaryDirectory() as td:
    (Path(td) / "repos" / "realproj").mkdir(parents=True)
    (Path(td) / "repos" / "realproj" / "a.md").write_text("# a\n", encoding="utf-8")
    p = subprocess.run(
        [sys.executable, scanner, td, "--project", "realprojj"],
        capture_output=True, text=True,
    )
    if p.returncode != 2:
        print(f"--project nonexistent: expected exit 2 (not false-clean), got {p.returncode}; stdout={p.stdout!r}")
        sys.exit(1)
    if "error" not in p.stderr.lower():
        print(f"--project nonexistent: expected an error on stderr, got {p.stderr!r}")
        sys.exit(1)
    # X4 regression (path containment — --project traversal): a `--project`
    # value that `../`-escapes <kb_root>/repos/ must error (exit 2) + stderr,
    # NEVER scan the out-of-tree subtree. Plant a real dir outside repos/ so a
    # bare is_dir() check (the iter-1 validation) would otherwise pass.
    (Path(td) / "secret").mkdir()
    (Path(td) / "secret" / "x.md").write_text("# x\n", encoding="utf-8")
    trav = subprocess.run(
        [sys.executable, scanner, td, "--project", "../secret"],
        capture_output=True, text=True,
    )
    if trav.returncode != 2:
        print(f"--project ../traversal: expected exit 2 (not an out-of-tree scan), got {trav.returncode}; stdout={trav.stdout!r}")
        sys.exit(1)
    if "error" not in trav.stderr.lower():
        print(f"--project ../traversal: expected an error on stderr, got {trav.stderr!r}")
        sys.exit(1)
    # Control: an EXISTING project still scans (exit 0, no findings here).
    ok = subprocess.run(
        [sys.executable, scanner, td, "--project", "realproj"],
        capture_output=True, text=True,
    )
    if ok.returncode != 0 or json.loads(ok.stdout)["findings"] != []:
        print(f"--project existing: expected exit 0 / no findings, got rc={ok.returncode} out={ok.stdout!r}")
        sys.exit(1)

# C2 cross-repo basename-collision resolver (nested/ repos/-layout vault). The
# flat clean/+drift/ fixtures can't exercise nested-source resolution, so scan
# nested/ in ISOLATION and assert PER-SOURCE-FILE (the single scanned root
# aggregates N1-N6, so an aggregate-only count could mask a per-file regression
# another file offsets, X6). The new target-class dispatch resolver:
#   N1 src.md  `CLAUDE.md` §X            → bare → SOURCE-relative only → absent
#              → skip → 0 C2 (THE regression witness: the bait nested/CLAUDE.md
#              exists, so the OLD cand_root=kb_root/CLAUDE.md would heading-
#              mismatch false-flag it).
#   N2 src2.md `NOPE-ROOT.md` §X         → bare absent everywhere → skip → 0 C2
#              (escape branch NOT tripped on a resolves-nowhere bare name; a
#              DISTINCT absent basename so it coexists with N1's present bait).
#   N5 src5.md `repos/projB/design/t.md` §Present → repos/-prefix → vault-root-
#              relative only → REAL projB t.md (Present present) → 0 C2 (NOT the
#              local shadow projA/design/repos/projB/design/t.md; the OLD
#              cand_rel-first resolver hit the shadow → false C2).
#   N3 src3.md `sib.md` §Gone            → source-relative → sib.md present,
#              heading gone → exactly 1 C2 "no matching heading" (genuine same-
#              dir dangling stays flagged — no over-suppression).
#   N4 src4.md `repos/projB/design/t.md` §Gone → repos/-prefix → REAL t.md,
#              heading gone → exactly 1 C2 "no matching heading".
#   N6 src6.md `../../../../escape-target/Note.md` §H → ..-traversal → escape-
#              only candidate is a REAL committed file OUT of the nested/ vault
#              → exactly 1 C2 "escapes vault containment" (X2 target-must-exist +
#              X5 depth-pinned; the explicit is_file() and not is_contained()
#              escape test).
#   N7 CLAUDE.md `CLAUDE.md` §X → now-scanned root file (whole-vault no-project
#              scope): the bait's OWN prose pointer resolves SOURCE-relative to
#              the root nested/CLAUDE.md (present, heading X absent) → exactly 1
#              C2 "no matching heading". Before the whole-vault widening this
#              root file was never scanned (repos/* only); it is now a CORRECT
#              finding, not a regression.
# Aggregate nested/ C2 total = 4 (N3 + N4 + N6 + N7).
n = subprocess.run([sys.executable, scanner, nested], capture_output=True, text=True)
if n.returncode != 1:
    print(f"nested fixture: expected exit 1 (N3+N4+N6+N7 drift), got {n.returncode}; stdout={n.stdout!r}")
    sys.exit(1)
NF = json.loads(n.stdout)["findings"]
nc2 = [f for f in NF if f["class"] == "C2_dangling_section_pointer"]
# Per-source-file expectations: (count, substring-in-detail-or-None).
nested_expect = {
    "repos/projA/design/src.md": (0, None),    # N1 collision bait present → still 0
    "repos/projA/design/src2.md": (0, None),   # N2 resolves nowhere → skip
    "repos/projA/design/src5.md": (0, None),   # N5 repos/-prefix → real file, no shadow
    "repos/projA/design/src3.md": (1, "no matching heading"),   # N3 genuine same-dir
    "repos/projA/design/src4.md": (1, "no matching heading"),   # N4 explicit repos/ xrepo
    "repos/projA/design/src6.md": (1, "escapes vault containment"),  # N6 nested escape
    "CLAUDE.md": (1, "no matching heading"),   # N7 now-scanned root file (whole-vault scope)
}
for src, (want_n, want_sub) in nested_expect.items():
    hits = [f for f in nc2 if f["file"] == src]
    if len(hits) != want_n:
        print(f"nested {src}: expected {want_n} C2 finding(s), got {len(hits)}: {hits}")
        sys.exit(1)
    if want_sub is not None and want_sub not in hits[0]["detail"]:
        print(f"nested {src}: expected C2 detail to contain {want_sub!r}, got {hits[0]['detail']!r}")
        sys.exit(1)
if len(nc2) != 4:
    print(f"nested fixture: expected exactly 4 C2 findings (N3+N4+N6+N7), got {len(nc2)}: {nc2}")
    sys.exit(1)
if any(f["auto_safe"] is not False for f in nc2):
    print(f"nested C2 findings must all be auto_safe:false, got {[f['auto_safe'] for f in nc2]}")
    sys.exit(1)

# C1 path-qualified wikilink suffix-match resolution (#76d FN-closer). The flat
# clean/+drift/ fixtures can't exercise path-qualified targets, so scan the
# pathqual/ vault in ISOLATION and assert PER-SOURCE-FILE C1 (a single scanned
# root aggregates all sources, so an aggregate-only count could mask a per-file
# regression another file offsets). Obsidian resolves `[[a/Note]]` by COMPONENT-
# SUFFIX, so the CLEAN witnesses MUST stay clean; the 2 BROKEN witnesses MUST
# each flag exactly 1 C1 (the old unconditional bare-stem fallback false-
# NEGATIVE'd them because the bare stem exists elsewhere).
#   src/suffix.md   `[[a/SuffixTarget]]`  → suffix of x/a/SuffixTarget.md → 0 C1.
#   src/case.md     `[[a/casetarget.md]]` → lowercased + .md-stripped suffix of
#                   x/a/CaseTarget.md → 0 C1 (case-insensitive + .md-suffixed).
#   src/slashnorm.md `[[/a/SuffixTarget]]` `[[a//SuffixTarget]]`
#                   `[[a/SuffixTarget/]]` → empties dropped → all suffix-match
#                   x/a/SuffixTarget.md → 0 C1 (slash normalization).
#   docs/src.md     `[[../docs/findings]]` → source-relative FS resolve to
#                   docs/findings.md (Option B) → 0 C1 (relative no-FP-lock; a
#                   strict ..-reject would false-positive this live-vault shape).
#   src/broken-fn.md `[[wrong/path/UniquePathTarget]]` → NOT a suffix of
#                   right/path/UniquePathTarget.md → exactly 1 C1 (the FN closed).
#   src/broken-boundary.md `[[xa/BoundaryTarget]]` → NOT a suffix of
#                   x/a/BoundaryTarget.md (component boundary, not string) → 1 C1.
pq = subprocess.run([sys.executable, scanner, pathqual], capture_output=True, text=True)
if pq.returncode != 1:
    print(f"pathqual fixture: expected exit 1 (2 BROKEN sources), got {pq.returncode}; stdout={pq.stdout!r}")
    sys.exit(1)
PQF = json.loads(pq.stdout)["findings"]
pqc1 = [f for f in PQF if f["class"] == "C1_broken_wikilink"]
pathqual_expect = {
    "src/suffix.md": 0,          # component-suffix CLEAN
    "src/case.md": 0,            # case-insensitive + .md-suffixed CLEAN
    "src/slashnorm.md": 0,       # slash-normalization CLEAN
    "docs/src.md": 0,            # relative no-FP-lock CLEAN (Option B)
    "src/broken-fn.md": 1,       # FN-closer BROKEN (1 C1)
    "src/broken-boundary.md": 1,  # component-boundary BROKEN (1 C1)
}
for src, want_n in pathqual_expect.items():
    hits = [f for f in pqc1 if f["file"] == src]
    if len(hits) != want_n:
        print(f"pathqual {src}: expected {want_n} C1 finding(s), got {len(hits)}: {hits}")
        sys.exit(1)
if len(pqc1) != 2:
    print(f"pathqual fixture: expected exactly 2 C1 findings (broken-fn + broken-boundary), got {len(pqc1)}: {pqc1}")
    sys.exit(1)

# X1 resolver-level unit witness (NON-VACUOUS source-relative FS branch). The
# pathqual/ [[../docs/findings]] fixture above guards strict-..-non-rejection
# only: in an isolated scan note_index spans the whole kb_root, so the retained
# bare-stem fallback (`parts[-1] in note_index`) reproduces a clean verdict with
# OR without the FS branch — toggling the branch can't change that fixture's
# verdict. The FS branch's DISTINCT contribution (a relative link to a REAL
# target that the fallback would miss because its stem is absent from the index)
# needs a direct unit assertion: call wikilink_resolves_as_written with a
# note_index that EXCLUDES the target stem + a real on-disk relative target →
# clean can then come ONLY from the source-relative FS branch (the fallback
# returns False). Removing/breaking that branch flips this assertion.
import importlib.util  # noqa: E402
spec = importlib.util.spec_from_file_location("kb_drift_scan_x1", scanner)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    (root / "docs").mkdir()
    (root / "src").mkdir()
    (root / "docs" / "findings.md").write_text("# Findings\n", encoding="utf-8")
    source = root / "src" / "note.md"
    source.write_text("# Note\n[[../docs/findings]]\n", encoding="utf-8")
    # note_index DELIBERATELY EMPTY → the bare-stem fallback `parts[-1] in
    # note_index` (`"findings" in {}`) returns False. A clean verdict can come
    # ONLY from the source-relative FS branch resolving src/../docs/findings.md.
    empty_note_index = {}
    empty_suffix_index = set()
    if "findings" in empty_note_index:
        print("X1 witness setup error: stem must be EXCLUDED from note_index")
        sys.exit(1)
    resolved = mod.wikilink_resolves_as_written(
        "../docs/findings", root, empty_note_index, empty_suffix_index, source
    )
    if resolved is not True:
        print("X1 witness: ../docs/findings with stem-excluded note_index + real "
              f"on-disk target must resolve clean via the FS branch, got {resolved!r}")
        sys.exit(1)
    # Control: with NO on-disk target AND the stem excluded, the same call must
    # return False — proves the True above came from the FS branch, not a
    # vacuous always-True path.
    (root / "docs" / "findings.md").unlink()
    unresolved = mod.wikilink_resolves_as_written(
        "../docs/findings", root, empty_note_index, empty_suffix_index, source
    )
    if unresolved is not False:
        print("X1 control: ../docs/findings with NO on-disk target + stem-excluded "
              f"note_index must NOT resolve, got {unresolved!r}")
        sys.exit(1)

print("kb_drift_scan: clean exit0/no-findings; drift exit1 with C1+C2+C3+C4+C5+C6, autonomy boundary intact; C3 frontmatter-scoped (X1); C4 status-drift on both structured + Log-marker paths (total 2), IN_PROGRESS/terminal/pre-impl/blocked stay clean (anti-FP); C5-R research-status enum (type:research-scoped): off-enum status: OPEN at line 4 + no-status line:null (total 2), legacy type:research-note under research/ dir segment NOT flagged (clean-dir-zero); code-aware (fenced+inline [[]] and C2-in-fence and tilde/longer fences → zero) + cross-repo pointer not flagged; --project-typo errors exit2 (X2); out-of-vault wikilink+pointer reported (X5); --project ../traversal errors exit2 (X4); nested/ C2 cross-repo resolver per-file: N1/N2/N5 clean, N3/N4 dangling-heading, N6 escapes-containment, N7 now-scanned root CLAUDE.md dangling-heading (whole-vault scope; aggregate C2=4, X6); pathqual/ C1 suffix-match per-source: suffix/case/slashnorm/relative CLEAN, broken-fn/broken-boundary 1 C1 each (#76d, aggregate C1=2) + X1 FS-branch unit witness (stem-excluded note_index + real relative target → clean via FS branch, control → broken)")
PYEOF
}

# Behavioral: `kb_drift_scan.py --summary` renders the human digest contract
# (§3.2) — a stable line-1 headline + per-class grouped detail with the correct
# auto_safe boundary tag — WITHOUT altering scan results. Mirrors
# check_kb_drift_scan_behavioral: imports the module and asserts exit via
# main() (status-explicit, never pipes the CLI's intentional nonzero exit
# through head). Catches a regression where the headline format drifts (the
# status fold reads line 1), a per-class count diverges from the --json tally
# (render altered the scan), the boundary tag is wrong, the null-line C3 finding
# renders the literal `:None`, or --summary stops winning over --json.
check_kb_drift_summary_behavioral() {
  local scanner="$PLUGIN_ROOT/tests/kb_drift_scan.py"
  local clean="$PLUGIN_ROOT/tests/fixtures/kb-drift/clean"
  local drift="$PLUGIN_ROOT/tests/fixtures/kb-drift/drift"
  local nullline="$PLUGIN_ROOT/tests/fixtures/kb-drift/null-line"
  [ -f "$scanner" ] || { echo "$scanner missing"; return 1; }
  [ -d "$clean" ] || { echo "$clean fixture dir missing"; return 1; }
  [ -d "$drift" ] || { echo "$drift fixture dir missing"; return 1; }
  [ -d "$nullline" ] || { echo "$nullline fixture dir missing"; return 1; }
  python3 - "$scanner" "$clean" "$drift" "$nullline" <<'PYEOF'
import importlib.util, io, sys
from contextlib import redirect_stdout
from pathlib import Path

scanner, clean, drift, nullline = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

# Import the scanner module (status-explicit: call main()/render_summary
# directly rather than piping the CLI through head, which would mask the
# intentional nonzero exit — the X5 fix).
spec = importlib.util.spec_from_file_location("kb_drift_scan", scanner)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def run(argv):
    """Call main(argv); capture stdout + exit code (status BEFORE the pipe)."""
    buf = io.StringIO()
    with redirect_stdout(buf):
        rc = mod.main(argv)
    return rc, buf.getvalue()


# (a) clean fixture → exact clean headline + exit 0.
rc, out = run([clean, "--summary"])
if rc != 0:
    print(f"(a) clean --summary: expected exit 0, got {rc}")
    sys.exit(1)
line1 = out.splitlines()[0]
scanned_clean = mod.scan(Path(clean), None)["scanned"]
want_clean = f"✓ KB clean — 0 drift findings (scanned {scanned_clean})"
if line1 != want_clean:
    print(f"(a) clean headline mismatch:\n  want: {want_clean!r}\n  got:  {line1!r}")
    sys.exit(1)

# (b) drift fixture → ⚠ headline WITH per-class counts in canonical C1<C2<C3<C4
# order AND trailing (scanned <N>) + exit 1. Per-class counts MUST match the
# --json finding tally (proves render didn't alter the scan).
rc, out = run([drift, "--summary"])
if rc != 1:
    print(f"(b) drift --summary: expected exit 1, got {rc}")
    sys.exit(1)
report = mod.scan(Path(drift), None)
findings = report["findings"]
counts = {}
for f in findings:
    short = f["class"].split("_", 1)[0]
    counts[short] = counts.get(short, 0) + 1
present = [s for s in ("C1", "C2", "C3", "C4", "C5", "C6", "C7") if s in counts]
want_counts = " ".join(f"{s}:{counts[s]}" for s in present)
want_drift = (
    f"⚠ KB drift — {len(findings)} findings: {want_counts} "
    f"(scanned {report['scanned']})"
)
line1 = out.splitlines()[0]
if line1 != want_drift:
    print(f"(b) drift headline mismatch:\n  want: {want_drift!r}\n  got:  {line1!r}")
    sys.exit(1)

# (c) detail block group headers `<full-class> (<count>) [<boundary>]` must
# EXACTLY match — in canonical C1<C2<C3<C4 order — the set of classes the
# --json tally proves present. A regressed render_summary that emits the right
# headline (computed independently in block (b)) but DROPS a detail group (e.g.
# C2/C4) or empties one would slip past a tally-only check; here every expected
# property is derived from the parsed findings and asserted against the rendered
# detail block: (1) the group-header sequence equals the expected canonical set
# AND order (a dropped/extra/reordered group → FAIL); (2) each header carries
# the boundary tag computed from THAT group's findings — `needs human decision`
# iff any finding in the group is auto_safe:false, else `auto-safe` — for ALL
# classes INCLUDING C1 (so a C1 group wrongly tagged [auto-safe] also fails);
# (3) each group renders exactly the expected number of indented finding lines
# (a group present-but-empty → FAIL).
import re

# Expected per-group facts derived from the already-parsed --json findings,
# grouped by CLASS_SHORT preserving scan order (mirrors render_summary's group).
groups = {}
for f in findings:
    short = f["class"].split("_", 1)[0]
    groups.setdefault(short, []).append(f)
expected_headers = []  # (full_class, count, boundary, finding_line_count) in canonical order
for short in present:
    grp = groups[short]
    full_class = grp[0]["class"]
    boundary = "needs human decision" if any(not g["auto_safe"] for g in grp) else "auto-safe"
    expected_headers.append((full_class, len(grp), boundary, len(grp)))

# Parse the rendered detail block: a header line opens a group; the indented
# `  ` lines that follow are its finding lines (until the next header).
detail = out.splitlines()[1:]
header_re = re.compile(r"^(\S+) \((\d+)\) \[(needs human decision|auto-safe)\]$")
rendered = []  # (full_class, count, boundary, finding_line_count) in render order
for d in detail:
    m = header_re.match(d)
    if m:
        rendered.append([m.group(1), int(m.group(2)), m.group(3), 0])
    elif d.startswith("  "):
        if not rendered:
            print(f"(c) indented finding line before any group header:\n{out}")
            sys.exit(1)
        rendered[-1][3] += 1
    elif d.strip():
        print(f"(c) unexpected non-header, non-indented detail line {d!r}:\n{out}")
        sys.exit(1)
rendered = [tuple(r) for r in rendered]

if rendered != expected_headers:
    print(
        "(c) detail group headers/order/boundary/finding-line-count mismatch:\n"
        f"  want (canonical, from json tally): {expected_headers}\n"
        f"  got  (rendered):                   {rendered}\n{out}"
    )
    sys.exit(1)

# (d) NEW null-line fixture (type:spec doc, NO status: line → C3 line:None)
# renders `  <file> — <detail>` with NO literal `:None` (X2).
nl_report = mod.scan(Path(nullline), None)
nl_findings = nl_report["findings"]
if not any(f["class"] == "C3_status_enum_violation" and f["line"] is None for f in nl_findings):
    print(f"(d) null-line fixture must produce a C3 finding with line:None, got {nl_findings}")
    sys.exit(1)
rc, out = run([nullline, "--summary"])
if rc != 1:
    print(f"(d) null-line --summary: expected exit 1, got {rc}")
    sys.exit(1)
finding_lines = [d for d in out.splitlines() if d.startswith("  ")]
if not finding_lines:
    print(f"(d) null-line --summary produced no finding lines:\n{out}")
    sys.exit(1)
if any(":None" in d for d in out.splitlines()):
    print(f"(d) null-line render must NOT contain the literal ':None':\n{out}")
    sys.exit(1)
want_nl = "  spec-no-status.md — type: spec doc has no frontmatter status:"
if want_nl not in out.splitlines():
    print(f"(d) null-line finding line missing; want {want_nl!r} in:\n{out}")
    sys.exit(1)

# (e) error path (bad kb_root) still exit 2.
rc, _ = run(["/nonexistent/kb/root/xyz", "--summary"])
if rc != 2:
    print(f"(e) bad kb_root --summary: expected exit 2, got {rc}")
    sys.exit(1)

# (f) --summary --json together → summary output wins (line 1 is the headline,
# not a JSON brace).
rc, out = run([drift, "--summary", "--json"])
if rc != 1:
    print(f"(f) --summary --json: expected exit 1, got {rc}")
    sys.exit(1)
line1 = out.splitlines()[0]
if line1 != want_drift:
    print(f"(f) --summary --json must render the summary headline, got {line1!r}")
    sys.exit(1)

print("kb_drift_scan --summary: clean headline exact + exit0; drift headline per-class counts canonical-order matching json tally + exit1; group header boundary tags correct (C2/C3/C4 human-decision); null-line C3 renders <file> — <detail> with NO :None (X2); bad kb_root exit2; --summary --json → summary wins (X3)")
PYEOF
}

# Behavioral: C6 index-row bloat (spec 2026-06-02-c6-index-row-bloat-check).
# Builds isolated single-file vaults so each assertion pins one C6 mechanic with
# byte-exact expectations (line, measure, detail) the shared-dir class-set pins
# cannot reach: the 301-flag / 300-clean STRICT boundary with the detail measure
# substring (a `>=` comparator or wrong measure flips it); a >300 `-` bullet and
# a >300 `1.` ordered entry firing at the correct 1-based line with the POST-
# MARKER measure (a full-line measure would inflate the number); a non-index
# `type: reference` >300 line that must NOT flag (scope); the UNESCAPED-pipe cell
# split (a cell `200*"a" + "\|" + 200*"b"` is ONE 402-char cell that flags — a
# naive `|` split would yield two ≤300 cells and miss it); and a no-frontmatter
# `vault-index.md` >300 row firing via the basename clause above the FM gate (X1).
check_kb_drift_c6_index_row_bloat() {
  local scanner="$PLUGIN_ROOT/tests/kb_drift_scan.py"
  [ -f "$scanner" ] || { echo "$scanner missing"; return 1; }
  python3 - "$scanner" <<'PYEOF'
import json, subprocess, sys, tempfile
from pathlib import Path

scanner = sys.argv[1]


def scan_one(name, body):
    """Write a single file into a fresh vault, scan it, return its findings."""
    with tempfile.TemporaryDirectory() as td:
        (Path(td) / name).write_text(body, encoding="utf-8")
        r = subprocess.run([sys.executable, scanner, td], capture_output=True, text=True)
        return json.loads(r.stdout)["findings"]


def c6(findings):
    return [f for f in findings if f["class"] == "C6_index_row_bloat"]


IDX = "---\ntitle: T\ntype: index\ncreated: 2026-06-02\n---\n\n# T\n\n"
HEAD = "| Page | Summary |\n|------|---------|\n"

# (1) STRICT boundary: a cell of exactly 301 flags with the measure in detail;
# exactly 300 stays clean. Pins the `> THRESHOLD` comparator + the per-cell
# measure + the detail substring.
flag = c6(scan_one("idx.md", IDX + HEAD + "| p | " + "x" * 301 + " |\n"))
if len(flag) != 1:
    print(f"(1) cell=301 must yield exactly 1 C6, got {len(flag)}: {flag}")
    sys.exit(1)
if "301 chars > 300" not in flag[0]["detail"]:
    print(f"(1) cell=301 detail must carry '301 chars > 300', got {flag[0]['detail']!r}")
    sys.exit(1)
if flag[0]["auto_safe"] is not False:
    print(f"(1) C6 must be auto_safe:false, got {flag[0]['auto_safe']!r}")
    sys.exit(1)
clean300 = c6(scan_one("idx.md", IDX + HEAD + "| p | " + "x" * 300 + " |\n"))
if clean300 != []:
    print(f"(1) cell=300 must NOT flag (strict >), got {clean300}")
    sys.exit(1)

# (2) List entries: a >300 `-` bullet and a >300 `1.` ordered entry each flag at
# their correct 1-based line with the POST-MARKER measure (315 / 325 — NOT the
# full-line length, which would be larger by the marker width).
bullet = "B" * 315
ordered = "O" * 325
body = IDX + "- " + bullet + "\n1. " + ordered + "\n"
lf = c6(scan_one("list.md", body))
by_line = {f["line"]: f for f in lf}
# IDX is 6 lines of frontmatter (---,title,type,created,---) + blank + "# T" +
# blank → the body list starts at file line 9.
if 9 not in by_line or "315 chars > 300" not in by_line[9]["detail"]:
    print(f"(2) `-` bullet must flag at line 9 with measure 315 (post-marker), got {lf}")
    sys.exit(1)
if 10 not in by_line or "325 chars > 300" not in by_line[10]["detail"]:
    print(f"(2) `1.` ordered entry must flag at line 10 with measure 325 (post-marker), got {lf}")
    sys.exit(1)
if len(lf) != 2:
    print(f"(2) expected exactly 2 C6 list findings, got {len(lf)}: {lf}")
    sys.exit(1)

# (3) Scope: a non-index `type: reference` file with a >300 cell/line must NOT
# flag (the predicate restricts C6 to type∈{moc,index} or vault-index.md).
ref = "---\ntitle: R\ntype: reference\ncreated: 2026-06-02\n---\n\n# R\n\n" + HEAD + "| t | " + "y" * 360 + " |\n"
refc6 = c6(scan_one("ref.md", ref))
if refc6 != []:
    print(f"(3) non-index type:reference >300 line must NOT flag, got {refc6}")
    sys.exit(1)

# (4) Unescaped-pipe cell split: a cell `200*"a" + "\|" + 200*"b"` is ONE logical
# cell measuring 402 (200 + len("\\|")==2 + 200) and MUST flag. A naive `|`
# split would yield two cells of 201 / 200 (both ≤300) and miss it entirely —
# this discriminates split_unescaped_pipes' parity behavior (one `\` is odd, so
# the pipe is escaped and stays inside the cell).
escaped_cell = "a" * 200 + "\\|" + "b" * 200
assert len(escaped_cell) == 402, len(escaped_cell)
moc = "---\ntitle: M\ntype: moc\ncreated: 2026-06-02\n---\n\n# M\n\n" + HEAD + "| p | " + escaped_cell + " |\n"
mocc6 = c6(scan_one("moc.md", moc))
if len(mocc6) != 1 or "402 chars > 300" not in mocc6[0]["detail"]:
    print(f"(4) escaped-pipe cell must be ONE 402-char cell that flags (not split into two ≤300 cells), got {mocc6}")
    sys.exit(1)

# (5) No-frontmatter vault-index.md: a >300 row fires via the basename clause —
# proves C6 runs ABOVE the frontmatter gate (X1). A file with no leading
# frontmatter returns None from leading_frontmatter(); a C6 block placed with
# C3/C4/C5 (after the `frontmatter is None: continue`) would never reach it.
vi = "# Vault Index\n\n" + HEAD + "| p | " + "z" * 441 + " |\n"
vic6 = c6(scan_one("vault-index.md", vi))
if len(vic6) != 1 or "441 chars > 300" not in vic6[0]["detail"]:
    print(f"(5) no-frontmatter vault-index.md >300 row must flag via basename clause (X1), got {vic6}")
    sys.exit(1)
# Control: the SAME body in a file that is NEITHER type∈{moc,index} NOR named
# vault-index.md must NOT flag (proves the basename clause, not a blanket scan).
ctrl = c6(scan_one("notes.md", vi))
if ctrl != []:
    print(f"(5) control: a non-vault-index no-frontmatter file must NOT flag, got {ctrl}")
    sys.exit(1)

# (6) Backslash-parity unit assertions on the split primitive: a `|` is a CELL
# separator iff the preceding `\` run is EVEN. `a\\|b` (2 `\`, even) SPLITS into
# `['a\\', 'b']`; `a\|b` (1 `\`, odd) does NOT split (escaped pipe stays in cell).
# And c6_table_row_measure on a row whose real cells split at a `\\|` separator
# measures the SPLIT cells (max 200) — not the merged 402. Kills a revert to the
# single-`\` lookbehind (which would refuse to split `\\|` and merge the cells).
import importlib.util as _u
_s = _u.spec_from_file_location("kb_drift_scan", scanner)
_m = _u.module_from_spec(_s)
_s.loader.exec_module(_m)
BS = chr(92)
even = _m.split_unescaped_pipes("a" + BS * 2 + "|b")
if even != ["a" + BS * 2, "b"]:
    print(f"(6) split_unescaped_pipes must SPLIT even-parity `\\\\|`, got {even!r}")
    sys.exit(1)
odd = _m.split_unescaped_pipes("a" + BS + "|b")
if odd != ["a" + BS + "|b"]:
    print(f"(6) split_unescaped_pipes must NOT split odd-parity `\\|`, got {odd!r}")
    sys.exit(1)
# Row with a REAL `\\|` separator: the even `\\|` splits the cells, so the left
# cell is 200*"a"+two raw backslashes = 202 (C6 keeps raw bytes — no parity
# collapse) and the right is 200*"b" = 200. The max measured cell is 202, NOT the
# merged 402. (`\|`, odd, would stay merged at 402 — covered by (4).)
sep_row = "| " + "a" * 200 + BS * 2 + "|" + "b" * 200 + " |"
measure = _m.c6_table_row_measure(sep_row)
if measure != 202:
    print(f"(6) c6_table_row_measure must measure the SPLIT cells (max 202) on a real `\\\\|` separator, got {measure}")
    sys.exit(1)

print("kb_drift_scan C6: 301-flag/300-clean strict boundary + detail measure; `-` bullet@9 (315) and `1.` ordered@10 (325) post-marker measure; non-index type:reference >300 NOT flagged (scope); unescaped-pipe cell 402 flags as ONE cell (not naive-split into two ≤300); no-frontmatter vault-index.md 441 flags via basename clause above the FM gate (X1) + control non-vault-index clean; split_unescaped_pipes parity unit — splits even `\\|`, not odd `\|`, and c6_table_row_measure splits a real `\\|` separator (201 not 402)")
PYEOF
}

# Behavioral: C7 backlog-done-bloat (spec 2026-06-04-backlog-curator). Builds two
# single-project vaults and pins the STRICT threshold boundary: a BACKLOG.md with
# exactly C7_BLOAT_THRESHOLD (12) struck-done lines fires C7 in the `--summary`
# headline (`C7:` token present), while one with 11 stays clean (no C7). Both the
# struck section-header form (`^### ~~`) and the struck table-row form (`^\s*\| ~~`)
# count toward the tally, and the BACKLOG carries NO frontmatter (proves C7 runs
# above the frontmatter gate, alongside C6). Mutation-protected: drop the `>=`
# threshold compare (fire on any count, or fire at 11) and the 11-struck clean
# assertion goes RED; key the regex on a non-line-start pattern (so prose
# `- ~~…~~` mentions count) and the low-FP boundary breaks.
check_kb_drift_c7_backlog_bloat() {
  local scanner="$PLUGIN_ROOT/tests/kb_drift_scan.py"
  [ -f "$scanner" ] || { echo "$scanner missing"; return 1; }
  python3 - "$scanner" <<'PYEOF'
import subprocess, sys, tempfile
from pathlib import Path

scanner = sys.argv[1]


def summary(struck_headers, struck_rows, prose_mentions=0):
    """Build a single-project vault whose BACKLOG.md (NO frontmatter) carries the
    given count of struck section headers + struck table rows + line-start-absent
    prose `~~` mentions; return the `--summary` stdout."""
    with tempfile.TemporaryDirectory() as td:
        proj = Path(td) / "repos" / "ai-dev-team"
        proj.mkdir(parents=True)
        lines = ["# Backlog", ""]
        for i in range(struck_headers):
            lines.append(f"### ~~{i}. done~~ ✅ DONE (2026-04-17)")
            lines.append("body")
        if struck_rows:
            lines += ["", "| # | Item | Status |", "|---|------|--------|"]
            for i in range(struck_rows):
                lines.append(f"| ~~**{100 + i}**~~ | done | ✅ DONE |")
        for i in range(prose_mentions):
            lines.append(f"- a ~~struck prose mention {i}~~ inline, not at line start")
        (proj / "BACKLOG.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
        r = subprocess.run(
            [sys.executable, scanner, str(td), "--project", "ai-dev-team", "--summary"],
            capture_output=True,
            text=True,
        )
        return r.stdout


# (1) STRICT threshold: exactly 12 struck items (>= C7_BLOAT_THRESHOLD) → C7 fires
# in the headline; 11 stays clean. A `>` instead of `>=`, or any-count firing,
# flips one of these.
bloat = summary(12, 0)
if "C7:" not in bloat.splitlines()[0]:
    print(f"(1) 12 struck headers must fire C7 in headline, got: {bloat.splitlines()[0]!r}")
    sys.exit(1)
lean = summary(11, 0)
if "C7:" in lean:
    print(f"(1) 11 struck headers (< threshold) must NOT fire C7, got: {lean!r}")
    sys.exit(1)

# (2) Both struck forms count: 6 struck headers + 6 struck table rows = 12 → fires.
mixed = summary(6, 6)
if "C7:" not in mixed.splitlines()[0]:
    print(f"(2) 6 headers + 6 struck rows (=12) must fire C7, got: {mixed.splitlines()[0]!r}")
    sys.exit(1)

# (3) Low-FP: 11 struck items + many `- ~~…~~` prose mentions (NOT line-start
# struck markers) must stay clean — prose `~~` must not be counted toward C7.
fp = summary(11, 0, prose_mentions=20)
if "C7:" in fp:
    print(f"(3) prose `- ~~…~~` mentions must NOT count toward C7, got: {fp!r}")
    sys.exit(1)

print("kb_drift_scan C7: 12-struck-fires / 11-clean strict threshold; header + table-row struck forms both count (6+6=12); no-frontmatter (above FM gate); prose `- ~~…~~` line-start-absent mentions NOT counted (low-FP)")
PYEOF
}

# Behavioral: C8_terminal_evidence_gap (spec 2026-07-05 §3.3). Scans the dedicated
# c8-fire / c8-nonfire fixture dirs and ID-anchors that a TERMINAL spec status
# (SHIPPED/VERIFIED/DONE) on a post-cutoff spec fires iff an audit-evidence key is
# absent / literal-null / off-enum, and NEVER fires pre-cutoff / non-terminal /
# both-keys-valid / created-absent / created-malformed. Mutation sensitivity: an
# ABSENCE-ONLY implementation fails the literal-null + off-enum fire fixtures (the
# incident signature — finding 6); dropping DONE from TERMINAL_SPEC_STATUSES fails
# fire-done-missing; a `>` instead of `>=` on the cutoff, or dropping the created
# well-formedness/skip gate, flips the nonfire pre-cutoff / created-malformed /
# created-absent cases; a per-key defect-shape mislabel flips the detail asserts.
check_kb_drift_c8_terminal_evidence_gap() {
  local scanner="$PLUGIN_ROOT/tests/kb_drift_scan.py"
  local fire="$PLUGIN_ROOT/tests/fixtures/kb-drift/c8-fire"
  local nonfire="$PLUGIN_ROOT/tests/fixtures/kb-drift/c8-nonfire"
  [ -f "$scanner" ] || { echo "$scanner missing"; return 1; }
  [ -d "$fire" ] || { echo "$fire fixture dir missing"; return 1; }
  [ -d "$nonfire" ] || { echo "$nonfire fixture dir missing"; return 1; }
  python3 - "$scanner" "$fire" "$nonfire" <<'PYEOF'
import json, subprocess, sys, tempfile
from pathlib import Path

scanner, fire, nonfire = sys.argv[1], sys.argv[2], sys.argv[3]

# --- FIRE dir: exit 1, exactly the 5 defect-shape fires, all auto_safe:false ---
f = subprocess.run([sys.executable, scanner, fire], capture_output=True, text=True)
if f.returncode != 1:
    print(f"c8-fire: expected exit 1 (>=1 finding), got {f.returncode}; out={f.stdout!r}")
    sys.exit(1)
F = json.loads(f.stdout)["findings"]
c8 = [x for x in F if x["class"] == "C8_terminal_evidence_gap"]
other = [x for x in F if x["class"] != "C8_terminal_evidence_gap"]
if other:
    print(f"c8-fire: fixtures must fire ONLY C8, got stray classes: {other}")
    sys.exit(1)
by_file = {x["file"]: x for x in c8}
# Per-fixture defect-shape contract. Each names the terminal status + the exact
# defect shape (missing / literal-null / off-enum) + the specific key — an
# absence-only implementation cannot satisfy the null/off-enum rows.
expected = {
    "fire-spec-audit-absent.md":  ["SHIPPED", "spec_audit_evidence missing"],
    "fire-spec-audit-null.md":    ["VERIFIED", "spec_audit_evidence literal-null"],
    "fire-code-audit-null.md":    ["SHIPPED", "code_audit_evidence literal-null"],
    "fire-off-enum.md":           ["VERIFIED", "spec_audit_evidence off-enum"],
    "fire-done-missing.md":       ["DONE", "spec_audit_evidence missing", "code_audit_evidence missing"],
}
if set(by_file) != set(expected):
    print(f"c8-fire: expected fires on {sorted(expected)}, got {sorted(by_file)}")
    sys.exit(1)
for fname, needles in expected.items():
    fnd = by_file[fname]
    if fnd["auto_safe"] is not False:
        print(f"c8-fire {fname}: C8 must be auto_safe:false, got {fnd['auto_safe']}")
        sys.exit(1)
    if not ({"class", "file", "line", "detail", "auto_safe"} <= set(fnd)):
        print(f"c8-fire {fname}: finding missing required keys: {fnd}")
        sys.exit(1)
    for needle in needles:
        if needle not in fnd["detail"]:
            print(f"c8-fire {fname}: detail must name {needle!r}, got: {fnd['detail']!r}")
            sys.exit(1)
# The single-key fires must NOT over-report the healthy sibling key.
if "literal-null" in by_file["fire-spec-audit-absent.md"]["detail"]:
    print("c8-fire fire-spec-audit-absent.md: must NOT name a literal-null defect (only the absent key)")
    sys.exit(1)

# --- NON-FIRE dir: no C8 anywhere (aggregate) AND per-file in isolation ---
n = subprocess.run([sys.executable, scanner, nonfire], capture_output=True, text=True)
nf = json.loads(n.stdout)["findings"]
if any(x["class"] == "C8_terminal_evidence_gap" for x in nf):
    print(f"c8-nonfire: no C8 finding expected, got: {[x for x in nf if x['class']=='C8_terminal_evidence_gap']}")
    sys.exit(1)
nonfire_files = {
    "nonfire-precutoff.md":         "created < cutoff → legacy_unknown",
    "nonfire-nonterminal.md":       "IN_PROGRESS not terminal",
    "nonfire-both-valid.md":        "both keys present + enum-valid",
    "nonfire-created-absent.md":    "created absent → skip",
    "nonfire-created-malformed.md": "created malformed → skip",
}
for fname, why in nonfire_files.items():
    fp = Path(nonfire) / fname
    if not fp.is_file():
        print(f"c8-nonfire missing {fname} ({why})")
        sys.exit(1)
    with tempfile.TemporaryDirectory() as td:
        (Path(td) / fname).write_text(fp.read_text(encoding="utf-8"), encoding="utf-8")
        r = subprocess.run([sys.executable, scanner, td], capture_output=True, text=True)
        rf = json.loads(r.stdout)["findings"]
        if any(x["class"] == "C8_terminal_evidence_gap" for x in rf):
            print(f"c8-nonfire {fname}: must NOT fire C8 ({why}), got {rf}")
            sys.exit(1)

print("kb_drift_scan C8: terminal (SHIPPED/VERIFIED/DONE) + post-cutoff + absent/literal-null/off-enum evidence key fires (5 shapes, per-key detail); pre-cutoff / non-terminal / both-valid / created-absent / created-malformed clean; auto_safe:false")
PYEOF
}

# Behavioral: GOLDEN backlog-archiver (spec 2026-06-04-backlog-curator §6). Copies
# the committed pre-cleanup golden BACKLOG (frozen ONCE as a static fixture from
# the real pre-deep-clean backlog — NO vault reach in the test, cwd-independent) into a
# temp project, then reproduces the 2026-06-04 human deep-clean and ID-anchors the
# result under the STRUCK-ONLY done-detection contract (spec §3.2 rule 1):
# `--dry-run` CANDIDATE set is EXACTLY {37,42,45,46,52,55,75} (with #55/#75 hinted
# likely-collision); the FLAGGED section lists the NON-struck `✅` rows #76 and #77;
# `--apply --archive-candidates 37,42,45,46,52` archives the non-struck approved set
# {#37,#42,#45,#46,#52} + ALL struck `### ~~`/`| ~~` items + the #76 own-status
# block, while {#40,#50,#55,#75} stay OPEN AND the non-struck `✅` rows #76/#77 stay
# in BACKLOG (flagged, never archived); the regenerated index has exactly ONE line
# each for #37/#45/#46/#52, FOUR lines for #42/#42a/#42b/#42c, ONE #76 line (the
# block only — the flagged #76 ROW produces no index line), and the #37 line sources
# `PR #57` from the matched row; a second identical `--apply` is a byte-identical
# no-op. Layered with the archiver's own `--selftest` and an end-to-end --apply
# guard that pins the column-parse data-loss class (X1/X4/X6) CLOSED BY CONSTRUCTION:
# every OPEN row carrying a `✅` in a non-Status cell + a misparse vector (escaped
# `\|` / double-escaped `\\|` / inline-code-span pipe / 6-col ragged / 5-col-under-
# 4-col-header) MUST stay OPEN; only a STRUCK row archives. Plus the file-level
# symlink write-target guard (X5 — symlinked month file / BACKLOG.md refused exit-2).
# Mutation-protected: any regression in classification (candidate set / flag set),
# coalescing (index line counts), date-bucketing, merge idempotency, a regression of
# done-detection to a column parse, or the symlink guard drives an assertion RED.
check_backlog_archiver_behavioral() {
  local archiver="$PLUGIN_ROOT/tests/backlog_archive.py"
  local golden="$PLUGIN_ROOT/tests/fixtures/backlog-curator/golden-input-backlog.md"
  [ -f "$archiver" ] || { echo "$archiver missing"; return 1; }
  [ -f "$golden" ] || { echo "$golden fixture missing"; return 1; }
  # Layer 0: the archiver's embedded selftest (per-table Status-col detection +
  # storage-identity merge keying — X1/X2/X3). Goes RED if that core regresses.
  if ! python3 "$archiver" --selftest >/dev/null 2>&1; then
    echo "backlog_archive.py --selftest failed"
    return 1
  fi
  python3 - "$archiver" "$golden" <<'PYEOF'
import hashlib, re, shutil, subprocess, sys, tempfile
from pathlib import Path

archiver, golden = sys.argv[1], sys.argv[2]


def run(root, *extra):
    return subprocess.run(
        [sys.executable, archiver, str(root), "--project", "ai-dev-team", *extra],
        capture_output=True,
        text=True,
    )


with tempfile.TemporaryDirectory() as td:
    proj = Path(td) / "repos" / "ai-dev-team"
    proj.mkdir(parents=True)
    shutil.copy(golden, proj / "BACKLOG.md")

    # (1) --dry-run CANDIDATE set is EXACTLY {37,42,45,46,52,55,75}; #55/#75 are
    # hinted likely-collision. A classification regression (number-match gate,
    # struck/own-status discrimination) shifts this set.
    dry = run(td, "--dry-run")
    cand_sec = dry.stdout.split("CANDIDATES", 1)[1] if "CANDIDATES" in dry.stdout else ""
    cand_ids = {int(x) for x in re.findall(r"#(\d+)", cand_sec)}
    if cand_ids != {37, 42, 45, 46, 52, 55, 75}:
        print(f"(1) candidate set must be {{37,42,45,46,52,55,75}}, got {sorted(cand_ids)}\n{cand_sec[:800]}")
        sys.exit(1)
    cand_lines = {}
    for ln in cand_sec.splitlines():
        m = re.search(r"#(\d+)\b", ln)
        if m:
            cand_lines[int(m.group(1))] = ln
    for n in (55, 75):
        if "likely-collision" not in cand_lines.get(n, ""):
            print(f"(1) #{n} must be hinted likely-collision, got {cand_lines.get(n)!r}")
            sys.exit(1)

    # (2) Reproduce the human's 2026-06-04 approval: --apply the AUTO set + the
    # five approved non-struck candidates {37,42,45,46,52}.
    ap = run(td, "--apply", "--archive-candidates", "37,42,45,46,52")
    if ap.returncode != 1:
        print(f"(2) --apply with changes must exit 1, got {ap.returncode}; stderr={ap.stderr[:400]}")
        sys.exit(1)
    arch = sorted((proj / "archive").glob("backlog-done-*.md"))
    archtxt = "\n".join(a.read_text() for a in arch)
    bl = (proj / "BACKLOG.md").read_text()
    openpart = bl.split("## Completed")[0]

    # ID-anchored archived set: the five approved non-struck blocks are archived
    # AND removed from the open part (move, not copy).
    for n in (37, 42, 45, 46, 52):
        if not re.search(rf"^### (~~)?{n}\.", archtxt, re.M):
            print(f"(2) approved #{n} block must be archived, missing from archive")
            sys.exit(1)
        if re.search(rf"^### (~~)?{n}\.", openpart, re.M):
            print(f"(2) approved #{n} block must be removed from open BACKLOG (move not copy)")
            sys.exit(1)

    # ALL struck items archived: none left in the open part.
    if "### ~~" in openpart or re.search(r"^\s*\| ~~", openpart, re.M):
        print("(2) all struck `### ~~`/`| ~~` items must be archived (none left in open part)")
        sys.exit(1)

    # The #76 own-status block ("Smoke-pin placement …") is archived even though
    # it was never struck (mid-line `**Status: ✅` own-status discriminator).
    if not re.search(r"^### 76\. Smoke-pin placement", archtxt, re.M):
        print("(2) #76 own-status block must be archived")
        sys.exit(1)

    # STRUCK-ONLY contract (spec §3.2 rule 1): the NON-struck #76 librarian-cluster
    # ROW and the NON-struck #77 row carry a `✅` but are NOT struck → they are
    # FLAGGED, never archived. They MUST stay in the open BACKLOG and MUST NOT
    # appear in any archive file. (RED if done-detection regresses to a column
    # parse that re-reads a non-Status `✅` cell and archives the OPEN row.)
    for n in (76, 77):
        if not re.search(rf"^\s*\| \*\*{n}\*\*", openpart, re.M):
            print(f"(2) non-struck ✅ row #{n} must STAY in the open BACKLOG (flagged, not archived)")
            sys.exit(1)
        if re.search(rf"^\s*\| \*\*{n}\*\*", archtxt, re.M):
            print(f"(2) non-struck ✅ row #{n} must NEVER be archived (struck-only done-detection)")
            sys.exit(1)
    # The FLAGGED dry-run section advertises the #76/#77 rows so the human can
    # strike them.
    flag_sec = dry.stdout.split("FLAGGED", 1)[1].split("CANDIDATES", 1)[0] if "FLAGGED" in dry.stdout else ""
    flag_ids = {int(x) for x in re.findall(r"#(\d+)", flag_sec)}
    if not {76, 77} <= flag_ids:
        print(f"(2) FLAGGED section must list the non-struck ✅ rows #76 and #77, got {sorted(flag_ids)}\n{flag_sec[:600]}")
        sys.exit(1)

    # Must-stay-OPEN set: #40/#50 (X12 FP-guards) + the un-approved collision
    # candidates #55/#75 keep their OPEN headers in the trimmed BACKLOG.
    for n in (40, 50, 55, 75):
        if not re.search(rf"^### (~~)?{n}\.", openpart, re.M):
            print(f"(2) #{n} must stay OPEN in the trimmed BACKLOG")
            sys.exit(1)

    # (3) Regenerated index: ONE line per logical item for the approved candidates
    # (block+row coalesce) — #37/#45/#46/#52; FOUR distinct #42/#42a/#42b/#42c
    # lines (block matched only to suffixed rows → no coalesce); exactly ONE #76
    # line — the AUTO-DONE block only (the non-struck #76 ROW is FLAGGED, never
    # archived, so it produces NO index line). The #37 line carries the row's
    # `PR #57` (coalesced PR sourced from the matched row).
    idx = (
        bl.split("### Done backlog items — index")[1].split("### Completed specs")[0]
        if "Done backlog items — index" in bl
        else ""
    )
    for lbl, want in (("#37", 1), ("#45", 1), ("#46", 1), ("#52", 1),
                      ("#42", 1), ("#42a", 1), ("#42b", 1), ("#42c", 1), ("#76", 1)):
        got = idx.count(f"**{lbl}**")
        if got != want:
            print(f"(3) index line count for {lbl}: want {want}, got {got}\n{idx[:1200]}")
            sys.exit(1)
    line37 = [ln for ln in idx.splitlines() if "**#37**" in ln]
    if not line37 or "PR #57" not in line37[0]:
        print(f"(3) #37 index line must carry `PR #57` from the matched row, got {line37}")
        sys.exit(1)

    # (4) Idempotency: a second identical --apply is a byte-identical no-op (exit 0,
    # archives + BACKLOG unchanged).
    snap = {f.name: hashlib.md5(f.read_bytes()).hexdigest() for f in [proj / "BACKLOG.md", *arch]}
    ap2 = run(td, "--apply", "--archive-candidates", "37,42,45,46,52")
    if ap2.returncode != 0:
        print(f"(4) second identical --apply must be a no-op (exit 0), got {ap2.returncode}")
        sys.exit(1)
    arch2 = sorted((proj / "archive").glob("backlog-done-*.md"))
    snap2 = {f.name: hashlib.md5(f.read_bytes()).hexdigest() for f in [proj / "BACKLOG.md", *arch2]}
    if snap != snap2:
        print(f"(4) second --apply must be byte-identical no-op; snapshots differ:\n  {snap}\n  {snap2}")
        sys.exit(1)

    # (5+6) STRUCK-ONLY done-detection closes the column-parse data-loss class
    # (X1 all-cell-scan / X4 escaped `\|` / X6 double-escaped `\\|`) BY
    # CONSTRUCTION — these REPLACE the prior column-parse vector pins. Every row
    # below carries a `✅` in a NON-Status cell PLUS a misparse vector (escaped
    # `\|`, double-escaped `\\|`, inline-code-span pipe, 6-col ragged, 5-col-under-
    # 4-col-header). Pre-fix, a column parse inflated the apparent arity and
    # re-keyed a non-Status `✅` cell as the Status cell → the OPEN row was
    # archived + trimmed = DATA LOSS. Asserted END-TO-END via --apply: NONE may be
    # archived (done-detection reads NO cell). The lone done signal is STRUCK, so a
    # struck control row still archives. These pins go RED if done-detection ever
    # regresses to a column parse.
    #   SOESCMARK   (escaped `\|` + leading-✅ Reason)              → MUST stay OPEN
    #   SODBLESC    (double-escaped `\\|` + leading-✅ Reason)      → MUST stay OPEN
    #   SOCODEMARK  (inline-code-span pipe + leading-✅ Reason)     → MUST stay OPEN
    #   SORAGMARK   (6-col ragged, ✅ in a non-Status cell)         → MUST stay OPEN
    #   SOALLCELL   (5-col-under-4-col-header, ✅ non-struck cell)  → MUST stay OPEN
    #   SOSTRUCK    (struck row)                                    → MUST archive
    synth = "\n".join([
        "# BACKLOG",
        "",
        "## Active priorities",
        "",
        "| # | Item | Status | Reason |",
        "|---|------|--------|--------|",
        r"| **101** | SOESCMARK escaped-pipe open | P2 queued | "
        r"✅ RESOLVED 2026-05-31 \| extra note |",
        r"| **102** | SODBLESC double-escaped open | P2 queued | "
        r"✅ RESOLVED 2026-05-31 \\| extra note |",
        "| **103** | SOCODEMARK code-span open | P2 queued | "
        "✅ see `a | b` pipe |",
        "| **104** | SOALLCELL five-col ✅-in-cell open | ax | P2 queued | "
        "✅ RESOLVED 2026-04-30 discussion only |",
        "| ~~**105**~~ | SOSTRUCK struck done | **✅ DONE 2026-04-15** | r |",
        "",
        "| # | Item | Status | Reason | Extra | More |",
        "|---|------|--------|--------|-------|------|",
        "| **106** | SORAGMARK six-col ✅-non-status open | ✅ leads here | "
        "P2 queued | x | y |",
        "",
    ])
    with tempfile.TemporaryDirectory() as td5:
        proj5 = Path(td5) / "repos" / "ai-dev-team"
        proj5.mkdir(parents=True)
        (proj5 / "BACKLOG.md").write_text(synth, encoding="utf-8")
        run(td5, "--apply")
        bl5 = (proj5 / "BACKLOG.md").read_text()
        open5 = bl5.split("## Completed")[0]
        arch5 = "\n".join(a.read_text() for a in (proj5 / "archive").glob("backlog-done-*.md"))
        for marker, why in (
            ("SOESCMARK", "escaped `\\|` + leading-✅ in a non-Status cell"),
            ("SODBLESC", "double-escaped `\\\\|` + leading-✅ in a non-Status cell"),
            ("SOCODEMARK", "inline-code-span pipe + leading-✅ in a non-Status cell"),
            ("SOALLCELL", "5-col-under-4-col-header, ✅ in a non-struck cell"),
            ("SORAGMARK", "6-col ragged row with ✅ in a non-Status cell"),
        ):
            if marker not in open5:
                print(f"(5+6) column-parse regression: OPEN row [{why}] was LOST from open BACKLOG (data loss)")
                sys.exit(1)
            if marker in arch5:
                print(f"(5+6) column-parse regression: OPEN row [{why}] was wrongly ARCHIVED — struck-only done-detection broke (data loss)")
                sys.exit(1)
        # The lone STRUCK row still archives — the done signal stays narrow.
        if "SOSTRUCK" not in arch5 or "SOSTRUCK" in open5:
            print("(5+6) struck control row MUST still archive (struck-only done signal)")
            sys.exit(1)

    # (7) AUDIT X5 (MEDIUM) — file-level symlink guard: a pre-planted symlink AT a
    # write target (the month file OR BACKLOG.md) is refused (exit 2, nothing
    # written through it), even when the `archive/` dir itself is a REAL dir that
    # passes the X3 dir-level guard.
    import os as _os
    seed7 = ("# BACKLOG\n\n## P1: section\n\n"
             "### ~~5. struck done~~ ✅ DONE (2026-04-10)\n\nBODY_5 content.\n")
    with tempfile.TemporaryDirectory() as td7:
        proj7 = Path(td7) / "repos" / "ai-dev-team"
        proj7.mkdir(parents=True)
        (proj7 / "BACKLOG.md").write_text(seed7, encoding="utf-8")
        (proj7 / "archive").mkdir()  # REAL dir → passes the X3 dir-level guard
        outside7 = Path(td7) / "OUTSIDE"
        outside7.mkdir()
        victim7 = outside7 / "victim.md"
        victim7.write_text("ORIGINAL VICTIM\n", encoding="utf-8")
        _os.symlink(str(victim7), str(proj7 / "archive" / "backlog-done-2026-04.md"))
        ap7 = run(td7, "--apply")
        if ap7.returncode != 2:
            print(f"(7) X5: symlinked month-file write target must be refused (exit 2), got {ap7.returncode}")
            sys.exit(1)
        if victim7.read_text() != "ORIGINAL VICTIM\n":
            print("(7) X5: outside victim file was written THROUGH the month-file symlink (escape)")
            sys.exit(1)
    with tempfile.TemporaryDirectory() as td7b:
        proj7b = Path(td7b) / "repos" / "ai-dev-team"
        proj7b.mkdir(parents=True)
        outside7b = Path(td7b) / "OUTSIDE"
        outside7b.mkdir()
        realbl7 = outside7b / "real-backlog.md"
        realbl7.write_text(seed7, encoding="utf-8")
        _os.symlink(str(realbl7), str(proj7b / "BACKLOG.md"))
        (proj7b / "archive").mkdir()
        ap7b = run(td7b, "--apply")
        if ap7b.returncode != 2:
            print(f"(7) X5: symlinked BACKLOG.md write target must be refused (exit 2), got {ap7b.returncode}")
            sys.exit(1)
        if "BODY_5" not in realbl7.read_text():
            print("(7) X5: outside real-backlog was trimmed THROUGH the BACKLOG.md symlink (escape)")
            sys.exit(1)

print("backlog_archive GOLDEN: dry-run candidates exactly {37,42,45,46,52,55,75} (#55/#75 likely-collision), FLAGGED lists non-struck ✅ rows #76/#77; --apply 37,42,45,46,52 archives approved+struck+#76-block (move not copy), {#40,#50,#55,#75} stay OPEN, non-struck ✅ rows #76/#77 stay in BACKLOG (flagged, never archived); index one line each #37/#45/#46/#52, four #42/#42a/#42b/#42c, ONE #76 (block only); #37 line sources PR #57; 2nd --apply byte-identical no-op; STRUCK-ONLY done-detection closes the column-parse data-loss class by construction (escaped-`\\|`/double-escaped-`\\\\|`/code-span/ragged/5-col-under-4-col OPEN rows with ✅ in a non-Status cell stay OPEN; only struck rows archive) (X1/X4/X6); file-level symlink write targets refused exit-2 (X5); selftest + AUDIT-X3/X5 green")
PYEOF
}

# Behavioral: the no-project scan covers the WHOLE vault (root files + non-repos
# top-level dirs + repos/*, each once), excludes the templates/images + dot-dir
# build content from the SCANNED set (case-insensitive plain names AND the
# Obsidian numbered-prefix form `90_Templates/`, whole-component anchored — never
# substring), and keeps the wikilink resolution index (all_md) unfiltered so a
# link INTO an excluded dir still resolves. Scans the committed vault-scope/
# fixture (which HAS a repos/ dir, so the no-project broadening from repos/*
# subdirs to [kb_root] is observable) and asserts BY FIXTURE FILE: the root
# vault-index.md C6-bloat row flags, the non-repos cross-cutting/foo.md C1 flags,
# the repos/projx/y.md C1 flags EXACTLY ONCE (no double-count from the scan-root
# switch), the numbered-prefix 90_Templates/x.md appears in NO finding (M-C
# numbered-prefix exclusion), the content dir templates-analysis/y.md flags
# EXACTLY 1 C1 (M-C anti-over-exclusion — fullmatch did not over-exclude), the
# link-into-templates.md flags EXACTLY 1 C6 (M-B positive: the linker IS in the
# scan set) AND 0 C1 (resolution-index invariant — `[[bar]]` into the excluded
# templates/ note resolves clean), the excluded templates/bar.md + .obsidian/baz.md
# appear in NO finding (build-dir exclusion), and — under a tmp ancestor dir
# literally named templates/ — all in-scope findings still fire (M-A relative-
# guard: _is_excluded compares kb_root-RELATIVE parts, NOT absolute). Catches a
# regression where the no-project scan reverts to repos/* only (root + non-repos-
# dir files silently skipped), the exclusion leaks into the resolution index
# (spurious C1 on a link into templates/), the numbered-prefix form is missed
# (90_Templates/ wrongly scanned) or over-matched (templates-analysis/ wrongly
# excluded), the case-insensitive plain-name match degrades to exact-case
# (capitalized Templates/ wrongly scanned — casefold dropped), the linker is
# silently dropped from the scan set (M-B positive C6 vanishes), the absolute-vs-
# relative comparison regresses to path.parts (a templates/ ancestor nukes the
# scan), or the scan-root switch double-counts repos files.
check_kb_drift_whole_vault_scope() {
  local scanner="$PLUGIN_ROOT/tests/kb_drift_scan.py"
  local vs="$PLUGIN_ROOT/tests/fixtures/kb-drift/vault-scope"
  [ -f "$scanner" ] || { echo "$scanner missing"; return 1; }
  [ -d "$vs" ] || { echo "$vs fixture dir missing"; return 1; }
  python3 - "$scanner" "$vs" <<'PYEOF'
import json, subprocess, sys
scanner, vs = sys.argv[1], sys.argv[2]

# vault-scope/ HAS a repos/ dir, so a no-project scan that walked repos/* only
# would skip the root + non-repos-dir files. exit 1 == findings present.
r = subprocess.run([sys.executable, scanner, vs], capture_output=True, text=True)
if r.returncode != 1:
    print(f"vault-scope: expected exit 1 (whole-vault findings), got {r.returncode}; stdout={r.stdout!r} stderr={r.stderr!r}")
    sys.exit(1)
F = json.loads(r.stdout)["findings"]
files = [f["file"] for f in F]

# (1) Root file scanned: the no-frontmatter vault-index.md C6-bloat row flags via
# the basename clause — proves a root-level file (skipped by the old repos/*
# scope) is now scanned. Exactly 1 C6 on it.
root_c6 = [f for f in F if f["file"] == "vault-index.md" and f["class"] == "C6_index_row_bloat"]
if len(root_c6) != 1:
    print(f"(1) root vault-index.md must flag exactly 1 C6 (root file now scanned), got {root_c6}")
    sys.exit(1)

# (2) Non-repos top-level dir scanned: cross-cutting/foo.md (a dir that is NEITHER
# repos/ NOR root) flags exactly 1 C1 — proves a non-repos content dir is now
# covered.
xc_c1 = [f for f in F if f["file"] == "cross-cutting/foo.md" and f["class"] == "C1_broken_wikilink"]
if len(xc_c1) != 1:
    print(f"(2) non-repos cross-cutting/foo.md must flag exactly 1 C1 (non-repos dir now scanned), got {xc_c1}")
    sys.exit(1)

# (3) Single-count: repos/projx/y.md flags exactly 1 C1. Switching the no-project
# scan root from repos/* subdirs to a single kb_root rglob must visit each repos
# file ONCE — a >1 count would witness a double-count regression.
repos_c1 = [f for f in F if f["file"] == "repos/projx/y.md" and f["class"] == "C1_broken_wikilink"]
if len(repos_c1) != 1:
    print(f"(3) repos/projx/y.md must flag EXACTLY 1 C1 (no double-count from the scan-root switch), got {len(repos_c1)}: {repos_c1}")
    sys.exit(1)

# (4) Build-dir exclusion: the templates/bar.md (broken link + C6-bloat row) and
# the .obsidian/baz.md (broken link) appear in NO finding's file — excluded from
# the SCAN set via SCAN_EXCLUDE_DIRNAMES + the dot-dir startswith('.') rule.
if any("templates/" in x for x in files):
    print(f"(4) templates/ files must be EXCLUDED from the scan set, got scanned: {[x for x in files if 'templates/' in x]}")
    sys.exit(1)
if any(x.startswith(".obsidian") or "/.obsidian" in x for x in files):
    print(f"(4) .obsidian/ dot-dir files must be EXCLUDED from the scan set, got scanned: {[x for x in files if '.obsidian' in x]}")
    sys.exit(1)

# (5) Resolution-index invariant: link-into-templates.md links `[[bar]]` to the
# EXCLUDED templates/bar.md note. The exclusion applies to the SCAN set ONLY;
# all_md stays whole-vault, so the link resolves and raises NO C1. A spurious C1
# here would witness the exclusion leaking into the resolution index.
if any(f["class"] == "C1_broken_wikilink" and f["file"] == "link-into-templates.md" for f in F):
    print(f"(5) [[bar]] into the excluded templates/ note must RESOLVE (all_md unfiltered) — no C1 on link-into-templates.md, got {[f for f in F if f['file']=='link-into-templates.md']}")
    sys.exit(1)

# (6) M-C numbered-prefix exclusion: 90_Templates/x.md (Obsidian numbered-prefix
# build dir) carries a C6-bloat row AND a broken wikilink that WOULD flag if
# scanned (it is C6-eligible via `type: index`), but SCAN_EXCLUDE_RE.fullmatch
# excludes it. It must appear in NO finding's file. A regression that reverts the
# match to exact-lowercase equality (90_Templates != templates) wrongly scans it.
if any(x.startswith("90_Templates") or "/90_Templates/" in x for x in files):
    print(f"(6) 90_Templates/x.md (numbered-prefix build dir) must be EXCLUDED from the scan set, got scanned: {[x for x in files if '90_Templates' in x]}")
    sys.exit(1)

# (7) M-C anti-over-exclusion: templates-analysis/y.md is a CONTENT dir embedding
# the `templates` token but is NOT the build dir — whole-component fullmatch
# rejects it (no leading digits + trailing `-analysis`). It MUST be scanned and
# flag EXACTLY 1 C1. A regression that swaps fullmatch for a substring `in` test
# wrongly excludes it (0 C1 here).
ta_c1 = [f for f in F if f["file"] == "templates-analysis/y.md" and f["class"] == "C1_broken_wikilink"]
if len(ta_c1) != 1:
    print(f"(7) templates-analysis/y.md must flag EXACTLY 1 C1 (content dir, NOT over-excluded), got {ta_c1}")
    sys.exit(1)

# (8) M-B positive: link-into-templates.md (now `type: index`) raises EXACTLY 1
# C6_index_row_bloat — POSITIVE proof the linker IS in the scan set (assertion
# (5) above is negative-only; it passes even if the file were silently dropped).
linker_c6 = [f for f in F if f["file"] == "link-into-templates.md" and f["class"] == "C6_index_row_bloat"]
if len(linker_c6) != 1:
    print(f"(8) link-into-templates.md must flag EXACTLY 1 C6 (linker IS in the scan set), got {linker_c6}")
    sys.exit(1)

# (10)+(11) Exclusion-match contract — UNIT assertions on _is_excluded directly.
# Two contract boundaries (X1 case-insensitivity, X2 ASCII-digit) cannot be pinned
# by a filesystem fixture: this repo's worktree may sit on a case-insensitive FS
# (macOS APFS default), where a capitalized `Templates/` dir collapses into the
# existing lowercase `templates/` — the distinct-case dir is unrepresentable on
# disk. So load the module and exercise `_is_excluded(path, kb_root)` with synthetic
# kb_root-relative components (portable, locale-independent — Unicode lookalikes
# built via chr() so this assertion's source stays ASCII):
#   (10) X1 case-insensitive plain name: a CAPITALIZED `Templates` / uppercase
#        `IMAGES` component must be EXCLUDED via the casefold clause
#        (`comp.casefold() in {"templates","images"}`). A regression dropping
#        `casefold()` (exact-case `comp in {...}`) wrongly SCANS `Templates`
#        (capitalized != exact-lowercase `templates`; no leading digit so the
#        regex does not catch it either).
#   (11) X2 ASCII-digit boundary: SCAN_EXCLUDE_RE must use `[0-9]` (ASCII), NOT
#        `\d` (Unicode-aware). The numbered-prefix forms `90_Templates`/`01-images`
#        are excluded; the Unicode-digit lookalikes (Arabic-Indic U+0669, fullwidth
#        U+FF11/U+FF12 + `_templates`/`_images`) must be SCANNED (a `[0-9]`->`\d`
#        revert over-excludes them — a false-negative dropping real content).
#   plus anti-over-exclusion at the unit level (`templates-analysis` scanned).
import importlib.util as _u
from pathlib import Path as _P
_spec = _u.spec_from_file_location("kb_drift_scan", scanner)
_m = _u.module_from_spec(_spec); _spec.loader.exec_module(_m)
_kr = _P("/v")
def _excl(comp):  # _is_excluded for a single kb_root-relative dir component
    return _m._is_excluded(_kr / comp / "a.md", _kr)
# NB: the plain-name set is PLURAL-only ({"templates","images"}); a bare singular
# `template`/`image` (no digit prefix) is intentionally SCANNED — only the regex's
# `templates?`/`images?` admits singular, and only WITH a leading digit.
_excluded_expected = ["Templates", "IMAGES", "90_Templates", "01-images", "2 Template"]
_scanned_expected = ["templates-analysis", "image-pipeline", "my-templates", "template", "image",
                     chr(0x669) + "_templates", chr(0xff11) + chr(0xff12) + "_images"]
_bad_excl = [c for c in _excluded_expected if not _excl(c)]
_bad_scan = [c for c in _scanned_expected if _excl(c)]
if _bad_excl:
    print(f"(10/11) _is_excluded must EXCLUDE {_bad_excl} (X1 casefold + numbered-prefix); they were SCANNED — casefold dropped or regex broken")
    sys.exit(1)
if _bad_scan:
    print(f"(10/11) _is_excluded must SCAN {_bad_scan} (anti-over-exclusion + X2 ASCII boundary); they were EXCLUDED — substring over-match or \\d Unicode over-match")
    sys.exit(1)

# Total: exactly the 5 intended findings (root C6 + cross-cutting C1 + repos C1 +
# templates-analysis C1 + linker C6), and nothing else — 90_Templates/x.md,
# templates/bar.md, .obsidian/baz.md contribute 0 (excluded).
if len(F) != 5:
    print(f"vault-scope: expected exactly 5 findings (root C6 + cross-cutting C1 + repos C1 + templates-analysis C1 + linker C6), got {len(F)}: {F}")
    sys.exit(1)

# (9) M-A relative-guard: copy the fixture into a tmp ancestor dir literally named
# templates/ (scan <tmp>/templates/vault-scope). _is_excluded compares kb_root-
# RELATIVE components, so the templates/ ANCESTOR does not nuke the scan — the 3
# baseline in-scope findings (root C6 + cross-cutting C1 + repos C1) still fire.
# A path.parts mutant (absolute, not relative) would see `templates` in every
# path component and exclude EVERYTHING → 0 findings here.
import os, shutil, tempfile
tmp = tempfile.mkdtemp()
try:
    nested = os.path.join(tmp, "templates", "vault-scope")
    shutil.copytree(vs, nested)
    rn = subprocess.run([sys.executable, scanner, nested], capture_output=True, text=True)
    if rn.returncode != 1:
        print(f"(9) M-A relative-guard: expected exit 1 (findings still fire under templates/ ancestor), got {rn.returncode}; stderr={rn.stderr!r}")
        sys.exit(1)
    Fn = json.loads(rn.stdout)["findings"]
    base = {
        ("vault-index.md", "C6_index_row_bloat"),
        ("cross-cutting/foo.md", "C1_broken_wikilink"),
        ("repos/projx/y.md", "C1_broken_wikilink"),
    }
    got = {(f["file"], f["class"]) for f in Fn}
    if not base.issubset(got):
        print(f"(9) M-A relative-guard: under a templates/ ANCESTOR the in-scope baseline findings must still fire (kb_root-RELATIVE, not path.parts) — missing {base - got}; got {sorted(got)}")
        sys.exit(1)
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print("kb_drift_scan whole-vault scope: root vault-index.md C6 + non-repos cross-cutting/foo.md C1 + repos/projx/y.md C1 (exactly once) scanned; 90_Templates/x.md (numbered-prefix) + templates/bar.md + .obsidian/baz.md EXCLUDED from the scan set; templates-analysis/y.md flags 1 C1 (anti-over-exclusion, not over-excluded); link-into-templates.md flags 1 C6 (linker IS in the scan set, M-B positive) + 0 C1 ([[bar]] into excluded templates/ resolves clean, all_md unfiltered); exactly 5 findings total; _is_excluded unit checks: casefold excludes capitalized Templates/IMAGES (X1), ASCII [0-9] excludes 90_Templates but SCANS Unicode-digit lookalikes (X2), content dirs templates-analysis/image-pipeline scanned (anti-over-exclusion); under a templates/ ANCESTOR the 3 baseline in-scope findings still fire (M-A kb_root-RELATIVE guard)")
PYEOF
}

# Behavioral: bare_target normalizes the escaped table-cell alias separator `\|`
# to a plain `|` BEFORE the target split, so an Obsidian table-cell wikilink
# `[[Real Note\|alias]]` resolves to the existing note instead of false-flagging
# C1 on a trailing-backslash target (`Real Note\`). Scans the committed
# c1-escaped-pipe/ fixture and asserts BY FIXTURE FILE: the escaped-pipe link AND
# the plain-alias link to the existing Real Note both resolve clean (no C1),
# while the genuinely-broken `[[No Such Note\|x]]` still flags EXACTLY 1 C1 whose
# detail names the CLEANED target `[[No Such Note]]` (NOT `[[No Such Note\]]`).
# Catches a regression where the `\|` normalization is dropped (escaped-pipe
# links false-flag C1 again), where the normalization over-reaches and breaks the
# genuine still-broken case, or where the trailing backslash leaks back into the
# finding detail / fuzzy-candidate key.
check_kb_drift_c1_escaped_pipe_alias() {
  local scanner="$PLUGIN_ROOT/tests/kb_drift_scan.py"
  local fx="$PLUGIN_ROOT/tests/fixtures/kb-drift/c1-escaped-pipe"
  [ -f "$scanner" ] || { echo "$scanner missing"; return 1; }
  [ -d "$fx" ] || { echo "$fx fixture dir missing"; return 1; }
  python3 - "$scanner" "$fx" <<'PYEOF'
import json, subprocess, sys
scanner, fx = sys.argv[1], sys.argv[2]

r = subprocess.run([sys.executable, scanner, fx], capture_output=True, text=True)
F = json.loads(r.stdout)["findings"]
c1 = [f for f in F if f["class"] == "C1_broken_wikilink"]

# (1) Exactly one C1: the two Real Note links (escaped `\|` + plain `|`) resolve
# clean; only the genuinely-broken [[No Such Note\|x]] flags.
if len(c1) != 1:
    print(f"(1) expected exactly 1 C1 (only the broken No Such Note link), got {len(c1)}: {c1}")
    sys.exit(1)

# (2) The detail names the CLEANED target [[No Such Note]] — bare_target
# truncates at the first alias pipe of ANY parity (the escaped `\|` is a single
# `\`, odd, so its `\` is the pipe's escape and is dropped), so the alias is
# dropped and NO trailing backslash leaks. A regression to the old buggy split
# would emit [[No Such Note\]] here.
detail = c1[0]["detail"]
if "[[No Such Note]]" not in detail:
    print(f"(2) C1 detail must name the cleaned target [[No Such Note]] (no trailing backslash), got {detail!r}")
    sys.exit(1)
if "[[No Such Note\\]]" in detail:
    print(f"(2) C1 detail must NOT carry the trailing-backslash target [[No Such Note\\]], got {detail!r}")
    sys.exit(1)

# (3) Neither Real Note link produces a C1 (both the escaped-pipe and the
# plain-alias forms resolve to the committed Real Note.md).
real = [f for f in c1 if "Real Note" in f["detail"]]
if real:
    print(f"(3) escaped + plain alias to the existing Real Note must resolve clean (no C1), got {real}")
    sys.exit(1)

# (4) bare_target backslash-parity unit matrix: EVERY pipe ends the target (both
# `|` and `\|` are alias separators) and the surviving literal backslashes are
# floor(bs/2) of the run before that pipe. The 1/2-bs rows pin the existing
# behavior; the 3/4-bs rows kill the global `replace("\\|","|")` mutant (which
# would keep bs-1 literal backslashes: 2 and 3, not 1 and 2).
import importlib.util as _u
_s = _u.spec_from_file_location("kb_drift_scan", scanner)
_m = _u.module_from_spec(_s)
_s.loader.exec_module(_m)
BS = chr(92)
matrix = [
    ("foo" + BS + "|bar", "foo"),            # 1 bs — odd, pipe escaped, dropped
    ("foo" + BS * 2 + "|bar", "foo" + BS),   # 2 bs — one literal `\` survives
    ("foo" + BS * 3 + "|bar", "foo" + BS),   # 3 bs — CHANGED (was foo\\)
    ("foo" + BS * 4 + "|bar", "foo" + BS * 2),  # 4 bs — kills global-replace mutant
]
for raw, want in matrix:
    got = _m.bare_target(raw)
    if got != want:
        print(f"(4) bare_target({raw!r}) must be {want!r}, got {got!r}")
        sys.exit(1)

print("kb_drift_scan C1 escaped-pipe alias: [[Real Note\\|alias]] (escaped) + [[Real Note|other]] (plain) resolve clean; [[No Such Note\\|x]] flags EXACTLY 1 C1 on the cleaned target [[No Such Note]] (no trailing backslash leak); bare_target parity matrix — floor(bs/2) literal backslashes (1bs->foo, 2bs->foo\\, 3bs->foo\\, 4bs->foo\\\\)")
PYEOF
}

# Prompt-text: the /kb-audit skill (skills/kb-audit/SKILL.md) carries the
# load-bearing prose contracts (X4 — not just file existence): name=kb-audit
# frontmatter; Phase-0 discovery; the scanner invocation at
# ${CLAUDE_PLUGIN_ROOT}/tests/kb_drift_scan.py with --project + --summary; the
# REPORT-only autonomy boundary (auto_safe:false = human decision, never
# auto-edit); the exit-code branch table with exit 1 = findings = SUCCESS (NOT
# an error); and silent-degrade limited to exit 2 / unavailable. Catches a
# regression where the skill drops the exit-1-is-success contract (and starts
# treating findings as a failure) or loses the REPORT-only autonomy boundary.
check_kb_audit_skill_contract() {
  local skill="$PLUGIN_ROOT/skills/kb-audit/SKILL.md"
  [ -f "$skill" ] || { echo "$skill missing"; return 1; }
  grep -q '^name: kb-audit$' "$skill" \
    || { echo "$skill missing 'name: kb-audit' frontmatter"; return 1; }
  grep -qi 'discovery' "$skill" \
    || { echo "$skill missing Phase-0 KB-discovery reference"; return 1; }
  grep -qF 'docs/kb-discovery.md' "$skill" \
    || { echo "$skill missing the docs/kb-discovery.md pointer"; return 1; }
  grep -qF '${CLAUDE_PLUGIN_ROOT}/tests/kb_drift_scan.py' "$skill" \
    || { echo "$skill missing the \${CLAUDE_PLUGIN_ROOT}/tests/kb_drift_scan.py invocation"; return 1; }
  grep -qF -- '--summary' "$skill" \
    || { echo "$skill missing the --summary flag on the scanner invocation"; return 1; }
  grep -qF -- '--project' "$skill" \
    || { echo "$skill missing the --project flag"; return 1; }
  # REPORT-only autonomy boundary: auto_safe + a never-edit assertion.
  grep -qF 'auto_safe' "$skill" \
    || { echo "$skill missing the auto_safe autonomy-boundary reference"; return 1; }
  grep -qiE 'never.*(auto-?edit|edit)|report.*only|reports only' "$skill" \
    || { echo "$skill missing the REPORT-only / never-auto-edit autonomy boundary"; return 1; }
  # X1: exit 1 = findings = SUCCESS, never a failure.
  grep -qiE 'exit .?1.?.*(success|findings)|findings.*success|never treat exit 1 as a failure' "$skill" \
    || { echo "$skill missing the exit-1-is-success (X1) contract"; return 1; }
  # Silent-degrade limited to exit 2 / unavailable (never crash / fabricate).
  grep -qiE 'degrade|unavailable' "$skill" \
    || { echo "$skill missing the silent-degrade-on-exit-2/unavailable contract"; return 1; }
  echo "$skill: name=kb-audit; Phase-0 discovery (docs/kb-discovery.md); \${CLAUDE_PLUGIN_ROOT}/tests/kb_drift_scan.py --project --summary; REPORT-only autonomy boundary (auto_safe:false=human, never auto-edit); exit 1=findings=SUCCESS (X1); silent-degrade only on exit 2/unavailable"
}

# Prompt-text: the /feature Status mode KB-drift fold (feature SKILL.md §"##
# Status mode") carries the load-bearing prose anchors (X4 + X6): the
# project-LABELED header `### KB drift — <project>` (X6 — single-project fold
# inside an all-project surface MUST be labeled so a one-project count is never
# mistaken for global); the `(run /kb-audit for detail)` pointer (one headline
# line, detail lives in /kb-audit); the omit-when-0-findings rule; the
# omit-when-unavailable / non-blocking / never-block rule; and the
# single-project scope note. Catches a regression where the fold drops the
# project label (X6), starts expanding grouped detail inline, or stops being
# non-blocking / omit-on-zero.
check_feature_status_kb_drift_fold() {
  local skill="$PLUGIN_ROOT/skills/feature/SKILL.md"
  [ -f "$skill" ] || { echo "$skill missing"; return 1; }
  local section
  section=$(awk '
    !in_s && $0 == "## Status mode" { in_s = 1 }
    in_s && /^## Checklist mode/ { exit }
    in_s { print }
  ' "$skill")
  [ -n "$section" ] || { echo "$skill missing '## Status mode' section"; return 1; }
  # X6: project-LABELED header.
  printf '%s\n' "$section" | grep -qF '### KB drift — <project>' \
    || { echo "$skill §Status mode missing the labeled '### KB drift — <project>' header (X6)"; return 1; }
  # One-line headline + detail pointer to /kb-audit.
  printf '%s\n' "$section" | grep -qF '(run /kb-audit for detail)' \
    || { echo "$skill §Status mode KB-drift fold missing the '(run /kb-audit for detail)' pointer"; return 1; }
  # Best-effort scanner invocation with --summary.
  printf '%s\n' "$section" | grep -qF -- '--summary' \
    || { echo "$skill §Status mode KB-drift fold missing the scanner --summary invocation"; return 1; }
  # Omit-when-0-findings.
  printf '%s\n' "$section" | grep -qi 'omit' \
    || { echo "$skill §Status mode KB-drift fold missing the omit-when-empty rule"; return 1; }
  # Omit-when-unavailable / non-blocking.
  printf '%s\n' "$section" | grep -qiE 'non-blocking|never block' \
    || { echo "$skill §Status mode KB-drift fold missing the non-blocking / never-block guarantee"; return 1; }
  printf '%s\n' "$section" | grep -qiE 'unavailable|exit 2' \
    || { echo "$skill §Status mode KB-drift fold missing the scanner-unavailable degrade path"; return 1; }
  # X6: single-project scope note (vs the all-project spec tables).
  printf '%s\n' "$section" | grep -qiE 'single-project|all-project|resolved .?project' \
    || { echo "$skill §Status mode KB-drift fold missing the single-project scope note (X6)"; return 1; }
  echo "$skill §Status mode KB-drift fold: labeled '### KB drift — <project>' header (X6); '(run /kb-audit for detail)' one-line pointer; --summary best-effort run; omit-when-0; non-blocking + unavailable-degrade; single-project scope note"
}

# Prompt-text: /kb-audit is wired into the intent→skill trigger map in BOTH
# the runtime-injected copy (hooks/session-prompt.md) AND the portable paste
# copy (docs/claude-md-snippet.md), each carrying the literal KB-hygiene intent
# phrase "check KB drift", AND is listed in the README §Usage core-trigger
# surface (X4 — README is a permanent pin target, not red-test-only). Catches a
# regression where the trigger row is dropped from one copy (so the two copies
# drift) or the /kb-audit entry vanishes from the README.
check_kb_audit_trigger_map_wired() {
  local sp="$PLUGIN_ROOT/hooks/session-prompt.md"
  local snippet="$PLUGIN_ROOT/docs/claude-md-snippet.md"
  local readme="$PLUGIN_ROOT/README.md"
  [ -f "$sp" ] || { echo "$sp missing"; return 1; }
  [ -f "$snippet" ] || { echo "$snippet missing"; return 1; }
  [ -f "$readme" ] || { echo "$readme missing"; return 1; }
  # session-prompt.md trigger row: /kb-audit + the literal intent phrase.
  grep -qF '/kb-audit' "$sp" \
    || { echo "$sp missing the /kb-audit trigger row"; return 1; }
  grep -qF 'check KB drift' "$sp" \
    || { echo "$sp missing the literal 'check KB drift' KB-hygiene intent phrase"; return 1; }
  # claude-md-snippet.md portable copy: same row + phrase.
  grep -qF '/kb-audit' "$snippet" \
    || { echo "$snippet missing the portable /kb-audit trigger row"; return 1; }
  grep -qF 'check KB drift' "$snippet" \
    || { echo "$snippet missing the literal 'check KB drift' KB-hygiene intent phrase"; return 1; }
  # README core-trigger surface (X4 — permanent pin target).
  grep -qF '/kb-audit' "$readme" \
    || { echo "$readme missing /kb-audit in the Usage core-trigger surface (X4)"; return 1; }
  echo "/kb-audit trigger row wired in hooks/session-prompt.md + docs/claude-md-snippet.md (both with literal 'check KB drift') + README core-trigger surface (X4)"
}

# Non-drift: the 8-status canonical enum line (NO DONE) lives in
# docs/kb-layout.md, is NOT re-declared in spec-template.md, and equals the
# scanner's CANONICAL_SPEC_STATUSES constant. DONE is a separate read-compat
# synonym (ACCEPTED_SPEC_STATUSES) — assert it is accepted by C3 (a status:DONE
# spec is NOT flagged) and is NOT folded into the enum line.
check_kb_layout_status_enum_single_source() {
  local layout="$PLUGIN_ROOT/docs/kb-layout.md"
  local template="$PLUGIN_ROOT/skills/feature/references/spec-template.md"
  local scanner="$PLUGIN_ROOT/tests/kb_drift_scan.py"
  local enum_line='status: DRAFT | APPROVED | AUDIT_PASSED | IN_PROGRESS | BLOCKED | SHIPPED | VERIFIED | DISCARDED'
  [ -f "$layout" ] || { echo "$layout missing"; return 1; }
  [ -f "$template" ] || { echo "$template missing"; return 1; }
  [ -f "$scanner" ] || { echo "$scanner missing"; return 1; }

  # Positive: enum line present in kb-layout.md.
  grep -qF "$enum_line" "$layout" \
    || { echo "$layout missing canonical 8-status enum line"; return 1; }

  # Negative: NOT re-declared in spec-template.md (canonical/template split).
  if grep -qF "$enum_line" "$template"; then
    echo "$template re-declares the status enum line — must only point at docs/kb-layout.md §Feature Spec frontmatter"
    return 1
  fi

  # Equality: kb-layout enum line == scanner CANONICAL_SPEC_STATUSES; DONE
  # excluded from canonical but accepted by ACCEPTED; status:DONE not flagged.
  python3 - "$layout" "$scanner" <<'PYEOF'
import importlib.util, re, sys
from pathlib import Path

layout, scanner = sys.argv[1], sys.argv[2]

# Load the scanner module to read its enum constants.
sys.path.insert(0, str(Path(scanner).resolve().parent))
spec = importlib.util.spec_from_file_location("kb_drift_scan", scanner)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

canonical = list(mod.CANONICAL_SPEC_STATUSES)
accepted = set(mod.ACCEPTED_SPEC_STATUSES)

# Parse the enum line tokens from kb-layout.md.
m = None
for line in Path(layout).read_text(encoding="utf-8").splitlines():
    if line.strip().startswith("status: DRAFT |"):
        m = line
        break
if m is None:
    print("could not find the status enum line in kb-layout.md")
    sys.exit(1)
tokens = [t.strip() for t in m.split("status:", 1)[1].split("|")]

if tokens != canonical:
    print(f"enum line tokens {tokens} != CANONICAL_SPEC_STATUSES {canonical}")
    sys.exit(1)
if "DONE" in tokens:
    print("DONE must NOT appear in the canonical enum line")
    sys.exit(1)
if accepted != set(canonical) | {"DONE"}:
    print(f"ACCEPTED_SPEC_STATUSES {accepted} != canonical ∪ {{DONE}}")
    sys.exit(1)
if "DONE" not in accepted:
    print("DONE must be in ACCEPTED_SPEC_STATUSES (legacy read-compat)")
    sys.exit(1)
print("enum single-source: kb-layout 8-status line == CANONICAL (no DONE); DONE accepted only via ACCEPTED")
PYEOF
  [ "$?" -eq 0 ] || return 1

  # Behavioral: a status:DONE spec is NOT flagged by C3.
  local tmpd
  tmpd="$(mktemp -d)" || { echo "mktemp failed"; return 1; }
  cat > "$tmpd/legacy-done.md" <<'SPECEOF'
---
title: Legacy Done Spec
project: fixture
type: spec
status: DONE
created: 2026-04-16
tags: [spec, fixture]
---

Legacy DONE spec — read-compat synonym of VERIFIED; must NOT be flagged.
SPECEOF
  local out
  out="$(python3 "$scanner" "$tmpd" 2>/dev/null)"
  local rc=$?
  rm -rf "$tmpd"
  if printf '%s' "$out" | grep -qF 'C3_status_enum_violation'; then
    echo "status:DONE spec was wrongly flagged C3 (DONE is legacy read-compat, must be accepted)"
    return 1
  fi
  if [ "$rc" -ne 0 ]; then
    echo "scanner exited non-zero on a clean status:DONE-only vault (rc=$rc)"
    return 1
  fi
  echo "kb-layout enum single-source intact; status:DONE accepted (not C3-flagged)"
}

# --- KB parallel-write protection (spec 2026-06-03-kb-parallel-write-protection) ---
# Stage-1 enforcement slice: orchestrator-sole-KB-writer (M1) + codex sandbox (M2).
# Four pins P1-P4, helper prefix `check_pwp_` (so the Step-3 probe
# `grep -c '^check_pwp_' tests/smoke-proves-manifest.txt` == 4). All prompt-text.

# Shared allowlist-primary write-verb scanner (§3.8 P2/P4). For each dev-facing
# line in the WHOLE FILE that contains a write verb, the write-TARGET must be
# ONLY captures/ , report.json , or a source/git path. A line whose target is
# the spec / exec.md / observed / workdoc / Log / status / compliance-checker
# FAILS — unless it is a prohibition ("do NOT write X", "never", "read-only",
# "may NOT", "but NOT") or attributes the action to the orchestrator. A write
# verb sitting DIRECTLY on a forbidden target (e.g. "Update observed",
# "append a note to the spec Log", "Spawn spec-compliance-checker",
# "Check off the step", "Set spec status") is a HARD fail even if the line also
# names an allowed token. Target-allowlist, not phrase-denylist — a novel
# phrasing of a forbidden write still fails because its target is off-allowlist.
_pwp_allowlist_scan() {
  python3 - "$1" <<'PY'
import re
import sys

path = sys.argv[1]
lines = open(path, encoding="utf-8").read().splitlines()

# X3/X8: WRITE_RE is a FLOOR, not the structural teeth. It is case-insensitive
# and carries the synonym set so a forbidden line using a lowercase/synonym verb
# (update/set/edit/modify/mark off/populate/log/enter/flip/note down/...) is not
# silently skipped (re-introducing the X17 denylist hole). The structural teeth
# (below) are "nearest write-destination after a write verb is a forbidden
# target, and the orchestrator is NOT the same-clause actor of that verb" — not
# the verb enumeration. `(?<![-/])` … `(?![-/])` reject a verb token embedded in
# a hyphen/slash compound noun (e.g. `workspace-write`, `read-write`,
# `amend/rebase`) on either side — config literals / nouns, not dev imperatives.
# X8: `log` is the feature's own vocabulary aimed at the spec Log; as a VERB it
# is the attack ("Log your R2 justification …") but as a NOUN it is everywhere
# ("the spec Log", "the Log"). The fixed-width lookbehinds `(?<!the )(?<!spec )`
# drop the noun forms; only the verb form is a write verb, the noun forms stay
# FORBIDDEN targets.
LOG_VERB = r"(?<!the )(?<!spec )\blog\b"
WRITE_RE = re.compile(
    r"(?<![-/])(?:"
    r"\bupdate(?:s|d)?\b|\bwrite(?:s)?\b|\bsave(?:s|d)?\b|\bappend(?:s|ed)?\b|"
    r"\bcheck(?:s)?\s+off\b|\bmark(?:s)?\s+off\b|\bspawn(?:s)?\b|\bset(?:s)?\b|"
    r"\bedit(?:s|ed)?\b|\bmodif(?:y|ies|ied)\b|\bfill(?:s)?\b|\brecord(?:s|ed)?\b|"
    r"\bpopulate(?:s|d)?\b|\binitiali[sz]e(?:s|d)?\b|\bamend(?:s|ed)?\b|\bput\b|"
    r"\binsert(?:s|ed)?\b|" + LOG_VERB + r"|\benter(?:s|ed)?\b|\bflip(?:s|ped)?\b|"
    r"\bnote(?:s|d)?\s+down\b)(?![-/])",
    re.IGNORECASE)

FORBIDDEN_RE = re.compile(
    r"\bthe spec\b|\bspec Log\b|\bspec file\b|\bspec frontmatter\b|"
    r"\bspec `status`\b|\bspec status\b|`exec\.md`|\bexec\.md\b|\bobserved\b|"
    r"`observed`|observed\.|\bthe workdoc\b|\bthe Log\b|\bLog section\b|"
    r"\bLog append\b|\bLog entry\b|\bLog line\b|\bLogs\b|\bLogged\b|\bstatus\b|"
    r"compliance-checker|spec-compliance-checker|\bthe checker\b|\bchecklist\b")

# X7: every ALLOWED token is word-boundary anchored so a substring inside a
# larger word (git⊂digital, capture⊂captured, commit⊂commitment) cannot win the
# nearest-dest race. captures/ and report.json keep their literal punctuated form.
ALLOWED_RE = re.compile(
    r"captures/|`captures/`|report\.json|`report\.json`|"
    r"\bcommit(?:s|ted|ting)?\b|\bgit\b|\bbranch(?:es)?\b|\bsource-repo\b|"
    r"\bcapture(?:s|d)?\b")

# Prohibition markers — a forbidden line that tells the dev NOT to do something
# (or that something is read-only) is compliant. Does NOT include a bare
# "orchestrator" token (X2): mere mention of the orchestrator must not exempt a
# dev-imperative forbidden write. Orchestrator-AS-SUBJECT exemption is positional
# + clause-scoped — handled in orch_is_actor(), not here.
PROHIBITION_RE = re.compile(
    r"do NOT|does NOT|never writes?|NOT touch|NOT write|may NOT|but NOT|"
    r"NOT the spec|no longer|read-only|read only|writes nothing|"
    r"neither you nor|contradicts this contract|are read-only", re.IGNORECASE)

# Orchestrator-as-actor token (subject attribution).
ORCH_SUBJECT_RE = re.compile(
    r"\borchestrator\b|\borchestrator-owned\b|\borchestrator's\b", re.IGNORECASE)

# X6: a NEW-SUBJECT signal between the orchestrator token and the verb breaks
# attribution — a second-person pronoun (the dev became the subject) or a
# sentence-ending period (new sentence = new subject). A bare comma/semicolon is
# NOT a break: "the orchestrator parses it, copies …, then spawns the checker" is
# one orchestrator subject with a compound predicate.
CLAUSE_BREAK_RE = re.compile(r"\.\s|\.$|\byou\b|\byour\b|\byourself\b",
                             re.IGNORECASE)


def orch_is_actor(line, verb_start):
    """X6: clause-scoped positional attribution. An orchestrator token precedes
    the verb AND no NEW-SUBJECT signal sits between them, so a cross-clause /
    cross-sentence mention ("After the orchestrator unblocks you, update the spec
    status") no longer exempts the dev-imperative verb."""
    for om in ORCH_SUBJECT_RE.finditer(line):
        if om.start() >= verb_start:
            break
        if not CLAUSE_BREAK_RE.search(line[om.end():verb_start]):
            return True
    return False


# X2/X4: single clause-tolerant algorithm — NO DIRECT/non-direct split (the
# split's lenient path re-introduced the bypass class). For each write verb on
# the line, look at what comes AFTER it: if the NEAREST write-destination after
# the verb is a forbidden target (and an allowed dest does not come first), it is
# a forbidden dev-write UNLESS the orchestrator is the same-clause actor of THAT
# verb. Iterating ALL verbs makes it clause-tolerant: "put … report.json notes
# (the orchestrator appends it to the spec Log …)" passes because the first verb
# (put) has an ALLOWED nearest-dest (report.json) and the second verb (appends →
# spec Log) has the orchestrator same-clause before it. Teeth = nearest-dest +
# clause-scoped positional attribution; the verb list is a FLOOR.
#
# KNOWN LIMITATION (§3.8 offline-pin limit) — not closed in this bounded pass:
#   X9 (whole-line PROHIBITION short-circuit): a prohibition in one clause
#     exempts a forbidden write in a different clause of the same line, e.g.
#     `You append to the spec Log; the old captures path is no longer used.`
#     Per-clause PROHIBITION scoping false-flagged many legit whole-line
#     prohibition sentences in the real docs, so it stays a whole-line check.
#   X10 (fronted object): `The spec status: set it to DONE.` — the forbidden
#     target precedes the verb (object fronting), so the nearest-dest-after-verb
#     rule does not see it. Both need sentence parsing beyond an offline regex
#     pin; accepted as the offline-pin limit (the mechanical guarantee on the
#     codex path is the sandbox §3.3, on the senior path the holistic rewrite).
failures = []
for i, line in enumerate(lines, 1):
    if PROHIBITION_RE.search(line):
        continue  # X9 known-limitation: whole-line prohibition short-circuit
    flagged = False
    for wm in WRITE_RE.finditer(line):
        rest = line[wm.end():]
        fhit = FORBIDDEN_RE.search(rest)
        if not fhit:
            continue  # this verb's object is not a forbidden target
        ahit = ALLOWED_RE.search(rest)
        if ahit and ahit.start() < fhit.start():
            continue  # nearest dest after the verb is ALLOWED → object allowed
        if orch_is_actor(line, wm.start()):
            continue  # orchestrator is the same-clause actor of this verb
        flagged = True
        break
    if flagged:
        failures.append((i, line))

if failures:
    print(f"{path}: allowlist FAIL — dev-facing write-verb line(s) target a "
          f"forbidden KB surface (spec/exec.md/observed/workdoc/Log/status/checker):")
    for n, l in failures:
        print(f"  :{n}: {l.strip()[:160]}")
    sys.exit(1)
sys.exit(0)
PY
}

# Continuous parallel diff-audits (large multi-step features — opt-in):
# §Implement subsection rule text. Prompt-text regression-guard for the 14
# load-bearing anchors — every behavior-bearing invariant whose removal would
# change orchestrator runtime behavior OR re-introduce a prior numbered finding
# (heading, opt-in-not-default, exact overview sub-line, initial + fixup
# `/cross-audit` invocations, worktree isolation, narrow scope, SOLE-writer
# reconciliation, audit_slug isolation, serial-gate header, append-only-fixup,
# pause-on-HIGH, Phase-5 non-replacement, ref-range-not-persisted). Residual is
# non-load-bearing prose — this is a regression-guard, not a prose-completeness proof.
check_cpda_subsection() {
  local path='skills/feature/SKILL.md'
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local a
  local anchors=(
    '### Continuous parallel diff-audits (large multi-step features — opt-in)'
    '**Opt-in, not default.**'
    '/cross-audit <prev-step-sha>..<step-sha> --mode full --severity high --materialize=worktree'
    'NEVER run a diff-audit in the active implementation worktree'
    'audit only the step/batch commit range'
    'the orchestrator stays the SOLE writer of the spec'
    'parallel audits never collide on a shared findings file'
    'does NOT weaken the serial per-step compliance gate'
    'it never rebases or amends an already-landed step'
    'PAUSES dispatch of NEW steps until that finding is triaged'
    'Does NOT replace the Phase-5 final code-audit gate.'
    '/cross-audit <prev-step-sha>..<fixup-sha> --mode full --severity high --materialize=worktree'
    'ref-range scope is NOT persisted in findings frontmatter'
    '(large multi-step features: opt-in continuous parallel diff-audits — see §Implement)'
  )
  for a in "${anchors[@]}"; do
    grep -qF "$a" "$path" \
      || { echo "$path §Implement continuous-parallel-diff-audits missing anchor: $a"; return 1; }
  done
  echo "$path §Implement continuous-parallel-diff-audits: all 14 load-bearing anchors present"
}

# P1 — orchestrator copies observed into exec.md BEFORE spawning the
# compliance-checker (the loop-ordering invariant; checker contract unchanged).
check_pwp_loop_ordering() {
  local path='skills/feature/SKILL.md'
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qF '**Copy observed BEFORE spawning the checker.**' "$path" \
    || { echo "$path §Implement missing '**Copy observed BEFORE spawning the checker.**' ordering anchor"; return 1; }
  grep -qF 'copies every `report.json` field into `exec.md` `observed` BEFORE spawning the compliance-checker' "$path" \
    || { echo "$path §Implement missing 'copies every report.json field into exec.md observed BEFORE spawning the compliance-checker' ordering sentence"; return 1; }
  # SKILL.md:170 must say the ORCHESTRATOR (not the developer) fills observed.
  grep -qF 'the orchestrator fills `observed` from the developer'"'"'s `report.json` before spawning the compliance-checker' "$path" \
    || { echo "$path missing 'orchestrator fills observed from the developer's report.json before spawning the compliance-checker' (was 'developer fills')"; return 1; }
  # X1 fix: R1/R2 justification goes to the spec Log BEFORE the checker (the
  # checker reads the spec Log, not observed.notes, for R1/R2); only the
  # checkoff stays post-PASS. Re-deferring it regresses this assertion.
  grep -qF '**Append R1/R2 justification to the spec Log BEFORE spawning the checker.**' "$path" \
    || { echo "$path §Implement missing '**Append R1/R2 justification to the spec Log BEFORE spawning the checker.**' anchor (X1)"; return 1; }
  grep -qF 'the orchestrator MUST append it to the spec Log in the checker-readable grammar BEFORE spawning the checker' "$path" \
    || { echo "$path §Implement missing 'orchestrator MUST append R1/R2 justification to the spec Log … BEFORE spawning the checker' sentence (X1)"; return 1; }
  grep -qF 'Only the `[ ]→[x]` checkoff stays post-PASS.' "$path" \
    || { echo "$path §Implement missing 'Only the [ ]->[x] checkoff stays post-PASS.' clause (X1)"; return 1; }
  # X5 fix: R7 is NOT checker-gated — its spec-Log append must be framed as
  # audit-trail, not a checker precondition. Assert the corrected framing and
  # reject the false 'R7 … checker reads the spec Log' claim.
  grep -qF 'R5-R7 are convention-text references, NOT checker-gated' "$path" \
    || { echo "$path §Implement missing 'R5-R7 … NOT checker-gated' clarification (X5)"; return 1; }
  grep -qF 'R7 is not checker-gated, so its Log append is a record, not a checker precondition' "$path" \
    || { echo "$path §Implement missing 'R7 … not checker-gated … record, not a checker precondition' clause (X5)"; return 1; }
  # The false 'R1/R2/R7 … rides report.json notes → observed.notes → the
  # checker' sentence must be gone (only R3 takes that path).
  if grep -qF 'Any R1/R2/R7 justification rides in `report.json` `notes` → `observed.notes` → the checker.' "$path"; then
    echo "$path still claims R1/R2/R7 justification rides observed.notes to the checker (false — checker reads spec Log for R1/R2) (X1)"
    return 1
  fi
  echo "$path §Implement: orchestrator writes observed + appends R1/R2 justification (checker-gated) + R7 audit-trail to the spec Log BEFORE the checker (only checkoff post-PASS)"
}

# P2 — developer-workflow.md (+ developer-senior.md) allowlist-primary:
# canonical allowlist sentence present + WHOLE-FILE write-verb target scan.
check_pwp_devworkflow_allowlist() {
  local dwf='skills/feature/references/developer-workflow.md'
  local snr='agents/developer-senior.md'
  [ -r "$dwf" ] || { echo "$dwf not readable"; return 1; }
  [ -r "$snr" ] || { echo "$snr not readable"; return 1; }
  grep -qF 'The developer'"'"'s ONLY writes are: source-repo commits on the branch, and files under `captures/` (including `report.json`). The developer writes nothing else and does not spawn the compliance-checker.' "$dwf" \
    || { echo "$dwf missing the canonical allowlist sentence (byte-exact)"; return 1; }
  local out
  out=$(_pwp_allowlist_scan "$dwf") || { echo "$out"; return 1; }
  out=$(_pwp_allowlist_scan "$snr") || { echo "$out"; return 1; }
  echo "developer-workflow.md has the canonical allowlist sentence; whole-file write-verb scan clean (dwf + developer-senior)"
}

# P3 — codex sandbox config shape: workspace-write (NOT danger-full-access),
# approval-policy: never, nested sandbox_workspace_write.writable_roots +
# captures-only placeholder.
check_pwp_codex_sandbox_config() {
  local path='agents/developer-codex.md'
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  grep -qE '^sandbox: workspace-write' "$path" \
    || { echo "$path missing active 'sandbox: workspace-write' param"; return 1; }
  if grep -qF 'sandbox: danger-full-access' "$path"; then
    echo "$path still sets the stale 'sandbox: danger-full-access' param"
    return 1
  fi
  grep -qE '^approval-policy: never' "$path" \
    || { echo "$path missing active 'approval-policy: never' param"; return 1; }
  grep -qF 'sandbox_workspace_write:' "$path" \
    || { echo "$path missing nested 'sandbox_workspace_write:' key"; return 1; }
  grep -qF 'writable_roots: [<captures_dir>]' "$path" \
    || { echo "$path missing captures-only 'writable_roots: [<captures_dir>]' placeholder"; return 1; }
  echo "$path codex sandbox config: workspace-write + approval-policy:never + nested sandbox_workspace_write.writable_roots=[<captures_dir>] (no danger-full-access)"
}

# P4 — developer-codex.md allowlist-primary WHOLE-FILE scan: no dev-facing
# write-verb line targets anything but captures/report.json/git; no
# checker-spawn directive.
check_pwp_codex_allowlist() {
  local path='agents/developer-codex.md'
  [ -r "$path" ] || { echo "$path not readable"; return 1; }
  local out
  out=$(_pwp_allowlist_scan "$path") || { echo "$out"; return 1; }
  # Negative — the old "Compliance loop is yours — you spawn …" directive gone.
  if grep -qF 'Compliance loop is yours' "$path"; then
    echo "$path still contains the stale 'Compliance loop is yours' checker-spawn directive"
    return 1
  fi
  echo "$path whole-file write-verb scan clean (captures/report.json/git only; no checker-spawn directive)"
}

# Behavioral self-test for the shared allowlist scanner — proves it has teeth
# (catches the X1->X9->X13->X17 dev-KB-write regression class) by driving it
# against synthetic forbidden + compliant fixtures. Without this, P2/P4 could
# silently degrade to a no-op (always-pass) and not be noticed.
check_smoke_helper_pwp_allowlist_scanner_self_test() {
  local tmpd
  tmpd=$(mktemp -d 2>/dev/null) || { echo "self-test: mktemp -d failed"; return 1; }
  if [ -z "$tmpd" ] || [ ! -d "$tmpd" ]; then echo "self-test: bad tmpdir"; return 1; fi
  # Forbidden fixtures (each must be REJECTED by the scanner, rc!=0).
  printf '%s\n' '**k. Check off the step** in the spec checklist and append a terse note to the spec Log section.' > "$tmpd/bad1.md"
  printf '%s\n' '- **i. Update `observed`** fields in the workdoc with actual_files_touched.' > "$tmpd/bad2.md"
  printf '%s\n' '**j. Spawn `spec-compliance-checker`** subagent with spec_path, workdoc_path.' > "$tmpd/bad3.md"
  printf '%s\n' 'Set spec status: IN_PROGRESS in the spec frontmatter before writing any code.' > "$tmpd/bad4.md"
  printf '%s\n' 'Append a terse note to the spec Log after the commit.' > "$tmpd/bad5.md"
  # X2 class — forbidden dev-imperative that name-drops orchestrator AFTER the
  # verb (a stray trailing mention must NOT exempt the imperative). MUST REJECT.
  printf '%s\n' 'Update `observed` in exec.md so the orchestrator can read it.' > "$tmpd/bad_x2.md"
  # X3 class — forbidden lines using lowercase / synonym verbs. MUST REJECT.
  printf '%s\n' 'update observed fields in the workdoc' > "$tmpd/bad_x3a.md"
  printf '%s\n' 'set spec status: IN_PROGRESS' > "$tmpd/bad_x3b.md"
  printf '%s\n' 'edit the spec Log' > "$tmpd/bad_x3c.md"
  printf '%s\n' 'mark off the step in the checklist' > "$tmpd/bad_x3d.md"
  # X4 / X2-reopened class — NON-direct forbidden writes (verb NOT adjacent to
  # target: a noun-phrase / clause sits between the verb and the forbidden
  # target, or the orchestrator is mentioned only AFTER the verb). The prior
  # DIRECT/non-direct split exempted these; the clause-tolerant nearest-dest
  # algorithm MUST REJECT them.
  printf '%s\n' 'You update the spec status to DONE once the orchestrator unblocks you.' > "$tmpd/bad_x4a.md"
  printf '%s\n' 'Record observed fields in exec.md before returning; the orchestrator consumes them.' > "$tmpd/bad_x4b.md"
  printf '%s\n' 'write the blocker into the spec Log' > "$tmpd/bad_x4c.md"
  printf '%s\n' 'put your notes into observed.notes' > "$tmpd/bad_x4d.md"
  # X6 class — cross-clause orchestrator mention (orchestrator is the subject of
  # a DIFFERENT clause; a 2nd-person pronoun introduces the dev as the actor of
  # the forbidden write). Clause-scoped attribution MUST REJECT.
  printf '%s\n' 'After the orchestrator unblocks you, update the spec status yourself.' > "$tmpd/bad_x6.md"
  # X6 class — cross-SENTENCE orchestrator mention (period breaks attribution).
  printf '%s\n' 'The orchestrator does its thing. Update the spec status to DONE.' > "$tmpd/bad_x6b.md"
  # X7 class — ALLOWED substring inside a larger word must NOT fake-allow
  # ("digital" ⊅ git). Nearest dest after the verb is the forbidden spec status.
  printf '%s\n' 'Update the digital spec status to DONE.' > "$tmpd/bad_x7.md"
  # X8 class — write-verb synonym `log` (the feature's own vocabulary) aimed at
  # the spec Log. MUST REJECT.
  printf '%s\n' 'Log your R2 justification in the spec Log.' > "$tmpd/bad_x8.md"
  # Compliant fixtures (each must be ACCEPTED, rc==0).
  {
    printf '%s\n' 'Write your evidence to captures/step-NN-report.json and return the pointer.'
    printf '%s\n' 'The developer does NOT write the spec Log; the orchestrator appends the Log.'
  } > "$tmpd/good1.md"
  # X2 legit — orchestrator is the SUBJECT (precedes the verb). MUST ACCEPT.
  printf '%s\n' 'The orchestrator copies every report.json field into exec.md observed before spawning the compliance-checker.' > "$tmpd/good2.md"
  # X4 legit multi-clause — first verb (put) has an ALLOWED nearest-dest
  # (report.json); the second clause's verb (appends → spec Log) has the
  # orchestrator preceding it. MUST ACCEPT (clause-tolerance).
  printf '%s\n' 'put the assertion-update justification in report.json notes (the orchestrator appends it to the spec Log before the checker)' > "$tmpd/good3.md"
  # X6 legit — orchestrator is the same-clause subject (no 2nd-person pronoun /
  # period in the gap). MUST ACCEPT.
  printf '%s\n' 'the orchestrator appends it to the spec Log before spawning the checker' > "$tmpd/good4.md"
  local f rc
  for f in bad1 bad2 bad3 bad4 bad5 bad_x2 bad_x3a bad_x3b bad_x3c bad_x3d \
           bad_x4a bad_x4b bad_x4c bad_x4d bad_x6 bad_x6b bad_x7 bad_x8; do
    _pwp_allowlist_scan "$tmpd/$f.md" >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 0 ]; then
      echo "self-test: scanner WRONGLY accepted forbidden fixture $f (no teeth)"
      rm -rf "$tmpd"; return 1
    fi
  done
  for f in good1 good2 good3 good4; do
    _pwp_allowlist_scan "$tmpd/$f.md" >/dev/null 2>&1; rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "self-test: scanner WRONGLY rejected the compliant fixture $f"
      rm -rf "$tmpd"; return 1
    fi
  done
  rm -rf "$tmpd"
  echo "allowlist scanner self-test: 18 forbidden fixtures rejected (incl X2 trailing-orch, X3 synonym-verb, X4 non-direct, X6 cross-clause/sentence orch, X7 substring-allow, X8 log-verb classes), 4 compliant accepted (orch-subject + multi-clause + same-clause-orch); scanner has teeth"
}

# --- Grill protocol reference (spec 2026-06-29-grill-feature-gate, Step 1) ---
# Structure-floor pins for skills/feature/references/grill-protocol.md. They lock
# the canonical interview contract: the fixed Decisions column set + order, the
# three load-bearing mechanics, the coarse route enum, and the `changed-sections:
# none` valid value. The grill-aware Step 3.5 cross-audit verifies citation
# RESOLVABILITY and the user judges answer quality — these pins are the floor only
# (per spec §3.5 "No machine handshake parser for v1").
GRILL_PROTOCOL='skills/feature/references/grill-protocol.md'

# (1) Decisions table header carries the seven columns in the exact canonical
# order. Anchors on the header row (the `|`-prefixed line containing decision-id),
# normalizes pipe/whitespace, and compares the extracted column sequence against
# the canonical 7-tuple — asserts presence AND order, robust to cell spacing.
check_grill_protocol_decisions_schema_columns() {
  local f="$GRILL_PROTOCOL"
  test -f "$f" || { echo "$f missing"; return 1; }
  local got expected
  expected='decision-id | question | confirmed-answer | route | evidence-ref | numeric-example | changed-sections'
  got=$(grep -F 'decision-id' "$f" | grep -E '^\|' | head -1 \
    | sed -E 's/^\|//; s/\|$//' \
    | awk -F'|' '{out=""; for(i=1;i<=NF;i++){gsub(/^[ \t]+|[ \t]+$/,"",$i); out=(i==1?$i:out" | "$i)} print out}')
  if [ "$got" != "$expected" ]; then
    echo "grill-protocol.md Decisions column set/order mismatch: got [$got] expected [$expected]"
    return 1
  fi
  echo "grill-protocol.md Decisions schema: 7 columns present in canonical order"
}

# (2) All three load-bearing mechanics named by their canonical literals.
check_grill_protocol_three_mechanics_named() {
  local f="$GRILL_PROTOCOL"
  test -f "$f" || { echo "$f missing"; return 1; }
  local m
  for m in 'recommended-answer-per-question' \
           'explore-codebase-instead-of-ask' \
           'numeric-worked-examples-on-contested-points'; do
    grep -qF "$m" "$f" || { echo "grill-protocol.md missing mechanic literal: $m"; return 1; }
  done
  echo "grill-protocol.md names all three load-bearing mechanics"
}

# (3) Coarse route enum is the two-value `{routine, domain_input}` set (NOT numeric
# confidence). Pins the combined enum literal so a drift to a single token or a
# numeric label fails.
check_grill_protocol_route_enum() {
  local f="$GRILL_PROTOCOL"
  test -f "$f" || { echo "$f missing"; return 1; }
  grep -qF '{routine, domain_input}' "$f" \
    || { echo "grill-protocol.md missing route enum literal '{routine, domain_input}'"; return 1; }
  echo "grill-protocol.md route enum {routine, domain_input} present"
}

# (4) `changed-sections: none` is named a VALID value (not merely mentioned): the
# line carrying the literal must also carry the word "valid" (case-insensitive).
check_grill_protocol_changed_sections_none_valid() {
  local f="$GRILL_PROTOCOL"
  test -f "$f" || { echo "$f missing"; return 1; }
  grep -qF 'changed-sections: none' "$f" \
    || { echo "grill-protocol.md missing 'changed-sections: none' literal"; return 1; }
  grep -iF 'changed-sections: none' "$f" | grep -qiF 'valid' \
    || { echo "grill-protocol.md does not mark 'changed-sections: none' as a VALID value"; return 1; }
  echo "grill-protocol.md marks 'changed-sections: none' as valid"
}

# --- Grill gate sub-phase in /feature SKILL.md (spec 2026-06-29-grill-feature-gate, Step 2) ---
# Structure floor for the grill gate sub-phase wired into skills/feature/SKILL.md.
# Pin the load-bearing flow contracts: placement BEFORE the Step 3 approval HARD
# GATE (grill hardens the DRAFT before approval reflects it), the `off by default`
# opt-in framing, and the neutral-suggest never-blocks / never-auto-runs contract.
# The grill section is region-extracted (header → next `### `) for the literal
# pins, NOT file-wide grep — later steps add `grill`-prose elsewhere in SKILL.md.

# (1) The grill gate section header sits BEFORE the Step 3 approval HARD GATE.
# Region/order assertion: line of `### Grill gate` < line of the `<HARD-GATE>` tag.
# Catches a regression that moves grill after approval (which would let approval
# ratify an un-grilled spec — the whole point is approval reflects the grilled spec).
check_skill_grill_gate_before_approval() {
  local f='skills/feature/SKILL.md'
  test -f "$f" || { echo "$f missing"; return 1; }
  local grill_ln gate_ln
  grill_ln=$(grep -nF '### Grill gate' "$f" | head -1 | cut -d: -f1)
  gate_ln=$(grep -nF '<HARD-GATE>' "$f" | head -1 | cut -d: -f1)
  [ -n "$grill_ln" ] || { echo "SKILL.md missing '### Grill gate' section header"; return 1; }
  [ -n "$gate_ln" ] || { echo "SKILL.md missing '<HARD-GATE>' approval anchor"; return 1; }
  if [ "$grill_ln" -ge "$gate_ln" ]; then
    echo "SKILL.md grill gate (line $grill_ln) not before approval HARD GATE (line $gate_ln)"
    return 1
  fi
  echo "SKILL.md grill gate at line $grill_ln precedes approval HARD GATE at line $gate_ln"
}

# (2) The grill gate section carries the `off by default` opt-in framing
# (case-insensitive). Region-scoped to the grill section, NOT a file-wide grep.
check_skill_grill_gate_off_by_default() {
  local f='skills/feature/SKILL.md'
  test -f "$f" || { echo "$f missing"; return 1; }
  local section
  section=$(awk '/^### Grill gate/{cap=1;print;next} cap&&/^### /{exit} cap{print}' "$f")
  printf '%s\n' "$section" | grep -qiF 'off by default' \
    || { echo "SKILL.md grill gate section missing 'off by default' literal"; return 1; }
  echo "SKILL.md grill gate section states 'off by default'"
}

# (3) The neutral auto-suggest contract: it surfaces a suggestion but never blocks
# and never auto-runs. Region-scoped. Locks the anti-creep-to-mandatory copy so a
# regression cannot quietly turn the suggestion into a gate or an auto-run.
check_skill_grill_gate_suggest_never_blocks() {
  local f='skills/feature/SKILL.md'
  test -f "$f" || { echo "$f missing"; return 1; }
  local section
  section=$(awk '/^### Grill gate/{cap=1;print;next} cap&&/^### /{exit} cap{print}' "$f")
  printf '%s\n' "$section" | grep -qiF 'auto-suggest' \
    || { echo "SKILL.md grill gate section missing neutral 'auto-suggest' contract"; return 1; }
  printf '%s\n' "$section" | grep -qiF 'never blocks' \
    || { echo "SKILL.md grill gate suggest does not state 'never blocks'"; return 1; }
  printf '%s\n' "$section" | grep -qiF 'never auto-runs' \
    || { echo "SKILL.md grill gate suggest does not state 'never auto-runs'"; return 1; }
  echo "SKILL.md grill gate neutral suggest never blocks / never auto-runs"
}

# --- Grill-aware spec cross-audit (spec 2026-06-29-grill-feature-gate, Step 3) ---
# Structure floor for the grill-aware Step 3.5 spec cross-audit. The grill-aware
# clause is region-scoped to SKILL.md §3.5 (`### Step 3.5` → next `### `), NOT a
# file-wide grep — the Step 2 grill gate section carries `grill_status` / `never
# gates` prose that would false-pass a file-wide check. The reference-file pin
# asserts BOTH cross-auditor halves (Claude mode-focus + Codex dispatch template)
# name the Decisions/evidence-ref-resolvability clause, so the dual-model backstop
# is not half-blind.
SKILL_MD='skills/feature/SKILL.md'

# §3.5 region extractor: from `### Step 3.5` to the next 3-hash header (`### 3.5b`).
# `#### `-level subsections (Pass 1 / Pass 2 / 3.5a) stay inside the region.
_grill_skill_35_region() {
  awk '/^### Step 3\.5 /{cap=1;print;next} cap&&/^### /{exit} cap{print}' "$SKILL_MD"
}

# (1) §3.5 names the grill-aware Decisions consumption AND the evidence-ref
# resolvability contract. Catches a regression that drops grill-awareness from the
# spec audit (the backstop) or weakens it from citation-resolvability to nothing.
check_skill_grill_aware_spec_audit() {
  test -f "$SKILL_MD" || { echo "$SKILL_MD missing"; return 1; }
  local region; region=$(_grill_skill_35_region)
  printf '%s\n' "$region" | grep -qF 'grill-aware' \
    || { echo "SKILL.md §3.5 missing 'grill-aware' literal"; return 1; }
  printf '%s\n' "$region" | grep -qF '## Decisions' \
    || { echo "SKILL.md §3.5 grill-aware clause does not name '## Decisions' consumption"; return 1; }
  printf '%s\n' "$region" | grep -qF 'evidence-ref' \
    || { echo "SKILL.md §3.5 grill-aware clause does not name 'evidence-ref'"; return 1; }
  printf '%s\n' "$region" | grep -qF 'RESOLVES' \
    || { echo "SKILL.md §3.5 grill-aware clause does not require evidence-ref citations RESOLVE"; return 1; }
  echo "SKILL.md §3.5 grill-aware: consumes ## Decisions + verifies evidence-ref RESOLVES"
}

# (2) §3.5 states grill NEVER gates. Region-scoped: `never gates` also appears in
# the Step 2 grill gate section (`never blocks, never gates` + `Grill NEVER gates
# approval or audit`), so a file-wide grep would false-pass even if the §3.5 site
# lost it. Catches the slide where `deferred > 0` becomes a Step 3.5 fail.
check_skill_grill_never_gates_spec_audit() {
  test -f "$SKILL_MD" || { echo "$SKILL_MD missing"; return 1; }
  local region; region=$(_grill_skill_35_region)
  printf '%s\n' "$region" | grep -qiF 'never gates' \
    || { echo "SKILL.md §3.5 does not state grill NEVER gates"; return 1; }
  echo "SKILL.md §3.5 states grill NEVER gates (deferred>0 advisory, never a fail)"
}

# (3) §3.5 keeps the spec audit MANDATORY by default AND the Skip path preserved —
# the X3 anti-regression. Asserts all three load-bearing literals co-locate at the
# §3.5 site: `MANDATORY by default`, `preserved`, and the recorded skip evidence
# `spec_audit_evidence: skipped`. Catches a regression that removes the Skip path
# or quietly drops the mandatory-by-default framing when grill ran.
check_skill_spec_audit_mandatory_skip_preserved() {
  test -f "$SKILL_MD" || { echo "$SKILL_MD missing"; return 1; }
  local region; region=$(_grill_skill_35_region)
  printf '%s\n' "$region" | grep -qiF 'MANDATORY by default' \
    || { echo "SKILL.md §3.5 missing 'MANDATORY by default' framing"; return 1; }
  printf '%s\n' "$region" | grep -qiF 'preserved' \
    || { echo "SKILL.md §3.5 does not state the Skip path is preserved"; return 1; }
  printf '%s\n' "$region" | grep -qF 'spec_audit_evidence: skipped' \
    || { echo "SKILL.md §3.5 Skip path does not record 'spec_audit_evidence: skipped'"; return 1; }
  echo "SKILL.md §3.5 spec audit MANDATORY by default + Skip path preserved (records skipped)"
}

# (4) BOTH cross-auditor reference files name the grill Decisions / evidence-ref
# resolvability clause — the hub `agents/cross-auditor.md` delegates spec-mode focus
# to these references, so if either half lost the clause the dual-model backstop
# would be half-blind to the Decisions table. Asserts the three clause literals
# (`## Decisions`, `evidence-ref`, `RESOLVES`) in each file.
check_cross_auditor_spec_mode_grill_aware() {
  local f
  for f in 'agents/references/cross-auditor-mode-focus.md' \
           'agents/references/cross-auditor-codex-dispatch.md'; do
    test -f "$f" || { echo "$f missing"; return 1; }
    grep -qF '## Decisions' "$f" \
      || { echo "$f spec-mode grill clause does not name '## Decisions'"; return 1; }
    grep -qF 'evidence-ref' "$f" \
      || { echo "$f spec-mode grill clause does not name 'evidence-ref'"; return 1; }
    grep -qF 'RESOLVES' "$f" \
      || { echo "$f spec-mode grill clause does not require evidence-ref citations RESOLVE"; return 1; }
  done
  echo "cross-auditor spec-mode grill clause present in BOTH Claude + Codex reference files"
}

# (5) BOTH cross-auditor reference files carry the codebase-grounded + numeric spec-mode
# upgrade (spec 2026-06-29-cross-auditor-spec-mode-codebase-grounded). The hub
# `agents/cross-auditor.md` delegates spec-mode focus to these references, so if either
# half lacked the upgrade the dual-model backstop would be half-blind to the
# code-grounded + numeric defect class. Asserts the FOUR pinned shared anchors (§3.3) in
# each file: the two CAPABILITY headlines `Codebase-grounded verification` and lowercase
# `numeric worked example`, PLUS the two DISTINCT over-reach guardrail clauses
# `Bounding (no over-reach)` (general over-reach guard) AND `Create-carve-out` (the clause
# that actually mitigates the X1 spurious-HIGH-on-create class). Both guardrails are pinned
# separately because they are two distinct clauses — pinning only `Bounding (no over-reach)`
# left the `Create-carve-out` mitigation silently deletable while the pin stayed green
# (code-audit X3). The DISTINCT/offensive-vs-defensive scope note is INTENTIONALLY not
# behavior-pinned (its deletion does not regress absent→HIGH behavior) — a recorded decision
# per spec §3.3, not a gap.
check_cross_auditor_spec_mode_codebase_grounded() {
  local f
  for f in 'agents/references/cross-auditor-mode-focus.md' \
           'agents/references/cross-auditor-codex-dispatch.md'; do
    test -f "$f" || { echo "$f missing"; return 1; }
    grep -qF 'Codebase-grounded verification' "$f" \
      || { echo "$f spec-mode upgrade does not name 'Codebase-grounded verification'"; return 1; }
    grep -qF 'numeric worked example' "$f" \
      || { echo "$f spec-mode upgrade does not require a 'numeric worked example'"; return 1; }
    grep -qF 'Bounding (no over-reach)' "$f" \
      || { echo "$f spec-mode upgrade does not carry the 'Bounding (no over-reach)' guardrail"; return 1; }
    grep -qF 'Create-carve-out' "$f" \
      || { echo "$f spec-mode upgrade does not carry the 'Create-carve-out' guardrail (X1 spurious-HIGH-on-create mitigation)"; return 1; }
  done
  echo "cross-auditor spec-mode codebase-grounded + numeric + BOTH over-reach guardrails (Bounding + Create-carve-out) present in BOTH Claude + Codex reference files"
}

# --- Grill write-back surface in spec-template.md (spec 2026-06-29-grill-feature-gate, Step 4) ---
# Structure floor for the grill write-back surface added to
# skills/feature/references/spec-template.md: the `## Decisions` table on the fixed
# 7-column schema, the grill_status / grill_date / grill_coverage frontmatter, the
# `changed-sections: none` valid value, and the non-degraded boundary note (the two
# `skipped` tokens differ by key). The cross-consistency pin asserts the Decisions
# column set MATCHES grill-protocol.md exactly (column-set equality, not mere presence) —
# the schema's two homes (canonical protocol + author template) cannot drift apart.
SPEC_TEMPLATE='skills/feature/references/spec-template.md'

# Shared extractor: normalize the Decisions table header row of $1 to the canonical
# ` | `-joined column tuple (the pipe-prefixed header line carrying decision-id, with
# per-cell whitespace stripped). Emits empty output when no header row exists.
_grill_decisions_columns() {
  grep -F 'decision-id' "$1" | grep -E '^\|' | head -1 \
    | sed -E 's/^\|//; s/\|$//' \
    | awk -F'|' '{out=""; for(i=1;i<=NF;i++){gsub(/^[ \t]+|[ \t]+$/,"",$i); out=(i==1?$i:out" | "$i)} print out}'
}

# (1) spec-template.md carries the `## Decisions` header AND the full 7-column tuple in
# canonical order. Catches a regression that drops the section header or drops/reorders/
# renames any column of the write-back schema authors copy into a real spec.
check_spec_template_decisions_schema() {
  local f="$SPEC_TEMPLATE"
  test -f "$f" || { echo "$f missing"; return 1; }
  grep -qF '## Decisions' "$f" || { echo "$f missing '## Decisions' section header"; return 1; }
  local got expected
  expected='decision-id | question | confirmed-answer | route | evidence-ref | numeric-example | changed-sections'
  got=$(_grill_decisions_columns "$f")
  if [ "$got" != "$expected" ]; then
    echo "spec-template.md Decisions column set/order mismatch: got [$got] expected [$expected]"
    return 1
  fi
  echo "spec-template.md Decisions schema: ## Decisions header + 7 columns in canonical order"
}

# (2) The grill frontmatter fields are present in the YAML frontmatter block (region-
# scoped to the leading `---`…`---`, so a stray body mention cannot satisfy the pin).
check_spec_template_grill_frontmatter() {
  local f="$SPEC_TEMPLATE"
  test -f "$f" || { echo "$f missing"; return 1; }
  local fm
  fm=$(awk 'NR==1&&/^---$/{cap=1;next} cap&&/^---$/{exit} cap{print}' "$f")
  local k
  for k in 'grill_status:' 'grill_date:' 'grill_coverage:'; do
    printf '%s\n' "$fm" | grep -qF "$k" \
      || { echo "spec-template.md frontmatter missing $k"; return 1; }
  done
  echo "spec-template.md frontmatter carries grill_status / grill_date / grill_coverage"
}

# (3) `changed-sections: none` is named a VALID value (the line carrying the literal
# also carries `valid`, case-insensitive) — authors record `none` honestly, never fake a
# bogus section ref.
check_spec_template_changed_sections_none_valid() {
  local f="$SPEC_TEMPLATE"
  test -f "$f" || { echo "$f missing"; return 1; }
  grep -qF 'changed-sections: none' "$f" \
    || { echo "spec-template.md missing 'changed-sections: none' literal"; return 1; }
  grep -iF 'changed-sections: none' "$f" | grep -qiF 'valid' \
    || { echo "spec-template.md does not mark 'changed-sections: none' as a VALID value"; return 1; }
  echo "spec-template.md marks 'changed-sections: none' as valid"
}

# (4) The non-degraded boundary note: one line states grill_status: skipped is
# NON-DEGRADED, the note contrasts it with the degraded *_audit_evidence: skipped, and
# states the two keys are different (never collide). Catches a regression that drops the
# boundary, which would let grill_status leak into the degraded predicate.
check_spec_template_grill_non_degraded_note() {
  local f="$SPEC_TEMPLATE"
  test -f "$f" || { echo "$f missing"; return 1; }
  grep -iF 'non-degraded' "$f" | grep -qiF 'grill_status' \
    || { echo "spec-template.md missing 'grill_status: skipped is non-degraded' note"; return 1; }
  grep -qF '*_audit_evidence' "$f" \
    || { echo "spec-template.md non-degraded note does not contrast with *_audit_evidence"; return 1; }
  grep -qiF 'different key' "$f" \
    || { echo "spec-template.md non-degraded note does not state the keys are different (never collide)"; return 1; }
  echo "spec-template.md non-degraded note: grill_status skipped non-degraded, distinct from *_audit_evidence (different keys)"
}

# (5) CROSS-CONSISTENCY (spec §5 Step 4 mandate): the Decisions column set in
# spec-template.md MATCHES grill-protocol.md EXACTLY — column-set equality, not mere
# presence. Extracts both header tuples and compares, so the schema's two homes (the
# canonical protocol and the author-facing template) can never drift apart.
check_decisions_schema_cross_consistency() {
  local sp="$SPEC_TEMPLATE" gp="$GRILL_PROTOCOL"
  test -f "$sp" || { echo "$sp missing"; return 1; }
  test -f "$gp" || { echo "$gp missing"; return 1; }
  local sp_cols gp_cols
  sp_cols=$(_grill_decisions_columns "$sp")
  gp_cols=$(_grill_decisions_columns "$gp")
  [ -n "$sp_cols" ] || { echo "spec-template.md has no Decisions header row to extract"; return 1; }
  [ -n "$gp_cols" ] || { echo "grill-protocol.md has no Decisions header row to extract"; return 1; }
  if [ "$sp_cols" != "$gp_cols" ]; then
    echo "Decisions column set differs: spec-template.md [$sp_cols] vs grill-protocol.md [$gp_cols]"
    return 1
  fi
  echo "Decisions column set matches exactly between spec-template.md and grill-protocol.md"
}

# --- Grill in the canonical KB-layout reference (spec 2026-06-29-grill-feature-gate, Step 5) ---
# Structure floor for the grill documentation added to docs/kb-layout.md (the canonical
# state-machine + frontmatter reference): grill is a DRAFT-hardening SUB-PHASE that adds
# no new status token (zero migration), and it carries three optional frontmatter fields.
# The third pin (degraded-predicate-negative) is the load-bearing X1/X5 guard — it lives
# in SKILL.md, region-scoped, never file-wide.
KB_LAYOUT='docs/kb-layout.md'

# (1) kb-layout.md carries the `no new state token` literal — grill is a sub-phase, NOT a
# status value, so the DRAFT|APPROVED|… enum is unchanged and there is zero migration.
# Catches a regression that drops the zero-migration assertion (or worse, promotes grill to
# a real state token). This is the step's RED literal (failing_test_cmd greps for it).
check_kb_layout_grill_no_new_state_token() {
  local f="$KB_LAYOUT"
  test -f "$f" || { echo "$f missing"; return 1; }
  grep -qF 'no new state token' "$f" \
    || { echo "kb-layout.md missing 'no new state token' literal (grill is a sub-phase, zero migration)"; return 1; }
  echo "kb-layout.md documents grill adds 'no new state token' (zero migration)"
}

# (2) kb-layout.md documents the three grill frontmatter fields. Catches a regression that
# drops any of grill_status / grill_date / grill_coverage from the canonical frontmatter
# reference (which the orchestrator + librarian consume).
check_kb_layout_grill_frontmatter() {
  local f="$KB_LAYOUT"
  test -f "$f" || { echo "$f missing"; return 1; }
  local k
  for k in 'grill_status' 'grill_date' 'grill_coverage'; do
    grep -qF "$k" "$f" \
      || { echo "kb-layout.md missing grill frontmatter field doc: $k"; return 1; }
  done
  echo "kb-layout.md documents grill frontmatter fields grill_status / grill_date / grill_coverage"
}

# (3) X1/X5 LOAD-BEARING NEGATIVE PIN — the entire structural protection for the §3.5.1
# anti-creep-to-mandatory boundary. The canonical `*_audit_evidence` degraded predicate
# (§3.5b) AND the Status-mode degraded render in skills/feature/SKILL.md MUST NOT reference
# any grill field: grill_status: skipped is non-degraded (grill is optional) and lives under
# a DIFFERENT key, so letting grill_status / grill_coverage leak into the degraded predicate
# or the Status-mode render would slide grill toward de-facto-mandatory.
#
# REGION-SCOPED, NOT file-wide. grill_status legitimately appears elsewhere in SKILL.md (the
# Step-2 grill gate section + the §3.5 grill-aware Pass 2 prose), so a file-wide forbidden-form
# grep would FALSE-FAIL. Extract the `## Status mode` region and the `### 3.5b` region with the
# same awk idiom as check_skill_renderer_evidence_flag_wired / check_skill_legacy_null_reader_
# semantics, then assert grill_status / grill_coverage are ABSENT from each. Each region is
# anchored on a known degraded-predicate literal FIRST, so a broken extraction (empty region)
# FAILS the pin rather than vacuously passing the negative assertion.
check_skill_degraded_predicate_no_grill() {
  local f='skills/feature/SKILL.md'
  test -f "$f" || { echo "$f missing"; return 1; }
  local status_region b35_region
  status_region=$(awk '/^## Status mode/{flag=1; next} flag && /^## /{exit} flag' "$f")
  b35_region=$(awk '/^### 3\.5b/{flag=1; next} flag && /^### / {exit} flag' "$f")
  # Anchor: each region must actually contain its degraded-predicate surface, else the
  # negative assertions below would vacuously pass on a broken extraction.
  printf '%s' "$status_region" | grep -qF '*_audit_evidence' \
    || { echo "Status-mode region empty / anchor missing — cannot region-scope grill-absence check"; return 1; }
  printf '%s' "$b35_region" | grep -qF '∈ {single_model, self_fallback, contract_violated, skipped}' \
    || { echo "§3.5b region empty / degraded-predicate missing — cannot region-scope grill-absence check"; return 1; }
  # NEGATIVE: no grill field inside either degraded-predicate surface.
  if printf '%s' "$status_region" | grep -qE 'grill_status|grill_coverage'; then
    echo "Status-mode degraded render references a grill field (grill_status/grill_coverage) — grill MUST NOT enter the degraded predicate (§3.5.1 anti-creep)"
    return 1
  fi
  if printf '%s' "$b35_region" | grep -qE 'grill_status|grill_coverage'; then
    echo "§3.5b degraded predicate references a grill field (grill_status/grill_coverage) — grill MUST NOT enter the degraded predicate (§3.5.1 anti-creep)"
    return 1
  fi
  echo "SKILL.md degraded predicate (§3.5b) + Status-mode render reference no grill field (region-scoped; grill_status legit elsewhere)"
}

# --- Grill mode handler + skipped write-path (X1/X2 code-audit fix on 2026-06-29-grill-feature-gate) ---
# Structure floor for the standalone `## Grill mode` H2 handler (X1) and the
# grill_status: skipped explicit-decline write path (X2) in skills/feature/SKILL.md.

# (X1) A `## Grill mode` H2 handler section exists and names the load-bearing
# standalone-dispatch contract: spec resolution + the DRAFT-only precondition.
# (X3) The precondition is a non-DRAFT CATCH-ALL ("any other status -> refuse"),
# NOT a brittle enumerated refuse-list — so BLOCKED and any future enum value route
# to a defined refuse path. Region-extracted (header -> next REAL `## ` handler),
# NOT file-wide, since `grill` prose lives all over SKILL.md. The exit guard skips
# the inline `## ⏸ AWAITING YOUR INPUT` banner (it sits between the header and the
# step-3 precondition), so the region covers the whole handler incl. step 3. Catches
# a regression that drops the standalone handler (leaving `/feature grill [spec-path]`
# dispatch undefined) OR that reverts the precondition to an enumerated list (leaving
# non-listed statuses like BLOCKED undefined).
check_skill_grill_mode_handler_exists() {
  local f='skills/feature/SKILL.md'
  test -f "$f" || { echo "$f missing"; return 1; }
  grep -qxF '## Grill mode' "$f" \
    || { echo "SKILL.md missing '## Grill mode' H2 handler section (X1)"; return 1; }
  local region
  region=$(awk '/^## Grill mode/{flag=1; next} flag && /^## / && !/AWAITING YOUR INPUT/{exit} flag' "$f")
  printf '%s\n' "$region" | grep -qiF 'resolve the target spec' \
    || { echo "SKILL.md '## Grill mode' handler does not name spec resolution"; return 1; }
  printf '%s\n' "$region" | grep -qF 'DRAFT' \
    || { echo "SKILL.md '## Grill mode' handler does not name the DRAFT precondition"; return 1; }
  printf '%s\n' "$region" | grep -qiE 'any other status.*refuse' \
    || { echo "SKILL.md '## Grill mode' precondition is not a non-DRAFT catch-all (expected 'any other status ... refuse', not an enumerated refuse-list — BLOCKED/future enum would fall through) (X3)"; return 1; }
  echo "SKILL.md '## Grill mode' H2 handler present (names spec resolution + DRAFT precondition; non-DRAFT catch-all refusal)"
}

# (X2) The `### Grill gate` section ties grill_status: skipped to the EXPLICIT-DECLINE
# path AND states the orchestrator actually WRITES it (the framing was orphaned: it
# said "skipped when not run" but no step wrote the value). Region-scoped to the
# `### Grill gate` section (header -> next `### `), since grill_status appears elsewhere.
# Catches a regression back to the orphaned "skipped when not run" framing.
check_skill_grill_status_skipped_write_path() {
  local f='skills/feature/SKILL.md'
  test -f "$f" || { echo "$f missing"; return 1; }
  local section
  section=$(awk '/^### Grill gate/{cap=1;print;next} cap&&/^### /{exit} cap{print}' "$f")
  [ -n "$section" ] || { echo "SKILL.md missing '### Grill gate' section for skipped write-path pin"; return 1; }
  printf '%s\n' "$section" | grep -qF 'explicit-decline' \
    || { echo "SKILL.md grill gate does not tie grill_status: skipped to the explicit-decline path (X2)"; return 1; }
  printf '%s\n' "$section" | grep -qF 'writes `grill_status: skipped`' \
    || { echo "SKILL.md grill gate does not state the orchestrator WRITES grill_status: skipped on decline (X2)"; return 1; }
  echo "SKILL.md grill gate ties grill_status: skipped to the explicit-decline write path"
}
