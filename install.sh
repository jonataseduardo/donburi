#!/bin/bash

# Donburi Installer
# Install via: curl -fsSL https://raw.githubusercontent.com/jonatas/donburi/main/install.sh | bash
#
# Environment variables:
#   DONBURI_HOME    Installation directory (default: ~/.donburi)
#   DONBURI_BRANCH  Git branch to install (default: main)

set -e

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
DONBURI_HOME="${DONBURI_HOME:-$HOME/.donburi}"
DONBURI_BRANCH="${DONBURI_BRANCH:-main}"
DONBURI_REPO="https://github.com/jonatas/donburi.git"
BIN_DIR="$HOME/.local/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ---------------------------------------------------------------------------
# Main Installation
# ---------------------------------------------------------------------------

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         Donburi Installer             ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
echo ""

# Check for custom brew path
if [ -n "${DONBURI_BREW_PATH:-}" ]; then
    log_info "Using custom brew path: $DONBURI_BREW_PATH"
fi

# Check for git
if ! command -v git &>/dev/null; then
    log_error "Git is required but not installed."
    echo "  Install via: https://git-scm.com or 'xcode-select --install'"
    exit 1
fi

# Clone or update repository
if [ -d "$DONBURI_HOME" ]; then
    log_info "Updating existing installation at $DONBURI_HOME"
    if ! git -C "$DONBURI_HOME" pull --ff-only origin "$DONBURI_BRANCH" 2>/dev/null; then
        log_warn "Fast-forward pull failed, fetching and resetting..."
        git -C "$DONBURI_HOME" fetch origin "$DONBURI_BRANCH"
        git -C "$DONBURI_HOME" reset --hard "origin/$DONBURI_BRANCH"
    fi
else
    log_info "Cloning donburi to $DONBURI_HOME"
    git clone --branch "$DONBURI_BRANCH" "$DONBURI_REPO" "$DONBURI_HOME"
fi

# Make donburi executable
chmod +x "$DONBURI_HOME/donburi"

# Create bin directory and symlink
mkdir -p "$BIN_DIR"
# Remove existing file/symlink/directory at target path
if [ -e "$BIN_DIR/donburi" ] || [ -L "$BIN_DIR/donburi" ]; then
    rm -rf "$BIN_DIR/donburi"
fi
ln -s "$DONBURI_HOME/donburi" "$BIN_DIR/donburi"
log_info "Created symlink: $BIN_DIR/donburi -> $DONBURI_HOME/donburi"

# ---------------------------------------------------------------------------
# Shell Configuration
# ---------------------------------------------------------------------------
add_to_path() {
    local shell_rc="$1"
    # shellcheck disable=SC2016
    local path_line='export PATH="$HOME/.local/bin:$PATH"'

    if [ -f "$shell_rc" ]; then
        # Skip if .local/bin is already referenced in the file
        if grep -q '\.local/bin' "$shell_rc" 2>/dev/null; then
            log_info "PATH already configured in $shell_rc"
            return 1
        fi
        {
            echo ""
            echo "# Added by donburi installer"
            echo "$path_line"
        } >> "$shell_rc"
        log_info "Added ~/.local/bin to PATH in $shell_rc"
        return 0
    fi
    return 1
}

# Update shell configuration if needed
PATH_UPDATED=false
# Only modify shell config if .local/bin is not in current PATH
if [[ ! ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    # Detect shell and update appropriate rc file
    if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "/bin/zsh" ] || [ -f "$HOME/.zshrc" ]; then
        if add_to_path "$HOME/.zshrc"; then
            PATH_UPDATED=true
        fi
    fi
    if [ -n "$BASH_VERSION" ] || [ "$SHELL" = "/bin/bash" ]; then
        if [ -f "$HOME/.bashrc" ]; then
            if add_to_path "$HOME/.bashrc"; then
                PATH_UPDATED=true
            fi
        elif [ -f "$HOME/.bash_profile" ]; then
            if add_to_path "$HOME/.bash_profile"; then
                PATH_UPDATED=true
            fi
        fi
    fi
else
    log_info "PATH already includes ~/.local/bin"
fi

# ---------------------------------------------------------------------------
# Success Message
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Installation Complete!          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo "  Installed to: $DONBURI_HOME"
echo "  CLI command:  donburi"
echo ""

if [ "$PATH_UPDATED" = true ]; then
    echo -e "${YELLOW}Note: Restart your terminal or run:${NC}"
    # shellcheck disable=SC2016
    echo '  export PATH="$HOME/.local/bin:$PATH"'
    echo ""
fi

echo "Next steps:"
echo "  donburi brew-check    # Check Homebrew installation"
echo "  donburi help          # Show available commands"
echo ""
echo "If Homebrew is installed:"
echo "  donburi brew apps     # Install applications (nvim, ghostty, etc.)"
echo "  donburi setup         # Install all configurations"
echo ""
echo "If Homebrew is NOT installed:"
echo "  donburi setup --no-brew  # Setup configs without brew dependencies"
echo ""
echo "For corporate environments:"
echo "  Ask admin: su -l <admin> -c \"donburi brew all\"  # Install all brew packages"
echo "  Then run:  donburi setup --no-brew  # Setup your configs"
echo ""
