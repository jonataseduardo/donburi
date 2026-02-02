# Keybinds Helpers

A collection of Bash scripts to display and manage keybindings for various applications in a beautiful, searchable table format with Kanagawa colors.

## Overview

This folder contains:
- **Shared library** (`lib/display.sh`) — Reusable table rendering functions
- **Reference files** (`config/`) — Keybinding references (`.ref` files)
- **Helper scripts** (`bin/`) — Display keybindings in the terminal

## Configuration Types

The system supports two types of configuration:

1. **Live Config** (Source of Truth)
   - Aerospace: `~/.config/aerospace/aerospace.toml`
   - Ghostty: `~/Library/Application Support/com.mitchellh.ghostty/config`
   - Scripts read these directly for always-current data

2. **Reference Files** (`.ref`)
   - Static documentation for apps without accessible configs (Slack, Chrome, macOS)
   - Generated snapshots for live configs (Aerospace, Ghostty) for fallback/documentation
   - Pipe-delimited format: `category|keybinding|description`

## Supported Applications

- **Slack** — macOS keybindings (reference file only)
- **Chrome** — Google Chrome keyboard shortcuts (reference file only)
- **Ghostty** — Terminal keybindings (reads live from `ghostty/config`)
- **Aerospace** — Window manager keybindings (reads live from `aerospace.toml`)
- **macOS** — System-wide keyboard shortcuts (reference file only)

## Quick Start

### Display Keybindings

```bash
./bin/slack-keys     # Show Slack keybindings with pager
./bin/chrome-keys    # Show Chrome keybindings with pager
./bin/ghostty-keys   # Show Ghostty keybindings with pager (reads live)
./bin/aerospace-keys # Show Aerospace keybindings with pager (reads live)
./bin/macos-keys     # Show macOS keybindings with pager
```

### View Without Pager

```bash
./bin/slack-keys --no-pager
./bin/chrome-keys --no-pager
./bin/ghostty-keys --no-pager
./bin/aerospace-keys --no-pager
./bin/macos-keys --no-pager
```

### Edit Source Configuration

```bash
./bin/slack-keys --edit       # Edit Slack reference file
./bin/chrome-keys --edit      # Edit Chrome reference file
./bin/ghostty-keys --edit     # Edit Ghostty live config (ghostty/config)
./bin/aerospace-keys --edit   # Edit Aerospace live config (aerospace.toml)
./bin/macos-keys --edit       # Edit macOS reference file
```

## Usage

### Basic Usage

Each script accepts the following options:

```
Usage: <script> [options]

Options:
  --no-pager  Output directly to terminal without pager
  --edit      Open config file in $EDITOR
  -h, --help  Show help message
```

### Examples

```bash
# Show all Slack shortcuts (opens in pager)
slack-keys

# Show all Chrome shortcuts without pager
chrome-keys --no-pager

# Edit macOS keybindings config
macos-keys --edit
```

### Pager Commands

When using the pager (bat or less):

```
/pattern    Search forward for pattern
?pattern    Search backward for pattern
n           Next search match
N           Previous search match
q           Quit pager
h           Show pager help (less only)
```

## Configuration

### Default Reference Files

Reference files are stored in `config/` (`.ref` extension):

```
keybinds/config/
├── slack.ref           # ~40 Slack shortcuts (static reference)
├── chrome.ref          # ~35 Chrome shortcuts (static reference)
├── ghostty.ref         # ~25 Ghostty shortcuts (generated from live config)
├── aerospace-main.ref  # Aerospace main mode (generated from live config)
└── macos.ref           # ~60 macOS system shortcuts (static reference)
```

**Generated Files**: `ghostty.ref` and `aerospace-main.ref` are auto-generated from live configs by `donburi setup keybinds`. Regenerate anytime you update the source configs.

### Customizing Keybindings

Each script supports user customization via `~/.config/keybinds/`:

```bash
# First time - creates a copy of defaults
slack-keys --edit

# Subsequent times - edits your custom config
slack-keys --edit
```

