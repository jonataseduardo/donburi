# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Donburi is a unified macOS dotfiles repository. Each tool (nvim, aerospace, ghostty, tmux, zsh, sketchybar) lives in its own directory and is installed via symlinks managed by `setup.sh`.

## Commands

```bash
# Install all configs (creates symlinks)
./setup.sh

# Preview changes without applying
./setup.sh --dry-run

# Install a single component
./setup.sh nvim|ghostty|aerospace|tmux|zsh|sketchybar|brew

# Check symlink status
./setup.sh status
```

For Neovim-specific commands, see `nvim/CLAUDE.md`.

## Testing the Installation

After running `./setup.sh`, verify everything is correctly linked:

```bash
# Check all symlinks are correct (shows OK/WRONG/MISSING for each)
./setup.sh status

# Verify individual symlinks manually
ls -la ~/.config/nvim                # should point to donburi/nvim
ls -la ~/.config/aerospace           # should point to donburi/aerospace
ls -la ~/.config/sketchybar          # should point to donburi/sketchybar
ls -la ~/.tmux.conf                  # should point to donburi/tmux/tmux.conf
ls -la ~/.zshrc                      # should point to donburi/zsh/zshrc
ls -la ~/Library/Application\ Support/com.mitchellh.ghostty/config  # should point to donburi/ghostty/config
```

Functional checks after restarting the terminal:
1. `source ~/.zshrc` loads without errors
2. Config aliases work: `nconf`, `aconf`, `gconf`, `tconf`, `zconf`, `sconf`
3. `nvim` opens without plugin errors (run `:checkhealth` inside Neovim)
4. `Alt+hjkl` moves focus between Aerospace windows
5. `Alt+1-9` switches workspaces
6. `brew services start sketchybar` shows the bar with workspace indicators

If `setup.sh` backed up existing configs, they are saved in `~/.config/donburi-backup-<timestamp>/`.

## Architecture

### Symlink-Based Configuration

`setup.sh` symlinks each tool's directory to its expected config location (e.g., `donburi/nvim` → `~/.config/nvim`). It backs up existing configs before replacing them. Each tool can be installed independently.

### Navigation Consistency

All tools use hjkl-based navigation with consistent modifier patterns:
- **Aerospace (window manager):** `Alt+hjkl` for focus, `Alt+Shift+hjkl` for resize, `Alt+Ctrl+hjkl` for move, `Alt+/` for layout toggle
- **Neovim splits:** `Ctrl+hjkl` for navigation, `Ctrl+Shift+hjkl` for resize, `Ctrl+/` for layout toggle
- **Workspace switching:** `Alt+1-9`
- **Pattern:** Aerospace uses `Alt` as base modifier, Neovim uses `Ctrl`. Adding `Shift` = resize in both.

### Kanagawa Theme

Consistent Kanagawa color scheme across all applications (Neovim, Ghostty, Sketchybar).

### Neovim (largest component)

Based on kickstart-modular.nvim with lazy.nvim plugin management. Core plugins live in `nvim/lua/kickstart/plugins/`, custom additions in `nvim/lua/custom/plugins/` (auto-imported). See `nvim/CLAUDE.md` for detailed Neovim architecture.

### Sketchybar

Shell-script plugin architecture in `sketchybar/plugins/`. Integrates with Aerospace for workspace indicators. Start with `brew services start sketchybar`.

### Ghostty Terminal

Simplified config (no splits) — relies on Aerospace for window management instead.

### tmux

Minimal config — Aerospace handles window/pane management.
