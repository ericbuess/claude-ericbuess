#!/bin/bash

# Enhanced Claude Code StatusLine with Session Tracking
# Displays: [Model] user@host:dir | sessions | time | tokens | git | project
# Part of claude-code-ericbuess

# Cache file locations
SESSION_CACHE="$HOME/.claude-code-ericbuess/statusline/cache/session-status.json"
GIT_CACHE="/tmp/claude_git_cache_$$"

# Read Claude Code input JSON
INPUT=$(cat)

# Function to format large numbers
format_number() {
    local num=$1
    if [ "$num" -ge 1000000000 ]; then
        printf "%.1fB" $(echo "scale=1; $num/1000000000" | bc)
    elif [ "$num" -ge 1000000 ]; then
        printf "%.1fM" $(echo "scale=1; $num/1000000" | bc)
    elif [ "$num" -ge 1000 ]; then
        printf "%.1fK" $(echo "scale=1; $num/1000" | bc)
    else
        echo "$num"
    fi
}

# Function to format time
format_time() {
    local mins=$1
    if [ "$mins" -eq 0 ]; then
        echo ""
    elif [ "$mins" -lt 60 ]; then
        echo "${mins}m"
    else
        local hours=$((mins / 60))
        local remaining_mins=$((mins % 60))
        echo "${hours}h${remaining_mins}m"
    fi
}

# Extract model info from Claude Code input
MODEL_NAME=""
if [ -n "$INPUT" ] && command -v jq &> /dev/null; then
    MODEL_NAME=$(echo "$INPUT" | jq -r '.model.display_name // ""' 2>/dev/null)
    WORKSPACE_DIR=$(echo "$INPUT" | jq -r '.workspace.current_dir // ""' 2>/dev/null)
    PROJECT_DIR=$(echo "$INPUT" | jq -r '.workspace.project_dir // ""' 2>/dev/null)
fi

# Get basic info
USER=$(whoami)
HOST=$(hostname -s)
DIR=${WORKSPACE_DIR:-$(pwd)}

# Model display with cost indicator
case "$MODEL_NAME" in
    "Opus") MODEL_DISPLAY="[🧠 Opus]" ;;
    "Sonnet") MODEL_DISPLAY="[⚡ Sonnet]" ;;
    "Haiku") MODEL_DISPLAY="[💨 Haiku]" ;;
    "") MODEL_DISPLAY="" ;;
    *) MODEL_DISPLAY="[🤖 $MODEL_NAME]" ;;
esac

# Default session values
SESSIONS=0
REMAINING_MINS=0
TOKENS_USED=0

