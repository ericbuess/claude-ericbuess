#!/bin/bash

# Ultra Claude Code StatusLine with Comprehensive Metrics
# Two-line display with all requested features
# Part of claude-code-ericbuess

# Cache file locations
SESSION_CACHE="$HOME/.claude-code-ericbuess/statusline/cache/session-status-ultra.json"
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
        echo "0m"
    elif [ "$mins" -lt 60 ]; then
        echo "${mins}m"
    else
        local hours=$((mins / 60))
        local remaining_mins=$((mins % 60))
        if [ "$remaining_mins" -eq 0 ]; then
            echo "${hours}h"
        else
            echo "${hours}h${remaining_mins}m"
        fi
    fi
}

# Function to format cost
format_cost() {
    local cost=$1
    printf "$%.2f" "$cost"
}

# Function to create progress bar
create_progress_bar() {
    local percent=$1
    local width=10
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do
        bar="${bar}█"
    done
    for ((i=0; i<empty; i++)); do
        bar="${bar}░"
    done
    echo "$bar"
}

# Function to format directory with ~/
format_directory() {
    local dir=$1
    local home=$HOME
    if [[ "$dir" == "$home"* ]]; then
        echo "~${dir#$home}"
    else
        echo "$dir"
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
DIR_DISPLAY=$(format_directory "$DIR")

# Model display with cost indicator
case "$MODEL_NAME" in
    *"Opus"*) MODEL_DISPLAY="[🧠 Opus]" ;;
    *"Sonnet"*) MODEL_DISPLAY="[⚡ Sonnet]" ;;
    *"Haiku"*) MODEL_DISPLAY="[💨 Haiku]" ;;
    "") MODEL_DISPLAY="" ;;
    *) MODEL_DISPLAY="[🤖 $MODEL_NAME]" ;;
esac

# Initialize default values
SESSIONS=0
REMAINING_MINS=0
TOKENS_USED=0
BURN_RATE=0
SESSION_PROGRESS=0
NEXT_SESSION_MINS=0
CONTEXT_USAGE=0
TODAY_SESSIONS=0
TODAY_COST=0
TOTAL_MONTH_COST=0
AUTO_COMPACT_SOON=false
AUTO_COMPACT_DISTANCE=0
GIT_STATUS="unknown"
GIT_CHANGES=0
GIT_UNPUSHED=0
DOCS_CURRENT=true
DOCS_CHECKED=0
STALE_DOCS=""
ACTIVE_HOOKS=0
NEXT_ACTION=""

