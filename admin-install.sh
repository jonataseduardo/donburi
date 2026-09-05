#!/bin/bash

# Donburi Admin Install Script - Single-command enterprise setup
# Assumes Homebrew is already installed
#
# Usage (run as root via su):
#   su -l <admin>
#   curl -fsSL https://raw.githubusercontent.com/jonataseduardo/donburi/main/admin-install.sh | bash

set -e

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------------

log_info() { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

find_brew() {
	if command -v brew &>/dev/null; then
		echo "brew"
		return 0
	fi
	if [[ -x "/opt/homebrew/bin/brew" ]]; then
		echo "/opt/homebrew/bin/brew"
		return 0
	fi
	if [[ -x "/usr/local/bin/brew" ]]; then
		echo "/usr/local/bin/brew"
		return 0
	fi
	return 1
}

brew_install() {
	local name="$1"
	local type="${2:-formula}"

	if "$BREW_CMD" list --"${type}" "$name" &>/dev/null; then
		log_info "Already installed: $name"
		return 0
	fi

	log_info "Installing $type: $name"
	"$BREW_CMD" install ${type:+--${type}} "$name"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if [ "$EUID" -ne 0 ]; then
	log_error "This script must be run as root (admin via su)"
	exit 1
fi

echo -e "${CYAN}=== Donburi Admin Install (Single Command) ===${NC}"
echo "This script will:"
echo "  - Install all required Homebrew packages"
echo ""
echo "Notes:"
echo "  - This script does not start services"
echo "  - This script does not automate macOS permissions"
echo ""

BREW_CMD="$(find_brew || true)"
if [[ -z "$BREW_CMD" ]]; then
	log_error "Homebrew not found. Please install Homebrew first."
	exit 1
fi

log_info "Using Homebrew at: $BREW_CMD"

# ---------------------------------------------------------------------------
# Package Installation (equivalent to 'donburi brew all')
# ---------------------------------------------------------------------------

echo ""
echo -e "${BOLD}Installing required packages...${NC}"

BREW_APPS_FORMULA=(neovim tmux sketchybar btop jq FelixKratz/formulae/borders)
BREW_APPS_CASK=(ghostty nikitabobko/tap/aerospace)

BREW_CLI_FORMULA=(bat lsd fzf ripgrep htop wget bash gcc make gnu-sed gawk curl gh stylua tree-sitter-cli)

BREW_UTILS_FORMULA=(node python ffmpeg imagemagick pandoc yq jless fd dust httpie watchexec direnv just glow tldr zoxide delta choose sd tokei postgresql@18 sqlite go telnet)
BREW_UTILS_CASK=(slack spotify)

BREW_DOCKER_FORMULA=(colima docker docker-compose docker-buildx)

for pkg in "${BREW_APPS_FORMULA[@]}"; do
	brew_install "$pkg" formula
done
for pkg in "${BREW_APPS_CASK[@]}"; do
	brew_install "$pkg" cask
done
for pkg in "${BREW_CLI_FORMULA[@]}"; do
	brew_install "$pkg" formula
done
for pkg in "${BREW_UTILS_FORMULA[@]}"; do
	brew_install "$pkg" formula
done
for pkg in "${BREW_UTILS_CASK[@]}"; do
	brew_install "$pkg" cask
done
for pkg in "${BREW_DOCKER_FORMULA[@]}"; do
	brew_install "$pkg" formula
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo -e "${GREEN}=== Admin install complete ===${NC}"
echo "Next steps for users:"
echo "  1) Install donburi: curl -fsSL https://raw.githubusercontent.com/jonataseduardo/donburi/main/install.sh | bash"
echo "  2) Setup configs:  donburi setup --no-brew"
echo "  3) Check status:   donburi permissions"
