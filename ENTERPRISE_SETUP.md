# Enterprise Setup Guide for Donburi

This guide helps IT administrators and users in corporate environments install and configure donburi when standard Homebrew installation may not be available or when administrative privileges are required.

## Table of Contents

- [Overview](#overview)
- [Two-Phase Installation](#two-phase-installation)
- [Phase 1: Administrator Tasks](#phase-1-administrator-tasks)
- [Phase 2: User Configuration](#phase-2-user-configuration)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)

## Overview

Donburi supports enterprise environments where:
- Users don't have sudo/admin privileges
- Homebrew needs to be installed by IT administrators
- System permissions need to be granted for applications
- Corporate security policies restrict software installation

## Two-Phase Installation

### Phase 1: Administrator Tasks

These tasks require administrative privileges and should be performed by IT staff.

#### 1.1 Install Homebrew (if not already installed)

Check if Homebrew is installed:
```bash
# Check common locations
ls -la /usr/local/bin/brew      # Intel Macs
ls -la /opt/homebrew/bin/brew    # Apple Silicon Macs
```

If not installed, install Homebrew:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### 1.2 Install Required Packages

Install all brew packages system-wide:
```bash
# Clone donburi repository
git clone https://github.com/jonatas/donburi.git /tmp/donburi

# Install all brew packages
sudo /tmp/donburi/donburi brew all
```

Or install specific categories:
```bash
sudo /tmp/donburi/donburi brew apps    # Core applications
sudo /tmp/donburi/donburi brew cli     # CLI tools
sudo /tmp/donburi/donburi brew utils   # Development utilities
sudo /tmp/donburi/donburi brew docker  # Container tools
```

#### 1.3 Grant System Permissions

**Aerospace (Window Manager)**
1. Open System Settings → Privacy & Security → Accessibility
2. Add and enable AeroSpace
3. Users will need to launch AeroSpace once after installation

**Sketchybar (Menu Bar)**
```bash
# Start sketchybar service system-wide
sudo brew services start sketchybar
```

**JankyBorders (Optional - Visual Window Borders)**
1. Open System Settings → Privacy & Security → Screen Recording
2. Add and enable Borders (if installed)
3. Note: Despite the permission name, this tool does NOT record your screen
   - It only draws colored borders around windows for visual enhancement
   - The permission is needed to overlay content on other apps' windows
   - This is completely optional and can be skipped

**Ghostty (Terminal)**
- No special permissions needed initially
- Users should launch once to trigger any permission dialogs

#### 1.4 Verify Installation

Check that packages are installed:
```bash
/tmp/donburi/donburi brew-check
```

### Phase 2: User Configuration

These tasks can be performed by regular users without administrative privileges.

#### 2.1 Install Donburi

```bash
# Install donburi to user's home directory
curl -fsSL https://raw.githubusercontent.com/jonatas/donburi/main/install.sh | bash
```

#### 2.2 Setup Configurations

If brew packages were installed by admin:
```bash
# Setup all configurations without installing brew packages
donburi setup --no-brew
```

Or setup individual components:
```bash
donburi setup nvim --no-brew       # Neovim configuration
donburi setup zsh --no-brew        # Zsh configuration
donburi setup aerospace --no-brew  # Aerospace configuration
# etc.
```

#### 2.3 Verify Setup

Check configuration status:
```bash
donburi status       # Check symlink status
donburi permissions  # Check app permissions
```

## Custom Brew Locations

If Homebrew is installed in a non-standard location, users can specify the path:

```bash
# Set custom brew path
export DONBURI_BREW_PATH=/custom/path/to/brew

# Verify it works
donburi brew-check

# Then proceed with setup
donburi setup
```

Add to shell configuration to make permanent:
```bash
echo 'export DONBURI_BREW_PATH=/custom/path/to/brew' >> ~/.zshrc
```

## Troubleshooting

### Homebrew Not Found

If `donburi brew-check` doesn't find Homebrew:

1. Check if brew is in a custom location:
   ```bash
   which brew
   find / -name brew 2>/dev/null
   ```

2. Set the path if found:
   ```bash
   export DONBURI_BREW_PATH=/path/to/brew
   ```

3. Or skip brew entirely:
   ```bash
   donburi setup --no-brew
   ```

### Permission Denied Errors

If users get permission errors:

1. Check what needs admin access:
   ```bash
   donburi permissions
   ```

2. For service management:
   ```bash
   # Admin runs:
   sudo brew services start sketchybar

   # Or user runs (if allowed):
   brew services start --user sketchybar
   ```

### Missing Dependencies

If setup fails due to missing dependencies:

1. List what would be installed:
   ```bash
   donburi brew --list
   ```

2. Share list with IT admin for installation

3. Or install manually without brew:
   - Download binaries from project websites
   - Place in `~/.local/bin` or similar
   - Update PATH accordingly

## Security Considerations

### For IT Administrators

- **Review packages**: Check `donburi brew --list` to review all packages
- **Audit scripts**: Review `donburi` and `install.sh` before deployment
- **Custom registries**: Configure Homebrew to use internal package mirrors if required
- **Permissions**: Only grant minimum required permissions:
  - Accessibility: Required for Aerospace window management
  - Screen Recording: Optional for JankyBorders visual effects (NOT actually recording)
  - No network access required for core functionality

### For Users

- **No sudo required**: User configuration doesn't need administrative privileges
- **Isolated configs**: All configurations are in user home directory
- **Backup safety**: Existing configs are backed up before changes
- **Reversible**: Can uninstall by removing symlinks and restored backups

## IT Support Template

Use this template to request IT assistance:

```
Subject: Request for Development Environment Setup

Dear IT Support,

I need to set up my development environment using the donburi dotfiles manager.
This requires the installation of Homebrew and several development packages.

Required actions:
1. Install Homebrew package manager
2. Run: sudo /path/to/donburi/donburi brew all
3. Grant accessibility permissions for AeroSpace window manager
4. Start sketchybar service

Repository: https://github.com/jonatas/donburi
Documentation: See ENTERPRISE_SETUP.md in the repository

All user configurations will be installed in my home directory without requiring
further administrative access.

Thank you,
[Your Name]
```

## Alternative Installation Methods

If Homebrew cannot be installed, users can:

1. **Use existing tools**: Skip components that require brew packages
2. **Manual installation**: Download and install binaries manually
3. **Container-based**: Use Docker/Podman for development environments
4. **Request exceptions**: Work with IT to approve specific tools

## Contact and Support

- **Repository**: https://github.com/jonatas/donburi
- **Issues**: https://github.com/jonatas/donburi/issues
- **Documentation**: README.md and CLAUDE.md

For enterprise-specific issues, please include:
- Output of `donburi brew-check`
- Output of `donburi permissions`
- Your OS version and architecture
- Any error messages received