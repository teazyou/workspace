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
- ./doc.aerospace.md
- ./features.aerospace.md
- ./configs/aerospace/lib-paths.sh
- ./configs/aerospace/open-dock-app.sh
- ./configs/aerospace/swap-workspaces.sh
- ./configs/aerospace/tests/swap-workspaces_test.sh
- ./scripts/aerospace-restart.sh
- ./configs/borders/bordersrc
- ./configs/sketchybar/sketchybarrc
- ./configs/sketchybar/colors.sh
- ./configs/sketchybar/icons.sh
- ./configs/sketchybar/theme.sh
- ./configs/sketchybar/helpers/wifi_rssi.swift
- ./configs/sketchybar/items/*.sh (15 files)
- ./configs/sketchybar/plugins/*.sh (25 files)
- ./configs/sketchybar/tests/pomodoro_test.sh
- ./configs/vscode/settings.json

## Descriptions

`./configs/aerospace/aerospace.toml`
- Main AeroSpace tiling window manager config
- Defines keybindings (alt+hjkl=focus, alt+shift+hjkl=move, alt+1-9=workspace)
- Configures gaps, monitors assignment, startup commands (NOTE: `gaps.outer.left/right` = 5 must stay equal to sketchybar `BAR_SIDE_PADDING` so the bar's outer divisions align with the tiled-window area edges)
- Launches sketchybar + borders (borders via `~/.config/borders/bordersrc`, the single source of truth) on startup; a third `after-startup-command` runs `apply-display-profile.sh` once the WM is up, regenerating the per-monitor top gaps + the workspace 7-9 assignment. The bar itself draws on the MAIN monitor only — sketchybarrc sets `display=main`; secondary monitors never show a bar
- App launchers via cmd+1-9 use open-dock-app.sh: if the app isn't running, open it on workspace N (matching the Dock position); if running, focus it (cycles through its windows on repeated presses, returns to last-focused window when coming from another app)
- CrossOver auto-floated via on-window-detected rule (prevents tiling conflicts with games)
- Stickies auto-floated via on-window-detected rule (keeps notes untiled; Stickies' own "Float on Top" handles always-on-top z-order)
- Preview auto-floated via on-window-detected rule (PDFs/images shouldn't grab a tile)
- **CrossOver GAMES auto-floated via one shared rule matched by app NAME** (`if.app-name-regex-substring = '(?i)ravenswatch|path ?of ?exile'`) — this is the single place to add a new game. The CrossOver `app-id` rule above can NOT catch them: a CrossOver game runs as a bare Wine process whose bundle id AeroSpace reports as `NULL-APP-BUNDLE-ID`, so no app-id rule ever fires on it (Ravenswatch → app `Ravenswatch.exe`, Path of Exile 2 → app `PathOfExile.exe`)
- **Gotcha — never read the game's identity off the CrossOver LAUNCHER.** While a game boots, the front window belongs to a short-lived helper with a *different* app name (`Path of Exile 2`) and a hashed `com.codeweavers.CrossOverHelper.<bottle-hash>.<app-hash>` bundle id; the real Wine process (`PathOfExile.exe`, null bundle id) replaces it moments later. A rule written from what `aerospace list-windows` shows during startup silently never matches the running game — always re-check once the game is actually up. The regex therefore covers BOTH spellings per game, with `(?i)` for case-insensitivity (verified: AeroSpace's engine handles inline flags + alternation)
- `layout floating` is the strongest per-app opt-out AeroSpace offers (there is no per-app "unmanage"; `aerospace enable off` is global): the window is never tiled, resized, or reflowed. `on-window-detected` fires at DETECTION time only, so a game already open when the rule is added must be floated once by hand (`aerospace layout floating --window-id <id>`) or simply restarted. NOTE: floating covers AeroSpace only — JankyBorders (`blacklist=` in bordersrc) is a separate opt-out and is currently NOT set for these games
- `on-focus-changed = []` AND `on-focused-monitor-changed = []`: mouse-follows-focus is deliberately NOT global on EITHER callback. `on-focus-changed` fires on every focus change and `on-focused-monitor-changed` fires whenever the focused monitor changes — including the mouse-driven ones triggered when the cursor crosses a window/monitor border — so a global `move-mouse` on either recentered the cursor on plain mouse-over (e.g. passing over a picture-in-picture player on another monitor warped the cursor to the focused app's center — annoying). Instead the warp is attached explicitly to the shortcut bindings, so only deliberate keyboard/app-switch focus changes recenter the cursor; manual mouse movement never does
- The `move-mouse window-lazy-center` warp is appended to: `alt-hjkl` (focus), `alt-1-9` + `alt-tab` (workspace), `alt-shift-1-9` (move-node-to-workspace --focus-follows-window), `alt-shift-hjkl` (move — a `move` keeps focus so it never relied on on-focus-changed anyway), and inside `open-dock-app.sh` for `cmd-1-9` app switches. This keeps pointer and keyboard focus together so they never diverge: after every deliberate focus change the cursor sits on the newly focused window. `lazy` = no warp if the cursor is already on the target (avoids jitter)
- Edit for: keybindings, workspace layout, monitor assignment, gaps

`./configs/aerospace/apply-display-profile.sh`
- Auto-adjusts AeroSpace outer.top gap based on connected monitor resolutions
- Uses lookup table for common resolutions (4K, 1440p, 1080p, MacBook Retina)
- Reads the connected displays from `system_profiler SPDisplaysDataType` (one capture per run, passed to every helper), rewrites aerospace.toml, reloads config. Runs unconditionally — no change detection, because it only runs once per AeroSpace start
- Bails without touching the config if no display is detected (`system_profiler` returns empty in some non-GUI contexts), so a blind rewrite can't clobber a working profile with the no-monitor fallback gap
- Single source of truth for outer.top — detects the main display via `Main Display: Yes` in system_profiler and tracks its gap (main_gap)
- The bar draws on the MAIN monitor only (sketchybarrc `display=main`), so with 2+ monitors (main detected) it always emits the main-only gap array — the bar gap stays on the main monitor and all other monitors reclaim the top space, regardless of monitor count; the per-resolution multi-entry array remains only as the no-main-detected fallback. The old `monitor.secondary` override is gone (it only worked for 2-monitor setups)
- **Also auto-manages the workspace 7-9 monitor assignment** (the "laptop-companion" workspaces) in aerospace.toml's `[workspace-to-monitor-force-assignment]`, rewriting just the `7/8/9 =` lines (1-6 `main` and 0 `sidecar.*` untouched). `companion_ws_pattern`: when the MacBook built-in is SECONDARY (an external is main, e.g. home desk) → `'built-in.*'` (names the MacBook explicitly so 7-9 never grab an iPad sidecar); when the built-in is itself MAIN (e.g. travel with a portable external) → `'secondary'`, because `'built-in.*'` would then collide with workspaces 1-6 on the main display. The portable external reports an empty monitor name to AeroSpace so it can't be matched by a name regex — `'secondary'` resolves to it as the only non-main screen in the travel setup
- **Trigger model — start-only, no poller:** the gaps + the 7-9 flip are applied on every AeroSpace (re)start via the startup `apply-display-profile.sh` call, and nowhere else. The WM stack has no LaunchAgent of its own. **So after plugging/unplugging a monitor, run `aerospace-restart` to re-fit the gaps and move workspaces 7-9.**
- If a background poller is ever added back, its plist `EnvironmentVariables.PATH` MUST include `/usr/sbin`: the script's first call is `system_profiler` (`/usr/sbin/system_profiler`), and under `set -euo pipefail` a missing PATH entry aborts the whole run with exit 127 and an empty log
- Edit for: gap values per resolution, adding new resolution mappings, the 7-9 companion-monitor logic

`./doc.aerospace.md`
- GENERIC upstream AeroSpace + SketchyBar + JankyBorders install/setup tutorial — step-by-step instructions for configuring the full stack from scratch
- **NON-AUTHORITATIVE: uses default/example values that do NOT match this repo's live config.** Reference only; trust the live config files (and the descriptions in this guide) over it
- Read-only reference, don't edit

`./features.aerospace.md`
- GENERIC upstream AeroSpace feature/keybinding reference — covers tiling, workspaces, layouts, integration features
- **NON-AUTHORITATIVE: lists keybindings (e.g. alt+f fullscreen, service-mode backspace=close-all-but-current) that are ABSENT from the live `aerospace.toml`.** Reference only; the real bindings live in the config
- Read-only reference, don't edit

`./configs/aerospace/open-dock-app.sh`
- Opens / focuses macOS Dock apps by position index (0-indexed)
- Called by aerospace.toml cmd+1-9 keybindings
- Reads persistent-apps from Dock plist, decodes URL to get .app path, extracts CFBundleIdentifier
- If app has no windows (per `aerospace list-windows --app-bundle-id`): switches to workspace (position+1), then `open`s the app, so the new window lands on the matching workspace
- After launching, spawns a backgrounded silent placement enforcer: polls `aerospace list-windows --app-bundle-id` every 200ms (cap ~18s, `PLACEMENT_CAP_SECONDS` in lib-paths.sh); when the first window appears, if it landed on a non-target workspace (user navigated away mid-launch), silently relocates it with `aerospace move-node-to-workspace --window-id` (no focus follow, no workspace switch)
- If app has windows and is already focused: cycles to next window in AeroSpace's window list (wraps)
- If app has windows but another app is focused: returns to last window focused via this script (per-app state at `/tmp/dock-cycle-<bundle_id>.state`); falls back to first window if state is missing/stale
- After focusing (both the running-app focus path and the cold-launch path once the window lands on the target workspace), warps the cursor onto the focused window via `aerospace move-mouse window-lazy-center` — mouse-follows-focus is no longer a global on-focus-changed callback (that also recentered on manual mouse-over), so shortcut-driven app switches recenter the cursor here instead
- State self-heals: closed windows / new window-ids after app restart drop out of the list and trigger the fallback
- Known limitation: manual focus changes (Mission Control, dock click, new window while app is in background) don't update the state file; next CMD+N from outside the app may target the previous CMD+N window rather than the most-recently-touched
- Fallback: if bundle id can't be read, plain `open` (old behavior)
- Edit for: state file location, cycling order, fallback behavior, placement-enforcer poll cap

`./configs/aerospace/lib-paths.sh`
- Shared library `source`d by open-dock-app.sh — the single source of truth for the cross-script contract, so a timing change lands everywhere from one edit
- Defines `PLACEMENT_CAP_SECONDS=18` (how long open-dock-app.sh's placement enforcer polls for a launching app's first window)
- Bash 3.2 compatible (no associative arrays / mapfile)
- Edit for: the placement-cap constant
- NOTE: the empty-workspace-watcher daemon, its plist, track-workspace-mru.sh, the grace-marker contract and the `aero()` timeout wrapper were REMOVED (2026-07): closing the last focused window is handled natively by AeroSpace (macOS refocuses another window and AeroSpace reveals its workspace); the watcher only covered rare cases (focus falling to a windowless app, background self-closes on a non-focused monitor) judged not worth its constant polling cost. If a long-running aerospace-polling loop is ever reintroduced, resurrect `aero()` from git history — a bare `$(aerospace …)` can hang forever on a wedged server socket

`./configs/aerospace/swap-workspaces.sh`
- Transactional workspace-content swap invoked by **service mode + `0`–`9`** (`alt-shift-semicolon`, then a digit). It exchanges every AeroSpace-managed window in the focused workspace with the target workspace, including floating windows, and leaves the original workspace focused.
- Uses explicit window IDs and one stable, collision-checked staging workspace (`aerospace-swap-staging`, test-overridable with `SWAP_TEMP_WORKSPACE`) under an atomic `mkdir` lock. The name deliberately does not begin with `_`, which AeroSpace reserves. An occupied staging workspace is refused so crash leftovers remain discoverable. Window IDs are moved source → temporary → target, so neither destination ever receives a mixture that can collide with the other set. Saved fullscreen state is suspended before the first move and restored after rebuilding; if a command fails after mutation begins, every captured ID is attempted during best-effort rollback.
- Preserves AeroSpace fullscreen state and captures the real depth-first order of **tiled** leaves by walking `focus --dfs-index`; floating windows are moved/restored explicitly but are not in AeroSpace's DFS index space. **Do not** substitute `list-windows` ordering, which is app/title ordered. On restoration it uses adjacent `swap dfs-prev` operations to deterministically recover tiled order.
- Supported tiling shapes are exact flat `h_tiles`/`v_tiles` roots and the service-mode `/` balanced 2×2 (`h_tiles` root with `v_tiles` child columns), plus its rotated counterpart. Accordion, mixed, or deeper custom nesting is refused before any mutation instead of being flattened. Parent IDs are not exposed by AeroSpace, so arbitrary nested trees cannot be reconstructed safely.
- On success it returns to the original workspace, focuses the first window currently listed there, issues one SketchyBar workspace repaint, and follows the repository's deliberate keyboard-focus mouse policy: `move-mouse window-lazy-center`, with `monitor-lazy-center` fallback for an empty workspace or a focus/warp race. A same-workspace digit is an AeroSpace no-op (no temporary workspace, reflow, repaint, or cursor move).
- Leaves JankyBorders running throughout the swap; its active border follows the temporary focus walk and the final focused window normally.
- Bash 3.2-compatible and command-boundary mockable via `AEROSPACE_BIN` / `SKETCHYBAR_BIN`. Run `bash configs/aerospace/tests/swap-workspaces_test.sh` for deterministic state-machine coverage of no-op, argument validation, stable-temp refusal, fullscreen timing, flat, normal/rotated grid, unsupported-layout, and rollback paths.

`./scripts/aerospace-restart.sh`
- Full restart of the whole window-manager stack — wired to the `aerospace-restart` shell alias (`zsh/alias/osx.zsh`)
- No LaunchAgent left in the stack: it covers AeroSpace, sketchybar and borders only
- Stop phase: `killall` AeroSpace, sketchybar, borders
- Start phase: `open -a AeroSpace` (its after-startup-command relaunches sketchybar + borders **and regenerates the per-monitor gaps**)
- **Also the way to re-profile gaps + the workspace 7-9 assignment after a monitor change** — nothing else re-runs `apply-display-profile.sh`
- Edit for: which processes are cycled, start/stop ordering

`./configs/borders/bordersrc`
- JankyBorders config (window border styling)
- Muted-red theme: active_color=0xffaa2222 (focused window); inactive_color=0x00000000 (transparent → unfocused windows get NO border, since JankyBorders has no "active only" toggle)
- Options: style=round, width=1.0, hidpi=on, order=above
- active_color MUST stay in sync with colors.sh `BORDER_ACTIVE` (=`PINK`, both `0xffaa2222`) — colors.sh's header literally says "keep in sync with configs/borders/bordersrc"; the whole bar accent mirrors this focused-border red
- Launched at startup by aerospace.toml running this file (`~/.config/borders/bordersrc`) — single source of truth, so border edits here apply on the next WM restart
- Edit for: border colors, width, style

`./configs/sketchybar/sketchybarrc`
- Main sketchybar entry point (status bar)
- Sources colors.sh, icons.sh, theme.sh, then items: spaces, calendar, the four-item Pomodoro timer, ram, cpu, battery, vpn_be + vpn_sn (both from items/vpn.sh), wifi, ethernet (the audio division — volume + headset — was removed entirely 2026-07; its item/plugin files are deleted, only the icons.sh glyph exports and the dead volume_click.sh template remain)
- Commented out (disabled): apple.sh, settings.sh
- Not sourced (disabled): front_app.sh, brew.sh, github.sh, spotify.sh
- Defines bar: height=58, floating style, transparent bg, `display=main` (bar on the main monitor ONLY — secondary monitors never draw it; apply-display-profile.sh emits the matching per-monitor top gaps)
- Edge alignment: `margin=0` + `BAR_SIDE_PADDING` place the outer divisions `BAR_SIDE_PADDING` px from each screen edge. Keep `BAR_SIDE_PADDING` = aerospace `gaps.outer.left/right` (5) so the left/right divisions line up with the tiled-window (app) area edges
- Defines defaults + the shared `bracket_style`: division geometry (corner radius, border, blur) all pulled from theme.sh tokens; font=JetBrainsMono
- Groups right-side items into brackets in visual order connectivity | resources | Pomodoro | calendar: `calendar_group`, `pomodoro_group`, `resources`, `connectivity`
- Inter-group spacer items (spacer0–2: calendar↔Pomodoro, Pomodoro↔resources, resources↔connectivity) all use theme.sh's `GROUP_GAP` width — exactly one gap per adjacent division pair
- Runs one Pomodoro `sync` after all items/brackets exist, then paints the spaces strip; startup/wake reconciliation resumes a future absolute deadline or commits one expired rollover
- Edit for: bar position, default item styling, enable/disable items (for the overall division look, edit theme.sh)

`./configs/sketchybar/theme.sh`
- Visual TEMPLATE — single source of truth for "division" geometry (a division = any grouped pill: spaces 1-6 / 7-9 / 0, calendar, Pomodoro, resources, connectivity)
- Tokens: `DIVISION_RADIUS` / `SPACE_BUBBLE_RADIUS` / `POPUP_RADIUS` (corner rounding), `DIVISION_BORDER_WIDTH` (0 = no border), `DIVISION_BLUR` (0 — fills are opaque), `GROUP_GAP` (the single uniform gap BETWEEN divisions), `DIVISION_PAD` (inner pad between a division edge and its first/last element) and `ELEMENT_GAP` (gap between elements inside a division)
- SUB-LABEL MARKER lesson (**not in use** — built as a selection dot, then a selection underline, for the VPN items on 2026-07-30 and removed the same day: colour alone reads the VPN state, and two grey icons simply mean "off"; kept here because the findings cost real measurement): SketchyBar has no sub-label slot, and neither `label.background` nor the item `background` can be shrunk or inset — `label.background.padding_*` does not change the fill's width at all, and the item background's padding does not inset it either: it only TRANSLATES the fill and ADDS outward layout width (measured: `background.padding_left/right=6` grew the connectivity division 85 → 97 px), so a background can only ever be a full-element-width rule (30 px under an 18 px label). A narrower/thinner marker therefore has to be the element's own ICON slot carrying a glyph (`●` U+25CF, or a `─` U+2500 hairline), dropped below the text with `icon.y_offset` (negative = DOWN) and pulled back under it with a NEGATIVE `icon.padding_right` such that `pad_left + <glyph advance> + pad_right == 0` → zero layout cost. Show/hide must then be a COLOUR (`icon.color=$TRANSPARENT`), NEVER `icon.drawing`: `drawing=off` removes the glyph's advance and shifts the label. Thinness floor: the display is @1:1, so 1 pt == 1 px — a sub-pixel rule is not expressible; U+2500 at `:Regular:` is the thinnest the font stack gives (`:Bold:` and `▁` U+2581 are visibly thicker), and glyph size trades stroke weight against rule length (`:Regular:13.0` → 14 px long)
- DIVISION_PAD/ELEMENT_GAP are applied via item paddings (NOT bracket bg padding — that does nothing in this build); kept EQUAL so a hiding edge element's neighbour gap doubles cleanly as the edge pad. The leftmost item gets DIVISION_PAD on its left, the rightmost DIVISION_PAD on its right, internal boundaries ELEMENT_GAP. Plugins that toggle visibility (ethernet) source theme.sh and set these
- Sourced by sketchybarrc before any item; items/*.sh (sourced in the same shell) inherit the tokens. Colour palette stays in colors.sh (DARK_BG = opaque division fill)
- Applied uniformly across BOTH bar sides
- Edit for: the bar's overall pill/division look — radius, border, opacity, inter-division spacing

`./configs/sketchybar/helpers/wifi_rssi.swift`
- Tiny CoreWLAN Swift helper that prints the current Wi-Fi link RSSI (dBm). Reads the CURRENT link only — no scan, and (verified) no Location permission needed — so it's cheap and non-disruptive. plugins/wifi.sh compiles it on demand to `helpers/wifi_rssi` (gitignored binary) and maps RSSI → the strength icon. Needed because macOS 26 removed `airport` and neither networksetup nor ipconfig expose RSSI
- Edit for: what the helper outputs (currently just RSSI)

`./configs/sketchybar/colors.sh`
- Color palette exports (CriticalElement Dotfiles base)
- Window-border-matched reds: `BORDER_ACTIVE=0xffaa2222` (firebrick; **keep in sync with configs/borders/bordersrc** `active_color`), `BORDER_INACTIVE=0xff4d1a1a` (popup borders only). `PINK` is repointed to `$BORDER_ACTIVE` — it stays the accent variable name referenced across every item, so the whole bar recolors from that one line
- `DARK_BG=0xff1e1e1e` (near-black, fully OPAQUE — pill/bracket division fills; no transparency, see theme.sh `DIVISION_BLUR`); `BAR_COLOR=TRANSPARENT` (the empty middle shows the wallpaper); `TRANSPARENT=0x00000000`. Plus the spaces palette (`SPACE_FOCUS_BG` etc.) the aerospace.sh coordinator reads
- Edit for: global color scheme changes

`./configs/sketchybar/icons.sh`
- Nerd Font icon exports
- Categories: general, git, spotify, aerospace, battery, volume, calendar, Pomodoro (work/break/play/pause/reset), wifi, ethernet, vpn, ram, headset, settings, network speed
- Edit for: adding/changing icons

`./configs/sketchybar/items/*.sh`
- Item definitions (visual config, positioning, subscriptions)
- Pattern: define item properties, add to bar, subscribe events
- Active item files: spaces.sh, calendar.sh, pomodoro.sh (defines preset/countdown/toggle/reset), ram.sh, cpu.sh, battery.sh, vpn.sh (defines TWO items: vpn_be + vpn_sn), wifi.sh, ethernet.sh; volume.sh/headset.sh were deleted with the audio division
- Disabled items: apple.sh (commented), settings.sh (commented), front_app.sh (not sourced), brew.sh, github.sh, spotify.sh
- Edge/element paddings come from theme.sh (DIVISION_PAD / ELEMENT_GAP), not per-item magic numbers — each item marks its left/right-edge vs internal paddings with those tokens
- State-driven items: calendar = one clock icon + "Day DD HH:MM" (date+time pair); Pomodoro = preset + countdown + play/pause + reset; resources = single stats icon + "cpu% ramGB" + battery last; ethernet shows ONLY when connected; vpn_be/vpn_sn = two text icons "BE"/"SN", colour-only (grey = not connected, red = connected, yellow = connecting, magenta = `nord refresh` needed) — no orange, and deliberately no selection marker (both grey = VPN off); wifi = RSSI strength bars
- Poller freqs as defined in items/*.sh — always-on: battery 60, vpn_be/vpn_sn 30, ethernet 30, wifi 30, cpu 5, ram 5. Pomodoro alone switches dynamically: 1 second while running, 0 while paused
- Key file: spaces.sh (workspaces with aerospace integration)
- Edit for: item appearance, positioning, which events trigger updates

`./configs/sketchybar/plugins/*.sh`
- Event handlers and data fetchers (25 files)
- Pattern: receive events, query system, update sketchybar items
- Key files: aerospace.sh (workspace state), pomodoro.sh, wifi.sh, ethernet.sh, ram.sh
- aerospace.sh: workspace display with multi-monitor colors. Renders app ICONS via sketchybar-app-font (__icon_map in icon_map.sh) when EVERY app in a space is mapped, else falls back to text names (shorten_app_name). Subscribes front_app_switched so it repaints on app open, not only on workspace change
- wifi.sh: maps current-link RSSI (helpers/wifi_rssi) → strength bars. wifi_click.sh toggles Wi-Fi power on click
- ram.sh outputs raw GB used (not %); ethernet.sh collapses the icon (icon.drawing=off + zero pad) when disconnected while keeping the item drawing=on so the poller still runs. Bracket lesson (historical): a SketchyBar bracket paints via TWO independent layers — the fill (`background.drawing`) AND the drop shadow (`background.shadow.drawing`) — and the item-level `drawing` flag controls NEITHER; `drawing=off` only FREEZES the bracket geometry at its last width while both layers keep painting (= an empty pill). To hide a bracket, keep it `drawing=on` and toggle BOTH paint layers together (verified via `--query`/`bounding_rects`; learned from the since-removed traffic divisions)
- Edit for: logic of what's displayed, data sources, formatting

`./configs/sketchybar/items/pomodoro.sh`, `./configs/sketchybar/plugins/pomodoro.sh`, `./configs/sketchybar/tests/pomodoro_test.sh`
- Self-contained Pomodoro division: preset-cycle (`45/15` ↔ `60/20`), visible countdown, one play/pause control, one reset control. Only explicit left clicks mutate state
- Controller actions are `sync`, `cycle`, `toggle`, `reset`. Cycle selects the other preset and resets to full work paused; reset preserves the preset and resets to full work paused; toggle starts the current remainder, pauses to `deadline-now`, or performs one paused rollover when clicked at/after expiry
- Runtime state is generated outside the repo at `${XDG_STATE_HOME:-$HOME/.local/state}/sketchybar/pomodoro.state`; its adjacent `.lock` is advisory, not a daemon. State is parsed as data (never sourced): `version=1`, `preset=45_15|60_20`, `phase=work|break`, `status=paused|running`, integer `remaining`, integer absolute Unix `deadline`. Malformed/missing state safely becomes 45/15 full work paused
- State directory is mode 0700; state/lock are 0600. Writes use a same-directory temporary file + atomic `mv`. macOS `/usr/bin/lockf` holds a persistent FD across load → transition → save → one batched four-item render; user actions wait up to two seconds, routine ticks are nonblocking. Notifications run only after lock release
- Running ticks derive display from the absolute deadline and do not rewrite valid state. SketchyBar owns the only 1 Hz scheduling via dynamic `update_freq=1`; paused state sets `update_freq=0`. No Node/Python, LaunchAgent, daemon, or AeroSpace polling is involved
- Boundary policy is deliberately one rollover: work completion → full break paused; break completion → full work paused, including wake/startup after a long sleep. The committed state prevents duplicate notifications; `/usr/bin/osascript` notifications are nonfatal and have no third-party/sound dependency
- Deterministic Bash 3.2 test uses isolated temp state, fake epoch, and SketchyBar/notification stubs. Run: `bash configs/sketchybar/tests/pomodoro_test.sh`

`./configs/vscode/settings.json`
- VSCode editor settings
- Font sizes, formatters, Claude Code config, icon themes
- Minimal UI: statusBar=hidden, activityBar=hidden, minimap=off
- Edit for: editor preferences, extension configs
