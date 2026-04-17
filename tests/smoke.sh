#!/usr/bin/env bash
# smoke.sh — plugin smoke test. Runs locally, no network, no Claude.
# Exits 0 if all checks pass, non-zero on first failure category.
#
# Usage: bash tests/smoke.sh
set -u

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PLUGIN_ROOT" || exit 2

PASS=0
FAIL=0
FAILURES=()

check() {
  local name="$1"; shift
  if "$@" >/tmp/smoke-out.$$ 2>&1; then
    echo "  PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name"
    FAILURES+=("$name")
    sed 's/^/        /' /tmp/smoke-out.$$
    FAIL=$((FAIL + 1))
  fi
  rm -f /tmp/smoke-out.$$
}

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

check "shared reference exists" check_dev_workflow_exists
for agent in agents/developer-codex.md agents/developer-senior.md agents/developer-middle.md; do
  check "agent links shared workflow: $agent" check_agent_refs_dev_workflow "$agent"
done
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

check_skill_last_agent() {
  grep -q 'last_agent=' skills/feature/SKILL.md \
    || { echo "SKILL.md missing last_agent Log convention"; return 1; }
  echo "SKILL.md documents last_agent Log convention"
}

check "SKILL.md mentions BLOCKED"           check_skill_blocked
check "SKILL.md has /feature discard mode"  check_skill_discard_mode
check "SKILL.md documents last_agent"       check_skill_last_agent
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
  # Feature skill prompts the user to save config after legacy discovery
  grep -q "Save .*kb_path.*\\.ai-dev-team\\.yml" skills/feature/SKILL.md \
    || { echo "feature SKILL.md missing autogen prompt"; return 1; }
  echo "feature SKILL.md has autogen prompt"
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

# 10. cross-auditor.md: within 10 lines of `mcp__codex__codex` token, contains `cwd` AND `worktree`.
check_cross_auditor_codex_cwd_proximity() {
  python3 - <<'PY'
import re, sys
lines = open('agents/cross-auditor.md').read().splitlines()
ok = False
for i, line in enumerate(lines):
    if 'mcp__codex__codex' in line:
        window = '\n'.join(lines[i:i+11])
        if 'cwd' in window and 'worktree' in window:
            ok = True
            break
if not ok:
    print("cross-auditor.md: no 'mcp__codex__codex' occurrence has both 'cwd' and 'worktree' within 10 lines")
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

# 12. hooks/session-start AND docs/claude-md-snippet.md both mention `publish|fix|accept|defer`
check_hooks_docs_phase3_exemption() {
  grep -q 'publish|fix|accept|defer' hooks/session-start \
    || { echo "hooks/session-start missing Phase 3 exemption clause (publish|fix|accept|defer)"; return 1; }
  grep -q 'publish|fix|accept|defer' docs/claude-md-snippet.md \
    || { echo "docs/claude-md-snippet.md missing Phase 3 exemption clause (publish|fix|accept|defer)"; return 1; }
  grep -q 'pass-through' hooks/session-start \
    || { echo "hooks/session-start missing 'pass-through' exemption wording"; return 1; }
  grep -q 'pass-through' docs/claude-md-snippet.md \
    || { echo "docs/claude-md-snippet.md missing 'pass-through' exemption wording"; return 1; }
  echo "hooks/docs exempt Phase 3 decision keywords"
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

# (b) feature SKILL.md must have exactly 15 AWAITING banner lines.
check_feature_awaiting_count_15() {
  local n
  n=$(grep -c "^## ⏸ AWAITING YOUR INPUT$" skills/feature/SKILL.md)
  if [ "$n" != "15" ]; then
    echo "feature AWAITING count=$n expected 15"
    return 1
  fi
  echo "feature AWAITING count=15 OK"
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
  if ! grep -qF "Verify passed. Moving to hand-off." skills/feature/SKILL.md; then
    echo "post-verify canonical replacement sentence missing in feature SKILL.md"
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

# (r) ruler-prefix count matches total banner count (expected 22 once all steps done).
check_awaiting_ruler_prefix_count_matches() {
  local c
  c=$(awk '
    BEGIN { c = 0; prev = "" }
    ($0 == "## ⏸ AWAITING YOUR INPUT" || $0 == "## ⏸ APPROVAL REQUIRED") && prev == "---" { c++ }
    { prev = $0 }
    END { print c }
  ' skills/*/SKILL.md)
  if [ "$c" != "22" ]; then
    echo "ruler-prefix count=$c expected 22"
    return 1
  fi
  echo "ruler-prefix count=22 OK"
}

# (s) each banner has trailing bold question within 15 lines (expected 22 satisfied).
check_banner_trailing_bold_present_each() {
  local c
  c=$(awk '
    BEGIN { satisfied = 0; inside = 0; countdown = 0 }
    /^## ⏸ (AWAITING YOUR INPUT|APPROVAL REQUIRED)$/ { inside = 1; countdown = 15; next }
    inside && /^## / { inside = 0; countdown = 0; next }
    inside && countdown > 0 && /\*\*[^*]+\?\*\*/ { satisfied++; inside = 0; countdown = 0; next }
    inside { countdown--; if (countdown <= 0) inside = 0 }
    END { print satisfied }
  ' skills/*/SKILL.md)
  if [ "$c" != "22" ]; then
    echo "trailing-bold-present-each count=$c expected 22"
    return 1
  fi
  echo "trailing-bold-present-each=22 OK"
}

check "banner-convention-doc-valid"             check_banner_convention_doc_valid
check "feature-AWAITING-count-15"               check_feature_awaiting_count_15
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


echo
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [ "$FAIL" -ne 0 ]; then
  echo "Failures:"
  for f in "${FAILURES[@]}"; do
    echo "  - $f"
  done
  exit 1
fi
exit 0