This creates:
```
~/.config/keybinds/
├── slack.ref
├── chrome.ref
├── ghostty.ref
├── aerospace-main.ref
└── macos.ref
```

For live config apps (Ghostty, Aerospace), overriding the `.ref` file is optional — the scripts always read the live config first.

### Config File Format

Each config file uses a simple pipe-delimited format:

```
category|keybinding|description
Navigation|Cmd+K|Quick Switcher - jump to any conversation
Messaging|Cmd+Enter|Send message
```

Requirements:
- **category** — Grouping for keybindings (e.g., "Navigation", "Messaging")
- **keybinding** — The keyboard shortcut (e.g., "Cmd+K")
- **description** — What the shortcut does

Comments start with `#`:

```bash
# This is a comment
Navigation|Cmd+K|Quick Switcher
```

## Architecture

### Directory Structure

```
keybinds/
├── lib/
│   └── display.sh              # Shared rendering library
├── config/
│   ├── slack.ref               # Slack reference file (static)
│   ├── chrome.ref              # Chrome reference file (static)
│   ├── ghostty.ref             # Ghostty reference file (generated)
│   ├── aerospace-main.ref      # Aerospace main mode reference (generated)
│   └── macos.ref               # macOS reference file (static)
├── bin/
│   ├── slack-keys              # Slack helper script (uses slack.ref)
│   ├── chrome-keys             # Chrome helper script (uses chrome.ref)
│   ├── ghostty-keys            # Ghostty helper script (reads live from ghostty/config)
│   ├── aerospace-keys          # Aerospace helper script (reads live via aerospace CLI)
│   └── macos-keys              # macOS helper script (uses macos.ref)
└── README.md
```

### Shared Library (display.sh)

The `lib/display.sh` library provides reusable functions for table rendering:

- **Color definitions** — Kanagawa color palette (BLUE, CYAN, GREEN, YELLOW, etc.)
- **Box drawing** — Table borders and separators
- **Functions** — `draw_header()`, `draw_category()`, `draw_row()`, `draw_footer()`, etc.
- **Pager setup** — `setup_pager()` for bat/less detection

This allows consistent styling across all keybinding helpers.

## Adding New Applications

To add a new application (e.g., VS Code):

1. **Create config file**: `config/vscode.conf`

```
# VS Code macOS Keybindings
Navigation|Cmd+P|Quick File Open
Navigation|Cmd+Shift+P|Command Palette
Editing|Cmd+/|Toggle Line Comment
```

2. **Create helper script**: `bin/vscode-keys`

Copy an existing script (e.g., `chrome-keys`) and modify:
- Change `CONFIG_FILE` path
- Change header title in `draw_header`
- Update help text to reference VS Code

3. **Make it executable**:

```bash
chmod +x bin/vscode-keys
```

## Design Principles

- **Kanagawa theme** — Consistent with donburi's design aesthetic
- **Non-intrusive defaults** — Config files are optional; defaults always work
- **User-editable** — Easy customization via `~/.config/keybinds/`
- **Reusable library** — Shared code reduces duplication
- **Pager-friendly** — Built-in search and navigation

## Dependencies

- **bash** (4.0+)
- **bat** or **less** (for paging, optional)
- **standard Unix tools** — awk, sed, xargs

## Similar Projects

- `aerospace/scripts/aerospace-keys-helper.sh` — Aerospace window manager keybindings
- This keybinds system extracts the table rendering into a reusable library

## Notes

- Keybindings are macOS-specific (Cmd, Opt, Ctrl, Shift notation)
- Config files use simple pipe-delimited format for easy editing
- Scripts gracefully degrade if pager is unavailable
- User configs override defaults (no need to edit defaults)

## Contributing

To update default keybindings:

1. Edit the config file (e.g., `config/slack.conf`)
2. Test with: `./bin/slack-keys --no-pager`
3. Verify pager works: `./bin/slack-keys`

For new applications, follow the "Adding New Applications" section above.