# Read session cache if it exists
if [ -f "$SESSION_CACHE" ] && command -v jq &> /dev/null; then
    CACHE_UPDATED=$(jq -r '.updated // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
    CURRENT_TIME=$(date +%s)
    CACHE_AGE=$((CURRENT_TIME - CACHE_UPDATED))
    
    if [ "$CACHE_AGE" -lt 120 ]; then
        SESSIONS=$(jq -r '.sessions // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        REMAINING_MINS=$(jq -r '.remaining_minutes // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        TOKENS_USED=$(jq -r '.tokens_used // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
    fi
fi

# User@host:dir part with original colors
USER_HOST_DIR=$(printf '\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m' "$USER" "$HOST" "$(basename "$DIR")")

# Session count with color coding
if [ "$SESSIONS" -ge 45 ]; then
    SESSION_COLOR="\033[01;31m"  # Red
    SESSION_ICON="🔴"
elif [ "$SESSIONS" -ge 35 ]; then
    SESSION_COLOR="\033[01;33m"  # Yellow
    SESSION_ICON="🟡"
else
    SESSION_COLOR="\033[01;32m"  # Green
    SESSION_ICON="🟢"
fi
SESSION_INFO=$(printf '%s%s %d/50\033[00m' "$SESSION_COLOR" "$SESSION_ICON" "$SESSIONS")

# Time remaining (only show if active session)
TIME_INFO=""
if [ "$REMAINING_MINS" -gt 0 ]; then
    TIME_FORMATTED=$(format_time "$REMAINING_MINS")
    if [ "$REMAINING_MINS" -lt 30 ]; then
        TIME_COLOR="\033[01;31m"  # Red
        TIME_ICON="⏰"
    elif [ "$REMAINING_MINS" -lt 120 ]; then
        TIME_COLOR="\033[01;33m"  # Yellow
        TIME_ICON="⏱️"
    else
        TIME_COLOR="\033[01;32m"  # Green
        TIME_ICON="⏳"
    fi
    TIME_INFO=$(printf ' %s%s %s\033[00m' "$TIME_COLOR" "$TIME_ICON" "$TIME_FORMATTED")
fi

# Token usage (only show if in active session)
TOKEN_INFO=""
if [ "$TOKENS_USED" -gt 0 ]; then
    TOKENS_FORMATTED=$(format_number "$TOKENS_USED")
    TOKEN_INFO=$(printf ' \033[01;36m📊 %s\033[00m' "$TOKENS_FORMATTED")
fi

# Git branch and status (with caching for performance)
GIT_INFO=""
if command -v git &> /dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
    # Cache git info for 30 seconds to avoid slowdowns
    CACHE_VALID=false
    if [ -f "$GIT_CACHE" ]; then
        CACHE_MTIME=$(stat -c %Y "$GIT_CACHE" 2>/dev/null || stat -f %m "$GIT_CACHE" 2>/dev/null || echo 0)
        CURRENT_TIME=$(date +%s)
        if [ $((CURRENT_TIME - CACHE_MTIME)) -lt 30 ]; then
            CACHE_VALID=true
        fi
    fi
    
    if [ "$CACHE_VALID" = false ]; then
        BRANCH=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null)
        CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        echo "$BRANCH:$CHANGES" > "$GIT_CACHE"
    else
        CACHED=$(cat "$GIT_CACHE")
        BRANCH="${CACHED%%:*}"
        CHANGES="${CACHED##*:}"
    fi
    
    if [ -n "$BRANCH" ]; then
        if [ "$CHANGES" -gt 0 ]; then
            GIT_INFO=$(printf ' \033[01;33m🌿 %s*\033[00m' "$BRANCH")
        else
            GIT_INFO=$(printf ' \033[01;32m🌿 %s\033[00m' "$BRANCH")
        fi
    fi
fi

# Project type detection
PROJECT_TYPE=""
if [ -n "$DIR" ]; then
    cd "$DIR" 2>/dev/null
    if [ -f "package.json" ]; then
        PROJECT_TYPE=" 📦"
    elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
        PROJECT_TYPE=" 🐍"
    elif [ -f "Cargo.toml" ]; then
        PROJECT_TYPE=" 🦀"
    elif [ -f "go.mod" ]; then
        PROJECT_TYPE=" 🐹"
    elif [ -f "pom.xml" ] || [ -f "build.gradle" ]; then
        PROJECT_TYPE=" ☕"
    elif [ -f "Gemfile" ]; then
        PROJECT_TYPE=" 💎"
    elif [ -f "composer.json" ]; then
        PROJECT_TYPE=" 🐘"
    fi
fi

# CLAUDE.md memory indicator
MEMORY_STATUS=""
if [ -f "CLAUDE.md" ] || [ -f ".claude/CLAUDE.md" ]; then
    MEMORY_STATUS=" 📝"
fi

# Permission mode indicator
PERM_MODE=""
if [ -f "$HOME/.claude/settings.json" ] && command -v jq &> /dev/null; then
    PERMISSION=$(jq -r '.permission_mode // "ask"' "$HOME/.claude/settings.json" 2>/dev/null)
    case "$PERMISSION" in
        "accept") PERM_MODE=" ✅" ;;
        "plan") PERM_MODE=" 📋" ;;
        "ask") PERM_MODE="" ;;  # Default, don't show
    esac
fi

# Combine all parts
if [ -n "$MODEL_DISPLAY" ]; then
    echo -e "${MODEL_DISPLAY} ${USER_HOST_DIR}${PROJECT_TYPE}${MEMORY_STATUS} | ${SESSION_INFO}${TIME_INFO}${TOKEN_INFO}${GIT_INFO}${PERM_MODE}"
else
    echo -e "${USER_HOST_DIR}${PROJECT_TYPE}${MEMORY_STATUS} | ${SESSION_INFO}${TIME_INFO}${TOKEN_INFO}${GIT_INFO}${PERM_MODE}"
fi

# Cleanup old cache files
find /tmp -name "claude_git_cache_*" -mmin +5 -delete 2>/dev/null || true