# Read session cache if it exists
if [ -f "$SESSION_CACHE" ] && command -v jq &> /dev/null; then
    CACHE_UPDATED=$(jq -r '.updated // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
    CURRENT_TIME=$(date +%s)
    CACHE_AGE=$((CURRENT_TIME - CACHE_UPDATED))
    
    if [ "$CACHE_AGE" -lt 300 ]; then  # Increased to 5 minutes for stability
        SESSIONS=$(jq -r '.sessions // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        REMAINING_MINS=$(jq -r '.remaining_minutes // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        TOKENS_USED=$(jq -r '.tokens_used // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        BURN_RATE=$(jq -r '.burn_rate // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        SESSION_PROGRESS=$(jq -r '.session_progress // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        NEXT_SESSION_MINS=$(jq -r '.next_session_mins // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        CONTEXT_USAGE=$(jq -r '.context_usage // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        TODAY_SESSIONS=$(jq -r '.today_sessions // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        TODAY_COST=$(jq -r '.today_cost // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        TOTAL_MONTH_COST=$(jq -r '.total_month_cost // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        COST_USD=$(jq -r '.cost_usd // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        AUTO_COMPACT_SOON=$(jq -r '.auto_compact_soon // false' "$SESSION_CACHE" 2>/dev/null)
        AUTO_COMPACT_DISTANCE=$(jq -r '.auto_compact_distance // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        GIT_STATUS=$(jq -r '.git_status // "unknown"' "$SESSION_CACHE" 2>/dev/null || echo "unknown")
        GIT_CHANGES=$(jq -r '.git_changes // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        GIT_UNPUSHED=$(jq -r '.git_unpushed // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        DOCS_CURRENT=$(jq -r '.docs_current // true' "$SESSION_CACHE" 2>/dev/null || echo "true")
        DOCS_CHECKED=$(jq -r '.docs_checked // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        STALE_DOCS=$(jq -r '.stale_docs // ""' "$SESSION_CACHE" 2>/dev/null || echo "")
        ACTIVE_HOOKS=$(jq -r '.active_hooks // 0' "$SESSION_CACHE" 2>/dev/null || echo "0")
        NEXT_ACTION=$(jq -r '.next_action // ""' "$SESSION_CACHE" 2>/dev/null || echo "")
    fi
fi

# ========== LINE 1 ==========
# Format: [Model] user@host:dir | sessions | time | tokens | git

# User@host:dir part with original colors
USER_HOST_DIR=$(printf '\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m' "$USER" "$HOST" "$(basename "$DIR_DISPLAY")")

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

# Git branch and status
GIT_INFO=""
if command -v git &> /dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
    CACHE_VALID=false
    if [ -f "$GIT_CACHE" ]; then
        # macOS stat command
        CACHE_MTIME=$(stat -f %m "$GIT_CACHE" 2>/dev/null || echo 0)
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

# Project type and memory status
PROJECT_TYPE=""
MEMORY_STATUS=""
if [ -n "$DIR" ]; then
    cd "$DIR" 2>/dev/null
    if [ -f "package.json" ]; then PROJECT_TYPE=" 📦"; fi
    if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then PROJECT_TYPE=" 🐍"; fi
    if [ -f "Cargo.toml" ]; then PROJECT_TYPE=" 🦀"; fi
    if [ -f "go.mod" ]; then PROJECT_TYPE=" 🐹"; fi
    if [ -f "CLAUDE.md" ] || [ -f ".claude/CLAUDE.md" ]; then MEMORY_STATUS=" 📝"; fi
fi

# ========== LINE 2 ==========
# Format: Progress | Cost | Burn | Context | Env | Stats

LINE2=""

# Progress bar for session
if [ "$REMAINING_MINS" -gt 0 ] && [ "$SESSION_PROGRESS" -ge 0 ]; then
    PROGRESS_BAR=$(create_progress_bar "$SESSION_PROGRESS")
    LINE2="${LINE2}${PROGRESS_BAR} ${SESSION_PROGRESS}%"
fi

# Cost tracking
if [ "$REMAINING_MINS" -gt 0 ] || [ "$TODAY_COST" != "0" ]; then
    if [ -n "$LINE2" ]; then LINE2="${LINE2} | "; fi
    COST_DISPLAY=$(format_cost "$COST_USD")
    LINE2="${LINE2}💰 ${COST_DISPLAY}"
fi

# Burn rate
if [ "$BURN_RATE" -gt 0 ]; then
    if [ -n "$LINE2" ]; then LINE2="${LINE2} | "; fi
    if [ "$BURN_RATE" -gt 1000 ]; then
        LINE2="${LINE2}🔥 $(format_number $BURN_RATE)/min"
    else
        LINE2="${LINE2}📈 ${BURN_RATE}/min"
    fi
fi

# Context usage
if [ "$CONTEXT_USAGE" -gt 0 ]; then
    if [ -n "$LINE2" ]; then LINE2="${LINE2} | "; fi
    if [ "$CONTEXT_USAGE" -ge 80 ]; then
        LINE2="${LINE2}⚠️ Context: ${CONTEXT_USAGE}%"
    else
        LINE2="${LINE2}📝 Context: ${CONTEXT_USAGE}%"
    fi
fi

# Environment indicators
ENV_INDICATORS=""

# Python venv detection
if [ -n "$VIRTUAL_ENV" ]; then
    ENV_INDICATORS="${ENV_INDICATORS}🐍 $(basename "$VIRTUAL_ENV") "
elif [ -n "$CONDA_DEFAULT_ENV" ]; then
    ENV_INDICATORS="${ENV_INDICATORS}🐍 $CONDA_DEFAULT_ENV "
fi

# Docker detection
if command -v docker &>/dev/null && docker ps &>/dev/null 2>&1; then
    DOCKER_COUNT=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
    if [ "$DOCKER_COUNT" -gt 0 ]; then
        ENV_INDICATORS="${ENV_INDICATORS}🐳 $DOCKER_COUNT "
    fi
fi

if [ -n "$ENV_INDICATORS" ]; then
    if [ -n "$LINE2" ]; then LINE2="${LINE2} | "; fi
    LINE2="${LINE2}${ENV_INDICATORS}"
fi

# Project state indicators
PROJECT_STATE=""

# Git state indicator
if [ "$GIT_STATUS" = "dirty" ]; then
    PROJECT_STATE="${PROJECT_STATE}🔴 Git: ${GIT_CHANGES}↻ ${GIT_UNPUSHED}↑ "
elif [ "$GIT_STATUS" = "pending" ] && ([ "$GIT_CHANGES" -gt 0 ] || [ "$GIT_UNPUSHED" -gt 0 ]); then
    PROJECT_STATE="${PROJECT_STATE}🟡 Git: ${GIT_CHANGES}↻ ${GIT_UNPUSHED}↑ "
elif [ "$GIT_STATUS" = "clean" ]; then
    # Don't show anything when clean
    :
fi

# Documentation freshness
if [ "$DOCS_CURRENT" = "false" ]; then
    if [ -n "$STALE_DOCS" ]; then
        # Show what's stale (truncate if too long)
        STALE_SHORT=$(echo "$STALE_DOCS" | cut -c1-15)
        PROJECT_STATE="${PROJECT_STATE}📝⚠️ ${STALE_SHORT} "
    else
        PROJECT_STATE="${PROJECT_STATE}📝⚠️ "
    fi
fi

# Hooks indicator
if [ "$ACTIVE_HOOKS" -gt 0 ]; then
    PROJECT_STATE="${PROJECT_STATE}🪝×${ACTIVE_HOOKS} "
fi

if [ -n "$PROJECT_STATE" ]; then
    if [ -n "$LINE2" ]; then LINE2="${LINE2} | "; fi
    LINE2="${LINE2}${PROJECT_STATE}"
fi

# Session reset timer
if [ "$REMAINING_MINS" -eq 0 ] && [ "$NEXT_SESSION_MINS" -eq 0 ]; then
    # No active session, show "ready"
    if [ -n "$LINE2" ]; then LINE2="${LINE2} | "; fi
    LINE2="${LINE2}✨ Ready"
elif [ "$REMAINING_MINS" -lt 30 ] && [ "$NEXT_SESSION_MINS" -gt 0 ]; then
    # Show next session timer when current is ending
    if [ -n "$LINE2" ]; then LINE2="${LINE2} | "; fi
    LINE2="${LINE2}Next: $(format_time $NEXT_SESSION_MINS)"
fi

# Daily stats (compact)
if [ "$TODAY_SESSIONS" -gt 0 ] || [ "$TODAY_COST" != "0" ]; then
    if [ -n "$LINE2" ]; then LINE2="${LINE2} | "; fi
    LINE2="${LINE2}Today: ${TODAY_SESSIONS}s/$(format_cost "$TODAY_COST")"
fi

# Auto-compact warning
if [ "$AUTO_COMPACT_SOON" = "true" ]; then
    if [ -n "$LINE2" ]; then LINE2="${LINE2} | "; fi
    LINE2="${LINE2}🔄 Compact soon!"
fi

# Next action hint
if [ -n "$NEXT_ACTION" ]; then
    if [ -n "$LINE2" ]; then LINE2="${LINE2} | "; fi
    LINE2="${LINE2}💡 ${NEXT_ACTION}"
fi

# Output both lines
if [ -n "$MODEL_DISPLAY" ]; then
    echo -e "${MODEL_DISPLAY} ${USER_HOST_DIR}${PROJECT_TYPE}${MEMORY_STATUS} | ${SESSION_INFO}${TIME_INFO}${TOKEN_INFO}${GIT_INFO}"
else
    echo -e "${USER_HOST_DIR}${PROJECT_TYPE}${MEMORY_STATUS} | ${SESSION_INFO}${TIME_INFO}${TOKEN_INFO}${GIT_INFO}"
fi

# Only show line 2 if there's content
if [ -n "$LINE2" ]; then
    echo -e "$LINE2"
fi

# Cleanup old cache files
find /tmp -name "claude_git_cache_*" -mmin +5 -delete 2>/dev/null || true