# Agent Instructions

Shared guidance for Cursor, OpenCode, and Claude Code. For user-facing docs see [README.md](README.md).

## Working Agreement

- Inspect `git status --short` and the relevant diff before editing. Preserve existing user and other-agent changes, including untracked files.
- Keep changes focused on the requested task and follow the surrounding code's style.
- Before editing `nvim/`, read `.claude/rules/nvim.md`; its technical guidance applies to every harness.
- Config directories are symlinked into the live home directory. Editing tracked configs can affect running apps immediately. Use an isolated HOME for installer tests.
- Never include credentials from `~/.secrets`, `.env`, or local harness settings in patches or output.
- Update README.md when changing user-facing behavior. Do not bump VERSION or CHANGELOG.md unless preparing a requested release.

## Concurrent Agents and Handoffs

- Assign each task a goal, owned files, acceptance criteria, and verification command before concurrent editing starts.
- Prefer one git worktree and branch per independently editing agent. Multiple herdr panes in the same checkout share files and the Git index; they do not provide isolation.
- In a shared checkout, use non-overlapping file ownership. Coordinate before touching shared files such as `donburi`, README.md, or the instruction files.
- Do not revert, clean, stash, stage, or commit another agent's work. Commit and push only when requested, staging explicit paths.
- A coordinating agent integrates changes and runs cross-component checks. Review-only agents should report findings with file paths and actionable fixes.
- At handoff, report the goal, changed files, checks run and their results, remaining work, and any overlap with other tasks. Keep task-specific notes out of permanent rules.

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
| `btop/` | `~/.config/btop` |
| `ghostty/` | `~/Library/Application Support/com.mitchellh.ghostty/config` |
| `herdr/` | `~/.config/herdr` |
| `zsh/` | `~/.zshrc` |
| `keybinds/` | Keybinding reference docs |

## Common Tasks

### Pre-commit / Linting

```bash
prek run --all-files          # Run all hooks (shellcheck + stylua)
prek install                  # Install git hook
```

Shell scripts: `shellcheck --severity=warning`. Add `# shellcheck shell=bash` to sourced files without a shebang.

Use `zsh -n` for genuine zsh scripts; ShellCheck does not support zsh. For CLI/installer changes, run `bash test/test_donburi.sh` (it creates an isolated HOME). For harness launch changes, run `python3 test/test_harness.py`.

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

- **hjkl navigation**: `Ctrl+hjkl` moves across Neovim splits and herdr panes (smart-splits.nvim); herdr resize is `prefix+hjkl` (prefix `ctrl+b`); Neovim resize is `Ctrl+w H/J/K/L`.
- **Kanagawa theme**: Consistent colors across all components.
- **Non-destructive**: `donburi` backs up existing configs to `~/.config/donburi-backup-<timestamp>/`.
- **Upstream tracking**: Neovim forked from [kickstart-modular.nvim](https://github.com/dam9000/kickstart-modular.nvim) (`kickstart` git remote).
