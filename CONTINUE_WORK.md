# Continue Statusline Work - Session Recovery Instructions

## Quick Start Command
```bash
cd ~/Projects/claude-ericbuess
claude-code
# Then ask Claude to: "Please read CONTINUE_WORK.md and continue the statusline work"
```

## Project Context
This is the claude-ericbuess repository - Eric's personal development environment configurations for macOS and Ubuntu. The statusline component provides real-time Claude usage statistics in the terminal.

## Work Already Completed
The following changes were successfully made before the session corrupted:

### 1. Path Restructuring - COMPLETED ✅
Moved session data from `~/.claude-ericbuess/` to `~/Projects/claude-ericbuess/session-data/`

**File: `/Users/ericbuess/Projects/claude-ericbuess/macos/statusline/scripts/statusline.sh`**
- Changed `SESSION_DATA="$HOME/.claude-ericbuess/session-data.json"` to `SESSION_DATA="$REPO_ROOT/session-data/session-data.json"`
- Changed `SESSION_REPO="$HOME/.claude-ericbuess"` to `SESSION_REPO="$REPO_ROOT/session-data"`
- Added `REPO_ROOT="$HOME/Projects/claude-ericbuess"` at the top

### 2. Bible Verse Integration - PARTIALLY COMPLETED ⚠️
Added daily rotating Bible verses to the macOS statusline output.

**Added to statusline.sh after line 77 (before the final OUTPUT):**
```bash
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
```

## Tasks To Complete

### 1. Update Cache Updater Scripts
**Files to modify:**
- `/Users/ericbuess/Projects/claude-ericbuess/macos/statusline/scripts/cache-updater.sh`
- `/Users/ericbuess/Projects/claude-ericbuess/macos/statusline/scripts/cache-updater-ultra.sh`

**Changes needed:**
```bash
# At the top of each file, add:
REPO_ROOT="$HOME/Projects/claude-ericbuess"

# Then change:
CACHE_DIR="$HOME/.claude-code-ericbuess/statusline/cache"
# To:
CACHE_DIR="$REPO_ROOT/session-data/cache"

# In cache-updater-ultra.sh also change:
HOOK_CONTEXT_CACHE="$HOME/.claude-code-ericbuess/statusline/cache/context-usage.json"
# To:
HOOK_CONTEXT_CACHE="$REPO_ROOT/session-data/cache/context-usage.json"
```

### 2. Apply Same Changes to Ubuntu Statusline
**Files to modify:**
- `/Users/ericbuess/Projects/claude-ericbuess/ubuntu/statusline/scripts/statusline.sh`
- `/Users/ericbuess/Projects/claude-ericbuess/ubuntu/statusline/scripts/cache-updater.sh`
- `/Users/ericbuess/Projects/claude-ericbuess/ubuntu/statusline/scripts/cache-updater-ultra.sh`

Apply the same path changes and Bible verse integration as done for macOS.

### 3. Update Claude CLI Settings
**File:** `~/.claude/settings.json`

Update the statusline command paths if they reference the old locations.

### 4. Update tmux Configuration
**Files to check:**
- `~/Projects/claude-ericbuess/macos/.tmux.conf`
- `~/Projects/claude-ericbuess/ubuntu/.tmux.conf`

Ensure any statusline references use the new paths.

### 5. Create/Update sync.sh Script
Ensure the sync script handles the new `session-data/` directory properly for syncing between machines.

### 6. Test Everything
```bash
# Test the statusline directly
~/Projects/claude-ericbuess/macos/statusline/scripts/statusline.sh

# Test in tmux
tmux
# Check if statusline appears correctly

# Run cache updater
~/Projects/claude-ericbuess/macos/statusline/scripts/cache-updater.sh
```

### 7. Commit and Push Changes
```bash
cd ~/Projects/claude-ericbuess
git add -A
git commit -m "Restructure statusline paths and add Bible verse integration

- Moved session data from ~/.claude-ericbuess to repo's session-data/
- Added daily rotating Bible verses to statusline
- Updated all path references in scripts
- Made statusline more self-contained within repo"
git push
```

## Additional Context

### Directory Structure After Changes
```
~/Projects/claude-ericbuess/
├── session-data/           # NEW - Centralized session data
│   ├── cache/             # Cache files for statusline
│   ├── machines/          # Machine-specific data
│   └── session-data.json  # Main session data file
├── macos/
│   └── statusline/
│       └── scripts/       # Updated scripts with new paths
└── ubuntu/
    └── statusline/
        └── scripts/       # Need to update these too
```

### Philosophy Notes
The statusline remains in the main repo because:
- It's part of Eric's complete development environment
- Benefits from unified git synchronization
- Follows the "Eric's Lab" philosophy of sharing the complete workshop
- Makes the entire system self-contained and portable

## Error Recovery Note
The previous session file at `~/.claude/projects/-Users-ericbuess-Projects-claude-ericbuess/f28a550d-ced1-41f4-944f-acc60ecb6b50.jsonl` is corrupted with tool_use/tool_result misalignment. Don't try to continue with `-c`. Start fresh and use these instructions.

## Quick Verification Commands
After making changes, verify with:
```bash
# Check if paths exist
ls -la ~/Projects/claude-ericbuess/session-data/

# Test statusline
~/Projects/claude-ericbuess/macos/statusline/scripts/statusline.sh

# Check git status
cd ~/Projects/claude-ericbuess && git status
```