#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*"; }

echo ""
echo "AI Dev Team — installer"
echo "========================"
echo ""

# ── Prerequisites ─────────────────────────────────────────────────────────────
if ! command -v claude &>/dev/null; then
  err "Claude Code CLI not found. Install from https://claude.ai/code"
  exit 1
fi

CLAUDE_VERSION=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "0.0.0")
REQUIRED="2.1.32"
if [ "$(printf '%s\n' "$REQUIRED" "$CLAUDE_VERSION" | sort -V | head -1)" != "$REQUIRED" ]; then
  warn "Claude Code $CLAUDE_VERSION detected; $REQUIRED+ recommended for agent teams."
fi

# ── Create dirs ────────────────────────────────────────────────────────────────
mkdir -p "$CLAUDE_DIR/agents"
mkdir -p "$CLAUDE_DIR/skills/feature/references"
mkdir -p "$CLAUDE_DIR/skills/cross-audit"
mkdir -p "$CLAUDE_DIR/skills/investigate/references"
mkdir -p "$CLAUDE_DIR/skills/audit"

# ── Install agents ─────────────────────────────────────────────────────────────
echo "Installing agents..."
for f in "$REPO_DIR"/agents/*.md; do
  name="$(basename "$f")"
  dest="$CLAUDE_DIR/agents/$name"
  if [ -f "$dest" ]; then
    warn "  $name already exists — overwriting"
  fi
  cp "$f" "$dest"
  ok "  agents/$name"
done

# ── Install skills ─────────────────────────────────────────────────────────────
echo ""
echo "Installing skills..."

cp "$REPO_DIR/skills/feature/SKILL.md"                          "$CLAUDE_DIR/skills/feature/SKILL.md"
cp "$REPO_DIR/skills/feature/references/spec-template.md"       "$CLAUDE_DIR/skills/feature/references/spec-template.md"
cp "$REPO_DIR/skills/feature/references/codex-implement.md"     "$CLAUDE_DIR/skills/feature/references/codex-implement.md"
ok "  skills/feature"

cp "$REPO_DIR/skills/cross-audit/SKILL.md"                      "$CLAUDE_DIR/skills/cross-audit/SKILL.md"
ok "  skills/cross-audit"

cp "$REPO_DIR/skills/investigate/SKILL.md"                      "$CLAUDE_DIR/skills/investigate/SKILL.md"
cp "$REPO_DIR/skills/investigate/references/codex-debate-profile.md" \
                                                                 "$CLAUDE_DIR/skills/investigate/references/codex-debate-profile.md"
ok "  skills/investigate"

cp "$REPO_DIR/skills/audit/SKILL.md"                            "$CLAUDE_DIR/skills/audit/SKILL.md"
ok "  skills/audit"

# ── Settings: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS ────────────────────────────
echo ""
echo "Checking settings..."

SETTINGS="$CLAUDE_DIR/settings.json"
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

if python3 -c "import json,sys; d=json.load(open('$SETTINGS')); sys.exit(0 if d.get('env',{}).get('CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS')=='1' else 1)" 2>/dev/null; then
  ok "  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS already set"
else
  python3 - "$SETTINGS" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    d = json.load(f)
d.setdefault('env', {})['CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'] = '1'
with open(path, 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
PYEOF
  ok "  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 added to $SETTINGS"
fi

# ── Codex MCP ─────────────────────────────────────────────────────────────────
echo ""
if python3 -c "import json,sys; d=json.load(open('$SETTINGS')); sys.exit(0 if any('codex' in k.lower() for k in d.get('mcpServers',{}).keys()) else 1)" 2>/dev/null; then
  ok "  Codex MCP already registered"
else
  if command -v codex &>/dev/null; then
    echo "  Registering Codex MCP server..."
    claude mcp add codex -s user -- codex mcp-server
    ok "  Codex MCP registered"
  else
    warn "  codex CLI not found — skipping MCP registration"
    echo "    Install codex, then run:"
    echo "    claude mcp add codex -s user -- codex mcp-server"
  fi
fi

# ── CLAUDE.md snippet ─────────────────────────────────────────────────────────
echo ""
echo "Project CLAUDE.md setup..."

SNIPPET_FILE="$REPO_DIR/docs/claude-md-snippet.md"
# Extract just the markdown block between the backtick fences
SNIPPET=$(awk '/^```markdown$/{found=1; next} found && /^```$/{exit} found{print}' "$SNIPPET_FILE")

PROJECT_CLAUDE_MD="$(pwd)/CLAUDE.md"

if [ -f "$PROJECT_CLAUDE_MD" ]; then
  if grep -q "ai-dev-team" "$PROJECT_CLAUDE_MD" 2>/dev/null; then
    ok "  CLAUDE.md already contains ai-dev-team workflow section"
  else
    echo ""
    echo "  Found CLAUDE.md at: $PROJECT_CLAUDE_MD"
    printf "  Add ai-dev-team workflow section to it? [y/N] "
    read -r answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      printf '\n\n%s\n' "$SNIPPET" >> "$PROJECT_CLAUDE_MD"
      ok "  Workflow section appended to CLAUDE.md"
    else
      warn "  Skipped. Add manually from: docs/claude-md-snippet.md"
    fi
  fi
else
  echo ""
  echo "  No CLAUDE.md found in current directory ($(pwd))"
  printf "  Create one with the ai-dev-team workflow section? [y/N] "
  read -r answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    printf '%s\n' "$SNIPPET" > "$PROJECT_CLAUDE_MD"
    ok "  CLAUDE.md created with workflow section"
  else
    warn "  Skipped. See docs/claude-md-snippet.md to add manually."
  fi
fi

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "Installation complete. Restart Claude Code to pick up changes."
echo ""
echo "Quick start — add to your project's CLAUDE.md (see docs/claude-md-snippet.md)"
echo "then just describe what you want:"
echo "  'add retry logic'         → Claude invokes /feature new"
echo "  'continue'                → Claude invokes /feature continue"
echo "  'audit the auth module'   → Claude invokes /cross-audit"
echo "  'should we use X or Y?'  → Claude invokes /investigate"
echo ""
echo "Or use slash commands directly:"
echo "  /feature new <description>"
echo "  /cross-audit <scope>"
echo "  /investigate <question>"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
