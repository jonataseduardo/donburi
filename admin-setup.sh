#!/bin/bash

# Donburi Admin Setup Script - Standalone version for IT administrators
# This script can be downloaded and run independently without cloning the full repository
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/jonatas/donburi/main/admin-setup.sh | su -l <admin> -c "bash -s"
#   Or download and run:
#   su -l <admin> -c ./admin-setup.sh

set -e

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
# shellcheck disable=SC2034  # DONBURI_REPO reserved for future cloning functionality
DONBURI_REPO="https://github.com/jonatas/donburi.git"
DONBURI_TEMP="/tmp/donburi-admin-$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------------

log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

get_console_user() {
    local user
    user="$(stat -f %Su /dev/console 2>/dev/null || true)"
    if [[ -z "$user" || "$user" == "root" ]]; then
        return 1
    fi
    echo "$user"
}

cleanup() {
    if [ -d "$DONBURI_TEMP" ]; then
        rm -rf "$DONBURI_TEMP"
    fi
}

trap cleanup EXIT

# ---------------------------------------------------------------------------
# Main Setup
# ---------------------------------------------------------------------------

clear
echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    Donburi Admin Setup Script         ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (admin)"
    echo "Usage: su -l <admin> -c $0"
    exit 1
fi

echo "This script will set up donburi for enterprise users by:"
echo "  • Installing Homebrew (if needed)"
echo "  • Installing all required packages"
echo "  • Starting necessary services for the logged-in user"
echo "  • Guiding through system permission grants"
echo ""
echo -e "${YELLOW}Press Enter to continue or Ctrl+C to cancel...${NC}"
read -r

# Step 1: Check/Install Homebrew
echo ""
echo -e "${BOLD}Step 1: Checking Homebrew...${NC}"

BREW_CMD=""
if command -v brew &>/dev/null; then
    BREW_CMD="brew"
elif [ -x "/usr/local/bin/brew" ]; then
    BREW_CMD="/usr/local/bin/brew"
elif [ -x "/opt/homebrew/bin/brew" ]; then
    BREW_CMD="/opt/homebrew/bin/brew"
