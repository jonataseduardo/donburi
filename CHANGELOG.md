# Changelog

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
