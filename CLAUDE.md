# Eric's Claude Setup - Configuration Guide

## Overview

This repository contains my personal development environment configurations, organized by operating system (macOS and Ubuntu). It serves as a reference implementation for others to learn from and adapt to their own needs.

## Repository Structure

```
.claude-ericbuess/
├── macos/              # macOS configurations
│   ├── claude/         # Claude CLI settings and hooks
│   ├── shell/          # Zsh configuration files
│   ├── tmux/           # Terminal multiplexer config
│   ├── nvim/           # Neovim configuration
│   ├── git/            # Git configuration
│   ├── ssh/            # SSH config (no keys)
│   └── vim/            # Vim configuration
│
├── ubuntu/             # Ubuntu/Linux configurations
│   ├── claude/         # Claude CLI settings and hooks
│   ├── shell/          # Bash configuration files
│   ├── tmux/           # Terminal multiplexer config
│   ├── nvim/           # Neovim configuration
│   ├── git/            # Git configuration
│   ├── ssh/            # SSH config (no keys)
│   └── vim/            # Vim configuration
│
├── sync.sh             # Sync script for managing configs
├── README.md           # Public-facing documentation
├── CLAUDE.md           # This file - for Claude CLI
└── .gitignore          # Excludes secrets and temp files
```

## Using the Sync Script

The `sync.sh` script manages configurations between your home directory and this repository. It automatically detects your OS and syncs to/from the appropriate directory.

### Commands

```bash
./sync.sh status    # Check sync status (default)
./sync.sh push      # Push configs from home to repo
./sync.sh pull      # Pull configs from repo to home
```

### What Gets Synced

**Shell Configurations:**
- macOS: `.zshrc` → `macos/shell/rc`, `.zprofile` → `macos/shell/profile`
- Ubuntu: `.bashrc` → `ubuntu/shell/rc`, `.bash_profile` → `ubuntu/shell/profile`

**Development Tools:**
- `.tmux.conf` → `{os}/tmux/tmux.conf`
- `.config/nvim/` → `{os}/nvim/`
- `.vimrc` → `{os}/vim/vimrc`
- `.gitconfig` → `{os}/git/gitconfig`

**Claude CLI:**
- `.claude/settings.json` → `{os}/claude/settings.json`
- `.claude/hooks/` → `{os}/claude/hooks/`

**SSH (config only, no keys):**
- `.ssh/config` → `{os}/ssh/config`

## Philosophy

This follows the "Eric's Lab" philosophy:
- **Not for installation** - It's for learning and inspiration
- **Not a product** - It's my actual working environment
- **Not stable** - It changes based on my needs
- **Not supported** - No issues or pull requests

## For Claude CLI Users

When pointing Claude at this repository:

```bash
# Get inspiration for your own setup
claude "Look at https://github.com/ericbuess/.claude-ericbuess and help me create a similar configuration structure"

# Understand specific configurations
claude "Explain the tmux configuration in the ubuntu directory"

# Adapt patterns to your needs
claude "Based on Eric's shell configuration, help me set up similar aliases for my workflow"
```

## Related Projects

- **[claude-code-project-index](https://github.com/ericbuess/claude-code-project-index)** - Indexes codebases for Claude context
- **[vm-bridge](https://github.com/ericbuess/vm-bridge)** - VM-to-host communication utilities

## Important Notes

1. **Secrets are excluded** - All sensitive data is gitignored
2. **OS detection is automatic** - The sync script detects macOS vs Linux
3. **Configs are real** - These are my actual working configurations
4. **Changes are frequent** - This is a living repository

## Quick Start

1. Clone this repository to `~/.claude-ericbuess`
2. Review configurations in your OS directory
3. Use `./sync.sh status` to see what would sync
4. Adapt ideas to your own workflow

Remember: This is meant to inspire your own setup, not to be copied directly.