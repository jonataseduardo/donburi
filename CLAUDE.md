# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

For general documentation, installation, keybindings, and usage, see [README.md](README.md).

## Quick Reference

```bash
donburi setup              # Install all configs
donburi setup <component>  # Install single component (nvim|ghostty|aerospace|tmux|zsh|sketchybar|btop)
donburi setup --dry-run    # Preview changes
donburi status             # Check symlink status
donburi brew [category]    # Install packages (apps|cli|docker|all)
donburi update             # Update donburi (git pull)
```

## Project Structure

Each tool lives in its own directory and is symlinked to its config location by `donburi`:

| Directory | Symlink Target |
|-----------|----------------|
| `nvim/` | `~/.config/nvim` |
| `aerospace/` | `~/.config/aerospace` |
| `sketchybar/` | `~/.config/sketchybar` |
| `btop/` | `~/.config/btop` |
| `ghostty/` | `~/Library/Application Support/com.mitchellh.ghostty/config` |
| `tmux/` | `~/.tmux.conf` |
| `zsh/` | `~/.zshrc` |

## CLI Files

| File | Purpose |
|------|---------|
| `donburi` | Main CLI script (multi-command tool) |
| `install.sh` | Curl-friendly installer for one-liner installation |

## Development Guidelines

### Design Principles

1. **Consistent hjkl navigation** — Aerospace uses `Alt`, Neovim uses `Ctrl`. Adding `Shift` = resize in both.
2. **Kanagawa theme** — Maintain color consistency across all components.
3. **Non-destructive setup** — `donburi` backs up existing configs to `~/.config/donburi-backup-<timestamp>/`.

### Component-Specific Notes

- **Neovim** (largest component): See `nvim/CLAUDE.md` for detailed architecture. Plugins in `nvim/lua/kickstart/plugins/` (core) and `nvim/lua/custom/plugins/` (custom, auto-imported).
- **Sketchybar**: Shell-script plugins in `sketchybar/plugins/`. Integrates with Aerospace for workspace indicators.
- **btop**: Resource monitor config with Kanagawa wave theme and custom theme files.
- **Ghostty/tmux**: Minimal configs — Aerospace handles window management.

### Upstream Tracking

The Neovim config is forked from [kickstart-modular.nvim](https://github.com/dam9000/kickstart-modular.nvim), available as the `kickstart` git remote. To review upstream changes:

```bash
git fetch kickstart
git diff HEAD...kickstart/main -- nvim/lua/kickstart/
```

### Linting

This project uses [prek](https://github.com/j178/prek) as a pre-commit hook framework. Hooks are defined in `.pre-commit-config.yaml`.

```bash
prek run --all-files    # Run all hooks on every file
prek install            # Install git pre-commit hook
```

Shell scripts must pass `shellcheck --severity=warning`. Add `# shellcheck shell=bash` to sourced files that lack a shebang.

### When Updating README.md

Keep README.md as the primary user-facing documentation. Update it when:
- Adding new components or features
- Changing keybindings or installation steps
- Modifying requirements or troubleshooting info
