#!/usr/bin/env bash
# caveman_paths.sh — shared project-hash + flag-path resolver for the caveman
# compression skill. Sourced by hooks/session-start and commands/caveman.md.
#
# Public surface:
#   caveman_flag_path [PATH]
#     With PATH: hash the realpath of PATH and emit the flag path.
#     Without PATH: resolve the project root by the order
#         git root  →  ancestor containing .ai-dev-team.yml  →  realpath $PWD
#       then hash that resolved root.
#     Output: $HOME/.claude/ai-dev-team/caveman/<16-hex-SHA-256-prefix>.flag
#
# Hash construction: first 16 hex chars of SHA-256 of the path bytes
# (no trailing newline, via `printf %s`).
#
# Sourcing this file MUST be silent (no stdout/stderr) and have no side
# effects beyond defining functions.

# Realpath helper — portable across macOS / Linux. Falls back through
# realpath(1), python3, then cd+pwd -P.
_caveman_realpath() {
    local target="$1"
    if [ -z "$target" ]; then
        return 1
    fi
    if command -v realpath >/dev/null 2>&1; then
        realpath "$target" 2>/dev/null && return 0
    fi
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$target" 2>/dev/null && return 0
    fi
    if [ -d "$target" ]; then
        ( cd "$target" 2>/dev/null && pwd -P ) && return 0
    fi
    # Last resort — strip trailing slash, echo as-is.
    printf '%s\n' "${target%/}"
}

# Resolve the project root for the current working directory using the
# spec resolver order. Emits the resolved realpath on stdout.
_caveman_resolve_project_root() {
    # 1. git rev-parse --show-toplevel (already realpath on most systems,
    #    but normalize through realpath helper for safety).
    local git_root
    if command -v git >/dev/null 2>&1; then
        git_root=$(git rev-parse --show-toplevel 2>/dev/null)
        if [ -n "$git_root" ]; then
            _caveman_realpath "$git_root"
            return 0
        fi
    fi

    # 2. Walk ancestors looking for .ai-dev-team.yml.
    local d
    d=$(pwd -P 2>/dev/null) || d="$PWD"
    while [ -n "$d" ] && [ "$d" != "/" ]; do
        if [ -f "$d/.ai-dev-team.yml" ]; then
            _caveman_realpath "$d"
            return 0
        fi
        d=$(dirname "$d")
    done

    # 3. Fall back to realpath $PWD.
    _caveman_realpath "$PWD"
}

# Hash a path's bytes via SHA-256 first 16 hex chars (no trailing newline
# in the hash input). Works with shasum or sha256sum.
_caveman_hash_path() {
    local p="$1"
    if command -v shasum >/dev/null 2>&1; then
        printf %s "$p" | shasum -a 256 | head -c 16
    elif command -v sha256sum >/dev/null 2>&1; then
        printf %s "$p" | sha256sum | head -c 16
    else
        return 1
    fi
}

caveman_flag_path() {
    local input root hash
    if [ "$#" -ge 1 ] && [ -n "$1" ]; then
        input="$1"
        # With-arg: hash the realpath of the supplied path. If the path
        # cannot be realpath'd (e.g. nonexistent), fall back to hashing
        # the input bytes as-given.
        root=$(_caveman_realpath "$input" 2>/dev/null)
        if [ -z "$root" ]; then
            root="$input"
        fi
    else
        root=$(_caveman_resolve_project_root)
    fi
    hash=$(_caveman_hash_path "$root") || return 1
    printf '%s/.claude/ai-dev-team/caveman/%s.flag\n' "$HOME" "$hash"
}
