# Claude Code Ultra StatusLine

A comprehensive two-line statusline for Claude Code with real-time metrics, cost tracking, and environment awareness.

## Features

### Core Display
- **Model Indicator**: Shows which Claude model you're using (🧠 Opus, ⚡ Sonnet, 💨 Haiku)
- **User@Host:Directory**: Standard terminal-style location display
- **Session Tracking**: Color-coded session count (🟢 <35, 🟡 35-45, 🔴 >45)
- **Time Remaining**: Shows time left in current 5-hour session block
- **Token Usage**: Displays tokens used in current session

### Smart Enhancements
- **Git Integration**: Shows current branch and change indicators
- **Project Type Detection**: Automatically detects project type (📦 JS, 🐍 Python, 🦀 Rust, etc.)
- **Memory Status**: Shows 📝 when CLAUDE.md is present
- **Permission Mode**: Displays current permission mode (✅ accept, 📋 plan)

## Installation

The statusline is already installed at:
```
~/.claude-code-ericbuess/statusline/
```

### Components
- `scripts/statusline-enhanced.sh` - Main statusline display script
- `scripts/cache-updater.sh` - Updates session metrics cache
- `cache/session-status.json` - Cached session data

### Cron Job
A cron job updates the cache every minute:
```bash
* * * * * /home/ericbuess/.claude-code-community-tools/statusline/scripts/cache-updater.sh
```

## Example Output

### Ultra StatusLine (Two Lines)
```
[🧠 Opus] user@host:~/Projects/app 📦 📝 | 🟢 22/50 | ⏳ 4h47m | 📊 1.2M | 🌿 main
░░░░░░░░░░ 4% | 💰 $3.49 | 🔥 396K/min | 📝 Context: 15% | 🐍 venv | Today: 2s/$8.50
```

### Line 1 Components:
- `[🧠 Opus]` - Model indicator (🧠 Opus, ⚡ Sonnet, 💨 Haiku)
- `user@host:~/Projects/app` - Location with ~/ relative paths
- `📦` - Project type (📦 JS, 🐍 Python, 🦀 Rust, 🐹 Go)
- `📝` - CLAUDE.md present
- `🟢 22/50` - Session count (🟢 <35, 🟡 35-45, 🔴 >45)
- `⏳ 4h47m` - Time remaining (⏳ >2h, ⏱️ 30m-2h, ⏰ <30m)
- `📊 1.2M` - Tokens used this session
- `🌿 main` - Git branch (yellow * if changes)

### Line 2 Components:
- `░░░░░░░░░░ 4%` - Visual progress bar for 5-hour session
- `💰 $3.49` - Current session cost
- `🔥 396K/min` - Token burn rate (🔥 if >1M/min)
- `📝 Context: 15%` - Context window usage (⚠️ if >80%)
- `🐍 venv` - Python virtual environment
- `🐳 3` - Docker containers running
- `Today: 2s/$8.50` - Daily sessions and cost
- `Next: 3h45m` - Time until next session (when current ends)
- `🔄 Compact soon!` - Auto-compact warning

## Switching Between Versions

### Use Ultra Version (Two Lines - All Features)
```bash
# Edit ~/.claude/settings.json
"statusLine": {
  "type": "command",
  "command": "/home/ericbuess/.claude-code-community-tools/statusline/scripts/statusline-ultra.sh"
}
```

### Use Enhanced Version (Single Line)
```bash
# Edit ~/.claude/settings.json
"statusLine": {
  "type": "command",
  "command": "/home/ericbuess/.claude-code-community-tools/statusline/scripts/statusline-enhanced.sh"
}
```

### Use Basic Version (Minimal)
```bash
# Edit ~/.claude/settings.json
"statusLine": {
  "type": "command",
  "command": "/home/ericbuess/.claude-code-community-tools/statusline/scripts/statusline.sh"
}
```

## Performance

- Git operations are cached for 30 seconds
- Session data is cached for 1 minute
- Cache staleness threshold: 2 minutes
- Automatic cleanup of old cache files

## Troubleshooting

### StatusLine Not Updating
1. Check cron job: `crontab -l`
2. Manually update cache: `/home/ericbuess/.claude-code-community-tools/statusline/scripts/cache-updater.sh`
3. Verify cache: `cat ~/.claude-code-ericbuess/statusline/cache/session-status.json`

### Missing Features
- Ensure `jq` is installed: `which jq`
- Check npm/npx availability: `which npx`
- Verify git installation: `which git`

## Customization

Edit the scripts in `~/.claude-code-ericbuess/statusline/scripts/` to customize:
- Color schemes
- Information displayed
- Icon choices
- Threshold values

Remember to restart Claude Code after making changes to see updates.