elif [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
    BREW_CMD="/home/linuxbrew/.linuxbrew/bin/brew"
fi

if [ -z "$BREW_CMD" ]; then
    log_warn "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Re-check for brew after installation
    if command -v brew &>/dev/null; then
        BREW_CMD="brew"
    elif [ -x "/opt/homebrew/bin/brew" ]; then
        BREW_CMD="/opt/homebrew/bin/brew"
    elif [ -x "/usr/local/bin/brew" ]; then
        BREW_CMD="/usr/local/bin/brew"
    else
        log_error "Failed to install or locate Homebrew"
        exit 1
    fi
fi

log_info "Homebrew found at: $BREW_CMD"

# Step 2: Install packages
echo ""
echo -e "${BOLD}Step 2: Installing required packages...${NC}"
echo "This may take several minutes..."

# Core applications
APPS=(neovim tmux sketchybar btop jq FelixKratz/formulae/borders ghostty nikitabobko/tap/aerospace)
# CLI tools
CLI_TOOLS=(bat lsd fzf ripgrep htop wget bash gcc make gnu-sed gawk curl)
# Development utilities
UTILS=(node python@3 slack discord spotify)
# Container tools
DOCKER=(colima docker docker-compose docker-buildx)

echo "Installing applications..."
for app in "${APPS[@]}"; do
    if "$BREW_CMD" list --cask "$app" &>/dev/null 2>&1 || "$BREW_CMD" list --formula "$app" &>/dev/null 2>&1; then
        echo "  ✓ $app (already installed)"
    else
        echo "  Installing $app..."
        "$BREW_CMD" install "$app" 2>/dev/null || "$BREW_CMD" install --cask "$app" 2>/dev/null || echo "  ⚠ Failed to install $app"
    fi
done

echo ""
echo "Installing CLI tools..."
for tool in "${CLI_TOOLS[@]}"; do
    if "$BREW_CMD" list --formula "$tool" &>/dev/null 2>&1; then
        echo "  ✓ $tool (already installed)"
    else
        echo "  Installing $tool..."
        "$BREW_CMD" install "$tool" 2>/dev/null || echo "  ⚠ Failed to install $tool"
    fi
done

echo ""
echo "Install development utilities? (y/N): "
read -r install_utils
if [[ "$install_utils" =~ ^[Yy]$ ]]; then
    for util in "${UTILS[@]}"; do
        if "$BREW_CMD" list --cask "$util" &>/dev/null 2>&1 || "$BREW_CMD" list --formula "$util" &>/dev/null 2>&1; then
            echo "  ✓ $util (already installed)"
        else
            echo "  Installing $util..."
            "$BREW_CMD" install "$util" 2>/dev/null || "$BREW_CMD" install --cask "$util" 2>/dev/null || echo "  ⚠ Failed to install $util"
        fi
    done
fi

echo ""
echo "Install Docker/container tools? (y/N): "
read -r install_docker
if [[ "$install_docker" =~ ^[Yy]$ ]]; then
    for tool in "${DOCKER[@]}"; do
        if "$BREW_CMD" list --formula "$tool" &>/dev/null 2>&1; then
            echo "  ✓ $tool (already installed)"
        else
            echo "  Installing $tool..."
            "$BREW_CMD" install "$tool" 2>/dev/null || echo "  ⚠ Failed to install $tool"
        fi
    done
fi

# Step 3: Start services
echo ""
echo -e "${BOLD}Step 3: Starting services...${NC}"

console_user="$(get_console_user || true)"
if [[ -n "$console_user" ]]; then
    echo "Starting sketchybar service for console user: $console_user"
    if su -l "$console_user" -c "$BREW_CMD services start --user sketchybar" 2>&1 | grep -q "Successfully started"; then
        log_info "Sketchybar service started"
    elif su -l "$console_user" -c "$BREW_CMD services list" 2>/dev/null | grep -q "sketchybar.*started"; then
        log_info "Sketchybar service already running"
    else
        log_warn "Could not verify sketchybar service status"
    fi
else
    log_warn "Console user not detected; cannot start sketchybar for a user session"
    log_warn "Ask the logged-in user to run: brew services start --user sketchybar"
fi

# Step 4: System permissions
echo ""
echo -e "${BOLD}Step 4: System Permissions${NC}"
echo ""
echo "The following applications need system permissions."
echo "The System Settings will open to the correct panes."
echo ""

echo -e "${CYAN}4a. Aerospace - Accessibility Permission${NC}"
echo "   Required for window management"
echo "   Action: Add and enable AeroSpace in the list"
echo ""
echo -e "${YELLOW}Opening Accessibility settings...${NC}"
open "x-apple.systempreferences:com.apple.Accessibility-Settings.extension" 2>/dev/null || \
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null
echo "Press Enter after granting permission..."
read -r

echo ""
echo -e "${CYAN}4b. Borders - Screen Recording Permission (Optional)${NC}"
echo "   Adds colored borders to windows (visual enhancement)"
echo "   Note: This does NOT actually record your screen"
echo ""
echo "Grant this optional permission? (y/N): "
read -r grant_borders
if [[ "$grant_borders" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Opening Screen Recording settings...${NC}"
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture" 2>/dev/null
    echo "Press Enter after granting permission (or skip)..."
    read -r
fi

# Step 5: Verification
echo ""
echo -e "${BOLD}Step 5: Verification${NC}"
echo ""

echo -e "${CYAN}=== Setup Status ===${NC}"
echo ""

# Check packages
echo "Installed packages:"
for app in neovim tmux sketchybar btop jq borders ghostty aerospace; do
    if "$BREW_CMD" list --formula "$app" &>/dev/null 2>&1 || "$BREW_CMD" list --cask "$app" &>/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $app"
    else
        echo -e "  ${RED}✗${NC} $app"
    fi
done

echo ""
echo "Services:"
console_user="$(get_console_user || true)"
if [[ -n "$console_user" ]]; then
    if su -l "$console_user" -c "$BREW_CMD services list" 2>/dev/null | grep -q "sketchybar.*started"; then
        echo -e "  ${GREEN}✓${NC} Sketchybar service running (user: $console_user)"
    else
        echo -e "  ${YELLOW}⚠${NC} Sketchybar service not running (user: $console_user)"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Console user not detected; cannot verify sketchybar service"
fi

# Step 6: Next steps
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Admin Setup Complete!             ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo "Next steps for users:"
echo ""
echo "1. Install donburi:"
echo "   curl -fsSL https://raw.githubusercontent.com/jonatas/donburi/main/install.sh | bash"
echo ""
echo "2. Setup configurations:"
echo "   donburi setup --no-brew"
echo ""
echo "For verification, users can run:"
echo "   donburi status"
echo "   donburi permissions"
echo ""
echo "Repository: https://github.com/jonatas/donburi"
echo "Documentation: ENTERPRISE_SETUP.md"
