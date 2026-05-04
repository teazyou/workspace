# macOS Tiling Window Manager Setup - AI-Actionable Tutorial

This tutorial provides structured instructions for AI assistants to configure AeroSpace, SketchyBar, and JankyBorders on a user's macOS system. Each section includes preconditions, exact commands, verification steps, and troubleshooting guidance.

---

## Document Metadata

```yaml
version: "1.0"
last_verified: "2026-01-02"
target_os: "macOS 14.0+ (Sonoma or later)"
tools_covered:
  - AeroSpace (tiling window manager)
  - SketchyBar (custom menu bar)
  - JankyBorders (window borders)
official_docs:
  aerospace: "https://nikitabobko.github.io/AeroSpace/guide"
  sketchybar: "https://felixkratz.github.io/SketchyBar/setup"
  jankyborders: "https://github.com/FelixKratz/JankyBorders"
```

---

## Table of Contents

1. [Prerequisites Check](#1-prerequisites-check)
2. [Install Homebrew](#2-install-homebrew)
3. [Install AeroSpace](#3-install-aerospace)
4. [Configure AeroSpace](#4-configure-aerospace)
5. [Install SketchyBar](#5-install-sketchybar)
6. [Configure SketchyBar](#6-configure-sketchybar)
7. [Install JankyBorders](#7-install-jankyborders)
8. [Configure JankyBorders](#8-configure-jankyborders)
9. [Integrate All Components](#9-integrate-all-components)
10. [Workspace Configuration](#10-workspace-configuration)
11. [Gap Configuration](#11-gap-configuration)
12. [Custom Keybindings](#12-custom-keybindings)
13. [Monitor Configuration](#13-monitor-configuration)
14. [Floating Window Rules](#14-floating-window-rules)
15. [Troubleshooting](#15-troubleshooting)
16. [Common User Requests](#16-common-user-requests)

---

## 1. Prerequisites Check

### AI Instructions

Before making any changes, verify the user's system meets requirements.

```bash
# Check macOS version (requires 14.0+ for JankyBorders)
sw_vers -productVersion

# Check if Homebrew is installed
which brew

# Check if AeroSpace is installed
which aerospace || brew list --cask | grep aerospace

# Check if SketchyBar is installed
which sketchybar || brew list | grep sketchybar

# Check if JankyBorders (borders) is installed
which borders || brew list | grep borders

# Check existing config files
ls -la ~/.aerospace.toml 2>/dev/null
ls -la ~/.config/aerospace/aerospace.toml 2>/dev/null
ls -la ~/.config/sketchybar/sketchybarrc 2>/dev/null
ls -la ~/.config/borders/bordersrc 2>/dev/null
```

### Verification Output Interpretation

- macOS version should be `14.0` or higher
- If `brew` not found → proceed to Section 2
- If tools not found → proceed to respective installation sections
- If config files exist → back them up before modifying

---

## 2. Install Homebrew

### Preconditions
- macOS system
- Internet connection
- Admin privileges

### Commands

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# For Apple Silicon Macs, add to PATH (if not already configured)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### Verification

```bash
# Should output Homebrew version
brew --version
```

---

## 3. Install AeroSpace

### Preconditions
- Homebrew installed
- macOS 13.0+

### Commands

```bash
# Install AeroSpace via Homebrew cask
brew install --cask nikitabobko/tap/aerospace
```

### Verification

```bash
# Check installation
which aerospace
# Expected: /opt/homebrew/bin/aerospace or similar

# Check version
aerospace --version
```

### Post-Installation

```bash
# Start AeroSpace (first time)
open -a AeroSpace

# Grant accessibility permissions when prompted:
# System Settings → Privacy & Security → Accessibility → Enable AeroSpace
```

---

## 4. Configure AeroSpace

### Preconditions
- AeroSpace installed
- Text editor available

### Configuration File Locations

AeroSpace checks these locations in order:
1. `~/.aerospace.toml` (recommended)
2. `~/.config/aerospace/aerospace.toml`

### Download Default Configuration

```bash
# Download default config to home directory
curl -L https://raw.githubusercontent.com/nikitabobko/AeroSpace/main/default-config.toml -o ~/.aerospace.toml
```

### Minimal Configuration Template

```bash
cat > ~/.aerospace.toml << 'EOF'
# AeroSpace Configuration
# Documentation: https://nikitabobko.github.io/AeroSpace/guide

# Config version (use 2 for latest features)
config-version = 2

# Start at login
start-at-login = true

# Commands to run after AeroSpace starts
after-startup-command = []

# Normalizations (recommended to keep enabled)
enable-normalization-flatten-containers = true
enable-normalization-opposite-orientation-for-nested-containers = true

# Accordion padding
accordion-padding = 30

# Default layout (tiles or accordion)
default-root-container-layout = 'tiles'

# Default orientation (horizontal, vertical, or auto)
default-root-container-orientation = 'auto'

# Keyboard layout preset (qwerty or dvorak)
key-mapping.preset = 'qwerty'

# Mouse follows focus when monitor changes
on-focused-monitor-changed = ['move-mouse monitor-lazy-center']

# Gaps configuration
[gaps]
inner.horizontal = 10
inner.vertical = 10
outer.left = 10
outer.bottom = 10
outer.top = 10
outer.right = 10

# Main mode keybindings
[mode.main.binding]
# Layout switching
alt-slash = 'layout tiles horizontal vertical'
alt-comma = 'layout accordion horizontal vertical'

# Focus movement
alt-h = 'focus left'
alt-j = 'focus down'
alt-k = 'focus up'
alt-l = 'focus right'

# Window movement
alt-shift-h = 'move left'
alt-shift-j = 'move down'
alt-shift-k = 'move up'
alt-shift-l = 'move right'

# Resize
alt-minus = 'resize smart -50'
alt-equal = 'resize smart +50'

# Workspaces
alt-1 = 'workspace 1'
alt-2 = 'workspace 2'
alt-3 = 'workspace 3'
alt-4 = 'workspace 4'
alt-5 = 'workspace 5'
alt-6 = 'workspace 6'
alt-7 = 'workspace 7'
alt-8 = 'workspace 8'
alt-9 = 'workspace 9'

# Move to workspaces
alt-shift-1 = 'move-node-to-workspace 1'
alt-shift-2 = 'move-node-to-workspace 2'
alt-shift-3 = 'move-node-to-workspace 3'
alt-shift-4 = 'move-node-to-workspace 4'
alt-shift-5 = 'move-node-to-workspace 5'
alt-shift-6 = 'move-node-to-workspace 6'
alt-shift-7 = 'move-node-to-workspace 7'
alt-shift-8 = 'move-node-to-workspace 8'
alt-shift-9 = 'move-node-to-workspace 9'

# Workspace navigation
alt-tab = 'workspace-back-and-forth'
alt-shift-tab = 'move-workspace-to-monitor --wrap-around next'

# Enter service mode
alt-shift-semicolon = 'mode service'

# Service mode
[mode.service.binding]
esc = ['reload-config', 'mode main']
r = ['flatten-workspace-tree', 'mode main']
f = ['layout floating tiling', 'mode main']
backspace = ['close-all-windows-but-current', 'mode main']
EOF
```

### Verification

```bash
# Validate config syntax by reloading
aerospace reload-config

# Check if AeroSpace is running
pgrep -x AeroSpace
```

---

## 5. Install SketchyBar

### Preconditions
- Homebrew installed
- macOS with "Displays have separate Spaces" enabled

### System Setting Verification

**Important Note on "Displays have separate Spaces":**

There is a conflict between SketchyBar and AeroSpace requirements:
- **SketchyBar** requires "Displays have separate Spaces" to be **ON** (the macOS default)
- **AeroSpace** recommends it be **OFF** for better stability and performance

**Recommendation:** Keep it **ON** (default) for compatibility with SketchyBar. If you experience focus or performance issues, you may consider disabling it, but some SketchyBar features may not work correctly.

```bash
# Check current setting (no output = enabled, which is the default)
defaults read com.apple.spaces spans-displays 2>/dev/null || echo "Setting is at default (separate spaces enabled)"
```

### Commands

```bash
# Add the tap and install
brew tap FelixKratz/formulae
brew install sketchybar
```

### Create Default Configuration

```bash
# Create config directory
mkdir -p ~/.config/sketchybar/plugins

# Copy example configuration
cp $(brew --prefix)/share/sketchybar/examples/sketchybarrc ~/.config/sketchybar/sketchybarrc
cp -r $(brew --prefix)/share/sketchybar/examples/plugins/ ~/.config/sketchybar/plugins/

# Make plugins executable
chmod +x ~/.config/sketchybar/plugins/*
```

### Verification

```bash
# Start SketchyBar
brew services start sketchybar

# Or run manually to see output
sketchybar

# Check if running
pgrep -x sketchybar
```

---

## 6. Configure SketchyBar

### Preconditions
- SketchyBar installed
- AeroSpace installed (for workspace integration)

### AeroSpace Workspace Integration

#### Step 1: Create the aerospace plugin script

```bash
cat > ~/.config/sketchybar/plugins/aerospace.sh << 'EOF'
#!/usr/bin/env bash

# AeroSpace workspace indicator plugin for SketchyBar
# Makes it executable: chmod +x ~/.config/sketchybar/plugins/aerospace.sh

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --set $NAME background.drawing=on
else
    sketchybar --set $NAME background.drawing=off
fi
EOF

chmod +x ~/.config/sketchybar/plugins/aerospace.sh
```

#### Step 2: Update sketchybarrc for AeroSpace workspaces

```bash
# Backup existing config
cp ~/.config/sketchybar/sketchybarrc ~/.config/sketchybar/sketchybarrc.backup

# Create new config with AeroSpace integration
cat > ~/.config/sketchybar/sketchybarrc << 'EOF'
#!/bin/bash

# SketchyBar configuration with AeroSpace workspace integration

# Bar appearance
sketchybar --bar height=32 \
                 blur_radius=30 \
                 position=top \
                 sticky=on \
                 padding_left=10 \
                 padding_right=10 \
                 color=0x40000000

# Default settings
sketchybar --default icon.font="SF Pro:Semibold:14.0" \
                     icon.color=0xffffffff \
                     label.font="SF Pro:Semibold:14.0" \
                     label.color=0xffffffff \
                     padding_left=5 \
                     padding_right=5 \
                     label.padding_left=4 \
                     label.padding_right=4 \
                     icon.padding_left=4 \
                     icon.padding_right=4

# Register AeroSpace workspace change event
sketchybar --add event aerospace_workspace_change

# Add workspace indicators for each AeroSpace workspace
for sid in $(aerospace list-workspaces --all); do
    sketchybar --add item space.$sid left \
        --subscribe space.$sid aerospace_workspace_change \
        --set space.$sid \
        background.color=0x44ffffff \
        background.corner_radius=5 \
        background.height=20 \
        background.drawing=off \
        label="$sid" \
        click_script="aerospace workspace $sid" \
        script="$CONFIG_DIR/plugins/aerospace.sh $sid"
done

# Add separator
sketchybar --add item space_separator left \
           --set space_separator icon="│" \
                                 icon.color=0x44ffffff \
                                 padding_left=10 \
                                 padding_right=10 \
                                 label.drawing=off

# Front app indicator
sketchybar --add item front_app left \
           --set front_app script="$CONFIG_DIR/plugins/front_app.sh" \
           --subscribe front_app front_app_switched

# Clock on the right
sketchybar --add item clock right \
           --set clock update_freq=10 \
                       script="$CONFIG_DIR/plugins/clock.sh"

# Initialize
sketchybar --update
EOF
```

#### Step 3: Create supporting plugins

```bash
# Clock plugin
cat > ~/.config/sketchybar/plugins/clock.sh << 'EOF'
#!/bin/bash
sketchybar --set $NAME label="$(date '+%H:%M')"
EOF
chmod +x ~/.config/sketchybar/plugins/clock.sh

# Front app plugin
cat > ~/.config/sketchybar/plugins/front_app.sh << 'EOF'
#!/bin/bash
sketchybar --set $NAME label="$INFO"
EOF
chmod +x ~/.config/sketchybar/plugins/front_app.sh
```

### Verification

```bash
# Restart SketchyBar
brew services restart sketchybar

# Or kill and restart manually
pkill sketchybar && sketchybar &
```

---

## 7. Install JankyBorders

### Preconditions
- Homebrew installed
- macOS 14.0+ (Sonoma or later)

### Commands

```bash
# Add tap (if not already added from SketchyBar)
brew tap FelixKratz/formulae

# Install borders
brew install borders
```

### Verification

```bash
# Check installation
which borders
# Expected: /opt/homebrew/bin/borders

# Test run (will show default white borders)
borders &

# Stop test
pkill borders
```

---

## 8. Configure JankyBorders

### Preconditions
- JankyBorders installed

### Option A: Command Line Configuration (via AeroSpace)

No separate config file needed. Configure in `~/.aerospace.toml`:

```toml
after-startup-command = [
    'exec-and-forget borders active_color=0xffe1e3e4 inactive_color=0xff494d64 width=5.0'
]
```

### Option B: Dedicated Config File

```bash
# Create config directory and file
mkdir -p ~/.config/borders

cat > ~/.config/borders/bordersrc << 'EOF'
#!/bin/bash

options=(
    style=round
    width=6.0
    hidpi=off
    active_color=0xffe2e2e3
    inactive_color=0xff414550
)

borders "${options[@]}"
EOF

chmod +x ~/.config/borders/bordersrc
```

### Color Format Reference

JankyBorders uses `0xAARRGGBB` format:
- `AA` = Alpha (transparency): `ff` = solid, `00` = transparent
- `RR` = Red component
- `GG` = Green component  
- `BB` = Blue component

**Common Colors:**
| Color | Hex Code |
|-------|----------|
| White | `0xffffffff` |
| Light gray | `0xffe1e3e4` |
| Dark gray | `0xff494d64` |
| Red | `0xffff0000` |
| Green | `0xff00ff00` |
| Blue | `0xff0000ff` |
| Transparent | `0x00000000` |

### Verification

```bash
# Start with config file
borders

# Or start with inline options
borders active_color=0xffe1e3e4 inactive_color=0xff494d64 width=5.0

# Check if running
pgrep borders
```

---

## 9. Integrate All Components

### Preconditions
- All three tools installed
- Individual configurations working

### Update AeroSpace Config for Full Integration

```bash
# Edit ~/.aerospace.toml to include startup commands

cat > ~/.aerospace.toml << 'EOF'
# AeroSpace with SketchyBar and JankyBorders Integration

# Config version (use 2 for latest features)
config-version = 2

start-at-login = true

# Start SketchyBar and JankyBorders with AeroSpace
after-startup-command = [
    'exec-and-forget sketchybar',
    'exec-and-forget borders active_color=0xffe1e3e4 inactive_color=0xff494d64 width=5.0'
]

# Notify SketchyBar on workspace change
exec-on-workspace-change = ['/bin/bash', '-c',
    'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE'
]

# Enable normalizations
enable-normalization-flatten-containers = true
enable-normalization-opposite-orientation-for-nested-containers = true

accordion-padding = 30
default-root-container-layout = 'tiles'
default-root-container-orientation = 'auto'
key-mapping.preset = 'qwerty'
on-focused-monitor-changed = ['move-mouse monitor-lazy-center']

# Gap configuration - adjust outer.top for SketchyBar
[gaps]
inner.horizontal = 10
inner.vertical = 10
outer.left = 10
outer.bottom = 10
outer.top = 40    # Leave room for SketchyBar
outer.right = 10

# Keybindings
[mode.main.binding]
alt-slash = 'layout tiles horizontal vertical'
alt-comma = 'layout accordion horizontal vertical'
alt-h = 'focus left'
alt-j = 'focus down'
alt-k = 'focus up'
alt-l = 'focus right'
alt-shift-h = 'move left'
alt-shift-j = 'move down'
alt-shift-k = 'move up'
alt-shift-l = 'move right'
alt-minus = 'resize smart -50'
alt-equal = 'resize smart +50'
alt-f = 'fullscreen'
alt-1 = 'workspace 1'
alt-2 = 'workspace 2'
alt-3 = 'workspace 3'
alt-4 = 'workspace 4'
alt-5 = 'workspace 5'
alt-6 = 'workspace 6'
alt-7 = 'workspace 7'
alt-8 = 'workspace 8'
alt-9 = 'workspace 9'
alt-shift-1 = 'move-node-to-workspace 1'
alt-shift-2 = 'move-node-to-workspace 2'
alt-shift-3 = 'move-node-to-workspace 3'
alt-shift-4 = 'move-node-to-workspace 4'
alt-shift-5 = 'move-node-to-workspace 5'
alt-shift-6 = 'move-node-to-workspace 6'
alt-shift-7 = 'move-node-to-workspace 7'
alt-shift-8 = 'move-node-to-workspace 8'
alt-shift-9 = 'move-node-to-workspace 9'
alt-tab = 'workspace-back-and-forth'
alt-shift-tab = 'move-workspace-to-monitor --wrap-around next'
alt-shift-semicolon = 'mode service'

[mode.service.binding]
esc = ['reload-config', 'mode main']
r = ['flatten-workspace-tree', 'mode main']
f = ['layout floating tiling', 'mode main']
backspace = ['close-all-windows-but-current', 'mode main']
EOF
```

### Restart All Services

```bash
# Kill all services
pkill AeroSpace
pkill sketchybar
pkill borders

# Start AeroSpace (will start others via after-startup-command)
open -a AeroSpace
```

### Verification

```bash
# Check all processes are running
pgrep -x AeroSpace && echo "AeroSpace: OK" || echo "AeroSpace: NOT RUNNING"
pgrep -x sketchybar && echo "SketchyBar: OK" || echo "SketchyBar: NOT RUNNING"
pgrep borders && echo "JankyBorders: OK" || echo "JankyBorders: NOT RUNNING"
```

---

## 10. Workspace Configuration

### Change Number of Workspaces

#### Reduce to fewer workspaces (e.g., 1-6)

In `~/.aerospace.toml`, modify the keybindings section:

```toml
[mode.main.binding]
# Only define workspaces 1-6
alt-1 = 'workspace 1'
alt-2 = 'workspace 2'
alt-3 = 'workspace 3'
alt-4 = 'workspace 4'
alt-5 = 'workspace 5'
alt-6 = 'workspace 6'
# Remove or comment out alt-7, alt-8, alt-9

alt-shift-1 = 'move-node-to-workspace 1'
alt-shift-2 = 'move-node-to-workspace 2'
alt-shift-3 = 'move-node-to-workspace 3'
alt-shift-4 = 'move-node-to-workspace 4'
alt-shift-5 = 'move-node-to-workspace 5'
alt-shift-6 = 'move-node-to-workspace 6'
```

Then update SketchyBar to only show those workspaces by modifying the loop in `~/.config/sketchybar/sketchybarrc`:

```bash
# Replace the workspace loop with explicit list
for sid in 1 2 3 4 5 6; do
    sketchybar --add item space.$sid left \
        # ... rest of configuration
done
```

---

## 11. Gap Configuration

### Modify Gap Sizes

In `~/.aerospace.toml`:

```toml
[gaps]
inner.horizontal = 8    # Space between windows horizontally
inner.vertical = 8      # Space between windows vertically
outer.left = 8          # Space from left screen edge
outer.bottom = 8        # Space from bottom screen edge
outer.top = 40          # Space from top (adjust for SketchyBar height)
outer.right = 8         # Space from right screen edge
```

### Remove All Gaps

```toml
[gaps]
inner.horizontal = 0
inner.vertical = 0
outer.left = 0
outer.bottom = 0
outer.top = 32    # Keep minimal space for SketchyBar
outer.right = 0
```

---

## 12. Custom Keybindings

### Change Focus Keys to Arrow Keys

```toml
[mode.main.binding]
# Arrow key navigation
alt-left = 'focus left'
alt-down = 'focus down'
alt-up = 'focus up'
alt-right = 'focus right'

alt-shift-left = 'move left'
alt-shift-down = 'move down'
alt-shift-up = 'move up'
alt-shift-right = 'move right'
```

### Add Application Launch Shortcuts

```toml
[mode.main.binding]
# Application launchers
alt-return = 'exec-and-forget open -a Terminal'
alt-b = 'exec-and-forget open -a "Brave Browser"'
alt-shift-b = 'exec-and-forget open -a Safari'
alt-e = 'exec-and-forget open -a Finder'
```

### Using Hyper Key (cmd+ctrl+alt+shift)

If user has Hyper key configured (e.g., via Karabiner-Elements):

```toml
[mode.main.binding]
cmd-ctrl-alt-shift-h = 'focus left'
cmd-ctrl-alt-shift-j = 'focus down'
cmd-ctrl-alt-shift-k = 'focus up'
cmd-ctrl-alt-shift-l = 'focus right'
```

---

## 13. Monitor Configuration

### Assign Workspace to Specific Monitor

```toml
# Add to ~/.aerospace.toml before [mode.main.binding]

[workspace-to-monitor-force-assignment]
9 = 'secondary'        # Workspace 9 always on secondary monitor
8 = 'secondary'        # Workspace 8 always on secondary monitor
# Main monitor workspaces: 1-7
```

### Monitor Identification

```bash
# List connected monitors
aerospace list-monitors

# Output will show monitor names like:
# 1 | main
# 2 | secondary
```

---

## 14. Floating Window Rules

### Force Apps to Always Float

```toml
# Add to ~/.aerospace.toml

[[on-window-detected]]
if.app-id = 'com.apple.systempreferences'
run = 'layout floating'

[[on-window-detected]]
if.app-id = 'com.apple.finder'
if.window-title-regex-substring = 'Copy|Move|Connecting'
run = 'layout floating'

[[on-window-detected]]
if.app-id = 'com.apple.calculator'
run = 'layout floating'
```

### Force Apps to Always Tile

```toml
[[on-window-detected]]
if.app-id = 'com.spotify.client'
run = 'layout tiling'
```

### Common App Bundle IDs

| Application | Bundle ID |
|-------------|-----------|
| System Settings | `com.apple.systempreferences` |
| Finder | `com.apple.finder` |
| Calculator | `com.apple.calculator` |
| Preview | `com.apple.Preview` |
| Safari | `com.apple.Safari` |
| Terminal | `com.apple.Terminal` |
| Music | `com.apple.Music` |
| Messages | `com.apple.MobileSMS` |

---

## 15. Troubleshooting

### AeroSpace Not Starting

```bash
# Check for errors
aerospace --version

# Check accessibility permissions
# System Settings → Privacy & Security → Accessibility → AeroSpace should be enabled

# Try running from terminal for error output
/Applications/AeroSpace.app/Contents/MacOS/AeroSpace
```

### SketchyBar Not Showing

```bash
# Check if "Displays have separate Spaces" is enabled
defaults read com.apple.spaces spans-displays
# Should return error (meaning it's enabled - the default)

# Run manually to see errors
sketchybar

# Check for syntax errors in config
cat ~/.config/sketchybar/sketchybarrc
```

### JankyBorders Not Working

```bash
# Verify macOS version (needs 14.0+)
sw_vers -productVersion

# Check if running
pgrep borders

# Run with verbose output
borders active_color=0xffff0000 width=10.0
# Should see red borders on focused window
```

### Workspaces Not Showing in SketchyBar

```bash
# Verify AeroSpace is running
pgrep AeroSpace

# Check if aerospace.sh plugin exists and is executable
ls -la ~/.config/sketchybar/plugins/aerospace.sh

# Test the workspace change trigger manually
sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=1
```

### Config Changes Not Taking Effect

```bash
# Reload AeroSpace config
aerospace reload-config

# Restart SketchyBar
brew services restart sketchybar
# Or: pkill sketchybar && sketchybar &

# Update JankyBorders (running a new borders command updates existing instance)
borders active_color=0xffe1e3e4 inactive_color=0xff494d64 width=5.0
```

---

## 16. Common User Requests

### "Make the border thicker/thinner"

Modify the `width` parameter:

```bash
# In AeroSpace config or run directly:
borders width=8.0  # Thicker
borders width=3.0  # Thinner
```

### "Change the border color to blue"

```bash
borders active_color=0xff0066ff inactive_color=0xff333333
```

### "Remove the gaps between windows"

In `~/.aerospace.toml`:

```toml
[gaps]
inner.horizontal = 0
inner.vertical = 0
```

### "Switch from tiles to accordion by default"

In `~/.aerospace.toml`:

```toml
default-root-container-layout = 'accordion'
```

### "Start AeroSpace automatically at login"

In `~/.aerospace.toml`:

```toml
start-at-login = true
```

### "Hide the macOS menu bar"

System Settings → Control Center → Automatically hide and show the menu bar → **Always**

Or via command:

```bash
defaults write NSGlobalDomain _HIHideMenuBar -bool true
killall SystemUIServer
```

### "Disable window tiling for specific app"

Add to `~/.aerospace.toml`:

```toml
[[on-window-detected]]
if.app-id = 'com.example.appname'
run = 'layout floating'
```

### "Use different workspaces on different monitors"

Add to `~/.aerospace.toml`:

```toml
[workspace-to-monitor-force-assignment]
1 = 'main'
2 = 'main'
3 = 'main'
7 = 'secondary'
8 = 'secondary'
9 = 'secondary'
```

---

## Quick Command Reference for AI Assistants

### Service Management

```bash
# Start all
open -a AeroSpace

# Stop all
pkill AeroSpace && pkill sketchybar && pkill borders

# Restart AeroSpace only
pkill AeroSpace && open -a AeroSpace

# Restart SketchyBar only
pkill sketchybar && sketchybar &

# Update JankyBorders
borders active_color=0xffe1e3e4 inactive_color=0xff494d64 width=5.0

# Reload AeroSpace config
aerospace reload-config
```

### Status Check

```bash
pgrep -x AeroSpace && echo "✓ AeroSpace" || echo "✗ AeroSpace"
pgrep -x sketchybar && echo "✓ SketchyBar" || echo "✗ SketchyBar"
pgrep borders && echo "✓ JankyBorders" || echo "✗ JankyBorders"
```

### Config Locations

```
~/.aerospace.toml                        # AeroSpace main config
~/.config/sketchybar/sketchybarrc        # SketchyBar main config
~/.config/sketchybar/plugins/            # SketchyBar plugins
~/.config/borders/bordersrc              # JankyBorders config (optional)
```

---

*Tutorial version 1.0 - Verified against official documentation January 2026*