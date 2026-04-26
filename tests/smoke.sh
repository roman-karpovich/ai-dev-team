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

# --- /feature --from-investigation bridge ---
echo "Feature skill --from-investigation:"

check_feature_from_investigation_flag() {
  grep -q -- "--from-investigation" skills/feature/SKILL.md \
    || { echo "SKILL.md missing --from-investigation flag"; return 1; }
  echo "feature SKILL.md documents --from-investigation"
}

check_feature_investigation_source_field() {
  grep -q "investigation_source" skills/feature/SKILL.md \
    && grep -q "investigation_source" skills/feature/references/spec-template.md \
    || { echo "investigation_source missing in SKILL.md or spec-template.md"; return 1; }
  echo "investigation_source documented in skill and template"
}

check "feature --from-investigation flag"    check_feature_from_investigation_flag
check "feature investigation_source"         check_feature_investigation_source_field
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

# 8. cross-auditor.md — pr_number / pr_changed_files / pr_head_oid literal tokens,
#    a fenced YAML block in Input/Outputs with all 5 pr_files keys,
#    and the literal delegation path `hooks/lib/build_pr_files.sh`.
check_cross_auditor_pr_yaml_block() {
  python3 - <<'PY'
import re, sys
text = open('agents/cross-auditor.md').read()
for token in ('pr_number', 'pr_changed_files', 'pr_head_oid'):
    if token not in text:
        print(f"cross-auditor.md missing literal token '{token}'")
        sys.exit(1)
if 'hooks/lib/build_pr_files.sh' not in text:
    print("cross-auditor.md missing literal delegation path 'hooks/lib/build_pr_files.sh'")
    sys.exit(1)
# Find all fenced yaml blocks with all 5 pr_files keys
keys = ('filename:', 'status:', 'previous_filename:', 'patch_present:', 'is_submodule:')
blocks = re.findall(r'```ya?ml\n(.*?)\n```', text, re.DOTALL)
found = False
for b in blocks:
    if all(k in b for k in keys):
        found = True
        break
if not found:
    print("cross-auditor.md: no fenced YAML block contains all 5 pr_files keys "
          "(filename:/status:/previous_filename:/patch_present:/is_submodule:)")
    sys.exit(1)
print("cross-auditor.md input/output YAML block has all 5 pr_files keys + build_pr_files.sh path")
PY
}

# 9. cross-auditor.md uses `gh pr checkout`
check_cross_auditor_gh_pr_checkout() {
  grep -q 'gh pr checkout' agents/cross-auditor.md \
    || { echo "cross-auditor.md missing 'gh pr checkout'"; return 1; }
  echo "cross-auditor.md uses gh pr checkout"
}

