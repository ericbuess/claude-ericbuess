# Quick Commands to Continue Work

## Start New Session
```bash
cd ~/Projects/claude-ericbuess
claude-code
```

## First Message to Claude
Copy and paste this entire message:

```
Please read CONTINUE_WORK.md and help me continue the statusline work. 

The previous session corrupted while restructuring statusline paths and adding Bible verses. Some changes are already done, but we need to:
1. Update the cache-updater scripts with new paths
2. Apply the same changes to Ubuntu statusline 
3. Test everything works
4. Commit the changes

Start by reading CONTINUE_WORK.md to get the full context, then let's complete the remaining tasks.
```

## Alternative: Detailed First Message
If you want Claude to have maximum context, use this instead:

```
I was working on restructuring my claude-ericbuess repo's statusline component. The session corrupted but I saved the work progress in CONTINUE_WORK.md.

Already completed:
- Moved session data from ~/.claude-ericbuess/ to ~/Projects/claude-ericbuess/session-data/
- Updated macOS statusline.sh with new paths
- Added Bible verse rotation to macOS statusline

Still need to do:
- Update cache-updater.sh and cache-updater-ultra.sh with new paths
- Apply all changes to Ubuntu statusline scripts
- Test everything
- Commit and push

Please read CONTINUE_WORK.md and help me finish this work.
```

## Quick Test After Changes
```bash
# Test macOS statusline
~/Projects/claude-ericbuess/macos/statusline/scripts/statusline.sh

# Test Ubuntu statusline (if on Ubuntu)
~/Projects/claude-ericbuess/ubuntu/statusline/scripts/statusline.sh

# Check what changed
cd ~/Projects/claude-ericbuess
git status
git diff
```

## Final Commit Command
```bash
cd ~/Projects/claude-ericbuess
git add -A
git commit -m "Restructure statusline paths and add Bible verse integration

- Moved session data from ~/.claude-ericbuess to repo's session-data/
- Added daily rotating Bible verses to statusline (7 verses)
- Updated all path references in scripts
- Made statusline self-contained within repo
- Applied changes to both macOS and Ubuntu versions

Previous session corrupted during this work - completed successfully in new session."
git push
```

## If Claude Needs More Context
Tell Claude to also read:
- `macos/statusline/README.md` - for understanding the statusline system
- `PROJECT_INDEX.json` - for understanding the repo structure
- Check git status to see what files were already modified

## Recovery Note
Don't use `claude-code -c` - the session file is corrupted. Start fresh with these instructions.