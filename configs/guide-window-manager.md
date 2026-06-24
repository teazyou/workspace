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
| `./configs/autoraise/config` | `~/.config/AutoRaise/config` |
| `./configs/autoraise/com.autoraise.daemon.plist` | `~/Library/LaunchAgents/com.autoraise.daemon.plist` |

## File List

- ./configs/aerospace/aerospace.toml
- ./configs/aerospace/apply-display-profile.sh
- ./configs/aerospace/com.aerospace.display-profile.plist
- ./configs/aerospace/com.aerospace.empty-watcher.plist
- ./configs/aerospace/doc.aerospace.md
- ./configs/aerospace/empty-workspace-watcher.sh
- ./configs/aerospace/features.aerospace.md
- ./configs/aerospace/open-dock-app.sh
- ./configs/aerospace/performance-mode.sh
- ./configs/aerospace/secondary-bar-toggle.sh
- ./configs/aerospace/track-workspace-mru.sh
- ./scripts/aerospace-restart.sh
- ./configs/autoraise/config
- ./configs/autoraise/com.autoraise.daemon.plist
- ./configs/borders/bordersrc
- ./configs/sketchybar/sketchybarrc
- ./configs/sketchybar/colors.sh
- ./configs/sketchybar/icons.sh
- ./configs/sketchybar/theme.sh
- ./configs/sketchybar/helpers/wifi_rssi.swift
- ./configs/sketchybar/wifi_home_ssids.example
- ./configs/sketchybar/items/*.sh (18 files)
- ./configs/sketchybar/plugins/*.sh (25 files)
- ./configs/vscode/settings.json

## Descriptions

`./configs/aerospace/aerospace.toml`
- Main AeroSpace tiling window manager config
- Defines keybindings (alt+hjkl=focus, alt+shift+hjkl=move, alt+1-9=workspace)
- Configures gaps, monitors assignment, startup commands (NOTE: `gaps.outer.left/right` = 5 must stay equal to sketchybar `BAR_SIDE_PADDING` so the bar's outer divisions align with the tiled-window area edges)
- Launches sketchybar+borders on startup, then applies the default modes (performance mode ON + the bar hidden on secondary monitors) once the bar is up — a third `after-startup-command` waits for the bar items, resets the `/tmp` state files, and runs `secondary-bar-toggle.sh` then `performance-mode.sh` from their clean state, so each (re)start re-establishes the defaults deterministically
- App launchers via cmd+1-9 use open-dock-app.sh: if the app isn't running, open it on workspace N (matching the Dock position); if running, focus it (cycles through its windows on repeated presses, returns to last-focused window when coming from another app)
- alt+shift+; then p triggers aerospace/performance-mode.sh (toggles UI overhead reduction)
- alt+shift+; then b triggers aerospace/secondary-bar-toggle.sh (hides/shows SketchyBar on secondary monitor)
- CrossOver auto-floated via on-window-detected rule (prevents tiling conflicts with games)
- Stickies auto-floated via on-window-detected rule (keeps notes untiled; Stickies' own "Float on Top" handles always-on-top z-order)
- `on-focus-changed = []` AND `on-focused-monitor-changed = []`: mouse-follows-focus is deliberately NOT global on EITHER callback. `on-focus-changed` fires on every focus change and `on-focused-monitor-changed` fires whenever the focused monitor changes — including the mouse-driven ones AutoRaise triggers when the cursor crosses a window/monitor border — so a global `move-mouse` on either recentered the cursor on plain mouse-over (e.g. passing over a picture-in-picture player on another monitor warped the cursor to the focused app's center — annoying). Instead the warp is attached explicitly to the shortcut bindings, so only deliberate keyboard/app-switch focus changes recenter the cursor; manual mouse movement never does
- The `move-mouse window-lazy-center` warp is appended to: `alt-hjkl` (focus), `alt-1-9` + `alt-tab` (workspace), `alt-shift-1-9` (move-node-to-workspace --focus-follows-window), `alt-shift-hjkl` (move — a `move` keeps focus so it never relied on on-focus-changed anyway), and inside `open-dock-app.sh` for `cmd-1-9` app switches. Still pairs with AutoRaise's focus-follows-mouse (see `./configs/autoraise/`): after a keyboard focus change the cursor sits on the new window so AutoRaise won't yank focus back. `lazy` = no warp if the cursor is already on the target (avoids jitter)
- Edit for: keybindings, workspace layout, monitor assignment, gaps

`./configs/aerospace/apply-display-profile.sh`
- Auto-adjusts AeroSpace outer.top gap based on connected monitor resolutions
- Uses lookup table for common resolutions (4K, 1440p, 1080p, MacBook Retina)
- Detects display changes via fingerprint, updates aerospace.toml, reloads config
- The fingerprint folds in **which display is main** (`builtin_is_main`) on top of the sorted resolutions, so swapping the main display on the same physical monitors still re-triggers a rebuild
- Single source of truth for outer.top — detects the main display via `Main Display: Yes` in system_profiler and tracks its gap (main_gap)
- Reads /tmp/secondary-bar.state — when "off" (2+ monitors, main detected), emits `[{ monitor.main = <main_gap> }, 10]` so the bar gap stays only on the main monitor (where the bar still shows) and all other monitors reclaim to 10, regardless of monitor count; otherwise keeps the per-resolution multi-entry array. The old `monitor.secondary` override is gone (it only worked for 2-monitor setups)
- **Also auto-manages the workspace 7-9 monitor assignment** (the "laptop-companion" workspaces) in aerospace.toml's `[workspace-to-monitor-force-assignment]`, rewriting just the `7/8/9 =` lines (1-6 `main` and 0 `sidecar.*` untouched). `companion_ws_pattern`: when the MacBook built-in is SECONDARY (an external is main, e.g. home desk) → `'built-in.*'` (names the MacBook explicitly so 7-9 never grab an iPad sidecar); when the built-in is itself MAIN (e.g. travel with a portable external) → `'secondary'`, because `'built-in.*'` would then collide with workspaces 1-6 on the main display. The portable external reports an empty monitor name to AeroSpace so it can't be matched by a name regex — `'secondary'` resolves to it as the only non-main screen in the travel setup
- Trigger model for the 7-9 flip: applied on every AeroSpace (re)start via the startup `secondary-bar-toggle.sh → apply-display-profile.sh --force` chain (runs before performance mode boots out this LaunchAgent), and on hot display swaps within ~15s **when performance mode is OFF** (performance mode unloads this agent, so a hot swap while it's ON waits for the next restart / perf-mode toggle)
- Edit for: gap values per resolution, adding new resolution mappings, the 7-9 companion-monitor logic

`./configs/aerospace/com.aerospace.display-profile.plist`
- LaunchAgent that runs apply-display-profile.sh every 15 seconds
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
- Opens / focuses macOS Dock apps by position index (0-indexed)
- Called by aerospace.toml cmd+1-9 keybindings
- Reads persistent-apps from Dock plist, decodes URL to get .app path, extracts CFBundleIdentifier
- If app has no windows (per `aerospace list-windows --app-bundle-id`): touches a per-workspace grace marker `/tmp/aerospace-empty-watcher-grace-<ws>`, switches to workspace (position+1), then `open`s the app, so the new window lands on the matching workspace
- The grace marker tells empty-workspace-watcher.sh to skip bouncing that specific workspace while its mtime is fresh (<20s), giving the app time to spawn its first window
- After launching, spawns a backgrounded silent placement enforcer: polls `aerospace list-windows --app-bundle-id` every 200ms (cap ~18s); when the first window appears, if it landed on a non-target workspace (user navigated away mid-launch), silently relocates it with `aerospace move-node-to-workspace --window-id` (no focus follow, no workspace switch). Removes the grace marker on completion
- If app has windows and is already focused: cycles to next window in AeroSpace's window list (wraps)
- If app has windows but another app is focused: returns to last window focused via this script (per-app state at `/tmp/dock-cycle-<bundle_id>.state`); falls back to first window if state is missing/stale
- After focusing (both the running-app focus path and the cold-launch path once the window lands on the target workspace), warps the cursor onto the focused window via `aerospace move-mouse window-lazy-center` — mouse-follows-focus is no longer a global on-focus-changed callback (that also recentered on manual mouse-over), so shortcut-driven app switches recenter the cursor here instead
- State self-heals: closed windows / new window-ids after app restart drop out of the list and trigger the fallback
- Known limitation: manual focus changes (Mission Control, dock click, new window while app is in background) don't update the state file; next CMD+N from outside the app may target the previous CMD+N window rather than the most-recently-touched
- Fallback: if bundle id can't be read, plain `open` (old behavior)
- Edit for: state file location, cycling order, fallback behavior, placement-enforcer poll cap

`./configs/aerospace/performance-mode.sh`
- Toggles performance mode on/off (alt+shift+; then p via aerospace.toml service mode)
- ON: unloads display-profile LaunchAgent, hides cpu + ram (battery STAYS) and the traffic group (network_down/up + bracket). KEEPS the volume/audio and connectivity groups visible. (JankyBorders left running.)
- OFF: restores everything, reloads the display-profile LaunchAgent, re-enables all items
- Keeps workspace spaces (left), time/date, battery, connectivity (vpn/wifi/ethernet) and the volume/audio group visible in both modes
- Hides items via item-level `drawing` only (preserving each item's own icon/label config — ram has no icon, volume keeps its muted state). Spacer handling: hides ONLY spacer3 (leading spacer of the hidden traffic group), keeping spacer0/1/2 so every remaining gap stays one `GROUP_GAP` (theme.sh) wide — identical to normal mode; never touches spacer width
- State tracked via /tmp/performance-mode.state
- Default at startup: ON — aerospace.toml's after-startup-command clears /tmp/performance-mode.state then runs this script, and no state ⇒ the toggle lands ON
- Edit for: which items/groups to hide/show, the spacer hide/keep lists

`./configs/aerospace/com.aerospace.empty-watcher.plist`
- LaunchAgent that runs empty-workspace-watcher.sh as a long-running daemon
- RunAtLoad + KeepAlive (no StartInterval — script has its own 500ms poll loop)
- ThrottleInterval=5 prevents tight restart loops if the script bombs
- Install via symlink to ~/Library/LaunchAgents/, then launchctl load
- Edit for: log paths, throttle interval

`./configs/aerospace/empty-workspace-watcher.sh`
- Long-running daemon, polls every 500ms — per-monitor (multi-monitor aware)
- For each monitor: if its currently visible workspace has zero windows, bounces it to a non-empty workspace assigned to THAT monitor (so closing the last window on mon1's ws5 doesn't leave mon1 empty while focus drifts to mon2)
- Per-monitor MRU read from `/tmp/aerospace-ws-mru-mon-<mon-id>.state` (written by track-workspace-mru.sh)
- Fallback order per monitor: MRU newest-first (filtered to that monitor + currently non-empty) → first non-empty workspace AeroSpace lists for that monitor → if every workspace on the monitor is empty, the first workspace AeroSpace lists for that monitor (per aerospace.toml assignment order: ws1 for main, ws7 for secondary, ws0 for the Sidecar/third monitor) → stay put only when that target equals the already-visible ws
- Focused-monitor bounce uses `aerospace workspace --fail-if-noop <target>` (focus stays put because target is on the same monitor)
- Non-focused-monitor bounce uses `aerospace workspace <target>` then `aerospace focus-monitor <orig-mon-id>` to return focus to the originally focused monitor — the workspace switch steals focus to the target's monitor as a side effect, so we restore it. The ~100ms borders/sketchybar flicker is accepted
- `focus-monitor` is called by numeric monitor-id (not name) — monitor names can contain glob metacharacters like `(` `)` (e.g. "Sidecar Display (AirPlay)") which break the name-pattern matching AeroSpace uses
- Per-workspace grace: if `/tmp/aerospace-empty-watcher-grace-<visible_ws>` exists with fresh mtime (<20s), that one monitor's bounce is skipped (other monitors still bounce). Touched by open-dock-app.sh during app launches
- The 20s grace cap is intentionally slightly longer than open-dock-app.sh's ~18s placement-enforcer cap so slow Electron cold-starts don't get bounced mid-launch
- Every `aerospace` call goes through the `aero()` timeout wrapper (defined in `lib-paths.sh`), NOT bare `aerospace`. The `aerospace` CLI is a client that talks to the AeroSpace.app server over a socket; when the server restarts/wedges (seen after a display change) an in-flight client call can block on that socket forever, and a bare `$(aerospace …)` then hangs this whole daemon — bash blocks on the command substitution and launchd KeepAlive can't help because the process is alive, just stuck (this silently killed the watcher for >1 day). `aero` runs `aerospace` in the background with a hard `AERO_TIMEOUT` (3s) watchdog that SIGKILLs a hung call, so a wedged server degrades to an empty result the loop skips and retries next tick instead of a permanent hang. Bash-native (no GNU `timeout` on macOS)
- Bash 3.2 compatible: no `declare -A`, no `mapfile` — uses parallel arrays and grep-based set membership
- Edit for: poll interval, fallback logic, grace_seconds cap, `AERO_TIMEOUT`/`aero()` in lib-paths.sh

`./configs/aerospace/track-workspace-mru.sh`
- Called from aerospace.toml exec-on-workspace-change with $AEROSPACE_FOCUSED_WORKSPACE
- Derives the workspace's monitor-id via `aerospace list-workspaces --all --format '%{monitor-id} %{workspace}'` + awk lookup (workspaces are statically assigned to monitors via aerospace.toml `[workspace-to-monitor-force-assignment]`)
- Appends focused workspace to per-monitor file `/tmp/aerospace-ws-mru-mon-<mon-id>.state`, dedups, caps at 10 entries (newest last)
- Uses per-monitor mkdir-based lockdir `/tmp/aerospace-ws-mru-mon-<mon-id>.lock` to serialise concurrent writers; bails after ~250ms to never block aerospace
- Silently exits if monitor lookup fails (workspace unknown, monitor disconnected mid-call) — avoids writing to a state file with empty monitor-id
- Edit for: MRU cap size, lock timeout

`./configs/aerospace/secondary-bar-toggle.sh`
- Toggles SketchyBar visibility on the secondary monitors (alt+shift+; then b via aerospace.toml service mode)
- ON: `sketchybar --bar display=all` + `rm -f` the state file
- OFF: `sketchybar --bar display=main` + writes `off` to the state file
- Does NOT edit outer.top itself anymore — after writing the state (state written BEFORE the generator runs), it delegates gap regeneration to `apply-display-profile.sh --force`, the single source of truth. When off, the generator emits `[{ monitor.main = <main_gap> }, 10]` so non-main monitors reclaim the freed bar space; works for any monitor count
- No own `aerospace reload-config` — the generator runs reload itself (avoids a double reload)
- Orthogonal to performance mode: only flips the bar's display target and the bar state, leaves per-item drawing state alone
- State tracked via /tmp/secondary-bar.state
- apply-display-profile.sh also reads this state file, so monitor-change events keep the bar-hidden gaps applied while the bar is hidden
- Default at startup: hidden (OFF) — aerospace.toml's after-startup-command clears /tmp/secondary-bar.state then runs this script, and no state ⇒ the toggle lands OFF/hidden
- Edit for: changing target monitor (display=main); gap behavior lives in apply-display-profile.sh

`./scripts/aerospace-restart.sh`
- Full restart of the whole window-manager stack — wired to the `aerostart` shell alias (`zsh/alias/osx.zsh`)
- Stop phase: `launchctl bootout` the three LaunchAgents (display-profile, empty-watcher, autoraise — they're KeepAlive so a plain kill respawns them) then `killall` AeroSpace, sketchybar, borders, AutoRaise
- Start phase: `open -a AeroSpace` (its after-startup-command relaunches sketchybar + borders), waits for AeroSpace to be up, then `launchctl bootstrap` the three LaunchAgents again
- Edit for: which agents/processes are cycled, start/stop ordering

`./configs/autoraise/config`
- AutoRaise config — focus-follows-mouse (hover a window to focus it), the piece AeroSpace doesn't do natively (it only does the inverse, mouse-follows-focus)
- Installed via `brew tap dimentium/autoraise && brew install autoraise` (binary at `/opt/homebrew/bin/AutoRaise`)
- Symlinked to `~/.config/AutoRaise/config` (the path AutoRaise reads); format is `key=value`, one per line
- `disableKey="option"`: holding alt fully suppresses AutoRaise. Since every AeroSpace binding is alt-based (alt+hjkl focus, alt+shift+hjkl move, alt+1-9 workspace), focus-follows-mouse is gated off during all keyboard window management — the cursor can't hijack the window you're manipulating
- `pollMillis=200` + `delay=1` + `requireMouseStop=false`: no mouse-stop requirement — the window under the cursor is focused on each ~200ms poll tick, and the coarse poll interval itself debounces fast fly-overs (a flick past a window between ticks is skipped). `requireMouseStop` is set explicitly to `false` because AutoRaise defaults it to `true`. Lower `pollMillis` = snappier but more likely to grab windows you only flick past. (Alternative to the earlier stop-based tuning; under evaluation.) `delay>1` adds a hover-dwell (each unit above 1 = one poll); `delay=0` disables raising
- `mouseDelta=1.0`: ignore pointer jitter smaller than this, so small unintentional nudges while the cursor rests don't re-trigger a focus change
- Warping is left to AeroSpace's `on-focus-changed` callback (AutoRaise's own warp disabled) so the two tools don't fight over the cursor
- Requires Accessibility permission (System Settings → Privacy & Security → Accessibility → add `/opt/homebrew/bin/AutoRaise`) or it runs but does nothing
- Edit for: pollMillis, delay, disableKey, ignoreApps, mouseDelta

`./configs/autoraise/com.autoraise.daemon.plist`
- LaunchAgent that runs the AutoRaise binary as a background daemon (RunAtLoad + KeepAlive, ThrottleInterval=5), mirroring the `com.aerospace.*` pattern instead of `brew services`
- Symlinked to `~/Library/LaunchAgents/`, then `launchctl load`
- Logs to `/tmp/autoraise.stdout.log` / `/tmp/autoraise.stderr.log`
- AutoRaise auto-reads `~/.config/AutoRaise/config`, so the plist just runs the binary with no args. After a config edit: `pkill AutoRaise` (KeepAlive respawns it) or unload/load the agent
- Edit for: binary path, log paths, throttle interval

`./configs/borders/bordersrc`
- JankyBorders config (window border styling)
- Muted-red theme: active_color=0xff9e2020 (focused window); inactive_color=0x00000000 (transparent → unfocused windows get NO border, since JankyBorders has no "active only" toggle)
- Options: style=round, width=1.0, hidpi=on
- active_color is kept in sync with colors.sh BORDER_ACTIVE/PINK (the bar accent mirrors the focused-border red)
- Edit for: border colors, width, style

`./configs/sketchybar/sketchybarrc`
- Main sketchybar entry point (status bar)
- Sources colors.sh, icons.sh, theme.sh, then items: spaces, calendar, volume, headset, ram, cpu, battery, vpn, wifi, ethernet, network_down, network_up
- Commented out (disabled): apple.sh, settings.sh
- Not sourced (disabled): front_app.sh, brew.sh, github.sh, spotify.sh
- Defines bar: height=58, floating style, transparent bg
- Edge alignment: `margin=0` + `BAR_SIDE_PADDING` place the outer divisions `BAR_SIDE_PADDING` px from each screen edge. Keep `BAR_SIDE_PADDING` = aerospace `gaps.outer.left/right` (5) so the left/right divisions line up with the tiled-window (app) area edges
- Defines defaults + the shared `bracket_style`: division geometry (corner radius, border, blur, drop shadow) all pulled from theme.sh tokens; font=JetBrainsMono
- Groups items into brackets: calendar_group, audio, traffic, resources, connectivity
- Inter-group spacer items (spacer0–3) all use theme.sh's `GROUP_GAP` width
- Edit for: bar position, default item styling, enable/disable items (for the overall division look, edit theme.sh)

`./configs/sketchybar/theme.sh`
- Visual TEMPLATE — single source of truth for "division" geometry (a division = any grouped pill: spaces 1-6 / 7-9 / 0, calendar, audio, resources, connectivity, traffic)
- Tokens: `DIVISION_RADIUS` / `SPACE_BUBBLE_RADIUS` / `POPUP_RADIUS` (corner rounding), `DIVISION_BORDER_WIDTH` (0 = no border), `DIVISION_BLUR` (0 — fills are opaque), `DIVISION_SHADOW_*` (hard-edged drop shadow at each division's bottom-right; SketchyBar uses SCREEN y-DOWN coords — 0=right, 90=down, 45=bottom-right — and has NO blur property, so it's softened via opacity; angle must stay positive as SketchyBar stores it unsigned), `GROUP_GAP` (the single uniform gap BETWEEN divisions), `DIVISION_PAD` (inner pad between a division edge and its first/last element) and `ELEMENT_GAP` (gap between elements inside a division)
- DIVISION_PAD/ELEMENT_GAP are applied via item paddings (NOT bracket bg padding — that does nothing in this build); kept EQUAL so a hiding edge element's neighbour gap doubles cleanly as the edge pad. The leftmost item gets DIVISION_PAD on its left, the rightmost DIVISION_PAD on its right, internal boundaries ELEMENT_GAP. Plugins that toggle visibility (ethernet/headset/network_speed) source theme.sh and set these
- Sourced by sketchybarrc before any item; items/*.sh (sourced in the same shell) inherit the tokens. Colour palette stays in colors.sh (DARK_BG = opaque division fill)
- Applied uniformly across BOTH bar sides and BOTH modes (normal + performance) — performance-mode.sh only toggles which spacers draw, never their width
- Edit for: the bar's overall pill/division look — radius, border, shadow, opacity, inter-division spacing

`./configs/sketchybar/helpers/wifi_rssi.swift`
- Tiny CoreWLAN Swift helper that prints the current Wi-Fi link RSSI (dBm). Reads the CURRENT link only — no scan, and (verified) no Location permission needed — so it's cheap and non-disruptive. plugins/wifi.sh compiles it on demand to `helpers/wifi_rssi` (gitignored binary) and maps RSSI → the strength icon + the weak-signal auto-reconnect trigger. Needed because macOS 26 removed `airport` and neither networksetup nor ipconfig expose RSSI
- Edit for: what the helper outputs (currently just RSSI)

`./configs/sketchybar/wifi_home_ssids.example`
- Template for the gitignored `wifi_home_ssids` (private SSID names) that arms wifi.sh's auto-reconnect: when on one of those SSIDs and signal hits 1 bar, Wi-Fi is bounced so macOS reconnects to the strongest AP. Any number of SSIDs works; empty/missing list = strength-icon-only, no auto-switch

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
- Edge/element paddings come from theme.sh (DIVISION_PAD / ELEMENT_GAP), not per-item magic numbers — each item marks its left/right-edge vs internal paddings with those tokens
- State-driven items: calendar = one clock icon + "Day DD HH:MM" (date+time pair); resources = single stats icon + "cpu% ramGB" + battery last; ethernet/headset show ONLY when connected; network_up/down show ONLY the direction with traffic; volume greys + drops % when muted; vpn = NordVPN app glyph tinted by connection; wifi = RSSI strength bars
- Key file: spaces.sh (workspaces with aerospace integration)
- Edit for: item appearance, positioning, which events trigger updates

`./configs/sketchybar/plugins/*.sh`
- Event handlers and data fetchers (25 files)
- Pattern: receive events, query system, update sketchybar items
- Key files: aerospace.sh (workspace state), wifi.sh, network_speed.sh, volume.sh, headset.sh, ethernet.sh, ram.sh
- aerospace.sh: workspace display with multi-monitor colors. Renders app ICONS via sketchybar-app-font (__icon_map in icon_map.sh) when EVERY app in a space is mapped, else falls back to text names (shorten_app_name). Subscribes front_app_switched so it repaints on app open, not only on workspace change
- wifi.sh: maps current-link RSSI (helpers/wifi_rssi) → strength bars, plus opt-in auto-reconnect on a weak home network (gate on wifi_home_ssids + 1-bar debounce + cooldown → toggle Wi-Fi). wifi_click.sh toggles Wi-Fi power on click
- network_speed.sh: single-poller (network_down) per-direction CONDITIONAL bandwidth (each shown only when its rate >0; bracket hidden when idle). Parses netstat byte counters FROM THE RIGHT (Ibytes=NF-4, Obytes=NF-1) so VPN/tunnel interfaces — which drop the Address column — read correctly
- ram.sh outputs raw GB used (not %); volume.sh adds a muted state; ethernet.sh/headset.sh collapse the icon (drawing=off + zero pad) when disconnected while keeping the item drawing=on so the poller still runs
- Edit for: logic of what's displayed, data sources, formatting

`./configs/vscode/settings.json`
- VSCode editor settings
- Font sizes, formatters, Claude Code config, icon themes
- Minimal UI: statusBar=hidden, activityBar=hidden, minimap=off
- Edit for: editor preferences, extension configs
