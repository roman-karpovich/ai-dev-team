#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$SCRIPT_DIR/repo"

if [ -d "$REPO/.git" ]; then
  exit 0
fi

mkdir -p "$REPO"
cd "$REPO"

git init -q
git config user.email test@example.com
git config user.name Test

printf 'v0.1\n' > foo.txt
git add foo.txt
git commit -q -m 'fixture v0.1'
git tag v0.1

printf 'v0.2\n' > foo.txt
git add foo.txt
git commit -q -m 'fixture v0.2'
git tag v0.2
