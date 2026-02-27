# Changelog

## [0.6.1] - 2026-02-24

### Fixed
- **sketchybar**: Only show VPN icon when VPN is connected
- **aerospace,sketchybar**: Prevent SketchyBar from disappearing in fullscreen

### Changed
- **sketchybar**: Apply Kanagawa Vibrant theme for cohesive look with tmux/neovim
- **akeys**: Update aerospace keybinding references

## [0.6.0] - 2026-02-18

### Added
- **nvim, tmux**: Unified Kanagawa vibrant theme across lualine and tmux status bar with matching surimiOrange accents, flame separators, and purple split dividers
- **nvim, tmux**: Seamless `Ctrl+hjkl` navigation between Neovim splits and tmux panes via smart-splits with tmux multiplexer backend
- **nvim**: Resolve ruff formatter dynamically per uv project context (uv run → global → uvx fallback)
- **keybinds**: Add `navigation-keys` helper (`nkeys`) for tmux and Neovim navigation reference
- **zsh**: Add `v=nvim` and `dconf` (donburi root) aliases

### Changed
- **nvim**: Overhaul keymaps.lua — remove 150+ lines of redundant navigation code, replace with clean resize/reposition bindings
- **nvim**: Simplify ghostty.lua comments to reflect tmux + smart-splits architecture
- **tmux**: Expand tmux.conf from minimal config to full Kanagawa-themed setup with smart-splits integration, pane resizing, and new plugins
- **README**: Update keybinding reference table to include tmux column and document new aliases

## [0.5.0] - 2026-02-17

### Added
- **Agent Skills**: Added `.claude/skills/changelog/` skill for automated changelog generation and semver version bumping from conventional commits

### Changed
- **CI**: Split brew tests into a separate `ci-brew.yml` workflow on macOS; run full CI on `ubuntu-latest` instead of `macos-latest`
- **Tests**: Reorganized test suite to separate brew-dependent tests, skip gracefully when Homebrew is not available

## [0.4.2] - 2026-02-17

### Added
- **Agent Skills**: Added `.claude/skills/create-pr/` skill for automated PR creation with conventional commits, pre-flight checks, and diff-aware descriptions
- **Agent Rules**: Moved `nvim/CLAUDE.md` to `.claude/rules/nvim.md` with `paths: nvim/**` scoping so guidance loads only for Neovim changes
- **AGENT.md**: New top-level agent file with key file index and task-oriented sections (replaces verbose `CLAUDE.md`)

### Changed
- **StyLua Hook**: Changed from check-only (`--check`) to auto-format mode so `prek run --all-files` fixes Lua formatting in place
- **Gitsigns**: Added inline git blame with 300ms delay; consolidated diff keymaps around diffview.nvim

### Fixed
- **Pre-commit Skill**: Updated create-pr skill to use `prek` instead of `pre-commit` (which is not in PATH)
- **Lua Formatting**: Applied StyLua formatting across 22 Lua files — parenthesized `require` calls, consistent table formatting, trailing newlines

## [0.4.1] - 2026-02-17

### Fixed
- **Network Resilience**: Added `|| log_warn` fallbacks to all 8 network-dependent operations (git clone for lazy.nvim, TPM, Powerlevel10k; curl for Oh My Zsh, rustup, uv, bun) so setup always completes symlinks even when external services are unreachable
- **Enterprise Package Lists**: Synced `admin-install.sh` and `admin-setup.sh` package lists with `donburi` source of truth — added missing `telnet`/`gh`, removed `discord`, fixed `python@3`
- **CI Stability**: Resolved 5 deterministic CI (Full) failures caused by `set -e` aborting setup functions before symlink creation; added `|| log_warn` fallbacks so symlinks always get created regardless of brew status
- **Oh My Zsh**: Set `KEEP_ZSHRC=yes` to prevent `.zshrc` overwrites during installation
- **CI Hardening**: Added `timeout-minutes` on all CI jobs, pinned prek version, triggered CI (Full) on push to `dev` to catch macOS integration failures before PRs to main

