#!/bin/bash

# Claude Code StatusLine with Session Tracking
# Displays user@host:dir with session metrics
# Part of claude-code-ericbuess

# Cache file location
CACHE_FILE="$HOME/.claude-code-ericbuess/statusline/cache/session-status.json"

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

# Get basic info
USER=$(whoami)
HOST=$(hostname -s)
DIR=$(pwd)

# Default values
SESSIONS=0
REMAINING_MINS=0
TOKENS_USED=0
CACHE_AGE=999999

# Read cache if it exists
if [ -f "$CACHE_FILE" ] && command -v jq &> /dev/null; then
    # Get cache age
    CACHE_UPDATED=$(jq -r '.updated // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
    CURRENT_TIME=$(date +%s)
    CACHE_AGE=$((CURRENT_TIME - CACHE_UPDATED))
    
    # Only use cache if less than 2 minutes old
    if [ "$CACHE_AGE" -lt 120 ]; then
        SESSIONS=$(jq -r '.sessions // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
        REMAINING_MINS=$(jq -r '.remaining_minutes // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
        TOKENS_USED=$(jq -r '.tokens_used // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
    fi
fi

# Build status line components
# User@host:dir part with original colors
USER_HOST_DIR=$(printf '\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m' "$USER" "$HOST" "$DIR")

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
    TIME_INFO=$(printf ' | %s%s %s\033[00m' "$TIME_COLOR" "$TIME_ICON" "$TIME_FORMATTED")
fi

# Token usage (only show if in active session)
TOKEN_INFO=""
if [ "$TOKENS_USED" -gt 0 ]; then
    TOKENS_FORMATTED=$(format_number "$TOKENS_USED")
    TOKEN_INFO=$(printf ' | \033[01;36m📊 %s\033[00m' "$TOKENS_FORMATTED")
fi

# Combine all parts
echo -e "${USER_HOST_DIR} | ${SESSION_INFO}${TIME_INFO}${TOKEN_INFO}"