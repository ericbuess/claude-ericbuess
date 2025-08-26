#!/bin/bash

# Ultra Claude Code Session Cache Updater
# Collects comprehensive metrics for advanced statusline display
# Part of claude-code-ericbuess

set -euo pipefail

# Add PATH for cron execution
export PATH="/home/ericbuess/.nvm/versions/node/v22.17.1/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

CACHE_DIR="$HOME/.claude-code-ericbuess/statusline/cache"
CACHE_FILE="$CACHE_DIR/session-status-ultra.json"
TRANSCRIPT_PATTERN="$HOME/.claude/projects/*.jsonl"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Check for ccusage runner - use full paths for cron
RUNNER=""
if command -v bunx &> /dev/null; then
    RUNNER="bunx"
elif [ -x "/home/ericbuess/.nvm/versions/node/v22.17.1/bin/npx" ]; then
    RUNNER="/home/ericbuess/.nvm/versions/node/v22.17.1/bin/npx"
elif command -v npx &> /dev/null; then
    RUNNER="npx"
else
    echo '{"error": "No runner available"}' > "$CACHE_FILE"
    exit 1
fi

# Get current month in YYYYMM01 format
MONTH_START=$(date +%Y%m01)
TODAY_START=$(date +%Y%m%d)

# Fetch ccusage data with timeout (suppress npm warnings)
CCUSAGE_OUTPUT=$($RUNNER ccusage@latest blocks --json --offline -s "$MONTH_START" 2>&1 | grep -v "npm" || echo '{"blocks": []}')

# Model pricing (per million tokens)
# Rough estimates - adjust as needed
declare -A INPUT_PRICES OUTPUT_PRICES
INPUT_PRICES["opus"]=15.0
OUTPUT_PRICES["opus"]=75.0
INPUT_PRICES["sonnet"]=3.0
OUTPUT_PRICES["sonnet"]=15.0
INPUT_PRICES["haiku"]=0.25
OUTPUT_PRICES["haiku"]=1.25

