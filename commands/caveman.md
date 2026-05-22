---
name: caveman
description: Toggle / inspect caveman compression mode for the current project (on by default; persists per project via a flag file under ~/.claude/ai-dev-team/caveman/).
argument-hint: "<on|off|status>"
---

# /caveman — toggle compression mode for the current project

Caveman is on by default. Suspend per-project with `/caveman off`. Re-enable
with `/caveman on`. Inspect current state with `/caveman status`.

The command shares its flag-path resolver with the SessionStart hook by
sourcing `hooks/lib/caveman_paths.sh` and calling the resolver function
`caveman_flag_path` — no hardcoded paths, no drift between command and hook.

Run the subcommand matching the user's first argument.

## /caveman on

Re-enable caveman compression for the current project by deleting the
project-scoped flag file. Idempotent — succeeds when the flag is already
absent.

```bash
# Locate the plugin install via Claude Code's plugin manifest. CLAUDE_PLUGIN_ROOT
# is not reliably exported to slash-command bash subprocesses, so we resolve via
# ~/.claude/plugins/installed_plugins.json instead. Scoped to a known plugin key
# (`ai-dev-team@ai-dev-team`) — no git-root fallback, no pwd fallback, defeats
# X6 target-repo-shadowing class without requiring the env var.
plugin_root=$(python3 - <<'PY' 2>/dev/null
import json, os, sys
manifest = os.path.expanduser("~/.claude/plugins/installed_plugins.json")
try:
    with open(manifest) as f:
        d = json.load(f)
    for e in d.get("plugins", {}).get("ai-dev-team@ai-dev-team", []):
        path = e.get("installPath")
        if path and os.path.isfile(os.path.join(path, "hooks/lib/caveman_paths.sh")):
            print(path); sys.exit(0)
    sys.exit(1)
except Exception:
    sys.exit(1)
PY
)
if [ -z "$plugin_root" ]; then
  echo "caveman: could not locate plugin install (looked up ai-dev-team@ai-dev-team in ~/.claude/plugins/installed_plugins.json)" >&2
  exit 1
fi
. "$plugin_root/hooks/lib/caveman_paths.sh"

flag=$(caveman_flag_path)
rm -f "$flag"
echo "caveman: ACTIVE (flag deleted: $flag)"
```

## /caveman off

Suspend caveman compression for the current project by writing a metadata
flag file. The parent directory is created with `mkdir -p` if absent. The
flag file is small YAML with five fields: `repo`, `plugin`, `mode`,
`created_at`, `updated_at`.

```bash
# Locate the plugin install via Claude Code's plugin manifest. CLAUDE_PLUGIN_ROOT
# is not reliably exported to slash-command bash subprocesses, so we resolve via
# ~/.claude/plugins/installed_plugins.json instead. Scoped to a known plugin key
# (`ai-dev-team@ai-dev-team`) — no git-root fallback, no pwd fallback, defeats
# X6 target-repo-shadowing class without requiring the env var.
plugin_root=$(python3 - <<'PY' 2>/dev/null
import json, os, sys
manifest = os.path.expanduser("~/.claude/plugins/installed_plugins.json")
try:
    with open(manifest) as f:
        d = json.load(f)
    for e in d.get("plugins", {}).get("ai-dev-team@ai-dev-team", []):
        path = e.get("installPath")
        if path and os.path.isfile(os.path.join(path, "hooks/lib/caveman_paths.sh")):
            print(path); sys.exit(0)
    sys.exit(1)
except Exception:
    sys.exit(1)
PY
)
if [ -z "$plugin_root" ]; then
  echo "caveman: could not locate plugin install (looked up ai-dev-team@ai-dev-team in ~/.claude/plugins/installed_plugins.json)" >&2
  exit 1
fi
. "$plugin_root/hooks/lib/caveman_paths.sh"

flag=$(caveman_flag_path)
mkdir -p "$(dirname "$flag")"

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)
now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Preserve the original created_at if the flag already exists.
created_at="$now"
if [ -f "$flag" ]; then
  prior=$(grep -E '^created_at:' "$flag" | head -n 1 | sed -E 's/^created_at:[[:space:]]*//')
  if [ -n "$prior" ]; then
    created_at="$prior"
  fi
fi

cat > "$flag" <<YAML
repo: $repo_root
plugin: ai-dev-team
mode: suspended
created_at: $created_at
updated_at: $now
YAML

echo "caveman: SUSPENDED (flag written: $flag)"
```

## /caveman status

Report whether caveman is active or suspended for the current project, the
resolved flag path, and the project hash. The branch uses a conditional
`[ -f "$flag" ]` flag-presence check to decide the report.

```bash
# Locate the plugin install via Claude Code's plugin manifest. CLAUDE_PLUGIN_ROOT
# is not reliably exported to slash-command bash subprocesses, so we resolve via
# ~/.claude/plugins/installed_plugins.json instead. Scoped to a known plugin key
# (`ai-dev-team@ai-dev-team`) — no git-root fallback, no pwd fallback, defeats
# X6 target-repo-shadowing class without requiring the env var.
plugin_root=$(python3 - <<'PY' 2>/dev/null
import json, os, sys
manifest = os.path.expanduser("~/.claude/plugins/installed_plugins.json")
try:
    with open(manifest) as f:
        d = json.load(f)
    for e in d.get("plugins", {}).get("ai-dev-team@ai-dev-team", []):
        path = e.get("installPath")
        if path and os.path.isfile(os.path.join(path, "hooks/lib/caveman_paths.sh")):
            print(path); sys.exit(0)
    sys.exit(1)
except Exception:
    sys.exit(1)
PY
)
if [ -z "$plugin_root" ]; then
  echo "caveman: could not locate plugin install (looked up ai-dev-team@ai-dev-team in ~/.claude/plugins/installed_plugins.json)" >&2
  exit 1
fi
. "$plugin_root/hooks/lib/caveman_paths.sh"

flag=$(caveman_flag_path)
hash=$(basename "$flag" .flag)

if [ -f "$flag" ]; then
  echo "caveman: SUSPENDED for ad-hoc and /research sessions"
  echo "  scope: /feature, /cross-audit, /investigate flows still apply compression (flag override)"
  echo "  flag : $flag"
  echo "  hash : $hash"
  echo "  meta :"
  sed 's/^/    /' "$flag"
else
  echo "caveman: ACTIVE (project default — no flag file present)"
  echo "  scope: /feature, /cross-audit, /investigate flows ALWAYS apply compression"
  echo "  scope: /research and ad-hoc sessions honor this flag"
  echo "  flag : $flag"
  echo "  hash : $hash"
fi
```
