# Files Guide for Agents

## Rules

- All window manager related configs (AeroSpace, SketchyBar, JankyBorders, etc.) MUST live in `./configs/<app-name>/` as the source of truth.
- Symlinks from the expected system location (e.g. `~/.config/<app>`, `~/.aerospace.toml`) MUST point to the corresponding file/folder in `./configs/`.
- Never edit configs directly in `~/.config/` or system paths — always edit the source in `./configs/` and ensure symlinks are in place.
- When adding a new WM-related tool, create its folder in `./configs/`, place configs there, then symlink.

### Current symlink map

| Source (configs/) | Symlink target |
|---|---|
| `./configs/aerospace/aerospace.toml` | `~/.aerospace.toml` |
| `./configs/borders/` | `~/.config/borders` |
| `./configs/sketchybar/` | `~/.config/sketchybar` |

## File List

- ./configs/aerospace/aerospace.toml
- ./configs/aerospace/apply-display-profile.sh
- ./configs/aerospace/com.aerospace.display-profile.plist
- ./configs/aerospace/doc.aerospace.md
- ./configs/aerospace/features.aerospace.md
- ./configs/aerospace/open-dock-app.sh
- ./configs/aerospace/performance-mode.sh
- ./configs/aerospace/secondary-bar-toggle.sh
- ./configs/borders/bordersrc
- ./configs/sketchybar/sketchybarrc
- ./configs/sketchybar/colors.sh
- ./configs/sketchybar/icons.sh
- ./configs/sketchybar/items/*.sh (18 files)
- ./configs/sketchybar/plugins/*.sh (25 files)
- ./configs/vscode/settings.json

## Descriptions

`./configs/aerospace/aerospace.toml`
- Main AeroSpace tiling window manager config
- Defines keybindings (alt+hjkl=focus, alt+shift+hjkl=move, alt+1-9=workspace)
- Configures gaps, monitors assignment, startup commands
- Launches sketchybar+borders on startup
- App launchers via cmd+1-9 use open-dock-app.sh to open Dock apps by position
- alt+shift+; then p triggers aerospace/performance-mode.sh (toggles UI overhead reduction)
- alt+shift+; then b triggers aerospace/secondary-bar-toggle.sh (hides/shows SketchyBar on secondary monitor)
- CrossOver auto-floated via on-window-detected rule (prevents tiling conflicts with games)
- Edit for: keybindings, workspace layout, monitor assignment, gaps

`./configs/aerospace/apply-display-profile.sh`
- Auto-adjusts AeroSpace outer.top gap based on connected monitor resolutions
- Uses lookup table for common resolutions (4K, 1440p, 1080p, MacBook Retina)
- Detects display changes via fingerprint, updates aerospace.toml, reloads config
- Reads /tmp/secondary-bar.state — when "off", prepends `{ monitor.secondary = 10 }` so the bar-hidden state survives monitor changes
- Edit for: gap values per resolution, adding new resolution mappings

`./configs/aerospace/com.aerospace.display-profile.plist`
- LaunchAgent that runs apply-display-profile.sh every 5 seconds
- Detects monitor connect/disconnect and auto-applies optimal gaps
- Install to ~/Library/LaunchAgents/ and launchctl load to activate
- Edit for: check interval timing

`./configs/aerospace/doc.aerospace.md`
- AeroSpace + SketchyBar + JankyBorders installation and setup tutorial
- Step-by-step instructions for AI assistants to configure the full stack
- Read-only reference, don't edit

`./configs/aerospace/features.aerospace.md`
- AeroSpace features documentation with keybinding reference
- Covers tiling, workspaces, layouts, integration features
- Read-only reference, don't edit

`./configs/aerospace/open-dock-app.sh`
- Opens macOS Dock apps by position index (0-indexed)
- Called by aerospace.toml cmd+1-9 keybindings
- Reads persistent-apps from Dock plist, decodes URL, opens app
- Edit for: changing how app path is resolved

`./configs/aerospace/performance-mode.sh`
- Toggles performance mode on/off (alt+shift+; then p via aerospace.toml service mode)
- ON: kills JankyBorders, unloads display-profile LaunchAgent, hides sketchybar polling items (cpu, ram, network, battery, volume, headset, vpn, wifi, ethernet) and their brackets
- OFF: restores everything, restarts borders, reloads LaunchAgent, re-enables all items
- Keeps workspace spaces (left) and time/date (right) always visible
- State tracked via /tmp/performance-mode.state
- Edit for: which items to hide/show, notification messages

`./configs/aerospace/secondary-bar-toggle.sh`
- Toggles SketchyBar visibility on the secondary monitor (alt+shift+; then b via aerospace.toml service mode)
- ON: `sketchybar --bar display=all` + removes `{ monitor.secondary = 10 }` override from outer.top
- OFF: `sketchybar --bar display=main` + prepends `{ monitor.secondary = 10 }` override to outer.top so windows reclaim the freed bar space
- Edits aerospace.toml via awk + tempfile + cp (writes through the symlink at ~/.aerospace.toml)
- Then runs `aerospace reload-config` to apply the new gaps
- Orthogonal to performance mode: only flips the bar's display target and the secondary outer.top, leaves per-item drawing state alone
- State tracked via /tmp/secondary-bar.state
- apply-display-profile.sh also reads this state file, so monitor-change events keep the override applied while the bar is hidden
- Edit for: gap value (default 10 = matches outer.left/right/bottom), changing target monitor

`./configs/borders/bordersrc`
- JankyBorders config (window border styling)
- Tokyo Night theme: active=0xffc0caf5, inactive=0xff414868
- Options: style=round, width=4.0, hidpi=on
- Edit for: border colors, width, style

`./configs/sketchybar/sketchybarrc`
- Main sketchybar entry point (status bar)
- Sources colors.sh, icons.sh, then items: spaces, calendar, volume, headset, ram, cpu, battery, vpn, wifi, ethernet, network_down, network_up
- Commented out (disabled): apple.sh, settings.sh
- Not sourced (disabled): front_app.sh, brew.sh, github.sh, spotify.sh
- Defines bar: height=58, floating style, transparent bg
- Defines defaults: pill style, corner_radius=10, font=JetBrainsMono
- Groups items into brackets: calendar_group, audio, traffic, resources, connectivity
- Edit for: bar position, default item styling, enable/disable items

`./configs/sketchybar/colors.sh`
- Color palette exports (CriticalElement Dotfiles theme)
- Key: PINK=0xffcf6679, DARK_BG=0xEB1e1e2e, TRANSPARENT=0x00000000
- Edit for: global color scheme changes

`./configs/sketchybar/icons.sh`
- Nerd Font icon exports
- Categories: general, git, spotify, aerospace, battery, volume, calendar, wifi, ethernet, vpn, ram, headset, settings, network speed
- Edit for: adding/changing icons

`./configs/sketchybar/items/*.sh`
- Item definitions (visual config, positioning, subscriptions)
- Pattern: define item properties, add to bar, subscribe events
- Active items: spaces.sh, calendar.sh, volume.sh, headset.sh, ram.sh, cpu.sh, battery.sh, vpn.sh, wifi.sh, ethernet.sh, network_down.sh, network_up.sh
- Disabled items: apple.sh (commented), settings.sh (commented), front_app.sh (not sourced), brew.sh, github.sh, spotify.sh
- Key file: spaces.sh (workspaces with aerospace integration)
- Edit for: item appearance, positioning, which events trigger updates

`./configs/sketchybar/plugins/*.sh`
- Event handlers and data fetchers (25 files)
- Pattern: receive events, query system, update sketchybar items
- Key files: aerospace.sh (workspace state with app name display), battery.sh, cpu.sh, wifi.sh
- aerospace.sh: simplified workspace display, shows app names next to workspace number, uses shorten_app_name() for common apps, multi-monitor support with distinct colors per monitor
- Edit for: logic of what's displayed, data sources, formatting

`./configs/vscode/settings.json`
- VSCode editor settings
- Font sizes, formatters, Claude Code config, icon themes
- Minimal UI: statusBar=hidden, activityBar=hidden, minimap=off
- Edit for: editor preferences, extension configs
