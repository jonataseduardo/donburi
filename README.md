<p align="center">
  <img src="img/donburi.png" alt="Donburi" width="200">
</p>
<h1 align="center">D O N B U R I</h1>
<p align="center">A unified macOS dotfiles configuration</p>

---

## Introduction

Donburi is a unified dotfiles repository for macOS that brings together window management, terminal, editor, and shell configurations into a cohesive development environment. Rather than treating each tool as an island, donburi creates a seamless workflow where navigation feels natural across all applications.

The philosophy centers on three principles: **consistent hjkl-based navigation** across all tools, a **unified Kanagawa color scheme** for visual harmony, and an **Aerospace-centric workflow** that makes window management effortless. Whether you're navigating Neovim splits or moving windows across workspaces, the muscle memory transfers.

Installation is **non-destructive**—existing configurations are automatically backed up before any changes are made. You can install everything at once or pick individual components to adopt incrementally.

## Features

- **Unified hjkl-based navigation** across window manager, editor, and terminal
- **Non-destructive installation** with automatic backups of existing configs
- **Modular installation** — install all components or pick what you need
- **Consistent Kanagawa color scheme** across all applications
- **Workspace-centric workflow** via Aerospace tiling window manager
- **Quick config aliases** for editing any configuration file

## Requirements

- **macOS 15+** (Sequoia)
- **Homebrew** — package manager for macOS
- **Git** — for cloning the repository

**Recommended:**
- Oh My Zsh — zsh framework
- Powerlevel10k — zsh theme

## Quick Start

```bash
git clone https://github.com/jonatas/donburi.git ~/donburi
cd ~/donburi
./setup.sh
```

Clone to any directory you prefer—the setup script creates symlinks to the standard config locations listed in [Components](#components).

## Components

| Component | Description | Config Location |
|-----------|-------------|-----------------|
| **Aerospace** | Tiling window manager | `~/.config/aerospace` |
| **Neovim** | Text editor with LSP, completions, AI | `~/.config/nvim` |
| **Ghostty** | Modern GPU-accelerated terminal | `~/Library/Application Support/com.mitchellh.ghostty/config` |
| **Sketchybar** | Custom menu bar with workspace indicators | `~/.config/sketchybar` |
| **tmux** | Terminal multiplexer (minimal config) | `~/.tmux.conf` |
| **zsh** | Shell configuration with Oh My Zsh | `~/.zshrc` |

## Keybinding Reference

Donburi uses consistent modifier patterns across tools. Aerospace uses `Alt` as the base modifier, Neovim uses `Ctrl`. Adding `Shift` triggers resize operations in both.

| Action | Aerospace | Neovim |
|--------|-----------|--------|
| Focus / Navigate | `Alt + hjkl` | `Ctrl + hjkl` |
| Resize | `Alt + Shift + hjkl` | `Ctrl + Shift + hjkl` |
| Move window | `Alt + Ctrl + hjkl` | — |
| Toggle layout | `Alt + /` | `Ctrl + /` |
| Switch workspace | `Alt + 1-9` | — |

## Installation Options

```bash
./setup.sh              # Install all components
./setup.sh nvim         # Install a single component
./setup.sh --dry-run    # Preview changes without applying
./setup.sh status       # Check symlink status
./setup.sh brew         # Install applications via Homebrew
```

Available components: `nvim`, `ghostty`, `aerospace`, `tmux`, `zsh`, `sketchybar`, `brew`

## Post-Installation

Verify the installation:

```bash
./setup.sh status       # Check all symlinks (shows OK/WRONG/MISSING)
source ~/.zshrc         # Reload shell configuration
```

Test the setup:
1. Press `Alt + hjkl` to test Aerospace window navigation
2. Press `Alt + 1-9` to switch workspaces
3. Open `nvim` and run `:checkhealth` to verify plugins

Start Sketchybar if not running:
```bash
brew services start sketchybar
```

## Config Aliases

Quick shortcuts to edit any configuration (added to your shell):

| Alias | Opens |
|-------|-------|
| `nconf` | Neovim config |
| `aconf` | Aerospace config |
| `gconf` | Ghostty config |
| `tconf` | tmux config |
| `zconf` | zsh config |
| `sconf` | Sketchybar config |

## Troubleshooting

**Aerospace not responding to keybindings**
- Grant accessibility permissions: System Settings → Privacy & Security → Accessibility → Enable AeroSpace

**Sketchybar not showing**
```bash
brew services start sketchybar
```

**Neovim plugins not loading**
- Run `:Lazy` inside Neovim to check plugin status
- Run `:checkhealth` for diagnostics

**Finding backed-up configs**
- Backups are stored in `~/.config/donburi-backup-<timestamp>/`

## License

MIT

## Acknowledgments

- [kickstart-modular.nvim](https://github.com/dam9000/kickstart-modular.nvim) — Neovim configuration foundation
- [Kanagawa](https://github.com/rebelot/kanagawa.nvim) — color scheme
- [Aerospace](https://github.com/nikitabobko/AeroSpace) — tiling window manager
- [Ghostty](https://ghostty.org/) — terminal emulator
- [Sketchybar](https://github.com/FelixKratz/SketchyBar) — custom menu bar
