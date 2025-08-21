#!/bin/bash
# sync.sh - Bidirectional sync for Eric's Claude Setup
# Detects OS and syncs configs between system and repo

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE=${1:-status}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect OS
case "$(uname -s)" in
    Darwin*)
        OS="mac"
        SHELL_RC=".zshrc"
        SHELL_NAME="zsh"
        ;;
    Linux*)
        OS="linux"
        SHELL_RC=".bashrc"
        SHELL_NAME="bash"
        ;;
    *)
        echo -e "${RED}Unknown OS: $(uname -s)${NC}"
        exit 1
        ;;
esac

# Configuration mapping
# Format: ["system_path"]="repo_path"
declare -A CONFIG_MAP=(
    ["$SHELL_RC"]="configs/$OS/shell-rc"
    [".tmux.conf"]="configs/shared/tmux.conf"
    [".vimrc"]="configs/shared/vimrc"
    [".claude/hooks"]="configs/shared/claude-hooks"
    [".claude/settings.json"]="configs/$OS/claude-settings.json"
    [".config/nvim"]="configs/shared/nvim"
)

echo -e "${GREEN}=== Eric's Claude Setup Sync ===${NC}"
echo "OS: $OS ($(uname -s))"
echo "Shell: $SHELL_NAME"
echo "Mode: $MODE"
echo ""

case $MODE in
    push)
        echo -e "${YELLOW}Copying from system to repo...${NC}"
        
        for src in "${!CONFIG_MAP[@]}"; do
            dest="${CONFIG_MAP[$src]}"
            src_path="$HOME/$src"
            dest_path="$REPO_DIR/$dest"
            
            if [[ -e "$src_path" ]]; then
                mkdir -p "$(dirname "$dest_path")"
                if [[ -d "$src_path" ]]; then
                    # For directories, use rsync
                    rsync -av --delete "$src_path/" "$dest_path/" > /dev/null 2>&1
                else
                    # For files, use cp
                    cp "$src_path" "$dest_path"
                fi
                echo -e "${GREEN}✓${NC} $src → $dest"
            else
                echo -e "${YELLOW}⚠${NC}  $src not found (skipping)"
            fi
        done
        
        echo ""
        echo "Ready to commit changes:"
        cd "$REPO_DIR"
        git add -A
        git status --short
        echo ""
        echo -e "${GREEN}Run: git commit -m 'Sync from $OS: $(date +%Y-%m-%d)'${NC}"
        ;;
        
    pull)
        echo -e "${YELLOW}Copying from repo to system...${NC}"
        echo -e "${RED}⚠ WARNING: This will overwrite your local configs!${NC}"
        read -p "Continue? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi
        
        for src in "${!CONFIG_MAP[@]}"; do
            dest="$HOME/$src"
            src_path="$REPO_DIR/${CONFIG_MAP[$src]}"
            
            if [[ -e "$src_path" ]]; then
                mkdir -p "$(dirname "$dest")"
                if [[ -d "$src_path" ]]; then
                    # For directories, use rsync
                    rsync -av "$src_path/" "$dest/" > /dev/null 2>&1
                else
                    # For files, use cp
                    cp "$src_path" "$dest"
                fi
                echo -e "${GREEN}✓${NC} $src restored"
            else
                echo -e "${YELLOW}⚠${NC}  $src not in repo (skipping)"
            fi
        done
        ;;
        
    status)
        echo -e "${YELLOW}Checking sync status...${NC}"
        
        for src in "${!CONFIG_MAP[@]}"; do
            dest="${CONFIG_MAP[$src]}"
            src_path="$HOME/$src"
            dest_path="$REPO_DIR/$dest"
            
            if [[ -e "$src_path" ]] && [[ -e "$dest_path" ]]; then
                if [[ -d "$src_path" ]]; then
                    # For directories, check with diff
                    if diff -qr "$src_path" "$dest_path" > /dev/null 2>&1; then
                        echo -e "${GREEN}✓${NC} $src is in sync"
                    else
                        echo -e "${RED}✗${NC} $src differs from repo"
                    fi
                else
                    # For files
                    if diff -q "$src_path" "$dest_path" > /dev/null 2>&1; then
                        echo -e "${GREEN}✓${NC} $src is in sync"
                    else
                        echo -e "${RED}✗${NC} $src differs from repo"
                    fi
                fi
            elif [[ -e "$src_path" ]]; then
                echo -e "${YELLOW}+${NC} $src exists locally only"
            elif [[ -e "$dest_path" ]]; then
                echo -e "${YELLOW}-${NC} $src exists in repo only"
            else
                echo -e "${YELLOW}⚠${NC}  $src not found anywhere"
            fi
        done
        
        echo ""
        echo "Use './sync.sh push' to save changes to repo"
        echo "Use './sync.sh pull' to restore from repo"
        ;;
        
    help|*)
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  status  - Show sync status (default)"
        echo "  push    - Copy configs from system to repo"
        echo "  pull    - Copy configs from repo to system"
        echo "  help    - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0          # Check what's out of sync"
        echo "  $0 push     # Save current configs to repo"
        echo "  $0 pull     # Restore configs from repo"
        ;;
esac