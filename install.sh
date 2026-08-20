#!/bin/sh
# Install Hyvä knowledge skills into an AI coding agent's skills directory.
#
# Usage:
#   ./install.sh                      # auto-detect agent, install all skills
#   ./install.sh claude               # install all skills for Claude Code
#   ./install.sh antigravity --global # install globally instead of per-project
#   ./install.sh codex hyva-checkout alpinejs-csp
#   ./install.sh --list
#
# Run it from the project you want the skills in.
#
# ponytail: symlink by default so `git pull` updates every install; --copy for containers.

set -e

RED=$(printf '\033[0;31m'); GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[0;33m'); BLUE=$(printf '\033[0;34m'); NC=$(printf '\033[0m')
ok()   { printf '%s[OK]%s %s\n'    "$GREEN"  "$NC" "$1"; }
warn() { printf '%s[WARN]%s %s\n'  "$YELLOW" "$NC" "$1"; }
err()  { printf '%s[ERROR]%s %s\n' "$RED"    "$NC" "$1" >&2; }
info() { printf '%s[INFO]%s %s\n'  "$BLUE"   "$NC" "$1"; }

REPO_ROOT="$(cd "$(dirname "$0")" && pwd -P)"
SKILLS_SRC="$REPO_ROOT/skills"

MODE=symlink
SCOPE=project
AGENT=""
WANTED=""

# Project-level skills directory per agent.
agent_project_dir() {
    case "$1" in
        claude)      echo ".claude/skills" ;;
        antigravity) echo ".agents/skills" ;;   # legacy: .agent/skills
        codex)       echo ".codex/skills" ;;
        cursor)      echo ".cursor/skills" ;;
        copilot)     echo ".github/skills" ;;
        gemini)      echo ".gemini/skills" ;;
        opencode)    echo ".opencode/skills" ;;
        *) return 1 ;;
    esac
}

# Global skills directory per agent. Empty = agent has no documented global dir.
agent_global_dir() {
    case "$1" in
        claude)      echo "$HOME/.claude/skills" ;;
        antigravity) echo "$HOME/.gemini/config/skills" ;;
        codex)       echo "$HOME/.codex/skills" ;;
        *)           echo "" ;;
    esac
}

AGENTS="claude antigravity codex cursor copilot gemini opencode"

usage() {
    echo "Usage: $(basename "$0") [--copy] [--global] [agent] [skill ...]"
    echo
    echo "  agent    one of: $AGENTS  (auto-detected if omitted)"
    echo "  skill    skill name(s); all skills if omitted"
    echo
    echo "  --copy    copy instead of symlink (for containers / no-symlink filesystems)"
    echo "  --global  install to the agent's global dir instead of this project"
    echo "  --list    list available skills and exit"
}

list_skills() {
    echo "Available skills:"
    for p in "$SKILLS_SRC"/*/; do
        [ -d "$p" ] || continue
        n=$(basename "$p")
        l=$(find "$p" -name '*.md' -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
        printf '  %-18s %s lines\n' "$n" "$l"
    done
}

for arg in "$@"; do
    case "$arg" in
        --copy)   MODE=copy ;;
        --global) SCOPE=global ;;
        --list)   list_skills; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        -*) err "Unknown option: $arg"; usage; exit 1 ;;
        *)
            if [ -z "$AGENT" ] && agent_project_dir "$arg" >/dev/null 2>&1; then
                AGENT="$arg"
            else
                WANTED="$WANTED $arg"
            fi
            ;;
    esac
done

# Auto-detect the agent from an existing dot-directory in the current project.
if [ -z "$AGENT" ]; then
    for a in $AGENTS; do
        d=$(agent_project_dir "$a")
        parent=$(dirname "$d")
        if [ -d "./$parent" ]; then AGENT="$a"; info "Detected $a (./$parent exists)"; break; fi
    done
fi

if [ -z "$AGENT" ]; then
    err "Could not detect an agent. Pass one explicitly:"
    err "  ./install.sh claude"
    err "Supported: $AGENTS"
    exit 1
fi

if [ "$SCOPE" = global ]; then
    TARGET=$(agent_global_dir "$AGENT")
    if [ -z "$TARGET" ]; then
        err "$AGENT has no documented global skills directory; install per-project instead."
        exit 1
    fi
else
    TARGET="$(pwd)/$(agent_project_dir "$AGENT")"
fi

[ -n "$WANTED" ] || WANTED=$(for p in "$SKILLS_SRC"/*/; do basename "$p"; done)

mkdir -p "$TARGET"
info "Installing to $TARGET ($MODE)"

count=0
for s in $WANTED; do
    src="$SKILLS_SRC/$s"
    if [ ! -d "$src" ]; then
        err "No such skill: $s (try --list)"
        exit 1
    fi
    dst="$TARGET/$s"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        warn "replacing existing $s"
        rm -rf "$dst"
    fi
    if [ "$MODE" = symlink ]; then
        ln -s "$src" "$dst"
    else
        cp -R "$src" "$dst"
    fi
    ok "$s"
    count=$((count + 1))
done

echo
ok "$count skill(s) installed for $AGENT."
if [ "$MODE" = symlink ]; then
    info "Symlinked — 'git pull' in $REPO_ROOT updates them all."
else
    info "Copied — re-run this script after 'git pull' to update."
fi
