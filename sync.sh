#!/bin/bash

# Detect OS and set target directory
case "$(uname -s)" in
    Darwin*)
        OS_DIR="macos"
        SHELL_RC=".zshrc"
        SHELL_PROFILE=".zprofile"
        ;;
    Linux*)
        OS_DIR="ubuntu"
        SHELL_RC=".bashrc"
        SHELL_PROFILE=".bash_profile"
        ;;
    *)
        echo "Unknown OS: $(uname -s)"
        exit 1
        ;;
esac

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
        
        # Shell configs
        echo "Shell configs:"
        safe_copy "$HOME/$SHELL_RC" "$TARGET_DIR/shell/rc"
        safe_copy "$HOME/$SHELL_PROFILE" "$TARGET_DIR/shell/profile"
        safe_copy "$HOME/.aliases" "$TARGET_DIR/shell/aliases"
        
        # Tmux
        echo -e "\nTmux:"
        safe_copy "$HOME/.tmux.conf" "$TARGET_DIR/tmux/tmux.conf"
        
        # Claude
        echo -e "\nClaude:"
        safe_copy "$HOME/.claude/settings.json" "$TARGET_DIR/claude/settings.json"
        if [[ -d "$HOME/.claude/hooks" ]]; then
            safe_copy "$HOME/.claude/hooks" "$TARGET_DIR/claude/hooks"
        fi
        
        # Neovim
        echo -e "\nNeovim:"
        if [[ -d "$HOME/.config/nvim" ]]; then
            safe_copy "$HOME/.config/nvim" "$TARGET_DIR/nvim"
        fi
        
        # Vim
        echo -e "\nVim:"
        safe_copy "$HOME/.vimrc" "$TARGET_DIR/vim/vimrc"
        
        # Git
        echo -e "\nGit:"
        safe_copy "$HOME/.gitconfig" "$TARGET_DIR/git/gitconfig"
        safe_copy "$HOME/.gitignore_global" "$TARGET_DIR/git/gitignore_global"
        
        # SSH (config only, no keys)
        echo -e "\nSSH:"
        safe_copy "$HOME/.ssh/config" "$TARGET_DIR/ssh/config"
        
        echo -e "\n✅ Push complete!"
        ;;
        
    pull)
        echo "Pulling configs from repository to home..."
        echo "⚠️  This will overwrite your local configs!"
        read -p "Continue? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi
        
        echo ""
        
        # Shell configs
        echo "Shell configs:"
        safe_copy "$TARGET_DIR/shell/rc" "$HOME/$SHELL_RC"
        safe_copy "$TARGET_DIR/shell/profile" "$HOME/$SHELL_PROFILE"
        safe_copy "$TARGET_DIR/shell/aliases" "$HOME/.aliases"
        
        # Tmux
        echo -e "\nTmux:"
        safe_copy "$TARGET_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
        
        # Claude
        echo -e "\nClaude:"
        mkdir -p "$HOME/.claude"
        safe_copy "$TARGET_DIR/claude/settings.json" "$HOME/.claude/settings.json"
        if [[ -d "$TARGET_DIR/claude/hooks" ]]; then
            safe_copy "$TARGET_DIR/claude/hooks" "$HOME/.claude/hooks"
        fi
        
        # Neovim
        echo -e "\nNeovim:"
        if [[ -d "$TARGET_DIR/nvim" ]]; then
            mkdir -p "$HOME/.config"
            safe_copy "$TARGET_DIR/nvim" "$HOME/.config/nvim"
        fi
        
        # Vim
        echo -e "\nVim:"
        safe_copy "$TARGET_DIR/vim/vimrc" "$HOME/.vimrc"
        
        # Git
        echo -e "\nGit:"
        safe_copy "$TARGET_DIR/git/gitconfig" "$HOME/.gitconfig"
        safe_copy "$TARGET_DIR/git/gitignore_global" "$HOME/.gitignore_global"
        
        # SSH
        echo -e "\nSSH:"
        mkdir -p "$HOME/.ssh"
        safe_copy "$TARGET_DIR/ssh/config" "$HOME/.ssh/config"
        chmod 600 "$HOME/.ssh/config" 2>/dev/null || true
        
        echo -e "\n✅ Pull complete!"
        ;;
        
    status|*)
        echo "Checking sync status..."
        echo ""
        
        # Shell configs
        echo "Shell configs:"
        check_diff "$HOME/$SHELL_RC" "$TARGET_DIR/shell/rc"
        check_diff "$HOME/$SHELL_PROFILE" "$TARGET_DIR/shell/profile"
        check_diff "$HOME/.aliases" "$TARGET_DIR/shell/aliases"
        
        # Tmux
        echo -e "\nTmux:"
        check_diff "$HOME/.tmux.conf" "$TARGET_DIR/tmux/tmux.conf"
        
        # Claude
        echo -e "\nClaude:"
        check_diff "$HOME/.claude/settings.json" "$TARGET_DIR/claude/settings.json"
        if [[ -d "$HOME/.claude/hooks" ]]; then
            check_diff "$HOME/.claude/hooks" "$TARGET_DIR/claude/hooks"
        fi
        
        # Neovim
        echo -e "\nNeovim:"
        if [[ -d "$HOME/.config/nvim" ]]; then
            check_diff "$HOME/.config/nvim" "$TARGET_DIR/nvim"
        fi
        
        # Vim
        echo -e "\nVim:"
        check_diff "$HOME/.vimrc" "$TARGET_DIR/vim/vimrc"
        
        # Git
        echo -e "\nGit:"
        check_diff "$HOME/.gitconfig" "$TARGET_DIR/git/gitconfig"
        check_diff "$HOME/.gitignore_global" "$TARGET_DIR/git/gitignore_global"
        
        # SSH
        echo -e "\nSSH:"
        check_diff "$HOME/.ssh/config" "$TARGET_DIR/ssh/config"
        
        echo ""
        echo "Usage:"
        echo "  $0 status  - Check sync status (default)"
        echo "  $0 push    - Push configs from home to repo"
        echo "  $0 pull    - Pull configs from repo to home"
        ;;
esac