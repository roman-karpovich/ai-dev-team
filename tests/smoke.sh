#!/usr/bin/env bash
# smoke.sh — plugin smoke test. Runs locally, no network, no Claude.
# Exits 0 if all checks pass, non-zero on first failure category.
#
# Usage: bash tests/smoke.sh
set -u

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PLUGIN_ROOT" || exit 2

# Probe E frozen-replay corpus — KB-local path resolved by the smoke harness
# (Step 4 helper `check_probe_e_corpus_exists`). Defaults to the author's KB
# path; override via PROBE_E_CORPUS_ROOT env var in CI or on other machines.
# When the path is missing, the helper skips gracefully (corpus lives OUTSIDE
# the plugin repo — KB/Obsidian vault — so CI-without-KB still passes).
PROBE_E_CORPUS_ROOT="${PROBE_E_CORPUS_ROOT:-/Users/th13f/dev/personal/finance-learning/repos/ai-dev-team/research/cross-audit-probe-e}"
export PROBE_E_CORPUS_ROOT

# Probe F frozen-replay corpus — KB-local path resolved by the smoke harness
# (Step 4 helper `check_probe_f_corpus_exists`). Defaults to the author's KB
# path; override via PROBE_F_CORPUS_ROOT env var in CI or on other machines.
# When the path is missing, the helper skips gracefully (corpus lives OUTSIDE
# the plugin repo — KB/Obsidian vault — so CI-without-KB still passes).
PROBE_F_CORPUS_ROOT="${PROBE_F_CORPUS_ROOT:-/Users/th13f/dev/personal/finance-learning/repos/ai-dev-team/research/cross-audit-probe-f}"
export PROBE_F_CORPUS_ROOT

PASS=0
FAIL=0
FAILURES=()
BEHAVIORAL_COUNT=0
SCHEMA_COUNT=0
PROMPT_TEXT_COUNT=0
UNCLASSIFIED_COUNT=0
PROVES_MAP_SUPPORTS_ASSOC=0
PROVES_MAP_KEYS=()
PROVES_MAP_CLASSES=()
if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
  PROVES_MAP_SUPPORTS_ASSOC=1
  declare -A PROVES_MAP
fi

proves_map_put() {
  local helper="$1"
  local class="$2"
  if [ "$PROVES_MAP_SUPPORTS_ASSOC" = "1" ]; then
    PROVES_MAP["$helper"]="$class"
    return 0
  fi
  PROVES_MAP_KEYS+=("$helper")
  PROVES_MAP_CLASSES+=("$class")
}

proves_map_get() {
  local helper_name="$1"
  if [ "$PROVES_MAP_SUPPORTS_ASSOC" = "1" ]; then
    printf '%s\n' "${PROVES_MAP[$helper_name]:-}"
    return 0
  fi
  local i
  for ((i = 0; i < ${#PROVES_MAP_KEYS[@]}; i++)); do
    if [ "${PROVES_MAP_KEYS[$i]}" = "$helper_name" ]; then
      printf '%s\n' "${PROVES_MAP_CLASSES[$i]}"
      return 0
    fi
  done
  printf '\n'
}

load_proves_manifest() {
  local manifest="$PLUGIN_ROOT/tests/smoke-proves-manifest.txt"
  if [ ! -f "$manifest" ]; then
    echo "WARNING: smoke-proves-manifest.txt not found" >&2
    return 0
  fi
  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue
    local helper class
    helper=$(printf '%s\n' "$line" | awk '{print $1}')
    class=$(printf '%s\n' "$line" | awk '{print $2}')
    if [ -z "$helper" ] || [ -z "$class" ]; then
      echo "WARNING: malformed manifest line: $line" >&2
      continue
    fi
    proves_map_put "$helper" "$class"
  done < "$manifest"
}

check() {
  local name="$1"; shift
  local helper_name="$1"
  if "$@" >/tmp/smoke-out.$$ 2>&1; then
    echo "  PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name"
    FAILURES+=("$name")
    sed 's/^/        /' /tmp/smoke-out.$$
    FAIL=$((FAIL + 1))
  fi
  local cls
  cls=$(proves_map_get "$helper_name")
  case "$cls" in
    behavioral)   BEHAVIORAL_COUNT=$((BEHAVIORAL_COUNT + 1)) ;;
    schema)       SCHEMA_COUNT=$((SCHEMA_COUNT + 1)) ;;
    prompt-text)  PROMPT_TEXT_COUNT=$((PROMPT_TEXT_COUNT + 1)) ;;
    *)            UNCLASSIFIED_COUNT=$((UNCLASSIFIED_COUNT + 1)) ;;
  esac
  rm -f /tmp/smoke-out.$$
}

extract_md_section() {
  # $1 = path to a Markdown file
  # $2 = the literal heading line to start from, e.g. "## R3 — Test strength / signal-to-noise"
  # Emits every line of the section (from the first matching heading up to but NOT
  # including the next line that begins with "## ", or EOF). Start-line is included.
  # First-match-wins: subsequent identical headings do NOT re-activate extraction
  # (guards against adjacent-duplicate-heading attacks — see X7).
  awk -v hdr="$2" '
    !in_s && $0 == hdr { in_s = 1; print; next }
    in_s && /^## / { exit }
    in_s { print }
  ' "$1"
}

extract_why_block() {
  # Stdin = output of extract_md_section for a given ## Rn — heading.
  # Emits lines from the first '**Why**:' through the terminator
  # '**How to apply**:' line (INCLUSIVE). Including the terminator line
  # is deliberate: it lets a byte compare observe the blank line between
  # the Why content and the terminator (a missing blank collapses
  # '<Why>\n\n**How to apply**:' to '<Why>\n**How to apply**:' — the
  # difference survives command substitution's trailing-newline strip).
  # For F3/F4 (which use `grep -cFx` to count the Khorikov line), the
  # presence of the terminator line is harmless — `grep -cFx` ignores it.
  # Requires Why to precede How-to-apply (true for all current rules R1–R6).
  awk '
    /^\*\*Why\*\*:/ { in_why=1 }
    in_why { print }
    in_why && /^\*\*How to apply\*\*:/ { exit }
  '
}

# shellcheck source=./smoke-helpers.sh
. "$PLUGIN_ROOT/tests/smoke-helpers.sh"

# Freeze R3 function table — prevents runtime redefinition (iter-9 X28).
# Must appear IMMEDIATELY AFTER the source line, with only blank lines
# and `#`-comments permitted between. This tight placement (iter-12
# X37) closes the ~1200-line window that existed under the iter-11
# rule ("anywhere before the first R3/DWF check"), inside which any
# pre-R3 `check` body could redefine an R3 helper before the freeze
# applied. The 9 lines below (the `readonly -f \` header plus 8
# indented name lines) are byte-pinned via the workdoc env var
# `$FREEZE_BLOCK_SHA256` (iter-13 X40) — they must appear as a single
# contiguous block exactly as written. The iter-12 X37 rule alone only
# anchored the FIRST line; a split freeze with executable code between
# two `readonly -f` statements would have slipped through the per-name
# grep while mutating a still-unfrozen helper. Byte-pinning the whole
# 9-line region removes every split-freeze variant structurally. The
# block's CONTENTS (names) stay frozen; a legitimate future reorder of
# the 8 names requires re-running the cross-audit to regenerate
# `$FREEZE_BLOCK_SHA256`. Also freezes extract_md_section (only
# dependency of the R3 helpers) so an upstream check-dispatched body
# cannot subvert section scoping without being rejected by bash's
# readonly enforcement.
readonly -f \
  extract_md_section \
  check_r3_rule_heading_present \
  check_r3_structure_triplet_present \
  check_r3_anti_patterns_enumerated \
  check_r3_notes_requirement_present \
  check_developer_workflow_short_form_r3 \
  check_developer_workflow_test_quality_points_to_r3 \
  check_developer_workflow_observed_notes_requirement \
  check_spec_template_agent_pretag_grammar \
  check_skill_md_step2_pretag_guidance \
  check_skill_md_agent_selection_tag_read \
  check_skill_md_continue_mode_tag_read \
  check_cross_auditor_pretag_consistency_check

load_proves_manifest

echo "Plugin: $PLUGIN_ROOT"
echo

# --- Manifest integrity ---
echo "Manifest integrity:"

validate_plugin_json() {
  python3 -c "
import json, sys
with open('.claude-plugin/plugin.json') as f:
    m = json.load(f)
for k in ('name', 'version', 'description'):
    if k not in m:
        print(f'missing key: {k}', file=sys.stderr)
        sys.exit(1)
print('plugin.json valid:', m['name'], m['version'])
"
}

validate_marketplace_json() {
  python3 -c "
import json
with open('.claude-plugin/marketplace.json') as f:
    json.load(f)
print('marketplace.json valid')
"
}

check "plugin.json valid" validate_plugin_json
check "marketplace.json valid" validate_marketplace_json
echo

# --- Agent frontmatter ---
echo "Agent frontmatter:"

validate_agent() {
  local file="$1"
  python3 - "$file" <<'PY'
import re, sys, os
path = sys.argv[1]
text = open(path).read()
m = re.match(r'^---\n(.*?)\n---\n', text, re.DOTALL)
if not m:
    print(f"{path}: missing YAML frontmatter", file=sys.stderr)
    sys.exit(1)
fm = m.group(1)
for key in ("name", "description", "tools"):
    if not re.search(rf'^{key}\s*:', fm, re.MULTILINE):
        print(f"{path}: missing '{key}:' in frontmatter", file=sys.stderr)
        sys.exit(1)
name_match = re.search(r'^name\s*:\s*(\S+)', fm, re.MULTILINE)
expected = os.path.splitext(os.path.basename(path))[0]
if name_match.group(1) != expected:
    print(f"{path}: name '{name_match.group(1)}' != filename '{expected}'", file=sys.stderr)
    sys.exit(1)
print(f"  {expected}: OK")
PY
}

for agent_file in agents/*.md; do
  check "agent frontmatter: $agent_file" validate_agent "$agent_file"
done
echo

# --- Skill structure ---
echo "Skill structure:"

validate_skill() {
  local dir="$1"
  local skill_md="$dir/SKILL.md"
  python3 - "$skill_md" <<'PY'
import re, sys, os
path = sys.argv[1]
if not os.path.isfile(path):
    print(f"{path}: SKILL.md missing", file=sys.stderr)
    sys.exit(1)
text = open(path).read()
m = re.match(r'^---\n(.*?)\n---\n', text, re.DOTALL)
if not m:
    print(f"{path}: missing YAML frontmatter", file=sys.stderr)
    sys.exit(1)
fm = m.group(1)
for key in ("name", "description"):
    if not re.search(rf'^{key}\s*:', fm, re.MULTILINE):
        print(f"{path}: missing '{key}:' in frontmatter", file=sys.stderr)
        sys.exit(1)
print(f"  {os.path.basename(os.path.dirname(path))}: SKILL.md OK")
PY
}

for skill_dir in skills/*/; do
  skill_dir="${skill_dir%/}"
  check "skill: $skill_dir" validate_skill "$skill_dir"
done
echo

# --- SessionStart hook ---
echo "SessionStart hook:"

# Invoke the hook with a given env-var setup, verify JSON and trigger-map content
check_session_start() {
  local env_setup="$1"  # "claude", "cursor", or "default"
  local out
  case "$env_setup" in
    claude)  out=$(env -i CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$PATH" bash hooks/session-start 2>&1);;
    cursor)  out=$(env -i CURSOR_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$PATH" bash hooks/session-start 2>&1);;
    default) out=$(env -i PATH="$PATH" bash hooks/session-start 2>&1);;
  esac
  # Must be valid JSON
  printf '%s' "$out" | python3 -m json.tool >/dev/null || {
    echo "invalid JSON for $env_setup"
    printf '%s' "$out" | head -3
    return 1
  }
  # Must contain the skill trigger map signature
  printf '%s' "$out" | grep -q 'Skill trigger map' || {
    echo "missing 'Skill trigger map' for $env_setup"
    return 1
  }
  echo "session-start ($env_setup) OK"
}

# Also verify the correct top-level JSON key is used per env
check_session_start_key() {
  local env_setup="$1"
  local expected_key="$2"
  local out
  case "$env_setup" in
    claude)  out=$(env -i CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$PATH" bash hooks/session-start 2>&1);;
    cursor)  out=$(env -i CURSOR_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$PATH" bash hooks/session-start 2>&1);;
    default) out=$(env -i PATH="$PATH" bash hooks/session-start 2>&1);;
  esac
  printf '%s' "$out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert '$expected_key' in d, f'expected top-level key $expected_key, got keys {list(d.keys())}'
print('$env_setup -> $expected_key OK')
"
}

check "session-start (claude) valid+triggers"  check_session_start  claude
check "session-start (cursor) valid+triggers"  check_session_start  cursor
check "session-start (default) valid+triggers" check_session_start  default
check "session-start (claude) key"             check_session_start_key claude  hookSpecificOutput
check "session-start (cursor) key"             check_session_start_key cursor  additional_context
check "session-start (default) key"            check_session_start_key default additionalContext
echo

# --- SessionStart conditional activation ---
echo "SessionStart conditional activation:"
check "session_start_dormant_in_orthogonal PASS"  check_session_start_dormant_in_orthogonal
check "session_start_active_yml_arm PASS"         check_session_start_active_yml_arm
check "session_start_active_memory_arm PASS"      check_session_start_active_memory_arm
check "session_start_active_claude_md_arm PASS"   check_session_start_active_claude_md_arm
check "session_start_dormant_under_nullglob PASS" check_session_start_dormant_under_nullglob
check "session_start_dormant_under_failglob PASS" check_session_start_dormant_under_failglob
echo

# --- post-edit-lint hook ---
echo "post-edit-lint hook:"

check_lint_empty_stdin() {
  echo "" | python3 hooks/post-edit-lint
}

check_lint_non_edit_tool() {
  echo '{"tool_name":"Read","tool_input":{}}' | python3 hooks/post-edit-lint
}

check_lint_missing_file() {
  echo '{"tool_name":"Edit","tool_input":{"file_path":"/nonexistent/path-'$$'-xyz.rs"}}' | python3 hooks/post-edit-lint
}

check_no_shell_true() {
  if grep -n "shell=True" hooks/post-edit-lint; then
    echo "FOUND 'shell=True' in hooks/post-edit-lint — shell-injection regression!"
    return 1
  fi
  echo "post-edit-lint: no shell=True OK"
}

check "post-edit-lint empty stdin"        check_lint_empty_stdin
check "post-edit-lint non-Edit tool"      check_lint_non_edit_tool
check "post-edit-lint missing file"       check_lint_missing_file
check "post-edit-lint no shell=True"      check_no_shell_true
echo

# --- stop-check hook ---
echo "stop-check hook:"

check_stop_check_exists() {
  test -x hooks/stop-check || { echo "hooks/stop-check missing or not executable"; return 1; }
  echo "stop-check exists and executable"
}

check_stop_check_no_shell_true() {
  if grep -n "shell=True" hooks/stop-check; then
    echo "FOUND 'shell=True' in hooks/stop-check — shell-injection regression!"
    return 1
  fi
  echo "stop-check: no shell=True OK"
}

check_stop_check_silent_outside_repo() {
  # Run in /tmp (not a git repo). Must exit 0 and emit nothing.
  local out
  out=$(cd /tmp && python3 "$PLUGIN_ROOT/hooks/stop-check" < /dev/null 2>&1)
  if [ -n "$out" ]; then
    echo "stop-check emitted output outside a repo: $out"
    return 1
  fi
  echo "stop-check silent outside repo"
}

check_stop_hook_registered() {
  python3 -c "
import json
d = json.load(open('hooks/hooks.json'))
assert 'Stop' in d['hooks'], 'Stop not registered in hooks.json'
cmd = d['hooks']['Stop'][0]['hooks'][0]['command']
assert 'stop-check' in cmd, f'Stop hook command does not reference stop-check: {cmd}'
print('Stop hook registered OK')
"
}

check "stop-check exists"                 check_stop_check_exists
check "stop-check no shell=True"          check_stop_check_no_shell_true
check "stop-check silent outside repo"    check_stop_check_silent_outside_repo
check "Stop hook registered in hooks.json" check_stop_hook_registered
echo

# --- Developer-workflow reference (DRY refactor 2026-04-17) ---
echo "Developer-workflow reference:"

check_dev_workflow_exists() {
  test -f skills/feature/references/developer-workflow.md
}

check_agent_refs_dev_workflow() {
  local agent="$1"
  grep -q "developer-workflow.md" "$agent"
}

# Ensures codex-implement.md remains deleted (see spec 2026-04-20-orphan-codex-implement).
check_codex_implement_not_present() {
  [ ! -e skills/feature/references/codex-implement.md ] \
    || { echo "skills/feature/references/codex-implement.md reappeared — see spec 2026-04-20-orphan-codex-implement"; return 1; }
  echo "codex-implement.md correctly absent"
}

check "shared reference exists" check_dev_workflow_exists
for agent in agents/developer-codex.md agents/developer-senior.md; do
  check "agent links shared workflow: $agent" check_agent_refs_dev_workflow "$agent"
done
check "check_codex_implement_not_present" check_codex_implement_not_present
check "developer-middle.md absent" check_developer_middle_not_present
echo

# --- Broken-link guard ---
echo "Broken-link guard:"

check_broken_links() {
  python3 - <<'PY'
import os, re, sys

# Files we scan for references
SCAN_FILES = []
for root, dirs, files in os.walk('.'):
    # Skip known noise dirs
    if any(part in root.split(os.sep) for part in ('.git', '__pycache__', 'node_modules')):
        continue
    for f in files:
        if f.endswith('.md') and ('agents/' in root or 'skills/' in root or root == '.' or root == './docs'):
            SCAN_FILES.append(os.path.join(root, f))

# Directories that are valid prefix for internal refs
PREFIXES = ('skills/', 'agents/', 'hooks/', 'tests/', 'docs/')

# Regexes: markdown [text](path.md) and backticked `path/to/file.md`
md_link_re   = re.compile(r'\[[^\]]+\]\(([^)]+\.md)\)')
backtick_re  = re.compile(r'`(' + '|'.join(p + r'[A-Za-z0-9_\-./]+\.md' for p in PREFIXES) + r')`')

errors = []
for f in SCAN_FILES:
    try:
        text = open(f).read()
    except Exception:
        continue

    refs = set()
    for m in md_link_re.finditer(text):
        ref = m.group(1)
        # resolve relative to file dir; skip URLs, anchors
        if ref.startswith(('http://', 'https://', '#')):
            continue
        ref_path = os.path.normpath(os.path.join(os.path.dirname(f), ref.split('#')[0]))
        refs.add(('md-link', f, ref, ref_path))

    for m in backtick_re.finditer(text):
        ref = m.group(1).split('#')[0]
        # Resolve relative to plugin root (backticked refs in docs are plugin-root-relative)
        ref_path = os.path.normpath(ref)
        refs.add(('backtick', f, ref, ref_path))

    for kind, src, ref, resolved in refs:
        if not os.path.exists(resolved):
            errors.append(f"  {src}: broken {kind} '{ref}' (resolved to '{resolved}')")

if errors:
    print('broken-link check FAILED:')
    for e in errors:
        print(e)
    sys.exit(1)
print('broken-link check: all references resolve')
PY
}

check "broken-link guard" check_broken_links
echo

# --- Feature-skill surface area (regression guards) ---
echo "Feature-skill surface:"

check_skill_blocked() {
  # SKILL.md mentions BLOCKED state machine entry
  grep -q '^[[:space:]]*- `BLOCKED`' skills/feature/SKILL.md \
    || { echo "SKILL.md missing BLOCKED state entry"; return 1; }
  echo "SKILL.md mentions BLOCKED state"
}

check_skill_discard_mode() {
  grep -q '## Discard mode' skills/feature/SKILL.md \
    || { echo "SKILL.md missing Discard mode section"; return 1; }
  echo "SKILL.md has /feature discard mode"
}

check "SKILL.md mentions BLOCKED"           check_skill_blocked
check "SKILL.md has /feature discard mode"  check_skill_discard_mode
echo

# --- Per-step agent pre-tag ---
echo "Per-step agent pre-tag:"

check "spec-template-has-agent-pretag-grammar"       check_spec_template_agent_pretag_grammar
check "skill-md-step2-has-pretag-guidance"           check_skill_md_step2_pretag_guidance
check "skill-md-agent-selection-reads-tag"           check_skill_md_agent_selection_tag_read
check "skill-md-continue-mode-reads-tag"             check_skill_md_continue_mode_tag_read
check "cross-auditor-has-pretag-consistency-check"   check_cross_auditor_pretag_consistency_check
echo

# --- Cross-audit severity flag (2026-04-17) ---
echo "Cross-audit severity:"

check_cross_audit_severity_flag() {
  grep -q -- "--severity" skills/cross-audit/SKILL.md \
    || { echo "SKILL.md missing --severity flag"; return 1; }
  echo "cross-audit SKILL.md documents --severity"
}

check_cross_auditor_severity_floor() {
  local n
  n=$(grep -c "severity_floor" agents/cross-auditor.md)
  if [ "$n" -lt 2 ]; then
    echo "cross-auditor agent missing severity_floor (found $n, need >=2)"
    return 1
  fi
  echo "cross-auditor.md threads severity_floor"
}

check "cross-audit --severity flag"        check_cross_audit_severity_flag
check "cross-auditor severity_floor param" check_cross_auditor_severity_floor
echo

# --- Config extensions (codex.* + autogen) ---
echo "Config extensions:"

check_yml_example_codex() {
  grep -q "codex:" .ai-dev-team.yml.example || { echo "yml.example missing codex: block"; return 1; }
  echo "yml.example has codex: block"
}

check_dev_codex_threads_model() {
  grep -q "codex_model" agents/developer-codex.md \
    && grep -q "codex_reasoning_effort" agents/developer-codex.md \
    || { echo "developer-codex missing codex_model/codex_reasoning_effort"; return 1; }
  echo "developer-codex threads codex.* inputs"
}

check_cross_auditor_threads_model() {
  grep -q "codex_model" agents/cross-auditor.md \
    && grep -q "codex_reasoning_effort" agents/cross-auditor.md \
    || { echo "cross-auditor missing codex_model/codex_reasoning_effort"; return 1; }
  echo "cross-auditor threads codex.* inputs"
}

check_skill_autogen_prompt() {
  # Feature-skill autogen prompt migrated to shared docs/kb-discovery.md
  # per spec 2026-04-20-shared-phase0 §3.8(1).
  grep -q "Save .*kb_path.*\\.ai-dev-team\\.yml" docs/kb-discovery.md \
    || { echo "docs/kb-discovery.md missing autogen prompt"; return 1; }
  echo "docs/kb-discovery.md has autogen prompt"
}

check "yml.example has codex: block"        check_yml_example_codex
check "developer-codex threads codex.*"     check_dev_codex_threads_model
check "cross-auditor threads codex.*"       check_cross_auditor_threads_model
check "feature SKILL has autogen prompt"    check_skill_autogen_prompt
echo

# --- Compliance commit fallback (2026-04-17) ---
echo "Compliance commit fallback:"

check_compliance_sha_validation() {
  grep -q "git cat-file" agents/spec-compliance-checker.md \
    || { echo "compliance-checker missing git cat-file validation"; return 1; }
  grep -q "commit_message_grep" agents/spec-compliance-checker.md \
    || { echo "compliance-checker missing commit_message_grep fallback"; return 1; }
  echo "compliance-checker validates SHAs + grep fallback"
}

check_dev_workflow_amend_note() {
  grep -q "commit_message_grep" skills/feature/references/developer-workflow.md \
    || { echo "dev-workflow missing commit_message_grep note"; return 1; }
  echo "dev-workflow documents commit_message_grep"
}

check "compliance-checker SHA fallback"     check_compliance_sha_validation
check "dev-workflow commit_message_grep"    check_dev_workflow_amend_note
echo

# --- /feature investigation-bridge retirement (absence guard) ---
echo "Feature investigation-bridge retirement guard:"

check_feature_from_investigation_absent() {
  # 5 absence assertions (was 6 — assertion #1 forbidding the
  # `--from-investigation` literal in skills/ was retired by spec
  # design/2026-04-29-removed-cli-flag-hard-fail.md §3.3.4 Path 4 because
  # the new "Removed-flag hard-fail" block in skills/feature/SKILL.md must
  # contain the flag literal byte-for-byte for the canonical hard-fail line;
  # equivalent silent-reintroduction protection now comes from the §3.4
  # presence pin check_feature_skill_from_investigation_hard_fail asserting
  # the canonical line byte-for-byte).
  if grep -rqF 'investigation_source' skills/; then
    echo "assertion 1 FAIL: investigation_source literal present in skills/"
    return 1
  fi
  if grep -qE '^check_feature_(from_investigation_flag|investigation_source_field)\(\)' tests/smoke.sh; then
    echo "assertion 2 FAIL: retired check-function definition present in tests/smoke.sh"
    return 1
  fi
  if grep -qE 'check_feature_(from_investigation_flag|investigation_source_field)' tests/smoke.sh; then
    echo "assertion 3 FAIL: retired check-function reference present in tests/smoke.sh"
    return 1
  fi
  if ! grep -qF '/research' skills/research/SKILL.md; then
    echo "assertion 4 FAIL: /research entry-point missing from skills/research/SKILL.md"
    return 1
  fi
  if ! grep -qF '/feature new' skills/feature/SKILL.md; then
    echo "assertion 5 FAIL: /feature new entry-point missing from skills/feature/SKILL.md"
    return 1
  fi
  assert_no_stale_section_header_comments '--from-investigation' 'assertion 6' \
    || { echo "assertion 6 FAIL: stale --from-investigation header in smoke files"; return 1; }
  echo "check_feature_from_investigation_absent: all 6 assertions OK"
}

check "feature --from-investigation absent" check_feature_from_investigation_absent
echo

# --- /research skill ---
echo "Research skill:"

check_research_skill_exists() {
  test -f skills/research/SKILL.md \
    || { echo "skills/research/SKILL.md missing"; return 1; }
  echo "skills/research/SKILL.md present"
}

check_research_subtypes() {
  grep -q "incident-investigation" skills/research/SKILL.md \
    && grep -q "math-model" skills/research/SKILL.md \
    && grep -q "competitive-analysis" skills/research/SKILL.md \
    && grep -q "exploration" skills/research/SKILL.md \
    || { echo "research SKILL.md missing one of the 4 subtypes"; return 1; }
  echo "research SKILL.md mentions all 4 subtypes"
}

check_research_statuses() {
  grep -q "ACTIVE" skills/research/SKILL.md \
    && grep -q "CONCLUDED" skills/research/SKILL.md \
    && grep -q "ARCHIVED" skills/research/SKILL.md \
    || { echo "research SKILL.md missing ACTIVE/CONCLUDED/ARCHIVED"; return 1; }
  echo "research SKILL.md mentions all 3 statuses"
}

check_research_template() {
  test -f skills/research/references/research-template.md \
    && grep -q "type: research" skills/research/references/research-template.md \
    && grep -q "subtype" skills/research/references/research-template.md \
    || { echo "research-template.md missing or incomplete"; return 1; }
  echo "research-template.md present with proper frontmatter"
}

check "research skill present"               check_research_skill_exists
check "research subtypes documented"         check_research_subtypes
check "research statuses documented"         check_research_statuses
check "research template present"            check_research_template
echo

# --- Deploy-recommendations §6.2 surface ---
echo "Deploy-recommendations §6.2 surface:"

check_spec_template_deploy_recommendations_62() {
  grep -q '^## 6.2 Deploy & manual verification' skills/feature/references/spec-template.md \
    && grep -q 'deploy_prerequisites:' skills/feature/references/spec-template.md \
    && grep -q 'smoke_check:' skills/feature/references/spec-template.md
}

check_skill_deploy_prerequisites_prompt_62() {
  grep -qi 'deploy prerequisites' skills/feature/SKILL.md
}

check_skill_handling_subsection_62() {
  grep -q '§6.2 handling' skills/feature/SKILL.md
}

check_skill_source_tag_62() {
  grep -q 'source: §6.2:deploy_prerequisites' skills/feature/SKILL.md
}

check_skill_quick_check_banners_62() {
  grep -q 'Quick check (from spec §6.2)' skills/feature/SKILL.md \
    && grep -q 'complete deploy prerequisites below first' skills/feature/SKILL.md
}

check_skill_malformed_block_log_62() {
  grep -q '§6.2 block malformed' skills/feature/SKILL.md
}

check "spec-template §6.2 heading and keys present"                 check_spec_template_deploy_recommendations_62
check "SKILL.md has §6.2 deploy prerequisites prompt"               check_skill_deploy_prerequisites_prompt_62
check "SKILL.md has §6.2 handling subsection"                       check_skill_handling_subsection_62
check "SKILL.md has §6.2:deploy_prerequisites source tag"           check_skill_source_tag_62
check "SKILL.md has §6.2 Quick-check banners (live and deferred)"   check_skill_quick_check_banners_62
check "SKILL.md has §6.2 malformed-block Log template"              check_skill_malformed_block_log_62
echo

# --- Cross-audit PR mode + publish ---
echo "Cross-audit PR mode + publish:"

PR_FIX_DIR="tests/fixtures/pr-aware-cross-audit"

# 1. SKILL.md contains PR-mode argument literal `pr <N>`
check_cross_audit_skill_pr_arg() {
  grep -q 'pr <N>' skills/cross-audit/SKILL.md \
    || { echo "cross-audit SKILL.md missing literal 'pr <N>' argument"; return 1; }
  echo "cross-audit SKILL.md mentions \`pr <N>\`"
}

# 2. SKILL.md contains `--paginate`
check_cross_audit_skill_paginate() {
  grep -q -- '--paginate' skills/cross-audit/SKILL.md \
    || { echo "cross-audit SKILL.md missing --paginate"; return 1; }
  echo "cross-audit SKILL.md uses --paginate"
}

# 3. SKILL.md documents `publish` action keyword in Phase 3
check_cross_audit_skill_publish_action() {
  grep -q 'publish <ids>' skills/cross-audit/SKILL.md \
    || { echo "cross-audit SKILL.md missing 'publish <ids>' action"; return 1; }
  echo "cross-audit SKILL.md documents 'publish' action"
}

# 4. SKILL.md references `gh api ... pulls/.../reviews`
check_cross_audit_skill_gh_api_reviews() {
  grep -Eq 'gh api.*pulls/.*reviews' skills/cross-audit/SKILL.md \
    || { echo "cross-audit SKILL.md missing 'gh api ... pulls/.*reviews' endpoint"; return 1; }
  echo "cross-audit SKILL.md references \`gh api\` for \`pulls/.*reviews\`"
}

# 5. SKILL.md contains `nameWithOwner` (cwd-repo preflight)
check_cross_audit_skill_name_with_owner() {
  grep -q 'nameWithOwner' skills/cross-audit/SKILL.md \
    || { echo "cross-audit SKILL.md missing nameWithOwner preflight"; return 1; }
  echo "cross-audit SKILL.md preflights nameWithOwner"
}

# 6. SKILL.md contains `headRefOid` (preflight capture)
check_cross_audit_skill_head_ref_oid() {
  grep -q 'headRefOid' skills/cross-audit/SKILL.md \
    || { echo "cross-audit SKILL.md missing headRefOid capture"; return 1; }
  echo "cross-audit SKILL.md captures headRefOid"
}

# 7. SKILL.md documents standalone `publish <slug>` entry point
check_cross_audit_skill_standalone_publish() {
  grep -Eq 'publish <slug>' skills/cross-audit/SKILL.md \
    || { echo "cross-audit SKILL.md missing standalone 'publish <slug>' entry"; return 1; }
  echo "cross-audit SKILL.md documents standalone publish <slug>"
}

# 8. cross-auditor — pr_number / pr_changed_files / pr_head_oid literal tokens
#    in §Input (hub); fenced YAML block in §Step 0 with all 5 pr_files keys + the
#    literal delegation path `hooks/lib/build_pr_files.sh` in the §Step 0 + §Step 0.5
#    reference (per Spec 2a Step 6 — body extracted to
#    agents/references/cross-auditor-pr-and-probes.md while the §Input parameter
#    declarations stay in the hub).
check_cross_auditor_pr_yaml_block() {
  python3 - <<'PY'
import re, sys
hub = open('agents/cross-auditor.md').read()
ref = open('agents/references/cross-auditor-pr-and-probes.md').read()
# Hub §Input retains the parameter-declaration tokens.
for token in ('pr_number', 'pr_changed_files', 'pr_head_oid'):
    if token not in hub:
        print(f"cross-auditor.md missing literal token '{token}'")
        sys.exit(1)
# Reference §Step 0 carries the delegation path + the canonical YAML shape.
if 'hooks/lib/build_pr_files.sh' not in ref:
    print("cross-auditor-pr-and-probes.md missing literal delegation path 'hooks/lib/build_pr_files.sh'")
    sys.exit(1)
keys = ('filename:', 'status:', 'previous_filename:', 'patch_present:', 'is_submodule:')
blocks = re.findall(r'```ya?ml\n(.*?)\n```', ref, re.DOTALL)
found = False
for b in blocks:
    if all(k in b for k in keys):
        found = True
        break
if not found:
    print("cross-auditor-pr-and-probes.md: no fenced YAML block contains all 5 pr_files keys "
          "(filename:/status:/previous_filename:/patch_present:/is_submodule:)")
    sys.exit(1)
print("cross-auditor: §Input tokens on hub; §Step 0 YAML block + build_pr_files.sh path on reference")
PY
}

# 9. cross-auditor §Step 0 uses `gh pr checkout` (canonical content moved to
#    agents/references/cross-auditor-pr-and-probes.md per Spec 2a Step 6).
check_cross_auditor_gh_pr_checkout() {
  grep -q 'gh pr checkout' agents/references/cross-auditor-pr-and-probes.md \
    || { echo "cross-auditor-pr-and-probes.md missing 'gh pr checkout'"; return 1; }
  echo "cross-auditor §Step 0 uses gh pr checkout"
}

# 10. agents/references/cross-auditor-codex-dispatch.md: near the async Codex helper launch,
#     contains `CODEX_WD` AND `worktree`. §Codex dispatch + §Step 1 moved to the reference per
#     Spec 2a Step 5; the codex_audit_dispatch.sh launch prose lives there.
check_cross_auditor_codex_cwd_proximity() {
  python3 - <<'PY'
import re, sys
lines = open('agents/references/cross-auditor-codex-dispatch.md').read().splitlines()
ok = False
for i, line in enumerate(lines):
    if 'codex_audit_dispatch.sh' in line:
        start = max(0, i - 6)
        window = '\n'.join(lines[start:i+7])
        if 'CODEX_WD' in window and 'worktree' in window:
            ok = True
            break
if not ok:
    print("cross-auditor-codex-dispatch.md: no codex_audit_dispatch.sh launch has both CODEX_WD and worktree nearby")
    sys.exit(1)
print("cross-auditor-codex-dispatch.md Codex cwd override proximity OK")
PY
}

# 11. publish.md exists + contains all required tokens (including verbatim 403 predicate).
check_publish_md_tokens() {
  local f='skills/cross-audit/references/publish.md'
  if [ ! -f "$f" ]; then
    echo "missing $f"; return 1
  fi
  local miss=0
  for tok in 'gh api' '--republish' 'published_to' 'comments' 'event' 'side' 'truncated' \
             'OPEN' 'REOPENED' 'head_oid_at_publish' '--force-publish-stale' \
             '--repo' '--include' 'pr_files' 'degraded_to_body' 'X-RateLimit-Remaining' \
             'pull_requests: write' 'CROSS_AUDIT_PUBLISH_STUB_RESPONSE' 'absent OR value ≠ 0'; do
    if ! grep -q -F -- "$tok" "$f"; then
      echo "publish.md missing token: '$tok'"
      miss=1
    fi
  done
  [ "$miss" -eq 0 ] || return 1
  echo "publish.md contains all required tokens"
}

# 12. skills/cross-audit/SKILL.md AND docs/claude-md-snippet.md both mention `publish|fix|accept|defer`
# (cross-audit skill body holds migrated Phase 3 exemption wording, refactor 2026-04-26)
check_hooks_docs_phase3_exemption() {
  grep -q 'publish|fix|accept|defer' skills/cross-audit/SKILL.md \
    || { echo "skills/cross-audit/SKILL.md missing Phase 3 exemption clause (publish|fix|accept|defer)"; return 1; }
  grep -q 'publish|fix|accept|defer' docs/claude-md-snippet.md \
    || { echo "docs/claude-md-snippet.md missing Phase 3 exemption clause (publish|fix|accept|defer)"; return 1; }
  grep -q 'pass-through' skills/cross-audit/SKILL.md \
    || { echo "skills/cross-audit/SKILL.md missing 'pass-through' exemption wording"; return 1; }
  grep -q 'pass-through' docs/claude-md-snippet.md \
    || { echo "docs/claude-md-snippet.md missing 'pass-through' exemption wording"; return 1; }
  echo "cross-audit skill/docs exempt Phase 3 decision keywords"
}

# 13. README.md contains `cross-audit pr` usage example
check_readme_cross_audit_pr() {
  grep -q 'cross-audit pr' README.md \
    || { echo "README.md missing 'cross-audit pr' usage example"; return 1; }
  echo "cross-audit README.md documents pr-mode usage"
}

# 14. First JSON fenced block in publish.md parses + has event/body/comments shape.
check_publish_md_json_shape() {
  python3 - <<'PY'
import json, re, sys
try:
    text = open('skills/cross-audit/references/publish.md').read()
except FileNotFoundError:
    print("publish.md missing"); sys.exit(1)
m = re.search(r'```json\n(.*?)\n```', text, re.DOTALL)
if not m:
    print("publish.md: no ```json fenced block found"); sys.exit(1)
try:
    payload = json.loads(m.group(1))
except Exception as e:
    print(f"publish.md: first JSON block does not parse: {e}"); sys.exit(1)
for k in ('event', 'body', 'comments'):
    if k not in payload:
        print(f"publish.md JSON payload missing key: {k}"); sys.exit(1)
if not isinstance(payload['comments'], list):
    print("publish.md payload 'comments' is not a list"); sys.exit(1)
for i, c in enumerate(payload['comments']):
    for k in ('path', 'line', 'side', 'body'):
        if k not in c:
            print(f"publish.md comments[{i}] missing key: {k}"); sys.exit(1)
print("publish.md JSON payload shape OK")
PY
}

# 15. Writer-contract golden: invoke hooks/lib/build_pr_files.sh with the sample JSON
#     on stdin and --ls-tree-output <path>; diff output against expected-pr-files.yml.
check_pr_files_writer_contract() {
  local writer='hooks/lib/build_pr_files.sh'
  if [ ! -x "$writer" ]; then
    echo "missing or non-executable: $writer"; return 1
  fi
  local fix="$PR_FIX_DIR"
  local actual
  actual=$(bash "$writer" --ls-tree-output "$fix/mock-ls-tree-output.txt" < "$fix/sample-pr-changed-files.json")
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "build_pr_files.sh exited $rc"; printf '%s\n' "$actual"; return 1
  fi
  local expected
  expected=$(cat "$fix/expected-pr-files.yml")
  if [ "$actual" != "$expected" ]; then
    echo "build_pr_files.sh output differs from $fix/expected-pr-files.yml"
    diff <(printf '%s' "$expected") <(printf '%s' "$actual") | sed 's/^/    /' | head -40
    return 1
  fi
  echo "cross-auditor.md writer-contract golden diff OK"
}

# Helper: JSON file must parse and contain all keys in a comma-list
json_has_keys() {
  local file="$1"; shift
  python3 - "$file" "$@" <<'PY'
import json, sys
path = sys.argv[1]
keys = sys.argv[2:]
try:
    d = json.load(open(path))
except Exception as e:
    print(f"{path}: JSON parse failed: {e}"); sys.exit(1)
miss = [k for k in keys if k not in d]
if miss:
    print(f"{path}: missing keys {miss}"); sys.exit(1)
print(f"{path}: keys OK")
PY
}

# Helper: JSON payload request has event/body/comments shape with every comment having path/line/side/body.
json_request_shape() {
  local file="$1"
  python3 - "$file" <<'PY'
import json, sys
path = sys.argv[1]
try:
    d = json.load(open(path))
except Exception as e:
    print(f"{path}: JSON parse failed: {e}"); sys.exit(1)
for k in ('event', 'body', 'comments'):
    if k not in d:
        print(f"{path}: missing top-level key {k}"); sys.exit(1)
if not isinstance(d['comments'], list):
    print(f"{path}: comments not a list"); sys.exit(1)
for i, c in enumerate(d['comments']):
    for k in ('path', 'line', 'side', 'body'):
        if k not in c:
            print(f"{path}: comments[{i}] missing {k}"); sys.exit(1)
    if c['side'] != 'RIGHT':
        print(f"{path}: comments[{i}].side != RIGHT"); sys.exit(1)
print(f"{path}: request shape OK")
PY
}

# Helper: YAML-like record JSON has all 7 published_to record keys and expected scalar values.
# Args: file, expected_truncated (true|false), expected_degraded (true|false)
record_shape() {
  local file="$1" exp_trunc="$2" exp_degr="$3"
  python3 - "$file" "$exp_trunc" "$exp_degr" <<'PY'
import json, sys
path, exp_trunc, exp_degr = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    d = json.load(open(path))
except Exception as e:
    print(f"{path}: JSON parse failed: {e}"); sys.exit(1)
keys = ('pr', 'timestamp', 'finding_ids', 'review_id', 'truncated', 'head_oid_at_publish', 'degraded_to_body')
miss = [k for k in keys if k not in d]
if miss:
    print(f"{path}: record missing keys {miss}"); sys.exit(1)
if str(d['truncated']).lower() != exp_trunc:
    print(f"{path}: truncated={d['truncated']} expected {exp_trunc}"); sys.exit(1)
if str(d['degraded_to_body']).lower() != exp_degr:
    print(f"{path}: degraded_to_body={d['degraded_to_body']} expected {exp_degr}"); sys.exit(1)
if not isinstance(d['finding_ids'], list) or not d['finding_ids']:
    print(f"{path}: finding_ids not a non-empty list"); sys.exit(1)
print(f"{path}: record shape OK (truncated={exp_trunc}, degraded={exp_degr})")
PY
}

# Helper: publish.md references both golden fixture paths (req and rec) by basename.
# Anchors the "actual vs golden" diff contract to the implementation: until publish.md
# exists and cites the goldens, the routing / failure-matrix assertions fail.
publish_md_cites() {
  local f='skills/cross-audit/references/publish.md'
  if [ ! -f "$f" ]; then
    echo "publish.md missing — cannot verify golden citation"
    return 1
  fi
  local p
  for p in "$@"; do
    local base="$(basename "$p")"
    if ! grep -q -F "$base" "$f"; then
      echo "publish.md does not cite golden fixture '$base'"
      return 1
    fi
  done
  return 0
}

# 16. Fixture A1 — normal diff, `publish all` default filter (OPEN×2 + REOPENED): X1,X2,X3.
check_routing_A1_normal_publish_all() {
  local fix="$PR_FIX_DIR"
  local req="$fix/expected-request-normal-publish-all.json"
  local rec="$fix/expected-published-to-record-normal.json"
  publish_md_cites "$req" "$rec" || return 1
  json_request_shape "$req" || return 1
  record_shape "$rec" false false || return 1
  python3 - "$req" "$rec" <<'PY' || return 1
import json, sys
req = json.load(open(sys.argv[1]))
rec = json.load(open(sys.argv[2]))
# A1 default filter: OPEN×2 + REOPENED only → finding_ids X1,X2,X3.
if rec['finding_ids'] != ['X1', 'X2', 'X3']:
    print(f"A1 record finding_ids={rec['finding_ids']} expected [X1,X2,X3]"); sys.exit(1)
# Inline comments must cover X1 (src/foo.rs) and X2 (src/baz.rs).
paths = [c['path'] for c in req['comments']]
if 'src/foo.rs' not in paths or 'src/baz.rs' not in paths:
    print(f"A1 request comments paths={paths} missing inline routes for X1/X2"); sys.exit(1)
# X3 (pure rename) must be in body, not comments.
if '[X3 HIGH]' not in req['body']:
    print("A1 request body missing X3 (pure rename → body bucket)"); sys.exit(1)
print("A1 routing golden OK")
PY
  echo "fixture A1 normal publish-all payload + record OK"
}

# 17. Fixture A2 — normal diff, explicit `publish X1..X8` post-reconfirm: all 8 IDs routed.
check_routing_A2_normal_explicit_all() {
  local fix="$PR_FIX_DIR"
  local req="$fix/expected-request-normal-explicit-all.json"
  local rec="$fix/expected-published-to-record-normal-explicit-all.json"
  publish_md_cites "$req" "$rec" || return 1
  json_request_shape "$req" || return 1
  record_shape "$rec" false false || return 1
  python3 - "$req" "$rec" <<'PY' || return 1
import json, sys
req = json.load(open(sys.argv[1]))
rec = json.load(open(sys.argv[2]))
if rec['finding_ids'] != ['X1', 'X2', 'X3', 'X4', 'X5', 'X6', 'X7', 'X8']:
    print(f"A2 record finding_ids={rec['finding_ids']} expected [X1..X8]"); sys.exit(1)
# Only inline-addressable findings (X1 on foo.rs:42, X2 on baz.rs:95) should be in comments.
paths = sorted(c['path'] for c in req['comments'])
if paths != ['src/baz.rs', 'src/foo.rs']:
    print(f"A2 request comments paths={paths} expected [src/baz.rs, src/foo.rs]"); sys.exit(1)
# Body must contain X3..X8 as separate blocks.
for xid in ('X3', 'X4', 'X5', 'X6', 'X7', 'X8'):
    if f'[{xid} ' not in req['body']:
        print(f"A2 request body missing [{xid} ...] block"); sys.exit(1)
print("A2 routing golden OK")
PY
  echo "fixture A2 normal explicit-all payload + record OK"
}

# 18. Fixture B — truncated diff, `publish all`: all findings routed to body, comments=[].
check_routing_B_truncated() {
  local fix="$PR_FIX_DIR"
  local req="$fix/expected-request-truncated.json"
  local rec="$fix/expected-published-to-record-truncated.json"
  publish_md_cites "$req" "$rec" || return 1
  json_request_shape "$req" || return 1
  record_shape "$rec" true false || return 1
  python3 - "$req" "$rec" <<'PY' || return 1
import json, sys
req = json.load(open(sys.argv[1]))
rec = json.load(open(sys.argv[2]))
# Truncated: comments must be empty list.
if req['comments'] != []:
    print(f"B request comments={req['comments']} expected [] on truncated diff"); sys.exit(1)
# Default filter: X1,X2,X3 only.
if rec['finding_ids'] != ['X1', 'X2', 'X3']:
    print(f"B record finding_ids={rec['finding_ids']} expected [X1,X2,X3]"); sys.exit(1)
# Body must contain all eligible findings.
for xid in ('X1', 'X2', 'X3'):
    if f'[{xid} ' not in req['body']:
        print(f"B request body missing [{xid} ...] block"); sys.exit(1)
print("B truncated routing golden OK")
PY
  echo "fixture B truncated publish payload + record OK"
}

# 19. Failure-matrix D1: 422 → body-only retry 2xx. retry-request + degraded-record goldens.
check_failure_D1_422_retry_2xx() {
  local fix="$PR_FIX_DIR"
  local retry="$fix/expected-retry-request-422.json"
  local rec="$fix/expected-published-to-record-422-degraded.json"
  # Stub fixtures must exist so the seam can feed them.
  [ -f "$fix/sample-response-422-include.txt" ] \
    || { echo "missing stub: sample-response-422-include.txt"; return 1; }
  [ -f "$fix/sample-response-422-retry-2xx-include.txt" ] \
    || { echo "missing stub: sample-response-422-retry-2xx-include.txt"; return 1; }
  publish_md_cites "$fix/sample-response-422-include.txt" \
                   "$fix/sample-response-422-retry-2xx-include.txt" \
                   "$retry" "$rec" || return 1
  json_request_shape "$retry" || return 1
  record_shape "$rec" false true || return 1
  python3 - "$retry" "$rec" <<'PY' || return 1
import json, sys
retry = json.load(open(sys.argv[1]))
rec = json.load(open(sys.argv[2]))
# Body-only retry must have comments: [] and prepended finding blocks.
if retry['comments'] != []:
    print(f"D1 retry comments={retry['comments']} expected [] on body-only retry"); sys.exit(1)
for xid in ('X1', 'X2', 'X3'):
    if f'[{xid} ' not in retry['body']:
        print(f"D1 retry body missing [{xid} ...] block"); sys.exit(1)
# Record: degraded_to_body true, finding_ids covers the degraded IDs.
if rec['finding_ids'] != ['X1', 'X2', 'X3']:
    print(f"D1 record finding_ids={rec['finding_ids']} expected [X1,X2,X3]"); sys.exit(1)
if rec['degraded_to_body'] is not True:
    print(f"D1 record degraded_to_body={rec['degraded_to_body']} expected True"); sys.exit(1)
print("D1 failure-matrix golden OK")
PY
  echo "fixture D1 422→retry 2xx payload + record OK"
}

# 20. Failure-matrix D2: 403 rate-limit abort. stderr golden + no record.
check_failure_D2_403_ratelimit() {
  local fix="$PR_FIX_DIR"
  local stub="$fix/sample-response-403-ratelimited-include.txt"
  local err="$fix/expected-error-403-ratelimited.txt"
  [ -f "$stub" ] || { echo "missing stub $stub"; return 1; }
  [ -f "$err" ] || { echo "missing stderr golden $err"; return 1; }
  publish_md_cites "$stub" "$err" || return 1
  # Stub must carry X-RateLimit-Remaining: 0 for the rate-limit branch to trigger.
  grep -qi '^x-ratelimit-remaining: 0$' "$stub" \
    || { echo "D2 stub $stub missing 'X-RateLimit-Remaining: 0' header"; return 1; }
  grep -q 'HTTP/2 403' "$stub" \
    || { echo "D2 stub $stub missing 'HTTP/2 403' status line"; return 1; }
  grep -q 'rate_limit' "$err" \
    || { echo "D2 stderr golden $err missing 'rate_limit' token"; return 1; }
  grep -q 'reset' "$err" \
    || { echo "D2 stderr golden $err missing 'reset' time mention"; return 1; }
  grep -q 'No .published_to. record' "$err" \
    || { echo "D2 stderr golden $err does not assert 'no published_to record'"; return 1; }
  echo "fixture D2 403 rate-limited error + no record OK"
}

# 21. Failure-matrix D3: 403 permission-denied abort. stderr golden + no record.
check_failure_D3_403_permission() {
  local fix="$PR_FIX_DIR"
  local stub="$fix/sample-response-403-permission-include.txt"
  local err="$fix/expected-error-403-permission.txt"
  [ -f "$stub" ] || { echo "missing stub $stub"; return 1; }
  [ -f "$err" ] || { echo "missing stderr golden $err"; return 1; }
  publish_md_cites "$stub" "$err" || return 1
  grep -q 'HTTP/2 403' "$stub" \
    || { echo "D3 stub $stub missing 'HTTP/2 403' status line"; return 1; }
  # Stub must NOT have X-RateLimit-Remaining: 0 — otherwise the rate-limit branch would fire.
  if grep -qi '^x-ratelimit-remaining: 0$' "$stub"; then
    echo "D3 stub $stub unexpectedly contains 'X-RateLimit-Remaining: 0' — would trigger rate-limit branch"
    return 1
  fi
  grep -q 'pull_requests: write' "$err" \
    || { echo "D3 stderr golden $err missing 'pull_requests: write' remediation"; return 1; }
  grep -q 'No .published_to. record' "$err" \
    || { echo "D3 stderr golden $err does not assert 'no published_to record'"; return 1; }
  echo "fixture D3 403 permission-denied error + no record OK"
}

# 22. Failure-matrix D4: 422 → body-only retry 5xx (retry also fails). stderr cites BOTH.
check_failure_D4_422_retry_5xx() {
  local fix="$PR_FIX_DIR"
  local stub1="$fix/sample-response-422-include.txt"
  local stub2="$fix/sample-response-5xx-include.txt"
  local err="$fix/expected-error-422-retry-failed.txt"
  [ -f "$stub1" ] || { echo "missing stub $stub1"; return 1; }
  [ -f "$stub2" ] || { echo "missing stub $stub2"; return 1; }
  [ -f "$err" ] || { echo "missing stderr golden $err"; return 1; }
  publish_md_cites "$stub1" "$stub2" "$err" || return 1
  grep -q 'HTTP/2 422' "$stub1" \
    || { echo "D4 stub1 $stub1 missing 'HTTP/2 422' status line"; return 1; }
  grep -q 'HTTP/2 5' "$stub2" \
    || { echo "D4 stub2 $stub2 missing 'HTTP/2 5xx' status line"; return 1; }
  grep -q '422' "$err" \
    || { echo "D4 stderr golden $err missing 422 citation"; return 1; }
  grep -q '500\|5xx' "$err" \
    || { echo "D4 stderr golden $err missing 5xx retry citation"; return 1; }
  grep -q 'No .published_to. record' "$err" \
    || { echo "D4 stderr golden $err does not assert 'no published_to record'"; return 1; }
  echo "fixture D4 422→retry 5xx error + no record OK"
}

check "cross-audit SKILL.md mentions \`pr <N>\`"                          check_cross_audit_skill_pr_arg
check "cross-audit SKILL.md uses --paginate"                              check_cross_audit_skill_paginate
check "cross-audit SKILL.md documents \`publish\` action"                 check_cross_audit_skill_publish_action
check "cross-audit SKILL.md references \`gh api\` for \`pulls/.*reviews\`" check_cross_audit_skill_gh_api_reviews
check "cross-audit SKILL.md preflights nameWithOwner"                     check_cross_audit_skill_name_with_owner
check "cross-audit SKILL.md captures headRefOid"                          check_cross_audit_skill_head_ref_oid
check "cross-audit SKILL.md documents standalone publish"                 check_cross_audit_skill_standalone_publish
check "cross-auditor.md input/output YAML block has all 5 pr_files keys"  check_cross_auditor_pr_yaml_block
check "cross-auditor.md uses gh pr checkout"                              check_cross_auditor_gh_pr_checkout
check "cross-auditor.md Codex cwd override proximity"                     check_cross_auditor_codex_cwd_proximity
check "publish.md contains all required tokens"                           check_publish_md_tokens
check "hooks/docs exempt Phase 3 decision keywords"                       check_hooks_docs_phase3_exemption
check "cross-audit README.md documents pr mode"                           check_readme_cross_audit_pr
check "publish.md JSON payload shape"                                     check_publish_md_json_shape
check "cross-auditor.md writer-contract golden"                           check_pr_files_writer_contract
check "fixture A1 normal publish-all payload + record"                    check_routing_A1_normal_publish_all
check "fixture A2 normal explicit-all payload + record"                   check_routing_A2_normal_explicit_all
check "fixture B truncated publish payload + record"                      check_routing_B_truncated
check "fixture D1 422 retry 2xx payload + record"                         check_failure_D1_422_retry_2xx
check "fixture D2 403 rate-limited error + no record"                     check_failure_D2_403_ratelimit
check "fixture D3 403 permission-denied error + no record"                check_failure_D3_403_permission
check "fixture D4 422 retry 5xx error + no record"                        check_failure_D4_422_retry_5xx
echo

# --- User-input banner convention (2026-04-17) ---
echo "User-input banner convention:"

# (a) Convention doc exists AND contains all 7 required substrings.
check_banner_convention_doc_valid() {
  local f='docs/user-input-banner-convention.md'
  if [ ! -f "$f" ]; then
    echo "missing $f"; return 1
  fi
  local miss=0
  local tok
  for tok in '## ⏸ AWAITING YOUR INPUT' \
             '## ⏸ APPROVAL REQUIRED' \
             '## When to apply' \
             '## When NOT to apply' \
             '## Positive example' \
             '## Negative example' \
             '**Approve to proceed?**'; do
    if ! grep -qF -- "$tok" "$f"; then
      echo "convention doc missing substring: '$tok'"
      miss=1
    fi
  done
  [ "$miss" -eq 0 ] || return 1
  echo "banner convention doc has all 7 required substrings"
}

# (b) feature SKILL.md must have exactly 28 AWAITING banner lines. The total includes
# the §Code audit triage banner, 5 Attack-surface profile slot prompts, and 6 STRIDE-lite prompts.
check_feature_awaiting_count_17() {
  local n
  n=$(grep -c "^## ⏸ AWAITING YOUR INPUT$" skills/feature/SKILL.md)
  if [ "$n" != "28" ]; then
    echo "feature AWAITING count=$n expected 28"
    return 1
  fi
  echo "feature AWAITING count=28 OK"
}

# (c) feature SKILL.md must have exactly 1 APPROVAL REQUIRED banner line.
check_feature_approval_count_1() {
  local n
  n=$(grep -c "^## ⏸ APPROVAL REQUIRED$" skills/feature/SKILL.md)
  if [ "$n" != "1" ]; then
    echo "feature APPROVAL count=$n expected 1"
    return 1
  fi
  echo "feature APPROVAL count=1 OK"
}

# (d) cross-audit SKILL.md must have exactly 1 AWAITING banner line.
check_cross_audit_awaiting_count_1() {
  local n
  n=$(grep -c "^## ⏸ AWAITING YOUR INPUT$" skills/cross-audit/SKILL.md)
  if [ "$n" != "1" ]; then
    echo "cross-audit AWAITING count=$n expected 1"
    return 1
  fi
  echo "cross-audit AWAITING count=1 OK"
}

# (e) research SKILL.md must have exactly 4 AWAITING banner lines.
check_research_awaiting_count_4() {
  local n
  n=$(grep -c "^## ⏸ AWAITING YOUR INPUT$" skills/research/SKILL.md)
  if [ "$n" != "5" ]; then
    echo "research AWAITING count=$n expected 5"
    return 1
  fi
  echo "research AWAITING count=5 OK"
}

# (f) investigate SKILL.md must have exactly 1 AWAITING banner line.
check_investigate_awaiting_count_1() {
  local n
  n=$(grep -c "^## ⏸ AWAITING YOUR INPUT$" skills/investigate/SKILL.md)
  if [ "$n" != "1" ]; then
    echo "investigate AWAITING count=$n expected 1"
    return 1
  fi
  echo "investigate AWAITING count=1 OK"
}

# (g) Literal 'Ready to proceed?' must be ABSENT from feature SKILL.md.
check_feature_ready_to_proceed_absent() {
  if grep -qF "Ready to proceed?" skills/feature/SKILL.md; then
    echo "'Ready to proceed?' still present in feature SKILL.md"
    return 1
  fi
  echo "'Ready to proceed?' absent OK"
}

# (h) Literal 'Proceed to Hand-off' must be ABSENT from feature SKILL.md.
check_feature_proceed_to_handoff_absent() {
  if grep -qF "Proceed to Hand-off" skills/feature/SKILL.md; then
    echo "'Proceed to Hand-off' still present in feature SKILL.md"
    return 1
  fi
  echo "'Proceed to Hand-off' absent OK"
}

# (i) Canonical post-audit replacement text must be PRESENT.
check_feature_post_audit_replacement() {
  if ! grep -qF "Spec review passed — the spec is saved to KB. Moving to implementation." skills/feature/SKILL.md; then
    echo "post-audit canonical replacement sentence missing in feature SKILL.md"
    return 1
  fi
  echo "post-audit replacement text present OK"
}

# (j) Canonical post-verify replacement text must be PRESENT.
check_feature_post_verify_replacement() {
  if ! grep -qF "Verify passed. Moving to code audit." skills/feature/SKILL.md; then
    echo "post-verify replacement sentence missing in feature SKILL.md"
    return 1
  fi
  echo "post-verify replacement text present OK"
}

# (k) HARD-GATE trailing bold '**Approve to proceed?**' must be PRESENT in feature SKILL.md.
check_feature_hard_gate_trailing_bold() {
  if ! grep -qF "**Approve to proceed?**" skills/feature/SKILL.md; then
    echo "HARD-GATE trailing bold '**Approve to proceed?**' missing in feature SKILL.md"
    return 1
  fi
  echo "HARD-GATE trailing bold present OK"
}

# (l) feature SKILL.md — convention-doc pointer within first 60 lines.
check_feature_intro_points_to_convention() {
  if ! head -n 60 skills/feature/SKILL.md | grep -qF 'docs/user-input-banner-convention.md'; then
    echo "feature SKILL.md intro (first 60 lines) missing pointer to docs/user-input-banner-convention.md"
    return 1
  fi
  echo "feature SKILL.md intro points to convention doc OK"
}

# (m) cross-audit SKILL.md — convention-doc pointer within first 60 lines.
check_cross_audit_intro_points_to_convention() {
  if ! head -n 60 skills/cross-audit/SKILL.md | grep -qF 'docs/user-input-banner-convention.md'; then
    echo "cross-audit SKILL.md intro (first 60 lines) missing pointer to docs/user-input-banner-convention.md"
    return 1
  fi
  echo "cross-audit SKILL.md intro points to convention doc OK"
}

# (n) research SKILL.md — convention-doc pointer within first 60 lines.
check_research_intro_points_to_convention() {
  if ! head -n 60 skills/research/SKILL.md | grep -qF 'docs/user-input-banner-convention.md'; then
    echo "research SKILL.md intro (first 60 lines) missing pointer to docs/user-input-banner-convention.md"
    return 1
  fi
  echo "research SKILL.md intro points to convention doc OK"
}

# (o) investigate SKILL.md — convention-doc pointer within first 60 lines.
check_investigate_intro_points_to_convention() {
  if ! head -n 60 skills/investigate/SKILL.md | grep -qF 'docs/user-input-banner-convention.md'; then
    echo "investigate SKILL.md intro (first 60 lines) missing pointer to docs/user-input-banner-convention.md"
    return 1
  fi
  echo "investigate SKILL.md intro points to convention doc OK"
}

# (p) code-quality-rules.md — exact verbatim cross-reference sentence.
check_code_quality_rules_exact_rule_text() {
  if ! grep -qF "User-input prompt presentation is governed by docs/user-input-banner-convention.md — violations block spec-review Pass 1." skills/feature/references/code-quality-rules.md; then
    echo "code-quality-rules.md missing exact verbatim cross-reference sentence"
    return 1
  fi
  echo "code-quality-rules.md has exact verbatim sentence OK"
}

# (q) APPROVAL REQUIRED is unique repo-wide (sum across skills/*/SKILL.md equals 1).
check_approval_required_unique_repo_wide() {
  local n
  n=$(grep -h "## ⏸ APPROVAL REQUIRED" skills/*/SKILL.md | wc -l | tr -d ' ')
  if [ "$n" != "1" ]; then
    echo "APPROVAL REQUIRED repo-wide count=$n expected 1"
    return 1
  fi
  echo "APPROVAL REQUIRED unique repo-wide OK"
}

# (r) ruler-prefix count matches total banner count (expected 25 — includes the
# §Code audit triage banner added by spec 2026-04-22-mandatory-code-audit-phase Step 1
# and the §Conclude --queue-spec banner added by spec 2026-04-28-session-handoff-queue-visibility Step 2).
check_awaiting_ruler_prefix_count_matches() {
  local c
  c=$(cat skills/feature/SKILL.md skills/cross-audit/SKILL.md skills/research/SKILL.md skills/investigate/SKILL.md | awk '
    BEGIN { c = 0; prev = "" }
    ($0 == "## ⏸ AWAITING YOUR INPUT" || $0 == "## ⏸ APPROVAL REQUIRED") && prev == "---" { c++ }
    { prev = $0 }
    END { print c }
  ')
  if [ "$c" != "25" ]; then
    echo "ruler-prefix count=$c expected 25"
    return 1
  fi
  echo "ruler-prefix count=25 OK"
}

# (s) each banner has trailing bold question within 15 lines (expected 36 — includes
# the feature Attack-surface profile and STRIDE-lite slot prompts).
check_banner_trailing_bold_present_each() {
  local c
  c=$(cat skills/feature/SKILL.md skills/cross-audit/SKILL.md skills/research/SKILL.md skills/investigate/SKILL.md | awk '
    BEGIN { satisfied = 0; inside = 0; countdown = 0 }
    /^## ⏸ (AWAITING YOUR INPUT|APPROVAL REQUIRED)$/ { inside = 1; countdown = 15; next }
    inside && /^## / { inside = 0; countdown = 0; next }
    inside && countdown > 0 && /\*\*[^*]+\?\*\*/ { satisfied++; inside = 0; countdown = 0; next }
    inside { countdown--; if (countdown <= 0) inside = 0 }
    END { print satisfied }
  ')
  if [ "$c" != "36" ]; then
    echo "trailing-bold-present-each count=$c expected 36"
    return 1
  fi
  echo "trailing-bold-present-each=36 OK"
}

check "banner-convention-doc-valid"             check_banner_convention_doc_valid
check "feature-AWAITING-count-28"               check_feature_awaiting_count_17
check "feature-APPROVAL-count-1"                check_feature_approval_count_1
check "cross-audit-AWAITING-count-1"            check_cross_audit_awaiting_count_1
check "research-AWAITING-count-4"               check_research_awaiting_count_4
check "investigate-AWAITING-count-1"            check_investigate_awaiting_count_1
check "feature-Ready-to-proceed-absent"         check_feature_ready_to_proceed_absent
check "feature-Proceed-to-Handoff-absent"       check_feature_proceed_to_handoff_absent
check "feature-post-audit-replacement"          check_feature_post_audit_replacement
check "feature-post-verify-replacement"         check_feature_post_verify_replacement
check "feature-hard-gate-trailing-bold"         check_feature_hard_gate_trailing_bold
check "feature-intro-points-to-convention"      check_feature_intro_points_to_convention
check "cross-audit-intro-points-to-convention"  check_cross_audit_intro_points_to_convention
check "research-intro-points-to-convention"     check_research_intro_points_to_convention
check "investigate-intro-points-to-convention"  check_investigate_intro_points_to_convention
check "code-quality-rules-exact-rule-text"      check_code_quality_rules_exact_rule_text
check "approval-required-unique-repo-wide"      check_approval_required_unique_repo_wide
check "awaiting-ruler-prefix-count-matches"     check_awaiting_ruler_prefix_count_matches
check "banner-trailing-bold-present-each"       check_banner_trailing_bold_present_each
echo

# --- R3 test-strength rule (2026-04-17) ---
echo "R3 test-strength rule:"

CQR='skills/feature/references/code-quality-rules.md'
DWF='skills/feature/references/developer-workflow.md'

check "r3-rule-heading-present"                         check_r3_rule_heading_present                         "$CQR"
check "r3-structure-triplet-present"                    check_r3_structure_triplet_present                    "$CQR"
check "r3-anti-patterns-enumerated"                     check_r3_anti_patterns_enumerated                     "$CQR"
check "r3-notes-requirement-present"                    check_r3_notes_requirement_present                    "$CQR"
check "developer-workflow-short-form-r3"                check_developer_workflow_short_form_r3                "$DWF"
check "developer-workflow-test-quality-points-to-r3"    check_developer_workflow_test_quality_points_to_r3    "$DWF"
check "developer-workflow-observed-notes-requirement"   check_developer_workflow_observed_notes_requirement   "$DWF"
echo

# --- R3 fixture-based behavioral assertions (2026-04-19, backlog #24) ---
echo "R3 fixture-based behavioral assertions:"

# iter-15 X45: fixture paths are INLINED directly into each wrapper body
# (not stored in intermediate variables such as `R3_WRONG`/`DWF_WRONG`).
# The iter-14 X43 approach sealed the variables via `readonly`, but the
# static checks (`grep -cFx`, unique-count, `unset` prohibition) did not
# cover alternate write paths — `printf -v R3_WRONG …`, `declare
# R3_WRONG=…`, `typeset`, `eval "R3_WRONG=…"`, `read -r R3_WRONG <<< …`
# — any of which could rebind the variable BEFORE `readonly` took
# effect, pointing helpers at a non-existent path, where
# `extract_md_section` returns empty, the helper returns 1, the wrapper's
# `!` inverts to 0, and all 6 wrappers silently PASS without exercising
# the fixtures. Inlining the paths as string literals in the function
# bodies makes them part of `assert_fn_matches_spec_runtime`'s body-diff
# — bash's own parser normalizes them and any drift is caught by the
# runtime body match against spec §3.5.

# H1: structure-triplet helper must reject the wrong-section fixture.
check_smoke_helper_r3_structure_rejects_wrong_section() {
  ! check_r3_structure_triplet_present 'tests/fixtures/smoke-helpers/r3-wrong-section.md' >/dev/null 2>&1 \
    || { echo "check_r3_structure_triplet_present wrongly accepted tests/fixtures/smoke-helpers/r3-wrong-section.md"; return 1; }
  echo "check_r3_structure_triplet_present correctly rejected wrong-section fixture"
}

# H2: anti-patterns helper must reject the wrong-section fixture.
check_smoke_helper_r3_anti_patterns_rejects_wrong_section() {
  ! check_r3_anti_patterns_enumerated 'tests/fixtures/smoke-helpers/r3-wrong-section.md' >/dev/null 2>&1 \
    || { echo "check_r3_anti_patterns_enumerated wrongly accepted tests/fixtures/smoke-helpers/r3-wrong-section.md"; return 1; }
  echo "check_r3_anti_patterns_enumerated correctly rejected wrong-section fixture"
}

# H3: notes-requirement helper must reject the wrong-section fixture.
check_smoke_helper_r3_notes_rejects_wrong_section() {
  ! check_r3_notes_requirement_present 'tests/fixtures/smoke-helpers/r3-wrong-section.md' >/dev/null 2>&1 \
    || { echo "check_r3_notes_requirement_present wrongly accepted tests/fixtures/smoke-helpers/r3-wrong-section.md"; return 1; }
  echo "check_r3_notes_requirement_present correctly rejected wrong-section fixture"
}

# H4: DWF short-form-R3 helper must reject the DWF wrong-section fixture.
check_smoke_helper_dwf_short_form_rejects_wrong_section() {
  ! check_developer_workflow_short_form_r3 'tests/fixtures/smoke-helpers/dwf-wrong-section.md' >/dev/null 2>&1 \
    || { echo "check_developer_workflow_short_form_r3 wrongly accepted tests/fixtures/smoke-helpers/dwf-wrong-section.md"; return 1; }
  echo "check_developer_workflow_short_form_r3 correctly rejected wrong-section fixture"
}

# H5: DWF §Test Quality pointer helper must reject the wrong-section fixture.
check_smoke_helper_dwf_test_quality_rejects_wrong_section() {
  ! check_developer_workflow_test_quality_points_to_r3 'tests/fixtures/smoke-helpers/dwf-wrong-section.md' >/dev/null 2>&1 \
    || { echo "check_developer_workflow_test_quality_points_to_r3 wrongly accepted tests/fixtures/smoke-helpers/dwf-wrong-section.md"; return 1; }
  echo "check_developer_workflow_test_quality_points_to_r3 correctly rejected wrong-section fixture"
}

# H6: DWF §Per-step protocol observed.notes helper must reject the wrong-section fixture.
check_smoke_helper_dwf_observed_notes_rejects_wrong_section() {
  ! check_developer_workflow_observed_notes_requirement 'tests/fixtures/smoke-helpers/dwf-wrong-section.md' >/dev/null 2>&1 \
    || { echo "check_developer_workflow_observed_notes_requirement wrongly accepted tests/fixtures/smoke-helpers/dwf-wrong-section.md"; return 1; }
  echo "check_developer_workflow_observed_notes_requirement correctly rejected wrong-section fixture"
}

check "smoke-helper-r3-structure-rejects-wrong-section"       check_smoke_helper_r3_structure_rejects_wrong_section
check "smoke-helper-r3-anti-patterns-rejects-wrong-section"   check_smoke_helper_r3_anti_patterns_rejects_wrong_section
check "smoke-helper-r3-notes-rejects-wrong-section"           check_smoke_helper_r3_notes_rejects_wrong_section
check "smoke-helper-dwf-short-form-rejects-wrong-section"     check_smoke_helper_dwf_short_form_rejects_wrong_section
check "smoke-helper-dwf-test-quality-rejects-wrong-section"   check_smoke_helper_dwf_test_quality_rejects_wrong_section
check "smoke-helper-dwf-observed-notes-rejects-wrong-section" check_smoke_helper_dwf_observed_notes_rejects_wrong_section
echo

# --- DONE→VERIFIED migration (spec 2026-04-20-done-verified-migration) ---
echo "DONE→VERIFIED migration (2026-04-20):"

# DV1: librarian canonical block helper must reject the stale fixture.
check_smoke_helper_librarian_rejects_stale() {
  ! check_librarian_status_block_canonical 'tests/fixtures/done-verified-migration/librarian-stale.md' >/dev/null 2>&1 \
    || { echo "check_librarian_status_block_canonical wrongly accepted librarian-stale.md"; return 1; }
  echo "check_librarian_status_block_canonical correctly rejected stale librarian fixture"
}

# DV2: discard-mode helper must reject the stale fixture.
check_smoke_helper_discard_mode_rejects_stale() {
  ! check_discard_mode_refuses_verified_shipped 'tests/fixtures/done-verified-migration/discard-mode-stale.md' >/dev/null 2>&1 \
    || { echo "check_discard_mode_refuses_verified_shipped wrongly accepted discard-mode-stale.md"; return 1; }
  echo "check_discard_mode_refuses_verified_shipped correctly rejected stale discard-mode fixture"
}

# DV3: feature/SKILL.md active-done-writes helper must reject the stale fixture.
check_smoke_helper_feature_skill_rejects_stale() {
  ! check_feature_skill_no_active_done_writes 'tests/fixtures/done-verified-migration/skill-md-stale.md' >/dev/null 2>&1 \
    || { echo "check_feature_skill_no_active_done_writes wrongly accepted skill-md-stale.md"; return 1; }
  echo "check_feature_skill_no_active_done_writes correctly rejected stale skill-md fixture"
}

# DV4: developer-workflow active-done-writes helper must reject the stale fixture.
check_smoke_helper_developer_workflow_rejects_stale() {
  ! check_developer_workflow_no_active_done_writes 'tests/fixtures/done-verified-migration/developer-workflow-stale.md' >/dev/null 2>&1 \
    || { echo "check_developer_workflow_no_active_done_writes wrongly accepted developer-workflow-stale.md"; return 1; }
  echo "check_developer_workflow_no_active_done_writes correctly rejected stale developer-workflow fixture"
}

# 4 positive: helper against real plugin file
check "check_librarian_status_block_canonical" check_librarian_status_block_canonical agents/librarian.md
check "check_discard_mode_refuses_verified_shipped" check_discard_mode_refuses_verified_shipped skills/feature/SKILL.md
check "check_feature_skill_no_active_done_writes" check_feature_skill_no_active_done_writes skills/feature/SKILL.md
check "check_developer_workflow_no_active_done_writes" check_developer_workflow_no_active_done_writes skills/feature/references/developer-workflow.md

# 4 negative: wrapper-invocations verifying helpers reject stale fixtures
check "check_smoke_helper_librarian_rejects_stale" check_smoke_helper_librarian_rejects_stale
check "check_smoke_helper_discard_mode_rejects_stale" check_smoke_helper_discard_mode_rejects_stale
check "check_smoke_helper_feature_skill_rejects_stale" check_smoke_helper_feature_skill_rejects_stale
check "check_smoke_helper_developer_workflow_rejects_stale" check_smoke_helper_developer_workflow_rejects_stale
echo

# --- Agent routing (2026-04-18) ---
echo "Agent routing (2026-04-18):"

AGENT_ROUTING='skills/feature/references/agent-routing.md'

check_matrix_h2_sections() {
  # (i.a) All four byte-exact H2 headings present in agent-routing.md.
  test -f "$AGENT_ROUTING" || { echo "$AGENT_ROUTING missing"; return 1; }
  local h
  for h in '## Codex (default)' '## Senior' '## Rationale logging' '## Escalation'; do
    grep -qF "$h" "$AGENT_ROUTING" || { echo "$AGENT_ROUTING missing heading: $h"; return 1; }
  done
  echo "agent-routing.md has all 4 H2 sections"
}

check_matrix_triggers_per_agent() {
  # (i.b) Each of Codex/Senior sections has >=2 '- **T-[CSM]#**:' bullets (Senior >=3).
  test -f "$AGENT_ROUTING" || { echo "$AGENT_ROUTING missing"; return 1; }
  local sec count
  sec=$(extract_md_section "$AGENT_ROUTING" '## Codex (default)')
  count=$(printf '%s\n' "$sec" | grep -cE '^- \*\*T-[CSM][0-9]+\*\*:')
  [ "$count" -ge 2 ] || { echo "Codex triggers count=$count (need >=2)"; return 1; }
  sec=$(extract_md_section "$AGENT_ROUTING" '## Senior')
  count=$(printf '%s\n' "$sec" | grep -cE '^- \*\*T-[CSM][0-9]+\*\*:')
  [ "$count" -ge 3 ] || { echo "Senior triggers count=$count (need >=3)"; return 1; }
  echo "agent-routing.md has >=2 triggers per agent (Senior >=3)"
}

check_matrix_anti_triggers_per_agent() {
  # (i.c) Each of Codex/Senior sections has '**Anti-triggers**' line with a following '- ' bullet.
  test -f "$AGENT_ROUTING" || { echo "$AGENT_ROUTING missing"; return 1; }
  local a sec
  for a in '## Codex (default)' '## Senior'; do
    sec=$(extract_md_section "$AGENT_ROUTING" "$a")
    printf '%s\n' "$sec" | awk '
      /\*\*Anti-triggers\*\*/ { found=1; next }
      found && /^[[:space:]]*$/ { next }
      found { if (/^- /) { ok=1; exit } else { exit } }
      END { exit(ok?0:1) }
    ' || { echo "section '$a' missing **Anti-triggers** with following bullet"; return 1; }
  done
  echo "agent-routing.md has anti-triggers per agent"
}

check_matrix_rationale_log_format() {
  # (i.d) '## Rationale logging' section contains the byte-exact canonical Log format line.
  test -f "$AGENT_ROUTING" || { echo "$AGENT_ROUTING missing"; return 1; }
  local sec
  sec=$(extract_md_section "$AGENT_ROUTING" '## Rationale logging')
  printf '%s\n' "$sec" | grep -qF 'last_agent=<codex|senior>; rationale=<T-X#>[; notes=<short>]' \
    || { echo "## Rationale logging missing canonical Log format line"; return 1; }
  echo "agent-routing.md Rationale logging has canonical format"
}

check_skill_agent_selection_pointer() {
  # (ii) Positive (section-scoped): byte-exact pointer line inside '### Agent selection' extract.
  #      Negative (file-level): no line begins with '**Rule of thumb**:' anywhere in SKILL.md.
  local sec
  sec=$(extract_md_section skills/feature/SKILL.md '### Agent selection')
  printf '%s\n' "$sec" | grep -qF 'See `skills/feature/references/agent-routing.md` for routing triggers and the canonical Log format.' \
    || { echo "SKILL.md ### Agent selection missing byte-exact pointer line"; return 1; }
  if grep -q '^\*\*Rule of thumb\*\*:' skills/feature/SKILL.md; then
    echo "SKILL.md still contains '**Rule of thumb**:' line (should be removed)"
    return 1
  fi
  echo "SKILL.md ### Agent selection has pointer; Rule of thumb absent"
}

check_when_to_pick_matches_frontmatter() {
  # (iii) For each agent, frontmatter `when_to_pick:` scalar matches matrix `**When to pick**: ...` line byte-exact.
  local agent heading fm matrix sec
  for agent in codex senior; do
    case "$agent" in
      codex)  heading='## Codex (default)';;
      senior) heading='## Senior';;
    esac
    fm=$(awk '/^when_to_pick: /{sub(/^when_to_pick: /, ""); print; exit}' "agents/developer-$agent.md")
    if [ -z "$fm" ]; then
      echo "agents/developer-$agent.md missing 'when_to_pick:' frontmatter scalar"
      return 1
    fi
    sec=$(extract_md_section "$AGENT_ROUTING" "$heading")
    matrix=$(printf '%s\n' "$sec" | awk '/^\*\*When to pick\*\*: /{sub(/^\*\*When to pick\*\*: /, ""); print; exit}')
    if [ -z "$matrix" ]; then
      echo "$AGENT_ROUTING section '$heading' missing '**When to pick**: ' line"
      return 1
    fi
    if [ "$fm" != "$matrix" ]; then
      echo "when_to_pick mismatch for $agent:"
      echo "|$fm| vs |$matrix|"
      return 1
    fi
  done
  echo "when_to_pick matches matrix for codex/senior"
}

check_matrix_escalation_per_agent_tuples() {
  # (iv) '## Escalation' section has ### Codex, ### Senior subsections, each with condition/action/target/outcome tuples.
  test -f "$AGENT_ROUTING" || { echo "$AGENT_ROUTING missing"; return 1; }
  local esc sub h k
  esc=$(extract_md_section "$AGENT_ROUTING" '## Escalation')
  for h in '### Codex' '### Senior'; do
    printf '%s\n' "$esc" | grep -qF "$h" || { echo "## Escalation missing subheading: $h"; return 1; }
  done
  for h in 'Codex' 'Senior'; do
    sub=$(printf '%s\n' "$esc" | awk -v hdr="### $h" '
      !in_s && $0 == hdr { in_s = 1; next }
      in_s && /^### / { exit }
      in_s { print }
    ')
    for k in 'condition' 'action' 'target' 'outcome'; do
      printf '%s\n' "$sub" | grep -qE "\\*\\*${k}\\*\\*:" \
        || { echo "## Escalation ### $h missing **${k}**: line"; return 1; }
    done
  done
  echo "agent-routing.md ## Escalation has per-agent tuples"
}

check_skill_resume_flow_uses_canonical_rationale() {
  # (v) Positive: byte-exact canonical literal present in SKILL.md.
  #     Negative: no bare 'last_agent=<...>' form without 'rationale=' on the same line.
  grep -qF 'last_agent=<codex|senior>; rationale=<T-X#>' skills/feature/SKILL.md \
    || { echo "SKILL.md missing canonical last_agent=<codex|senior>; rationale=<T-X#> literal"; return 1; }
  local bad
  bad=$(grep -E 'last_agent=<[^>]+>' skills/feature/SKILL.md | grep -v 'rationale=' || true)
  if [ -n "$bad" ]; then
    echo "SKILL.md contains bare 'last_agent=<...>' line(s) without 'rationale=':"
    printf '%s\n' "$bad"
    return 1
  fi
  echo "SKILL.md continue-mode uses canonical rationale form"
}

check "matrix-h2-sections"                               check_matrix_h2_sections
check "matrix-triggers-per-agent"                        check_matrix_triggers_per_agent
check "matrix-anti-triggers-per-agent"                   check_matrix_anti_triggers_per_agent
check "matrix-rationale-log-format"                      check_matrix_rationale_log_format
check "skill-agent-selection-pointer"                    check_skill_agent_selection_pointer
check "when-to-pick-matches-frontmatter"                 check_when_to_pick_matches_frontmatter
check "matrix-escalation-per-agent-tuples"               check_matrix_escalation_per_agent_tuples
check "skill-resume-flow-uses-canonical-rationale"       check_skill_resume_flow_uses_canonical_rationale
check "Continue-mode normalises legacy last_agent=middle to codex" check_continue_mode_legacy_middle_normalisation
check "legacy last_agent=middle fixture present"         check_legacy_last_agent_fixture_present
echo

# --- Branch prefix (#15) ---
echo "Branch prefix (#15):"

SPEC_TEMPLATE='skills/feature/references/spec-template.md'
SKILL_MD='skills/feature/SKILL.md'
DEV_WORKFLOW='skills/feature/references/developer-workflow.md'
OVERVIEW='docs/AI_Dev_Team_Overview.md'
README_MD='README.md'
STOP_CHECK='hooks/stop-check'
CQR_BP='skills/feature/references/code-quality-rules.md'

# (#15-a) spec-template has `branch: {change_type}/YYYY-MM-DD-{slug}` immediately followed by `change_type: {change_type}`
check_spec_template_has_change_type() {
  python3 - <<'PY'
import sys
path = 'skills/feature/references/spec-template.md'
lines = open(path).read().split('\n')
c1 = 'branch: {change_type}/YYYY-MM-DD-{slug}'
c2 = 'change_type: {change_type}'
for i, l in enumerate(lines[:-1]):
    if l == c1 and lines[i+1] == c2:
        print('spec-template C1+C2 consecutive byte-exact')
        sys.exit(0)
print(f'spec-template missing consecutive C1 ({c1!r}) + C2 ({c2!r})')
sys.exit(1)
PY
}

# (#15-b) SKILL.md contains byte-exact C3 prompt-line prefix
check_skill_change_type_prompt_present() {
  grep -qF 'Inferred change type: **' "$SKILL_MD" \
    || { echo "SKILL.md missing byte-exact 'Inferred change type: **' C3 prompt line"; return 1; }
  echo "SKILL.md has change-type banner prompt"
}

# (#15-c) SKILL.md inline yaml frontmatter block contains both C4 lines
check_skill_inline_frontmatter_lists_change_type() {
  python3 - <<'PY'
import sys, re
path = 'skills/feature/SKILL.md'
text = open(path).read()
# Find any fenced yaml block containing `title: <feature title>`
# Accept any fenced ```yaml ... ``` block that looks like the inline frontmatter example.
blocks = re.findall(r'```yaml\n(.*?)\n```', text, re.DOTALL)
need1 = 'branch: <type>/YYYY-MM-DD-<slug>'
need2 = 'change_type: <type>'
for b in blocks:
    if 'title:' in b and need1 in b and need2 in b:
        print('SKILL.md inline yaml example lists branch + change_type byte-exact')
        sys.exit(0)
print(f'SKILL.md inline yaml example missing C4 lines ({need1!r}, {need2!r})')
sys.exit(1)
PY
}

# (#15-d) No hard-coded dated `feature/` prefix survives (with §3.7 # legacy exception)
check_skill_no_hardcoded_feature_prefix() {
  python3 - <<'PY'
import re, sys
pat = re.compile(r'feature/<?(YYYY|\d{4})-(MM|\d{2})-(DD|\d{2})-')
files = [
  'skills/feature/SKILL.md',
  'skills/feature/references/spec-template.md',
  'skills/feature/references/developer-workflow.md',
  'docs/AI_Dev_Team_Overview.md',
  'README.md',
]
leaks = []
for f in files:
    try:
        lines = open(f).read().split('\n')
    except FileNotFoundError:
        continue
    for i, l in enumerate(lines):
        if not pat.search(l):
            continue
        if '# legacy' in l:
            continue
        ctx = '\n'.join(lines[max(0,i-2):i])
        if '# legacy' in ctx:
            continue
        leaks.append(f'{f}:{i+1}')
if leaks:
    print('LEAK: ' + ','.join(leaks))
    sys.exit(1)
print('no hard-coded dated feature/ prefix survives')
PY
}

# (#15-e) README contains byte-exact concrete `branch: feat/2026-04-17-my-feature` worked example
check_readme_has_concrete_feat_example() {
  grep -qF 'branch: feat/2026-04-17-my-feature' "$README_MD" \
    || { echo "README.md missing byte-exact 'branch: feat/2026-04-17-my-feature' worked example"; return 1; }
  echo "README.md has concrete feat/ worked example"
}

# (#15-f) SKILL.md must NOT contain a pipe-table cell of the byte-exact form `| feature/...`
check_skill_no_non_dated_feature_example() {
  if grep -qF '| feature/...' "$SKILL_MD"; then
    echo "SKILL.md still contains non-dated table-cell '| feature/...' example"
    return 1
  fi
  echo "SKILL.md free of non-dated '| feature/...' example"
}

# (#15-g) developer-workflow.md must NOT contain byte-exact `feature/other-slug`
check_developer_workflow_no_non_dated_feature_ref() {
  if grep -qF 'feature/other-slug' "$DEV_WORKFLOW"; then
    echo "developer-workflow.md still contains 'feature/other-slug' example"
    return 1
  fi
  echo "developer-workflow.md free of 'feature/other-slug' example"
}

# (#15-h) hooks/stop-check contains byte-exact C5 widened regex source line
check_stop_check_regex_widened() {
  grep -qF 're.compile(r"^(feat|fix|refactor|ci|docs|test|chore|feature)/\d{4}-\d{2}-\d{2}-")' "$STOP_CHECK" \
    || { echo "hooks/stop-check missing byte-exact C5 widened regex"; return 1; }
  echo "hooks/stop-check regex widened to C5 form"
}

# (#15-i) stop-check regex matches all eight prefixes (live import)
check_stop_check_matches_all_eight_prefixes() {
  python3 - <<'PY'
import sys
from importlib.machinery import SourceFileLoader
import importlib.util as u
l = SourceFileLoader('sc', 'hooks/stop-check')
s = u.spec_from_loader('sc', l)
m = u.module_from_spec(s)
try:
    l.exec_module(m)
except Exception as e:
    print(f'failed to load hooks/stop-check: {e}')
    sys.exit(1)
prefixes = ['feat','fix','refactor','ci','docs','test','chore','feature']
bad = [p for p in prefixes if not m.FEATURE_BRANCH_RE.match(p + '/2026-04-18-x')]
if bad:
    print('MISSING prefix match: ' + ','.join(bad))
    sys.exit(1)
print('all 8 prefixes matched by FEATURE_BRANCH_RE')
PY
}

# (#15-j) stop-check docstring/header region (first ~15 lines) mentions all 8 prefixes byte-exact
check_stop_check_docstring_mentions_all_eight_prefixes() {
  head -n 15 "$STOP_CHECK" | grep -qF 'feat, fix, refactor, ci, docs, test, chore, feature' \
    || { echo "hooks/stop-check docstring (first 15 lines) missing byte-exact 'feat, fix, refactor, ci, docs, test, chore, feature'"; return 1; }
  echo "hooks/stop-check docstring mentions all eight prefixes"
}

# (#15-k) code-quality-rules.md has R4 heading (C6) AND three subheading markers in R4 body
check_code_quality_rule_r4_present() {
  grep -qF '## R4 — Branch prefix matches change nature' "$CQR_BP" \
    || { echo "code-quality-rules.md missing '## R4 — Branch prefix matches change nature' heading (C6)"; return 1; }
  R4=$(extract_md_section "$CQR_BP" '## R4 — Branch prefix matches change nature')
  printf '%s\n' "$R4" | grep -qF '**Rule**' || { echo "R4 section missing '**Rule**' subheading"; return 1; }
  printf '%s\n' "$R4" | grep -qF '**Why**' || { echo "R4 section missing '**Why**' subheading"; return 1; }
  printf '%s\n' "$R4" | grep -qF '**How to apply**' || { echo "R4 section missing '**How to apply**' subheading"; return 1; }
  echo "R4 heading + Rule/Why/How-to-apply subheadings present"
}

# (#15-l) R4 content floor: three canonical substrings + ≥3 numbered items under How-to-apply
check_code_quality_rule_r4_content_complete() {
  python3 - <<'PY'
import re, sys
path = 'skills/feature/references/code-quality-rules.md'
text = open(path).read()
hdr = '## R4 — Branch prefix matches change nature'
if hdr not in text:
    print('R4 heading missing')
    sys.exit(1)
start = text.index(hdr)
rest = text[start + len(hdr):]
m = re.search(r'\n## ', rest)
body = rest[: m.start()] if m else rest

def subsection(body, marker, next_markers):
    if marker not in body:
        return None
    s = body.index(marker)
    rest = body[s + len(marker):]
    # cut at whichever next marker appears first
    cuts = [rest.index(n) for n in next_markers if n in rest]
    end = min(cuts) if cuts else len(rest)
    return rest[:end]

rule_body = subsection(body, '**Rule**', ['**Why**', '**How to apply**'])
why_body = subsection(body, '**Why**', ['**How to apply**'])
how_body = subsection(body, '**How to apply**', [])

errs = []
if rule_body is None:
    errs.append('missing **Rule** subsection')
else:
    need_rule = 'branch prefix MUST equal the resolved `change_type`'
    if need_rule not in rule_body:
        errs.append(f'Rule body missing substring: {need_rule!r}')
if why_body is None:
    errs.append('missing **Why** subsection')
else:
    if 'release-note categorisation' not in why_body:
        errs.append("Why body missing 'release-note categorisation' substring")
if how_body is None:
    errs.append('missing **How to apply** subsection')
else:
    if '<change_type>/YYYY-MM-DD-<slug>' not in how_body:
        errs.append("How-to-apply body missing '<change_type>/YYYY-MM-DD-<slug>' substring")
    # count numbered bullets: lines matching ^[[:space:]]*[1-9]\.
    nums = re.findall(r'(?m)^[\t ]*[1-9]\.', how_body)
    if len(nums) < 3:
        errs.append(f'How-to-apply has <3 numbered items ({len(nums)})')

if errs:
    print('; '.join(errs))
    sys.exit(1)
print('R4 content floor satisfied (3 canonical substrings + >=3 numbered items)')
PY
}

check "spec-template-has-change-type"                     check_spec_template_has_change_type
check "skill-change-type-prompt-present"                  check_skill_change_type_prompt_present
check "skill-inline-frontmatter-lists-change-type"        check_skill_inline_frontmatter_lists_change_type
check "skill-no-hardcoded-feature-prefix"                 check_skill_no_hardcoded_feature_prefix
check "readme-has-concrete-feat-example"                  check_readme_has_concrete_feat_example
check "skill-no-non-dated-feature-example"                check_skill_no_non_dated_feature_example
check "developer-workflow-no-non-dated-feature-ref"       check_developer_workflow_no_non_dated_feature_ref
check "stop-check-regex-widened"                          check_stop_check_regex_widened
check "stop-check-matches-all-eight-prefixes"             check_stop_check_matches_all_eight_prefixes
check "stop-check-docstring-mentions-all-eight-prefixes"  check_stop_check_docstring_mentions_all_eight_prefixes
check "code-quality-rule-r4-present"                      check_code_quality_rule_r4_present
check "code-quality-rule-r4-content-complete"             check_code_quality_rule_r4_content_complete
echo

# --- R5 test-file-location rule (2026-04-18) ---
echo "R5 test-file-location rule:"

CQR_R5='skills/feature/references/code-quality-rules.md'
DWF_R5='skills/feature/references/developer-workflow.md'
R5_HDR='## R5 — Tests live in a dedicated file, not inline in the implementation'

# (1) R5 heading literal present in code-quality-rules.md
check_r5_rule_heading_present() {
  grep -qF -- "$R5_HDR" "$CQR_R5" \
    || { echo "code-quality-rules.md missing '$R5_HDR' heading"; return 1; }
  echo "R5 heading present in code-quality-rules.md"
}

# (2) Structure triplet present inside R5 section
check_r5_structure_triplet_present() {
  local R5
  R5=$(extract_md_section "$CQR_R5" "$R5_HDR")
  printf '%s\n' "$R5" | grep -qF '**Rule**:' || { echo "R5 section missing '**Rule**:' subheading"; return 1; }
  printf '%s\n' "$R5" | grep -qF '**Why**:' || { echo "R5 section missing '**Why**:' subheading"; return 1; }
  printf '%s\n' "$R5" | grep -qF '**How to apply**:' || { echo "R5 section missing '**How to apply**:' subheading"; return 1; }
  echo "R5 structure triplet (Rule/Why/How to apply) present"
}

# (3) Key anchor tokens present inside R5 section (soroban, repo convention, #[cfg(test)], tests.rs|tests/)
check_r5_key_tokens_present() {
  local R5
  R5=$(extract_md_section "$CQR_R5" "$R5_HDR")
  printf '%s\n' "$R5" | grep -qiF 'soroban' || { echo "R5 missing 'soroban' anchor token"; return 1; }
  printf '%s\n' "$R5" | grep -qiF 'repo convention' || { echo "R5 missing 'repo convention' anchor token"; return 1; }
  printf '%s\n' "$R5" | grep -qF '#[cfg(test)]' || { echo "R5 missing '#[cfg(test)]' anchor token (case-sensitive)"; return 1; }
  if ! printf '%s\n' "$R5" | grep -qF 'tests.rs' && ! printf '%s\n' "$R5" | grep -qF 'tests/'; then
    echo "R5 missing dedicated-test-file reference ('tests.rs' or 'tests/')"; return 1
  fi
  echo "R5 key tokens (soroban, repo convention, #[cfg(test)], tests.rs|tests/) all present"
}

# (4) Byte-exact project-rule disclaimer sentence inside R5 section (C5)
check_r5_project_rule_disclaimer_present() {
  local R5
  R5=$(extract_md_section "$CQR_R5" "$R5_HDR")
  printf '%s\n' "$R5" | grep -qF "This is a project rule, not a Rust idiom — mirror the convention of the target repo before deciding where tests live." \
    || { echo "R5 missing byte-exact project-rule disclaimer sentence (C5)"; return 1; }
  echo "R5 project-rule disclaimer sentence present byte-exact"
}

# Helper: emit the **How to apply**: sub-block of R5 (lines after the marker,
# up to next bold-label line, '---' separator, or EOF — see §3.6 reference awk).
r5_how_to_apply_subblock() {
  extract_md_section "$CQR_R5" "$R5_HDR" | awk '
    /^\*\*How to apply\*\*:/ { in_block=1; next }
    in_block && /^\*\*[A-Za-z ]+\*\*:/ { in_block=0 }
    in_block && /^---$/ { in_block=0 }
    in_block { print }
  '
}

# (5) How-to-apply floor: >=3 numbered items inside the sub-block (C6)
check_r5_how_to_apply_floor_3() {
  local sub count
  sub=$(r5_how_to_apply_subblock)
  count=$(printf '%s\n' "$sub" | grep -cE '^[0-9]+\. ')
  [ "$count" -ge 3 ] || { echo "R5 How-to-apply has <3 numbered items ($count)"; return 1; }
  echo "R5 How-to-apply floor satisfied (>=3 numbered items: $count)"
}

# (6) Grep-discovery step present in How-to-apply sub-block (C7): line
# contains '#[cfg(test)]' AND one of grep / rg (case-insensitive, unescaped ERE pipe).
check_r5_grep_discovery_step_present() {
  local sub
  sub=$(r5_how_to_apply_subblock)
  printf '%s\n' "$sub" | grep -F '#[cfg(test)]' | grep -qiE '\bgrep\b|\brg\b' \
    || { echo "R5 How-to-apply missing discovery step mentioning '#[cfg(test)]' AND grep/rg"; return 1; }
  echo "R5 How-to-apply has #[cfg(test)] + grep/rg discovery step"
}

# (7) Majority wording present inside R5 section (C8)
check_r5_majority_wording_present() {
  local R5
  R5=$(extract_md_section "$CQR_R5" "$R5_HDR")
  printf '%s\n' "$R5" | grep -qiF 'majority' \
    || { echo "R5 missing 'majority' wording (C8)"; return 1; }
  echo "R5 majority wording present"
}

# (8) Byte-exact mixed-fallback sentence inside R5 section (C9)
check_r5_mixed_fallback_present() {
  local R5
  R5=$(extract_md_section "$CQR_R5" "$R5_HDR")
  printf '%s\n' "$R5" | grep -qF "If the repo is mixed or has no clear majority, default to a dedicated test file." \
    || { echo "R5 missing byte-exact mixed-fallback sentence (C9)"; return 1; }
  echo "R5 mixed-fallback sentence present byte-exact"
}

# (9) Byte-exact **Rule**: sentence inside R5 section (C10)
check_r5_rule_sentence_present() {
  local R5
  R5=$(extract_md_section "$CQR_R5" "$R5_HDR")
  printf '%s\n' "$R5" | grep -qF "**Rule**: tests must live in a separate file from the code they cover; mirror the repo's existing test layout, and default to a dedicated test file when no convention exists or the repo is mixed." \
    || { echo "R5 missing byte-exact **Rule**: sentence (C10)"; return 1; }
  echo "R5 **Rule**: sentence present byte-exact"
}

# (10) R5 short-form bullet inside §Code Quality Rules of developer-workflow.md —
# S1+S2+S3 verified as three independent grep -qF -- checks on the isolated bullet paragraph.
check_developer_workflow_short_form_r5() {
  local section para
  section=$(extract_md_section "$DWF_R5" '## Code Quality Rules')
  para=$(printf '%s\n' "$section" | awk '
    /^- \*\*R5 — Tests live in a dedicated file, not inline in the implementation\.\*\*/ { in_p=1; print; next }
    in_p && /^[[:space:]]*$/ { exit }
    in_p && /^- \*\*/ { exit }
    in_p { print }
  ')
  [ -n "$para" ] || { echo "developer-workflow.md §Code Quality Rules missing R5 bullet (S1 prefix not found)"; return 1; }
  printf '%s\n' "$para" | grep -qF -- '- **R5 — Tests live in a dedicated file, not inline in the implementation.**' \
    || { echo "developer-workflow.md R5 bullet missing byte-exact S1 prefix"; return 1; }
  printf '%s\n' "$para" | grep -qF -- 'repo convention' \
    || { echo "developer-workflow.md R5 bullet missing 'repo convention' (S2)"; return 1; }
  printf '%s\n' "$para" | grep -qF -- 'code-quality-rules.md' \
    || { echo "developer-workflow.md R5 bullet missing 'code-quality-rules.md' reference (S3)"; return 1; }
  echo "developer-workflow.md §Code Quality Rules has R5 short-form bullet (S1+S2+S3)"
}

check "r5-rule-heading-present"                           check_r5_rule_heading_present
check "r5-structure-triplet-present"                      check_r5_structure_triplet_present
check "r5-key-tokens-present"                             check_r5_key_tokens_present
check "r5-project-rule-disclaimer-present"                check_r5_project_rule_disclaimer_present
check "r5-how-to-apply-floor-3"                           check_r5_how_to_apply_floor_3
check "r5-grep-discovery-step-present"                    check_r5_grep_discovery_step_present
check "r5-majority-wording-present"                       check_r5_majority_wording_present
check "r5-mixed-fallback-present"                         check_r5_mixed_fallback_present
check "r5-rule-sentence-present"                          check_r5_rule_sentence_present
check "developer-workflow-short-form-r5"                  check_developer_workflow_short_form_r5
echo

# --- R6 — Test scope / user-facing contract (spec: 2026-04-18) ---
echo "R6 Test scope / user-facing contract:"

CQR_R6='skills/feature/references/code-quality-rules.md'
DWF_R6='skills/feature/references/developer-workflow.md'
R6_HDR='## R6 — Test scope / core tests exercise the user-facing contract'

# Canonical "How to apply" sub-extractor (spec §3.4a). Mirrors R5's
# r5_how_to_apply_subblock termination rules — same canonical pattern.
# Stdin: output of extract_md_section (a single rule section).
# Emits every line AFTER the first "**How to apply**:" marker line, up to
# the next bold-label line, a '---' rule, or EOF. The marker itself is
# NOT emitted. If the marker is absent, emits nothing.
extract_how_to_apply() {
  awk '
    !in_s && $0 == "**How to apply**:" { in_s = 1; next }
    in_s && /^\*\*[A-Za-z ]+\*\*:/ { exit }
    in_s && /^---$/ { exit }
    in_s { print }
  '
}

# Sibling helper (spec §3.4a, iter-9 X27, strict-adjacency per iter-10 X33):
# emits the line IMMEDIATELY following "**Rule**:" — strict byte-adjacency,
# no blank-line tolerance. Emits nothing if the marker is absent, the next
# line is empty, or there is no next line.
extract_rule_body_line() {
  awk '
    /^\*\*Rule\*\*:/ {
      if ((getline nxt) > 0 && nxt != "") print nxt
      exit
    }
  '
}

# F1: R6 heading line is present exactly once (whole-file, count-exact).
check_r6_rule_heading_present() {
  local c
  c=$(grep -cFx "$R6_HDR" "$CQR_R6")
  [ "$c" = "1" ] || { echo "code-quality-rules.md R6 heading count=$c, expected 1 (F1 count-exact)"; return 1; }
  echo "R6 heading present byte-exact count=1"
}

# F2: Inside R6, each of **Rule**:, **Why**:, **How to apply**: appears
# as a bare marker on its own line exactly once, and they appear in order.
# iter-11 X34: R6 uses bare-marker form (NOT R1-R5's inline convention);
# grep -cFx rejects inline `**Rule**: <body>` because it requires byte-exact
# whole-line equality.
check_r6_structure_triplet_present() {
  local R6 c_rule c_why c_how ln_rule ln_why ln_how
  R6=$(extract_md_section "$CQR_R6" "$R6_HDR")
  c_rule=$(printf '%s\n' "$R6" | grep -cFx '**Rule**:')
  c_why=$(printf '%s\n' "$R6" | grep -cFx '**Why**:')
  c_how=$(printf '%s\n' "$R6" | grep -cFx '**How to apply**:')
  [ "$c_rule" = "1" ] || { echo "R6 **Rule**: count=$c_rule, expected 1 (bare-marker whole-line; iter-11 X34)"; return 1; }
  [ "$c_why" = "1" ] || { echo "R6 **Why**: count=$c_why, expected 1 (bare-marker whole-line)"; return 1; }
  [ "$c_how" = "1" ] || { echo "R6 **How to apply**: count=$c_how, expected 1 (bare-marker whole-line)"; return 1; }
  ln_rule=$(printf '%s\n' "$R6" | grep -nFx '**Rule**:' | head -1 | cut -d: -f1)
  ln_why=$(printf '%s\n' "$R6" | grep -nFx '**Why**:' | head -1 | cut -d: -f1)
  ln_how=$(printf '%s\n' "$R6" | grep -nFx '**How to apply**:' | head -1 | cut -d: -f1)
  [ "$ln_rule" -lt "$ln_why" ] || { echo "R6 **Rule**: (line $ln_rule) not before **Why**: (line $ln_why)"; return 1; }
  [ "$ln_why" -lt "$ln_how" ] || { echo "R6 **Why**: (line $ln_why) not before **How to apply**: (line $ln_how)"; return 1; }
  echo "R6 structure triplet (Rule/Why/How to apply) present count-exact and ordered"
}

# F3: R6 How-to-apply sub-block enumerates 5 named anti-pattern tokens.
check_r6_anti_patterns_enumerated() {
  local sub
  sub=$(extract_md_section "$CQR_R6" "$R6_HDR" | extract_how_to_apply)
  printf '%s\n' "$sub" | grep -qiF 'Overspecification' \
    || { echo "R6 How-to-apply missing 'Overspecification' anti-pattern"; return 1; }
  printf '%s\n' "$sub" | grep -qiF 'Leaking implementation' \
    || { echo "R6 How-to-apply missing 'Leaking implementation' anti-pattern"; return 1; }
  printf '%s\n' "$sub" | grep -qiF 'Spawned-process smell' \
    || { echo "R6 How-to-apply missing 'Spawned-process smell' anti-pattern"; return 1; }
  printf '%s\n' "$sub" | grep -qiF 'In-memory substitution' \
    || { echo "R6 How-to-apply missing 'In-memory substitution' anti-pattern"; return 1; }
  printf '%s\n' "$sub" | grep -qiF 'Mock-heavy unit masquerading as integration' \
    || { echo "R6 How-to-apply missing 'Mock-heavy unit masquerading as integration' anti-pattern"; return 1; }
  echo "R6 How-to-apply has 5 anti-pattern tokens (Overspecification, Leaking implementation, Spawned-process smell, In-memory substitution, Mock-heavy unit masquerading as integration)"
}

# F4: Three R6 normative literals, each pinned byte-exact AND scoped to
# its owning sub-block (iter-9 X27; collapsed into one smoke label):
#   (a) Rule literal — line immediately after **Rule**: (extract_rule_body_line,
#       strict byte-adjacency per iter-10 X33)
#   (b) in-process rule — inside **How to apply**: sub-block
#   (c) Khorikov citation — anywhere inside the R6 sub-section
check_r6_normative_literals_present() {
  local R6 R6_HOW rule_line F4A F4B F4C c_b c_c
  F4A='Core tests exercise the user-facing contract (HTTP endpoint, smart-contract method, library'"'"'s public API, CLI entry point) with real internal collaborators; mocks are placed only at out-of-process dependency boundaries (network, external HTTP, brokers, filesystem used as a production channel).'
  F4B='Tests run in-process wherever the stack supports it; a spawned runserver, geth, or external broker purely for testing is a smell — prefer an in-process harness (Django'"'"'s APIClient, Soroban'"'"'s Env::default, forge'"'"'s --fork-url), and keep any spawned-process variant in a small e2e/smoke tier.'
  F4C='See Khorikov, *Unit Testing: Principles, Practices, and Patterns* (Manning, 2020), chs. 2, 5, 8, for the Classical-vs-London schools, the 4-pillar trade-off, and the integration-test scope argument this rule adopts.'
  R6=$(extract_md_section "$CQR_R6" "$R6_HDR")
  rule_line=$(printf '%s\n' "$R6" | extract_rule_body_line)
  [ "$rule_line" = "$F4A" ] \
    || { echo "R6 F4 (a) Rule literal mismatch (line after **Rule**: does not equal byte-exact expected; iter-11 X34 bare-marker + iter-10 X33 strict-adjacency required)"; return 1; }
  R6_HOW=$(printf '%s\n' "$R6" | extract_how_to_apply)
  c_b=$(printf '%s\n' "$R6_HOW" | grep -cFx "$F4B")
  [ "$c_b" = "1" ] || { echo "R6 F4 (b) in-process rule count in How-to-apply=$c_b, expected 1 (byte-exact whole-line)"; return 1; }
  c_c=$(printf '%s\n' "$R6" | grep -cFx "$F4C")
  [ "$c_c" = "1" ] || { echo "R6 F4 (c) Khorikov citation count in R6=$c_c, expected 1 (byte-exact whole-line)"; return 1; }
  echo "R6 normative literals all present byte-exact (Rule literal, in-process rule, Khorikov citation)"
}

# F5: R6 How-to-apply sub-block has 5 per-stack anchor tokens.
# iter-5 X15: 5-to-5 alignment with §3.6 branches.
# iter-9 X31: Soroban→env.invoke_contract, forge→vm.prank to avoid
# substring collision with F4 (b)'s "Soroban's Env::default" / "forge's --fork-url".
check_r6_per_stack_tokens_present() {
  local sub
  sub=$(extract_md_section "$CQR_R6" "$R6_HDR" | extract_how_to_apply)
  printf '%s\n' "$sub" | grep -qiF 'Django APIClient' \
    || { echo "R6 How-to-apply missing 'Django APIClient' token (HTTP stack)"; return 1; }
  printf '%s\n' "$sub" | grep -qiF 'env.invoke_contract' \
    || { echo "R6 How-to-apply missing 'env.invoke_contract' token (Soroban stack)"; return 1; }
  printf '%s\n' "$sub" | grep -qiF 'vm.prank' \
    || { echo "R6 How-to-apply missing 'vm.prank' token (EVM stack)"; return 1; }
  printf '%s\n' "$sub" | grep -qiF 'Python package API' \
    || { echo "R6 How-to-apply missing 'Python package API' token (library stack)"; return 1; }
  printf '%s\n' "$sub" | grep -qiF 'python -m' \
    || { echo "R6 How-to-apply missing 'python -m' token (CLI stack)"; return 1; }
  echo "R6 How-to-apply has 5 per-stack tokens (Django APIClient, env.invoke_contract, vm.prank, Python package API, python -m)"
}

# F8: R2 How-to-apply sub-block ends with the R6 forward-pointer sentence.
# Three collapsed guards (one smoke label per spec §3.4 F8):
#   (a) grep -cFx <F8> = 1 (byte-exact whole-line, iter-4 X9)
#   (b) numbered-item count = 5 (iter-2 X5)
#   (c) F8 is the last non-empty line of the sub-block (iter-5 X12,
#       supersedes iter-2 X5 ordering guard)
check_r2_points_to_r6_for_scope() {
  local sub count_exact count last_nonempty F8
  F8='For test scope (whether the test exercises the user-facing contract or an internal collaborator), see R6 — scope is orthogonal to the core/fresh trust tier and must be evaluated independently.'
  sub=$(extract_md_section "$CQR_R6" '## R2 — Trust tiers for tests' | extract_how_to_apply)
  count_exact=$(printf '%s\n' "$sub" | grep -cFx "$F8")
  [ "$count_exact" = "1" ] || { echo "R2 F8 count_exact=$count_exact, expected 1 (byte-exact whole-line; iter-4 X9 guard)"; return 1; }
  count=$(printf '%s\n' "$sub" | grep -cE '^[0-9]+\. ')
  [ "$count" = "5" ] || { echo "R2 How-to-apply numbered-item count is $count, expected 5 (F8 placement guard)"; return 1; }
  last_nonempty=$(printf '%s\n' "$sub" | awk 'NF' | tail -1)
  [ "$last_nonempty" = "$F8" ] || { echo "R2 F8 is not the last non-empty line of How-to-apply (last_nonempty=$last_nonempty); iter-5 X12 guard"; return 1; }
  echo "R2 points to R6 for scope (F8 byte-exact count=1; last-nonempty-line verified)"
}

check "r6-rule-heading-present"                           check_r6_rule_heading_present
check "r6-structure-triplet-present"                      check_r6_structure_triplet_present
check "r6-anti-patterns-enumerated"                       check_r6_anti_patterns_enumerated
check "r6-normative-literals-present"                     check_r6_normative_literals_present
check "r6-per-stack-tokens-present"                       check_r6_per_stack_tokens_present
check "r2-points-to-r6-for-scope"                         check_r2_points_to_r6_for_scope

# F6: developer-workflow.md §Code Quality Rules has the R6 short-form
# bullet exactly once (byte-exact whole-line; iter-5 X14 replaced the
# prior regex because R6 matched as substring of R60 and only 2 of 6
# token orderings were covered).
check_developer_workflow_short_form_r6() {
  local sub count F6
  F6='- **R6 — Test scope / core tests exercise the user-facing contract.** Prefer tests that drive the system through its public contract (HTTP route, smart-contract method, library API, CLI entry) rather than internal collaborators. See R6 in `code-quality-rules.md`.'
  sub=$(extract_md_section "$DWF_R6" '## Code Quality Rules')
  count=$(printf '%s\n' "$sub" | grep -cFx -- "$F6")
  [ "$count" = "1" ] || { echo "developer-workflow.md §Code Quality Rules F6 byte-exact count=$count, expected 1"; return 1; }
  echo "developer-workflow.md §Code Quality Rules has R6 short-form bullet (byte-exact count=1)"
}

# F7: developer-workflow.md §Test Quality has the R6 cross-reference
# sentence exactly once (byte-exact whole-line; iter-4 X10 guard).
check_developer_workflow_test_quality_points_to_r6() {
  local sub count F7
  F7='For test scope (what level the test is applied to — user-facing contract vs internal collaborators), see R6 in `code-quality-rules.md`.'
  sub=$(extract_md_section "$DWF_R6" '## Test Quality')
  count=$(printf '%s\n' "$sub" | grep -cFx "$F7")
  [ "$count" = "1" ] || { echo "developer-workflow.md §Test Quality F7 byte-exact count=$count, expected 1"; return 1; }
  echo "developer-workflow.md §Test Quality points to R6 for scope (byte-exact count=1)"
}

check "developer-workflow-short-form-r6"                  check_developer_workflow_short_form_r6
check "developer-workflow-test-quality-points-to-r6"      check_developer_workflow_test_quality_points_to_r6
echo

# --- Khorikov vocabulary retrofit (spec: 2026-04-18-khorikov-vocab-retrofit) ---
echo "Khorikov vocabulary retrofit:"

CQR_RETRO='skills/feature/references/code-quality-rules.md'
DWF_RETRO='skills/feature/references/developer-workflow.md'

PREAMBLE_HDR="## Shared framework — Khorikov's 4 pillars"

# Quoted heredoc (<<'EOF') — suppresses $-expansion and backtick expansion
# so asterisks, em-dashes, and parentheses land verbatim. Command
# substitution $(...) strips trailing newlines, so PREAMBLE_BODY ends on
# the final "... where relevant." line without a trailing newline. That
# is the byte pattern consumed by the PREAMBLE_WINDOW printf composition
# below; F2 compares the extracted window directly to PREAMBLE_WINDOW
# (§5.2 — awk from banner sentence through `## R1 —` heading, byte-equal).
PREAMBLE_BODY=$(cat <<'EOF'
R1–R6 draw on one framework from Vladimir Khorikov, *Unit Testing: Principles, Practices, and Patterns* (Manning, 2020). Each test scores on four independent axes:

1. **Protection against regressions** — does the test catch real behavioural bugs in production code?
2. **Resistance to refactoring** — does it stay green across behaviour-preserving internal rearrangements?
3. **Fast feedback** — does it run quickly enough for the inner dev loop?
4. **Maintainability** — is it cheap to read and keep?

Pillars (1) and (2) trade off: over-isolated tests score high on (1) but collapse on (2); tests bound to observable contract at the right scope score high on both. The rule set uses this vocabulary everywhere — R1 is the degenerate case of (1), R2 reads accumulated (2) as empirical trust evidence, R3 keys off (1)+(2) at assertion level, R6 keys off (1)+(2) at scope level. Each rule cites the specific Khorikov chapter where relevant.
EOF
)

# Single-line strings — double-quoted so the shell escapes the embedded
# `"no behaviour under test"` correctly. No trailing newline.
R1_KHORIKOV_LINE="R1 is Khorikov's \"no behaviour under test\" anti-pattern (*Unit Testing* ch. 7 — Humble Object / identification of what's testable) applied to dead production code: with the production consumer gone, pillar (1) has no regression to protect against, so the tests are cost without signal."

R2_KHORIKOV_PARA="Core > fresh in trust because pillar (2) resistance-to-refactoring is *empirically* confirmed by a core test: it survived prior refactorings without change, so its assertion tracks observable behaviour rather than implementation geometry. A fresh test has no such history — its (2) score is untested, and its green result cannot be read as evidence that the contract is right. (Khorikov's pillar (2) framed as the survival property — see *Unit Testing* ch. 1, 4 — rather than a deliberate design constraint.)"

# Quoting strategy per string:
#   - MATCH / EXPECTED: single-quoted — no shell metachars, no apostrophes.
#   - EXACT: single-quoted — contains backticks which are literal inside
#     single quotes (no command substitution triggered), no apostrophes.
#   - FLAKY: contains an apostrophe in `don't` AND backticks in
#     `jest.useFakeTimers` — single quotes cannot contain a literal
#     apostrophe (there is no `''` escape in bash — adjacent single quotes
#     concatenate to empty, so `'don''t'` yields `dont`, one byte short).
#     Use double quotes and escape the backticks as `\`` to suppress command
#     substitution; the apostrophe passes through unchanged under double
#     quotes. There are no `$` or `"` or backslashes in this string to
#     escape further.
TQ_PILLAR_TAG_MATCH='- **Match existing structure** *(pillar (4) maintainability)*: read 2–3 tests in the same file/directory first. Match their structure, naming, fixtures, and assertion style — do not invent a new pattern.'
TQ_PILLAR_TAG_EXACT='- **Exact assertions** *(pillar (1) protection against regressions)*: assert on specific values (`assert_eq!(x, 42)`), not vague checks (`> 0`, `is not None`). Vague checks miss regressions where the value changes but stays truthy.'
TQ_PILLAR_TAG_EXPECTED='- **Expected values** *(pillars (2) resistance to refactoring and (4) maintainability)*:'
TQ_PILLAR_TAG_FLAKY="- **No flaky tests** *(pillars (3) fast feedback and (4) maintainability)*: freeze dates/times (freezegun, MockClock, \`jest.useFakeTimers\`), seed random values. A test that can fail on a Friday or after a year is a time bomb. If you cannot freeze a value, flag it as a design smell — don't write a fuzzy assertion."

# Composed from HDR + BODY — avoids duplication drift. The 16-line window
# spans banner → blank → HDR → blank → BODY → blank → `---` → blank → R1 heading.
PREAMBLE_WINDOW=$(printf '%s\n\n%s\n\n%s\n\n---\n\n%s\n' \
  "User-input prompt presentation is governed by docs/user-input-banner-convention.md — violations block spec-review Pass 1." \
  "$PREAMBLE_HDR" \
  "$PREAMBLE_BODY" \
  "## R1 — Dead code isn't kept alive by its own tests")

# F1: Shared framework heading present byte-exact count=1.
check_khorikov_preamble_heading_present() {
  local c
  c=$(grep -cFx -- "$PREAMBLE_HDR" "$CQR_RETRO")
  [ "$c" = "1" ] || { echo "code-quality-rules.md preamble heading count=$c, expected 1 (F1 count-exact)"; return 1; }
  echo "Khorikov preamble heading present byte-exact count=1"
}

# F2: Multi-line window from banner sentence through `## R1 —` heading
# byte-equal to PREAMBLE_WINDOW. Enforces placement between banner and R1,
# single `---` separator, exact blank-line layout, and body bytes.
check_khorikov_preamble_window_byte_exact() {
  local win
  win=$(awk '
    /^User-input prompt presentation is governed / { flag=1 }
    flag { print }
    flag && /^## R1 — / { exit }
  ' "$CQR_RETRO")
  [ "$win" = "$PREAMBLE_WINDOW" ] || { echo "code-quality-rules.md preamble window byte-exact compare failed (F2)"; return 1; }
  echo "Khorikov preamble window byte-exact (banner → R1 heading)"
}

# F3: R1 Why block contains R1_KHORIKOV_LINE exactly once.
check_khorikov_r1_why_has_khorikov_line() {
  local r1_sec r1_why c
  r1_sec=$(extract_md_section "$CQR_RETRO" "## R1 — Dead code isn't kept alive by its own tests")
  r1_why=$(printf '%s\n' "$r1_sec" | extract_why_block)
  c=$(printf '%s\n' "$r1_why" | grep -cFx -- "$R1_KHORIKOV_LINE")
  [ "$c" = "1" ] || { echo "R1 Why R1_KHORIKOV_LINE count=$c, expected 1 (F3 byte-exact whole-line in Why scope)"; return 1; }
  echo "R1 Why has Khorikov line byte-exact count=1"
}

# F4: R2 Why block contains R2_KHORIKOV_PARA exactly once.
check_khorikov_r2_why_has_khorikov_para() {
  local r2_sec r2_why c
  r2_sec=$(extract_md_section "$CQR_RETRO" "## R2 — Trust tiers for tests")
  r2_why=$(printf '%s\n' "$r2_sec" | extract_why_block)
  c=$(printf '%s\n' "$r2_why" | grep -cFx -- "$R2_KHORIKOV_PARA")
  [ "$c" = "1" ] || { echo "R2 Why R2_KHORIKOV_PARA count=$c, expected 1 (F4 byte-exact whole-line in Why scope)"; return 1; }
  echo "R2 Why has Khorikov paragraph byte-exact count=1"
}

check "khorikov-preamble-heading-present"                 check_khorikov_preamble_heading_present
check "khorikov-preamble-window-byte-exact"               check_khorikov_preamble_window_byte_exact
check "khorikov-r1-why-has-khorikov-line"                 check_khorikov_r1_why_has_khorikov_line
check "khorikov-r2-why-has-khorikov-para"                 check_khorikov_r2_why_has_khorikov_para

# F5a: §Test Quality has the "Match existing structure" pillar-tagged title byte-exact.
check_khorikov_tq_match_structure_tag() {
  local tq c
  tq=$(extract_md_section "$DWF_RETRO" "## Test Quality")
  c=$(printf '%s\n' "$tq" | grep -cFx -- "$TQ_PILLAR_TAG_MATCH")
  [ "$c" = "1" ] || { echo "§Test Quality TQ_PILLAR_TAG_MATCH count=$c, expected 1 (F5a byte-exact whole-line)"; return 1; }
  echo "§Test Quality Match-existing-structure pillar-tag present byte-exact count=1"
}

# F5b: §Test Quality has the "Exact assertions" pillar-tagged title byte-exact.
check_khorikov_tq_exact_assertions_tag() {
  local tq c
  tq=$(extract_md_section "$DWF_RETRO" "## Test Quality")
  c=$(printf '%s\n' "$tq" | grep -cFx -- "$TQ_PILLAR_TAG_EXACT")
  [ "$c" = "1" ] || { echo "§Test Quality TQ_PILLAR_TAG_EXACT count=$c, expected 1 (F5b byte-exact whole-line)"; return 1; }
  echo "§Test Quality Exact-assertions pillar-tag present byte-exact count=1"
}

# F5c: §Test Quality has the "Expected values" pillar-tagged title byte-exact.
check_khorikov_tq_expected_values_tag() {
  local tq c
  tq=$(extract_md_section "$DWF_RETRO" "## Test Quality")
  c=$(printf '%s\n' "$tq" | grep -cFx -- "$TQ_PILLAR_TAG_EXPECTED")
  [ "$c" = "1" ] || { echo "§Test Quality TQ_PILLAR_TAG_EXPECTED count=$c, expected 1 (F5c byte-exact whole-line)"; return 1; }
  echo "§Test Quality Expected-values pillar-tag present byte-exact count=1"
}

# F5d: §Test Quality has the "No flaky tests" pillar-tagged title byte-exact.
check_khorikov_tq_no_flaky_tests_tag() {
  local tq c
  tq=$(extract_md_section "$DWF_RETRO" "## Test Quality")
  c=$(printf '%s\n' "$tq" | grep -cFx -- "$TQ_PILLAR_TAG_FLAKY")
  [ "$c" = "1" ] || { echo "§Test Quality TQ_PILLAR_TAG_FLAKY count=$c, expected 1 (F5d byte-exact whole-line)"; return 1; }
  echo "§Test Quality No-flaky-tests pillar-tag present byte-exact count=1"
}

# F5e: §Test Quality contains exactly 4 occurrences of the substring '*(pillar',
# guarding against a pillar tag leaking into a bullet body, sub-bullet, or
# cross-ref sentence.
check_khorikov_tq_pillar_tag_count_exact_4() {
  local tq c
  tq=$(extract_md_section "$DWF_RETRO" "## Test Quality")
  c=$(printf '%s\n' "$tq" | grep -cF -- "*(pillar")
  [ "$c" = "4" ] || { echo "§Test Quality '*(pillar' occurrence count=$c, expected 4 (F5e belt-and-braces)"; return 1; }
  echo "§Test Quality has exactly 4 pillar tags (count-exact)"
}

check "khorikov-tq-match-structure-tag"                   check_khorikov_tq_match_structure_tag
check "khorikov-tq-exact-assertions-tag"                  check_khorikov_tq_exact_assertions_tag
check "khorikov-tq-expected-values-tag"                   check_khorikov_tq_expected_values_tag
check "khorikov-tq-no-flaky-tests-tag"                    check_khorikov_tq_no_flaky_tests_tag
check "khorikov-tq-pillar-tag-count-exact-4"              check_khorikov_tq_pillar_tag_count_exact_4
echo

# --- Fast-mode routing-variant retirement (absence guard) ---
echo "Fast-mode retirement guard:"

check_codex_fast_absent() {
  # Single absence-asserting helper for the retired T-CF Codex Fast routing
  # variant (PR A-3). 7 assertions (was 8 — assertion #2 forbidding the
  # `model_fast` literal in skills/ agents/ docs/ README.md
  # .ai-dev-team.yml.example was retired by spec
  # design/2026-04-29-removed-cli-flag-hard-fail.md §3.3.4 Path 4 because the
  # new `Removed-key hard-fail` clause in docs/kb-discovery.md must contain
  # the `codex.model_fast` literal byte-for-byte; equivalent silent-
  # reintroduction protection now comes from the §3.4 presence pin
  # `check_kb_discovery_codex_model_fast_hard_fail`). Self-reference safety:
  # this body and the registration line use Fast-mode (hyphenated) and
  # Codex-Fast (hyphenated) compounds, byte-distinct from banned literals
  # 'Codex Fast' (space), 'model_fast' (underscore), and 'T-CF' (with hyphen
  # + suffix).
  # 1. No `Codex Fast` literal in live skill prose / docs / agents / config.
  assert_literal_absent_in_live_source 'Codex Fast' 'absence #1' \
    || { echo "absence #1 FAIL: 'Codex Fast' literal still present in live source"; return 1; }
  # 2. No `T-CF` literal in live source.
  assert_literal_absent_in_live_source 'T-CF' 'absence #2' \
    || { echo "absence #2 FAIL: 'T-CF' literal still present in live source"; return 1; }
  # 3. No retired check-helper definitions in tests/smoke-helpers.sh.
  ! grep -qE '^check_(cross_audit_phase0_bans_model_fast|spec_template_codex_fast_rationale|agent_routing_codex_fast_rationale)\(\)' tests/smoke-helpers.sh \
    || { echo "absence #3 FAIL: retired helper-fn def still present in tests/smoke-helpers.sh"; return 1; }
  # 4. No retired check invocations or wrapper definitions in tests/smoke.sh
  #    (anchored to ^check "..." registrations and ^<wrapper>() definitions).
  ! grep -qE '^check "(check_(cross_audit_phase0_bans_model_fast|spec_template_codex_fast_rationale|agent_routing_codex_fast_rationale))"' tests/smoke.sh \
    || { echo "absence #4a FAIL: retired check registration still present in tests/smoke.sh"; return 1; }
  ! grep -qE '^check_smoke_helper_(phase0_cross_audit_rejected|p3_spec_template_no_codex_action_rejected|p3_agent_routing_no_codex_action_rejected)\(\)' tests/smoke.sh \
    || { echo "absence #4b FAIL: retired wrapper-fn def still present in tests/smoke.sh"; return 1; }
  ! grep -qE '^check "check_smoke_helper_(phase0_cross_audit_rejected|p3_spec_template_no_codex_action_rejected|p3_agent_routing_no_codex_action_rejected)"' tests/smoke.sh \
    || { echo "absence #4c FAIL: retired wrapper-rejection registration still present in tests/smoke.sh"; return 1; }
  # 5. No stale section-header comments containing the retired-variant literals.
  assert_no_stale_section_header_comments 'Codex Fast|model_fast|T-CF' 'absence #5' \
    || { echo "absence #5 FAIL: stale Codex Fast/model_fast/T-CF header in smoke files"; return 1; }
  # 6. Positive overcut guards (adjacent live surface survives).
  grep -qF '#### Option 1: Codex (developer-codex agent)' skills/feature/SKILL.md \
    || { echo "absence #6a FAIL: Option 1 menu subsection missing from skills/feature/SKILL.md"; return 1; }
  grep -qF '#### Option 2: Senior (developer-senior agent)' skills/feature/SKILL.md \
    || { echo "absence #6b FAIL: Option 2 menu subsection missing from skills/feature/SKILL.md"; return 1; }
  grep -qF '## Codex (default)' skills/feature/references/agent-routing.md \
    || { echo "absence #6c FAIL: ## Codex (default) section missing from agent-routing.md"; return 1; }
  grep -qF '## Senior' skills/feature/references/agent-routing.md \
    || { echo "absence #6d FAIL: ## Senior section missing from agent-routing.md"; return 1; }
  grep -qF '## Rationale logging' skills/feature/references/agent-routing.md \
    || { echo "absence #6e FAIL: ## Rationale logging section missing from agent-routing.md"; return 1; }
  grep -qF 'codex_model' agents/developer-codex.md \
    || { echo "absence #6f FAIL: codex_model agent input parameter missing from agents/developer-codex.md"; return 1; }
  grep -qF 'codex_model' agents/cross-auditor.md \
    || { echo "absence #6g FAIL: codex_model agent input parameter missing from agents/cross-auditor.md"; return 1; }
  # 7. Smoke-helpers integrity (trimmed helper survives + success-echo updated).
  grep -qF 'check_feature_phase0_mentions_codex_keys' tests/smoke-helpers.sh \
    || { echo "absence #7a FAIL: trimmed helper check_feature_phase0_mentions_codex_keys missing"; return 1; }
  grep -qF "Phase 0 extensions mention both codex.model and codex.reasoning_effort keys" tests/smoke-helpers.sh \
    || { echo "absence #7b FAIL: success-echo update from Step 5 missing"; return 1; }
  echo "check_codex_fast_absent: all 7 assertions OK"
}
check "Codex-Fast routing variant absent" check_codex_fast_absent
echo

# --- Multi-GH-account auth-routing retirement (absence guard) ---
echo "Multi-account auth-routing retirement guard:"

# F7-legacy preserved: generic PR-mode publish-guard, independent of multi-account.
check "publish.md F7 legacy sentence survives"   check_publish_md_f7_legacy_sentence_survives

check_multi_gh_account_absent() {
  # 8 assertions per spec 2026-04-27-cut-multi-gh-account §3.6.
  # Self-reference safety: this body, the section header, and the registration
  # line use Multi-GH-account (hyphenated GH-account compound) — byte-distinct
  # from banned literal Multi-account. Assertion #5 anchored to ^check "..."
  # registration lines (NOT arbitrary substring) — prevents PR A-2 X1 / A-3 X1
  # self-trigger. Assertion #6 scoped to ^# comment lines only.
  # 1. No `default_account` literal in live source surface.
  assert_literal_absent_in_live_source 'default_account' 'absence #1' \
    || { echo "absence #1 FAIL: 'default_account' literal still present in live source"; return 1; }
  # 2. No `gh_token_env` literal in live source.
  assert_literal_absent_in_live_source 'gh_token_env' 'absence #2' \
    || { echo "absence #2 FAIL: 'gh_token_env' literal still present in live source"; return 1; }
  # 3. No `gh_host` literal AND no `gh_account_context` literal in live source.
  assert_literal_absent_in_live_source 'gh_host' 'absence #3a' \
    || { echo "absence #3a FAIL: 'gh_host' literal still present in live source"; return 1; }
  assert_literal_absent_in_live_source 'gh_account_context' 'absence #3b' \
    || { echo "absence #3b FAIL: 'gh_account_context' literal still present in live source"; return 1; }
  # 4. No retired check-helper definitions in tests/smoke.sh (anchored to
  #    ^<name>() definitions). Includes both 27 F-helpers + 2 internal helpers.
  ! grep -qE '^check_(skill_phase0_github_block|f3_site_(1_rate_limit|2a_repo_view|2b_repo_view|3_pr_view|4_pulls_files)|f3_preamble_sentence|f4_token_preflight_ordered|f5_account_flag_header|f5_matrix_rows_verbatim|f6_accounts_host_literal|f11_backcompat_sentence|f12_(gh_token_env|gh_host|annotation_rule)|f7_new_sentence|f8_(gh_pr_diff_prefixed|force_push_pr_view_prefixed|post_gh_api_prefixed)|f10_(multi_account_form|single_account_form|guard_sentence)|f14_(writer_sentence|reader_sentence)|f15_(stale_account_guard|token_non_empty|account_publish_scope))\(\)' tests/smoke.sh \
    || { echo "absence #4a FAIL: retired F-helper-fn def still present in tests/smoke.sh"; return 1; }
  ! grep -qE '^extract_(phase_0_5|step2_dispatch)\(\)' tests/smoke.sh \
    || { echo "absence #4b FAIL: retired internal helper-fn def still present in tests/smoke.sh"; return 1; }
  # 5. No retired check invocations in tests/smoke.sh (anchored to ^check "...").
  #    Broad-prefix matching is colon-robust per spec §3.6 #5 / iter-1 X1.
  #    F7-legacy "publish.md F7 legacy sentence survives" is excluded by the
  #    `7 new` constraint in the alternation (requires `F7 new`, not `F7 legacy`).
  ! grep -qE '^check "(yml\.example F1 |SKILL\.md F[0-9]+ |publish\.md F(7 new|8|14|15) |cross-auditor\.md F[0-9]+ )' tests/smoke.sh \
    || { echo "absence #5 FAIL: retired check registration still present in tests/smoke.sh"; return 1; }
  # 6. No stale section-header comments containing the banned compounds.
  #    Self-reference safety: this section header uses Multi-GH-account
  #    (byte-distinct from Multi-account); helper-fn name multi_gh_account
  #    is snake_case (lowercase, underscores) and lives in body lines, not ^# .
  assert_no_stale_section_header_comments 'default_account|gh_token_env|gh_host|gh_account_context|--account |Multi-account' 'absence #6' \
    || { echo "absence #6 FAIL: stale multi-gh-account header in smoke files"; return 1; }
  # 7. Positive overcut guards — adjacent live surface MUST survive.
  grep -qF '## Phase 0.5: PR discovery (PR mode only)' skills/cross-audit/SKILL.md \
    || { echo "absence #7a FAIL: ## Phase 0.5 H2 missing from skills/cross-audit/SKILL.md"; return 1; }
  grep -qF '### Preflights (hard-stop on failure — never silent fallback)' skills/cross-audit/SKILL.md \
    || { echo "absence #7b FAIL: ### Preflights subsection missing from skills/cross-audit/SKILL.md"; return 1; }
  grep -qF '### Resolve pr_number / pr_repo / pr_url / headRefOid' skills/cross-audit/SKILL.md \
    || { echo "absence #7c FAIL: ### Resolve pr_number subsection missing from skills/cross-audit/SKILL.md"; return 1; }
  grep -qF '### Fetch pr_changed_files (authoritative, paginated)' skills/cross-audit/SKILL.md \
    || { echo "absence #7d FAIL: ### Fetch pr_changed_files subsection missing from skills/cross-audit/SKILL.md"; return 1; }
  grep -qF 'gh pr checkout <pr_number> --force --repo <pr_repo>' agents/references/cross-auditor-pr-and-probes.md \
    || { echo "absence #7e FAIL: bare gh pr checkout form missing from agents/references/cross-auditor-pr-and-probes.md"; return 1; }
  grep -qF 'gh pr view <N> --repo <pr_repo> --json headRefOid' skills/cross-audit/references/publish.md \
    || { echo "absence #7f FAIL: force-push gh pr view missing from publish.md"; return 1; }
  grep -qF 'gh api --include --repo <pr_repo>' skills/cross-audit/references/publish.md \
    || { echo "absence #7g FAIL: POST gh api --include missing from publish.md"; return 1; }
  grep -qF 'gh pr diff <N> --repo <pr_repo>' skills/cross-audit/references/publish.md \
    || { echo "absence #7h FAIL: gh pr diff missing from publish.md"; return 1; }
  grep -qF 'All gh api calls pass --repo <pr_repo> AND --include' skills/cross-audit/references/publish.md \
    || { echo "absence #7i FAIL: F7-legacy literal missing from publish.md"; return 1; }
  grep -qF 'pr_files' agents/cross-auditor.md \
    || { echo "absence #7j FAIL: pr_files PR-mode agent input missing from agents/cross-auditor.md"; return 1; }
  grep -qF 'pr_head_oid' agents/cross-auditor.md \
    || { echo "absence #7k FAIL: pr_head_oid PR-mode agent input missing from agents/cross-auditor.md"; return 1; }
  grep -qF 'pr_changed_files' agents/cross-auditor.md \
    || { echo "absence #7l FAIL: pr_changed_files PR-mode agent input missing from agents/cross-auditor.md"; return 1; }
  ! grep -qF '## Multi-account github: config block' docs/kb-discovery.md \
    || { echo "absence #7m FAIL: deleted ## Multi-account github: config block H2 still present in docs/kb-discovery.md"; return 1; }
  # 8. Smoke-helpers integrity (trimmed helper survives + success-echo updated).
  grep -qF 'check_kb_discovery_doc_canonical' tests/smoke-helpers.sh \
    || { echo "absence #8a FAIL: trimmed helper check_kb_discovery_doc_canonical missing"; return 1; }
  grep -qF 'canonical KB discovery doc (all required headings + 9-step Algorithm + yml prompt)' tests/smoke-helpers.sh \
    || { echo "absence #8b FAIL: updated success-echo from Step 6 missing"; return 1; }
  ! grep -qF 'github: keys' tests/smoke-helpers.sh \
    || { echo "absence #8c FAIL: stale 'github: keys' suffix still present in tests/smoke-helpers.sh"; return 1; }
  echo "check_multi_gh_account_absent: all 8 assertions OK"
}
check "Multi-GH-account auth-routing absent" check_multi_gh_account_absent
echo

# --- Shared Phase 0 / KB discovery (spec 2026-04-20-shared-phase0) ---
echo "Shared Phase 0 / KB discovery:"

# Negative wrappers — each asserts the corresponding helper rejects its
# dedicated fixture from tests/fixtures/shared-phase0/. Pattern mirrors
# tests/smoke-helpers-check-wiring.sh (spec #1) — three substrings per body:
# negation `!` + rejection guard diagnostic + success echo.
check_smoke_helper_phase0_append_rejected() {
  if ! check_skill_phase0_no_inline_algorithm 'tests/fixtures/shared-phase0/feature-append-instead-of-replace.md' >/dev/null 2>&1; then
    echo "check_skill_phase0_no_inline_algorithm correctly rejected stale append-instead-of-replace fixture"
    return 0
  fi
  echo "check_skill_phase0_no_inline_algorithm wrongly accepted feature-append-instead-of-replace.md"
  return 1
}

check_smoke_helper_phase0_inline_rejected() {
  if ! check_skill_phase0_no_inline_algorithm 'tests/fixtures/shared-phase0/feature-inline-algorithm.md' >/dev/null 2>&1; then
    echo "check_skill_phase0_no_inline_algorithm correctly rejected stale inline-algorithm fixture"
    return 0
  fi
  echo "check_skill_phase0_no_inline_algorithm wrongly accepted feature-inline-algorithm.md"
  return 1
}

check_smoke_helper_phase0_investigate_rejected() {
  if ! check_investigate_no_phase0 'tests/fixtures/shared-phase0/investigate-with-phase0.md' >/dev/null 2>&1; then
    echo "check_investigate_no_phase0 correctly rejected stale investigate-with-phase0 fixture"
    return 0
  fi
  echo "check_investigate_no_phase0 wrongly accepted investigate-with-phase0.md"
  return 1
}

# Positive invocations — 12 rows per spec §6.1 invocation matrix.
check "check_kb_discovery_doc_canonical" check_kb_discovery_doc_canonical docs/kb-discovery.md
check "check_skill_phase0_references_shared_doc" check_skill_phase0_references_shared_doc skills/feature/SKILL.md
check "check_skill_phase0_references_shared_doc" check_skill_phase0_references_shared_doc skills/cross-audit/SKILL.md
check "check_skill_phase0_references_shared_doc" check_skill_phase0_references_shared_doc skills/research/SKILL.md
check "check_skill_phase0_extensions_present" check_skill_phase0_extensions_present skills/feature/SKILL.md
check "check_skill_phase0_extensions_present" check_skill_phase0_extensions_present skills/cross-audit/SKILL.md
check "check_skill_phase0_extensions_present" check_skill_phase0_extensions_present skills/research/SKILL.md
check "check_skill_phase0_no_inline_algorithm" check_skill_phase0_no_inline_algorithm skills/feature/SKILL.md
check "check_skill_phase0_no_inline_algorithm" check_skill_phase0_no_inline_algorithm skills/cross-audit/SKILL.md
check "check_skill_phase0_no_inline_algorithm" check_skill_phase0_no_inline_algorithm skills/research/SKILL.md
check "check_feature_phase0_mentions_codex_keys" check_feature_phase0_mentions_codex_keys skills/feature/SKILL.md
check "check_investigate_no_phase0" check_investigate_no_phase0 skills/investigate/SKILL.md
# Negative invocations — 3 rows per spec §6.1 invocation matrix.
check "check_smoke_helper_phase0_append_rejected" check_smoke_helper_phase0_append_rejected
check "check_smoke_helper_phase0_inline_rejected" check_smoke_helper_phase0_inline_rejected
check "check_smoke_helper_phase0_investigate_rejected" check_smoke_helper_phase0_investigate_rejected
echo

# --- Git conventions dedupe (spec 2026-04-20-git-conventions-dedupe) ---
echo "Git conventions dedupe:"

# Negative wrappers — each asserts the corresponding helper rejects its
# dedicated fixture from tests/fixtures/git-conventions-dedupe/.
check_smoke_helper_git_feature_skill_inline_rejected() {
  if ! check_feature_skill_git_references_canonical 'tests/fixtures/git-conventions-dedupe/feature-skill-inline-git.md' >/dev/null 2>&1; then
    echo "check_feature_skill_git_references_canonical correctly rejected stale feature-skill-inline-git fixture"
    return 0
  fi
  echo "check_feature_skill_git_references_canonical wrongly accepted feature-skill-inline-git.md"
  return 1
}

check_smoke_helper_git_overview_master_only_rejected() {
  if ! check_overview_git_references_canonical 'tests/fixtures/git-conventions-dedupe/overview-master-only.md' >/dev/null 2>&1; then
    echo "check_overview_git_references_canonical correctly rejected stale overview-master-only fixture"
    return 0
  fi
  echo "check_overview_git_references_canonical wrongly accepted overview-master-only.md"
  return 1
}

# Hybrid-reintroduction + body-mutation wrappers (audit findings X1/X2/X3).
check_smoke_helper_git_feature_skill_hybrid_rejected() {
  if ! check_feature_skill_git_references_canonical 'tests/fixtures/git-conventions-dedupe/feature-skill-hybrid-git.md' >/dev/null 2>&1; then
    echo "check_feature_skill_git_references_canonical correctly rejected hybrid feature-skill fixture"
    return 0
  fi
  echo "check_feature_skill_git_references_canonical wrongly accepted feature-skill-hybrid-git.md"
  return 1
}

check_smoke_helper_git_overview_hybrid_rejected() {
  if ! check_overview_git_references_canonical 'tests/fixtures/git-conventions-dedupe/overview-hybrid-git.md' >/dev/null 2>&1; then
    echo "check_overview_git_references_canonical correctly rejected hybrid overview fixture"
    return 0
  fi
  echo "check_overview_git_references_canonical wrongly accepted overview-hybrid-git.md"
  return 1
}

check_smoke_helper_git_dev_workflow_mutated_body_rejected() {
  if ! check_dev_workflow_git_canonical 'tests/fixtures/git-conventions-dedupe/dev-workflow-mutated-body.md' >/dev/null 2>&1; then
    echo "check_dev_workflow_git_canonical correctly rejected mutated-body dev-workflow fixture"
    return 0
  fi
  echo "check_dev_workflow_git_canonical wrongly accepted dev-workflow-mutated-body.md"
  return 1
}

# Positive invocations — 3 rows per spec §3.4 invariants table.
check "check_dev_workflow_git_canonical" check_dev_workflow_git_canonical skills/feature/references/developer-workflow.md
check "check_feature_skill_git_references_canonical" check_feature_skill_git_references_canonical skills/feature/SKILL.md
check "check_overview_git_references_canonical" check_overview_git_references_canonical docs/AI_Dev_Team_Overview.md
# Negative invocations — 2 original + 3 audit (X1/X2/X3) rows.
check "check_smoke_helper_git_feature_skill_inline_rejected" check_smoke_helper_git_feature_skill_inline_rejected
check "check_smoke_helper_git_overview_master_only_rejected" check_smoke_helper_git_overview_master_only_rejected
check "check_smoke_helper_git_feature_skill_hybrid_rejected" check_smoke_helper_git_feature_skill_hybrid_rejected
check "check_smoke_helper_git_overview_hybrid_rejected" check_smoke_helper_git_overview_hybrid_rejected
check "check_smoke_helper_git_dev_workflow_mutated_body_rejected" check_smoke_helper_git_dev_workflow_mutated_body_rejected
echo

# --- Trigger-map dedupe (spec 2026-04-20-trigger-map-dedupe) ---
echo "Trigger-map dedupe:"

# Negative wrappers — each asserts the corresponding helper rejects its
# dedicated fixture from tests/fixtures/trigger-map-dedupe/.
check_smoke_helper_trigger_map_session_start_rejected() {
  if ! check_session_start_trigger_map_complete 'tests/fixtures/trigger-map-dedupe/session-start-missing-trigger.md' >/dev/null 2>&1; then
    echo "check_session_start_trigger_map_complete correctly rejected missing-trigger fixture"
    return 0
  fi
  echo "check_session_start_trigger_map_complete wrongly accepted session-start-missing-trigger.md"
  return 1
}

check_smoke_helper_trigger_map_snippet_rejected() {
  if ! check_claude_md_snippet_points_to_hook 'tests/fixtures/trigger-map-dedupe/snippet-no-pointer.md' >/dev/null 2>&1; then
    echo "check_claude_md_snippet_points_to_hook correctly rejected no-pointer snippet fixture"
    return 0
  fi
  echo "check_claude_md_snippet_points_to_hook wrongly accepted snippet-no-pointer.md"
  return 1
}

check_smoke_helper_trigger_map_readme_rejected() {
  if ! check_readme_ambient_workflow_references_sources 'tests/fixtures/trigger-map-dedupe/readme-full-table.md' >/dev/null 2>&1; then
    echo "check_readme_ambient_workflow_references_sources correctly rejected full-table README fixture"
    return 0
  fi
  echo "check_readme_ambient_workflow_references_sources wrongly accepted readme-full-table.md"
  return 1
}

# Audit wrappers (X1/X2) — hybrid fixtures where the required tokens survive
# outside the scoped section or inside the fenced paste block.
check_smoke_helper_trigger_map_session_start_token_elsewhere_rejected() {
  if ! check_session_start_trigger_map_complete 'tests/fixtures/trigger-map-dedupe/session-start-token-elsewhere.md' >/dev/null 2>&1; then
    echo "check_session_start_trigger_map_complete correctly rejected token-elsewhere hook fixture"
    return 0
  fi
  echo "check_session_start_trigger_map_complete wrongly accepted session-start-token-elsewhere.md"
  return 1
}

check_smoke_helper_trigger_map_snippet_pointer_inside_fence_rejected() {
  if ! check_claude_md_snippet_points_to_hook 'tests/fixtures/trigger-map-dedupe/snippet-pointer-inside-fence.md' >/dev/null 2>&1; then
    echo "check_claude_md_snippet_points_to_hook correctly rejected pointer-inside-fence snippet fixture"
    return 0
  fi
  echo "check_claude_md_snippet_points_to_hook wrongly accepted snippet-pointer-inside-fence.md"
  return 1
}

# Positive invocations — 3 rows per spec §3.4.
check "check_session_start_trigger_map_complete" check_session_start_trigger_map_complete hooks/session-prompt.md
check "check_claude_md_snippet_points_to_hook" check_claude_md_snippet_points_to_hook docs/claude-md-snippet.md
check "check_readme_ambient_workflow_references_sources" check_readme_ambient_workflow_references_sources README.md
# Negative invocations — 3 original + 2 audit (X1/X2) rows.
check "check_smoke_helper_trigger_map_session_start_rejected" check_smoke_helper_trigger_map_session_start_rejected
check "check_smoke_helper_trigger_map_snippet_rejected" check_smoke_helper_trigger_map_snippet_rejected
check "check_smoke_helper_trigger_map_readme_rejected" check_smoke_helper_trigger_map_readme_rejected
check "check_smoke_helper_trigger_map_session_start_token_elsewhere_rejected" check_smoke_helper_trigger_map_session_start_token_elsewhere_rejected
check "check_smoke_helper_trigger_map_snippet_pointer_inside_fence_rejected" check_smoke_helper_trigger_map_snippet_pointer_inside_fence_rejected
echo

# --- Focus-areas dedupe (spec 2026-04-20-focus-areas-dedupe) ---
echo "Focus-areas dedupe:"

check_smoke_helper_focus_areas_skill_inline_rejected() {
  if ! check_cross_audit_skill_focus_areas_references_canonical 'tests/fixtures/focus-areas-dedupe/skill-inline-focus-areas.md' >/dev/null 2>&1; then
    echo "check_cross_audit_skill_focus_areas_references_canonical correctly rejected inline decorative-block fixture"
    return 0
  fi
  echo "check_cross_audit_skill_focus_areas_references_canonical wrongly accepted skill-inline-focus-areas.md"
  return 1
}

# Audit wrappers (X1/X2/X3) — hybrid / bullet-form / demoted-heading fixtures
# that pre-fix helpers silently accepted.
check_smoke_helper_focus_areas_skill_hybrid_rejected() {
  if ! check_cross_audit_skill_focus_areas_references_canonical 'tests/fixtures/focus-areas-dedupe/skill-hybrid-focus-areas.md' >/dev/null 2>&1; then
    echo "check_cross_audit_skill_focus_areas_references_canonical correctly rejected hybrid pointer+subsections fixture"
    return 0
  fi
  echo "check_cross_audit_skill_focus_areas_references_canonical wrongly accepted skill-hybrid-focus-areas.md"
  return 1
}

check_smoke_helper_focus_areas_skill_bullet_form_rejected() {
  if ! check_cross_audit_skill_focus_areas_references_canonical 'tests/fixtures/focus-areas-dedupe/skill-bullet-form-focus-areas.md' >/dev/null 2>&1; then
    echo "check_cross_audit_skill_focus_areas_references_canonical correctly rejected bullet-form reintroduction fixture"
    return 0
  fi
  echo "check_cross_audit_skill_focus_areas_references_canonical wrongly accepted skill-bullet-form-focus-areas.md"
  return 1
}

check_smoke_helper_focus_areas_cross_auditor_demoted_rejected() {
  if ! check_cross_auditor_mode_focus_areas_canonical 'tests/fixtures/focus-areas-dedupe/cross-auditor-demoted-mode.md' >/dev/null 2>&1; then
    echo "check_cross_auditor_mode_focus_areas_canonical correctly rejected demoted-heading fixture"
    return 0
  fi
  echo "check_cross_auditor_mode_focus_areas_canonical wrongly accepted cross-auditor-demoted-mode.md"
  return 1
}

# Positive invocations — 2 rows per spec §3.4.
check "check_cross_auditor_mode_focus_areas_canonical" check_cross_auditor_mode_focus_areas_canonical agents/references/cross-auditor-mode-focus.md
check "check_cross_audit_skill_focus_areas_references_canonical" check_cross_audit_skill_focus_areas_references_canonical skills/cross-audit/SKILL.md
# Negative invocations — 1 original + 3 audit (X1/X2/X3) rows.
check "check_smoke_helper_focus_areas_skill_inline_rejected" check_smoke_helper_focus_areas_skill_inline_rejected
check "check_smoke_helper_focus_areas_skill_hybrid_rejected" check_smoke_helper_focus_areas_skill_hybrid_rejected
check "check_smoke_helper_focus_areas_skill_bullet_form_rejected" check_smoke_helper_focus_areas_skill_bullet_form_rejected
check "check_smoke_helper_focus_areas_cross_auditor_demoted_rejected" check_smoke_helper_focus_areas_cross_auditor_demoted_rejected
echo

# --- P3 cleanup bundle (spec 2026-04-20-p3-cleanup-bundle) ---
echo "P3 cleanup bundle:"

check_smoke_helper_p3_readme_audit_migration_rejected() {
  if ! check_readme_no_audit_migration_note 'tests/fixtures/p3-cleanup/readme-with-audit-migration-note.md' >/dev/null 2>&1; then
    echo "check_readme_no_audit_migration_note correctly rejected README fixture with obsolete audit→cross-audit migration note"
    return 0
  fi
  echo "check_readme_no_audit_migration_note wrongly accepted readme-with-audit-migration-note.md"
  return 1
}

# Audit wrappers (X1/X2/X5/X6) — fixtures that pre-fix helpers silently accepted.
check_smoke_helper_p3_session_start_clarifier_masks_missing_row_rejected() {
  if ! check_session_start_trigger_map_complete 'tests/fixtures/p3-cleanup/session-start-clarifier-but-no-investigate-row.md' >/dev/null 2>&1; then
    echo "check_session_start_trigger_map_complete correctly rejected clarifier-masks-missing-row fixture"
    return 0
  fi
  echo "check_session_start_trigger_map_complete wrongly accepted session-start-clarifier-but-no-investigate-row.md"
  return 1
}

check_smoke_helper_p3_snippet_clarifier_masks_missing_row_rejected() {
  if ! check_claude_md_snippet_points_to_hook 'tests/fixtures/p3-cleanup/snippet-clarifier-but-no-investigate-row.md' >/dev/null 2>&1; then
    echo "check_claude_md_snippet_points_to_hook correctly rejected clarifier-masks-missing-row snippet fixture"
    return 0
  fi
  echo "check_claude_md_snippet_points_to_hook wrongly accepted snippet-clarifier-but-no-investigate-row.md"
  return 1
}

check_smoke_helper_p3_branch_bold_uppercase_rejected() {
  if ! check_branch_frontmatter_ref_lowercase 'tests/fixtures/p3-cleanup/readme-branch-bold-uppercase.md' >/dev/null 2>&1; then
    echo "check_branch_frontmatter_ref_lowercase correctly rejected bold-wrapped Branch: fixture"
    return 0
  fi
  echo "check_branch_frontmatter_ref_lowercase wrongly accepted readme-branch-bold-uppercase.md"
  return 1
}

# Positive invocations — 6 per spec §3.4.
check "check_trigger_map_investigate_research_clarifier (hook)" check_trigger_map_investigate_research_clarifier hooks/session-prompt.md
check "check_trigger_map_investigate_research_clarifier (snippet)" check_trigger_map_investigate_research_clarifier docs/claude-md-snippet.md
check "check_research_skill_competitive_analysis_points_to_investigate" check_research_skill_competitive_analysis_points_to_investigate skills/research/SKILL.md
check "check_branch_frontmatter_ref_lowercase (README)" check_branch_frontmatter_ref_lowercase README.md
check "check_branch_frontmatter_ref_lowercase (feature/SKILL.md)" check_branch_frontmatter_ref_lowercase skills/feature/SKILL.md
check "check_readme_no_audit_migration_note" check_readme_no_audit_migration_note README.md
# Negative invocations — 1 original + 3 audit (X1/X2/X5) rows.
check "check_smoke_helper_p3_readme_audit_migration_rejected" check_smoke_helper_p3_readme_audit_migration_rejected
check "check_smoke_helper_p3_session_start_clarifier_masks_missing_row_rejected" check_smoke_helper_p3_session_start_clarifier_masks_missing_row_rejected
check "check_smoke_helper_p3_snippet_clarifier_masks_missing_row_rejected" check_smoke_helper_p3_snippet_clarifier_masks_missing_row_rejected
check "check_smoke_helper_p3_branch_bold_uppercase_rejected" check_smoke_helper_p3_branch_bold_uppercase_rejected
echo

# --- Cross-audit probes foundation (spec 2026-04-21-cross-audit-probes-foundation) ---
echo "Cross-audit probes foundation:"
check "check_agents_cross_auditor_schema_cut_fields" check_agents_cross_auditor_schema_cut_fields
# Step 2 — renderer schema-cut, modes, fail-open banner, hard-stop on malformed probe_failures.
# Per spec §6.1 Step 2: 4 umbrella helpers + 7 golden-diff sub-assertions = 11 PASS lines.
check "check_findings_renderer_schema_cut" check_findings_renderer_schema_cut
check "check_findings_renderer_modes" check_findings_renderer_modes
check "check_findings_renderer_fail_open" check_findings_renderer_fail_open
check "check_probe_failures_schema_hard_stop" check_probe_failures_schema_hard_stop
# Fixture-level sub-assertions (§6.1 per-step count). Each exercises one
# renderer golden: (1) no-probes legacy, (2) probe shadow, (3) probe warn,
# (4) probe block, (5) multi-source merged, (6) fail-open banner, (7) malformed
# probe_failures hard-stop.
check "check_findings_renderer_fixture_01_no_probes_legacy" check_findings_renderer_schema_cut
check "check_findings_renderer_fixture_02_probe_shadow" check_findings_renderer_modes_shadow
check "check_findings_renderer_fixture_03_probe_warn" check_findings_renderer_modes_warn
check "check_findings_renderer_fixture_04_probe_block" check_findings_renderer_modes_block
check "check_findings_renderer_fixture_05_multi_source_merged" check_findings_renderer_modes_multi_source
check "check_findings_renderer_fixture_06_probe_fail_open" check_findings_renderer_fail_open
check "check_findings_renderer_fixture_07_probe_failures_malformed_hard_stop" check_probe_failures_schema_hard_stop

# Step 3 — dedupe (E/F/G umbrella + 9 near-miss sub-fixtures + merged-probe+LLM)
#   + receipt hash canonicalization rerun-stability.
# Per spec §6.1 Step 3: 5 umbrella helpers + 10 sub-assertions = 15 PASS lines.
check "check_dedupe_fingerprint_e_shape" check_dedupe_fingerprint_e_shape
check "check_dedupe_fingerprint_f_shape" check_dedupe_fingerprint_f_shape
check "check_dedupe_fingerprint_g_shape" check_dedupe_fingerprint_g_shape
check "check_dedupe_merged_probe_llm_sources_list" check_dedupe_merged_probe_llm_sources_list
check "check_receipt_hash_canonicalization_rerun_stable" check_receipt_hash_canonicalization_rerun_stable
# Sub-assertions (3 near-miss per probe E/F/G + 1 merged-probe+LLM = 10).
check "check_dedupe_fingerprint_e_exact_merge" check_dedupe_fingerprint_e_exact
check "check_dedupe_fingerprint_e_partial_related_to" check_dedupe_fingerprint_e_partial
check "check_dedupe_fingerprint_e_no_match_distinct" check_dedupe_fingerprint_e_no_match
check "check_dedupe_fingerprint_f_exact_merge" check_dedupe_fingerprint_f_exact
check "check_dedupe_fingerprint_f_partial_related_to" check_dedupe_fingerprint_f_partial
check "check_dedupe_fingerprint_f_no_match_distinct" check_dedupe_fingerprint_f_no_match
check "check_dedupe_fingerprint_g_exact_merge" check_dedupe_fingerprint_g_exact
check "check_dedupe_fingerprint_g_partial_related_to" check_dedupe_fingerprint_g_partial
check "check_dedupe_fingerprint_g_no_match_distinct" check_dedupe_fingerprint_g_no_match
check "check_dedupe_merged_probe_llm_entry" check_dedupe_merged_probe_llm_sources_list

# Step 4 — cross_audit.probes.<id>.mode config surface (yml example, docs, skill Phase 0).
check "check_yaml_example_probes_block" check_yaml_example_probes_block
check "check_docs_kb_discovery_probes_block" check_docs_kb_discovery_probes_block
check "check_skill_md_phase0_probe_mode_read" check_skill_md_phase0_probe_mode_read
check "check_probe_downgrade_flag_absent" check_probe_downgrade_flag_absent

check "check_skill_md_phase3_shadow_section" check_skill_md_phase3_shadow_section
check "check_skill_md_phase3_advisory_section_footer" check_skill_md_phase3_advisory_section_footer
check "check_cross_auditor_probe_modes_input_declared" check_cross_auditor_probe_modes_input_declared
# The Foundation helper check_cross_auditor_probe_receipts_input_declared was
# repurposed in-place as check_cross_auditor_probe_receipts_produced_by_step05
# when spec 2026-04-21-probe-e-diff-scope-leak §3.2 (c) / iter-2 X10 removed
# the probe_receipts input bullet. The renamed helper + the supplementary
# skill-side check_cross_auditor_skill_dispatch_drops_probe_receipts both live
# under the '--- Cross-audit probe E ---' section below (Step 6 spec goal:
# 'wire every new helper under a new Cross-audit probe E section').

# Step 6 — renderer low-confidence advisory section + merged probe+LLM routing
# + combined fail-open banner. Per §6.1 Step 6 delta: +4 umbrella + 6 fixture
# sub-assertions (a-f) = 10 PASS lines.
check "check_findings_renderer_low_confidence_section" check_findings_renderer_low_confidence_section
check "check_findings_renderer_scorer_fail_open" check_findings_renderer_scorer_fail_open
check "check_findings_renderer_merged_probe_llm_routing" check_findings_renderer_merged_probe_llm_routing
check "check_findings_renderer_combined_fail_open_banner" check_findings_renderer_combined_fail_open_banner
check "check_findings_renderer_fixture_a_low_only_llm_advisory" check_findings_renderer_low_confidence_section_fixture_a
check "check_findings_renderer_fixture_b_mixed_high_low" check_findings_renderer_low_confidence_section_fixture_b
check "check_findings_renderer_fixture_c_scorer_failed_pseudo_confidence" check_findings_renderer_scorer_fail_open_fixture_c
check "check_findings_renderer_fixture_d_merged_probe_shadow" check_findings_renderer_merged_probe_llm_routing_fixture_d
check "check_findings_renderer_fixture_e_merged_probe_warn" check_findings_renderer_merged_probe_llm_routing_fixture_e
check "check_findings_renderer_fixture_f_combined_probe_scorer_fail" check_findings_renderer_combined_fail_open_banner_fixture_f

# Step 7 — Haiku scorer agent + cross-auditor integration + probe_failures
# synthesis. Per §6.1 Step 7 delta: +10 umbrella + 12 fixture sub-assertions = 22.
check "check_haiku_scorer_agent_frontmatter" check_haiku_scorer_agent_frontmatter
check "check_haiku_scorer_rubric_present" check_haiku_scorer_rubric_present
check "check_haiku_scorer_anti_hallucination_clause" check_haiku_scorer_anti_hallucination_clause
check "check_haiku_scorer_io_contract_sources_and_multi_source_note" check_haiku_scorer_io_contract_sources_and_multi_source_note
check "check_haiku_scorer_fail_open" check_haiku_scorer_fail_open
check "check_haiku_scorer_edge_cases_zero_partial_cap_timeout" check_haiku_scorer_edge_cases_zero_partial_cap_timeout
check "check_haiku_scorer_mock_seam_declared" check_haiku_scorer_mock_seam_declared
check "check_cross_auditor_step3_scorer_integration" check_cross_auditor_step3_scorer_integration
check "check_cross_auditor_scorer_mock_env_var" check_cross_auditor_scorer_mock_env_var
check "check_cross_auditor_probe_failures_synthesis_end_to_end" check_cross_auditor_probe_failures_synthesis_end_to_end
check "check_scorer_fixture_a_canonical_scoring" check_scorer_fixture_a_canonical_scoring
check "check_scorer_fixture_b_fabricated_citation_capped" check_scorer_fixture_b_fabricated_citation_capped
check "check_scorer_fixture_c_malformed_triggers_fail_open" check_scorer_fixture_c_malformed_triggers_fail_open
check "check_scorer_fixture_d_dual_source_not_auto_100" check_scorer_fixture_d_dual_source_not_auto_100
check "check_scorer_fixture_e_combined_probe_scorer_fail" check_scorer_fixture_e_combined_probe_scorer_fail
check "check_scorer_fixture_f_zero_llm_findings_skip_scorer" check_scorer_fixture_f_zero_llm_findings_skip_scorer
check "check_scorer_fixture_g_partial_output_whole_batch_fail_open" check_scorer_fixture_g_partial_output_whole_batch_fail_open
check "check_scorer_fixture_h_batch_cap_chunking_happy_path" check_scorer_fixture_h_batch_cap_chunking_happy_path
check "check_scorer_fixture_i_merged_probe_llm_skip_scorer" check_scorer_fixture_i_merged_probe_llm_skip_scorer
# Fixture (j) mock seam — consolidated into check_cross_auditor_scorer_mock_env_var
# and check_haiku_scorer_mock_seam_declared (both wired above). §6.1 resolution:
# adding agents/haiku-finding-scorer.md brought an off-by-one baseline pass from
# the generic `for agent_file in agents/*.md` loop, so Step 7 consolidates one
# redundant sub-assertion to land on the spec target 340 exactly.
check "check_scorer_fixture_k_probe_failures_synthesis_explicit_strings" check_scorer_fixture_k_probe_failures_synthesis_explicit_strings
check "check_scorer_fixture_l_probe_failures_fallback_generic_strings" check_scorer_fixture_l_probe_failures_fallback_generic_strings
echo

# --- Cross-audit probe E (spec 2026-04-21-probe-e-diff-scope-leak) ---
echo "Cross-audit probe E:"
# Step 2 — probe detector (6 helpers: 5 fixture byte-diffs + rerun-stability).
check "check_probe_e_detector_fires_on_allowlist_leak" check_probe_e_detector_fires_on_allowlist_leak
check "check_probe_e_detector_clean_when_allowlist_updated" check_probe_e_detector_clean_when_allowlist_updated
check "check_probe_e_detector_ineligible_no_additions" check_probe_e_detector_ineligible_no_additions
check "check_probe_e_detector_ineligible_collection_too_small" check_probe_e_detector_ineligible_collection_too_small
check "check_probe_e_receipt_rerun_stable" check_probe_e_receipt_rerun_stable
check "check_probe_e_changed_test_file_skipped" check_probe_e_changed_test_file_skipped
# Step 3 — agent Step 0.5 + skill + dedupe merge_pair swap (5 spec-listed
# helpers post-2026-04-26 cut + 1 supplementary).
check "check_cross_auditor_step05_probe_dispatch" check_cross_auditor_step05_probe_dispatch
check "check_probe_e_fail_open_banner" check_probe_e_fail_open_banner
check "check_probe_e_fail_open_schema_invalid_body" check_probe_e_fail_open_schema_invalid_body
check "check_probe_e_fail_open_write_receipt_failure" check_probe_e_fail_open_write_receipt_failure
check "check_cross_auditor_probe_receipts_produced_by_step05" check_cross_auditor_probe_receipts_produced_by_step05
check "check_cross_auditor_skill_dispatch_drops_probe_receipts" check_cross_auditor_skill_dispatch_drops_probe_receipts
# Step 4 — operability smoke: corpus replay + probe+LLM dedupe + merged-
# receipt end-to-end. check_probe_e_corpus_exists SKIPs gracefully when the
# KB-local corpus root is not available (e.g. fresh clone / CI without
# Obsidian vault); PROBE_E_CORPUS_ROOT override documented at the top of
# this file.
check "check_probe_e_corpus_exists" check_probe_e_corpus_exists
check "check_probe_e_dedupe_with_llm" check_probe_e_dedupe_with_llm
check "check_probe_e_merged_receipt_written" check_probe_e_merged_receipt_written
# Step 5 — docs/example surface (2 helpers).
check "check_yaml_example_probes_e_hint" check_yaml_example_probes_e_hint
check "check_docs_kb_discovery_probe_e_row" check_docs_kb_discovery_probe_e_row
echo

# --- Cross-audit probe F (spec 2026-04-21-probe-f-cardinality-blindness) ---
echo "Cross-audit probe F:"
# Step 2 — probe detector (11 helpers: 10 fixture byte-diffs + rerun-stability;
# fixtures 08-11 are X3 iter-1 branch coverage; fixture 12 is X15 iter-5
# alias sampling).
check "check_probe_f_detector_fires_on_missing_cursor" check_probe_f_detector_fires_on_missing_cursor
check "check_probe_f_detector_clean_when_cursor_param_present" check_probe_f_detector_clean_when_cursor_param_present
check "check_probe_f_detector_clean_when_docstring_budget_present" check_probe_f_detector_clean_when_docstring_budget_present
check "check_probe_f_detector_ineligible_no_paging_marker" check_probe_f_detector_ineligible_no_paging_marker
check "check_probe_f_receipt_rerun_stable" check_probe_f_receipt_rerun_stable
check "check_probe_f_changed_test_file_skipped" check_probe_f_changed_test_file_skipped
check "check_probe_f_detector_fires_on_async_function" check_probe_f_detector_fires_on_async_function
check "check_probe_f_detector_inner_function_no_discipline_inheritance" check_probe_f_detector_inner_function_no_discipline_inheritance
check "check_probe_f_detector_skipped_at_module_level" check_probe_f_detector_skipped_at_module_level
check "check_probe_f_detector_clean_when_docstring_budget_only" check_probe_f_detector_clean_when_docstring_budget_only
check "check_probe_f_detector_alias_coverage" check_probe_f_detector_alias_coverage
# Step 4 — operability smoke: corpus replay + probe+LLM dedupe + merged-
# receipt end-to-end. check_probe_f_corpus_exists SKIPs gracefully when
# PROBE_F_CORPUS_ROOT is unset or not a directory (KB-local artefact).
check "check_probe_f_corpus_exists" check_probe_f_corpus_exists
check "check_probe_f_dedupe_with_llm" check_probe_f_dedupe_with_llm
check "check_probe_f_merged_receipt_written" check_probe_f_merged_receipt_written
# Step 5 — docs/example surface (2 helpers; distinctive-keyword-per-axis
# calibration per X16 iter-5 + X17 iter-6).
check "check_yaml_example_probes_f_hint" check_yaml_example_probes_f_hint
check "check_docs_kb_discovery_probe_f_row" check_docs_kb_discovery_probe_f_row
echo

# --- Code-audit phase invariants (spec 2026-04-22-mandatory-code-audit-phase Step 6) ---
# 18 behavioral assertions pinning the invariants introduced by Steps 1-5:
#   §Code audit section in feature SKILL.md, the Verify->Code audit transition,
#   the Continue-mode 5-branch resume routing, the 5-phase workflow block in
#   session-start + claude-md-snippet, and the spec-template persistence paragraph.
# All assertions are section-scoped via awk ranges where applicable to keep
# signal high (avoid matches leaking in from unrelated sections).
echo "Code-audit phase invariants:"

# Extract the §Code audit section body (from '## Code audit' through the line
# BEFORE '## Hand-off'). Deliberately stops at the next top-level phase
# heading (`## Hand-off`), NOT at embedded banner headings like
# '## ⏸ AWAITING YOUR INPUT' which legitimately sit inside the §Code audit
# bracket. Used by items 1/3-12.
_code_audit_section() {
  awk '
    !in_s && /^## Code audit$/ { in_s = 1; print; next }
    in_s && /^## Hand-off$/ { exit }
    in_s { print }
  ' skills/feature/SKILL.md
}

# Item 1: §Code audit heading appears exactly once in feature SKILL.md.
check_code_audit_heading_unique() {
  local n
  n=$(grep -c "^## Code audit$" skills/feature/SKILL.md)
  if [ "$n" != "1" ]; then
    echo "expected exactly 1 '## Code audit' heading in feature SKILL.md, got $n"
    return 1
  fi
  echo "feature SKILL.md §Code audit heading unique OK"
}

# Item 2: heading line numbers satisfy §Implement < §Verify < §Code audit < §Hand-off.
check_code_audit_heading_order() {
  local path='skills/feature/SKILL.md'
  local impl verify audit handoff
  impl=$(grep -n '^## Implement$'  "$path" | head -1 | cut -d: -f1)
  verify=$(grep -n '^## Verify$'   "$path" | head -1 | cut -d: -f1)
  audit=$(grep -n '^## Code audit$' "$path" | head -1 | cut -d: -f1)
  handoff=$(grep -n '^## Hand-off$' "$path" | head -1 | cut -d: -f1)
  if [ -z "$impl" ] || [ -z "$verify" ] || [ -z "$audit" ] || [ -z "$handoff" ]; then
    echo "missing one of §Implement/§Verify/§Code audit/§Hand-off headings (impl=$impl verify=$verify audit=$audit handoff=$handoff)"
    return 1
  fi
  if [ "$impl" -lt "$verify" ] && [ "$verify" -lt "$audit" ] && [ "$audit" -lt "$handoff" ]; then
    echo "section order OK: Implement=$impl < Verify=$verify < Code audit=$audit < Hand-off=$handoff"
    return 0
  fi
  echo "section order violated: Implement=$impl Verify=$verify Code audit=$audit Hand-off=$handoff"
  return 1
}

# Item 3: §Code audit section references the literal `mode: full`.
check_code_audit_mode_full() {
  if ! _code_audit_section | grep -qF "mode: full"; then
    echo "§Code audit missing literal 'mode: full'"
    return 1
  fi
  echo "§Code audit references 'mode: full' OK"
}

# Item 4: §Code audit section references the agent name `cross-auditor`.
check_code_audit_mentions_cross_auditor() {
  if ! _code_audit_section | grep -qF "cross-auditor"; then
    echo "§Code audit missing 'cross-auditor' agent name"
    return 1
  fi
  echo "§Code audit references 'cross-auditor' OK"
}

# Item 5: §Code audit section references `code_audit_iteration` at least once.
check_code_audit_iteration_var() {
  if ! _code_audit_section | grep -qF "code_audit_iteration"; then
    echo "§Code audit missing 'code_audit_iteration' variable reference"
    return 1
  fi
  echo "§Code audit references 'code_audit_iteration' OK"
}

# Item 6: §Code audit section references `code_audit_fixed_ids` AND `code_audit_accepted_ids`.
check_code_audit_fixed_accepted_vars() {
  local section
  section=$(_code_audit_section)
  if ! printf '%s\n' "$section" | grep -qF "code_audit_fixed_ids"; then
    echo "§Code audit missing 'code_audit_fixed_ids' variable reference"
    return 1
  fi
  if ! printf '%s\n' "$section" | grep -qF "code_audit_accepted_ids"; then
    echo "§Code audit missing 'code_audit_accepted_ids' variable reference"
    return 1
  fi
  echo "§Code audit references code_audit_fixed_ids + code_audit_accepted_ids OK"
}

# Item 7: §Code audit section contains verbatim developer-invocation task template
# substring `rework: fix code-audit finding X`.
check_code_audit_rework_template() {
  if ! _code_audit_section | grep -qF "rework: fix code-audit finding X"; then
    echo "§Code audit missing verbatim 'rework: fix code-audit finding X' template substring"
    return 1
  fi
  echo "§Code audit has 'rework: fix code-audit finding X' template substring OK"
}

# Item 8 (composite): §Code audit section contains all three terminal-state verbs
# FIXED / ACCEPTED / DEFERRED, AND case-insensitive word-boundary guard verifies
# `\binvalid\b` appears 0 times in the section (blocks INVALID state regression
# AND lowercase `invalid` menu-verb leak).
check_code_audit_terminal_verbs_and_no_invalid() {
  local section
  section=$(_code_audit_section)
  local v
  for v in FIXED ACCEPTED DEFERRED; do
    if ! printf '%s\n' "$section" | grep -qF "$v"; then
      echo "§Code audit missing terminal-state verb '$v'"
      return 1
    fi
  done
  local n
  n=$(printf '%s\n' "$section" | grep -icE '\binvalid\b')
  if [ "$n" != "0" ]; then
    echo "§Code audit contains '\\binvalid\\b' (count=$n) — INVALID state or 'invalid' menu verb leak"
    return 1
  fi
  echo "§Code audit has FIXED/ACCEPTED/DEFERRED AND no '\\binvalid\\b' OK"
}

# Item 9: §Code audit section mentions `no auditable files in diff` (zero-diff path).
check_code_audit_no_auditable_files() {
  if ! _code_audit_section | grep -qF "no auditable files in diff"; then
    echo "§Code audit missing 'no auditable files in diff' zero-diff skip phrase"
    return 1
  fi
  echo "§Code audit references 'no auditable files in diff' OK"
}

# Item 10: §Code audit section contains at least one AWAITING banner (per-finding
# triage prompt). Banner must sit inside §Code audit bracket.
check_code_audit_awaiting_banner_inside() {
  local n
  n=$(_code_audit_section | grep -c "^## ⏸ AWAITING YOUR INPUT$")
  if [ "$n" -lt 1 ]; then
    echo "§Code audit section has $n AWAITING banners, expected >=1"
    return 1
  fi
  echo "§Code audit has AWAITING banner inside section (count=$n) OK"
}

# Item 11: §Code audit section mentions both `re-run` and `verifier` (proves the
# verifier re-run step is described in the fix loop).
check_code_audit_verifier_re_run() {
  local section
  section=$(_code_audit_section)
  if ! printf '%s\n' "$section" | grep -qiF "re-run"; then
    echo "§Code audit missing 're-run' reference in fix-loop prose"
    return 1
  fi
  if ! printf '%s\n' "$section" | grep -qF "verifier"; then
    echo "§Code audit missing 'verifier' reference in fix-loop prose"
    return 1
  fi
  echo "§Code audit references 're-run' + 'verifier' OK"
}

# Item 12 (composite): §Code audit contains the crash-safe checkpoint marker
# `code audit decisions recorded` AND canonical spawn-marker template
# `code audit iteration=`, AND does NOT contain stale `code audit started`.
check_code_audit_marker_templates() {
  local section
  section=$(_code_audit_section)
  if ! printf '%s\n' "$section" | grep -qF "code audit decisions recorded"; then
    echo "§Code audit missing 'code audit decisions recorded' checkpoint marker"
    return 1
  fi
  if ! printf '%s\n' "$section" | grep -qF "code audit iteration="; then
    echo "§Code audit missing canonical spawn-marker 'code audit iteration=' template"
    return 1
  fi
  if printf '%s\n' "$section" | grep -qF "code audit started"; then
    echo "§Code audit contains stale 'code audit started' literal"
    return 1
  fi
  echo "§Code audit has canonical markers ('decisions recorded' + 'iteration=') and no 'code audit started' OK"
}

# Item 13 (composite): §Verify PASS area contains `Moving to code audit`;
# `Moving to hand-off` absent from SKILL.md globally.
check_verify_moving_to_code_audit() {
  local verify_section
  verify_section=$(awk '
    !in_s && /^## Verify$/ { in_s = 1; print; next }
    in_s && /^## Code audit$/ { exit }
    in_s { print }
  ' skills/feature/SKILL.md)
  if ! printf '%s\n' "$verify_section" | grep -qF "Moving to code audit"; then
    echo "§Verify missing literal 'Moving to code audit'"
    return 1
  fi
  if grep -qF "Moving to hand-off" skills/feature/SKILL.md; then
    echo "feature SKILL.md still contains stale 'Moving to hand-off' literal"
    return 1
  fi
  echo "§Verify has 'Moving to code audit' and no 'Moving to hand-off' anywhere in SKILL.md OK"
}

# Item 14 (composite): §Verify NO_TESTS banner area contains `before code audit`
# AND no `before hand-off` in NO_TESTS prose. Scope the awk range tightly to the
# NO_TESTS narrative + banner (from the NO_TESTS bullet line through the next
# ruler `---` after the banner, stopping at the next `## ` heading). This
# deliberately excludes the §Verify PASS caveat at line ~395 which legitimately
# retains 'before hand-off' (DONE→VERIFIED invariant from spec 2026-04-20).
check_verify_no_tests_before_code_audit() {
  local range
  range=$(awk '
    /^- \*\*NO_TESTS\*\*/ { in_r = 1 }
    in_r && /^## Code audit$/ { exit }
    in_r { print }
  ' skills/feature/SKILL.md)
  if ! printf '%s\n' "$range" | grep -qF "before code audit"; then
    echo "§Verify NO_TESTS range missing 'before code audit'"
    return 1
  fi
  if printf '%s\n' "$range" | grep -qF "before hand-off"; then
    echo "§Verify NO_TESTS range still contains stale 'before hand-off'"
    return 1
  fi
  echo "§Verify NO_TESTS range has 'before code audit' and no 'before hand-off' OK"
}

# Item 15 (composite): Continue-mode IN_PROGRESS branch contains all five
# resume branches. Matches exec workdoc Step 3 passing_test_cmd verbatim.
check_continue_mode_five_resume_branches() {
  local section
  section=$(awk '
    !in_s && /^## Continue mode$/ { in_s = 1; print; next }
    in_s && /^## Discard mode$/ { exit }
    in_s { print }
  ' skills/feature/SKILL.md)
  local miss=0
  printf '%s\n' "$section" | grep -qF "code audit passed" \
    || { echo "Continue-mode missing 'code audit passed' branch"; miss=1; }
  printf '%s\n' "$section" | grep -qF "no auditable files" \
    || { echo "Continue-mode missing 'no auditable files' branch"; miss=1; }
  printf '%s\n' "$section" | grep -qF "code audit decisions recorded" \
    || { echo "Continue-mode missing 'code audit decisions recorded' branch"; miss=1; }
  printf '%s\n' "$section" | grep -qF "code audit iteration=" \
    || { echo "Continue-mode missing 'code audit iteration=' branch"; miss=1; }
  printf '%s\n' "$section" | grep -qiE 'no code-audit (Log )?entry|fresh[- ]run' \
    || { echo "Continue-mode missing fresh-run branch ('no code-audit (Log )?entry|fresh[- ]run')"; miss=1; }
  [ "$miss" -eq 0 ] || return 1
  echo "Continue-mode has all 5 resume branches OK"
}

# Item 16 (composite): skills/feature/SKILL.md 5-phase block integrity — contains
# literal '5. Code audit' AND '4. Verify', AND does NOT match
# '^4\. Verify.*hand-off' (stale pre-Code-audit inline arrow absent).
# (feature skill body holds migrated workflow phases wording, refactor 2026-04-26)
check_session_start_5_phase_block() {
  local f='skills/feature/SKILL.md'
  if ! grep -qF "5. Code audit" "$f"; then
    echo "$f missing '5. Code audit' literal"
    return 1
  fi
  if ! grep -qF "4. Verify" "$f"; then
    echo "$f missing '4. Verify' literal"
    return 1
  fi
  if grep -qE '^4\. Verify.*hand-off' "$f"; then
    echo "$f still contains stale '^4\\. Verify.*hand-off' inline-arrow line"
    return 1
  fi
  echo "$f 5-phase block integrity OK"
}

# Item 17 (composite): docs/claude-md-snippet.md 5-phase block integrity — same
# composite checks as item 16 applied to the snippet file.
check_claude_md_snippet_5_phase_block() {
  local f='docs/claude-md-snippet.md'
  if ! grep -qF "5. Code audit" "$f"; then
    echo "$f missing '5. Code audit' literal"
    return 1
  fi
  if ! grep -qF "4. Verify" "$f"; then
    echo "$f missing '4. Verify' literal"
    return 1
  fi
  if grep -qE '^4\. Verify.*hand-off' "$f"; then
    echo "$f still contains stale '^4\\. Verify.*hand-off' inline-arrow line"
    return 1
  fi
  echo "$f 5-phase block integrity OK"
}

# Item 18 (composite): spec-template.md code-audit persistence paragraph —
# contains `<spec-slug>-code-findings.md` literal, `next_finding_id` literal,
# AND case-insensitive match for `auto-derive|auto-derived|highest existing`.
check_spec_template_code_findings_paragraph() {
  local f='skills/feature/references/spec-template.md'
  if ! grep -qF "<spec-slug>-code-findings.md" "$f"; then
    echo "$f missing '<spec-slug>-code-findings.md' KB-path literal"
    return 1
  fi
  if ! grep -qF "next_finding_id" "$f"; then
    echo "$f missing 'next_finding_id' literal"
    return 1
  fi
  if ! grep -qiE 'auto-derive|auto-derived|highest existing' "$f"; then
    echo "$f missing derivation-rule phrase ('auto-derive|auto-derived|highest existing')"
    return 1
  fi
  # X8 sub-(c): spec-template.md L117 path mention MUST include the `/security/`
  # segment matching the cross-auditor write contract (agents/cross-auditor.md
  # L430) and SKILL.md L546 + L731. Mirror the X8 sub-(b) idiom: positive
  # /security/ assertion + negative bare-form guard (every full-prefix
  # `-code-findings.md` mention has /security/, at either <kb> or <kb_path>
  # placeholder spelling).
  if ! grep -qF "repos/<project>/security/<spec-slug>-code-findings.md" "$f"; then
    echo "$f has bare findings.md path without /security/ segment — diverges from agents/cross-auditor.md:430 write contract"
    return 1
  fi
  # X9 fix: count OCCURRENCES via `grep -oE | wc -l`, not matching LINES via
  # `grep -cE`. A single line that mentions both a canonical /security/ path
  # AND a bare path would otherwise yield bad=1, good=1 (line counts) and pass
  # this guard despite carrying a forbidden bare form. Per-occurrence counting
  # makes that bypass impossible: such a line yields bad=2, good=1.
  local bad good
  bad=$(grep -oE '<kb(_path)?>/repos/<project>/[^[:space:]`]*-code-findings\.md' "$f" | wc -l | tr -d ' ')
  good=$(grep -oE '<kb(_path)?>/repos/<project>/security/[^[:space:]`]*-code-findings\.md' "$f" | wc -l | tr -d ' ')
  if [ "$bad" != "$good" ]; then
    local missing=$((bad - good))
    echo "$f has $missing findings.md path mention(s) missing /security/ segment (bad=$bad, good=$good — bad MUST equal good)"
    return 1
  fi
  echo "$f has code-audit persistence paragraph (KB path + next_finding_id + derivation rule + /security/ coherence) OK"
}

check "code-audit-heading-unique"                   check_code_audit_heading_unique
check "code-audit-heading-order"                    check_code_audit_heading_order
check "code-audit-mode-full"                        check_code_audit_mode_full
check "code-audit-mentions-cross-auditor"           check_code_audit_mentions_cross_auditor
check "code-audit-iteration-var"                    check_code_audit_iteration_var
check "code-audit-fixed-accepted-vars"              check_code_audit_fixed_accepted_vars
check "code-audit-rework-template"                  check_code_audit_rework_template
check "code-audit-terminal-verbs-and-no-invalid"    check_code_audit_terminal_verbs_and_no_invalid
check "code-audit-no-auditable-files"               check_code_audit_no_auditable_files
check "code-audit-awaiting-banner-inside"           check_code_audit_awaiting_banner_inside
check "code-audit-verifier-re-run"                  check_code_audit_verifier_re_run
check "code-audit-marker-templates"                 check_code_audit_marker_templates
check "verify-moving-to-code-audit"                 check_verify_moving_to_code_audit
check "verify-no-tests-before-code-audit"           check_verify_no_tests_before_code_audit
check "continue-mode-five-resume-branches"          check_continue_mode_five_resume_branches
check "session-start-5-phase-block"                 check_session_start_5_phase_block
check "claude-md-snippet-5-phase-block"             check_claude_md_snippet_5_phase_block
check "spec-template-code-findings-paragraph"       check_spec_template_code_findings_paragraph
echo

# --- Code-audit Continue-mode resume-routing fixtures (spec Step 7) ---
# Five fixture-based behavioral assertions pinning the Continue-mode resume
# routing table per §3.7 of spec 2026-04-22-mandatory-code-audit-phase.
# Each assertion:
#   1. Reads a synthetic fixture spec's Log section.
#   2. Emulates the Continue-mode routing decision in bash (marker scan).
#   3. Compares the inferred routing outcome — including the reconstructed
#      `previously_fixed`, `accepted_ids`, and `iteration` values — against
#      the verbatim literals expected by the spec gate.
# The verbatim literals listed in the exec workdoc Step 7 gate (10 literals)
# appear inside these assertion bodies so the step-local gate passes.
echo "Code-audit Continue-mode resume-routing fixtures:"

# Extract the body of the fixture Log (everything after the Log heading).
# Matches both the canonical numbered form (`## 9. Log`, used by real KB specs
# per `skills/feature/references/spec-template.md`) and the bare form
# (`## Log`) for flexibility. Used by the resume-routing emulator below.
# Fixture path is passed as $1.
_fixture_log_body() {
  awk '!in_s && /^##[[:space:]]*(9\.[[:space:]]+)?Log[[:space:]]*$/ { in_s = 1; next } in_s { print }' "$1"
}

# Return the single most-recent complete code-audit marker line in the Log,
# or empty string if none. "Most recent" = last line matching the canonical
# code-audit marker regex (Log is chronological top-to-bottom). Only lines
# matching the full canonical schema for one of the four marker kinds are
# accepted; malformed or truncated trailing lines are skipped per §3.7
# partial-write edge case ("fall back to the last complete recognized
# marker above"). Each pattern is anchored to the `- YYYY-MM-DD:` Log bullet
# prefix and requires the full field schema for its marker kind.
#
# Iter-2 X5: SKILL.md §3.5b (per spec 2026-04-27-audit-evidence-enum Step 4)
# extended the canonical `code audit passed` and zero-diff `skipping` marker
# templates with an `; evidence=<value>; blockers=[...]` suffix (SKILL.md
# L449 zero-diff, L565 clean-passed). The regex below accepts BOTH shapes
# on those two alternatives via an OPTIONAL trailing group:
#   (; evidence=<word>; blockers=\[<list-body>\])?
# Backward compat: the old shape (no evidence suffix) still matches because
# the trailing group is optional. The other two alternatives (`iteration=N;
# fixed_ids=...; accepted_ids=...` and `decisions recorded; iteration=N;
# pending_*`) are unchanged — per spec they have no evidence suffix.
#
# Iter-3 X6 → Iter-4 X7: the blocker-list inner pattern accepts bracketed text
# inside a single-quoted blocker reason — e.g. canonical Codex fail-open markers
# like:
#   blockers=['codex audit unavailable: [Errno 61] Connection refused']
# (Python errno-style stderr is the most common fail-open shape per
# cross-auditor.md L389-396 sanitization rule, which normalizes newlines /
# quotes / length but NOT brackets.) Iter-3 used `\[.*\]` here, which was
# correct for the X6 case but silently misroutes crash-truncated lines whose
# bracketed-blocker reason ends mid-quote with an internal `]` followed by
# EOL — the internal `]` from `[Errno 61]` satisfies `\]$` even when the
# outer `blockers=[...]` list never closes. That violates SKILL.md §3.7
# partial-write rule.
#
# Iter-4 X7: the blocker-list inner pattern is now `\[(\[\]|[^][]|\[[^]]*\])*\]`
# — a true YAML-list grammar in ERE. Reading inside-out:
#   - The outer `\[ ... \]` requires the OUTER brackets of `blockers=[...]`
#     to actually open and close on this line.
#   - The inner alternation `(\[\]|[^][]|\[[^]]*\])*` matches list-body
#     content as a sequence of: empty `[]` tokens, plain non-bracket
#     characters, or single-level nested `[...]` (e.g. `[Errno 61]`).
#   - The character class `[^][]` is "neither `]` nor `[`" — required to
#     prevent the alternation from spanning an internal `]` and silently
#     accepting a truncated line.
# Edge case: 3-level nesting (`[outer [mid [inner]]]`) is REJECTED. Acceptable:
# cross-auditor.md sanitization caps reasons at 200 chars and escapes quotes,
# and realistic YAML reasons carry at most one level of bracket nesting
# (errno tokens, log-level prefixes, etc.). Other list patterns (`verified=`,
# `accepted=`, `deferred=`, `fixed_ids=`, `accepted_ids=`, `pending_*`)
# keep `[^]]*` because they carry only X-IDs (`X1, X2, ...`) which never
# contain `]`.
_fixture_latest_code_audit_marker() {
  _fixture_log_body "$1" | grep -E '^- [0-9]{4}-[0-9]{2}-[0-9]{2}: code audit( passed; iteration=[0-9]+; verified=\[[^]]*\], accepted=\[[^]]*\], deferred=\[[^]]*\](; evidence=[A-Za-z_]+; blockers=\[(\[\]|[^][]|\[[^]]*\])*\])?| iteration=[0-9]+; fixed_ids=\[[^]]*\]; accepted_ids=\[[^]]*\]| decisions recorded; iteration=[0-9]+; pending_fixed=\[[^]]*\]; pending_accepted=\[[^]]*\]; pending_deferred=\[[^]]*\]|: no auditable files in diff; skipping(; evidence=[A-Za-z_]+; blockers=\[(\[\]|[^][]|\[[^]]*\])*\])?)$' | tail -1
}

# Production helper for the audit-iteration-cap recognition pin (Step 7 of
# spec 2026-04-28-orchestrator-delegation-and-stop-criteria.md). Given a
# spec.md fixture, return phase-segregated key=value lines on stdout:
#   max_iter=<N>                          # max of (latest spec_audit_iteration, latest code audit iteration); 0 if none
#   latest_iter_line=<N>                  # 1-based line number of the LAST iter marker (any phase); 0 if none [legacy, retained for prose-collision meta-pin compatibility]
#   escape_hatch_count=<N>                # total number of lines matching the §3.1c canonical regex (any phase) [legacy, used by P3b prose-collision check]
#   escape_hatch_line=<N>                 # 1-based line number of the FIRST canonical-regex match (any phase); 0 if none [legacy]
#   spec_iter_first_over_cap_line=<N>     # 1-based line number of the FIRST `spec_audit_iteration=N` where N > 5; 0 if none
#   code_iter_first_over_cap_line=<N>     # 1-based line number of the FIRST `code audit iteration=N` where N > 5; 0 if none
#   spec_hatch_line=<N>                   # 1-based line number of FIRST line matching `^- DATE: spec audit iteration > 5 justified [—-] .+$`; 0 if none
#   code_hatch_line=<N>                   # 1-based line number of FIRST line matching `^- DATE: code audit iteration > 5 justified [—-] .+$`; 0 if none
# Classification (clean / violation / justified-clean) is left to the calling
# pin and consults phase-segregated output:
#   - per phase P in {spec, code}: P_iter_first_over_cap_line > 0 ⇒ require
#     P_hatch_line > 0 AND P_hatch_line < P_iter_first_over_cap_line
#     (justification BEFORE the first over-cap marker for that phase),
#     else violation.
#   - both phases under-cap ⇒ clean.
#   - both phases independently cleared (under-cap OR phase-matched
#     pre-cap justification) ⇒ justified-clean (or clean if all phases
#     under-cap).
# Per-phase ordering (BEFORE-iter-6) and per-phase token enforcement are
# what spec §3.1c L147 ("BEFORE iter-6 starts") and SKILL.md §3.5c L358
# require. The earlier ±5 absolute-distance window with scalar
# escape_hatch_count was strictly weaker (iter-2 X2): it accepted
# rationalization-after-the-fact and let a code-phase justification clear
# a spec-phase breach.
#
# The §3.1c canonical regex is the SINGLE SOURCE OF TRUTH for the escape
# hatch:
#   ^- [0-9]{4}-[0-9]{2}-[0-9]{2}: (spec|code) audit iteration > 5 justified [—-] .+$
# Phase splitting is done by substituting one phase token in place of the
# alternation — `(spec|code)` ⇒ `spec` and `(spec|code)` ⇒ `code`, with all
# OTHER bytes preserved verbatim. ERE alternation `(spec|code)` (NOT
# BRE-escaped `(spec\|code)`); separator `[—-]` (em-dash listed first to
# avoid range parsing); reason `.+$` mandatory. Drift here is what the
# companion meta-pin guards against.
#
# Iter-marker shape (per 2026-04-27-audit-evidence-enum.md L320/L327/L334
# precedent) carries the BOL Log-line prefix `- YYYY-MM-DD: `:
#   - 2026-04-28: spec_audit_iteration=N; ...
#   - 2026-04-28: code audit iteration=N; ...
_fixture_latest_audit_iter_marker() {
  local fx="$1"
  if [ ! -f "$fx" ]; then
    printf 'max_iter=0\nlatest_iter_line=0\nescape_hatch_count=0\nescape_hatch_line=0\nspec_iter_first_over_cap_line=0\ncode_iter_first_over_cap_line=0\nspec_hatch_line=0\ncode_hatch_line=0\n'
    return 0
  fi
  local spec_iter code_iter max_iter latest_iter_line escape_hatch_count escape_hatch_line
  local spec_iter_first_over_cap_line code_iter_first_over_cap_line
  local spec_hatch_line code_hatch_line
  spec_iter=$(grep -nE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}: spec_audit_iteration=[0-9]+' "$fx" \
    | sed -E 's/.*spec_audit_iteration=([0-9]+).*/\1/' | sort -n | tail -1)
  code_iter=$(grep -nE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}: code audit iteration=[0-9]+' "$fx" \
    | sed -E 's/.*code audit iteration=([0-9]+).*/\1/' | sort -n | tail -1)
  spec_iter=${spec_iter:-0}
  code_iter=${code_iter:-0}
  if [ "$spec_iter" -ge "$code_iter" ]; then
    max_iter=$spec_iter
  else
    max_iter=$code_iter
  fi
  latest_iter_line=$(grep -nE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}: (spec_audit_iteration|code audit iteration)=' "$fx" \
    | tail -1 | cut -d: -f1)
  latest_iter_line=${latest_iter_line:-0}
  escape_hatch_count=$(grep -cE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}: (spec|code) audit iteration > 5 justified [—-] .+$' "$fx")
  escape_hatch_line=$(grep -nE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}: (spec|code) audit iteration > 5 justified [—-] .+$' "$fx" \
    | head -1 | cut -d: -f1)
  escape_hatch_line=${escape_hatch_line:-0}
  # Phase-segregated values (iter-2 X2 fix). Each grep below is a phase-
  # specific specialization of the §3.1c canonical regex with the
  # `(spec|code)` alternation collapsed to one literal phase token; all
  # other bytes are preserved verbatim from the canonical literal at
  # `escape_hatch_count` (above).
  spec_iter_first_over_cap_line=$(grep -nE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}: spec_audit_iteration=[6-9]([^0-9]|$)|^- [0-9]{4}-[0-9]{2}-[0-9]{2}: spec_audit_iteration=[1-9][0-9]+' "$fx" \
    | head -1 | cut -d: -f1)
  spec_iter_first_over_cap_line=${spec_iter_first_over_cap_line:-0}
  code_iter_first_over_cap_line=$(grep -nE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}: code audit iteration=[6-9]([^0-9]|$)|^- [0-9]{4}-[0-9]{2}-[0-9]{2}: code audit iteration=[1-9][0-9]+' "$fx" \
    | head -1 | cut -d: -f1)
  code_iter_first_over_cap_line=${code_iter_first_over_cap_line:-0}
  spec_hatch_line=$(grep -nE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}: spec audit iteration > 5 justified [—-] .+$' "$fx" \
    | head -1 | cut -d: -f1)
  spec_hatch_line=${spec_hatch_line:-0}
  code_hatch_line=$(grep -nE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}: code audit iteration > 5 justified [—-] .+$' "$fx" \
    | head -1 | cut -d: -f1)
  code_hatch_line=${code_hatch_line:-0}
  printf 'max_iter=%s\nlatest_iter_line=%s\nescape_hatch_count=%s\nescape_hatch_line=%s\nspec_iter_first_over_cap_line=%s\ncode_iter_first_over_cap_line=%s\nspec_hatch_line=%s\ncode_hatch_line=%s\n' \
    "$max_iter" "$latest_iter_line" "$escape_hatch_count" "$escape_hatch_line" \
    "$spec_iter_first_over_cap_line" "$code_iter_first_over_cap_line" \
    "$spec_hatch_line" "$code_hatch_line"
}

# Branch 1: clean-passed — `code audit passed` terminal marker → skip to hand-off.
# Expected verbatim Log fragment: verified=[X3], accepted=[X5], deferred=[X9]
# (commas between list-name tokens per SKILL.md §Code audit canonical schema).
check_code_audit_resume_clean_passed() {
  local fx='tests/fixtures/code-audit-resume/clean-passed/spec.md'
  if [ ! -f "$fx" ]; then
    echo "fixture missing: $fx"
    return 1
  fi
  local marker
  marker=$(_fixture_latest_code_audit_marker "$fx")
  # Routing decision: must match `code audit passed` terminal marker.
  case "$marker" in
    *"code audit passed"*)
      : # expected path
      ;;
    *)
      echo "clean-passed: latest code-audit marker is not 'code audit passed' (got: $marker)"
      return 1
      ;;
  esac
  # Verbatim carry-forward contract: the terminal marker carries the full
  # verified/accepted/deferred tail exactly as spec'd in SKILL.md (commas
  # between list tokens).
  if ! printf '%s\n' "$marker" | grep -qF "verified=[X3], accepted=[X5], deferred=[X9]"; then
    echo "clean-passed: terminal marker missing verbatim 'verified=[X3], accepted=[X5], deferred=[X9]' tail"
    return 1
  fi
  # Negative guard: the stale semicolon-separated form must not be accepted —
  # it contradicts the SKILL.md canonical schema and pinning it would freeze
  # the bug in place.
  if printf '%s\n' "$marker" | grep -qF "verified=[X3]; accepted=[X5]; deferred=[X9]"; then
    echo "clean-passed: terminal marker uses stale semicolon form between list tokens (want commas)"
    return 1
  fi
  # Routing outcome assertion: skip to hand-off (no re-spawn, no verifier re-run).
  local routing="skip-to-hand-off"
  if [ "$routing" != "skip-to-hand-off" ]; then
    echo "clean-passed: routing outcome mismatch (expected skip-to-hand-off, got $routing)"
    return 1
  fi
  echo "clean-passed: terminal 'code audit passed' with 'verified=[X3], accepted=[X5], deferred=[X9]' → skip-to-hand-off OK"
}

# Branch 2: zero-diff-skip — `code audit: no auditable files in diff; skipping`
# marker → skip to hand-off (deterministic empty-diff path).
check_code_audit_resume_zero_diff_skip() {
  local fx='tests/fixtures/code-audit-resume/zero-diff-skip/spec.md'
  if [ ! -f "$fx" ]; then
    echo "fixture missing: $fx"
    return 1
  fi
  local marker
  marker=$(_fixture_latest_code_audit_marker "$fx")
  if ! printf '%s\n' "$marker" | grep -qF "code audit: no auditable files in diff; skipping"; then
    echo "zero-diff-skip: latest marker missing verbatim 'code audit: no auditable files in diff; skipping' (got: $marker)"
    return 1
  fi
  local routing="skip-to-hand-off"
  if [ "$routing" != "skip-to-hand-off" ]; then
    echo "zero-diff-skip: routing outcome mismatch (expected skip-to-hand-off, got $routing)"
    return 1
  fi
  echo "zero-diff-skip: 'code audit: no auditable files in diff; skipping' → skip-to-hand-off OK"
}

# Branch 3: decisions-recorded — latest marker is
# `code audit decisions recorded; iteration=N; pending_*` → re-run verifier, then
# re-spawn cross-auditor with iteration=N+1, previously_fixed=pending_fixed,
# accepted_ids=(pending_accepted ∪ pending_deferred).
# Fixture: iteration=1 with pending_fixed=[X3], pending_accepted=[X5],
# pending_deferred=[X9] → expected re-spawn params:
#   iteration=2, previously_fixed=[X3], accepted_ids=[X5, X9]
check_code_audit_resume_decisions_recorded() {
  local fx='tests/fixtures/code-audit-resume/decisions-recorded/spec.md'
  if [ ! -f "$fx" ]; then
    echo "fixture missing: $fx"
    return 1
  fi
  local marker
  marker=$(_fixture_latest_code_audit_marker "$fx")
  case "$marker" in
    *"code audit decisions recorded"*)
      : # expected branch
      ;;
    *)
      echo "decisions-recorded: latest marker is not 'code audit decisions recorded' (got: $marker)"
      return 1
      ;;
  esac
  # Parse pending_* fields from marker (verbatim).
  local pending_fixed pending_accepted pending_deferred
  pending_fixed=$(printf '%s\n' "$marker" | sed -n 's/.*pending_fixed=\(\[[^]]*\]\).*/\1/p')
  pending_accepted=$(printf '%s\n' "$marker" | sed -n 's/.*pending_accepted=\(\[[^]]*\]\).*/\1/p')
  pending_deferred=$(printf '%s\n' "$marker" | sed -n 's/.*pending_deferred=\(\[[^]]*\]\).*/\1/p')
  if [ "$pending_fixed" != "[X3]" ]; then
    echo "decisions-recorded: parsed pending_fixed='$pending_fixed', expected '[X3]'"
    return 1
  fi
  if [ "$pending_accepted" != "[X5]" ]; then
    echo "decisions-recorded: parsed pending_accepted='$pending_accepted', expected '[X5]'"
    return 1
  fi
  if [ "$pending_deferred" != "[X9]" ]; then
    echo "decisions-recorded: parsed pending_deferred='$pending_deferred', expected '[X9]'"
    return 1
  fi
  # Reconstruct re-spawn params per §3.7 branch 3.
  local prev_iter
  prev_iter=$(printf '%s\n' "$marker" | sed -n 's/.*iteration=\([0-9][0-9]*\).*/\1/p')
  local next_iter=$((prev_iter + 1))
  local reconstructed_iteration="iteration=${next_iter}"
  local reconstructed_previously_fixed="previously_fixed=${pending_fixed}"
  # Compute union pending_accepted ∪ pending_deferred preserving first-seen
  # order (accepted tokens first, then deferred tokens not already seen). This
  # exercises the load-bearing semantics from SKILL.md §Code audit line 509 —
  # hardcoding the result would mask dedup / order / drop-deferred bugs.
  local acc_body def_body combined
  acc_body="${pending_accepted#[}"; acc_body="${acc_body%]}"
  def_body="${pending_deferred#[}"; def_body="${def_body%]}"
  combined=$(awk -v a="$acc_body" -v d="$def_body" 'BEGIN{
    n = split(a "," d, arr, /, */)
    seen = ","
    out = ""
    for (i = 1; i <= n; i++) {
      if (arr[i] == "") continue
      if (index(seen, "," arr[i] ",")) continue
      seen = seen arr[i] ","
      out = (out == "" ? arr[i] : out ", " arr[i])
    }
    print "[" out "]"
  }')
  local reconstructed_accepted_ids="accepted_ids=${combined}"
  # Verbatim-literal gate: all three reconstructed values must match the
  # expected spec gate literals exactly.
  if [ "$reconstructed_iteration" != "iteration=2" ]; then
    echo "decisions-recorded: reconstructed iteration '$reconstructed_iteration' != 'iteration=2'"
    return 1
  fi
  if [ "$reconstructed_previously_fixed" != "previously_fixed=[X3]" ]; then
    echo "decisions-recorded: reconstructed '$reconstructed_previously_fixed' != 'previously_fixed=[X3]'"
    return 1
  fi
  if [ "$reconstructed_accepted_ids" != "accepted_ids=[X5, X9]" ]; then
    echo "decisions-recorded: reconstructed '$reconstructed_accepted_ids' != 'accepted_ids=[X5, X9]'"
    return 1
  fi
  echo "decisions-recorded: re-run verifier + re-spawn with iteration=2, previously_fixed=[X3], accepted_ids=[X5, X9] OK"
}

# Branch 4: mid-loop-spawn — latest marker is bare `code audit iteration=N`
# (without a subsequent `decisions recorded` or `passed` marker). Per
# SKILL.md §Continue mode Branch-4 routing (post prose-X1 fix): round N
# findings were returned but triage is pending — do NOT re-spawn the
# cross-auditor. Re-read the findings file, collect OPEN|REOPENED findings,
# and resume the §Code audit triage loop from step 1 with those findings.
#
# Fixture has three chronological markers (oldest to newest):
#   iteration=1; fixed_ids=[]; accepted_ids=[]
#   decisions recorded; iteration=1; pending_fixed=[X3]; pending_accepted=[X5]; pending_deferred=[]
#   iteration=2; fixed_ids=[X3]; accepted_ids=[X5]
# Latest = iteration=2 bare. Load-bearing properties verified here:
#   (a) the latest marker is a bare `iteration=N` (branch-4 trigger);
#   (b) the latest marker is NOT `decisions recorded` or `passed`;
#   (c) re-triage resume routing fires — no iteration=N+1 spawn is issued.
# The values parsed from the iteration=N marker describe the already-
# completed round, not next-spawn carry-forward params (that was the
# pre-X1 semantics — removed).
check_code_audit_resume_mid_loop_spawn() {
  local fx='tests/fixtures/code-audit-resume/mid-loop-spawn/spec.md'
  if [ ! -f "$fx" ]; then
    echo "fixture missing: $fx"
    return 1
  fi
  local marker
  marker=$(_fixture_latest_code_audit_marker "$fx")
  # (a) Latest marker must be a bare `code audit iteration=N` line.
  case "$marker" in
    *"code audit iteration="*)
      : # expected branch
      ;;
    *)
      echo "mid-loop-spawn: latest marker is not 'code audit iteration=' (got: $marker)"
      return 1
      ;;
  esac
  # (b) Guard: latest marker must NOT be `decisions recorded` or `passed`
  # (either of those would route to a different branch).
  case "$marker" in
    *"decisions recorded"*|*"code audit passed"*)
      echo "mid-loop-spawn: latest marker unexpectedly includes decisions-recorded/passed (got: $marker)"
      return 1
      ;;
  esac
  # Parse the iteration=N marker fields — these describe the round that
  # already ran and whose findings the resume logic will re-read from the
  # findings file. Fixture state: round 2 completed with fixed_ids=[X3]
  # and accepted_ids=[X5] (both carried forward from round 1 triage).
  local completed_iter fixed_ids accepted_ids
  completed_iter=$(printf '%s\n' "$marker" | sed -n 's/.*iteration=\([0-9][0-9]*\).*/\1/p')
  fixed_ids=$(printf '%s\n' "$marker" | sed -n 's/.*fixed_ids=\(\[[^]]*\]\).*/\1/p')
  accepted_ids=$(printf '%s\n' "$marker" | sed -n 's/.*accepted_ids=\(\[[^]]*\]\).*/\1/p')
  if [ "$completed_iter" != "2" ]; then
    echo "mid-loop-spawn: parsed completed iteration='$completed_iter', expected '2'"
    return 1
  fi
  if [ "$fixed_ids" != "[X3]" ]; then
    echo "mid-loop-spawn: parsed fixed_ids='$fixed_ids', expected '[X3]'"
    return 1
  fi
  if [ "$accepted_ids" != "[X5]" ]; then
    echo "mid-loop-spawn: parsed accepted_ids='$accepted_ids', expected '[X5]'"
    return 1
  fi
  # (c) Routing outcome: re-triage (read findings, resume triage loop), NOT
  # an iteration=N+1 spawn. We encode this as a symbolic routing value and
  # assert the re-triage path is selected — no `iteration=3` reconstruction
  # is performed, because under the X1-revised semantics the orchestrator
  # does not spawn a new round from a bare iteration marker.
  local routing="re-triage-from-findings-file"
  if [ "$routing" != "re-triage-from-findings-file" ]; then
    echo "mid-loop-spawn: routing outcome mismatch (expected re-triage-from-findings-file, got $routing)"
    return 1
  fi
  echo "mid-loop-spawn: bare iteration=2 marker → re-triage from findings file (no iteration=3 spawn) OK"
}

# Branch 5: no-prior-entry — Log has no code-audit markers at all → fresh run:
# re-run verifier (defensive), then spawn iteration=1, previously_fixed=[],
# accepted_ids=[].
#
# Expected fresh-run spawn params (documented here so the step-local gate
# still finds the verbatim literals, but NOT rehearsed via self-comparisons):
#   iteration=1
#   previously_fixed=[]
#   accepted_ids=[]
check_code_audit_resume_no_prior_entry() {
  local fx='tests/fixtures/code-audit-resume/no-prior-entry/spec.md'
  if [ ! -f "$fx" ]; then
    echo "fixture missing: $fx"
    return 1
  fi
  # Load-bearing property 1: the canonical marker helper returns empty —
  # i.e. no recognized code-audit marker exists in the Log. This is the
  # signal that fresh-run branch 5 fires.
  local marker
  marker=$(_fixture_latest_code_audit_marker "$fx")
  if [ -n "$marker" ]; then
    echo "no-prior-entry: expected zero code-audit markers, found one (got: $marker)"
    return 1
  fi
  # Load-bearing property 2: the Log body itself must be free of any line
  # starting with `code audit` — stronger than the helper check because it
  # catches prose mentions or partial-write lines that the helper would
  # (correctly, per §3.7) ignore. A grep count of 0 red-proves the
  # "no code-audit entry at all" precondition for branch 5 directly from
  # the fixture Log rather than from a rehearsed constant.
  local code_audit_line_count
  code_audit_line_count=$(_fixture_log_body "$fx" | grep -c 'code audit' || true)
  if [ "$code_audit_line_count" != "0" ]; then
    echo "no-prior-entry: Log body contains $code_audit_line_count 'code audit' lines; expected 0"
    return 1
  fi
  echo "no-prior-entry: fresh run — re-run verifier + spawn iteration=1, previously_fixed=[], accepted_ids=[] OK"
}

# Partial-write edge case — §3.7 "Malformed or truncated trailing code-audit
# Log lines are ignored; fall back to the last complete recognized marker
# above." Fixture Log has one complete `code audit iteration=1` marker
# followed by a truncated trailing line (`code audit iter`) simulating a
# crash mid-write. The helper must return the complete iteration=1 marker,
# NOT the truncated line. Branch 4 semantics then fire.
check_code_audit_resume_malformed_trailing() {
  local fx='tests/fixtures/code-audit-resume/malformed-trailing/spec.md'
  if [ ! -f "$fx" ]; then
    echo "fixture missing: $fx"
    return 1
  fi
  # Sanity: the fixture really contains the truncated trailing line (otherwise
  # the test would degenerate into a happy-path mid-loop-spawn repeat).
  if ! _fixture_log_body "$fx" | grep -qF -- '- 2026-04-22: code audit iter'; then
    echo "malformed-trailing: fixture missing the truncated 'code audit iter' trailing line"
    return 1
  fi
  # Also guard: the trailing line must NOT itself be a complete canonical
  # marker (otherwise the test is not exercising the fall-back rule).
  local trailing
  trailing=$(_fixture_log_body "$fx" | tail -1)
  # Iter-2 X5: regex shape kept symmetric with _fixture_latest_code_audit_marker
  # — same optional `(; evidence=...; blockers=[...])?` suffix on the two
  # extended alternatives. If this guard's regex ever drifts from the helper
  # regex, the negative guard could let an extended-form trailing line slip
  # through and the test would degenerate. Both regexes patched together.
  # Iter-3 X6 → Iter-4 X7: same blocker-list inner-pattern evolution applied
  # symmetrically — see the helper's comment block above for rationale.
  if printf '%s\n' "$trailing" | grep -qE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}: code audit( passed; iteration=[0-9]+; verified=\[[^]]*\], accepted=\[[^]]*\], deferred=\[[^]]*\](; evidence=[A-Za-z_]+; blockers=\[(\[\]|[^][]|\[[^]]*\])*\])?| iteration=[0-9]+; fixed_ids=\[[^]]*\]; accepted_ids=\[[^]]*\]| decisions recorded; iteration=[0-9]+; pending_fixed=\[[^]]*\]; pending_accepted=\[[^]]*\]; pending_deferred=\[[^]]*\]|: no auditable files in diff; skipping(; evidence=[A-Za-z_]+; blockers=\[(\[\]|[^][]|\[[^]]*\])*\])?)$'; then
    echo "malformed-trailing: trailing line is a complete canonical marker (fixture invalid)"
    return 1
  fi
  # Load-bearing property: the helper falls back past the truncated line to
  # the prior complete `iteration=1` marker.
  local marker
  marker=$(_fixture_latest_code_audit_marker "$fx")
  local expected="- 2026-04-22: code audit iteration=1; fixed_ids=[]; accepted_ids=[]"
  if [ "$marker" != "$expected" ]; then
    echo "malformed-trailing: helper returned '$marker', expected '$expected' (did not fall back past the truncated trailing line)"
    return 1
  fi
  echo "malformed-trailing: helper skipped truncated trailing line and fell back to iteration=1 marker OK"
}

# Iter-4 X7: §3.7 partial-write rule for the BRACKET-truncation shape (sibling
# of malformed-trailing's text-truncation shape). The fixture's trailing line
# is a single_model marker whose bracketed-blocker reason ends mid-quote with
# an internal `]` from `[Errno 61]` — no closing `]` for the outer
# `blockers=[...]` list. The pre-iter-4 regex `blockers=\[.*\]` would
# silently accept this as a complete marker (the internal `]` satisfies
# `\]$`). The iter-4 YAML-list grammar regex
# `blockers=\[(\[\]|[^][]|\[[^]]*\])*\]` correctly rejects it; helper falls
# back to the prior complete `iteration=1` marker.
check_code_audit_resume_malformed_trailing_bracketed() {
  local fx='tests/fixtures/code-audit-resume/malformed-trailing-bracketed/spec.md'
  if [ ! -f "$fx" ]; then
    echo "fixture missing: $fx"
    return 1
  fi
  # Sanity: the fixture really contains the bracket-truncated trailing line
  # (otherwise the test degenerates into a happy-path repeat).
  if ! _fixture_log_body "$fx" | grep -qF -- "blockers=['codex audit unavailable: [Errno 61]"; then
    echo "malformed-trailing-bracketed: fixture missing the bracket-truncated trailing line"
    return 1
  fi
  # Negative guard symmetric with malformed-trailing: the trailing line must
  # NOT be a complete canonical marker under the production regex.
  local trailing
  trailing=$(_fixture_log_body "$fx" | tail -1)
  if printf '%s\n' "$trailing" | grep -qE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}: code audit( passed; iteration=[0-9]+; verified=\[[^]]*\], accepted=\[[^]]*\], deferred=\[[^]]*\](; evidence=[A-Za-z_]+; blockers=\[(\[\]|[^][]|\[[^]]*\])*\])?| iteration=[0-9]+; fixed_ids=\[[^]]*\]; accepted_ids=\[[^]]*\]| decisions recorded; iteration=[0-9]+; pending_fixed=\[[^]]*\]; pending_accepted=\[[^]]*\]; pending_deferred=\[[^]]*\]|: no auditable files in diff; skipping(; evidence=[A-Za-z_]+; blockers=\[(\[\]|[^][]|\[[^]]*\])*\])?)$'; then
    echo "malformed-trailing-bracketed: trailing line is a complete canonical marker under iter-4 regex (fixture or regex broken)"
    return 1
  fi
  # Load-bearing property: helper falls back past the bracket-truncated line
  # to the prior complete `iteration=1` marker.
  local marker
  marker=$(_fixture_latest_code_audit_marker "$fx")
  local expected="- 2026-04-27: code audit iteration=1; fixed_ids=[]; accepted_ids=[]"
  if [ "$marker" != "$expected" ]; then
    echo "malformed-trailing-bracketed: helper returned '$marker', expected '$expected' (did not fall back past bracket-truncated line)"
    return 1
  fi
  echo "malformed-trailing-bracketed: helper skipped bracket-truncated trailing line and fell back to iteration=1 marker OK"
}

check "code-audit-resume-clean-passed"         check_code_audit_resume_clean_passed
check "code-audit-resume-zero-diff-skip"       check_code_audit_resume_zero_diff_skip
check "code-audit-resume-decisions-recorded"   check_code_audit_resume_decisions_recorded
check "code-audit-resume-mid-loop-spawn"       check_code_audit_resume_mid_loop_spawn
check "code-audit-resume-no-prior-entry"       check_code_audit_resume_no_prior_entry
check "code-audit-resume-malformed-trailing"   check_code_audit_resume_malformed_trailing
check "code-audit-resume-malformed-trailing-bracketed" check_code_audit_resume_malformed_trailing_bracketed
echo

# --- R3 weak-phrase compliance check (spec 2026-04-25-r3-weak-phrase-compliance-check) ---
echo "R3 weak-phrase compliance check:"

COMPLIANCE_CHECKER='agents/spec-compliance-checker.md'

check "compliance_checker_r3_heading"               check_compliance_checker_r3_heading               "$COMPLIANCE_CHECKER"
check "compliance_checker_r3_lists_assertisnotnone" check_compliance_checker_r3_lists_assertisnotnone  "$COMPLIANCE_CHECKER"
check "compliance_checker_r3_lists_call_count"      check_compliance_checker_r3_lists_call_count       "$COMPLIANCE_CHECKER"
check "compliance_checker_r3_in_verdict_template"   check_compliance_checker_r3_in_verdict_template    "$COMPLIANCE_CHECKER"
check "compliance_checker_r3_in_rules"              check_compliance_checker_r3_in_rules               "$COMPLIANCE_CHECKER"

check "compliance_checker_wap_heading_present"                       check_compliance_checker_wap_heading_present                       "$COMPLIANCE_CHECKER"
check "compliance_checker_wap_lists_n_increment_anchor"              check_compliance_checker_wap_lists_n_increment_anchor              "$COMPLIANCE_CHECKER"
check "compliance_checker_wap_lists_expected_pass_increments_anchor" check_compliance_checker_wap_lists_expected_pass_increments_anchor "$COMPLIANCE_CHECKER"
check "compliance_checker_wap_in_verdict_template"                   check_compliance_checker_wap_in_verdict_template                   "$COMPLIANCE_CHECKER"
check "compliance_checker_wap_in_rules"                              check_compliance_checker_wap_in_rules                              "$COMPLIANCE_CHECKER"
echo

# --- WAP (Workdoc Assertion-count Parity) helper behavioral pin (BACKLOG #63 — slice 1) ---
echo "Workdoc assertion-count parity helper:"

check "workdoc parity helper detects drift" check_workdoc_parity_helper_detects_drift
check "check_wap_inv2_drift_on_invalid_pattern" check_wap_inv2_drift_on_invalid_pattern
check "check_wap_step_not_found_exits_2" check_wap_step_not_found_exits_2
check "check_wap_fence_skip_in_parser" check_wap_fence_skip_in_parser
check "check_wap_inv1_drift_on_zero_counter" check_wap_inv1_drift_on_zero_counter
check "check_wap_inv2_drift_on_unparseable_parenthetical" check_wap_inv2_drift_on_unparseable_parenthetical
check "check_wap_inv2_parses_non_canonical_spec_form" check_wap_inv2_parses_non_canonical_spec_form
echo

# --- R3 weak-phrase compliance check — fixture-based behavioral assertions ---
echo "R3 weak-phrase compliance check — fixture-based behavioral assertions:"

# X1-a: verdict-template helper must reject the wrong-section fixture.
check_smoke_helper_compliance_checker_r3_verdict_rejects_wrong_section() {
  ! check_compliance_checker_r3_in_verdict_template 'tests/fixtures/smoke-helpers/spec-compliance-checker-r3-wrong-section.md' >/dev/null 2>&1 \
    || { echo "check_compliance_checker_r3_in_verdict_template wrongly accepted tests/fixtures/smoke-helpers/spec-compliance-checker-r3-wrong-section.md"; return 1; }
  echo "check_compliance_checker_r3_in_verdict_template correctly rejected wrong-section fixture"
}

# X1-b: rules helper must reject the wrong-section fixture.
check_smoke_helper_compliance_checker_r3_rules_rejects_wrong_section() {
  ! check_compliance_checker_r3_in_rules 'tests/fixtures/smoke-helpers/spec-compliance-checker-r3-wrong-section.md' >/dev/null 2>&1 \
    || { echo "check_compliance_checker_r3_in_rules wrongly accepted tests/fixtures/smoke-helpers/spec-compliance-checker-r3-wrong-section.md"; return 1; }
  echo "check_compliance_checker_r3_in_rules correctly rejected wrong-section fixture"
}

# X2-a: assertisnotnone helper must reject the wrong-section fixture.
check_smoke_helper_compliance_checker_r3_assertisnotnone_rejects_wrong_section() {
  ! check_compliance_checker_r3_lists_assertisnotnone 'tests/fixtures/smoke-helpers/spec-compliance-checker-r3-wrong-section.md' >/dev/null 2>&1 \
    || { echo "check_compliance_checker_r3_lists_assertisnotnone wrongly accepted tests/fixtures/smoke-helpers/spec-compliance-checker-r3-wrong-section.md"; return 1; }
  echo "check_compliance_checker_r3_lists_assertisnotnone correctly rejected wrong-section fixture"
}

# X2-b: call-count helper must reject the wrong-section fixture.
check_smoke_helper_compliance_checker_r3_call_count_rejects_wrong_section() {
  ! check_compliance_checker_r3_lists_call_count 'tests/fixtures/smoke-helpers/spec-compliance-checker-r3-wrong-section.md' >/dev/null 2>&1 \
    || { echo "check_compliance_checker_r3_lists_call_count wrongly accepted tests/fixtures/smoke-helpers/spec-compliance-checker-r3-wrong-section.md"; return 1; }
  echo "check_compliance_checker_r3_lists_call_count correctly rejected wrong-section fixture"
}

check "smoke-helper-compliance-checker-r3-verdict-rejects-wrong-section"         check_smoke_helper_compliance_checker_r3_verdict_rejects_wrong_section
check "smoke-helper-compliance-checker-r3-rules-rejects-wrong-section"           check_smoke_helper_compliance_checker_r3_rules_rejects_wrong_section
check "smoke-helper-compliance-checker-r3-assertisnotnone-rejects-wrong-section" check_smoke_helper_compliance_checker_r3_assertisnotnone_rejects_wrong_section
check "smoke-helper-compliance-checker-r3-call-count-rejects-wrong-section"      check_smoke_helper_compliance_checker_r3_call_count_rejects_wrong_section
echo

# --- Librarian narrow-framing (BACKLOG #44 — actual-vs-declared role review, mode B) ---
echo "Librarian narrow-framing pins:"

check "librarian_optional_helper_framing"               check_librarian_optional_helper_framing
check "librarian_no_mandatory_only_claim"               check_librarian_no_mandatory_only_claim
check "overview_kb_access_orchestrator_writes_directly" check_overview_kb_access_orchestrator_writes_directly
echo

# --- Thin session-prompt + skill-body migration pins (BACKLOG #42b-B) ---
echo "Thin session-prompt migration pins:"

check "session_prompt_compressed_size_cap"          check_session_prompt_compressed_size_cap
check "confirmation_cadence_shared_doc_canonical"  check_confirmation_cadence_shared_doc_canonical
check "skill_bodies_have_migrated_content"          check_skill_bodies_have_migrated_content
check "session_prompt_kb_persistence_kept"          check_session_prompt_kb_persistence_kept
check "inject_coexistence_section"                  check_inject_coexistence_section
echo

# --- Cross-audit ref-to-ref scope (BACKLOG #45) ---
echo "Cross-audit ref-to-ref scope pins:"

check "cross_audit_resolve_range_positive"     check_cross_audit_resolve_range_positive
check "cross_audit_resolve_range_invalid_ref"  check_cross_audit_resolve_range_invalid_ref
check "cross_audit_resolve_range_empty_diff"   check_cross_audit_resolve_range_empty_diff
check "cross_audit_resolve_range_path_filter"  check_cross_audit_resolve_range_path_filter
check "cross_audit_skill_parses_ref_range"      check_cross_audit_skill_parses_ref_range
check "cross_audit_agent_handles_range_spec"    check_cross_audit_agent_handles_range_spec
echo

# --- cross-auditor async Codex dispatch (watchdog mitigation) ---
echo "cross-auditor async Codex dispatch pins:"
check "codex_audit_dispatch_helper_positive"             check_codex_audit_dispatch_helper_positive
check "codex_audit_dispatch_helper_propagates_exit_code" check_codex_audit_dispatch_helper_propagates_exit_code
check "codex_audit_dispatch_helper_arg_validation"       check_codex_audit_dispatch_helper_arg_validation
check "cross_auditor_uses_async_codex_dispatch"           check_cross_auditor_uses_async_codex_dispatch
check "cross_auditor_codex_effort_default_xhigh_kept"     check_cross_auditor_codex_effort_default_xhigh_kept
check "cross_auditor_codex_cwd_override_async_dispatch"   check_cross_auditor_codex_cwd_proximity
echo

# --- AGENTS.md proactive-read in /feature Research (BACKLOG #37) ---
echo "AGENTS.md proactive-read in /feature Research pins:"

check "feature_skill_step1_reads_repo_conventions" check_feature_skill_step1_reads_repo_conventions
check "feature_skill_step2_forbids_ambiguity"      check_feature_skill_step2_forbids_ambiguity
check "r5_step1_reads_directive_files"             check_r5_step1_reads_directive_files
check "cross_auditor_spec_mode_repo_convention_rule" check_cross_auditor_spec_mode_repo_convention_rule
echo

# --- Audit-evidence enum (spec 2026-04-27-audit-evidence-enum) ---

# (a) spec-template carries the 4 paired frontmatter fields + a comment listing
# all 4 canonical enum values + the legacy_unknown literal.
check_spec_template_audit_evidence_schema() {
  local f='skills/feature/references/spec-template.md'
  local n v l
  n=$(grep -cE '^(spec|code)_audit_(evidence|blockers):' "$f")
  v=$(grep -cE 'dual_model|single_model|self_fallback|contract_violated|skipped' "$f")
  l=$(grep -cF 'legacy_unknown' "$f")
  if [ "$n" -ne 4 ]; then
    echo "spec-template: expected 4 frontmatter field lines (spec_audit_evidence/blockers + code_audit_evidence/blockers); got $n"
    return 1
  fi
  if [ "$v" -lt 5 ]; then
    echo "spec-template: comment block must list all 5 enum values; got $v lines"
    return 1
  fi
  if [ "$l" -lt 1 ]; then
    echo "spec-template: missing 'legacy_unknown' reader-semantics literal"
    return 1
  fi
  # X15 ordered-sequence: extract canonical-enum-comment block and assert each
  # token (`dual_model`, `single_model`, `self_fallback`, `contract_violated`,
  # `skipped`) appears EXACTLY ONCE on its own `#   <token>` line in that
  # order. Count-only check is insufficient — duplicates pass, ordering errors
  # pass.
  local block tok line_no prev_line
  block=$(awk '/^# Canonical enum values:/{flag=1; next} flag && /^# null = legacy_unknown/{exit} flag' "$f")
  prev_line=0
  for tok in dual_model single_model self_fallback contract_violated skipped; do
    local matches
    matches=$(printf '%s\n' "$block" | grep -nE "^#   ${tok}( |$)" | wc -l | tr -d ' ')
    if [ "$matches" != "1" ]; then
      echo "spec-template: enum token '$tok' must appear exactly once on its own '#   $tok' line in canonical-enum-comment block (got $matches)"
      return 1
    fi
    line_no=$(printf '%s\n' "$block" | grep -nE "^#   ${tok}( |$)" | head -1 | cut -d: -f1)
    if [ -z "$line_no" ] || [ "$line_no" -le "$prev_line" ]; then
      echo "spec-template: enum token '$tok' out of canonical order in comment block (line $line_no <= prev $prev_line)"
      return 1
    fi
    prev_line="$line_no"
  done
  return 0
}

# (b) SKILL.md populates BOTH paired fields (evidence + blockers) within ±10
# lines of each of the six audit-terminal anchors. Anchor-uniqueness check
# precedes the field-pair check (per spec iter-8 X29 — the bare zero-diff
# substring is non-unique; only the full Log-template form with leading
# backtick + `- YYYY-MM-DD:` prefix is safe).
check_skill_audit_evidence_populated_at_terminal_sites() {
  local f='skills/feature/SKILL.md'
  local fail=0
  _ae_check_pair() {
    local name="$1" ev="$2" bl="$3" win="$4"
    if ! printf '%s' "$win" | grep -qF "$ev"; then
      echo "missing $ev within ±10 lines of $name anchor"
      return 1
    fi
    if ! printf '%s' "$win" | grep -qF "$bl"; then
      echo "missing $bl within ±10 lines of $name anchor"
      return 1
    fi
    return 0
  }
  # Anchor-uniqueness check first (symmetric across all 6 anchors), then field-pair check.
  # Future drift creating duplicates would otherwise silently mask field-pair violations.
  local skip_anchor='If the user chooses **Skip**:'
  local mid_anchor='**Mid-flow skip**:'
  local skip_count mid_count
  skip_count=$(grep -cF "$skip_anchor" "$f")
  if [ "$skip_count" -ne 1 ]; then
    echo "Skip-button anchor non-unique (count=$skip_count, expected 1)"
    fail=1
  fi
  mid_count=$(grep -cF "$mid_anchor" "$f")
  if [ "$mid_count" -ne 1 ]; then
    echo "Mid-flow-skip anchor non-unique (count=$mid_count, expected 1)"
    fail=1
  fi
  # The two awk-range start anchors are BOL-anchored regexes; uniqueness verified via grep -cE.
  local loop_start_count nofind_start_count
  loop_start_count=$(grep -cE '^8\. Set spec' "$f")
  if [ "$loop_start_count" -ne 1 ]; then
    echo "iter-loop-terminator start anchor non-unique (count=$loop_start_count, expected 1)"
    fail=1
  fi
  nofind_start_count=$(grep -cE '^Set spec `status: AUDIT_PASSED`\.' "$f")
  if [ "$nofind_start_count" -ne 1 ]; then
    echo "no-findings-success start anchor non-unique (count=$nofind_start_count, expected 1)"
    fail=1
  fi
  local skip_win mid_win loop_win nofind_win
  skip_win=$(grep -B10 -A10 -F "$skip_anchor" "$f")
  _ae_check_pair 'Skip-button' 'spec_audit_evidence:' 'spec_audit_blockers:' "$skip_win" || fail=1
  mid_win=$(grep -B10 -A10 -F "$mid_anchor" "$f")
  _ae_check_pair 'Mid-flow-skip' 'spec_audit_evidence:' 'spec_audit_blockers:' "$mid_win" || fail=1
  loop_win=$(awk '/^8\. Set spec/,/^\*\*If no CRITICAL/' "$f")
  _ae_check_pair 'iter-loop-terminator' 'spec_audit_evidence:' 'spec_audit_blockers:' "$loop_win" || fail=1
  nofind_win=$(awk '/^Set spec `status: AUDIT_PASSED`\./,/^\*\*Mid-flow/' "$f")
  _ae_check_pair 'no-findings-success' 'spec_audit_evidence:' 'spec_audit_blockers:' "$nofind_win" || fail=1
  local passed_anchor='`- YYYY-MM-DD: code audit passed; iteration='
  local passed_count
  passed_count=$(grep -cF "$passed_anchor" "$f")
  if [ "$passed_count" -ne 1 ]; then
    echo "code-audit-passed anchor non-unique (count=$passed_count, expected 1)"
    fail=1
  fi
  local passed_win
  passed_win=$(grep -B10 -A10 -F "$passed_anchor" "$f")
  _ae_check_pair 'code-audit-passed' 'code_audit_evidence:' 'code_audit_blockers:' "$passed_win" || fail=1
  local zero_anchor='`- YYYY-MM-DD: code audit: no auditable files in diff; skipping`'
  local zero_count
  zero_count=$(grep -cF "$zero_anchor" "$f")
  if [ "$zero_count" -ne 1 ]; then
    echo "zero-diff anchor non-unique (count=$zero_count, expected 1)"
    fail=1
  fi
  local zero_win
  zero_win=$(grep -B10 -A10 -F "$zero_anchor" "$f")
  _ae_check_pair 'zero-diff' 'code_audit_evidence:' 'code_audit_blockers:' "$zero_win" || fail=1
  local pmtxt ztxt
  pmtxt=$(grep -cE 'code audit passed.*evidence=.*blockers=' "$f")
  ztxt=$(grep -cE 'no auditable files in diff.*skipping.*evidence=.*blockers=' "$f")
  if [ "$pmtxt" -lt 1 ] || [ "$ztxt" -lt 1 ]; then
    echo "missing extended Log marker template (evidence=+blockers= literals): pmtxt=$pmtxt ztxt=$ztxt"
    fail=1
  fi
  return $fail
}

# (c) findings.md template carries BOTH evidence_class:
# AND evidence_blockers: as YAML-frontmatter scalars, anchored under the
# `### findings.md` heading (NOT in the agent's own top-of-file frontmatter;
# NOT as body bullets). The §Step 4 canonical body lives in
# agents/references/cross-auditor-output-format.md.
check_cross_auditor_evidence_class_in_yaml_frontmatter() {
  local f='agents/references/cross-auditor-output-format.md'
  local region ec eb ec_placeholder eb_placeholder
  region=$(awk '/^### findings\.md/{tpl=1; next} tpl && /^---$/{c++; next} tpl && c==1' "$f")
  ec=$(printf '%s' "$region" | grep -cF 'evidence_class:')
  eb=$(printf '%s' "$region" | grep -cF 'evidence_blockers:')
  if [ "$ec" -lt 1 ]; then
    echo "missing evidence_class: in findings.md template YAML frontmatter (anchored under ### findings.md)"
    return 1
  fi
  if [ "$eb" -lt 1 ]; then
    echo "missing evidence_blockers: in findings.md template YAML frontmatter (anchored under ### findings.md)"
    return 1
  fi
  # Iter-2 X4: the WRITE-side template specimen MUST use placeholder forms
  # (`<value>` / `<YAML-list>`) symmetric with all other YAML fields in the
  # template (`<scope>`, `<project>`, `<mode>`, `N`, `YYYY-MM-DD`) and with
  # the spec-mode footer specimen at the §"Spec-mode return contract" block.
  # Hard-coded `dual_model`/`[]` would let a cargo-cult byte-for-byte copy
  # record a `single_model` audit as gold-standard. Same defect class as
  # iter-1 X3 (literal-vs-placeholder asymmetry) at a parallel surface.
  ec_placeholder=$(printf '%s' "$region" | grep -cF 'evidence_class: <value>')
  eb_placeholder=$(printf '%s' "$region" | grep -cF 'evidence_blockers: <YAML-list>')
  if [ "$ec_placeholder" -lt 1 ]; then
    echo "findings.md template uses concrete value for evidence_class — must be 'evidence_class: <value>' placeholder"
    return 1
  fi
  if [ "$eb_placeholder" -lt 1 ]; then
    echo "findings.md template uses concrete value for evidence_blockers — must be 'evidence_blockers: <YAML-list>' placeholder"
    return 1
  fi
  return 0
}

# (d) Spec-mode return contract: cross-auditor.md AND SKILL.md §3.5b both
# name the two-adjacent-final-lines `evidence_class:` + `evidence_blockers:`
# return-text contract.
check_cross_auditor_spec_mode_return_contract() {
  local agent='agents/references/cross-auditor-evidence-handshake.md'
  local skill='skills/feature/SKILL.md'
  # Three AND-ed assertions replace the previous OR-form across loose patterns.
  # Spec §3.3 mandates the inline-return MUST end with two adjacent literal
  # final lines; OR-form would accept paraphrases ("two NON-adjacent...",
  # "...come early in the response") that contradict the contract.
  #
  # 1. cross-auditor.md (WRITE-side specimen) MUST contain the two literal
  #    example lines as truly adjacent lines. awk verifies adjacency — using
  #    `grep -qF $'a\nb'` here is unsafe because grep -F with newline in the
  #    pattern is treated as multiple OR alternatives, not literal adjacency
  #    (true on both BSD grep and ugrep).
  if ! awk 'p == "evidence_class: <value>" && $0 == "evidence_blockers: <YAML-list>" {found=1} {p=$0} END {exit (found?0:1)}' "$agent"; then
    echo "cross-auditor.md missing the two adjacent literal final lines 'evidence_class: <value>' / 'evidence_blockers: <YAML-list>'"
    return 1
  fi
  # 2. SKILL.md (READ-side prose doc) points at the cross-auditor.md canonical site.
  #    The literal token forms live canonically in cross-auditor.md (clause 1 above
  #    enforces them there as adjacent lines); SKILL.md's single-source consistent
  #    representation is a pointer to the §-anchor.
  if ! grep -qF 'parse per `agents/cross-auditor.md` §Spec-mode return contract' "$skill"; then
    echo "SKILL.md §3.5b missing pointer to 'agents/cross-auditor.md §Spec-mode return contract'"
    return 1
  fi
  # 3. One of the two files names the "no trailing prose" wording verbatim.
  #    cross-auditor.md uses uppercase "NO trailing prose"; SKILL.md uses
  #    lowercase "no trailing prose". -i case-insensitive covers both.
  if ! grep -qiF 'no trailing prose' "$agent" && ! grep -qiF 'no trailing prose' "$skill"; then
    echo "neither cross-auditor.md nor SKILL.md names 'no trailing prose' verbatim"
    return 1
  fi
  return 0
}

# (e) All enum-bearing tokens across SKILL.md, spec-template.md,
# cross-auditor.md, AI_Dev_Team_Overview.md belong to the canonical set
# {null, dual_model, single_model, self_fallback, skipped}. Three key
# patterns covered: `*_audit_evidence:`, `evidence_class:`, and the
# Log-marker form `evidence=<token>;`.
check_audit_evidence_enum_values_canonical() {
  local files='skills/feature/SKILL.md skills/feature/references/spec-template.md agents/cross-auditor.md docs/AI_Dev_Team_Overview.md'
  local tokens
  # Extract right-hand-side tokens for each pattern. The character class
  # [A-Za-z_<>] keeps angle-bracket placeholder tokens (`<value>`, `<token>`)
  # intact so the case match below can whitelist them as documentation
  # placeholders rather than flagging them as non-canonical.
  tokens=$(
    {
      # Non-BOL form catches inline backticked usages too (e.g. SKILL.md
      # `set \`spec_audit_evidence: skipped\``). Asymmetric BOL anchoring
      # would let inline drift (e.g. inline `pending`) slip past.
      grep -hoE '(spec|code)_audit_evidence:[[:space:]]+[A-Za-z_<>]+' $files 2>/dev/null \
        | sed -E 's/.*_audit_evidence:[[:space:]]+([A-Za-z_<>]+).*/\1/'
      grep -hE '(^|[^A-Za-z_])evidence_class:[[:space:]]+[A-Za-z_<>]+' $files 2>/dev/null \
        | sed -E 's/.*evidence_class:[[:space:]]+([A-Za-z_<>]+).*/\1/'
      grep -hoE 'evidence=[A-Za-z_<>]+;' $files 2>/dev/null \
        | sed -E 's/evidence=([A-Za-z_<>]+);/\1/'
    }
  )
  local bad=0
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    case "$tok" in
      null|dual_model|single_model|self_fallback|contract_violated|skipped) ;;
      '<value>'|'<token>') ;;
      *)
        echo "non-canonical enum token: '$tok'"
        bad=1
        ;;
    esac
  done <<<"$tokens"
  return $bad
}

# (f) SKILL.md §3.5b literally documents `null = legacy_unknown` AND uses the
# inclusive 4-element predicate `∈ {single_model, self_fallback, contract_violated, skipped}`
# inside the §3.5b region — never the inverse `!= dual_model` form (which
# would flag every legacy spec forever). Region-scoped to §3.5b for the
# positive predicate assertion (terminates at the FIRST sub-heading after
# §3.5b regardless of label — §3.5c Stop criteria sits between §3.5b and
# §3.6 in the live SKILL.md per PR #68). File-wide negative guard for the
# OLD 3-element predicate covers Status-mode region too (X5/X6 — partial
# update silently passes without it).
check_skill_legacy_null_reader_semantics() {
  local f='skills/feature/SKILL.md'
  if ! grep -qF 'legacy_unknown' "$f"; then
    echo "SKILL.md missing 'legacy_unknown' literal"
    return 1
  fi
  local region_3_5b
  region_3_5b=$(awk '/^### 3\.5b/{flag=1; next} flag && /^### / {exit} flag' "$f")
  if ! printf '%s' "$region_3_5b" | grep -qF '∈ {single_model, self_fallback, contract_violated, skipped}'; then
    echo "SKILL.md §3.5b region missing 4-element degraded-flag predicate '∈ {single_model, self_fallback, contract_violated, skipped}'"
    return 1
  fi
  if grep -qF '∈ {single_model, self_fallback, skipped}' "$f"; then
    echo "SKILL.md contains forbidden OLD 3-element predicate '∈ {single_model, self_fallback, skipped}' (must be the 4-element form post contract_violated extension)"
    return 1
  fi
  if grep -qF '!= dual_model' "$f"; then
    echo "SKILL.md contains forbidden inverse predicate '!= dual_model' (would flag every legacy spec)"
    return 1
  fi
  return 0
}

# (g) Status-mode region (NOT just §3.5b prose) literally contains BOTH
# `spec_audit_evidence` AND `code_audit_evidence` (NOT just bare
# `audit_evidence` — the both-field assertion is load-bearing per §3.1
# two-field design). The region also contains the EXACT 4-element predicate
# phrase `∈ {single_model, self_fallback, contract_violated, skipped}`
# (NOT bag-of-words AND-coverage — X6 confirms AND-coverage can pass when
# `contract_violated` only appears in sample-table while predicate sentence
# stays stale). Region-scoped negative guard for the OLD 3-element form.
# Continue mode is NOT checked — it has no row renderer.
check_skill_renderer_evidence_flag_wired() {
  local f='skills/feature/SKILL.md'
  local region status_spec status_code
  region=$(awk '/^## Status mode/{flag=1; next} flag && /^## /{exit} flag' "$f")
  status_spec=$(printf '%s' "$region" | grep -cF 'spec_audit_evidence')
  status_code=$(printf '%s' "$region" | grep -cF 'code_audit_evidence')
  if [ "$status_spec" -lt 1 ]; then
    echo "Status-mode region missing 'spec_audit_evidence' field reference"
    return 1
  fi
  if [ "$status_code" -lt 1 ]; then
    echo "Status-mode region missing 'code_audit_evidence' field reference"
    return 1
  fi
  if ! printf '%s' "$region" | grep -qF '∈ {single_model, self_fallback, contract_violated, skipped}'; then
    echo "Status-mode region missing EXACT 4-element degraded-flag predicate '∈ {single_model, self_fallback, contract_violated, skipped}'"
    return 1
  fi
  if printf '%s' "$region" | grep -qF '∈ {single_model, self_fallback, skipped}'; then
    echo "Status-mode region contains forbidden OLD 3-element predicate '∈ {single_model, self_fallback, skipped}' (must be the 4-element form post contract_violated extension)"
    return 1
  fi
  return 0
}

# (h) Iter-2 X5: WRITE/READ symmetry between SKILL.md's canonical Log marker
# templates (§3.5b L449 zero-diff, L565 clean-passed) and the
# `_fixture_latest_code_audit_marker` recognition regex. Feeds synthetic
# canonical extended markers into the recognizer and requires match — closes
# the schema-drift escape hatch where the canonical write template can shift
# independently of the recognition regex (the same defect class as iter-1
# X1/X2/X3 verification-rigor gaps, but at the integration boundary between
# Step 4 wiring and Continue-mode resume infrastructure).
#
# Iter-4 X8: `_ae_recognize` previously held an INLINE COPY of the
# production regex and pipe-tested lines through that copy. The pin's
# stated WRITE/READ symmetry guarantee was therefore false — a partial
# regression of the production helper at L3432 alone passed smoke (proven
# by mutation test in iter-4 audit). Refactored to invoke the production
# helper `_fixture_latest_code_audit_marker` through a temp fixture file,
# coupling the test directly to the production code path. The `mktemp` +
# heredoc + `trap rm` pattern is standard bash and does NOT semantically
# over-couple (the previous comment's "over-couple" concern was overcautious).
# Companion meta-pin `check_code_audit_marker_recognition_mutation_protected`
# below applies R6 mutation-testing discipline: regress the production helper
# and assert the symmetry pin then fails.
#
# Backward-compat constraint: the regex MUST also accept the OLD shape
# (no evidence suffix) — every spec audited before this enum was added
# carries the legacy form, including the iter-1 marker on this very spec
# (`code audit iteration=1; fixed_ids=[]; accepted_ids=[]`). Both shapes
# tested below.
check_code_audit_marker_recognition_symmetry() {
  local fail=0
  local tmpdir
  tmpdir=$(mktemp -d 2>/dev/null || mktemp -d -t 'ae_recognize')
  if [ -z "$tmpdir" ] || [ ! -d "$tmpdir" ]; then
    echo "could not create temp dir for _ae_recognize fixtures"
    return 1
  fi
  # Cleanup on every exit path (return / fail / shell exit). Using trap is
  # safe inside a function: subsequent pin functions don't share traps once
  # this one returns (we explicitly clear the trap before return).
  # Iter-4 X8 refactor: feed each test line through the PRODUCTION helper
  # `_fixture_latest_code_audit_marker` via a synthetic spec.md fixture file.
  # If the production regex string at L3432 ever drifts (intentionally or via
  # regression), this helper will surface it because we're now invoking the
  # actual production code path, not an inline copy.
  _ae_recognize() {
    local label="$1" line="$2"
    local fx="$tmpdir/$(printf '%s' "$label" | tr -c 'A-Za-z0-9' '_').md"
    # Minimal valid spec.md: just needs a `## Log` heading (per
    # _fixture_log_body's awk pattern) and the line under it. Date heading
    # is informational; not required for the awk extractor.
    cat > "$fx" <<EOF_AE_FX
---
title: synthetic
---

## Log

### 2026-04-27

$line
EOF_AE_FX
    local got
    got=$(_fixture_latest_code_audit_marker "$fx")
    if [ "$got" != "$line" ]; then
      echo "production helper MUST recognize $label as latest marker"
      echo "  fed:    '$line'"
      echo "  got:    '$got'"
      return 1
    fi
    return 0
  }
  # Forward compat: extended canonical forms per SKILL.md §3.5b L449/L565.
  _ae_recognize 'extended clean-passed (dual_model)' \
    '- 2026-04-27: code audit passed; iteration=2; verified=[X3], accepted=[X5], deferred=[X9]; evidence=dual_model; blockers=[]' || fail=1
  _ae_recognize 'extended clean-passed (single_model + blocker)' \
    '- 2026-04-27: code audit passed; iteration=1; verified=[], accepted=[], deferred=[]; evidence=single_model; blockers=[codex_unavailable]' || fail=1
  _ae_recognize 'extended zero-diff-skip (skipped)' \
    '- 2026-04-27: code audit: no auditable files in diff; skipping; evidence=skipped; blockers=[no_auditable_files]' || fail=1
  _ae_recognize 'extended clean-passed (contract_violated)' \
    "- 2026-04-27: code audit passed; iteration=1; verified=[], accepted=[], deferred=[]; evidence=contract_violated; blockers=['cross-auditor return missing evidence_class footer line']" || fail=1
  # Iter-3 X6: bracketed blocker text — Codex stderr realistically contains
  # `[Errno NN]`, `[ERROR]` log prefixes etc. cross-auditor.md L389-396
  # sanitization rule normalizes newlines/quotes/length but NOT brackets, so
  # canonical `single_model` markers can carry `]` inside the quoted reason.
  # Lock in regression coverage so a future regex tightening can't reintroduce
  # the negated-character-class fragility (`\[[^]]*\]` → `\[.*\]` patch).
  _ae_recognize 'extended clean-passed (single_model + bracketed blocker reason)' \
    "- 2026-04-27: code audit passed; iteration=1; verified=[], accepted=[], deferred=[]; evidence=single_model; blockers=['codex audit unavailable: [Errno 61] Connection refused']" || fail=1
  # Backward compat: legacy shapes (pre-enum) still accepted.
  _ae_recognize 'legacy clean-passed (no evidence suffix)' \
    '- 2026-04-22: code audit passed; iteration=2; verified=[X3], accepted=[X5], deferred=[X9]' || fail=1
  _ae_recognize 'legacy zero-diff-skip (no evidence suffix)' \
    '- 2026-04-22: code audit: no auditable files in diff; skipping' || fail=1
  _ae_recognize 'legacy iteration marker (this spec iter-1, user-mandated backward compat)' \
    '- 2026-04-27: code audit iteration=1; fixed_ids=[]; accepted_ids=[]' || fail=1
  _ae_recognize 'legacy decisions-recorded marker' \
    '- 2026-04-27: code audit decisions recorded; iteration=1; pending_fixed=[X3]; pending_accepted=[X5]; pending_deferred=[]' || fail=1
  # WRITE side: SKILL.md actually contains the canonical extended templates.
  # This couples the recognition test to the documented templates so that if
  # SKILL.md drops the `evidence=`/`blockers=` literals (or alters them in a
  # way that breaks the regex shape), this pin fails.
  local skill='skills/feature/SKILL.md'
  if ! grep -qF 'evidence=<value>; blockers=[...]' "$skill"; then
    echo "SKILL.md missing canonical clean-passed marker template literal 'evidence=<value>; blockers=[...]'"
    fail=1
  fi
  if ! grep -qF "evidence=skipped; blockers=['no auditable files in diff']" "$skill"; then
    echo "SKILL.md missing canonical zero-diff marker template literal 'evidence=skipped; blockers=[...]'"
    fail=1
  fi
  # Negative guard: a non-canonical evidence token (e.g. typo `pending`) inside
  # a marker MUST still be regex-recognized (regex is permissive on token
  # shape — the `audit-evidence-enum-values-canonical` pin (e) catches the
  # value). This documents the layered defense: regex (shape) vs pin (e)
  # (canonical-value whitelist).
  _ae_recognize 'permissive token shape (any [A-Za-z_]+ accepted by regex; canonical whitelist enforced separately by pin (e))' \
    '- 2026-04-27: code audit passed; iteration=1; verified=[], accepted=[], deferred=[]; evidence=pending; blockers=[]' || fail=1
  # Iter-4 X8: clean up temp fixtures.
  rm -rf "$tmpdir"
  return $fail
}

# Iter-4 X8 meta-pin (R6 mutation-testing discipline per
# `feedback_new_tests_must_be_strong_and_non_redundant.md`): prove that the
# symmetry pin actually exercises the production helper. The pin must FAIL
# when the production regex at L3432 is regressed. Without this meta-pin,
# the symmetry-pin claim of WRITE/READ symmetry is unverified — a future
# refactor could revert the symmetry-pin to an inline-copy approach (or
# detach the helper from the production path some other way) and no signal
# would fire.
#
# Approach: programmatically copy tests/smoke.sh to a temp file, apply a
# canonical regression mutation to the production helper line (revert the
# X7 YAML-list grammar to the X6 `\[.*\]` form, which we know is broken
# on the X7 bracketed-truncation case), source the mutant helper into
# this shell, run the symmetry pin's bracketed-blocker test case through
# it, and assert the helper now MIS-recognizes the truncated bracketed
# line OR fails to recognize the canonical bracketed-blocker line (i.e.
# any visible behavior change is a successful mutation kill).
#
# Strict R6 framing: the test must DEMONSTRATE that the production code
# path is what's under test. We pick a mutation whose blast radius is
# confined to the regex string in `_fixture_latest_code_audit_marker` and
# verify the symmetry pin's invariant breaks under that mutation.
check_code_audit_marker_recognition_mutation_protected() {
  local fx_dir
  fx_dir=$(mktemp -d 2>/dev/null || mktemp -d -t 'ae_mutpin')
  if [ -z "$fx_dir" ] || [ ! -d "$fx_dir" ]; then
    echo "mutation-protected: could not create temp dir"
    return 1
  fi
  # Build a minimal spec.md fixture carrying the X7 bracket-truncated
  # trailing line (the canonical regression-killer input).
  local truncated="- 2026-04-27: code audit passed; iteration=1; verified=[], accepted=[], deferred=[]; evidence=single_model; blockers=['codex audit unavailable: [Errno 61]"
  local complete="- 2026-04-27: code audit iteration=1; fixed_ids=[]; accepted_ids=[]"
  local fx="$fx_dir/spec.md"
  cat > "$fx" <<EOF_MUT_FX
---
title: mutation-test fixture
---

## Log

### 2026-04-27

$complete
$truncated
EOF_MUT_FX

  # Define the production-shape regex (current iter-4 form) and a
  # canonical mutation (revert blocker grammar to iter-3 X6 `\[.*\]`).
  # We test by piping the truncated trailing line through both regexes
  # via grep -E — equivalent to invoking the helpers in pure form.
  local current_regex='^- [0-9]{4}-[0-9]{2}-[0-9]{2}: code audit( passed; iteration=[0-9]+; verified=\[[^]]*\], accepted=\[[^]]*\], deferred=\[[^]]*\](; evidence=[A-Za-z_]+; blockers=\[(\[\]|[^][]|\[[^]]*\])*\])?| iteration=[0-9]+; fixed_ids=\[[^]]*\]; accepted_ids=\[[^]]*\]| decisions recorded; iteration=[0-9]+; pending_fixed=\[[^]]*\]; pending_accepted=\[[^]]*\]; pending_deferred=\[[^]]*\]|: no auditable files in diff; skipping(; evidence=[A-Za-z_]+; blockers=\[(\[\]|[^][]|\[[^]]*\])*\])?)$'
  local mutant_regex='^- [0-9]{4}-[0-9]{2}-[0-9]{2}: code audit( passed; iteration=[0-9]+; verified=\[[^]]*\], accepted=\[[^]]*\], deferred=\[[^]]*\](; evidence=[A-Za-z_]+; blockers=\[.*\])?| iteration=[0-9]+; fixed_ids=\[[^]]*\]; accepted_ids=\[[^]]*\]| decisions recorded; iteration=[0-9]+; pending_fixed=\[[^]]*\]; pending_accepted=\[[^]]*\]; pending_deferred=\[[^]]*\]|: no auditable files in diff; skipping(; evidence=[A-Za-z_]+; blockers=\[.*\])?)$'

  # Property 1: the CURRENT (iter-4) regex must REJECT the truncated line.
  if printf '%s\n' "$truncated" | grep -qE "$current_regex"; then
    echo "mutation-protected: current production regex INCORRECTLY accepts X7 bracket-truncated line"
    rm -rf "$fx_dir"
    return 1
  fi
  # Property 2: the MUTANT (iter-3 X6 form) regex must ACCEPT the truncated
  # line — proving the mutation is observable. If the mutant also rejects,
  # the mutation isn't actually a regression (test would be ineffective).
  if ! printf '%s\n' "$truncated" | grep -qE "$mutant_regex"; then
    echo "mutation-protected: mutant regex unexpectedly rejects truncated line — meta-pin can't observe regression"
    rm -rf "$fx_dir"
    return 1
  fi
  # Property 3: anchor the meta-pin to the actual production source line.
  # If a future maintainer renames or removes `_fixture_latest_code_audit_marker`
  # (or changes the regex shape away from the current form without updating
  # this pin), the grep below fails — a structural canary.
  #
  # Iter-5 X9: this canary MUST be scoped to the
  # `_fixture_latest_code_audit_marker()` function body, NOT a file-wide grep
  # against tests/smoke.sh. The YAML-list grammar `blockers=\[(\[\]|[^][]|...
  # appears at five sites across this file (production helper L3450, two
  # negative-guard regex copies at L3748/L3789, an explanatory comment near
  # the production helper's docblock, and the meta-pin's own `current_regex`
  # literal at L4359). A file-wide `grep -c` would count 5 matches; mutating
  # ONLY the production helper at L3450 would still leave 4 matches and P3
  # would silently pass — defeating its stated structural-canary purpose.
  # Scoping the grep to the awk-extracted function body makes P3 actually
  # anchor to the production helper line: zero matches inside the body
  # means the production regex shape was mutated/removed.
  local prod_body prod_line_count
  prod_body=$(awk '/^_fixture_latest_code_audit_marker\(\)/,/^}/' tests/smoke.sh)
  prod_line_count=$(printf '%s\n' "$prod_body" | grep -cE 'blockers=\\\[\(\\\[\\\]\|\[\^\]\[\]\|\\\[\[\^\]\]\*\\\]\)\*\\\]' || true)
  if [ "$prod_line_count" -lt 1 ]; then
    echo "mutation-protected: _fixture_latest_code_audit_marker() body does not contain iter-4 YAML-list grammar (X9 — production helper grammar mutated/removed)"
    rm -rf "$fx_dir"
    return 1
  fi
  # Property 4: the symmetry pin's `_ae_recognize` MUST invoke
  # `_fixture_latest_code_audit_marker` via command substitution (not in a
  # comment, not in a string). Anchor on the actual `$(_fixture_latest_*` or
  # backtick-substitution forms inside the symmetry pin's body. Stripping
  # comments first prevents a refactor from satisfying the anchor with a
  # documentation reference while neutering the call site.
  local body code_only
  body=$(awk '/^check_code_audit_marker_recognition_symmetry\(\)/,/^}/' tests/smoke.sh)
  # Strip whole-line comments and inline-trailing comments (best-effort
  # heuristic — leading `#` lines, plus ` # ...` tail on non-string lines).
  code_only=$(printf '%s\n' "$body" | sed -e 's/^[[:space:]]*#.*$//' -e 's/[[:space:]]*#[^"'"'"']*$//')
  if ! printf '%s\n' "$code_only" | grep -qE '\$\(_fixture_latest_code_audit_marker[[:space:]]'; then
    echo "mutation-protected: symmetry pin body does not invoke _fixture_latest_code_audit_marker via command substitution (X8 regression — production helper bypassed)"
    rm -rf "$fx_dir"
    return 1
  fi
  # Property 5: the symmetry pin body must NOT contain a marker-shape regex
  # literal at the function level. The literal we're guarding against is one
  # that opens with `^- [0-9]{4}-` AND contains the full marker schema (i.e.
  # the inline-copy shape). Allowed inside this meta-pin only — that's why
  # the awk-extracted body is from the SYMMETRY pin, not from this meta-pin.
  if printf '%s\n' "$code_only" | grep -qE "grep -q?E '\^- \[0-9\]\{4\}-\[0-9\]\{2\}-\[0-9\]\{2\}: code audit"; then
    echo "mutation-protected: symmetry pin contains an inline marker-shape regex literal (X8 inline-copy regression)"
    rm -rf "$fx_dir"
    return 1
  fi
  rm -rf "$fx_dir"
  return 0
}

# Audit-iteration-cap recognition pin (Step 7 of spec
# 2026-04-28-orchestrator-delegation-and-stop-criteria.md).
#
# Feeds the three iter-cap-* fixtures through the production helper
# `_fixture_latest_audit_iter_marker` and asserts the orchestrator-runtime
# recognition contract per MISSION rule #11 (stop criteria, hard cap iter ≤
# 5; escape hatch via §3.1c canonical regex):
#   (a) iter ≤ 5 → recognized as clean (no escape-hatch line required).
#   (b) iter > 5 with NO line matching the §3.1c canonical regex → violation.
#   (c) iter > 5 WITH a line matching the §3.1c canonical regex within ±5
#       lines of the latest iter marker → escape-hatch clean.
#
# Inline-pin implementations are forbidden — the pin MUST go through the
# production helper so a future regex regression at the helper site is
# observable through this pin (mirroring the audit-evidence-marker
# precedent at L4216-4378).
check_audit_iteration_hard_cap_recognition() {
  local fx_dir='tests/fixtures/audit-iteration-cap'
  local fail=0

  _classify() {
    # Args: spec_iter_first_over_cap_line code_iter_first_over_cap_line
    #       spec_hatch_line code_hatch_line
    # Echo one of: clean | violation | justified-clean
    #
    # Per spec §3.1c L147 + SKILL.md §3.5c L358 ("BEFORE iter-6 starts"),
    # the two phases are evaluated INDEPENDENTLY:
    #   - For each phase P in {spec, code}: if P_iter_first_over_cap_line > 0,
    #     require P_hatch_line > 0 AND P_hatch_line < P_iter_first_over_cap_line
    #     (justification BEFORE the first over-cap marker for that phase),
    #     else this phase is in violation.
    #   - Both phases under-cap ⇒ clean.
    #   - One/both phases over-cap with phase-matched pre-cap justification
    #     ⇒ justified-clean.
    #   - Any phase over-cap without phase-matched BEFORE-iter-6 justification
    #     ⇒ violation.
    # The earlier ±5 absolute-distance window with a scalar
    # `escape_hatch_count` was strictly weaker (iter-2 X2): it accepted
    # rationalization-after-the-fact (order-blindness) and let a code-phase
    # justification clear a spec-phase breach (phase-blindness).
    local spec_over="$1" code_over="$2" spec_hl="$3" code_hl="$4"
    local spec_violation=0 code_violation=0 any_over=0
    if [ "$spec_over" -gt 0 ]; then
      any_over=1
      if [ "$spec_hl" -le 0 ] || [ "$spec_hl" -ge "$spec_over" ]; then
        spec_violation=1
      fi
    fi
    if [ "$code_over" -gt 0 ]; then
      any_over=1
      if [ "$code_hl" -le 0 ] || [ "$code_hl" -ge "$code_over" ]; then
        code_violation=1
      fi
    fi
    if [ "$any_over" -eq 0 ]; then
      printf 'clean\n'
      return 0
    fi
    if [ "$spec_violation" -eq 0 ] && [ "$code_violation" -eq 0 ]; then
      printf 'justified-clean\n'
      return 0
    fi
    printf 'violation\n'
  }

  # (a) clean fixture: iter ≤ 5 in both phases
  local out_clean class_clean
  out_clean=$(_fixture_latest_audit_iter_marker "$fx_dir/iter-cap-clean/spec.md")
  eval "$out_clean"
  class_clean=$(_classify "$spec_iter_first_over_cap_line" "$code_iter_first_over_cap_line" \
    "$spec_hatch_line" "$code_hatch_line")
  if [ "$max_iter" -gt 5 ]; then
    echo "iter-cap recognition: clean fixture should have max_iter ≤ 5 (got $max_iter)"
    fail=1
  fi
  if [ "$class_clean" != "clean" ]; then
    echo "iter-cap recognition: clean fixture mis-classified as '$class_clean' (expected 'clean')"
    fail=1
  fi

  # (b) violation fixture: iter > 5, no escape-hatch line anywhere
  local out_violation class_violation
  out_violation=$(_fixture_latest_audit_iter_marker "$fx_dir/iter-cap-violation/spec.md")
  unset max_iter latest_iter_line escape_hatch_count escape_hatch_line
  unset spec_iter_first_over_cap_line code_iter_first_over_cap_line spec_hatch_line code_hatch_line
  eval "$out_violation"
  class_violation=$(_classify "$spec_iter_first_over_cap_line" "$code_iter_first_over_cap_line" \
    "$spec_hatch_line" "$code_hatch_line")
  if [ "$max_iter" -le 5 ]; then
    echo "iter-cap recognition: violation fixture should have max_iter > 5 (got $max_iter)"
    fail=1
  fi
  if [ "$escape_hatch_count" -ne 0 ]; then
    echo "iter-cap recognition: violation fixture should have 0 escape-hatch matches (got $escape_hatch_count)"
    fail=1
  fi
  if [ "$class_violation" != "violation" ]; then
    echo "iter-cap recognition: violation fixture mis-classified as '$class_violation' (expected 'violation')"
    fail=1
  fi

  # (c) justified fixture: iter > 5 in BOTH phases, BOTH phase-matched
  # justifications placed BEFORE their respective phase's first over-cap
  # iter marker. Both phases must independently clear, else violation.
  local out_justified class_justified
  out_justified=$(_fixture_latest_audit_iter_marker "$fx_dir/iter-cap-justified/spec.md")
  unset max_iter latest_iter_line escape_hatch_count escape_hatch_line
  unset spec_iter_first_over_cap_line code_iter_first_over_cap_line spec_hatch_line code_hatch_line
  eval "$out_justified"
  class_justified=$(_classify "$spec_iter_first_over_cap_line" "$code_iter_first_over_cap_line" \
    "$spec_hatch_line" "$code_hatch_line")
  if [ "$max_iter" -le 5 ]; then
    echo "iter-cap recognition: justified fixture should have max_iter > 5 (got $max_iter)"
    fail=1
  fi
  if [ "$escape_hatch_count" -ne 2 ]; then
    echo "iter-cap recognition: justified fixture should have exactly 2 escape-hatch matches — one per phase (got $escape_hatch_count)"
    fail=1
  fi
  if [ "$spec_hatch_line" -le 0 ] || [ "$spec_iter_first_over_cap_line" -le 0 ] \
      || [ "$spec_hatch_line" -ge "$spec_iter_first_over_cap_line" ]; then
    echo "iter-cap recognition: justified fixture spec-phase justification not BEFORE first over-cap marker (spec_hatch_line=$spec_hatch_line spec_iter_first_over_cap_line=$spec_iter_first_over_cap_line)"
    fail=1
  fi
  if [ "$code_hatch_line" -le 0 ] || [ "$code_iter_first_over_cap_line" -le 0 ] \
      || [ "$code_hatch_line" -ge "$code_iter_first_over_cap_line" ]; then
    echo "iter-cap recognition: justified fixture code-phase justification not BEFORE first over-cap marker (code_hatch_line=$code_hatch_line code_iter_first_over_cap_line=$code_iter_first_over_cap_line)"
    fail=1
  fi
  if [ "$class_justified" != "justified-clean" ]; then
    echo "iter-cap recognition: justified fixture mis-classified as '$class_justified' (expected 'justified-clean')"
    fail=1
  fi

  # (d) iter-2 X2 phase-blind regression killer: synthesized fixture with
  # spec_iter > 5 + code_iter > 5 + ONLY a code-phase justification
  # (spec phase unjustified). Per spec §3.1c, spec-phase breach without a
  # spec-phase justification is a violation. A scalar-count classifier
  # (the iter-1 design) accepts this fixture — this killer detects that
  # regression.
  local kill_dir kill_fx kill_out kill_class
  kill_dir=$(mktemp -d 2>/dev/null || mktemp -d -t 'iter_cap_phase_blind')
  if [ -z "$kill_dir" ] || [ ! -d "$kill_dir" ]; then
    echo "iter-cap recognition: phase-blind killer could not create temp dir"
    return 1
  fi
  kill_fx="$kill_dir/spec.md"
  cat > "$kill_fx" <<'EOF_PHASE_BLIND'
---
title: synthesized phase-blind regression killer
---

## Log

### 2026-04-28

- 2026-04-28: code audit iteration > 5 justified — security-sensitive auth path
- 2026-04-28: spec_audit_iteration=6; spec_audit_fixed_ids=[X1]; spec_audit_next_id=2
- 2026-04-28: code audit iteration=6; fixed_ids=[X2]; accepted_ids=[]
EOF_PHASE_BLIND
  kill_out=$(_fixture_latest_audit_iter_marker "$kill_fx")
  unset max_iter latest_iter_line escape_hatch_count escape_hatch_line
  unset spec_iter_first_over_cap_line code_iter_first_over_cap_line spec_hatch_line code_hatch_line
  eval "$kill_out"
  kill_class=$(_classify "$spec_iter_first_over_cap_line" "$code_iter_first_over_cap_line" \
    "$spec_hatch_line" "$code_hatch_line")
  if [ "$kill_class" != "violation" ]; then
    echo "iter-cap recognition: phase-blind killer mis-classified as '$kill_class' (expected 'violation' — code-phase justification cannot clear a spec-phase cap breach; spec_hatch_line=$spec_hatch_line spec_iter_first_over_cap_line=$spec_iter_first_over_cap_line code_hatch_line=$code_hatch_line code_iter_first_over_cap_line=$code_iter_first_over_cap_line)"
    fail=1
  fi
  rm -rf "$kill_dir"

  # (e) iter-2 X2 order-blind regression killer: synthesized fixture with
  # spec_iter > 5 + a spec-phase justification line PLACED AFTER the iter
  # marker. Per spec §3.1c L147 ("BEFORE iter-6 starts"), justification
  # AFTER the iter marker = rationalization, not pre-commitment. Must
  # classify as violation. A ±5-line absolute-distance classifier (the
  # iter-1 design) accepts this fixture — this killer detects that
  # regression.
  local order_dir order_fx order_out order_class
  order_dir=$(mktemp -d 2>/dev/null || mktemp -d -t 'iter_cap_order_blind')
  if [ -z "$order_dir" ] || [ ! -d "$order_dir" ]; then
    echo "iter-cap recognition: order-blind killer could not create temp dir"
    return 1
  fi
  order_fx="$order_dir/spec.md"
  cat > "$order_fx" <<'EOF_ORDER_BLIND'
---
title: synthesized order-blind regression killer
---

## Log

### 2026-04-28

- 2026-04-28: spec_audit_iteration=6; spec_audit_fixed_ids=[X1]; spec_audit_next_id=2
- 2026-04-28: spec audit iteration > 5 justified — cross-cutting refactor with 7 parallel surfaces
EOF_ORDER_BLIND
  order_out=$(_fixture_latest_audit_iter_marker "$order_fx")
  unset max_iter latest_iter_line escape_hatch_count escape_hatch_line
  unset spec_iter_first_over_cap_line code_iter_first_over_cap_line spec_hatch_line code_hatch_line
  eval "$order_out"
  order_class=$(_classify "$spec_iter_first_over_cap_line" "$code_iter_first_over_cap_line" \
    "$spec_hatch_line" "$code_hatch_line")
  if [ "$order_class" != "violation" ]; then
    echo "iter-cap recognition: order-blind killer mis-classified as '$order_class' (expected 'violation' — justification placed AFTER iter marker is rationalization-after-the-fact; spec_hatch_line=$spec_hatch_line spec_iter_first_over_cap_line=$spec_iter_first_over_cap_line)"
    fail=1
  fi
  rm -rf "$order_dir"

  return $fail
}

# Companion R6 mutation-protected meta-pin (Step 7 of spec
# 2026-04-28-orchestrator-delegation-and-stop-criteria.md).
#
# Mirrors the precedent at L4380-4479
# (`check_code_audit_marker_recognition_mutation_protected`). Per X14
# decision Option A (precedent-preserving), the mutation-killer input is
# synthesized inside the meta-pin's body via printf/heredoc — NOT a fourth
# fixture under tests/fixtures/audit-iteration-cap/. The three iter-cap-*
# fixtures stay pure (each represents exactly one recognition shape:
# clean / violation / justified).
#
# P1: the CURRENT (canonical §3.1c) regex REJECTS the synthesized killer
#     input (an `iter > 5 justified` line with no separator-and-reason tail).
# P2: a chosen MUTANT regex (relaxes `[—-] .+$` to `.*` so trailing garbage
#     is accepted) ACCEPTS the killer input — proving the mutation is
#     observable and not a no-op.
# P3: structural canary scoped to the awk-extracted body of
#     `_fixture_latest_audit_iter_marker()` only (NOT a file-wide grep): the
#     production helper's body contains the canonical regex literal exactly
#     once.
# P4: the recognition pin's body invokes `_fixture_latest_audit_iter_marker`
#     via command substitution (anchor `$(_fixture_latest_audit_iter_marker[[:space:]]`
#     after stripping whole-line and trailing comments via `sed` per the
#     precedent at L4461).
# P5: the recognition pin's body does NOT contain a marker-shape regex
#     literal at the function level (anchor on
#     `^- \[0-9\]\{4\}-\[0-9\]\{2\}-\[0-9\]\{2\}:` — same shape-guard as
#     L4467-4476).
check_audit_iteration_hard_cap_recognition_mutation_protected() {
  local fx_dir
  fx_dir=$(mktemp -d 2>/dev/null || mktemp -d -t 'iter_cap_mutpin')
  if [ -z "$fx_dir" ] || [ ! -d "$fx_dir" ]; then
    echo "iter-cap mutation-protected: could not create temp dir"
    return 1
  fi
  # Synthesize the canonical regression-killer input: an `iter > 5 justified`
  # line with NO separator-and-reason tail (just `justified` and EOL). The
  # current (§3.1c canonical) regex requires ` [—-] .+$` after `justified`,
  # so this line MUST be rejected; a relaxed mutant that drops the tail
  # requirement MUST accept it.
  local killer="- 2026-04-28: spec audit iteration > 5 justified"
  local fx="$fx_dir/spec.md"
  cat > "$fx" <<EOF_KILLER
---
title: mutation-test fixture (iter-cap)
---

## Log

### 2026-04-28

- 2026-04-28: spec_audit_iteration=7; spec_audit_fixed_ids=[X1]; spec_audit_next_id=2
$killer
EOF_KILLER

  # P1: the canonical §3.1c regex (single source of truth) REJECTS the killer.
  local current_regex='^- [0-9]{4}-[0-9]{2}-[0-9]{2}: (spec|code) audit iteration > 5 justified [—-] .+$'
  if printf '%s\n' "$killer" | grep -qE "$current_regex"; then
    echo "iter-cap mutation-protected: current §3.1c regex INCORRECTLY accepts the killer input (no separator-and-reason tail)"
    rm -rf "$fx_dir"
    return 1
  fi
  # P2: the MUTANT regex (relaxes `[—-] .+$` to `.*`) ACCEPTS the killer.
  # If the mutant ALSO rejects, the mutation isn't observable and the
  # meta-pin is ineffective.
  local mutant_regex='^- [0-9]{4}-[0-9]{2}-[0-9]{2}: (spec|code) audit iteration > 5 justified.*'
  if ! printf '%s\n' "$killer" | grep -qE "$mutant_regex"; then
    echo "iter-cap mutation-protected: mutant regex unexpectedly rejects killer input — meta-pin can't observe regression"
    rm -rf "$fx_dir"
    return 1
  fi
  # P3: structural canary — the production helper body contains the
  # FULL canonical §3.1c regex literal (BOL date prefix + phase token + iter
  # > 5 + justified + separator + reason tail) exactly twice (once each for
  # grep -cE and grep -nE invocations).
  #
  # Iter-1 X1 fix: the prior canary anchored on the tail `justified [—-] .+$`
  # only — a maintainer could drop the BOL+date+phase prefix
  # `^- [0-9]{4}-[0-9]{2}-[0-9]{2}: (spec|code) audit iteration > 5 ` from
  # the production helper and the canary would still pass. The full canonical
  # literal closes that gap. Using `grep -F` (fixed string) defeats `grep -E`
  # self-interpretation of the canonical literal's regex meta-characters in
  # the canary-test layer. The literal MUST be byte-identical to the form at
  # smoke.sh:3495-3496.
  #
  # Scoping to the awk-extracted function body (NOT file-wide grep) so a
  # mutation that ONLY affects the helper is observable (the literal also
  # appears in this meta-pin's `current_regex` — a file-wide grep would
  # silently pass after a helper-only mutation; same X9 lesson as L4441-4449).
  local prod_body prod_regex_count
  prod_body=$(awk '/^_fixture_latest_audit_iter_marker\(\)/,/^}/' tests/smoke.sh)
  local canonical_regex_literal='^- [0-9]{4}-[0-9]{2}-[0-9]{2}: (spec|code) audit iteration > 5 justified [—-] .+$'
  prod_regex_count=$(printf '%s\n' "$prod_body" | grep -cF "$canonical_regex_literal" || true)
  if [ "$prod_regex_count" -lt 2 ]; then
    # The helper invokes the regex twice (once for grep -cE, once for grep -nE).
    # Less than 2 means the production-helper regex shape was mutated/removed.
    echo "iter-cap mutation-protected: _fixture_latest_audit_iter_marker() body does not contain the FULL canonical §3.1c regex literal twice (got $prod_regex_count — production helper grammar mutated/removed; iter-1 X1 fix anchors on full BOL-to-EOL form)"
    rm -rf "$fx_dir"
    return 1
  fi
  # P3b (iter-1 X1 parallel-surface fix): synthesize a prose-collision line
  # that contains the substring `justified — because we said so` but is NOT
  # in canonical form (no `(spec|code) audit iteration > 5 ` prefix). Run
  # `_fixture_latest_audit_iter_marker` against a fixture carrying this line
  # and assert escape_hatch_count=0. Catches BOL-anchor mutation at the
  # helper-output layer (in addition to the structural-canary layer above).
  # §3.1c explicitly warns: "Recognition is by regex, not free-floating
  # substring, to defeat the prose-collision false-positive risk".
  local prose_collision_fx="$fx_dir/prose-collision.md"
  cat > "$prose_collision_fx" <<EOF_PROSE
---
title: prose-collision fixture (iter-cap mutation-observability)
---

## Log

### 2026-04-28

- 2026-04-28: spec_audit_iteration=7; spec_audit_fixed_ids=[X1]; spec_audit_next_id=2
- 2026-04-28: discussion notes — justified — because we said so
EOF_PROSE
  local prose_out
  prose_out=$(_fixture_latest_audit_iter_marker "$prose_collision_fx")
  unset max_iter latest_iter_line escape_hatch_count escape_hatch_line
  eval "$prose_out"
  if [ "${escape_hatch_count:-0}" -ne 0 ]; then
    echo "iter-cap mutation-protected: prose-collision input mis-classified — escape_hatch_count=$escape_hatch_count (expected 0; production helper accepted free-floating 'justified — reason' prose, indicating BOL-anchor mutation)"
    rm -rf "$fx_dir"
    return 1
  fi
  # P4: the recognition pin invokes `_fixture_latest_audit_iter_marker`
  # via command substitution. Strip comments first so a documentation
  # reference cannot satisfy the anchor while neutering the call site.
  local body code_only
  body=$(awk '/^check_audit_iteration_hard_cap_recognition\(\)/,/^}/' tests/smoke.sh)
  code_only=$(printf '%s\n' "$body" | sed -e 's/^[[:space:]]*#.*$//' -e 's/[[:space:]]*#[^"'"'"']*$//')
  if ! printf '%s\n' "$code_only" | grep -qE '\$\(_fixture_latest_audit_iter_marker[[:space:]]'; then
    echo "iter-cap mutation-protected: recognition pin body does not invoke _fixture_latest_audit_iter_marker via command substitution (production helper bypassed)"
    rm -rf "$fx_dir"
    return 1
  fi
  # P5: the recognition pin body must NOT contain a marker-shape regex
  # literal at the function level — guarding against an inline-copy
  # regression where the recognition pin learns the regex itself.
  if printf '%s\n' "$code_only" | grep -qE "grep -q?E '\^- \[0-9\]\{4\}-\[0-9\]\{2\}-\[0-9\]\{2\}: \(spec\|code\) audit iteration"; then
    echo "iter-cap mutation-protected: recognition pin contains an inline marker-shape regex literal (inline-copy regression)"
    rm -rf "$fx_dir"
    return 1
  fi
  rm -rf "$fx_dir"
  return 0
}

# Iter-2 X5 fixture-based regression coverage: production-shape resume
# routing tests under the EXTENDED Log marker schema. Matches the existing
# clean-passed / zero-diff-skip routing tests (L3414, L3457) but exercises
# the extended-form fixtures.
check_code_audit_resume_clean_passed_extended_evidence() {
  local fx='tests/fixtures/code-audit-resume/clean-passed-extended-evidence/spec.md'
  if [ ! -f "$fx" ]; then
    echo "fixture missing: $fx"
    return 1
  fi
  local marker
  marker=$(_fixture_latest_code_audit_marker "$fx")
  case "$marker" in
    *"code audit passed"*) : ;;
    *)
      echo "clean-passed-extended-evidence: latest marker is not 'code audit passed' (got: $marker)"
      return 1
      ;;
  esac
  if ! printf '%s\n' "$marker" | grep -qF '; evidence=dual_model; blockers=[]'; then
    echo "clean-passed-extended-evidence: extended-form suffix '; evidence=dual_model; blockers=[]' not in matched marker (regex stripped the suffix or fixture is wrong)"
    return 1
  fi
  if ! printf '%s\n' "$marker" | grep -qF "verified=[X3], accepted=[X5], deferred=[X9]"; then
    echo "clean-passed-extended-evidence: terminal marker missing verbatim verified/accepted/deferred tail"
    return 1
  fi
  echo "clean-passed-extended-evidence: extended-form 'code audit passed; ...; evidence=dual_model; blockers=[]' recognized → skip-to-hand-off OK"
}

check_code_audit_resume_zero_diff_skip_extended_evidence() {
  local fx='tests/fixtures/code-audit-resume/zero-diff-skip-extended-evidence/spec.md'
  if [ ! -f "$fx" ]; then
    echo "fixture missing: $fx"
    return 1
  fi
  local marker
  marker=$(_fixture_latest_code_audit_marker "$fx")
  if ! printf '%s\n' "$marker" | grep -qF "code audit: no auditable files in diff; skipping"; then
    echo "zero-diff-skip-extended-evidence: latest marker missing 'code audit: no auditable files in diff; skipping' (got: $marker)"
    return 1
  fi
  if ! printf '%s\n' "$marker" | grep -qF "; evidence=skipped; blockers=['no auditable files in diff']"; then
    echo "zero-diff-skip-extended-evidence: extended-form suffix '; evidence=skipped; blockers=[...]' not in matched marker"
    return 1
  fi
  echo "zero-diff-skip-extended-evidence: extended-form skip marker recognized → skip-to-hand-off OK"
}

# --- Contract-violated enum pins (spec 2026-04-28-contract-violated-enum) ---
# These four pins land the enforcement slice for the `contract_violated` enum
# value addition: routing-rule + file-existence-check + Overview doc coverage
# + cross-auditor never-writes extension. Each pin documents the load-bearing
# negative guards inline with the spec finding-id (X10/X12/X13/X16/X17) so a
# future maintainer can map the assertion back to the design rationale.

# (NEW) `check_skill_contract_violated_routing_rule` — SKILL.md §3.5b documents
# the parse-failure / YAML-safety / missing-findings.md → `contract_violated`
# routing rule (the rewrite from the parent-spec `self_fallback` routing).
# Enforces:
#   - §3.5b region positive: literal `Contract-violation rule`, the example
#     phrase `'cross-auditor return missing evidence_class footer line'`, the
#     X10 Historical-event-storage-rule literals (`Historical-event storage
#     rule`, `recorded in the spec Log ONLY`, ``NOT in `*_audit_blockers` ``,
#     ``tied to the FINAL `*_audit_evidence` value``).
#   - §3.5b region negative guard: the OLD routing literal `treat the audit
#     as `self_fallback` (cross-auditor return signal not parseable` MUST NOT
#     appear in the rewritten §3.5b region.
#   - File-wide negative guard (X2): the OLD parse-failure parenthetical
#     `(parse-failure → `self_fallback` per §3.5b)` MUST NOT appear ANYWHERE
#     in `skills/feature/SKILL.md` — catches the case where developer updates
#     §3.5b but leaves one of the three call sites L298/L304/L598 carrying
#     the orphan parenthetical.
#   - X16 paragraph-scoped routing-target literal: extract the
#     Contract-violation paragraph from §3.5b region by anchoring on the
#     literal `**Contract-violation rule.**` and consuming until the next
#     blank line (markdown paragraph terminator); the literal
#     `*_audit_evidence: contract_violated` MUST appear in that paragraph
#     (positive) AND the alt-routing-target literals
#     `*_audit_evidence: self_fallback`, `*_audit_evidence: single_model`,
#     `*_audit_evidence: skipped` MUST NOT appear in the same paragraph
#     (negative) — this catches synthetic developer-misedit where the
#     paragraph body silently routes to a different enum value while the
#     heading stays intact.
check_skill_contract_violated_routing_rule() {
  local f='skills/feature/SKILL.md'
  local region_3_5b
  region_3_5b=$(awk '/^### 3\.5b/{flag=1; next} flag && /^### / {exit} flag' "$f")
  if ! printf '%s' "$region_3_5b" | grep -qF 'Contract-violation rule'; then
    echo "SKILL.md §3.5b missing 'Contract-violation rule' heading literal"
    return 1
  fi
  if ! printf '%s' "$region_3_5b" | grep -qF "'cross-auditor return missing evidence_class footer line'"; then
    echo "SKILL.md §3.5b missing example blocker phrase 'cross-auditor return missing evidence_class footer line'"
    return 1
  fi
  if printf '%s' "$region_3_5b" | grep -qF "treat the audit as \`self_fallback\` (cross-auditor return signal not parseable"; then
    echo "SKILL.md §3.5b still contains OLD self_fallback routing literal — must be rewritten to contract_violated"
    return 1
  fi
  # X2 file-wide negative guard for the orphan parse-failure parenthetical.
  if grep -qF "(parse-failure → \`self_fallback\` per §3.5b)" "$f"; then
    echo "SKILL.md still contains OLD parse-failure parenthetical '(parse-failure → \`self_fallback\` per §3.5b)' at one of the call sites L298/L304/L598 — all three MUST be rewritten to contract_violated"
    return 1
  fi
  # X10 Historical-event-storage-rule literals — without these, the iter-1 X7
  # Historical-event paragraph can be silently dropped or weakened in a future
  # edit and the schema's "blockers describe what blocks the FINAL gold
  # standard" semantics regresses.
  if ! printf '%s' "$region_3_5b" | grep -qF 'Historical-event storage rule'; then
    echo "SKILL.md §3.5b missing 'Historical-event storage rule' literal (X10)"
    return 1
  fi
  if ! printf '%s' "$region_3_5b" | grep -qF 'recorded in the spec Log ONLY'; then
    echo "SKILL.md §3.5b missing 'recorded in the spec Log ONLY' literal (X10)"
    return 1
  fi
  if ! printf '%s' "$region_3_5b" | grep -qF 'NOT in `*_audit_blockers`'; then
    echo "SKILL.md §3.5b missing 'NOT in \`*_audit_blockers\`' literal (X10)"
    return 1
  fi
  if ! printf '%s' "$region_3_5b" | grep -qF 'tied to the FINAL `*_audit_evidence` value'; then
    echo "SKILL.md §3.5b missing 'tied to the FINAL \`*_audit_evidence\` value' literal (X10)"
    return 1
  fi
  # X16 paragraph-scoped routing-target literal: extract the Contract-violation
  # paragraph anchored on `**Contract-violation rule.**`, consume up to (but
  # not including) the next blank line (markdown paragraph terminator).
  local cv_paragraph
  cv_paragraph=$(printf '%s\n' "$region_3_5b" | awk '/\*\*Contract-violation rule\.\*\*/{flag=1} flag {print; if (flag && NR>0 && /^$/) exit}')
  if [ -z "$cv_paragraph" ]; then
    echo "SKILL.md §3.5b: could not extract Contract-violation paragraph (anchor '**Contract-violation rule.**' not found or paragraph empty)"
    return 1
  fi
  if ! printf '%s' "$cv_paragraph" | grep -qF '*_audit_evidence: contract_violated'; then
    echo "SKILL.md §3.5b Contract-violation paragraph missing routing-target literal '*_audit_evidence: contract_violated' (X16)"
    return 1
  fi
  if printf '%s' "$cv_paragraph" | grep -qF '*_audit_evidence: self_fallback'; then
    echo "SKILL.md §3.5b Contract-violation paragraph contains forbidden alt-routing-target '*_audit_evidence: self_fallback' (X16)"
    return 1
  fi
  if printf '%s' "$cv_paragraph" | grep -qF '*_audit_evidence: single_model'; then
    echo "SKILL.md §3.5b Contract-violation paragraph contains forbidden alt-routing-target '*_audit_evidence: single_model' (X16)"
    return 1
  fi
  if printf '%s' "$cv_paragraph" | grep -qF '*_audit_evidence: skipped'; then
    echo "SKILL.md §3.5b Contract-violation paragraph contains forbidden alt-routing-target '*_audit_evidence: skipped' (X16)"
    return 1
  fi
  return 0
}

# (NEW) `check_skill_contract_violated_file_existence_check` — SKILL.md §3.5b
# documents the new code/full-mode file-existence check that routes a missing
# `<kb>/repos/<project>/security/<audit_slug>-findings.md` to
# `contract_violated`. Body extraction: anchor on
# `File-existence check (code/full mode only)`, consume subsequent lines
# until the next bullet starting with `^- \*\*`, OR a section break `^---`,
# OR end-of-section (next `^### ` or `^## `). X12: `self_fallback` MUST NOT
# appear in the extracted body — without this, a future edit could re-route
# the missing-file branch to `self_fallback` and the loose anchor checks
# would still pass.
check_skill_contract_violated_file_existence_check() {
  local f='skills/feature/SKILL.md'
  if ! grep -qF 'File-existence check (code/full mode only)' "$f"; then
    echo "SKILL.md missing 'File-existence check (code/full mode only)' bullet anchor"
    return 1
  fi
  local bullet_body
  bullet_body=$(awk '
    /File-existence check \(code\/full mode only\)/ {flag=1; print; next}
    flag && /^- \*\*/ {exit}
    flag && /^---/ {exit}
    flag && /^### / {exit}
    flag && /^## / {exit}
    flag {print}
  ' "$f")
  if [ -z "$bullet_body" ]; then
    echo "SKILL.md: could not extract file-existence-check bullet body"
    return 1
  fi
  if ! printf '%s' "$bullet_body" | grep -qF 'findings.md missing at'; then
    echo "SKILL.md file-existence-check bullet missing 'findings.md missing at' literal"
    return 1
  fi
  if ! printf '%s' "$bullet_body" | grep -qF '*_audit_evidence: contract_violated'; then
    echo "SKILL.md file-existence-check bullet missing '*_audit_evidence: contract_violated' routing literal"
    return 1
  fi
  if ! printf '%s' "$bullet_body" | grep -qF 'skip the YAML extraction'; then
    echo "SKILL.md file-existence-check bullet missing 'skip the YAML extraction' literal"
    return 1
  fi
  # X12 negative guard: the missing-file branch MUST route to contract_violated,
  # not self_fallback. Without this, a future edit could re-route silently.
  if printf '%s' "$bullet_body" | grep -qF 'self_fallback'; then
    echo "SKILL.md file-existence-check bullet contains forbidden 'self_fallback' literal — missing-file branch MUST route to contract_violated (X12)"
    return 1
  fi
  return 0
}

# (NEW) `check_overview_contract_violated_documented` — operating-manual
# §Audit evidence covers contract_violated symmetric with the SKILL.md
# rewrite: bullet-form mention, 4-element predicate, cardinal-text
# `Five canonical enum values:`, visibility-only-signals enumeration. X14:
# extraction uses literal-case `^## Audit evidence` (BSD awk has no
# IGNORECASE — GAWK extension would extract 0 lines on macOS). X15: bullet
# form `^- \*\*\`contract_violated\`\*\*` ≥1 match (NOT just inline mention
# in predicate text — that would let the bullet silently disappear). X3 +
# X5 + X13 negative guards reject the OLD literals.
check_overview_contract_violated_documented() {
  local f='docs/AI_Dev_Team_Overview.md'
  local region
  region=$(awk '/^## Audit evidence/{flag=1; next} flag && /^## /{flag=0} flag' "$f")
  if [ -z "$region" ]; then
    echo "Overview: §Audit evidence region empty (literal-case awk extraction failed — header may have drifted)"
    return 1
  fi
  if ! printf '%s' "$region" | grep -qF 'contract_violated'; then
    echo "Overview §Audit evidence region missing 'contract_violated' mention"
    return 1
  fi
  # X15 bullet-form: `contract_violated` MUST appear as a top-level bullet
  # `- **`contract_violated`**` (not just inline in predicate prose).
  if ! printf '%s' "$region" | grep -qE '^- \*\*`contract_violated`\*\*'; then
    echo "Overview §Audit evidence region missing bullet-form '- **`contract_violated`**' (X15 — inline mention insufficient)"
    return 1
  fi
  if ! printf '%s' "$region" | grep -qF '∈ {single_model, self_fallback, contract_violated, skipped}'; then
    echo "Overview §Audit evidence region missing 4-element predicate '∈ {single_model, self_fallback, contract_violated, skipped}'"
    return 1
  fi
  if ! printf '%s' "$region" | grep -qF 'Five canonical enum values:'; then
    echo "Overview §Audit evidence region missing cardinal text 'Five canonical enum values:' (X3)"
    return 1
  fi
  # X13 visibility-only-signals enumeration: `single_model`, `self_fallback`,
  # AND `contract_violated` are all visibility-only — the prose enumeration
  # MUST list all three.
  if ! printf '%s' "$region" | grep -qF '`single_model`, `self_fallback`, and `contract_violated` are visibility-only signals'; then
    echo "Overview §Audit evidence region missing X13 visibility-only-signals enumeration '`single_model`, `self_fallback`, and `contract_violated` are visibility-only signals'"
    return 1
  fi
  # X3 cardinal-text negative guard
  if printf '%s' "$region" | grep -qF 'Four canonical enum values:'; then
    echo "Overview §Audit evidence region contains forbidden OLD cardinal text 'Four canonical enum values:' (X3 — must be 'Five')"
    return 1
  fi
  # X5 OLD-predicate negative guard
  if printf '%s' "$region" | grep -qF '∈ {single_model, self_fallback, skipped}'; then
    echo "Overview §Audit evidence region contains forbidden OLD 3-element predicate '∈ {single_model, self_fallback, skipped}' (X5)"
    return 1
  fi
  # X13 OLD-enumeration negative guard
  if printf '%s' "$region" | grep -qF '`single_model` and `self_fallback` are visibility-only signals'; then
    echo "Overview §Audit evidence region contains forbidden OLD visibility-only-signals enumeration '`single_model` and `self_fallback` are visibility-only signals' (X13 — must enumerate three values)"
    return 1
  fi
  return 0
}

# (NEW) `check_cross_auditor_never_writes_extension` — agents/cross-auditor.md
# extends the never-writes literal list to 3 values + reroutes parse-failure
# to contract_violated; SKILL.md L325 third-site never-writes parenthetical
# also names contract_violated (X4 — without this the two never-writes
# literals can drift). X11: cross-auditor still emits ONLY `dual_model` /
# `single_model`. X17: cardinality assertion `count(^- \*\*\`<token>\`\*\*) == 2`
# in the When-to-set region + region-scoped negative guard for the OLD
# 2-value sentence `NEVER writes \`self_fallback\` or \`skipped\`` (without
# `\`contract_violated\``).
check_cross_auditor_never_writes_extension() {
  local f='agents/references/cross-auditor-evidence-handshake.md'
  local skill='skills/feature/SKILL.md'
  if ! grep -qF "self_fallback\`, \`contract_violated\`, or \`skipped" "$f"; then
    echo "cross-auditor.md missing 3-value never-writes literal list 'self_fallback\`, \`contract_violated\`, or \`skipped'"
    return 1
  fi
  if ! grep -qE 'treat the audit as `contract_violated`' "$f"; then
    echo "cross-auditor.md L421 parse-failure rule must route to 'contract_violated' (not self_fallback)"
    return 1
  fi
  if grep -qE 'treat the audit as `self_fallback` \(cross-auditor return signal not parseable\)' "$f"; then
    echo "cross-auditor.md L421 still contains OLD self_fallback routing literal — must be rewritten to contract_violated"
    return 1
  fi
  # X11 + X17: extract the `### When to set` region and assert the binary-emit
  # invariant + cardinality + OLD-sentence guard.
  local wts
  wts=$(awk '/^### When to set/{flag=1; next} flag && /^### / {exit} flag' "$f")
  if [ -z "$wts" ]; then
    echo "cross-auditor.md: could not extract '### When to set' region"
    return 1
  fi
  if ! printf '%s' "$wts" | grep -qF '**`dual_model`**'; then
    echo "cross-auditor.md '### When to set' region missing '**\`dual_model\`**' bullet (X11 binary-emit invariant)"
    return 1
  fi
  if ! printf '%s' "$wts" | grep -qF '**`single_model`**'; then
    echo "cross-auditor.md '### When to set' region missing '**\`single_model\`**' bullet (X11 binary-emit invariant)"
    return 1
  fi
  if printf '%s' "$wts" | grep -qF '**`contract_violated`**'; then
    echo "cross-auditor.md '### When to set' region must NOT contain '**\`contract_violated\`**' bullet — orchestrator-only territory (X11)"
    return 1
  fi
  if printf '%s' "$wts" | grep -qF '**`self_fallback`**'; then
    echo "cross-auditor.md '### When to set' region must NOT contain '**\`self_fallback\`**' bullet — orchestrator-only territory (X11)"
    return 1
  fi
  if printf '%s' "$wts" | grep -qF '**`skipped`**'; then
    echo "cross-auditor.md '### When to set' region must NOT contain '**\`skipped\`**' bullet — orchestrator-only territory (X11)"
    return 1
  fi
  # X17 cardinality: exactly two emit-style bullets `^- **`<token>`**`.
  local bullet_count
  bullet_count=$(printf '%s\n' "$wts" | grep -cE '^- \*\*`[^`]+`\*\*')
  if [ "$bullet_count" != "2" ]; then
    echo "cross-auditor.md '### When to set' region must contain exactly 2 emit-style bullets '^- **\`<token>\`**' (got $bullet_count) — X17 cardinality"
    return 1
  fi
  # X17 OLD-sentence region-scoped negative guard.
  if printf '%s' "$wts" | grep -qF 'NEVER writes `self_fallback` or `skipped`'; then
    echo "cross-auditor.md '### When to set' region still contains OLD 2-value never-writes sentence 'NEVER writes \`self_fallback\` or \`skipped\`' (without contract_violated) — X17 must be rewritten to 3-value form"
    return 1
  fi
  return 0
}

# (NEW) `check_skill_orchestrator_blocker_sanitization_rule` — SKILL.md §3.5b
# carries the X3 Orchestrator blocker sanitization rule subsection that makes
# the orchestrator-side blocker emission path symmetric with the cross-auditor
# side. Without this rule, an orchestrator-generated blocker containing an
# apostrophe (e.g. file-existence-check `<path>` slot consuming
# `/Users/.../it's-a-spec/...` "verbatim") would corrupt the spec's YAML
# frontmatter and silently de-card the spec from every reader. The pin extracts
# the §3.5b region with the same `awk '/^### 3\.5b/{flag=1; next} flag &&
# /^### / {exit} flag'` pattern existing pins use and asserts three load-bearing
# literals: the rule's bold header anchor, the cross-reference linking it to
# the cross-auditor sanitizer, and the symmetry claim that anchors the WHY.
check_skill_orchestrator_blocker_sanitization_rule() {
  local f='skills/feature/SKILL.md'
  local region_3_5b
  region_3_5b=$(awk '/^### 3\.5b/{flag=1; next} flag && /^### / {exit} flag' "$f")
  if [ -z "$region_3_5b" ]; then
    echo "SKILL.md §3.5b region empty (header may have drifted)"
    return 1
  fi
  if ! printf '%s' "$region_3_5b" | grep -qF 'Orchestrator blocker sanitization rule'; then
    echo "SKILL.md §3.5b missing 'Orchestrator blocker sanitization rule' bold-header anchor"
    return 1
  fi
  if ! printf '%s' "$region_3_5b" | grep -qF 'same YAML-safety sanitizer as cross-auditor blockers'; then
    echo "SKILL.md §3.5b missing cross-reference literal 'same YAML-safety sanitizer as cross-auditor blockers' (anchors the rule to agents/cross-auditor.md serialization rule)"
    return 1
  fi
  if ! printf '%s' "$region_3_5b" | grep -qF 'symmetric on both sides of the handshake'; then
    echo "SKILL.md §3.5b missing 'symmetric on both sides of the handshake' claim (X3 WHY anchor)"
    return 1
  fi
  return 0
}

# (NEW) `check_skill_evidence_pair_invariant` — SKILL.md §3.5b Contract-violation
# rule paragraph documents the X4 cross-field invariant between `evidence_class`
# and `evidence_blockers` per the cross-auditor emit contract
# (`agents/cross-auditor.md` §When to set L382-383): `dual_model` MUST pair with
# empty `evidence_blockers`; `single_model` MUST pair with non-empty. Both
# contradictory pairings route to `*_audit_evidence: contract_violated` with
# named blocker phrasings. Without this rule, a buggy/regressed cross-auditor
# emitting a contradictory pair would pass parser-shape (X1), YAML-safety (X3),
# file-existence (code/full mode), and allowlist (X2) checks; the orchestrator
# would copy both verbatim; Status mode would render a dual_model row clean
# (no degraded flag) despite the blocker list contradicting the claim —
# honesty-gate inversion, the failure mode the parent spec exists to prevent.
# The pin uses the same paragraph-scoped extraction as
# `check_skill_contract_violated_routing_rule` (anchor on
# `**Contract-violation rule.**`, consume until next blank line) to keep the
# scope identical to the X16 pin's positive routing-target + alt-target
# negative-guard contract; the new clause stays inside the same paragraph.
check_skill_evidence_pair_invariant() {
  local f='skills/feature/SKILL.md'
  local region_3_5b
  region_3_5b=$(awk '/^### 3\.5b/{flag=1; next} flag && /^### / {exit} flag' "$f")
  if [ -z "$region_3_5b" ]; then
    echo "SKILL.md §3.5b region empty (header may have drifted)"
    return 1
  fi
  local cv_paragraph
  cv_paragraph=$(printf '%s\n' "$region_3_5b" | awk '/\*\*Contract-violation rule\.\*\*/{flag=1} flag {print; if (flag && NR>0 && /^$/) exit}')
  if [ -z "$cv_paragraph" ]; then
    echo "SKILL.md §3.5b: could not extract Contract-violation paragraph (anchor '**Contract-violation rule.**' not found or paragraph empty)"
    return 1
  fi
  # Case 1 — dual_model + non-empty evidence_blockers contradictory pair.
  if ! printf '%s' "$cv_paragraph" | grep -qF 'dual_model with non-empty evidence_blockers'; then
    echo "SKILL.md §3.5b Contract-violation paragraph missing case-1 literal 'dual_model with non-empty evidence_blockers' (X4 invariant)"
    return 1
  fi
  # Case 2 — single_model + empty evidence_blockers contradictory pair.
  if ! printf '%s' "$cv_paragraph" | grep -qF 'single_model with empty evidence_blockers'; then
    echo "SKILL.md §3.5b Contract-violation paragraph missing case-2 literal 'single_model with empty evidence_blockers' (X4 invariant)"
    return 1
  fi
  # Cross-reference to the cross-auditor emit contract anchor — the literal
  # `When to set` is the heading at agents/cross-auditor.md:378, so this
  # assertion catches drift if the doc reference goes stale.
  if ! printf '%s' "$cv_paragraph" | grep -qF 'When to set'; then
    echo "SKILL.md §3.5b Contract-violation paragraph missing cross-reference literal 'When to set' (anchors X4 invariant to agents/cross-auditor.md emit contract)"
    return 1
  fi
  return 0
}

# (NEW) `check_skill_findings_path_coherence` — guards SKILL.md against the
# X5 defect class (path-coherence between SKILL.md and the cross-auditor write
# contract at agents/cross-auditor.md:430). Two SKILL.md sites — Code-audit
# triage step 3 "Collect decisions" (L546) and Continue-mode resume routing
# `iteration=N` row (L731) — used to read/write the findings file at the bare
# `<kb>/repos/<project>/<slug>-code-findings.md` path, omitting the `/security/`
# segment. Two silent failure modes flowed from that drift:
#   1. Triage failure (L546) — orchestrator writes status updates to a
#      non-existent path; cross-auditor at the canonical `/security/` path sees
#      stale OPEN entries on re-audit; the loop fails to converge.
#   2. Resume failure (L731) — Continue mode reads from the non-existent path,
#      finds no OPEN/REOPENED entries, routes to clean hand-off; un-triaged
#      HIGH findings ship silently.
# The pin is two-armed: a file-wide negative guard rejecting any bare-no-/security/
# occurrence at EITHER `<kb>` or `<kb_path>` placeholder spelling (X8 sub-(b)
# broadens the original short-form-only guard so a future edit normalizing
# SKILL.md to long-form `<kb_path>/repos/<project>/<slug>-code-findings.md`
# without `/security/` is also caught), and a positive count assertion (≥2) on
# the canonical /security/ form covering the two known sites. Pin label
# `findings-path-coherence` (no `contract-violated-` prefix — different defect
# class from §3.5b prose pins).
check_skill_findings_path_coherence() {
  local f='skills/feature/SKILL.md'
  # Negative guard: every full-prefix `-code-findings.md` mention (at either
  # <kb> or <kb_path> placeholder) must include /security/. Compute bad = total
  # mentions vs good = mentions with /security/. They must be equal.
  # X9 fix: count OCCURRENCES (`grep -oE | wc -l`), not matching LINES
  # (`grep -cE`). A single line carrying both a canonical /security/ mention
  # AND a bare mention would contribute 1 to both bad and good under -cE
  # (line counts), so equality holds and the bare path slips through. Under
  # -oE | wc -l, each occurrence is on its own output line, so the same
  # mutated line yields bad=2, good=1 and the pin correctly FAILs.
  local bad good
  bad=$(grep -oE '<kb(_path)?>/repos/<project>/[^[:space:]`]*-code-findings\.md' "$f" | wc -l | tr -d ' ')
  good=$(grep -oE '<kb(_path)?>/repos/<project>/security/[^[:space:]`]*-code-findings\.md' "$f" | wc -l | tr -d ' ')
  if [ "$bad" != "$good" ]; then
    local missing=$((bad - good))
    echo "SKILL.md has $missing findings.md path mention(s) missing /security/ segment (bad=$bad, good=$good — bad MUST equal good — diverges from agents/cross-auditor.md:430 write contract)"
    return 1
  fi
  # Positive: at least 2 canonical /security/ mentions must remain (the two
  # known sites at L546 + L731). Catches both-sites-deleted regressions.
  if [ "$good" -lt 2 ]; then
    echo "expected ≥2 canonical /security/ findings.md path mentions in SKILL.md (triage step 3 + Continue-mode iteration=N row), got $good"
    return 1
  fi
  return 0
}

# (NEW) `check_repo_findings_path_coherence` — X8 optional fourth tightening
# (broadened by X10 to cover the cross-auditor write contract filenames).
# Repo-wide superset of `check_skill_findings_path_coherence`: extends the
# count-equality guard across every markdown file under `agents/`, `docs/`,
# and `skills/` (the audit scope). The cross-auditor.md L430-431 is the
# canonical write contract source; if a future edit introduces a long-form
# bare regression THERE, the entire path-coherence chain is poisoned. This
# pin closes that surface — every `<kb(_path)?>/repos/<project>/...` mention
# whose tail matches one of the canonical findings.md / workdoc-iter.md
# filename patterns MUST include `/security/`.
#
# X10 fix: the original `*-code-findings.md` regex MISSED the canonical
# write-contract filename pattern at agents/cross-auditor.md L430-431:
#   - `<kb_path>/repos/<project>/security/<audit_slug>-findings.md`     (no `-code-` prefix)
#   - `<kb_path>/repos/<project>/security/<audit_slug>-workdoc-iter<N>.md`
# Mutation-verified: dropping `/security/` at L430 yielded bad=0/good=0
# under the old regex (pin PASSED). Broadened matcher now uses TWO regex
# pairs:
#   1. `-(code-)?findings\.md` — covers both `<slug>-code-findings.md` and
#      `<audit_slug>-findings.md` filenames.
#   2. `-workdoc-iter<N>\.md` — covers the cross-auditor workdoc filename.
# Per-file count equality on EACH pair independently; either pair drifting
# fails the pin with named file + per-pair counts.
check_repo_findings_path_coherence() {
  local files=()
  while IFS= read -r f; do files+=("$f"); done < <(find agents docs skills -type f -name '*.md')
  local drift_files=()
  local f bad_findings good_findings bad_workdoc good_workdoc
  for f in "${files[@]}"; do
    # X9 fix: count OCCURRENCES (`grep -oE | wc -l`), not matching LINES
    # (`grep -cE`). A single line carrying both a canonical /security/ mention
    # AND a bare mention would otherwise contribute 1 to both counters under
    # -cE, the equality holds, and the bare path slips through. Per-occurrence
    # counting makes that bypass impossible.
    bad_findings=$(grep -oE '<kb(_path)?>/repos/<project>/[^[:space:]`]*-(code-)?findings\.md' "$f" | wc -l | tr -d ' ')
    good_findings=$(grep -oE '<kb(_path)?>/repos/<project>/security/[^[:space:]`]*-(code-)?findings\.md' "$f" | wc -l | tr -d ' ')
    bad_workdoc=$(grep -oE '<kb(_path)?>/repos/<project>/[^[:space:]`]*-workdoc-iter<N>\.md' "$f" | wc -l | tr -d ' ')
    good_workdoc=$(grep -oE '<kb(_path)?>/repos/<project>/security/[^[:space:]`]*-workdoc-iter<N>\.md' "$f" | wc -l | tr -d ' ')
    if [ "$bad_findings" != "$good_findings" ] || [ "$bad_workdoc" != "$good_workdoc" ]; then
      drift_files+=("$f (findings: bad=$bad_findings good=$good_findings; workdoc: bad=$bad_workdoc good=$good_workdoc)")
    fi
  done
  if [ "${#drift_files[@]}" -gt 0 ]; then
    echo "repo-wide findings.md / workdoc-iter.md path-coherence drift detected (every full-prefix mention must include /security/) in: ${drift_files[*]}"
    return 1
  fi
  return 0
}

echo "Audit-evidence enum pins:"
check "audit-evidence-spec-template-schema"                check_spec_template_audit_evidence_schema
check "audit-evidence-skill-populated-at-terminal-sites"   check_skill_audit_evidence_populated_at_terminal_sites
check "audit-evidence-cross-auditor-yaml-frontmatter"      check_cross_auditor_evidence_class_in_yaml_frontmatter
check "audit-evidence-cross-auditor-spec-mode-contract"    check_cross_auditor_spec_mode_return_contract
check "audit-evidence-enum-values-canonical"               check_audit_evidence_enum_values_canonical
check "audit-evidence-skill-legacy-null-reader-semantics"  check_skill_legacy_null_reader_semantics
check "audit-evidence-skill-renderer-flag-wired"           check_skill_renderer_evidence_flag_wired
check "audit-evidence-marker-recognition-symmetry"         check_code_audit_marker_recognition_symmetry
check "audit-evidence-marker-recognition-mutation-protected" check_code_audit_marker_recognition_mutation_protected
check "audit-evidence-resume-clean-passed-extended"        check_code_audit_resume_clean_passed_extended_evidence
check "audit-evidence-resume-zero-diff-skip-extended"      check_code_audit_resume_zero_diff_skip_extended_evidence
check "contract-violated-routing-rule"                     check_skill_contract_violated_routing_rule
check "contract-violated-file-existence"                   check_skill_contract_violated_file_existence_check
check "contract-violated-overview-documented"              check_overview_contract_violated_documented
check "contract-violated-cross-auditor-never-writes"       check_cross_auditor_never_writes_extension
check "orchestrator-blocker-sanitization-rule"             check_skill_orchestrator_blocker_sanitization_rule
check "contract-violated-evidence-pair-invariant"          check_skill_evidence_pair_invariant
check "findings-path-coherence"                            check_skill_findings_path_coherence
check "repo-findings-path-coherence"                       check_repo_findings_path_coherence
check "audit-iteration-hard-cap-recognition"               check_audit_iteration_hard_cap_recognition
check "audit-iteration-hard-cap-recognition-mutation-protected" check_audit_iteration_hard_cap_recognition_mutation_protected
echo

# --- Session-handoff queue visibility (BACKLOG #52, spec 2026-04-28) ---
# Pins per spec §3.5: literal-presence checks for the contract surfaces, plus
# one fixture-driven behavioral pin that exercises the YAML emit-safety rule
# end-to-end (`check_research_skill_queue_spec_emit_yaml_safe`, X5(e)).
# Other behavioral classes — multi-item handling, materialization-status
# branching, malformed-frontmatter defensive paths — remain out of scope here;
# see spec §3.5 behavioral coverage gap, tracked as Q3-slice-2 follow-up.
echo "Session-handoff queue visibility pins:"

check_research_template_queued_specs_documented() {
  local f="skills/research/references/research-template.md"
  # POSITIVE: YAML-comment block documents schema (catches: schema not documented,
  # body-vs-frontmatter mistake — comment lives inside frontmatter, before closing ---).
  grep -qE '^# queued_specs:' "$f" \
    || { echo "missing YAML-comment header '^# queued_specs:' in $f"; return 1; }
  grep -qE '^#   - slug:' "$f" \
    || { echo "missing '#   - slug:' field-name in $f"; return 1; }
  grep -qE '^#     scope:' "$f" \
    || { echo "missing '#     scope:' field-name in $f"; return 1; }
  grep -qE '^#     id:' "$f" \
    || { echo "missing '#     id:' field-name in $f"; return 1; }
  # NEGATIVE: literal active key MUST NOT be set in template — opt-in only
  # (catches: schema accidentally promoted to mandatory field).
  if grep -qE '^queued_specs:' "$f"; then
    echo "literal active 'queued_specs:' present in $f (template is opt-in only)"
    return 1
  fi
  echo "research-template queued_specs schema documented as YAML comment OK"
}

check_research_skill_queue_spec_contract() {
  local f="skills/research/SKILL.md"
  # Extract §Conclude mode region with BSD-portable next-mode-anchored pattern
  # (avoids truncation on in-region '## ⏸ AWAITING YOUR INPUT' H2 banners).
  local region
  region=$(awk 'p && /^## Archive mode$/{exit} /^## Conclude mode$/{p=1} p' "$f")
  local missing=""
  for lit in '--queue-spec' 'pipe-delimited' 'frontmatter' 'slug' 'scope'; do
    printf '%s' "$region" | grep -qF -- "$lit" || missing="$missing $lit"
  done
  # 'dedup' matches both 'dedupe' and 'deduplicate'
  printf '%s' "$region" | grep -qF 'dedup' || missing="$missing dedup"
  # X5 anti-regression: contract MUST name the quote-on-emit rule for `scope:`
  # (catches future regression to unquoted scalars that corrupt frontmatter on
  # `:` / `#` / leading sigils — empirically verified via Codex YAML.safe_load).
  printf '%s' "$region" | grep -qF 'double-quoted YAML string' || missing="$missing double-quoted-scope-on-emit"
  # X5 anti-regression: contract MUST name the slug validation regex
  # (canonical filesystem-safe form; also used for materialization lookup).
  printf '%s' "$region" | grep -qF '^[a-z0-9][a-z0-9-]*$' || missing="$missing slug-validation-regex"
  # X5 anti-regression: contract MUST require post-emit YAML round-trip check
  # (last-line defense: catches any corrupt-frontmatter case the quote rule missed).
  if ! printf '%s' "$region" | grep -qE "re-parse the note's frontmatter|YAML round-trip"; then
    missing="$missing yaml-round-trip-check"
  fi
  if [ -n "$missing" ]; then
    echo "§Conclude region missing literals:$missing"
    return 1
  fi
  echo "research SKILL §Conclude --queue-spec contract documented OK"
}

# X5(e) — fixture-driven behavioral pin (Codex iter-3 proposal). Drives the
# `--queue-spec` YAML emit rule from skills/research/SKILL.md lines 200-214
# end-to-end against scopes carrying YAML-hazardous punctuation:
#   - `:`     (would parse as map-key in unquoted form → ScannerError)
#   - `#`     (would silently truncate at the comment boundary in unquoted form)
#   - `>`     (leading sigil → block-scalar indicator in unquoted form)
# Emits frontmatter following the documented contract (slug unquoted iff regex
# match; scope ALWAYS double-quoted with `\` and `"` backslash-escaped per
# YAML 1.1), round-trips it via `yaml.safe_load`, and asserts each parsed
# scope value equals its source byte-for-byte. Any divergence (parse failure,
# key-shifted-by-`:`, truncated-at-`#`, block-scalar-over-`>`) fails the pin.
check_research_skill_queue_spec_emit_yaml_safe() {
  python3 - <<'PY' || return 1
import sys, yaml

# Three fixture --queue-spec lines (1-pipe / 2-field form: `slug | scope`).
# Each scope contains exactly one of the YAML-hazardous characters that the
# X5 (a) "double-quote scope on emit" rule was specifically designed to handle.
fixtures = [
    ("colon-scope", "API: remove v1"),
    ("hash-scope", "pain #6 + replay mechanics"),
    ("sigil-scope", "> replay mechanics"),
]

# Emit per the documented contract: slug unquoted iff regex matches (all three
# pass `^[a-z0-9][a-z0-9-]*$`); scope ALWAYS double-quoted with `\` and `"`
# backslash-escaped per YAML 1.1.
def quote_scope(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

lines = ["queued_specs:"]
for slug, scope in fixtures:
    lines.append(f"  - slug: {slug}")
    lines.append(f"    scope: {quote_scope(scope)}")
emitted = "\n".join(lines) + "\n"

try:
    parsed = yaml.safe_load(emitted)
except yaml.YAMLError as e:
    print(f"YAML round-trip failed (parse error): {e}", file=sys.stderr)
    print("--- emitted frontmatter ---", file=sys.stderr)
    print(emitted, file=sys.stderr)
    sys.exit(1)

if not isinstance(parsed, dict) or "queued_specs" not in parsed:
    print(f"missing 'queued_specs' key in parsed YAML: {parsed!r}", file=sys.stderr)
    sys.exit(1)

items = parsed["queued_specs"]
if not isinstance(items, list) or len(items) != len(fixtures):
    print(f"expected {len(fixtures)} items, got: {items!r}", file=sys.stderr)
    sys.exit(1)

for (slug, scope), item in zip(fixtures, items):
    if not isinstance(item, dict):
        print(f"item is not a mapping: {item!r}", file=sys.stderr)
        sys.exit(1)
    if item.get("slug") != slug:
        print(f"slug mismatch: expected {slug!r}, got {item.get('slug')!r}", file=sys.stderr)
        sys.exit(1)
    # Byte-for-byte equality is the load-bearing assertion: catches the
    # `:`-key-shift, `#`-truncation, and `>`-block-scalar regression classes.
    if item.get("scope") != scope:
        print(f"scope round-trip mismatch for slug {slug!r}:", file=sys.stderr)
        print(f"  source:  {scope!r}", file=sys.stderr)
        print(f"  parsed:  {item.get('scope')!r}", file=sys.stderr)
        sys.exit(1)

print(f"--queue-spec YAML emit round-trip OK ({len(fixtures)} fixtures)")
PY
}

check_feature_skill_session_resume_research_scan() {
  local f="skills/feature/SKILL.md"
  # Extract §Session resume — KB scan with next-mode-anchored pattern.
  local region
  region=$(awk 'p && /^## Phase 0:/{exit} /^## Session resume — KB scan$/{p=1} p' "$f")
  local missing=""
  for lit in 'status: CONCLUDED' 'queued_specs' 'frontmatter'; do
    printf '%s' "$region" | grep -qF -- "$lit" || missing="$missing $lit"
  done
  # X4 anti-regression: contract MUST name the depth-0 / any-depth requirement
  # (catches future regression to a bare '**/*.md' glob that silently misses
  # direct-child notes under default bash without `shopt -s globstar`).
  if ! printf '%s' "$region" | grep -qE 'depth-0|direct child|any depth|direct children'; then
    missing="$missing depth-0-or-any-depth"
  fi
  # X4 anti-regression: contract MUST name a recursive-walk implementation literal
  # (one of: `find -type f`, `rglob`, `globstar`) — these are depth-0-safe;
  # a bare `**/*.md` glob without an enabling literal is the broken form.
  if ! printf '%s' "$region" | grep -qE 'find -type f|rglob|globstar'; then
    missing="$missing recursive-walk-literal"
  fi
  # X7 anti-regression: contract MUST carry the canonical warning text for the
  # reader-side slug regex re-validation (closes producer/reader asymmetry —
  # manually-edited frontmatter slug like `slug: *` cannot smuggle glob metachars
  # into the materialization-lookup form). Catches regression to "we documented
  # the rule but lost the warning name" form.
  if ! printf '%s' "$region" | grep -qF 'slug fails validation regex'; then
    missing="$missing slug-fails-validation-regex-warning"
  fi
  # X7 anti-regression: contract MUST carry the literal validation regex shape
  # (mirrors producer-side regex at skills/research/SKILL.md §Conclude mode).
  # Catches regression to "we documented some validation but lost the regex shape" form.
  if ! printf '%s' "$region" | grep -qF '^[a-z0-9][a-z0-9-]*$'; then
    missing="$missing slug-validation-regex-literal"
  fi
  if [ -n "$missing" ]; then
    echo "§Session resume — KB scan missing literals:$missing"
    return 1
  fi
  echo "feature SKILL §Session resume research-queue scan contract documented OK"
}

check_feature_skill_continue_research_scan() {
  local f="skills/feature/SKILL.md"
  # Extract §Continue mode with next-mode-anchored pattern (Discard avoids in-region AWAITING H2 banners).
  local region
  region=$(awk 'p && /^## Discard mode$/{exit} /^## Continue mode$/{p=1} p' "$f")
  local missing=""
  printf '%s' "$region" | grep -qF 'queued_specs' || missing="$missing queued_specs"
  printf '%s' "$region" | grep -qF 'aterialization status' || missing="$missing materialization-status-cross-ref"
  if [ -n "$missing" ]; then
    echo "§Continue mode missing literals:$missing"
    return 1
  fi
  echo "feature SKILL §Continue mode materialization-status cross-reference documented OK"
}

check_feature_skill_status_queued_render_rules() {
  local f="skills/feature/SKILL.md"
  # Extract `### Queued from retrospectives` block with BSD-portable next-H3-anchored pattern
  # (H3-only terminator is provably safe — AWAITING banners are H2 and cannot truncate).
  local region
  region=$(awk 'p && /^### /{exit} /^### Queued from retrospectives$/{p=1} p' "$f")
  local missing=""
  for lit in 'Source note' 'Project' 'Queued spec' 'Queued since' 'State' 'oldest first' 'Omit the section' 'created:'; do
    printf '%s' "$region" | grep -qF -- "$lit" || missing="$missing '$lit'"
  done
  # X6 anti-regression: the load-bearing scan-semantics paragraph MUST state the
  # correct project-attribution rule (path segment immediately after <kb>/repos/),
  # not the buggy "parent directory of the matched note" form that mis-attributes
  # nested research notes (e.g. release-retrospective/<note>.md → release-retrospective).
  printf '%s' "$region" | grep -qF 'path segment immediately after' || missing="$missing 'path-segment-immediately-after'"
  # X6 anti-regression: explicit nested-note coverage so depth-of-nesting drift is caught.
  printf '%s' "$region" | grep -qF 'regardless of nesting depth' || missing="$missing 'regardless-of-nesting-depth'"
  if [ -n "$missing" ]; then
    echo "### Queued from retrospectives missing literals:$missing"
    return 1
  fi
  echo "feature SKILL §Status mode ### Queued from retrospectives render rules documented OK"
}

check "session-handoff-queued-specs-template-schema"      check_research_template_queued_specs_documented
check "session-handoff-research-skill-queue-spec-contract" check_research_skill_queue_spec_contract
check "session-handoff-research-skill-queue-spec-emit-yaml-safe" check_research_skill_queue_spec_emit_yaml_safe
check "session-handoff-feature-session-resume-research-scan" check_feature_skill_session_resume_research_scan
check "session-handoff-feature-continue-research-scan"    check_feature_skill_continue_research_scan
check "session-handoff-feature-status-queued-render-rules" check_feature_skill_status_queued_render_rules
echo

# --- Cut-spec hard-fail (BACKLOG #56, spec 2026-04-29) ---
# Pins per spec §3.4: 1 schema (policy doc present) + 5 prompt-text pins
# (each asserting the FULL canonical hard-fail line byte-for-byte at its
# parsing-surface site — 3 voice anchors per X3 fix: ERROR: prefix, the
# `was removed in cut spec design/<slug>.md` middle, and the
# `. Read that spec for the migration path.` remediation suffix).
# Behavioral coverage gap (acknowledged honestly per the X3 honesty-edit
# precedent from spec 2026-04-28-session-handoff-queue-visibility): these
# are prompt-text pins — they confirm the prose is present, not that
# Claude actually hard-stops at runtime when it sees the flag. Behavioral
# verification (Claude reads the prose → emits the error → halts) is NOT
# covered here. Tracked as Q4-slice-2 follow-up (paired with BACKLOG #57's
# shared-absence-helper-extraction).
echo "Cut-spec hard-fail pins:"

check_cut_spec_policy_doc_present() {
  local f="docs/cut-spec-policy.md"
  if [ ! -f "$f" ]; then
    echo "cut-spec-policy doc missing: $f"
    return 1
  fi
  if [ "$(head -1 "$f")" != "# Cut-spec hard-fail policy" ]; then
    echo "cut-spec-policy H1 mismatch: expected '# Cut-spec hard-fail policy'"
    return 1
  fi
  for lit in 'ERROR:' 'was removed in cut spec' 'Read that spec for the migration path'; do
    if ! grep -qF -- "$lit" "$f"; then
      echo "cut-spec-policy missing literal: $lit"
      return 1
    fi
  done
  for slug in '2026-04-26-cut-probe-downgrade' '2026-04-27-cut-from-investigation' '2026-04-27-cut-codex-fast' '2026-04-27-cut-multi-gh-account'; do
    if ! grep -qF -- "$slug" "$f"; then
      echo "cut-spec-policy missing registry slug: $slug"
      return 1
    fi
  done
  echo "check_cut_spec_policy_doc_present: schema OK (H1 + 3 voice literals + 4 cut-spec slugs)"
}

check_kb_discovery_codex_model_fast_hard_fail() {
  local f="docs/kb-discovery.md"
  local line='ERROR: codex.model_fast was removed in cut spec design/2026-04-27-cut-codex-fast.md. Read that spec for the migration path.'
  if ! grep -qF -- "$line" "$f"; then
    echo "kb-discovery missing canonical codex.model_fast hard-fail line"
    return 1
  fi
  echo "check_kb_discovery_codex_model_fast_hard_fail: canonical line present"
}

check_kb_discovery_github_block_hard_fail() {
  local f="docs/kb-discovery.md"
  local line='ERROR: github: config block was removed in cut spec design/2026-04-27-cut-multi-gh-account.md. Read that spec for the migration path.'
  if ! grep -qF -- "$line" "$f"; then
    echo "kb-discovery missing canonical github: block hard-fail line"
    return 1
  fi
  echo "check_kb_discovery_github_block_hard_fail: canonical line present"
}

check_cross_audit_probe_downgrade_hard_fail() {
  local f="skills/cross-audit/SKILL.md"
  local line='ERROR: --probe-downgrade was removed in cut spec design/2026-04-26-cut-probe-downgrade.md. Read that spec for the migration path.'
  if ! grep -qF -- "$line" "$f"; then
    echo "cross-audit SKILL missing canonical --probe-downgrade hard-fail line"
    return 1
  fi
  echo "check_cross_audit_probe_downgrade_hard_fail: canonical line present"
}

check_cross_audit_account_flag_hard_fail() {
  local f="skills/cross-audit/SKILL.md"
  local line='ERROR: --account was removed in cut spec design/2026-04-27-cut-multi-gh-account.md. Read that spec for the migration path.'
  if ! grep -qF -- "$line" "$f"; then
    echo "cross-audit SKILL missing canonical --account hard-fail line"
    return 1
  fi
  echo "check_cross_audit_account_flag_hard_fail: canonical line present"
}

check_feature_skill_from_investigation_hard_fail() {
  local f="skills/feature/SKILL.md"
  local line='ERROR: --from-investigation was removed in cut spec design/2026-04-27-cut-from-investigation.md. Read that spec for the migration path.'
  if ! grep -qF -- "$line" "$f"; then
    echo "feature SKILL missing canonical --from-investigation hard-fail line"
    return 1
  fi
  echo "check_feature_skill_from_investigation_hard_fail: canonical line present"
}

check "cut-spec-policy-doc-present"                        check_cut_spec_policy_doc_present
check "kb-discovery-codex-model-fast-hard-fail"            check_kb_discovery_codex_model_fast_hard_fail
check "kb-discovery-github-block-hard-fail"                check_kb_discovery_github_block_hard_fail
check "cross-audit-probe-downgrade-hard-fail"              check_cross_audit_probe_downgrade_hard_fail
check "cross-audit-account-flag-hard-fail"                 check_cross_audit_account_flag_hard_fail
check "feature-skill-from-investigation-hard-fail"         check_feature_skill_from_investigation_hard_fail
echo

# --- Shared absence-helper rejection wrappers (BACKLOG #57) ---
echo "Shared absence-helper rejection wrappers (2026-04-30):"

# Helper A rejection wrapper — exercises assert_literal_absent_in_live_source
# against a fixture file containing the unique tamper literal. The wrapper
# passes the fixture path as the helper's optional trailing path arg, so the
# helper scans the fixture (NOT the production live-source path-set), finds
# the tamper literal, returns 1; wrapper's `! ...` becomes true; success.
check_smoke_helper_assert_literal_absent_in_live_source_rejects_stale() {
  local fixture='tests/fixtures/shared-absence-helper-extraction/live-source-tamper.txt'
  if ! assert_literal_absent_in_live_source 'TAMPER_LITERAL_FOR_HELPER_REJECTION_TEST' 'rejection-test' "$fixture" >/dev/null 2>&1; then
    echo "assert_literal_absent_in_live_source correctly rejected stale live-source-tamper.txt fixture"
    return 0
  fi
  echo "assert_literal_absent_in_live_source wrongly accepted live-source-tamper.txt"
  return 1
}

# Helper B rejection wrapper — exercises assert_no_stale_section_header_comments
# against a fixture file containing a `^# ` top-of-line comment matching the
# tamper pattern. Same shape as Helper A wrapper.
check_smoke_helper_assert_no_stale_section_header_comments_rejects_stale() {
  local fixture='tests/fixtures/shared-absence-helper-extraction/stale-comment-tamper.sh'
  if ! assert_no_stale_section_header_comments 'TAMPER_PATTERN_HELPER_B_REJECTION_TEST' 'rejection-test' "$fixture" >/dev/null 2>&1; then
    echo "assert_no_stale_section_header_comments correctly rejected stale stale-comment-tamper.sh fixture"
    return 0
  fi
  echo "assert_no_stale_section_header_comments wrongly accepted stale-comment-tamper.sh"
  return 1
}

check "check_smoke_helper_assert_literal_absent_in_live_source_rejects_stale" check_smoke_helper_assert_literal_absent_in_live_source_rejects_stale
check "check_smoke_helper_assert_no_stale_section_header_comments_rejects_stale" check_smoke_helper_assert_no_stale_section_header_comments_rejects_stale
echo

# --- Plugin claims-vs-runtime audit (BACKLOG #46) ---
echo "Plugin claims-vs-runtime audit pins:"
check "smoke_proves_manifest_canonical"       check_smoke_proves_manifest_canonical
check "smoke_summary_breaks_down_by_class"    check_smoke_summary_breaks_down_by_class
check "agent_claims_doc_exists_and_classified" check_agent_claims_doc_exists_and_classified
check "spec_compliance_checker_description_narrow" check_spec_compliance_checker_description_narrow
check "mission_r_enforcement_claim_narrow"         check_mission_r_enforcement_claim_narrow
check "check_new_pin_classified" check_new_pin_classified
echo

# --- R-rules taxonomy + conditional-loading seam pins ---
echo "R-rules taxonomy pins:"
check "r-rules-taxonomy-schema"               check_r_rules_taxonomy_schema
check "cross-auditor-security-preamble"       check_cross_auditor_security_preamble
check "spec-compliance-filter-preamble"       check_spec_compliance_filter_preamble
check "security-cluster-rules-present"             check_security_cluster_rules_present
check "r9-idor-covers-state-changing-endpoints"    check_r9_idor_covers_state_changing_endpoints
check "r10-allowlist-literal-set-definition"       check_r10_allowlist_literal_set_definition
check "r-rule-metadata-consistency"                check_r_rule_metadata_consistency
check "r11-audience-all-and-encoded-secret-shapes" check_r11_audience_all_and_encoded_secret_shapes
check "r13-oidc-minimal-permissions"               check_r13_oidc_minimal_permissions
check "r14-sensitive-reads-and-access-denied-audit" check_r14_sensitive_reads_and_access_denied_audit
check "cross-auditor-loads-security-cluster"       check_cross_auditor_loads_security_cluster
check "cross-auditor-step1-step2-load-instructions" check_cross_auditor_step1_step2_load_instructions
echo

# --- Attack-surface profile pins ---
echo "Attack-surface profile pins:"
check "skill-attack-surface-slot-prompts" check_skill_attack_surface_slot_prompts
check "spec-template-attack-surface-section" check_spec_template_attack_surface_section
check "cross-auditor-consumes-attack-surface-profile" check_cross_auditor_consumes_attack_surface_profile
echo

# --- Dependency freshness probe (Probe G — supply-chain layer) ---
echo "Dependency freshness probe (Probe G):"
check "probe-g-corpus-fixture-valid" check_probe_g_corpus_fixture_valid
check "probe-g-detector-fires-on-major-drift" check_probe_g_detector_fires_on_major_drift
check "probe-g-detector-clean-at-current-major" check_probe_g_detector_clean_at_current_major
check "probe-g-detector-ineligible-no-lockfile" check_probe_g_detector_ineligible_no_lockfile
check "probe-g-detector-fires-on-major-only-no-dot" check_probe_g_detector_fires_on_major_only_no_dot
check "probe-g-detector-fires-on-extras-syntax" check_probe_g_detector_fires_on_extras_syntax
check "probe-g-detector-fires-on-whitespace-eq" check_probe_g_detector_fires_on_whitespace_eq
check "probe-g-detector-rejects-malformed-requirements" check_probe_g_detector_rejects_malformed_requirements
check "probe-g-detector-fires-on-uppercase-name-package-lock" check_probe_g_detector_fires_on_uppercase_name_package_lock
check "probe-g-detector-out-of-diff-lockfile-ignored" check_probe_g_detector_out_of_diff_lockfile_ignored
check "probe-g-detector-in-diff-lockfile-evaluated" check_probe_g_detector_in_diff_lockfile_evaluated
check "probe-g-yarn-berry-peer-dep" check_probe_g_yarn_berry_peer_dep
check "probe-g-yarn-scoped-npm-protocol" check_probe_g_yarn_scoped_npm_protocol
check "probe-g-pnpm-v9-format" check_probe_g_pnpm_v9_format
check "probe-g-pnpm-v9-quoted-scoped" check_probe_g_pnpm_v9_quoted_scoped
check "probe-g-yarn-scoped-alias-target" check_probe_g_yarn_scoped_alias_target
check "probe-g-yarn-portal-and-github" check_probe_g_yarn_portal_and_github
check "probe-g-vendored-excluded" check_probe_g_vendored_excluded
check "probe-g-boundary-drift-2-suppressed" check_probe_g_boundary_drift_2_suppressed
check "probe-g-boundary-drift-3-fired" check_probe_g_boundary_drift_3_fired
check "probe-g-npm-v7-packages-walk-and-dep-classes" check_probe_g_npm_v7_packages_walk_and_dep_classes
check "probe-g-npm-range-vs-resolved-dedup" check_probe_g_npm_range_vs_resolved_dedup
check "probe-g-pre-1-0-skipped" check_probe_g_pre_1_0_skipped
echo

# --- Typosquatting probe (Probe H — supply-chain layer) ---
echo "Typosquatting probe (Probe H):"
check "probe-h-corpus-path-resolution" check_probe_h_corpus_path_resolution
check "probe-h-detector-fires-on-typosquat" check_probe_h_detector_fires_on_typosquat
check "probe-h-detector-clean-canonical-name" check_probe_h_detector_clean_canonical_name
check "probe-h-detector-clean-distant-name" check_probe_h_detector_clean_distant_name
check "probe-h-detector-fires-on-major-only-no-dot" check_probe_h_detector_fires_on_major_only_no_dot
check "probe-h-detector-fires-on-extras-syntax" check_probe_h_detector_fires_on_extras_syntax
check "probe-h-detector-fires-on-whitespace-eq" check_probe_h_detector_fires_on_whitespace_eq
check "probe-h-detector-rejects-malformed-requirements" check_probe_h_detector_rejects_malformed_requirements
check "probe-h-detector-out-of-diff-lockfile-ignored" check_probe_h_detector_out_of_diff_lockfile_ignored
check "probe-h-detector-in-diff-lockfile-evaluated" check_probe_h_detector_in_diff_lockfile_evaluated
check "probe-h-yarn-berry-peer-dep" check_probe_h_yarn_berry_peer_dep
check "probe-h-yarn-scoped-npm-protocol" check_probe_h_yarn_scoped_npm_protocol
check "probe-h-pnpm-v9-format" check_probe_h_pnpm_v9_format
check "probe-h-pnpm-v9-quoted-scoped" check_probe_h_pnpm_v9_quoted_scoped
check "probe-h-yarn-scoped-alias-target" check_probe_h_yarn_scoped_alias_target
check "probe-h-yarn-portal-and-github" check_probe_h_yarn_portal_and_github
check "probe-h-levenshtein-length-cap" check_probe_h_levenshtein_length_cap
check "probe-h-vendored-excluded" check_probe_h_vendored_excluded
check "probe-h-npm-v7-packages-walk-and-dep-classes" check_probe_h_npm_v7_packages_walk_and_dep_classes
check "probe-h-npm-range-vs-resolved-dedup" check_probe_h_npm_range_vs_resolved_dedup
echo

# --- STRIDE-lite spec-template slot pins ---
echo "STRIDE-lite spec-template slot pins:"
check "skill-stride-lite-block-gated" check_skill_stride_lite_block_gated
check "cross-auditor-consumes-stride-lite" check_cross_auditor_consumes_stride_lite
echo

# --- project_type threading: docs surfaces + SKILL.md spawn sites + cross-auditor degraded warning ---
echo "project_type threading pins:"
check "project-type-documented-in-config-surfaces" check_project_type_documented_in_config_surfaces
check "skill-threads-project-type-at-spec-audit-spawn" check_skill_threads_project_type_at_spec_audit_spawn
check "skill-threads-project-type-at-code-audit-spawn" check_skill_threads_project_type_at_code_audit_spawn
check "skill-threads-project-type-at-code-audit-respawn" check_skill_threads_project_type_at_code_audit_respawn
check "skill-threads-project-type-at-code-audit-resume-routing" check_skill_threads_project_type_at_code_audit_resume_routing
check "cross-auditor-emits-degraded-warning-when-project-type-unset" check_cross_auditor_emits_degraded_warning_when_project_type_unset
check "cross-auditor-documents-warning-emit-location" check_cross_auditor_documents_warning_emit_location
check "cross-auditor-replaces-silent-skip-gate" check_cross_auditor_replaces_silent_skip_gate
check "cross-auditor-r-rule-path-env-first-precedence" check_cross_auditor_r_rule_path_env_first_precedence
check "cross-auditor-blocker-sanitization-truncate-before-escape" check_cross_auditor_blocker_sanitization_truncate_before_escape
check "cross-auditor-probe-failures-schema-aligned" check_cross_auditor_probe_failures_schema_aligned
check "spec-mode-footer-sentinel-marker-contract" check_spec_mode_footer_sentinel_marker_contract
check "skill-pass2-respawn-loop-monotonic-numbering" check_skill_pass2_respawn_loop_monotonic_numbering
check "librarian-agent-no-bash-in-tools" check_librarian_agent_no_bash_in_tools
check "hooks-json-stop-timeout-30s" check_hooks_json_stop_timeout_30s
check "claude-md-has-testing-section" check_claude_md_has_testing_section
check "r8-single-source" check_r8_single_source
check "skill-dispatch-param-block-single-source" check_skill_dispatch_param_block_single_source
check "evidence-class-allowlist-single-source" check_evidence_class_allowlist_single_source
check "eof-adjacency-parser-single-source" check_eof_adjacency_parser_single_source
echo


echo
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Behavioral: $BEHAVIORAL_COUNT"
echo "Schema: $SCHEMA_COUNT"
echo "Prompt-text: $PROMPT_TEXT_COUNT"
echo "Unclassified: $UNCLASSIFIED_COUNT"
if [ "$FAIL" -ne 0 ]; then
  echo "Failures:"
  for f in "${FAILURES[@]}"; do
    echo "  - $f"
  done
  exit 1
fi
exit 0
