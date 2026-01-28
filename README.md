# Donburi Dotfiles

Unified macOS development environment configuration with Aerospace window management.

## Structure

```
donburi/
├── setup.sh                    # Symlink installation script
├── aerospace/
│   ├── aerospace.toml          # Window manager config
│   └── scripts/setup-layout.sh
├── ghostty/
│   └── config                  # Terminal config (simplified, no splits)
├── nvim/
│   └── [full nvim config]
├── sketchybar/
│   ├── sketchybarrc
│   └── plugins/
│       ├── aerospace.sh
│       ├── front_app.sh
│       ├── cpu.sh
│       ├── memory.sh
│       ├── clock.sh
│       └── battery.sh
├── tmux/
│   └── tmux.conf               # Minimal config
└── zsh/
    ├── zshrc
    └── cobra.sh
```

## Keybindings

### Window Navigation (Aerospace)
- `Ctrl+h/j/k/l` - Move focus between windows
- `Alt+Shift+h/j/k/l` - Move window in direction
- `Alt+Cmd+h/j/k/l` - Resize window
- `Alt+1-9` - Switch to workspace
- `Alt+Shift+1-9` - Move window to workspace

### Neovim Splits
- `Ctrl+w+h/j/k/l` - Move between splits (vim default)
- `<leader>h/j/k/l` - Alternative split navigation

### Ghostty Terminal
- `Ctrl+Shift+t` - New tab
- `Ctrl+Shift+w` - Close tab
- `Ctrl+1-9` - Switch to tab
- `Ctrl+Shift+c/v` - Copy/paste

## Installation

```bash
cd ~/c/donburi

# Preview changes (dry run)
./setup.sh --dry-run

# Install symlinks
./setup.sh
```

## Config Aliases

After installation, use these aliases to quickly edit configs:

- `nconf` - Edit Neovim config
- `aconf` - Edit Aerospace config
- `gconf` - Edit Ghostty config
- `tconf` - Edit tmux config
- `zconf` - Edit zsh config
- `sconf` - Edit Sketchybar config

## Symlink Mapping

| Source | Target |
|--------|--------|
| `donburi/nvim` | `~/.config/nvim` |
| `donburi/ghostty/config` | `~/Library/Application Support/com.mitchellh.ghostty/config` |
| `donburi/aerospace` | `~/.config/aerospace` |
| `donburi/tmux/tmux.conf` | `~/.tmux.conf` |
| `donburi/zsh/zshrc` | `~/.zshrc` |
| `donburi/sketchybar` | `~/.config/sketchybar` |

## Sketchybar

Uses Kanagawa color scheme. Shows:
- Aerospace workspaces (1-9) on left
- Current app name
- CPU and memory usage on right
- Clock and battery on right

Start with:
```bash
brew services start sketchybar
```

## Verification

After running setup.sh:
1. Restart terminal
2. Test `Ctrl+hjkl` moves between Aerospace windows
3. Test `Ctrl+w+hjkl` moves between Neovim splits
4. Verify sketchybar shows workspaces
5. Switch workspaces with `Alt+1-9` and verify sketchybar updates
6. Test config aliases work (`nconf`, `aconf`, etc.)
