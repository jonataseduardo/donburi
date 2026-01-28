#!/bin/bash

# Donburi Dotfiles Setup Script
# Usage: ./setup.sh [--dry-run] <command>
#
# Commands:
#   all          Install all configs (default)
#   nvim         Install Neovim config
#   ghostty      Install Ghostty config
#   aerospace    Install Aerospace config
#   tmux         Install tmux config
#   zsh          Install zsh config
#   sketchybar   Install Sketchybar config
#   brew         Install/upgrade all apps via Homebrew
#   status       Show current symlink status

set -e

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
DONBURI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config/donburi-backup-$(date +%Y%m%d-%H%M%S)"

# Source paths
SRC_NVIM="$DONBURI_DIR/nvim"
SRC_GHOSTTY="$DONBURI_DIR/ghostty/config"
SRC_AEROSPACE="$DONBURI_DIR/aerospace"
SRC_TMUX="$DONBURI_DIR/tmux/tmux.conf"
SRC_ZSH="$DONBURI_DIR/zsh/zshrc"
SRC_SKETCHYBAR="$DONBURI_DIR/sketchybar"

# Target paths
DST_NVIM="$HOME/.config/nvim"
DST_GHOSTTY="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
DST_AEROSPACE="$HOME/.config/aerospace"
DST_TMUX="$HOME/.tmux.conf"
DST_ZSH="$HOME/.zshrc"
DST_SKETCHYBAR="$HOME/.config/sketchybar"

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------
DRY_RUN=false

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
# Helpers
# ---------------------------------------------------------------------------

# Check if a symlink already points to the correct source
is_correct_symlink() {
    local target="$1"
    local source="$2"
    [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]
}

# Backup a file, directory, or dangling symlink before replacing it.
# Skips if target doesn't exist at all.
backup_if_exists() {
    local target="$1"

    # Nothing to back up
    [[ ! -e "$target" && ! -L "$target" ]] && return 0

    mkdir -p "$BACKUP_DIR"

    # Deduplicate backup names when the same basename appears twice
    local base
    base="$(basename "$target")"
    local backup_path="$BACKUP_DIR/$base"
    local n=1
    while [[ -e "$backup_path" ]]; do
        backup_path="$BACKUP_DIR/${base}.$n"
        ((n++))
    done

    if [[ "$DRY_RUN" == true ]]; then
        if [[ -L "$target" ]]; then
            log_warn "Would remove symlink: $target (-> $(readlink "$target"))"
        else
            log_warn "Would backup: $target -> $backup_path"
        fi
    else
        if [[ -L "$target" ]]; then
            local old_dest
            old_dest="$(readlink "$target")"
            rm "$target"
            log_info "Removed old symlink: $target (-> $old_dest)"
        else
            mv "$target" "$backup_path"
            log_info "Backed up: $target -> $backup_path"
        fi
    fi
}

