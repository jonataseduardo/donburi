# AGENT.md

Guidance for Claude Code. For user-facing docs see [README.md](README.md).

## Key Files

| File | Purpose |
|------|---------|
| `donburi` | Main CLI script (all commands) |
| `install.sh` | Curl-friendly one-liner installer |
| `admin-install.sh` | Enterprise admin install (run as root) |
| `admin-setup.sh` | Enterprise admin setup (interactive) |
| `ENTERPRISE_SETUP.md` | Enterprise deployment guide |
| `README.md` | Primary user-facing documentation |
| `CHANGELOG.md` | Release history |
| `VERSION` | Current version string |
| `.pre-commit-config.yaml` | Linting hooks (shellcheck + stylua) |

## Config Directories

| Directory | Symlink Target |
|-----------|----------------|
| `nvim/` | `~/.config/nvim` (see `.claude/rules/nvim.md` for architecture) |
| `aerospace/` | `~/.config/aerospace` |
| `sketchybar/` | `~/.config/sketchybar` |
| `btop/` | `~/.config/btop` |
| `ghostty/` | `~/Library/Application Support/com.mitchellh.ghostty/config` |
| `tmux/` | `~/.tmux.conf` |
| `zsh/` | `~/.zshrc` |
| `keybinds/` | Keybinding reference docs |

## Common Tasks

### Pre-commit / Linting

```bash
prek run --all-files          # Run all hooks (shellcheck + stylua)
prek install                  # Install git hook
```

Shell scripts: `shellcheck --severity=warning`. Add `# shellcheck shell=bash` to sourced files without a shebang.

### Update README.md

Update `README.md` whenever adding/changing components, keybindings, installation steps, or requirements. It is the single source of truth for users.

### Sync Donburi (personal use)

```bash
donburi update                # Git pull latest changes
donburi setup                 # Re-apply all symlinks
donburi setup <component>     # Re-apply one component
donburi status                # Verify symlink health
```

### Enterprise Installation

Two-phase process documented in `ENTERPRISE_SETUP.md`:

**Phase 1 - Admin** (requires root via `su -l <admin>`):
```bash
# Automated single-command install:
curl -fsSL https://raw.githubusercontent.com/jonataseduardo/donburi/main/admin-install.sh | bash

# Or via CLI:
donburi admin-setup           # Interactive admin setup
donburi admin-check           # Verify admin tasks complete
donburi brew all              # Install all brew packages
```

**Phase 2 - User** (no admin needed):
```bash
curl -fsSL https://raw.githubusercontent.com/jonataseduardo/donburi/main/install.sh | bash
donburi setup --no-brew       # Setup configs (packages already installed by admin)
donburi permissions           # Check app permissions
```

## Design Principles

- **hjkl navigation**: Aerospace uses `Alt`, Neovim uses `Ctrl`. Add `Shift` = resize.
- **Kanagawa theme**: Consistent colors across all components.
- **Non-destructive**: `donburi` backs up existing configs to `~/.config/donburi-backup-<timestamp>/`.
- **Upstream tracking**: Neovim forked from [kickstart-modular.nvim](https://github.com/dam9000/kickstart-modular.nvim) (`kickstart` git remote).
