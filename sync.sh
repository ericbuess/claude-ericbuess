#!/bin/bash

# Detect OS and set target directory
case "$(uname -s)" in
    Darwin*)
        OS_DIR="macos"
        ;;
    Linux*)
        OS_DIR="ubuntu"
        ;;
    *)
        echo "Unknown OS: $(uname -s)"
        exit 1
        ;;
esac

# Configuration mapping
# Format: "source_path:dest_path:os_filter"
# os_filter can be: all, macos, ubuntu
declare -a SYNC_CONFIGS=(
    # Shell configs
    ".zshrc:shell/rc:macos"
    ".zprofile:shell/profile:macos"
    ".bashrc:shell/rc:ubuntu"
    ".bash_profile:shell/profile:ubuntu"
    ".aliases:shell/aliases:all"
    
    # Development tools
    ".tmux.conf:tmux/tmux.conf:all"
    ".vimrc:vim/vimrc:all"
    ".gitconfig:git/gitconfig:all"
    ".gitignore_global:git/gitignore_global:all"
    
    # Claude CLI
    ".claude/settings.json:claude/settings.json:all"
    ".claude/hooks:claude/hooks:all"
    
    # Neovim
    ".config/nvim:nvim:all"
    
    # SSH (config only)
    ".ssh/config:ssh/config:all"
    
    # Add new configs here as needed
)

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$REPO_DIR/$OS_DIR"
MODE=${1:-status}

echo "OS: $OS_DIR | Mode: $MODE | Target: $TARGET_DIR"

# Function to check for sensitive content
check_sensitive() {
    local file="$1"
    
    # Check filename patterns
    case "$(basename "$file")" in
        *.key|*.pem|*.p12|*.pfx|id_rsa*|id_ed25519*|id_dsa*)
            echo "  ⚠️  SKIPPING (private key): $file"
            return 1
            ;;
        .env|.env.*|*.env)
            echo "  ⚠️  SKIPPING (env file): $file"
            return 1
            ;;
        *secret*|*token*|*password*|*credential*)
            echo "  ⚠️  SKIPPING (sensitive name): $file"
            return 1
            ;;
        *history|.bash_history|.zsh_history|.python_history|.node_repl_history)
            echo "  ⚠️  SKIPPING (history file): $file"
            return 1
            ;;
        .lesshst|.viminfo|.wget-hsts|.recently-used*)
            echo "  ⚠️  SKIPPING (usage tracking): $file"
            return 1
            ;;
        known_hosts|authorized_keys)
            echo "  ⚠️  SKIPPING (SSH file): $file"
            return 1
            ;;
    esac
    
    # For text files, check content
    if [[ -f "$file" ]] && file "$file" | grep -q "text"; then
        if grep -qE "(PRIVATE KEY|BEGIN RSA|BEGIN DSA|BEGIN EC|BEGIN OPENSSH)" "$file" 2>/dev/null; then
            echo "  ⚠️  SKIPPING (contains private key): $file"
            return 1
        fi
        if grep -qE "^[A-Z_]+_(KEY|TOKEN|SECRET|PASSWORD|API|CREDENTIAL)" "$file" 2>/dev/null; then
            echo "  ⚠️  WARNING (may contain secrets): $file"
            read -p "    Include this file anyway? (y/N) " -n 1 -r
            echo
            [[ ! $REPLY =~ ^[Yy]$ ]] && return 1
        fi
    fi
    
    return 0
}

# Function to safely copy files
safe_copy() {
    local src="$1"
    local dest="$2"
    
    if [[ -e "$src" ]]; then
        # Check for sensitive content first
        if ! check_sensitive "$src"; then
            return 1
        fi
        
        mkdir -p "$(dirname "$dest")"
        if [[ -d "$src" ]]; then
            echo "  Copying directory: $src"
            # For directories, use rsync with exclude patterns
            rsync -a --delete \
                --exclude="*.key" \
                --exclude="*.pem" \
                --exclude="id_rsa*" \
                --exclude="id_ed25519*" \
                --exclude=".env" \
                --exclude=".env.*" \
                --exclude="*secret*" \
                --exclude="*token*" \
                --exclude="*history" \
                --exclude=".*_history" \
                --exclude=".viminfo" \
                --exclude=".lesshst" \
                --exclude="known_hosts" \
                --exclude="authorized_keys" \
                --exclude="*.log" \
                --exclude="*.cache" \
                "$src/" "$dest/"
        else
            echo "  Copying file: $src"
            cp "$src" "$dest"
        fi
        return 0
    else
        echo "  Skipping (not found): $src"
        return 1
    fi
}

# Function to check differences
check_diff() {
    local src="$1"
    local dest="$2"
    
    if [[ ! -e "$src" ]]; then
        echo "  ✗ Missing: $src"
        return 1
    elif [[ ! -e "$dest" ]]; then
        echo "  + New: $src"
        return 0
    elif diff -q "$src" "$dest" > /dev/null 2>&1; then
        echo "  ✓ In sync: $src"
        return 0
    else
        echo "  ≠ Modified: $src"
        return 0
    fi
}

case $MODE in
    push)
        echo "Pushing configs from home to repository..."
        echo ""
        
        for config in "${SYNC_CONFIGS[@]}"; do
            IFS=':' read -r src dest os_filter <<< "$config"
            
            # Skip if OS doesn't match filter
            if [[ "$os_filter" != "all" ]] && [[ "$os_filter" != "$OS_DIR" ]]; then
                continue
            fi
            
            safe_copy "$HOME/$src" "$TARGET_DIR/$dest"
        done
        
        echo -e "\n✅ Push complete!"
        ;;
        
    status|*)
        echo "Checking sync status..."
        echo ""
        
        for config in "${SYNC_CONFIGS[@]}"; do
            IFS=':' read -r src dest os_filter <<< "$config"
            
            # Skip if OS doesn't match filter
            if [[ "$os_filter" != "all" ]] && [[ "$os_filter" != "$OS_DIR" ]]; then
                continue
            fi
            
            check_diff "$HOME/$src" "$TARGET_DIR/$dest"
        done
        
        echo ""
        echo "Usage:"
        echo "  $0 status  - Check sync status (default)"
        echo "  $0 push    - Push configs from home to repo"
        echo ""
        echo "Note: This is a reference repository for learning."
        echo "Users should adapt these configs to their own needs, not copy directly."
        echo ""
        echo "To add new configs, edit SYNC_CONFIGS array in this script"
        ;;
esac