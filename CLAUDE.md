# Eric's Claude Setup - Migration & Configuration Guide

## 🎯 Primary Goal
Transform scattered configuration repositories into a single, unified personal toolkit at `~/.claude-ericbuess` that works seamlessly across Mac and Linux, following the "Eric's Lab" philosophy of sharing working code for education, not distribution.

## 📋 Current State Assessment
You are migrating from:
1. `~/.claude-code-ericbuess/` - Old tools and configs (mostly obsolete)
2. `https://github.com/ericbuess/ubuntu-user-root/` - Linux dotfiles tracked from ~/
3. `https://github.com/ericbuess/mac-user-root/` - Mac dotfiles tracked from ~/
4. `~/Projects/vm-bridge/` - VM-to-Mac bridge tools
5. `~/Projects/claude-code-project-index/` - Project indexing tool

## 🚀 Migration Strategy

### Phase 1: Repository Setup
1. Initialize this directory as a git repository
2. Create the directory structure
3. Set up the sync.sh tool
4. Configure git with appropriate .gitignore

### Phase 2: Config Migration
1. Pull essential configs from ubuntu-user-root
2. Identify Mac-specific configs from mac-user-root
3. Extract reusable tools from .claude-code-ericbuess
4. Set up vm-bridge as a tool subdirectory

### Phase 3: Cleanup
1. Archive old repos with "MOVED TO" notices
2. Update any references in existing projects
3. Test sync between Mac and Linux

## 📁 Target Directory Structure
```
~/.claude-ericbuess/
├── README.md                   # "Eric's Lab" philosophy & disclaimers
├── CLAUDE.md                   # This file - instructions for Claude
├── sync.sh                     # Bidirectional Mac/Linux sync tool
├── .gitignore                  # Ignore secrets, caches, etc.
├── configs/
│   ├── mac/                   # Mac-specific configs
│   │   ├── shell-rc           # .zshrc content
│   │   ├── claude-settings.json
│   │   └── ...
│   ├── linux/                 # Linux-specific configs
│   │   ├── shell-rc           # .bashrc content
│   │   ├── claude-settings.json
│   │   └── ...
│   └── shared/                # Cross-platform configs
│       ├── tmux.conf
│       ├── claude-hooks/
│       ├── nvim/
│       └── ...
├── tools/                      # Personal tools/scripts
│   ├── vm-bridge/             # VM-to-Mac communication
│   ├── project-index/         # Link or submodule
│   └── scripts/               # Various utility scripts
├── projects/                   # Git submodules to active projects
│   └── [submodules as needed]
└── docs/
    ├── videos/                 # Video transcripts/examples
    └── archive/                # Old documentation for reference
```

## 💡 Philosophy: "Eric's Lab"

### Core Principles
1. **This is not a product** - It's Eric's actual working environment
2. **This is not for installation** - It's for learning and inspiration
3. **This is not supported** - It changes based on Eric's needs
4. **This is not stable** - It's a living, evolving toolkit

### Sharing Model
- **Browse on GitHub** to understand organization
- **Watch videos** to understand thinking
- **Clone to explore** but adapt to your needs
- **Copy what resonates** but make it yours

### Documentation Approach
- Video-first explanations
- Code as reference implementation
- No installation instructions
- No issue tracking
- No feature requests

## 🔧 Implementation Steps

### Step 1: Initialize Repository
```bash
cd ~/.claude-ericbuess
git init
git branch -m main
```

### Step 2: Create Directory Structure
```bash
mkdir -p configs/{mac,linux,shared}
mkdir -p configs/shared/claude-hooks
mkdir -p tools/{vm-bridge,scripts}
mkdir -p projects
mkdir -p docs/{videos,archive}
```

### Step 3: Create Sync Tool
Create `sync.sh` with OS detection and bidirectional sync:
```bash
#!/bin/bash
# Detects Mac vs Linux
# Maps configs to appropriate locations
# Handles push (system→repo) and pull (repo→system)
```

