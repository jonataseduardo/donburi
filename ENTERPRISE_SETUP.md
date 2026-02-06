# Enterprise Setup Guide for Donburi

This guide helps IT administrators and users in corporate environments install and configure donburi when standard Homebrew installation may not be available or when administrative privileges are required.

## Table of Contents

- [Express Admin Setup](#express-admin-setup)
- [Detailed Two-Phase Installation](#detailed-two-phase-installation)
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

## Express Admin Setup

**For administrators who want the fastest setup:**

### Prerequisites
- macOS 15+ (Sequoia)
- Administrator privileges
- Homebrew installed (or permission to install it)

### Quick Setup (5 minutes)

1. **Install Homebrew** (if not already installed):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

2. **Run the admin install command (via `su`)**:
```bash
# Enter admin shell
su -l <admin>

# Run single-command admin install
curl -fsSL https://raw.githubusercontent.com/jonatas/donburi/main/admin-install.sh | bash
```

Note: `admin-install.sh` assumes Homebrew is already installed.

This single command will:
- ✅ Install all required packages (neovim, ghostty, aerospace, sketchybar, tmux, etc.)
- ✅ Start the sketchybar service for the logged-in user (auto-detected via `/dev/console`)
- ✅ Open the System Settings panes for required permissions

3. **Tell users to run**:
```bash
# Install donburi
curl -fsSL https://raw.githubusercontent.com/jonatas/donburi/main/install.sh | bash

# Setup configs (packages already installed by admin)
donburi setup --no-brew
```

That's it! For detailed manual setup, continue reading below.

## Detailed Two-Phase Installation

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
su -l <admin> -c "/tmp/donburi/donburi brew all"
```

Or install specific categories:
```bash
su -l <admin> -c "/tmp/donburi/donburi brew apps"    # Core applications
su -l <admin> -c "/tmp/donburi/donburi brew cli"     # CLI tools
su -l <admin> -c "/tmp/donburi/donburi brew utils"   # Development utilities
su -l <admin> -c "/tmp/donburi/donburi brew docker"  # Container tools
```

#### 1.3 Grant System Permissions

If macOS asks for administrator authentication during this step, enter the admin password in the prompt.

**Aerospace (Window Manager)**
1. Open System Settings → Privacy & Security → Accessibility
2. Add and enable AeroSpace
3. Users will need to launch AeroSpace once after installation

**Sketchybar (Menu Bar)**
```bash
# Start sketchybar service for the logged-in user (console session)
CONSOLE_USER="$(stat -f %Su /dev/console)"
su -l "$CONSOLE_USER" -c "brew services start --user sketchybar"
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

Run the admin check command to verify all tasks are complete:
```bash
/tmp/donburi/donburi admin-check
```

This will verify:
- Homebrew installation
- All required packages
- Service status
- System permissions (if apps have been launched)

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
    # Admin runs (targeting console user):
    CONSOLE_USER="$(stat -f %Su /dev/console)"
    su -l "$CONSOLE_USER" -c "brew services start --user sketchybar"

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
Subject: Request for Development Environment Setup (Donburi)

Dear IT Support,

I need to set up my development environment using the donburi dotfiles manager.
This requires administrator privileges for initial setup.

Quick Setup Instructions:
1. Enter admin shell: su -l <admin>
2. Run automated setup: curl -fsSL https://raw.githubusercontent.com/jonatas/donburi/main/admin-install.sh | bash
3. Follow the on-screen prompts for permissions

The admin install command will:
- Install all required packages (assumes Homebrew is already installed)
- Start the Sketchybar service for the logged-in user
- Open System Settings panes for permissions

Repository: https://github.com/jonatas/donburi
Full docs: ENTERPRISE_SETUP.md (Express Admin Setup section)

After admin setup, I can configure my user environment without further admin access.

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
