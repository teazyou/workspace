# macOS Keyboard-Driven Window Management - Feature Documentation

This document covers all features demonstrated in the AeroSpace, SketchyBar, and JankyBorders setup video tutorial.

---

## Table of Contents

1. [Overview](#overview)
2. [Core Components](#core-components)
3. [AeroSpace Features](#aerospace-features)
4. [SketchyBar Features](#sketchybar-features)
5. [JankyBorders Features](#jankyborders-features)
6. [Integration Features](#integration-features)
7. [Dependencies Summary](#dependencies-summary)

---

## Overview

This setup creates a keyboard-driven window management workflow for macOS, similar to i3 on Linux. The system allows users to:

- Automatically tile windows without manual resizing
- Navigate between windows using keyboard shortcuts
- Organize windows into virtual workspaces
- Visualize workspace status in a custom menu bar
- Highlight the focused window with colored borders

---

## Core Components

| Component | Purpose | Dependencies |
|-----------|---------|--------------|
| **AeroSpace** | Tiling window manager | Homebrew |
| **SketchyBar** | Custom status bar replacement | Homebrew, Shell scripts |
| **JankyBorders** | Window border highlighting | Homebrew, macOS 14.0+ |

---

## AeroSpace Features

### 1. Automatic Window Tiling

**Description:** Windows automatically arrange themselves in a grid layout when opened.

**Depends on:**
- AeroSpace application
- Configuration file: `~/.aerospace.toml` or `./configs/aerospace/aerospace.toml`

**Behavior:**
- New windows split the available space with existing windows
- Windows are resized automatically to fill the screen
- Supports horizontal and vertical tiling orientations

---

### 2. Layout Modes

#### Tiles Layout (Default)
**Description:** Windows are arranged side-by-side in horizontal or vertical tiles.

**Depends on:**
- AeroSpace configuration setting: `default-root-container-layout = 'tiles'`

**Shortcuts (Default):**
- `alt + /` - Toggle between horizontal and vertical tiles

#### Accordion Layout
**Description:** One window is displayed in front with others partially visible on sides.

**Depends on:**
- AeroSpace accordion feature
- Configuration setting: `accordion-padding`

**Shortcuts (Default):**
- `alt + ,` - Switch to accordion layout

---

### 3. Window Focus Navigation

**Description:** Move focus between windows using keyboard shortcuts.

**Depends on:**
- AeroSpace keybindings in `[mode.main.binding]` section

**Shortcuts (Default):**
- `alt + h` - Focus window to the left
- `alt + j` - Focus window below
- `alt + k` - Focus window above
- `alt + l` - Focus window to the right

---

### 4. Window Movement

**Description:** Move windows within the current layout.

**Depends on:**
- AeroSpace keybindings

**Shortcuts (Default):**
- `alt + shift + h` - Move window left
- `alt + shift + j` - Move window down
- `alt + shift + k` - Move window up
- `alt + shift + l` - Move window right

---

### 5. Window Resizing

**Description:** Resize windows within the tiled layout.

**Depends on:**
- AeroSpace resize mode
- Configuration: `[mode.resize.binding]` section

**Shortcuts (Default):**
- `alt + minus` - Decrease size
- `alt + equal` - Increase size

---

### 6. Tree-Based Window Management

**Description:** Windows are organized in a tree structure allowing nested layouts.

**Depends on:**
- AeroSpace core architecture
- Normalization settings:
  - `enable-normalization-flatten-containers`
  - `enable-normalization-opposite-orientation-for-nested-containers`

**Features:**
- Join windows into nodes
- Create nested horizontal/vertical layouts
- Flatten layout structure with shortcuts

---

### 7. Workspaces (Virtual Desktops)

**Description:** Emulated virtual desktops independent of macOS Spaces.

**Depends on:**
- AeroSpace workspace emulation (not macOS native Spaces)
- Workspace keybindings

**Shortcuts (Default):**
- `alt + 1` through `alt + 9` - Switch to workspace 1-9
- `alt + shift + 1` through `alt + shift + 9` - Move window to workspace 1-9

**Configuration Options:**
- Assign workspaces to specific monitors
- Define persistent workspaces

---

### 8. Monitor-Specific Workspace Assignment

**Description:** Lock specific workspaces to specific monitors.

**Depends on:**
- AeroSpace configuration
- Multiple connected monitors

**Configuration Example:**
```toml
[workspace-to-monitor-force-assignment]
9 = 'secondary'
```

---

### 9. Floating Windows

**Description:** Pull windows out of automatic tiling for manual positioning.

**Depends on:**
- AeroSpace floating mode
- Service mode keybindings

**Shortcuts (Default):**
- `alt + shift + ;` then `f` - Toggle floating mode

**Notes:**
- Some apps (like System Settings) are excluded from tiling by default
- Windows can be returned to tiling mode

---

### 10. Application Launch Shortcuts

**Description:** Define keyboard shortcuts to launch or switch to specific applications.

**Depends on:**
- AeroSpace `exec-and-forget` command
- Custom keybindings

**Configuration Example:**
```toml
alt-b = 'exec-and-forget open -a Brave'
```

---

### 11. Fullscreen Modes

**Description:** Maximize windows in different ways.

**Depends on:**
- AeroSpace fullscreen command

**Types:**
- **Full maximize:** Window covers entire screen including menu bar
- **Gap-respecting maximize:** Window fills available space while respecting gaps

**Shortcuts (Default):**
- `alt + f` - Toggle fullscreen

---

### 12. Gap Configuration

**Description:** Configurable spacing between windows and screen edges.

**Depends on:**
- AeroSpace configuration file

**Configuration Options:**
```toml
[gaps]
inner.horizontal = 10  # Between windows horizontally
inner.vertical = 10    # Between windows vertically
outer.left = 10        # Left screen edge
outer.bottom = 10      # Bottom screen edge
outer.top = 10         # Top screen edge (adjust for SketchyBar)
outer.right = 10       # Right screen edge
```

---

### 13. Service Mode

**Description:** Secondary keybinding mode for less-frequent operations.

**Depends on:**
- AeroSpace mode system
- Configuration: `[mode.service.binding]` section

**Activation (Default):**
- `alt + shift + ;` - Enter service mode
- `esc` - Return to main mode

**Service Mode Commands:**
- `r` - Reload configuration
- `f` - Toggle floating
- `backspace` - Close all windows except focused

---

### 14. Start at Login

**Description:** Automatically start AeroSpace when logging into macOS.

**Depends on:**
- AeroSpace configuration setting

**Configuration:**
```toml
start-at-login = true
```

---

### 15. After-Startup Commands

**Description:** Execute commands when AeroSpace starts.

**Depends on:**
- AeroSpace configuration
- External applications to launch

**Configuration Example:**
```toml
after-startup-command = [
    'exec-and-forget sketchybar',
    'exec-and-forget borders active_color=0xffe1e3e4 inactive_color=0xff494d64 width=5.0'
]
```

---

## SketchyBar Features

### 1. Custom Menu Bar

**Description:** Replacement for the macOS default menu bar.

**Depends on:**
- SketchyBar application
- Configuration: `./configs/sketchybar/sketchybarrc`
- Plugin scripts: `./configs/sketchybar/plugins/`

---

### 2. AeroSpace Workspace Indicators

**Description:** Display current AeroSpace workspaces in SketchyBar.

**Depends on:**
- SketchyBar
- AeroSpace
- Custom event integration
- Plugin script: `./configs/sketchybar/plugins/aerospace.sh`

**Required AeroSpace Configuration:**
```toml
exec-on-workspace-change = ['/bin/bash', '-c',
    'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE'
]
```

---

### 3. Monitor-Specific Workspace Display

**Description:** Show workspace indicators separately for different monitors.

**Depends on:**
- SketchyBar configuration
- Multi-monitor setup

---

### 4. Clickable Workspace Switching

**Description:** Click on workspace indicators to switch workspaces.

**Depends on:**
- SketchyBar click_script configuration
- AeroSpace CLI

**Configuration:**
```bash
click_script="aerospace workspace $sid"
```

---

## JankyBorders Features

### 1. Active Window Border

**Description:** Colored border around the currently focused window.

**Depends on:**
- JankyBorders application (macOS 14.0+ required)
- Configuration via command line or config file

**Configuration Options:**
- `active_color` - Color for focused window (hex format: `0xAARRGGBB`)
- `inactive_color` - Color for unfocused windows
- `width` - Border width in pixels
- `style` - Border style (`round` or `square`)

---

### 2. Border Styling

**Description:** Customize border appearance.

**Depends on:**
- JankyBorders configuration

**Options:**
- `style=round` - Rounded corners
- `style=square` - Square corners
- `hidpi=on/off` - HiDPI display support
- `order=above` - Render border above window shadows

---

### 3. Configuration File Support

**Description:** Persistent border configuration via file.

**Depends on:**
- Configuration file: `./configs/borders/bordersrc`

**Example:**
```bash
#!/bin/bash
options=(
    style=round
    width=6.0
    hidpi=off
    active_color=0xffe2e2e3
    inactive_color=0xff414550
)
borders "${options[@]}"
```

---

## Integration Features

### 1. Unified Startup

**Description:** Start all three tools together when AeroSpace launches.

**Depends on:**
- AeroSpace `after-startup-command`
- SketchyBar
- JankyBorders

**Configuration:**
```toml
after-startup-command = [
    'exec-and-forget sketchybar',
    'exec-and-forget borders active_color=0xffe1e3e4 inactive_color=0xff494d64 width=5.0'
]
```

---

### 2. Workspace Change Notifications

**Description:** Notify SketchyBar when AeroSpace workspace changes.

**Depends on:**
- AeroSpace `exec-on-workspace-change` callback
- SketchyBar custom events

---

### 3. Gap Coordination with SketchyBar

**Description:** Configure outer top gap to accommodate SketchyBar height.

**Depends on:**
- AeroSpace gap configuration
- SketchyBar height configuration

**Typical Configuration:**
```toml
[gaps]
outer.top = 48  # Adjust based on SketchyBar height
```

---

## Dependencies Summary

### Required Software

| Software | Installation Method | Purpose |
|----------|-------------------|---------|
| Homebrew | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` | Package manager |
| AeroSpace | `brew install --cask nikitabobko/tap/aerospace` | Window manager |
| SketchyBar | `brew tap FelixKratz/formulae && brew install sketchybar` | Status bar |
| JankyBorders | `brew tap FelixKratz/formulae && brew install borders` | Window borders |

### Configuration Files

| File | Purpose |
|------|---------|
| `~/.aerospace.toml` | AeroSpace main configuration |
| `./configs/sketchybar/sketchybarrc` | SketchyBar main configuration |
| `./configs/sketchybar/plugins/` | SketchyBar plugin scripts |
| `./configs/borders/bordersrc` | JankyBorders configuration |

### System Requirements

- **macOS Version:** 14.0+ (Sonoma) for JankyBorders
- **macOS Setting:** "Displays have separate Spaces" enabled (System Settings → Desktop & Dock)

### Optional Enhancements

| Enhancement | Depends On |
|-------------|------------|
| Hyper key (all modifiers) | Custom keyboard firmware or Karabiner-Elements |
| Nerd Fonts for icons | Font installation |
| Raycast integration | Raycast app + AeroSpace extension |

---

## Quick Reference - Default Keybindings

### Main Mode (alt + ...)

| Shortcut | Action |
|----------|--------|
| `alt + h/j/k/l` | Focus window left/down/up/right |
| `alt + shift + h/j/k/l` | Move window left/down/up/right |
| `alt + 1-9` | Switch to workspace 1-9 |
| `alt + shift + 1-9` | Move window to workspace 1-9 |
| `alt + /` | Toggle tiles horizontal/vertical |
| `alt + ,` | Switch to accordion layout |
| `alt + -` | Decrease window size |
| `alt + =` | Increase window size |
| `alt + f` | Toggle fullscreen |
| `alt + shift + ;` | Enter service mode |

### Service Mode

| Shortcut | Action |
|----------|--------|
| `r` or `esc` | Reload config and return to main mode |
| `f` | Toggle floating mode |
| `backspace` | Close all windows except focused |

---

*Document generated from video tutorial analysis. Verified against official documentation as of January 2026.*