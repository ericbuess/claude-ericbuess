# Simple Claude Statusline

A dead-simple statusline for Claude Code CLI that uses git-based session tracking.

## How It Works

1. **No cache, no cron, no complexity**
2. Session data stored in `~/Projects/claude-ericbuess/session-data/session-data.json`
3. Automatically runs `ccusage` only when needed:
   - First interaction in a new 5-hour session
   - When remaining time hits 0
4. Data synced via git between machines

## What It Shows

```
user@host:dir | 🟢 14/50 ⏳ 3h41m 📊 1.7M 🌿 branch*
```

- Session count with color coding (🟢 green, 🟡 yellow, 🔴 red)
- Time remaining in current session
- Tokens used (if available)
- Git branch and changes

## Setup

1. Script is at: `~/Projects/claude-ericbuess/macos/statusline/scripts/statusline.sh`
2. Configured in `~/.claude/settings.json`:
```json
"statusLine": {
  "type": "command", 
  "command": "/Users/ericbuess/Projects/claude-ericbuess/macos/statusline/scripts/statusline.sh"
}
```

## Multi-Machine Sync

The session data at `~/Projects/claude-ericbuess/session-data/` is tracked in the main repo.
It syncs automatically when you push/pull the main repository.

Then on other machines, it will auto-pull before reading.

## Notes

- Context usage detection removed (too complex to get current session file)
- No background processes needed
- Updates only when starting a new session