# Complete Session Recovery Instructions

## IMMEDIATE ACTION REQUIRED
Read this entire file first, then execute the tasks listed below. The previous session corrupted while working on statusline restructuring. This file contains everything you need to continue.

## FILES TO READ FOR CONTEXT
Please read these files in this exact order to understand the project:
1. `/Users/ericbuess/Projects/claude-ericbuess/PROJECT_INDEX.json` - Overview of repo structure
2. `/Users/ericbuess/Projects/claude-ericbuess/CLAUDE.md` - Project philosophy and guidelines  
3. `/Users/ericbuess/Projects/claude-ericbuess/macos/statusline/README.md` - Statusline documentation
4. `/Users/ericbuess/Projects/claude-ericbuess/.claude/commands/index.md` - Check for any custom commands

## PROJECT CONTEXT
- **Repository:** claude-ericbuess - Eric's personal development environment configurations
- **Current Task:** Restructuring statusline paths and adding Bible verse integration
- **Philosophy:** Keep statusline in main repo as part of complete dev environment ("Eric's Lab")

## WORK ALREADY COMPLETED - DO NOT REDO
The following changes were already successfully made:

### 1. macOS Statusline Script Updated ✅
**File:** `/Users/ericbuess/Projects/claude-ericbuess/macos/statusline/scripts/statusline.sh`

**Changes made:**
- Line 5: Added `REPO_ROOT="$HOME/Projects/claude-ericbuess"`
- Line 10: Changed to `SESSION_DATA="$REPO_ROOT/session-data/session-data.json"`  
- Line 30: Changed to `SESSION_REPO="$REPO_ROOT/session-data"`
- Lines 78-92: Added Bible verse rotation code (see below)

**Bible verse code added after line 77:**
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

## TASKS TO COMPLETE - DO THESE NOW

### Task 1: Update macOS Cache Updater Scripts
**Files to modify:**
1. `/Users/ericbuess/Projects/claude-ericbuess/macos/statusline/scripts/cache-updater.sh`
2. `/Users/ericbuess/Projects/claude-ericbuess/macos/statusline/scripts/cache-updater-ultra.sh`

**Required changes for BOTH files:**
```bash
# Add at top after shebang and comments:
REPO_ROOT="$HOME/Projects/claude-ericbuess"

# Change this line:
CACHE_DIR="$HOME/.claude-code-ericbuess/statusline/cache"
# To:
CACHE_DIR="$REPO_ROOT/session-data/cache"
```

**Additional change for cache-updater-ultra.sh only:**
```bash
# Find and change:
HOOK_CONTEXT_CACHE="$HOME/.claude-code-ericbuess/statusline/cache/context-usage.json"
# To:
HOOK_CONTEXT_CACHE="$REPO_ROOT/session-data/cache/context-usage.json"
```

### Task 2: Update Ubuntu Statusline (Mirror macOS Changes)
**Files to modify:**
1. `/Users/ericbuess/Projects/claude-ericbuess/ubuntu/statusline/scripts/statusline.sh`
2. `/Users/ericbuess/Projects/claude-ericbuess/ubuntu/statusline/scripts/cache-updater.sh`
3. `/Users/ericbuess/Projects/claude-ericbuess/ubuntu/statusline/scripts/cache-updater-ultra.sh`

**Apply the EXACT SAME changes as macOS:**
- Add `REPO_ROOT` variable
- Update all paths from `~/.claude-code-ericbuess` to `$REPO_ROOT/session-data`
- Add the Bible verse rotation code to statusline.sh

### Task 3: Create Session Data Directory Structure
```bash
# Create the directories if they don't exist:
mkdir -p ~/Projects/claude-ericbuess/session-data/cache
mkdir -p ~/Projects/claude-ericbuess/session-data/machines
```

### Task 4: Test Everything
```bash
# Test macOS statusline
~/Projects/claude-ericbuess/macos/statusline/scripts/statusline.sh

# Run cache updater
~/Projects/claude-ericbuess/macos/statusline/scripts/cache-updater.sh

# Check if cache files are created in new location
ls -la ~/Projects/claude-ericbuess/session-data/cache/
```

### Task 5: Commit and Push Changes
```bash
cd ~/Projects/claude-ericbuess
git add -A
git commit -m "Restructure statusline paths and add Bible verse integration

- Moved session data from ~/.claude-ericbuess to repo's session-data/
- Added daily rotating Bible verses to statusline (7 verses)
- Updated all path references in scripts for both macOS and Ubuntu
- Created centralized session-data directory structure
- Made statusline self-contained within repo for better portability

Bible verses rotate daily:
- Philippians 4:13, Proverbs 3:5, Psalm 23:1
- John 3:16, Romans 8:28, Joshua 1:9, Jeremiah 29:11"
git push
```

## VERIFICATION CHECKLIST
After completing all tasks, verify:
- [ ] All 6 scripts updated (3 macOS, 3 Ubuntu)
- [ ] `session-data/` directory exists with `cache/` and `machines/` subdirs
- [ ] Statusline displays Bible verse when run
- [ ] Cache updater creates files in new location
- [ ] All changes committed and pushed

## IMPORTANT NOTES
1. Do NOT try to fix or reference the corrupted session file
2. Do NOT use any path with `~/.claude-code-ericbuess` - everything should use `$REPO_ROOT/session-data`
3. The repo root is `/Users/ericbuess/Projects/claude-ericbuess`
4. Test commands should work immediately after changes

## ERROR CONTEXT (FYI Only)
The previous session file corrupted with tool_use/tool_result misalignment errors. This is why we're starting fresh. The work described above was extracted from the corrupted session before it failed.

## ORIGINAL SESSION FILE FOR REFERENCE
If you need more context about what was being worked on, the original session file is preserved at:
`~/.claude/projects/-Users-ericbuess-Projects-claude-ericbuess/f28a550d-ced1-41f4-944f-acc60ecb6b50.jsonl.original`

You can use the Task tool with a subagent to extract specific information if needed:
```
Use Task tool with general-purpose agent to analyze the session file and extract any relevant context about the statusline work, focusing on user messages and successful tool executions.
```

**Note:** The session has structural corruption (duplicate message IDs, misaligned tool_use/tool_result blocks) but the content is readable. Focus on extracting what was actually done, not fixing the structure.

## EXECUTION ORDER
1. Read the context files listed at the top
2. Create session-data directories (Task 3)
3. Update all script files (Tasks 1-2)
4. Test everything works (Task 4)
5. Commit and push (Task 5)

---
END OF INSTRUCTIONS - Start with reading the context files, then execute the tasks in order.