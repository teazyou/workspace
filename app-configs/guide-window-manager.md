# Files Guide for Agents

## Rules

- All window manager related configs (AeroSpace, SketchyBar, JankyBorders, aerospace-swipe, etc.) MUST live in `./app-configs/<app-name>/` as the source of truth.
- Symlinks from the expected system location (e.g. `~/.config/<app>`, `~/.aerospace.toml`) MUST point to the corresponding file/folder in `./app-configs/`.
- Never edit configs directly in `~/.config/` or system paths — always edit the source in `./app-configs/` and ensure symlinks are in place.
- When adding a new WM-related tool, create its folder in `./app-configs/`, place configs there, then symlink.

### Current symlink map

| Source (app-configs/) | Symlink target |
|---|---|
| `./app-configs/aerospace/aerospace.toml` | `~/.aerospace.toml` |
| `./app-configs/borders/` | `~/.config/borders` |
| `./app-configs/sketchybar/` | `~/.config/sketchybar` |
| `./app-configs/aerospace-swipe/` | `~/.config/aerospace-swipe` |

## File List

- ./app-configs/aerospace/aerospace.toml
- ./app-configs/aerospace/apply-display-profile.sh
- ./app-configs/aerospace/com.aerospace.display-profile.plist
- ./app-configs/aerospace/doc.aerospace.md
- ./app-configs/aerospace/features.aerospace.md
- ./app-configs/aerospace/open-dock-app.sh
- ./app-configs/aerospace/performance-mode.sh
- ./app-configs/borders/bordersrc
- ./app-configs/sketchybar/sketchybarrc
- ./app-configs/sketchybar/colors.sh
- ./app-configs/sketchybar/icons.sh
- ./app-configs/sketchybar/items/*.sh (18 files)
- ./app-configs/sketchybar/plugins/*.sh (25 files)
- ./app-configs/aerospace-swipe/config.json
- ./app-configs/vscode/settings.json

## Descriptions

`./app-configs/aerospace/aerospace.toml`
- Main AeroSpace tiling window manager config
- Defines keybindings (alt+hjkl=focus, alt+shift+hjkl=move, alt+1-9=workspace)
- Configures gaps, monitors assignment, startup commands
- Launches sketchybar+borders on startup
- App launchers via cmd+1-9 use open-dock-app.sh to open Dock apps by position
- alt+shift+p triggers aerospace/performance-mode.sh (toggles UI overhead reduction)
- CrossOver auto-floated via on-window-detected rule (prevents tiling conflicts with games)
- Edit for: keybindings, workspace layout, monitor assignment, gaps

`./app-configs/aerospace/apply-display-profile.sh`
- Auto-adjusts AeroSpace outer.top gap based on connected monitor resolutions
- Uses lookup table for common resolutions (4K, 1440p, 1080p, MacBook Retina)
- Detects display changes via fingerprint, updates aerospace.toml, reloads config
- Edit for: gap values per resolution, adding new resolution mappings

`./app-configs/aerospace/com.aerospace.display-profile.plist`
- LaunchAgent that runs apply-display-profile.sh every 5 seconds
- Detects monitor connect/disconnect and auto-applies optimal gaps
- Install to ~/Library/LaunchAgents/ and launchctl load to activate
- Edit for: check interval timing

`./app-configs/aerospace/doc.aerospace.md`
- AeroSpace + SketchyBar + JankyBorders installation and setup tutorial
- Step-by-step instructions for AI assistants to configure the full stack
- Read-only reference, don't edit

`./app-configs/aerospace/features.aerospace.md`
- AeroSpace features documentation with keybinding reference
- Covers tiling, workspaces, layouts, integration features
- Read-only reference, don't edit

`./app-configs/aerospace/open-dock-app.sh`
- Opens macOS Dock apps by position index (0-indexed)
- Called by aerospace.toml cmd+1-9 keybindings
- Reads persistent-apps from Dock plist, decodes URL, opens app
- Edit for: changing how app path is resolved

`./app-configs/aerospace/performance-mode.sh`
- Toggles performance mode on/off (alt+shift+p via aerospace.toml)
- ON: kills JankyBorders, unloads display-profile LaunchAgent, hides sketchybar polling items (cpu, ram, network, battery, volume, headset, vpn, wifi, ethernet) and their brackets
- OFF: restores everything, restarts borders, reloads LaunchAgent, re-enables all items
- Keeps workspace spaces (left) and time/date (right) always visible
- State tracked via /tmp/performance-mode.state
- Edit for: which items to hide/show, notification messages

`./app-configs/borders/bordersrc`
- JankyBorders config (window border styling)
- Tokyo Night theme: active=0xffc0caf5, inactive=0xff414868
- Options: style=round, width=4.0, hidpi=on
- Edit for: border colors, width, style

`./app-configs/sketchybar/sketchybarrc`
- Main sketchybar entry point (status bar)
- Sources colors.sh, icons.sh, then items: spaces, calendar, volume, headset, ram, cpu, battery, vpn, wifi, ethernet, network_down, network_up
- Commented out (disabled): apple.sh, settings.sh
- Not sourced (disabled): front_app.sh, brew.sh, github.sh, spotify.sh
- Defines bar: height=58, floating style, transparent bg
- Defines defaults: pill style, corner_radius=10, font=JetBrainsMono
- Groups items into brackets: calendar_group, audio, traffic, resources, connectivity
- Edit for: bar position, default item styling, enable/disable items

`./app-configs/sketchybar/colors.sh`
- Color palette exports (CriticalElement Dotfiles theme)
- Key: PINK=0xffcf6679, DARK_BG=0xEB1e1e2e, TRANSPARENT=0x00000000
- Edit for: global color scheme changes

`./app-configs/sketchybar/icons.sh`
- Nerd Font icon exports
- Categories: general, git, spotify, aerospace, battery, volume, calendar, wifi, ethernet, vpn, ram, headset, settings, network speed
- Edit for: adding/changing icons

`./app-configs/sketchybar/items/*.sh`
- Item definitions (visual config, positioning, subscriptions)
- Pattern: define item properties, add to bar, subscribe events
- Active items: spaces.sh, calendar.sh, volume.sh, headset.sh, ram.sh, cpu.sh, battery.sh, vpn.sh, wifi.sh, ethernet.sh, network_down.sh, network_up.sh
- Disabled items: apple.sh (commented), settings.sh (commented), front_app.sh (not sourced), brew.sh, github.sh, spotify.sh
- Key file: spaces.sh (workspaces with aerospace integration)
- Edit for: item appearance, positioning, which events trigger updates

`./app-configs/sketchybar/plugins/*.sh`
- Event handlers and data fetchers (25 files)
- Pattern: receive events, query system, update sketchybar items
- Key files: aerospace.sh (workspace state with app name display), battery.sh, cpu.sh, wifi.sh
- aerospace.sh: simplified workspace display, shows app names next to workspace number, uses shorten_app_name() for common apps, multi-monitor support with distinct colors per monitor
- Edit for: logic of what's displayed, data sources, formatting

`./app-configs/aerospace-swipe/config.json`
- Config for aerospace-swipe (trackpad gesture workspace switching)
- Enables 3-finger swipe left/right to navigate AeroSpace workspaces
- Options: fingers, natural_swipe, wrap_around, skip_empty, haptic
- Symlinked from ~/.config/aerospace-swipe/
- Edit for: gesture sensitivity, swipe direction, wrap behavior

`./app-configs/vscode/settings.json`
- VSCode editor settings
- Font sizes, formatters, Claude Code config, icon themes
- Minimal UI: statusBar=hidden, activityBar=hidden, minimap=off
- Edit for: editor preferences, extension configs
