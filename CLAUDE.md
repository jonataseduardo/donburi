# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

For general documentation, installation, keybindings, and usage, see [README.md](README.md).

## Quick Reference

```bash
./setup.sh              # Install all configs
./setup.sh <component>  # Install single component (nvim|ghostty|aerospace|tmux|zsh|sketchybar|brew)
./setup.sh --dry-run    # Preview changes
./setup.sh status       # Check symlink status
```

## Project Structure

Each tool lives in its own directory and is symlinked to its config location by `setup.sh`:

| Directory | Symlink Target |
|-----------|----------------|
| `nvim/` | `~/.config/nvim` |
| `aerospace/` | `~/.config/aerospace` |
| `sketchybar/` | `~/.config/sketchybar` |
| `ghostty/` | `~/Library/Application Support/com.mitchellh.ghostty/config` |
| `tmux/` | `~/.tmux.conf` |
| `zsh/` | `~/.zshrc` |

## Development Guidelines

### Design Principles

1. **Consistent hjkl navigation** — Aerospace uses `Alt`, Neovim uses `Ctrl`. Adding `Shift` = resize in both.
2. **Kanagawa theme** — Maintain color consistency across all components.
3. **Non-destructive setup** — `setup.sh` backs up existing configs to `~/.config/donburi-backup-<timestamp>/`.

### Component-Specific Notes

- **Neovim** (largest component): See `nvim/CLAUDE.md` for detailed architecture. Plugins in `nvim/lua/kickstart/plugins/` (core) and `nvim/lua/custom/plugins/` (custom, auto-imported).
- **Sketchybar**: Shell-script plugins in `sketchybar/plugins/`. Integrates with Aerospace for workspace indicators.
- **Ghostty/tmux**: Minimal configs — Aerospace handles window management.

### When Updating README.md

Keep README.md as the primary user-facing documentation. Update it when:
- Adding new components or features
- Changing keybindings or installation steps
- Modifying requirements or troubleshooting info
