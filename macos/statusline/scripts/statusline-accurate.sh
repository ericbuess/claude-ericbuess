#!/bin/bash

# Accurate Cross-Machine Session Tracker for Claude Code
# Automatically deduplicates sessions across all machines

# Paths
REPO_ROOT="$HOME/Projects/claude-ericbuess"
SESSION_REPO="$REPO_ROOT/session-data"
MACHINES_DIR="$SESSION_REPO/machines"
THIS_MACHINE=$(hostname -s)
MERGED_DATA="$SESSION_REPO/session-data.json"

# Read Claude Code input
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

# Function to get 5-hour window start for a given timestamp
get_window_start() {
    local timestamp="$1"
    # Convert to epoch seconds
    local epoch
    if [[ "$OSTYPE" == "darwin"* ]]; then
        epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${timestamp%%.*}" +%s 2>/dev/null || echo 0)
    else
        epoch=$(date -d "${timestamp%%.*}" +%s 2>/dev/null || echo 0)
    fi
    
    # Calculate window start (5-hour blocks from midnight UTC)
    local hours_since_midnight=$(( (epoch % 86400) / 3600 ))
    local window_block=$(( hours_since_midnight / 5 ))
    local window_start_hour=$(( window_block * 5 ))
    
    # Get the date part and construct window start
    local date_part="${timestamp%%T*}"
    printf "%sT%02d:00:00.000Z" "$date_part" "$window_start_hour"
}

# Get workspace info
WORKSPACE_DIR=""
if [ -n "$INPUT" ] && command -v jq &> /dev/null; then
    WORKSPACE_DIR=$(echo "$INPUT" | jq -r '.workspace.current_dir // ""' 2>/dev/null)
fi

# Basic info
USER=$(whoami)
HOST=$(hostname -s)
DIR=${WORKSPACE_DIR:-$(pwd)}

# Ensure repo and directories exist
mkdir -p "$MACHINES_DIR"
cd "$SESSION_REPO" 2>/dev/null || {
    mkdir -p "$SESSION_REPO"
    cd "$SESSION_REPO"
    git init .
}

# Git pull to get latest data from other machines (silent)
git pull origin main --quiet >/dev/null 2>&1 || true

# Step 1: Collect local ccusage data
RUNNER=""
if command -v bunx &> /dev/null; then
    RUNNER="bunx"
elif command -v npx &> /dev/null; then
    RUNNER="npx"
fi

if [ -n "$RUNNER" ]; then
    # Get current month
    MONTH_START=$(date +%Y%m01)
    
    # Run ccusage and save raw output
    CCUSAGE_OUTPUT=$($RUNNER ccusage@latest blocks --json --offline -s "$MONTH_START" 2>/dev/null || echo '{"blocks": []}')
    
    # Save with timestamp
    if [ -n "$CCUSAGE_OUTPUT" ]; then
        echo "$CCUSAGE_OUTPUT" | jq --arg host "$THIS_MACHINE" --arg time "$(date -Iseconds)" \
            '. + {machine: $host, collected_at: $time}' > "$MACHINES_DIR/${THIS_MACHINE}.json" 2>/dev/null || true
    fi
fi

# Step 2: Merge all machine data and deduplicate
TOTAL_SESSIONS=0
REMAINING_MINS=0
CURRENT_WINDOW_END=""
TOKENS_USED=0

