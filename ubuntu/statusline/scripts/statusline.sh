#!/bin/bash

# Ultra-Simple Claude Code StatusLine
# Git-based session tracking, no cache, always fresh context

# Paths
REPO_ROOT="$HOME/Projects/claude-ericbuess"
SESSION_DATA="$REPO_ROOT/session-data/session-data.json"
SESSION_REPO="$REPO_ROOT/session-data"

# Read Claude Code input JSON
INPUT=$(cat)

# Function to format numbers
format_number() {
    local num=$1
    if [ "$num" -ge 1000000 ]; then
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

# Extract workspace info from Claude Code input
WORKSPACE_DIR=""
if [ -n "$INPUT" ] && command -v jq &> /dev/null; then
    WORKSPACE_DIR=$(echo "$INPUT" | jq -r '.workspace.current_dir // ""' 2>/dev/null)
fi

# Get basic info
USER=$(whoami)
HOST=$(hostname -s)
DIR=${WORKSPACE_DIR:-$(pwd)}

# Git pull to get latest session data (silent)
if [ -d "$SESSION_REPO/.git" ]; then
    cd "$SESSION_REPO" 2>/dev/null
    git pull --quiet >/dev/null 2>&1 || true
    cd - >/dev/null
fi

# Initialize defaults
SESSIONS=0
REMAINING_MINS=0
TOKENS_USED=0

# Check if we need to update session data
UPDATE_NEEDED=false
if [ -f "$SESSION_DATA" ] && command -v jq &> /dev/null; then
    # Read existing data
    LAST_UPDATED=$(jq -r '.last_updated // ""' "$SESSION_DATA" 2>/dev/null || echo "")
    REMAINING_MINS=$(jq -r '.remaining_minutes // 0' "$SESSION_DATA" 2>/dev/null || echo "0")
    SESSIONS=$(jq -r '.sessions_used // 0' "$SESSION_DATA" 2>/dev/null || echo "0")
    TOKENS_USED=$(jq -r '.tokens_used // 0' "$SESSION_DATA" 2>/dev/null || echo "0")
    
    if [ -n "$LAST_UPDATED" ]; then
        # Check if it's been more than 5 hours since last update
        LAST_EPOCH=$(date -d "${LAST_UPDATED%%.*}" +%s 2>/dev/null || echo 0)
        NOW_EPOCH=$(date +%s)
        HOURS_DIFF=$(( (NOW_EPOCH - LAST_EPOCH) / 3600 ))
        
        # Update if: >5 hours passed OR no remaining time
        if [ "$HOURS_DIFF" -ge 5 ] || [ "$REMAINING_MINS" -eq 0 ]; then
            UPDATE_NEEDED=true
        fi
    else
        UPDATE_NEEDED=true
    fi
else
    UPDATE_NEEDED=true
fi

# If update needed, run ccusage and update git
if [ "$UPDATE_NEEDED" = true ]; then
    # Try to run ccusage
    RUNNER=""
    if command -v bunx &> /dev/null; then
        RUNNER="bunx"
    elif command -v npx &> /dev/null; then
        RUNNER="npx"
    fi
    
    if [ -n "$RUNNER" ]; then
        # Get current month for ccusage
        MONTH_START=$(date +%Y%m01)
        
        # Run ccusage and parse
        CCUSAGE_OUTPUT=$($RUNNER ccusage@latest blocks --json --offline -s "$MONTH_START" 2>/dev/null || echo '{"blocks": []}')
        
        if [ -n "$CCUSAGE_OUTPUT" ] && command -v jq &> /dev/null; then
            # Extract data from active session
            ACTIVE_SESSION=$(echo "$CCUSAGE_OUTPUT" | jq '.blocks[] | select(.isActive == true)' 2>/dev/null)
            
            if [ -n "$ACTIVE_SESSION" ]; then
                SESSIONS=$(echo "$CCUSAGE_OUTPUT" | jq '[.blocks[] | select(.isGap == false)] | length' 2>/dev/null || echo "0")
                REMAINING_MINS=$(echo "$ACTIVE_SESSION" | jq -r '.projection.remainingMinutes // 0' 2>/dev/null || echo "0")
                TOKENS_USED=$(echo "$ACTIVE_SESSION" | jq -r '.totalTokens // 0' 2>/dev/null || echo "0")
                SESSION_START=$(echo "$ACTIVE_SESSION" | jq -r '.startTime // ""' 2>/dev/null || echo "")
                
                # Write session data
                mkdir -p "$(dirname "$SESSION_DATA")"
                cat > "$SESSION_DATA" <<EOF
{
  "sessions_used": $SESSIONS,
  "remaining_minutes": $REMAINING_MINS,
  "tokens_used": $TOKENS_USED,
  "session_start": "$SESSION_START",
  "last_updated": "$(date -Iseconds)",
  "updated_by": "$USER@$HOST"
}
EOF
                
                # Git commit and push (silent)
                if [ -d "$SESSION_REPO/.git" ]; then
                    cd "$SESSION_REPO" 2>/dev/null
                    git add session-data.json >/dev/null 2>&1
                    git commit -m "Update session: ${SESSIONS}/50, ${REMAINING_MINS}m left" >/dev/null 2>&1 || true
                    git push >/dev/null 2>&1 || true
                    cd - >/dev/null
                fi
            fi
        fi
    fi
fi

# Get LIVE context usage for current chat (always fresh)
CONTEXT_USAGE=0
CONTEXT_PCT=0

# Try to find the current transcript file
if [ -n "$WORKSPACE_DIR" ]; then
    # Look for most recent .jsonl in Claude projects
    TRANSCRIPT=$(ls -t ~/.claude/projects/*.jsonl 2>/dev/null | head -1)
    
    if [ -f "$TRANSCRIPT" ]; then
        # Count characters in the transcript (rough estimate)
        CHAR_COUNT=$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo 0)
        
        # Rough conversion: ~4 chars per token
        ESTIMATED_TOKENS=$((CHAR_COUNT / 4))
        
        # Claude's context is roughly 200k tokens
        MAX_CONTEXT=200000
        
        if [ "$ESTIMATED_TOKENS" -gt 0 ]; then
            CONTEXT_PCT=$((ESTIMATED_TOKENS * 100 / MAX_CONTEXT))
            if [ "$CONTEXT_PCT" -gt 100 ]; then
                CONTEXT_PCT=100
            fi
            CONTEXT_USAGE=$ESTIMATED_TOKENS
        fi
    fi
fi

# Git branch and status (always fresh)
GIT_BRANCH=""
GIT_CHANGES=0
if command -v git &> /dev/null && [ -n "$DIR" ]; then
    cd "$DIR" 2>/dev/null
    if git rev-parse --git-dir &>/dev/null 2>&1; then
        GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
        GIT_CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    fi
    cd - >/dev/null
fi

# Build status line - Line 1
# Format: user@host:dir | sessions | time | git

# Color codes
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
RED='\033[01;31m'
BLUE='\033[01;34m'
CYAN='\033[01;36m'
RESET='\033[00m'

# Session indicator
if [ "$SESSIONS" -ge 45 ]; then
    SESSION_COLOR="$RED"
    SESSION_ICON="🔴"
elif [ "$SESSIONS" -ge 35 ]; then
    SESSION_COLOR="$YELLOW"
    SESSION_ICON="🟡"
else
    SESSION_COLOR="$GREEN"
    SESSION_ICON="🟢"
fi

# Build output
OUTPUT="${GREEN}${USER}@${HOST}${RESET}:${BLUE}$(basename "$DIR")${RESET}"

# Add session info
OUTPUT="${OUTPUT} | ${SESSION_COLOR}${SESSION_ICON} ${SESSIONS}/50${RESET}"

# Add time remaining if in active session
if [ "$REMAINING_MINS" -gt 0 ]; then
    TIME_FMT=$(format_time "$REMAINING_MINS")
    if [ "$REMAINING_MINS" -lt 30 ]; then
        OUTPUT="${OUTPUT} ${RED}⏰ ${TIME_FMT}${RESET}"
    else
        OUTPUT="${OUTPUT} ${GREEN}⏳ ${TIME_FMT}${RESET}"
    fi
fi

# Add tokens if we have them
if [ "$TOKENS_USED" -gt 0 ]; then
    TOKENS_FMT=$(format_number "$TOKENS_USED")
    OUTPUT="${OUTPUT} ${CYAN}📊 ${TOKENS_FMT}${RESET}"
fi

# Bible verse (daily rotation based on day of year)
DAY_OF_YEAR=$(date +%j)
VERSE_INDEX=$((DAY_OF_YEAR % 7))  # Rotate through 7 verses

case $VERSE_INDEX in
    0) VERSE="✝️ Php 4:13" ;;  # I can do all things through Christ
    1) VERSE="✝️ Prv 3:5" ;;   # Trust in the Lord with all your heart
    2) VERSE="✝️ Ps 23:1" ;;   # The Lord is my shepherd
    3) VERSE="✝️ Jn 3:16" ;;    # For God so loved the world
    4) VERSE="✝️ Rom 8:28" ;;  # All things work together for good
    5) VERSE="✝️ Josh 1:9" ;;  # Be strong and courageous
    6) VERSE="✝️ Jer 29:11" ;; # I know the plans I have for you
esac

OUTPUT="${OUTPUT} ${CYAN}${VERSE}${RESET}"

# Add git branch
if [ -n "$GIT_BRANCH" ]; then
    if [ "$GIT_CHANGES" -gt 0 ]; then
        OUTPUT="${OUTPUT} ${YELLOW}🌿 ${GIT_BRANCH}*${RESET}"
    else
        OUTPUT="${OUTPUT} ${GREEN}🌿 ${GIT_BRANCH}${RESET}"
    fi
fi

# Line 2 - Context usage (if significant)
LINE2=""
if [ "$CONTEXT_PCT" -gt 0 ]; then
    if [ "$CONTEXT_PCT" -ge 80 ]; then
        LINE2="${RED}⚠️ Context: ${CONTEXT_PCT}% ($(format_number $CONTEXT_USAGE) tokens)${RESET}"
    elif [ "$CONTEXT_PCT" -ge 60 ]; then
        LINE2="${YELLOW}📝 Context: ${CONTEXT_PCT}%${RESET}"
    else
        LINE2="📝 Context: ${CONTEXT_PCT}%"
    fi
fi

# Output
echo -e "$OUTPUT"
if [ -n "$LINE2" ]; then
    echo -e "$LINE2"
fi