#!/bin/bash
# Quick script to show remaining Claude time in tmux status bar

# Read session data
REPO_ROOT="$HOME/Projects/claude-ericbuess"
SESSION_DATA="$REPO_ROOT/session-data/session-data.json"

if [ -f "$SESSION_DATA" ]; then
    TIME=$(cat "$SESSION_DATA" 2>/dev/null | jq -r '.remaining_minutes // 0')
    SESSIONS=$(cat "$SESSION_DATA" 2>/dev/null | jq -r '.total_sessions // 0')
    
    if [ "$TIME" -gt 0 ]; then
        HOURS=$((TIME / 60))
        MINS=$((TIME % 60))
        if [ "$MINS" -eq 0 ]; then
            echo "Claude: ${SESSIONS}/50 | ⏳ ${HOURS}h"
        else
            echo "Claude: ${SESSIONS}/50 | ⏳ ${HOURS}h${MINS}m"
        fi
    else
        echo "Claude: ${SESSIONS}/50 | ⏰ Session ended"
    fi
else
    echo "Claude: No data"
fi