if command -v jq &> /dev/null; then
    # Create temporary file for merged analysis
    TEMP_MERGED=$(mktemp)
    
    # Collect all unique session windows from all machines
    echo '{"windows": [], "current_active": null}' > "$TEMP_MERGED"
    
    for machine_file in "$MACHINES_DIR"/*.json; do
        [ -f "$machine_file" ] || continue
        
        # Extract all non-gap blocks from this machine
        BLOCKS=$(jq -r '.blocks[] | select(.isGap == false) | @json' "$machine_file" 2>/dev/null || true)
        
        while IFS= read -r block; do
            [ -z "$block" ] || [ "$block" = "null" ] && continue
            
            # Parse block data
            START_TIME=$(echo "$block" | jq -r '.startTime // ""')
            END_TIME=$(echo "$block" | jq -r '.endTime // ""')
            IS_ACTIVE=$(echo "$block" | jq -r '.isActive // false')
            BLOCK_TOKENS=$(echo "$block" | jq -r '.totalTokens // 0')
            PROJECTION=$(echo "$block" | jq -r '.projection // {}')
            
            [ -z "$START_TIME" ] && continue
            
            # Get 5-hour window for this block
            WINDOW_START=$(get_window_start "$START_TIME")
            
            # Add window to our list (jq will handle deduplication)
            jq --arg window "$WINDOW_START" \
               --arg active "$IS_ACTIVE" \
               --arg end "$END_TIME" \
               --argjson tokens "$BLOCK_TOKENS" \
               --argjson proj "$PROJECTION" '
                .windows += [$window] |
                .windows = (.windows | unique) |
                if $active == "true" then
                    .current_active = {
                        window: $window,
                        end: $end,
                        tokens: $tokens,
                        projection: $proj
                    }
                else . end
            ' "$TEMP_MERGED" > "${TEMP_MERGED}.new" && mv "${TEMP_MERGED}.new" "$TEMP_MERGED"
            
        done <<< "$BLOCKS"
    done
    
    # Count unique windows (deduplicated sessions)
    TOTAL_SESSIONS=$(jq '.windows | length' "$TEMP_MERGED")
    
    # Get current session info
    ACTIVE_INFO=$(jq -r '.current_active // null' "$TEMP_MERGED")
    if [ "$ACTIVE_INFO" != "null" ]; then
        REMAINING_MINS=$(echo "$ACTIVE_INFO" | jq -r '.projection.remainingMinutes // 0')
        TOKENS_USED=$(echo "$ACTIVE_INFO" | jq -r '.tokens // 0')
        CURRENT_WINDOW_END=$(echo "$ACTIVE_INFO" | jq -r '.end // ""')
    fi
    
    # If no active session, calculate from current time
    if [ "$REMAINING_MINS" -eq 0 ]; then
        NOW=$(date +%s)
        CURRENT_HOUR=$(date +%H)
        # Calculate next window boundary
        WINDOW_HOUR=$(( (CURRENT_HOUR / 5 + 1) * 5 ))
        if [ "$WINDOW_HOUR" -ge 24 ]; then
            WINDOW_HOUR=0
            # Next day
            TOMORROW=$(( NOW + 86400 ))
            if [[ "$OSTYPE" == "darwin"* ]]; then
                CURRENT_WINDOW_END=$(date -j -f "%s" "$TOMORROW" "+%Y-%m-%dT00:00:00.000Z")
            else
                CURRENT_WINDOW_END=$(date -d "@$TOMORROW" "+%Y-%m-%dT00:00:00.000Z")
            fi
        else
            if [[ "$OSTYPE" == "darwin"* ]]; then
                CURRENT_WINDOW_END=$(date -j "+%Y-%m-%dT$(printf '%02d' $WINDOW_HOUR):00:00.000Z")
            else
                CURRENT_WINDOW_END=$(date "+%Y-%m-%dT$(printf '%02d' $WINDOW_HOUR):00:00.000Z")
            fi
        fi
    fi
    
    # Save merged data
    cat > "$MERGED_DATA" <<EOF
{
  "total_sessions": $TOTAL_SESSIONS,
  "remaining_minutes": $REMAINING_MINS,
  "tokens_used": $TOKENS_USED,
  "current_window_end": "$CURRENT_WINDOW_END",
  "last_updated": "$(date -Iseconds)",
  "updated_by": "$USER@$HOST"
}
EOF
    
    rm -f "$TEMP_MERGED"
fi

# Step 3: Git push (silent, best effort)
if [ -d "$SESSION_REPO/.git" ]; then
    cd "$SESSION_REPO" 2>/dev/null
    git add -A >/dev/null 2>&1
    git commit -m "Session update: ${TOTAL_SESSIONS}/50 by ${THIS_MACHINE}" >/dev/null 2>&1 || true
    git push origin main >/dev/null 2>&1 || true
    cd - >/dev/null
fi

# Step 4: Display statusline
# Git branch and status
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

# Build statusline
# Color codes
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
RED='\033[01;31m'
BLUE='\033[01;34m'
CYAN='\033[01;36m'
RESET='\033[00m'

# Session indicator with color
if [ "$TOTAL_SESSIONS" -ge 45 ]; then
    SESSION_COLOR="$RED"
    SESSION_ICON="🔴"
elif [ "$TOTAL_SESSIONS" -ge 35 ]; then
    SESSION_COLOR="$YELLOW"
    SESSION_ICON="🟡"
else
    SESSION_COLOR="$GREEN"
    SESSION_ICON="🟢"
fi

# Build output
OUTPUT="${GREEN}${USER}@${HOST}${RESET}:${BLUE}$(basename "$DIR")${RESET}"
OUTPUT="${OUTPUT} | ${SESSION_COLOR}${SESSION_ICON} ${TOTAL_SESSIONS}/50${RESET}"

# Time remaining
if [ "$REMAINING_MINS" -gt 0 ]; then
    TIME_FMT=$(format_time "$REMAINING_MINS")
    if [ "$REMAINING_MINS" -lt 30 ]; then
        OUTPUT="${OUTPUT} ${RED}⏰ ${TIME_FMT}${RESET}"
    else
        OUTPUT="${OUTPUT} ${GREEN}⏳ ${TIME_FMT}${RESET}"
    fi
fi

# Tokens
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

# Git branch
if [ -n "$GIT_BRANCH" ]; then
    if [ "$GIT_CHANGES" -gt 0 ]; then
        OUTPUT="${OUTPUT} ${YELLOW}🌿 ${GIT_BRANCH}*${RESET}"
    else
        OUTPUT="${OUTPUT} ${GREEN}🌿 ${GIT_BRANCH}${RESET}"
    fi
fi

echo -e "$OUTPUT"