Key features:
- Auto-detect OS (Darwin=Mac, Linux=Linux)
- Map shell-rc to .zshrc (Mac) or .bashrc (Linux)
- Sync shared configs to same locations
- Handle directories with rsync, files with cp

### Step 4: Import from ubuntu-user-root

Essential files to migrate:
```bash
# From https://github.com/ericbuess/ubuntu-user-root/
.bashrc                 → configs/linux/shell-rc
.tmux.conf             → configs/shared/tmux.conf
.vimrc                 → configs/shared/vimrc
.claude/               → configs/shared/claude-hooks/
.config/nvim/          → configs/shared/nvim/
```

### Step 5: Import from mac-user-root

Essential files to migrate:
```bash
# From https://github.com/ericbuess/mac-user-root/
.zshrc                 → configs/mac/shell-rc
.claude/settings.json  → configs/mac/claude-settings.json
# Any Mac-specific configs
```

### Step 6: Extract from .claude-code-ericbuess

Salvage useful items:
```bash
# Tools and scripts that are still relevant
tools/                 → tools/scripts/
# Any hooks that still work
hooks/                 → configs/shared/claude-hooks/
```

### Step 7: Integrate vm-bridge

Move vm-bridge to tools:
```bash
# If it exists locally
cp -r ~/Projects/vm-bridge/* tools/vm-bridge/
# Or as submodule if it has its own repo
git submodule add [vm-bridge-repo] tools/vm-bridge
```

### Step 8: Create README.md
```markdown
# Eric's Claude Setup

⚠️ **This is not a dotfiles installer** ⚠️

This is my personal Claude and development environment configuration.
It exists for educational purposes - to show how I work.

## What This Is
- My actual working configuration
- A reference for video tutorials
- An example of tool organization
- A living, changing toolkit

## What This Is NOT
- A product for installation
- A maintained package
- A stable API
- A supported tool

## How to Use This Repository
1. Browse the code on GitHub
2. Watch the videos for context
3. Understand the patterns
4. Build your own version

## Philosophy
I share my workshop, not products. Take ideas, not code.

See CLAUDE.md for technical details.
```

### Step 9: Configure Git
Create `.gitignore`:
```
# Secrets and sensitive data
.secrets/
*.secret
*_secret*
.env
.env.*

# Cache and temporary files
*.cache
*.tmp
.DS_Store

# Build artifacts
build/
dist/
*.pyc
__pycache__/

# Personal notes
personal/
NOTES_PRIVATE.md
```

### Step 10: Archive Old Repositories

Create "MOVED TO" notices in:
1. `~/.claude-code-ericbuess/README.md`
2. `ubuntu-user-root/README.md`
3. `mac-user-root/README.md`

Content:
```markdown
# MOVED TO ~/.claude-ericbuess

This repository has been consolidated into:
https://github.com/ericbuess/.claude-ericbuess

The new structure provides:
- Unified Mac/Linux configuration
- Better organization
- Single source of truth

This repo is archived for historical reference only.
```

## 🎬 Quick Start Commands

For a fresh Claude instance to execute:

```bash
# 1. Initialize the repository
cd ~/.claude-ericbuess
git init
git branch -m main

# 2. Create structure
mkdir -p configs/{mac,linux,shared} tools projects docs

# 3. Create sync.sh tool (see sync.sh content below)
# 4. Make it executable
chmod +x sync.sh

# 5. Start migration
./sync.sh status  # See what would sync
./sync.sh push    # Save current configs to repo

# 6. Commit initial structure
git add -A
git commit -m "Initial structure with migration plan"
```

## 📝 sync.sh Content