# Create a symlink from $1 (source) to $2 (target).
# Handles existing symlinks, regular files, and directories.
create_symlink() {
    local source="$1"
    local target="$2"

    if [[ ! -e "$source" ]]; then
        log_error "Source does not exist: $source"
        return 1
    fi

    # Already correct — nothing to do
    if is_correct_symlink "$target" "$source"; then
        log_info "Already linked: $target"
        return 0
    fi

    # Ensure parent directory exists
    local target_dir
    target_dir="$(dirname "$target")"
    if [[ ! -d "$target_dir" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_info "Would create directory: $target_dir"
        else
            mkdir -p "$target_dir"
            log_info "Created directory: $target_dir"
        fi
    fi

    # Backup whatever is currently at the target path
    backup_if_exists "$target"

    # Create the symlink
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would symlink: $target -> $source"
    else
        ln -s "$source" "$target"
        log_info "Symlinked: $target -> $source"
    fi
}

# Install or upgrade a Homebrew formula
brew_install() {
    local name="$1"
    local type="${2:-formula}" # "formula" or "cask"

    if [[ "$DRY_RUN" == true ]]; then
        if brew list --${type} "$name" &>/dev/null; then
            log_info "Would upgrade $type: $name"
        else
            log_info "Would install $type: $name"
        fi
        return 0
    fi

    if brew list --${type} "$name" &>/dev/null; then
        log_info "Upgrading $type: $name"
        brew upgrade --${type} "$name" 2>/dev/null || log_info "Already up to date: $name"
    else
        log_info "Installing $type: $name"
        brew install ${type:+--${type}} "$name"
    fi
}

# Make scripts executable inside a directory
make_executable() {
    local dir="$1"
    local pattern="$2"
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would chmod +x: $dir/$pattern"
    else
        chmod +x "$dir"/$pattern 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# Per-app install commands
# ---------------------------------------------------------------------------

setup_nvim() {
    echo -e "${CYAN}--- nvim ---${NC}"
    create_symlink "$SRC_NVIM" "$DST_NVIM"
}

setup_ghostty() {
    echo -e "${CYAN}--- ghostty ---${NC}"
    create_symlink "$SRC_GHOSTTY" "$DST_GHOSTTY"
}

setup_aerospace() {
    echo -e "${CYAN}--- aerospace ---${NC}"
    # Remove old ~/.aerospace.toml to avoid AeroSpace ambiguity error
    local old_aerospace="$HOME/.aerospace.toml"
    if [[ -e "$old_aerospace" || -L "$old_aerospace" ]]; then
        backup_if_exists "$old_aerospace"
    fi
    make_executable "$DONBURI_DIR/aerospace/scripts" "*.sh"
    create_symlink "$SRC_AEROSPACE" "$DST_AEROSPACE"
}

setup_tmux() {
    echo -e "${CYAN}--- tmux ---${NC}"
    create_symlink "$SRC_TMUX" "$DST_TMUX"
}

setup_zsh() {
    echo -e "${CYAN}--- zsh ---${NC}"
    create_symlink "$SRC_ZSH" "$DST_ZSH"
}

setup_sketchybar() {
    echo -e "${CYAN}--- sketchybar ---${NC}"
    make_executable "$DONBURI_DIR/sketchybar" "sketchybarrc"
    make_executable "$DONBURI_DIR/sketchybar/plugins" "*.sh"
    create_symlink "$SRC_SKETCHYBAR" "$DST_SKETCHYBAR"
}

setup_brew() {
    echo -e "${CYAN}--- brew ---${NC}"
    if ! command -v brew &>/dev/null; then
        log_error "Homebrew not installed. Visit https://brew.sh"
        return 1
    fi
    brew_install neovim formula
    brew_install ghostty cask
    brew_install nikitabobko/tap/aerospace cask
    brew_install tmux formula
    brew_install sketchybar formula
    brew_install jq formula
}

setup_all() {
    setup_nvim
    setup_ghostty
    setup_aerospace
    setup_tmux
    setup_zsh
    setup_sketchybar
}

# ---------------------------------------------------------------------------
# Status command
# ---------------------------------------------------------------------------
check_link() {
    local label="$1"
    local source="$2"
    local target="$3"

    printf "  %-12s " "$label"
    if is_correct_symlink "$target" "$source"; then
        echo -e "${GREEN}OK${NC}  $target -> $source"
    elif [[ -L "$target" ]]; then
        echo -e "${YELLOW}WRONG${NC}  $target -> $(readlink "$target")  (expected $source)"
    elif [[ -e "$target" ]]; then
        echo -e "${YELLOW}EXISTS${NC}  $target (not a symlink)"
    else
        echo -e "${RED}MISSING${NC}  $target"
    fi
}

cmd_status() {
    echo "Symlink status:"
    check_link "nvim"       "$SRC_NVIM"       "$DST_NVIM"
    check_link "ghostty"    "$SRC_GHOSTTY"    "$DST_GHOSTTY"
    check_link "aerospace"  "$SRC_AEROSPACE"   "$DST_AEROSPACE"
    check_link "tmux"       "$SRC_TMUX"       "$DST_TMUX"
    check_link "zsh"        "$SRC_ZSH"        "$DST_ZSH"
    check_link "sketchybar" "$SRC_SKETCHYBAR" "$DST_SKETCHYBAR"
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    echo "Usage: $(basename "$0") [--dry-run] <command>"
    echo ""
    echo "Commands:"
    echo "  all          Install all configs (default)"
    echo "  nvim         Install Neovim config"
    echo "  ghostty      Install Ghostty config"
    echo "  aerospace    Install Aerospace config"
    echo "  tmux         Install tmux config"
    echo "  zsh          Install zsh config"
    echo "  sketchybar   Install Sketchybar config"
    echo "  brew         Install/upgrade all apps via Homebrew"
    echo "  status       Show current symlink status"
    echo ""
    echo "Options:"
    echo "  --dry-run    Preview changes without applying them"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Parse flags
while [[ "$1" == --* ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

COMMAND="${1:-all}"

echo "========================================"
echo "Donburi Dotfiles Setup"
echo "========================================"
echo "Source: $DONBURI_DIR"
[[ "$DRY_RUN" == true ]] && echo -e "${YELLOW}Dry run mode${NC}"
echo ""

case "$COMMAND" in
    all)        setup_all ;;
    nvim)       setup_nvim ;;
    ghostty)    setup_ghostty ;;
    aerospace)  setup_aerospace ;;
    tmux)       setup_tmux ;;
    zsh)        setup_zsh ;;
    sketchybar) setup_sketchybar ;;
    brew)       setup_brew ;;
    status)     cmd_status ;;
    help)       usage; exit 0 ;;
    *)          log_error "Unknown command: $COMMAND"; usage; exit 1 ;;
esac

echo ""
echo "========================================"

if [[ "$COMMAND" != "status" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}Dry run complete. No changes were made.${NC}"
    else
        echo -e "${GREEN}Done!${NC}"
        [[ -d "$BACKUP_DIR" ]] && echo "Backups: $BACKUP_DIR" || true
    fi
fi
