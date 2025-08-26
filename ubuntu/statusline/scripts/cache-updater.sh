#!/bin/bash

# Claude Code Session Cache Updater
# Updates session metrics cache for statusline display
# Part of claude-code-ericbuess

set -euo pipefail

CACHE_DIR="$HOME/.claude-code-ericbuess/statusline/cache"
CACHE_FILE="$CACHE_DIR/session-status.json"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Check for ccusage runner
RUNNER=""
if command -v bunx &> /dev/null; then
    RUNNER="bunx"
elif command -v npx &> /dev/null; then
    RUNNER="npx"
else
    echo '{"error": "No runner available"}' > "$CACHE_FILE"
    exit 1
fi

# Get current month in YYYYMM01 format
MONTH_START=$(date +%Y%m01)

# Fetch ccusage data with timeout
CCUSAGE_OUTPUT=$($RUNNER ccusage@latest blocks --json --offline -s "$MONTH_START" 2>/dev/null || echo '{"blocks": []}')

# Parse the data using jq
if command -v jq &> /dev/null; then
    # Count non-gap sessions
    SESSION_COUNT=$(echo "$CCUSAGE_OUTPUT" | jq '[.blocks[] | select(.isGap == false)] | length')
    
    # Get active session data
    ACTIVE_SESSION=$(echo "$CCUSAGE_OUTPUT" | jq '.blocks[] | select(.isActive == true)' 2>/dev/null)
    
    if [ -n "$ACTIVE_SESSION" ]; then
        # Extract metrics from active session
        REMAINING_MINS=$(echo "$ACTIVE_SESSION" | jq -r '.projection.remainingMinutes // 0')
        TOKENS_USED=$(echo "$ACTIVE_SESSION" | jq -r '.totalTokens // 0')
        COST_USD=$(echo "$ACTIVE_SESSION" | jq -r '.costUSD // 0')
        BURN_RATE=$(echo "$ACTIVE_SESSION" | jq -r '.burnRate.tokensPerMinute // 0')
    else
        REMAINING_MINS=0
        TOKENS_USED=0
        COST_USD=0
        BURN_RATE=0
    fi
    
    # Calculate total tokens for the month
    TOTAL_MONTH_TOKENS=$(echo "$CCUSAGE_OUTPUT" | jq '[.blocks[] | select(.isGap == false) | .totalTokens] | add // 0')
    
    # Create JSON output
    cat > "$CACHE_FILE" <<EOF
{
  "sessions": $SESSION_COUNT,
  "remaining_minutes": $REMAINING_MINS,
  "tokens_used": $TOKENS_USED,
  "total_month_tokens": $TOTAL_MONTH_TOKENS,
  "cost_usd": $COST_USD,
  "burn_rate": $BURN_RATE,
  "updated": $(date +%s),
  "updated_iso": "$(date -Iseconds)"
}
EOF
else
    # Fallback without jq
    echo '{"error": "jq not installed"}' > "$CACHE_FILE"
fi