```bash
#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE=${1:-status}

# Detect OS
case "$(uname -s)" in
    Darwin*)
        OS="mac"
        SHELL_RC=".zshrc"
        ;;
    Linux*)
        OS="linux"
        SHELL_RC=".bashrc"
        ;;
    *)
        echo "Unknown OS"
        exit 1
        ;;
esac

# Configuration mapping
declare -A CONFIG_MAP=(
    ["$SHELL_RC"]="configs/$OS/shell-rc"
    [".tmux.conf"]="configs/shared/tmux.conf"
    [".vimrc"]="configs/shared/vimrc"
    [".claude/hooks"]="configs/shared/claude-hooks"
    [".config/nvim"]="configs/shared/nvim"
)

echo "OS: $OS | Mode: $MODE"

case $MODE in
    push)
        echo "Copying from system to repo..."
        for src in "${!CONFIG_MAP[@]}"; do
            dest="${CONFIG_MAP[$src]}"
            src_path="$HOME/$src"
            dest_path="$REPO_DIR/$dest"
            
            if [[ -e "$src_path" ]]; then
                mkdir -p "$(dirname "$dest_path")"
                if [[ -d "$src_path" ]]; then
                    rsync -av --delete "$src_path/" "$dest_path/"
                else
                    cp "$src_path" "$dest_path"
                fi
                echo "✓ $src → $dest"
            fi
        done
        ;;
        
    pull)
        echo "Copying from repo to system..."
        for src in "${!CONFIG_MAP[@]}"; do
            dest="$HOME/$src"
            src_path="$REPO_DIR/${CONFIG_MAP[$src]}"
            
            if [[ -e "$src_path" ]]; then
                mkdir -p "$(dirname "$dest")"
                if [[ -d "$src_path" ]]; then
                    rsync -av "$src_path/" "$dest/"
                else
                    cp "$src_path" "$dest"
                fi
                echo "✓ $src restored"
            fi
        done
        ;;
        
    status)
        echo "Checking sync status..."
        for src in "${!CONFIG_MAP[@]}"; do
            src_path="$HOME/$src"
            dest_path="$REPO_DIR/${CONFIG_MAP[$src]}"
            
            if [[ -e "$src_path" ]] && [[ -e "$dest_path" ]]; then
                if diff -q "$src_path" "$dest_path" > /dev/null 2>&1; then
                    echo "✓ $src is in sync"
                else
                    echo "✗ $src differs"
                fi
            elif [[ -e "$src_path" ]]; then
                echo "+ $src exists locally only"
            elif [[ -e "$dest_path" ]]; then
                echo "- $src exists in repo only"
            fi
        done
        ;;
esac
```

## 🚨 Important Notes

1. **project-index**: After this migration, return to ~/Projects/claude-code-project-index to:
   - Fix the clipboard issue for large repos
   - Add "maintenance mode" notice
   - Tag as v1.0.0
   - Update to point to ~/.claude-ericbuess for full toolkit

2. **vm-bridge**: Decide if it should be:
   - Copied into tools/vm-bridge/ (simpler)
   - Submodule linked (if actively developed)
   - The network clipboard solution needs to be integrated with project-index

3. **Cleanup Order**:
   - First get this repo working
   - Then update project-index
   - Finally archive old repos

4. **Testing**: After setup, test:
   - Push from Linux, pull on Mac
   - Push from Mac, pull on Linux
   - Verify all paths work in both environments

## 🎯 Success Criteria

- [ ] Single repo at ~/.claude-ericbuess works on both Mac and Linux
- [ ] sync.sh successfully syncs configs bidirectionally  
- [ ] Old repos have "MOVED TO" notices
- [ ] project-index is fixed and frozen at v1.0.0
- [ ] Videos can reference this structure clearly
- [ ] No installation complexity for viewers
- [ ] Clear "Eric's Lab" philosophy throughout

## 🔄 Next Steps After Migration

1. Open Claude in `~/Projects/claude-code-project-index/`
2. Fix clipboard issue with vm-bridge integration
3. Update README with maintenance mode notice
4. Tag v1.0.0 and push
5. Record your unblocked video
6. Point all future tool development to ~/.claude-ericbuess

---

This is a living document. Update as the structure evolves.