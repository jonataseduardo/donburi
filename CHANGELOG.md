# Changelog

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