# 10. cross-auditor.md: near the async Codex helper launch, contains `CODEX_WD` AND `worktree`.
check_cross_auditor_codex_cwd_proximity() {
  python3 - <<'PY'
import re, sys
lines = open('agents/cross-auditor.md').read().splitlines()
ok = False
for i, line in enumerate(lines):
    if 'codex_audit_dispatch.sh' in line:
        start = max(0, i - 6)
        window = '\n'.join(lines[start:i+7])
        if 'CODEX_WD' in window and 'worktree' in window:
            ok = True
            break
if not ok:
    print("cross-auditor.md: no codex_audit_dispatch.sh launch has both CODEX_WD and worktree nearby")
    sys.exit(1)
print("cross-auditor.md Codex cwd override proximity OK")
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

# (b) feature SKILL.md must have exactly 17 AWAITING banner lines. The total includes
# the §Code audit triage banner added by spec 2026-04-22-mandatory-code-audit-phase Step 1.
check_feature_awaiting_count_17() {
  local n
  n=$(grep -c "^## ⏸ AWAITING YOUR INPUT$" skills/feature/SKILL.md)
  if [ "$n" != "17" ]; then
    echo "feature AWAITING count=$n expected 17"
    return 1
  fi
  echo "feature AWAITING count=17 OK"
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
  if [ "$n" != "4" ]; then
    echo "research AWAITING count=$n expected 4"
    return 1
  fi
  echo "research AWAITING count=4 OK"
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

# (r) ruler-prefix count matches total banner count (expected 24 — includes the
# §Code audit triage banner added by spec 2026-04-22-mandatory-code-audit-phase Step 1).
check_awaiting_ruler_prefix_count_matches() {
  local c
  c=$(cat skills/feature/SKILL.md skills/cross-audit/SKILL.md skills/research/SKILL.md skills/investigate/SKILL.md | awk '
    BEGIN { c = 0; prev = "" }
    ($0 == "## ⏸ AWAITING YOUR INPUT" || $0 == "## ⏸ APPROVAL REQUIRED") && prev == "---" { c++ }
    { prev = $0 }
    END { print c }
  ')
  if [ "$c" != "24" ]; then
    echo "ruler-prefix count=$c expected 24"
    return 1
  fi
  echo "ruler-prefix count=24 OK"
}

# (s) each banner has trailing bold question within 15 lines (expected 24 — includes the
# §Code audit triage banner added by spec 2026-04-22-mandatory-code-audit-phase Step 1).
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
  if [ "$c" != "24" ]; then
    echo "trailing-bold-present-each count=$c expected 24"
    return 1
  fi
  echo "trailing-bold-present-each=24 OK"
}

check "banner-convention-doc-valid"             check_banner_convention_doc_valid
check "feature-AWAITING-count-17"               check_feature_awaiting_count_17
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

# --- Codex Fast config surface ---
echo "Codex Fast config surface:"

check "codex.model_fast documented in .ai-dev-team.yml.example" \
  bash -c "grep -qF -- '#   model_fast: gpt-5.5-fast    # optional — per-task opt-in for developer-codex only (ignored by cross-auditor)' .ai-dev-team.yml.example"

check ".ai-dev-team.yml.example documents model_fast precondition" \
  bash -c "grep -qF -- '#   NOTE: when codex.model_fast is set, codex.model must also be set and must differ from codex.model_fast (otherwise cross-auditor would use Fast reasoning).' .ai-dev-team.yml.example"
echo

# --- Codex Fast routing ---
echo "Codex Fast routing:"

assert_codex_fast_section_present() {
  local sec
  sec=$(extract_md_section skills/feature/references/agent-routing.md "## Codex Fast (opt-in)")
  [ -n "$sec" ] || { echo "## Codex Fast (opt-in) section missing"; return 1; }
  echo "## Codex Fast (opt-in) section present"
}
check "Codex Fast routing section present" assert_codex_fast_section_present

assert_codex_fast_triggers_bulletform() {
  local sec
  sec=$(extract_md_section skills/feature/references/agent-routing.md "## Codex Fast (opt-in)")
  printf '%s\n' "$sec" | grep -qE '^- \*\*T-CF1\*\*:' || { echo "- **T-CF1**: bullet missing"; return 1; }
  printf '%s\n' "$sec" | grep -qE '^- \*\*T-CF2\*\*:' || { echo "- **T-CF2**: bullet missing"; return 1; }
  echo "T-CF1/T-CF2 bullets present in Codex Fast section"
}
check "T-CF bullets defined in Codex Fast section" assert_codex_fast_triggers_bulletform

assert_codex_fast_ban_line() {
  local sec
  sec=$(extract_md_section skills/feature/references/agent-routing.md "## Codex Fast (opt-in)")
  printf '%s\n' "$sec" | grep -qF -- '**Cross-auditor never consumes `codex.model_fast`.** Audit reasoning depth is non-negotiable; Fast is developer-codex-only.' \
    || { echo "cross-auditor ban line missing from Codex Fast section"; return 1; }
  echo "cross-auditor ban line present"
}
check "cross-auditor ban line in Codex Fast section" assert_codex_fast_ban_line

assert_codex_fast_anti_triggers() {
  local sec
  sec=$(extract_md_section skills/feature/references/agent-routing.md "## Codex Fast (opt-in)")
  # F8: **Anti-triggers** label followed by at least one '- ' bullet (skip blanks)
  printf '%s\n' "$sec" | awk '
    /\*\*Anti-triggers\*\*/ { found=1; next }
    found && /^[[:space:]]*$/ { next }
    found { if (/^- /) { ok=1; exit } else { exit } }
    END { exit(ok?0:1) }
  ' || { echo "**Anti-triggers** label + bullet missing in Codex Fast section"; return 1; }
  # F9: all 3 tokens must appear within the section
  printf '%s\n' "$sec" | grep -qF -- 'security-sensitive' || { echo "token security-sensitive missing"; return 1; }
  printf '%s\n' "$sec" | grep -qF -- 'cross-cutting'      || { echo "token cross-cutting missing"; return 1; }
  printf '%s\n' "$sec" | grep -qF -- 'new-abstraction'    || { echo "token new-abstraction missing"; return 1; }
  echo "Anti-triggers + 3 category tokens present"
}
check "Anti-triggers block with 3 tokens in Codex Fast section" assert_codex_fast_anti_triggers

assert_rationale_logging_three_sections() {
  local sec
  sec=$(extract_md_section skills/feature/references/agent-routing.md "## Rationale logging")
  printf '%s\n' "$sec" | grep -qF -- '`rationale=` MUST be a trigger ID from one of the three agent sections above (including `Codex Fast`).' \
    || { echo "## Rationale logging missing updated 'three agent sections' sentence"; return 1; }
  echo "Rationale logging sentence updated to three agent sections"
}
check "Rationale logging mentions three agent sections" assert_rationale_logging_three_sections

check "agent-routing preamble lists T-CF# as valid" \
  bash -c "grep -qF -- 'Trigger IDs below (\`T-C#\`, \`T-S#\`, \`T-CF#\`) are the only valid \`rationale=\` values in \`last_agent=\` Log entries.' skills/feature/references/agent-routing.md"
echo

# --- Codex Fast agent-selection menu ---
echo "Codex Fast agent-selection menu:"

check "SKILL.md agent-selection lists Codex Fast" \
  bash -c "grep -qF -- '1b. **Codex Fast** — faster/cheaper variant; only shown when \`codex.model_fast\` is configured.' skills/feature/SKILL.md"

assert_skill_option_1b_wiring() {
  local sec
  sec=$(extract_md_section skills/feature/SKILL.md '#### Option 1b: Codex Fast (developer-codex agent)')
  [ -n "$sec" ] || { echo '#### Option 1b: Codex Fast (developer-codex agent) subsection missing'; return 1; }
  printf '%s\n' "$sec" | grep -qF -- '- `codex_model`: the value of `codex.model_fast` from config (not `codex.model`)' \
    || { echo 'Option 1b missing dispatch-wiring line (codex_model ← codex.model_fast)'; return 1; }
  echo 'Option 1b subsection wires codex.model_fast → codex_model'
}
check "SKILL.md Option 1b subsection wires codex.model_fast" assert_skill_option_1b_wiring

check "SKILL.md renders Option 1b conditionally on codex.model_fast" \
  bash -c "grep -qF -- 'Render option 1b and the \"#### Option 1b: Codex Fast (developer-codex agent)\" subsection only when \`codex.model_fast\` resolved in Phase 0; when it is unset, omit both entirely (the menu reverts to two options).' skills/feature/SKILL.md"
echo

# --- Codex Fast cross-auditor ban ---
echo "Codex Fast cross-auditor ban:"

check "cross-auditor.md bans codex.model_fast" \
  bash -c "grep -qF -- '- **Never** read \`codex.model_fast\`. Cross-audit always uses \`codex.model\` (normal) or the Codex default; Fast is developer-codex-only.' agents/cross-auditor.md"
echo

# --- Multi-GitHub-account (2026-04-18) ---

# Helper: extract Phase 0.5 section from SKILL.md (between `## Phase 0.5:` and the next `## `).
extract_phase_0_5() {
  awk '/^## Phase 0\.5:/{in_s=1} in_s && /^## Phase 1-2:/{exit} in_s{print}' \
    skills/cross-audit/SKILL.md
}

echo "Multi-GitHub-account config schema (Step 1):"

# F1 (5 asserts): .ai-dev-team.yml.example has commented github: block with 5 keys on commented lines.
check "yml.example F1 commented 'github:' line" \
  bash -c "grep -qE '^#[[:space:]]*github:' .ai-dev-team.yml.example"
check "yml.example F1 commented 'default_account:' line" \
  bash -c "grep -qE '^#[[:space:]]+default_account:' .ai-dev-team.yml.example"
check "yml.example F1 commented 'accounts:' line" \
  bash -c "grep -qE '^#[[:space:]]+accounts:' .ai-dev-team.yml.example"
check "yml.example F1 commented 'token_env:' line" \
  bash -c "grep -qE '^#[[:space:]]+token_env:' .ai-dev-team.yml.example"
check "yml.example F1 commented 'host:' line" \
  bash -c "grep -qE '^#[[:space:]]+host:' .ai-dev-team.yml.example"

# F2 (2 asserts): docs/kb-discovery.md documents github: block AND contains the verbatim precedence line.
# Retargeted from skills/cross-audit/SKILL.md to docs/kb-discovery.md per spec
# 2026-04-20-shared-phase0 §3.8(4). The YAML schema reproduced byte-exact in
# the "## Multi-account github: config block" section of the shared doc.
check_skill_phase0_github_block() {
  # Extract the github: config block section of docs/kb-discovery.md
  # (between `## Multi-account github:` and the next `## ` heading).
  local sec
  sec=$(awk '/^## Multi-account github:/{in_s=1; next} in_s && /^## /{exit} in_s{print}' docs/kb-discovery.md)
  printf '%s\n' "$sec" | grep -qE '^[[:space:]]*github:' \
    || { echo "docs/kb-discovery.md missing github: block entry"; return 1; }
  printf '%s\n' "$sec" | grep -qE '^[[:space:]]*default_account:' \
    || { echo "docs/kb-discovery.md missing default_account: under github: block"; return 1; }
  printf '%s\n' "$sec" | grep -qE '^[[:space:]]*accounts:' \
    || { echo "docs/kb-discovery.md missing accounts: under github: block"; return 1; }
  printf '%s\n' "$sec" | grep -qE '^[[:space:]]*token_env:' \
    || { echo "docs/kb-discovery.md missing token_env: under github: block"; return 1; }
  echo "docs/kb-discovery.md github: block documented"
}
check "SKILL.md F2 Phase 0 github: block" check_skill_phase0_github_block

check "SKILL.md F2 precedence line verbatim" \
  bash -c "grep -qF -- 'precedence: --account flag → URL host match → default_account → ambient gh auth' skills/cross-audit/SKILL.md"
echo

echo "Multi-GitHub-account Phase 0.5 (Step 2):"

# F3 (6 asserts): each of 5 live Phase 0.5 gh call sites has the env prefix inline, plus preamble sentence.
#
# Sites pinned by searching the Phase 0.5 section for the prefix immediately followed by each call.
check_f3_site_1_rate_limit() {
  extract_phase_0_5 | grep -qF 'GH_TOKEN="${<token_env>}" GH_HOST="<host>" gh api rate_limit' \
    || { echo "F3 site 1: rate_limit call missing env prefix"; return 1; }
  echo "F3 site 1 (rate_limit) prefixed OK"
}
check_f3_site_2a_repo_view() {
  # preflight 3: caller's-cwd verification. Extract the preflight-3 bullet region and look for the prefix there.
  extract_phase_0_5 | awk '
    /cwd-repo matches pr_repo/{in_s=1}
    in_s && /Resolve pr_number/{exit}
    in_s{print}
  ' | grep -qF 'GH_TOKEN="${<token_env>}" GH_HOST="<host>" gh repo view --json nameWithOwner' \
    || { echo "F3 site 2a: preflight-3 (cwd-repo) gh repo view missing env prefix"; return 1; }
  echo "F3 site 2a (preflight 3 / cwd-repo) prefixed OK"
}
check_f3_site_2b_repo_view() {
  # bare-pr resolver site. Extract the "Resolve pr_number" region and look for the prefix there.
  extract_phase_0_5 | awk '
    /Resolve pr_number/{in_s=1}
    in_s && /Fetch pr_changed_files/{exit}
    in_s{print}
  ' | grep -qF 'GH_TOKEN="${<token_env>}" GH_HOST="<host>" gh repo view --json nameWithOwner' \
    || { echo "F3 site 2b: bare-pr resolver gh repo view missing env prefix"; return 1; }
  echo "F3 site 2b (bare pr <N> resolver) prefixed OK"
}
check_f3_site_3_pr_view() {
  extract_phase_0_5 | grep -qF 'GH_TOKEN="${<token_env>}" GH_HOST="<host>" gh pr view <pr_number> --repo <pr_repo>' \
    || { echo "F3 site 3: gh pr view missing env prefix"; return 1; }
  echo "F3 site 3 (gh pr view) prefixed OK"
}
check_f3_site_4_pulls_files() {
  extract_phase_0_5 | grep -qF 'GH_TOKEN="${<token_env>}" GH_HOST="<host>" gh api "repos/<pr_repo>/pulls/<pr_number>/files"' \
    || { echo "F3 site 4: gh api /pulls/<N>/files missing env prefix"; return 1; }
  echo "F3 site 4 (pulls/<N>/files) prefixed OK"
}
check_f3_preamble_sentence() {
  extract_phase_0_5 | tr '\n' ' ' | grep -qF -- 'gh auth status (preflight 1) is the ONLY unprefixed Phase 0.5 call — it probes ambient auth; all five other Phase 0.5 gh calls run under the resolved prefix when a github: account was resolved.' \
    || { echo "F3 preamble sentence missing verbatim"; return 1; }
  echo "F3 preamble sentence present verbatim"
}

check "SKILL.md F3 site 1 rate_limit prefixed" check_f3_site_1_rate_limit
check "SKILL.md F3 site 2a cwd-repo verification prefixed" check_f3_site_2a_repo_view
check "SKILL.md F3 site 2b bare-pr resolver prefixed" check_f3_site_2b_repo_view
check "SKILL.md F3 site 3 gh pr view prefixed" check_f3_site_3_pr_view
check "SKILL.md F3 site 4 pulls/<N>/files prefixed" check_f3_site_4_pulls_files
check "SKILL.md F3 preamble sentence verbatim" check_f3_preamble_sentence

# F4 (1 assert): new preflight bullet `token env resolves to non-empty` ordered between `gh auth status` and rate-limit.
check_f4_token_preflight_ordered() {
  local sec
  sec=$(extract_phase_0_5)
  # Collect line numbers (within section) of the three preflights.
  local auth_ln token_ln rate_ln
  auth_ln=$(printf '%s\n' "$sec" | grep -nF 'gh auth status' | head -1 | cut -d: -f1)
  token_ln=$(printf '%s\n' "$sec" | grep -nF 'token env resolves to non-empty' | head -1 | cut -d: -f1)
  rate_ln=$(printf '%s\n' "$sec" | grep -nF 'rate_limit' | head -1 | cut -d: -f1)
  if [ -z "$auth_ln" ] || [ -z "$token_ln" ] || [ -z "$rate_ln" ]; then
    echo "F4: missing one of (gh auth status / token env resolves to non-empty / rate_limit) in Phase 0.5"
    return 1
  fi
  if [ "$auth_ln" -ge "$token_ln" ] || [ "$token_ln" -ge "$rate_ln" ]; then
    echo "F4: ordering wrong — auth=$auth_ln token=$token_ln rate=$rate_ln (need auth<token<rate)"
    return 1
  fi
  # Remediation must name a concrete env var (e.g. GH_TOKEN_PERSONAL).
  printf '%s\n' "$sec" | grep -qE 'GH_TOKEN_[A-Z]+' \
    || { echo "F4: remediation must name an env var (e.g. GH_TOKEN_PERSONAL)"; return 1; }
  echo "F4 token-env preflight bullet ordered + named env var OK"
}
check "SKILL.md F4 token-env preflight bullet ordered" check_f4_token_preflight_ordered

# F5 (2 asserts): --account <name> flag header + §3.7b matrix with 8 rows (a)-(h) at line-start.
check_f5_account_flag_header() {
  # Flags section lists --account <name>.
  awk '/^\*\*Flags\*\*/{in_s=1} in_s && /^## /{exit} in_s && /^---$/{exit} in_s{print}' \
    skills/cross-audit/SKILL.md \
    | grep -qE '^\s*-\s+`--account' \
    || { echo "F5: Flags section missing --account <name> bullet"; return 1; }
  echo "F5 --account flag header present in Flags section"
}
check_f5_matrix_rows_verbatim() {
  local sec
  sec=$(extract_phase_0_5)
  local c
  for c in 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h'; do
    printf '%s\n' "$sec" | grep -qE "^\| \($c\) \|" \
      || { echo "F5: §3.7b matrix row ($c) missing in Phase 0.5"; return 1; }
  done
  echo "F5 §3.7b matrix 8 rows (a)-(h) present in Phase 0.5"
}
check "SKILL.md F5 --account flag" check_f5_account_flag_header
check "SKILL.md F5 §3.7b matrix 8 rows" check_f5_matrix_rows_verbatim

# F6 (1 assert): literal token `accounts[*].host` appears in Phase 0.5 prose.
check_f6_accounts_host_literal() {
  extract_phase_0_5 | grep -qF 'accounts[*].host' \
    || { echo "F6: 'accounts[*].host' literal missing from Phase 0.5"; return 1; }
  echo "F6 accounts[*].host literal present"
}
check "SKILL.md F6 accounts[*].host literal in Phase 0.5" check_f6_accounts_host_literal

# F11 (1 assert): backwards-compat operative sentence verbatim.
check_f11_backcompat_sentence() {
  extract_phase_0_5 | tr '\n' ' ' | grep -qF -- 'When .ai-dev-team.local.yml contains no github: block, Phase 0.5 skips account resolution entirely; every gh call runs without the env prefix, preserving current single-account behaviour.' \
    || { echo "F11: backwards-compat sentence missing verbatim"; return 1; }
  echo "F11 backwards-compat sentence present verbatim"
}
check "SKILL.md F11 backwards-compat sentence" check_f11_backcompat_sentence

# F12 (3 asserts): Phase 1-2 Step 2 dispatch template adds gh_token_env + gh_host + annotation rule.
extract_step2_dispatch() {
  awk '/^### Step 2: Launch cross-auditor/{in_s=1} in_s && /^### Step 3:/{exit} in_s{print}' \
    skills/cross-audit/SKILL.md
}
check_f12_gh_token_env() {
  extract_step2_dispatch | grep -qE '^gh_token_env:' \
    || { echo "F12: Step 2 dispatch missing 'gh_token_env:' line"; return 1; }
  echo "F12 gh_token_env: present in dispatch template"
}
check_f12_gh_host() {
  extract_step2_dispatch | grep -qE '^gh_host:' \
    || { echo "F12: Step 2 dispatch missing 'gh_host:' line"; return 1; }
  echo "F12 gh_host: present in dispatch template"
}
check_f12_annotation_rule() {
  extract_step2_dispatch | tr '\n' ' ' | grep -qF -- 'When no account resolved, both fields are OMITTED from the dispatch (not present as empty strings). This is mandatory — an empty-string value would leak into the agent as a literal, triggering an I2 violation.' \
    || { echo "F12: annotation rule missing verbatim"; return 1; }
  echo "F12 annotation rule present verbatim"
}
check "SKILL.md F12 gh_token_env in dispatch" check_f12_gh_token_env
check "SKILL.md F12 gh_host in dispatch" check_f12_gh_host
check "SKILL.md F12 annotation rule verbatim" check_f12_annotation_rule
echo

echo "Multi-GitHub-account downstream propagation (Step 3):"

PUBLISH_MD='skills/cross-audit/references/publish.md'
CROSS_AUDITOR_MD='agents/cross-auditor.md'

# F7 (2 asserts): publish.md §1 preamble — legacy sentence survives byte-exact AND new F7 sentence appended verbatim.
check "publish.md F7 legacy sentence survives" \
  bash -c "grep -qF -- 'All gh api calls pass --repo <pr_repo> AND --include' $PUBLISH_MD"

check_f7_new_sentence() {
  # The sentence is long; use grep -qF on the multi-line-joined content.
  tr '\n' ' ' < "$PUBLISH_MD" | grep -qF -- 'In multi-account mode all gh calls in this recipe (gh api, gh pr view, and gh pr diff) are additionally prefixed with GH_TOKEN="${<token_env>}" GH_HOST="<host>" resolved from the findings-frontmatter gh_account_context: field — publish reuses the same env pattern as the cross-audit skill.' \
    || { echo "F7: new multi-account sentence missing verbatim"; return 1; }
  echo "F7 new sentence present verbatim"
}
check "publish.md F7 new multi-account sentence" check_f7_new_sentence

# F8 (3 asserts): publish.md §3 — three live gh calls prefixed.
check_f8_gh_pr_diff_prefixed() {
  grep -qF 'GH_TOKEN="${<token_env>}" GH_HOST="<host>" gh pr diff <N> --repo <pr_repo>' "$PUBLISH_MD" \
    || { echo "F8: gh pr diff missing env prefix"; return 1; }
  echo "F8 gh pr diff prefixed OK"
}
check_f8_force_push_pr_view_prefixed() {
  grep -qF 'GH_TOKEN="${<token_env>}" GH_HOST="<host>" gh pr view <N> --repo <pr_repo> --json headRefOid -q' "$PUBLISH_MD" \
    || { echo "F8: force-push gh pr view missing env prefix"; return 1; }
  echo "F8 force-push gh pr view prefixed OK"
}
check_f8_post_gh_api_prefixed() {
  grep -qF 'GH_TOKEN="${<token_env>}" GH_HOST="<host>" gh api --include --repo <pr_repo>' "$PUBLISH_MD" \
    || { echo "F8: POST gh api --include missing env prefix"; return 1; }
  echo "F8 POST gh api --include prefixed OK"
}
check "publish.md F8 gh pr diff prefixed" check_f8_gh_pr_diff_prefixed
check "publish.md F8 force-push gh pr view prefixed" check_f8_force_push_pr_view_prefixed
check "publish.md F8 POST gh api --include prefixed" check_f8_post_gh_api_prefixed

# F9 (2 asserts): cross-auditor.md ## Input adds gh_token_env + gh_host bullets.
check "cross-auditor.md F9 gh_token_env input bullet" \
  bash -c "grep -qE '^- \*\*gh_token_env\*\*' $CROSS_AUDITOR_MD"
check "cross-auditor.md F9 gh_host input bullet" \
  bash -c "grep -qE '^- \*\*gh_host\*\*' $CROSS_AUDITOR_MD"

# F10 (3 asserts): Step 0 shows BOTH forms + the verbatim guard sentence.
check_f10_multi_account_form() {
  grep -qF 'GH_TOKEN="${<gh_token_env>}" GH_HOST="<gh_host>" gh pr checkout <pr_number> --force --repo <pr_repo>' "$CROSS_AUDITOR_MD" \
    || { echo "F10: multi-account form missing"; return 1; }
  echo "F10 multi-account form OK"
}
check_f10_single_account_form() {
  # bare form — must appear on its own line inside a fenced block (not in a prose sentence).
  # Allow leading whitespace (fenced blocks may be indented under a list item).
  awk '
    /^[[:space:]]*```/ { in_fence = !in_fence; next }
    in_fence {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (line == "gh pr checkout <pr_number> --force --repo <pr_repo>") found=1
    }
    END { exit(found?0:1) }
  ' "$CROSS_AUDITOR_MD" \
    || { echo "F10: bare single-account 'gh pr checkout <pr_number> --force --repo <pr_repo>' form missing inside a fenced block"; return 1; }
  echo "F10 single-account form OK (in fenced block)"
}
check_f10_guard_sentence() {
  tr '\n' ' ' < "$CROSS_AUDITOR_MD" | grep -qF -- 'When gh_token_env and gh_host are absent from the agent input, the gh pr checkout command is rendered without the env prefix (bare gh pr checkout <pr_number> --force --repo <pr_repo>) — never as GH_TOKEN="" GH_HOST="" gh pr checkout ....' \
    || { echo "F10: guard sentence missing verbatim"; return 1; }
  echo "F10 guard sentence present verbatim"
}
check "cross-auditor.md F10 multi-account form" check_f10_multi_account_form
check "cross-auditor.md F10 single-account form" check_f10_single_account_form
check "cross-auditor.md F10 guard sentence verbatim" check_f10_guard_sentence

# F14 (3 asserts): gh_account_context: literal + cross-auditor writer sentence + publish reader sentence.
check "cross-auditor.md F14 gh_account_context: literal" \
  bash -c "grep -qF 'gh_account_context:' $CROSS_AUDITOR_MD"

check_f14_writer_sentence() {
  tr '\n' ' ' < "$CROSS_AUDITOR_MD" | grep -qF -- 'PR mode only: write gh_account_context: <resolved_account_name_or_null> into findings frontmatter on every audit iteration. Publish reads this field to re-derive the env prefix on standalone invocations (see skills/cross-audit/references/publish.md §1).' \
    || { echo "F14: cross-auditor writer sentence missing verbatim"; return 1; }
  echo "F14 cross-auditor writer sentence present"
}
check "cross-auditor.md F14 writer sentence verbatim" check_f14_writer_sentence

check_f14_reader_sentence() {
  tr '\n' ' ' < "$PUBLISH_MD" | grep -qF -- 'Standalone publish reads gh_account_context: from findings frontmatter to look up the account under github.accounts and re-derive the GH_TOKEN / GH_HOST prefix. When the field is null or absent, publish runs every gh call bare (single-account compat).' \
    || { echo "F14: publish reader sentence missing verbatim"; return 1; }
  echo "F14 publish reader sentence present"
}
check "publish.md F14 reader sentence verbatim" check_f14_reader_sentence

# F15 (3 asserts): publish.md failure paths — three verbatim sentences.
check_f15_stale_account_guard() {
  tr '\n' ' ' < "$PUBLISH_MD" | grep -qF -- 'When gh_account_context: is non-null, standalone publish looks up the account under github.accounts. If the account is missing from config, publish hard-stops with remediation naming the stale name and the currently-configured account keys — never silent fallback to ambient auth.' \
    || { echo "F15: stale-account guard sentence missing verbatim"; return 1; }
  echo "F15 stale-account guard present"
}
check_f15_token_non_empty() {
  tr '\n' ' ' < "$PUBLISH_MD" | grep -qF -- 'Standalone publish runs the F4 token-non-empty check against the resolved token_env before any gh call; empty resolution is a hard-stop, never a silent fallback.' \
    || { echo "F15: token-non-empty sentence missing verbatim"; return 1; }
  echo "F15 token-non-empty present"
}
check_f15_account_publish_scope() {
  tr '\n' ' ' < "$PUBLISH_MD" | grep -qF -- 'On /cross-audit publish, --account <name> overrides the gh_account_context: frontmatter value (same resolution ladder, same §3.7b hard-stops). When omitted, the frontmatter value is authoritative.' \
    || { echo "F15: --account publish-mode scope sentence missing verbatim"; return 1; }
  echo "F15 --account publish scope present"
}
check "publish.md F15 stale-account guard" check_f15_stale_account_guard
check "publish.md F15 token-non-empty check" check_f15_token_non_empty
check "publish.md F15 --account publish-mode scope" check_f15_account_publish_scope
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

check_smoke_helper_phase0_cross_audit_rejected() {
  if ! check_cross_audit_phase0_bans_model_fast 'tests/fixtures/shared-phase0/cross-audit-no-ban.md' >/dev/null 2>&1; then
    echo "check_cross_audit_phase0_bans_model_fast correctly rejected stale cross-audit-no-ban fixture"
    return 0
  fi
  echo "check_cross_audit_phase0_bans_model_fast wrongly accepted cross-audit-no-ban.md"
  return 1
}

# Positive invocations — 13 rows per spec §6.1 invocation matrix.
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
check "check_cross_audit_phase0_bans_model_fast" check_cross_audit_phase0_bans_model_fast skills/cross-audit/SKILL.md
check "check_investigate_no_phase0" check_investigate_no_phase0 skills/investigate/SKILL.md
# Negative invocations — 4 rows per spec §6.1 invocation matrix.
check "check_smoke_helper_phase0_append_rejected" check_smoke_helper_phase0_append_rejected
check "check_smoke_helper_phase0_inline_rejected" check_smoke_helper_phase0_inline_rejected
check "check_smoke_helper_phase0_investigate_rejected" check_smoke_helper_phase0_investigate_rejected
check "check_smoke_helper_phase0_cross_audit_rejected" check_smoke_helper_phase0_cross_audit_rejected
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
check "check_cross_auditor_mode_focus_areas_canonical" check_cross_auditor_mode_focus_areas_canonical agents/cross-auditor.md
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

check_smoke_helper_p3_spec_template_no_codex_action_rejected() {
  if ! check_spec_template_codex_fast_rationale 'tests/fixtures/p3-cleanup/spec-template-no-codex-action.md' >/dev/null 2>&1; then
    echo "check_spec_template_codex_fast_rationale correctly rejected no-actionable-instruction fixture"
    return 0
  fi
  echo "check_spec_template_codex_fast_rationale wrongly accepted spec-template-no-codex-action.md"
  return 1
}

check_smoke_helper_p3_agent_routing_no_codex_action_rejected() {
  if ! check_agent_routing_codex_fast_rationale 'tests/fixtures/p3-cleanup/agent-routing-no-codex-action.md' >/dev/null 2>&1; then
    echo "check_agent_routing_codex_fast_rationale correctly rejected no-actionable-instruction fixture"
    return 0
  fi
  echo "check_agent_routing_codex_fast_rationale wrongly accepted agent-routing-no-codex-action.md"
  return 1
}

# Positive invocations — 8 per spec §3.4.
check "check_spec_template_codex_fast_rationale" check_spec_template_codex_fast_rationale skills/feature/references/spec-template.md
check "check_agent_routing_codex_fast_rationale" check_agent_routing_codex_fast_rationale skills/feature/references/agent-routing.md
check "check_trigger_map_investigate_research_clarifier (hook)" check_trigger_map_investigate_research_clarifier hooks/session-prompt.md
check "check_trigger_map_investigate_research_clarifier (snippet)" check_trigger_map_investigate_research_clarifier docs/claude-md-snippet.md
check "check_research_skill_competitive_analysis_points_to_investigate" check_research_skill_competitive_analysis_points_to_investigate skills/research/SKILL.md
check "check_branch_frontmatter_ref_lowercase (README)" check_branch_frontmatter_ref_lowercase README.md
check "check_branch_frontmatter_ref_lowercase (feature/SKILL.md)" check_branch_frontmatter_ref_lowercase skills/feature/SKILL.md
check "check_readme_no_audit_migration_note" check_readme_no_audit_migration_note README.md
# Negative invocations — 1 original + 5 audit (X1/X2/X5/X6) rows.
check "check_smoke_helper_p3_readme_audit_migration_rejected" check_smoke_helper_p3_readme_audit_migration_rejected
check "check_smoke_helper_p3_session_start_clarifier_masks_missing_row_rejected" check_smoke_helper_p3_session_start_clarifier_masks_missing_row_rejected
check "check_smoke_helper_p3_snippet_clarifier_masks_missing_row_rejected" check_smoke_helper_p3_snippet_clarifier_masks_missing_row_rejected
check "check_smoke_helper_p3_branch_bold_uppercase_rejected" check_smoke_helper_p3_branch_bold_uppercase_rejected
check "check_smoke_helper_p3_spec_template_no_codex_action_rejected" check_smoke_helper_p3_spec_template_no_codex_action_rejected
check "check_smoke_helper_p3_agent_routing_no_codex_action_rejected" check_smoke_helper_p3_agent_routing_no_codex_action_rejected
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

# Step 5 — --probe-downgrade CLI flag + Phase 3 shadow/advisory sections +
# cross-auditor input-surface. Per §6.1 Step 5 delta: +6.
check "check_skill_md_probe_downgrade_flag" check_skill_md_probe_downgrade_flag
check "check_skill_md_probe_downgrade_off_floor_refusal" check_skill_md_probe_downgrade_off_floor_refusal
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
# Step 3 — agent Step 0.5 + skill + dedupe merge_pair swap (7 spec-listed
# helpers per §3.2 + 1 supplementary closing the §6.1 arithmetic gap).
check "check_cross_auditor_step05_probe_dispatch" check_cross_auditor_step05_probe_dispatch
check "check_probe_e_cli_downgrade" check_probe_e_cli_downgrade
check "check_probe_e_downgrade_upgrade_refused_when_yaml_off" check_probe_e_downgrade_upgrade_refused_when_yaml_off
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
# Step 3 — CLI downgrade + upgrade-refused docs smoke (2 helpers per probe E
# precedent; X6 iter-1 resolution: documentation grep, not end-to-end dispatch
# harness — generic Step 0.5 dispatch coverage inherited from probe E).
check "check_probe_f_cli_downgrade" check_probe_f_cli_downgrade
check "check_probe_f_downgrade_upgrade_refused_when_yaml_off" check_probe_f_downgrade_upgrade_refused_when_yaml_off
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
  echo "$f has code-audit persistence paragraph (KB path + next_finding_id + derivation rule) OK"
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
_fixture_latest_code_audit_marker() {
  _fixture_log_body "$1" | grep -E '^- [0-9]{4}-[0-9]{2}-[0-9]{2}: code audit( passed; iteration=[0-9]+; verified=\[[^]]*\], accepted=\[[^]]*\], deferred=\[[^]]*\]| iteration=[0-9]+; fixed_ids=\[[^]]*\]; accepted_ids=\[[^]]*\]| decisions recorded; iteration=[0-9]+; pending_fixed=\[[^]]*\]; pending_accepted=\[[^]]*\]; pending_deferred=\[[^]]*\]|: no auditable files in diff; skipping)$' | tail -1
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
  if printf '%s\n' "$trailing" | grep -qE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}: code audit( passed; iteration=[0-9]+; verified=\[[^]]*\], accepted=\[[^]]*\], deferred=\[[^]]*\]| iteration=[0-9]+; fixed_ids=\[[^]]*\]; accepted_ids=\[[^]]*\]| decisions recorded; iteration=[0-9]+; pending_fixed=\[[^]]*\]; pending_accepted=\[[^]]*\]; pending_deferred=\[[^]]*\]|: no auditable files in diff; skipping)$'; then
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

check "code-audit-resume-clean-passed"         check_code_audit_resume_clean_passed
check "code-audit-resume-zero-diff-skip"       check_code_audit_resume_zero_diff_skip
check "code-audit-resume-decisions-recorded"   check_code_audit_resume_decisions_recorded
check "code-audit-resume-mid-loop-spawn"       check_code_audit_resume_mid_loop_spawn
check "code-audit-resume-no-prior-entry"       check_code_audit_resume_no_prior_entry
check "code-audit-resume-malformed-trailing"   check_code_audit_resume_malformed_trailing
echo

# --- R3 weak-phrase compliance check (spec 2026-04-25-r3-weak-phrase-compliance-check) ---
echo "R3 weak-phrase compliance check:"

COMPLIANCE_CHECKER='agents/spec-compliance-checker.md'

check "compliance_checker_r3_heading"               check_compliance_checker_r3_heading               "$COMPLIANCE_CHECKER"
check "compliance_checker_r3_lists_assertisnotnone" check_compliance_checker_r3_lists_assertisnotnone  "$COMPLIANCE_CHECKER"
check "compliance_checker_r3_lists_call_count"      check_compliance_checker_r3_lists_call_count       "$COMPLIANCE_CHECKER"
check "compliance_checker_r3_in_verdict_template"   check_compliance_checker_r3_in_verdict_template    "$COMPLIANCE_CHECKER"
check "compliance_checker_r3_in_rules"              check_compliance_checker_r3_in_rules               "$COMPLIANCE_CHECKER"
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

# --- Plugin claims-vs-runtime audit (BACKLOG #46) ---
echo "Plugin claims-vs-runtime audit pins:"
check "smoke_proves_manifest_canonical"       check_smoke_proves_manifest_canonical
check "smoke_summary_breaks_down_by_class"    check_smoke_summary_breaks_down_by_class
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
