# Eric's Claude Setup

⚠️ **This is not a dotfiles installer** ⚠️

This is my personal Claude and development environment configuration.
It exists for educational purposes - to show how I work.

## What This Is

- **My actual working configuration** - These are the real files I use daily
- **A reference for video tutorials** - See how things connect in practice
- **An example of tool organization** - One way to structure a dev environment
- **A living, changing toolkit** - Constantly evolving based on my needs

## What This Is NOT

- **Not a product for installation** - Don't install this directly
- **Not a maintained package** - No version guarantees or stability
- **Not a stable API** - Everything can change without notice
- **Not a supported tool** - No issues, no PRs, no support

## How to Use This Repository

1. **Browse the code on GitHub** - Understand the organization
2. **Watch the videos for context** - Learn the thinking behind decisions
3. **Understand the patterns** - See how problems are solved
4. **Build your own version** - Take ideas, not code

## The "Eric's Lab" Philosophy

I share my workshop, not products.

This repository is like walking into my garage and seeing my tools laid out on the workbench. You can see what I use, how I organize things, and maybe get ideas for your own setup. But you wouldn't take my tools home - you'd go buy your own and arrange them for your needs.

**Take ideas, not code.**

## Repository Structure

```
.
├── macos/          # macOS configurations
│   ├── claude/     # Claude CLI settings and hooks
│   ├── shell/      # Zsh configuration
│   ├── tmux/       # Terminal multiplexer
│   ├── nvim/       # Neovim setup
│   └── git/        # Git configuration
│
├── ubuntu/         # Ubuntu/Linux configurations
│   ├── claude/     # Claude CLI settings and hooks
│   ├── shell/      # Bash configuration
│   ├── tmux/       # Terminal multiplexer
│   ├── nvim/       # Neovim setup
│   └── git/        # Git configuration
│
└── sync.sh         # Sync script for managing configs
```

### How sync.sh Works

The `sync.sh` script manages configs between your home directory and this repository:

```bash
./sync.sh status  # Check what's different
./sync.sh push    # Push configs from ~ to repo
./sync.sh pull    # Pull configs from repo to ~
```

## Related Projects

My other tools that complement this setup:

- **[claude-code-project-index](https://github.com/ericbuess/claude-code-project-index)** - Tool for indexing codebases for Claude context
- **[claude-code-docs](https://github.com/ericbuess/claude-code-docs)** - Documentation helper for Claude CLI
- **[vm-bridge](https://github.com/ericbuess/vm-bridge)** - VM-to-host communication utilities

## For Video Viewers

If you're here from a video:
1. The code you saw is probably in here somewhere
2. Remember: adapt, don't adopt
3. Build your own version that fits your workflow

## For the Curious

Feel free to explore, learn, and get inspired. But remember:
- Your workflow is not my workflow
- Your needs are not my needs  
- Your style is not my style

Build something that works for YOU.

---

See [CLAUDE.md](CLAUDE.md) for technical implementation details.

*Last updated when I last updated it. No schedule. No promises.*