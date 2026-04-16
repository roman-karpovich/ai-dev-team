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