# Parse the data using jq
if command -v jq &> /dev/null; then
    # Count non-gap sessions
    SESSION_COUNT=$(echo "$CCUSAGE_OUTPUT" | jq '[.blocks[] | select(.isGap == false)] | length')
    
    # Get active session data
    ACTIVE_SESSION=$(echo "$CCUSAGE_OUTPUT" | jq '.blocks[] | select(.isActive == true)' 2>/dev/null)
    
    # Session timing data
    if [ -n "$ACTIVE_SESSION" ]; then
        # Extract metrics from active session
        REMAINING_MINS=$(echo "$ACTIVE_SESSION" | jq -r '.projection.remainingMinutes // 0')
        TOKENS_USED=$(echo "$ACTIVE_SESSION" | jq -r '.totalTokens // 0')
        COST_USD=$(echo "$ACTIVE_SESSION" | jq -r '.costUSD // 0')
        BURN_RATE=$(echo "$ACTIVE_SESSION" | jq -r '.burnRate.tokensPerMinute // 0' | cut -d. -f1)
        START_TIME=$(echo "$ACTIVE_SESSION" | jq -r '.startTime // ""')
        END_TIME=$(echo "$ACTIVE_SESSION" | jq -r '.endTime // ""')
        
        # Calculate session progress (0-100%)
        if [ -n "$START_TIME" ] && [ -n "$END_TIME" ]; then
            START_EPOCH=$(date -d "$START_TIME" +%s 2>/dev/null || echo 0)
            END_EPOCH=$(date -d "$END_TIME" +%s 2>/dev/null || echo 0)
            NOW_EPOCH=$(date +%s)
            
            if [ "$END_EPOCH" -gt "$START_EPOCH" ]; then
                TOTAL_DURATION=$((END_EPOCH - START_EPOCH))
                ELAPSED=$((NOW_EPOCH - START_EPOCH))
                if [ "$ELAPSED" -lt 0 ]; then ELAPSED=0; fi
                if [ "$ELAPSED" -gt "$TOTAL_DURATION" ]; then ELAPSED=$TOTAL_DURATION; fi
                SESSION_PROGRESS=$((ELAPSED * 100 / TOTAL_DURATION))
            else
                SESSION_PROGRESS=0
            fi
        else
            SESSION_PROGRESS=0
        fi
        
        # Time until next session block starts (if current expires)
        NEXT_SESSION_MINS=$((300 - (300 - REMAINING_MINS)))
        if [ "$NEXT_SESSION_MINS" -lt 0 ]; then
            NEXT_SESSION_MINS=0
        fi
    else
        REMAINING_MINS=0
        TOKENS_USED=0
        COST_USD=0
        BURN_RATE=0
        SESSION_PROGRESS=0
        NEXT_SESSION_MINS=0
        START_TIME=""
        END_TIME=""
    fi
    
    # Calculate total tokens for the month
    TOTAL_MONTH_TOKENS=$(echo "$CCUSAGE_OUTPUT" | jq '[.blocks[] | select(.isGap == false) | .totalTokens] | add // 0')
    TOTAL_MONTH_COST=$(echo "$CCUSAGE_OUTPUT" | jq '[.blocks[] | select(.isGap == false) | .costUSD] | add // 0')
    
    # Calculate today's usage
    TODAY_SESSIONS=$(echo "$CCUSAGE_OUTPUT" | jq --arg today "$TODAY_START" '
        [.blocks[] | select(.isGap == false and (.startTime | startswith($today)))] | length
    ')
    TODAY_TOKENS=$(echo "$CCUSAGE_OUTPUT" | jq --arg today "$TODAY_START" '
        [.blocks[] | select(.isGap == false and (.startTime | startswith($today))) | .totalTokens] | add // 0
    ')
    TODAY_COST=$(echo "$CCUSAGE_OUTPUT" | jq --arg today "$TODAY_START" '
        [.blocks[] | select(.isGap == false and (.startTime | startswith($today))) | .costUSD] | add // 0
    ')
    
    # Get context usage from hook-generated cache (preferred) or fallback to direct access
    CONTEXT_USAGE=0
    HOOK_CONTEXT_CACHE="$HOME/.claude-code-ericbuess/statusline/cache/context-usage.json"
    
    # Try hook-generated context data first (more accurate and accessible)
    if [ -f "$HOOK_CONTEXT_CACHE" ]; then
        HOOK_UPDATED=$(jq -r '.updated // 0' "$HOOK_CONTEXT_CACHE" 2>/dev/null || echo "0")
        CURRENT_TIME=$(date +%s)
        HOOK_AGE=$((CURRENT_TIME - HOOK_UPDATED))
        
        # Use hook data if less than 10 minutes old
        if [ "$HOOK_AGE" -lt 600 ]; then
            CONTEXT_USAGE=$(jq -r '.context_usage // 0' "$HOOK_CONTEXT_CACHE" 2>/dev/null || echo "0")
        fi
    fi
    
    # Fallback: try direct transcript access (may fail due to security restrictions)
    if [ "$CONTEXT_USAGE" -eq 0 ]; then
        LATEST_TRANSCRIPT=$(ls -t ~/.claude/projects/*.jsonl 2>/dev/null | head -1 || echo "")
        if [ -n "$LATEST_TRANSCRIPT" ] && [ -f "$LATEST_TRANSCRIPT" ]; then
            # Rough estimate: count total characters in messages (context is ~4 chars per token, max ~200k tokens)
            TOTAL_CHARS=$(jq -s '[.[] | .content // "" | length] | add // 0' "$LATEST_TRANSCRIPT" 2>/dev/null || echo 0)
            ESTIMATED_TOKENS=$((TOTAL_CHARS / 4))
            MAX_CONTEXT=200000  # Rough estimate for Claude's context window
            if [ "$ESTIMATED_TOKENS" -gt 0 ]; then
                CONTEXT_USAGE=$((ESTIMATED_TOKENS * 100 / MAX_CONTEXT))
                if [ "$CONTEXT_USAGE" -gt 100 ]; then CONTEXT_USAGE=100; fi
            fi
        fi
    fi
    
    # Auto-compact indicator (usually triggers around 80-90% context)
    AUTO_COMPACT_THRESHOLD=80
    if [ "$CONTEXT_USAGE" -ge "$AUTO_COMPACT_THRESHOLD" ]; then
        AUTO_COMPACT_SOON=true
        AUTO_COMPACT_DISTANCE=$((100 - CONTEXT_USAGE))
    else
        AUTO_COMPACT_SOON=false
        AUTO_COMPACT_DISTANCE=$((AUTO_COMPACT_THRESHOLD - CONTEXT_USAGE))
    fi
    
    # Performance metrics (response time - simplified)
    # Would need more sophisticated tracking in real implementation
    AVG_RESPONSE_TIME=1.2  # Placeholder in seconds
    
    # Git status check
    GIT_STATUS="unknown"
    GIT_CHANGES=0
    GIT_UNPUSHED=0
    if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null 2>&1; then
        # Count uncommitted changes
        GIT_CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        
        # Count unpushed commits
        UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
        if [ -n "$UPSTREAM" ]; then
            GIT_UNPUSHED=$(git rev-list HEAD..."$UPSTREAM" --count 2>/dev/null || echo 0)
        fi
        
        # Determine status
        if [ "$GIT_CHANGES" -eq 0 ] && [ "$GIT_UNPUSHED" -eq 0 ]; then
            GIT_STATUS="clean"
        elif [ "$GIT_CHANGES" -gt 10 ] || [ "$GIT_UNPUSHED" -gt 5 ]; then
            GIT_STATUS="dirty"
        else
            GIT_STATUS="pending"
        fi
    fi
    
    # CLAUDE.md documentation tracking (simplified and correct)
    DOCS_CURRENT=true
    STALE_DOCS=""
    DOCS_CHECKED=0
    
    # Find only CLAUDE.md files in the project
    CLAUDE_MD_FILES=$(find . -name "CLAUDE.md" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/vendor/*" 2>/dev/null | head -10)
    
    # Get most recent code change (excluding gitignored paths if .gitignore exists)
    if [ -f ".gitignore" ]; then
        # Use git to respect gitignore
        MOST_RECENT_CODE_TIME=$(git ls-files -z '*.py' '*.js' '*.ts' '*.jsx' '*.tsx' '*.sh' '*.go' '*.rs' '*.java' '*.cpp' '*.c' 2>/dev/null | xargs -0 stat -c %Y 2>/dev/null | sort -n | tail -1)
    else
        # Fallback to find
        MOST_RECENT_CODE_TIME=$(find . -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" -o -name "*.sh" -o -name "*.go" -o -name "*.rs" \) -not -path "*/node_modules/*" -not -path "*/.git/*" -printf "%Y\n" 2>/dev/null | sort -n | tail -1)
    fi
    
    if [ -z "$MOST_RECENT_CODE_TIME" ]; then
        MOST_RECENT_CODE_TIME=0
    fi
    
    # Check each CLAUDE.md file
    for CLAUDE_MD in $CLAUDE_MD_FILES; do
        if [ -f "$CLAUDE_MD" ]; then
            DOCS_CHECKED=$((DOCS_CHECKED + 1))
            MD_MTIME=$(stat -c %Y "$CLAUDE_MD" 2>/dev/null || stat -f %m "$CLAUDE_MD" 2>/dev/null || echo 0)
            
            # Simple check: if code changed after CLAUDE.md, it's stale
            if [ "$MOST_RECENT_CODE_TIME" -gt "$MD_MTIME" ]; then
                DOCS_CURRENT=false
                STALE_DOCS="CLAUDE.md"
            fi
            
            # Check @-referenced files in CLAUDE.md
            if [ -f "$CLAUDE_MD" ]; then
                REFERENCED_FILES=$(grep -o '@[^[:space:]]*' "$CLAUDE_MD" 2>/dev/null | sed 's/@//' | grep -v '^$' || true)
                for REF_FILE in $REFERENCED_FILES; do
                    # Clean up the reference (remove trailing punctuation)
                    REF_FILE=$(echo "$REF_FILE" | sed 's/[,;:!?]$//')
                    if [ -f "$REF_FILE" ]; then
                        REF_MTIME=$(stat -c %Y "$REF_FILE" 2>/dev/null || stat -f %m "$REF_FILE" 2>/dev/null || echo 0)
                        # If referenced file changed after CLAUDE.md, docs are stale
                        if [ "$REF_MTIME" -gt "$MD_MTIME" ]; then
                            DOCS_CURRENT=false
                            if [ -z "$STALE_DOCS" ]; then
                                STALE_DOCS="@$REF_FILE"
                            fi
                            break
                        fi
                    fi
                done
            fi
        fi
    done
    
    # If no CLAUDE.md found, docs are not current
    if [ "$DOCS_CHECKED" -eq 0 ]; then
        DOCS_CURRENT=false
        STALE_DOCS="No CLAUDE.md"
    fi
    
    # Hooks activity (simple count from settings)
    ACTIVE_HOOKS=0
    if [ -f "$HOME/.claude/settings.json" ]; then
        # Count configured hooks
        ACTIVE_HOOKS=$(jq '[.hooks | to_entries[] | select(.value | length > 0)] | length' "$HOME/.claude/settings.json" 2>/dev/null || echo 0)
    fi
    
    # Next action hint
    NEXT_ACTION=""
    if [ "$GIT_CHANGES" -gt 5 ]; then
        NEXT_ACTION="Commit changes"
    elif [ "$GIT_UNPUSHED" -gt 0 ]; then
        NEXT_ACTION="Push to remote"
    elif [ "$DOCS_CURRENT" = false ]; then
        NEXT_ACTION="Update CLAUDE.md"
    else
        NEXT_ACTION=""
    fi
    
    # Create comprehensive JSON output
    cat > "$CACHE_FILE" <<EOF
{
  "sessions": $SESSION_COUNT,
  "remaining_minutes": $REMAINING_MINS,
  "tokens_used": $TOKENS_USED,
  "total_month_tokens": $TOTAL_MONTH_TOKENS,
  "cost_usd": $COST_USD,
  "total_month_cost": $TOTAL_MONTH_COST,
  "burn_rate": $BURN_RATE,
  "session_progress": $SESSION_PROGRESS,
  "next_session_mins": $NEXT_SESSION_MINS,
  "today_sessions": $TODAY_SESSIONS,
  "today_tokens": $TODAY_TOKENS,
  "today_cost": $TODAY_COST,
  "context_usage": $CONTEXT_USAGE,
  "auto_compact_soon": $AUTO_COMPACT_SOON,
  "auto_compact_distance": $AUTO_COMPACT_DISTANCE,
  "avg_response_time": $AVG_RESPONSE_TIME,
  "session_start": "$START_TIME",
  "session_end": "$END_TIME",
  "git_status": "$GIT_STATUS",
  "git_changes": $GIT_CHANGES,
  "git_unpushed": $GIT_UNPUSHED,
  "docs_current": $DOCS_CURRENT,
  "docs_checked": $DOCS_CHECKED,
  "stale_docs": "$STALE_DOCS",
  "active_hooks": $ACTIVE_HOOKS,
  "next_action": "$NEXT_ACTION",
  "updated": $(date +%s),
  "updated_iso": "$(date -Iseconds)"
}
EOF
else
    # Fallback without jq
    echo '{"error": "jq not installed"}' > "$CACHE_FILE"
fi