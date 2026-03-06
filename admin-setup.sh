#!/bin/bash

# Donburi Admin Setup Script - Standalone version for IT administrators
# This script can be downloaded and run independently without cloning the full repository
#
# Usage:
#   su -l <admin>
#   curl -fsSL https://raw.githubusercontent.com/jonataseduardo/donburi/main/admin-setup.sh | bash
#   Or download and run:
#   su -l <admin>
#   ./admin-setup.sh

set -e

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
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

log_info() { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

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
echo "  • Installing all required packages"
echo ""
echo "Notes:"
echo "  • Homebrew must already be installed"
echo "  • This script does not start services"
echo "  • This script does not automate macOS permissions"
echo ""
echo -e "${YELLOW}Press Enter to continue or Ctrl+C to cancel...${NC}"
read -r

# Step 1: Check Homebrew
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
	log_error "Homebrew not found. Please install Homebrew first."
	exit 1
fi

log_info "Homebrew found at: $BREW_CMD"

# Step 2: Install packages
echo ""
echo -e "${BOLD}Step 2: Installing required packages...${NC}"
echo "This may take several minutes..."

# Core applications
APPS=(neovim tmux sketchybar btop jq FelixKratz/formulae/borders ghostty nikitabobko/tap/aerospace)
# CLI tools
CLI_TOOLS=(bat lsd fzf ripgrep htop wget bash gcc make gnu-sed gawk curl gh)
# Development utilities
UTILS=(node python slack spotify)
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

# Step 3: Verification
echo ""
echo -e "${BOLD}Step 3: Verification${NC}"
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

# Step 4: Next steps
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Admin Setup Complete!             ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo "Next steps for users:"
echo ""
echo "1. Install donburi:"
echo "   curl -fsSL https://raw.githubusercontent.com/jonataseduardo/donburi/main/install.sh | bash"
echo ""
echo "2. Setup configurations:"
echo "   donburi setup --no-brew"
echo ""
echo "3. Grant AeroSpace Accessibility permission manually:"
echo "   System Settings -> Privacy & Security -> Accessibility -> enable AeroSpace"
echo ""
echo "For verification, users can run:"
echo "   donburi status"
echo "   donburi permissions"
echo ""
echo "Repository: https://github.com/jonataseduardo/donburi"
echo "Documentation: ENTERPRISE_SETUP.md"