### Added
- **Enterprise Tests**: Added comprehensive enterprise test coverage — `--no-brew` setup flow with full symlink and idempotency verification, `admin-check` command validation, script syntax checks for all enterprise scripts, and per-component status assertions
- **Package Drift Detection**: Added CI test that automatically catches future package list drift between `donburi` and enterprise scripts

## [0.4.0] - 2026-02-08

### Added
- **Dashboard**: Added [snacks.nvim](https://github.com/folke/snacks.nvim) dashboard with Donburi ASCII art header in Kanagawa palette gradient colors
  - Quick actions: find file, find text, recent files, config, Lazy, quit
  - Startup time display
- Updated screenshot to reflect new dashboard

## [0.3.1] - 2026-02-07

### Added
- **GitHub Code Review**: Added [octo.nvim](https://github.com/pwntester/octo.nvim) plugin for full GitHub PR review workflow from Neovim
  - PR management: list, search, checkout, diff, merge, mark as ready
  - Code review: start, submit, discard, resume reviews with inline comments
  - Thread management: resolve/unresolve review threads
  - Issue management: list, search, create issues
  - All keybindings under `<leader>o` (Octo) with which-key sub-groups
- **Diffview PR Diff**: `<leader>od` opens PR diffs file-by-file via diffview.nvim (auto-detects base branch); raw unified diff moved to `<leader>oD`

## [0.3.0] - 2026-02-07

### Added
- **Admin Install Script**: New `admin-install.sh` for single-command enterprise setup (curl-friendly)
- **Language Runtimes**: Auto-install Rust (rustup), uv (Python), and bun (JavaScript) during `donburi setup`
- **Code Formatters Guide**: README section documenting available formatters (shfmt, ruff, prettier, taplo) and install commands
- **Brew Packages**: Added `postgresql@18`, `sqlite`, `go`, `telnet` to utils; `btop` to apps category
- **Agent Instructions**: Renamed `CLAUDE.md` to `AGENT.md` for tool-agnostic naming

### Changed
- **Enterprise Admin Flow**: Replaced `sudo` pattern with `su -l <admin>` across all admin scripts, documentation, and help text
- **Sketchybar Service Management**: Uses `get_console_user()` helper to start sketchybar as the logged-in user instead of system-wide
- **Documentation**: Updated ENTERPRISE_SETUP.md, README.md, and install.sh to reflect new admin workflow

### Fixed
- Indentation in `brew-check` admin/root privilege message
- Stale `CLAUDE.md` and version references in README.md
- PostgreSQL version bumped from @17 to @18 (latest available)

## [0.2.0] - 2026-02-01

### Added
- **Enterprise Setup**: Admin-friendly commands (`admin-setup`, `admin-check`) for corporate environments
- **Keybinds Management System**: Unified keybinding commands (`akeys`, `skeys`, `ckeys`, `gkeys`, `mkeys`) with color-coded display
- **Brew Enhancement**: New `brew-check` command to verify Homebrew installation status
- **Sketchybar Improvements**: Added Slack widget with dynamic status indicators
- **Documentation**: Comprehensive ENTERPRISE_SETUP.md guide for IT administrators and restricted environments
- **Extended README**: Added CLI reference, environment variables, keybind helper section, and development workflow

### Changed
- **README Expansion**: Documented all CLI commands, package categories, admin workflows, and enterprise usage
- **Sketchybar Styling**: Improved widget visuals with better padding and workspace indicators
- **Brew Package Organization**: Better categorization of packages (apps, cli, utils, docker)
- **Setup Options**: Added `--no-brew` flag for users in restricted environments

### Fixed
- Shellcheck warnings for reserved variables and zsh syntax
- Improved Homebrew detection for enterprise environments with custom installation paths
- Better error handling in gitignore configuration

## [0.1.0] - 2026-01-29

### Added
- Initial versioned release
- CLI commands: setup, status, brew, update, help
- GitHub Actions CI (quick + full)
- Components: nvim, ghostty, aerospace, tmux, zsh, sketchybar
