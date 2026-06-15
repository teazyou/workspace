# Repository Index — `~/workspace`

> Centralized macOS environment configuration: app configs, shell setup, helper functions, and install/system scripts. This repo is the **source of truth**; most files are symlinked into the locations each app expects (`repo file ← system path`). See `setup_symlinks.sh` for the canonical wiring.
>
> **KEEP THIS CURRENT:** when you add, move, remove, or rename a file, or change a symlink target, update the matching entry here in the same change.

```
configs/    app configs (aerospace, sketchybar, borders, autoraise, vscode, iterm2)
zsh/        ~/.zshrc + sourced configs and aliases
scripts/    install/system scripts (installs/, git/, checkpoint, obsi)
functions/  shared SH helpers sourced by scripts
logs/       runtime logs + checkpoint state (gitignored)
```

## configs
App configuration; the window-manager stack (aerospace + sketchybar + borders + autoraise) is the most-edited area.
- `configs/guide-window-manager.md` — overview of the aerospace + borders + sketchybar + autoraise setup. *Edit when: documenting WM behavior.*
- `configs/aerospace/aerospace.toml` — AeroSpace tiling WM config (workspaces, keybindings, gaps) — `← ~/.aerospace.toml`. *Edit when: changing window-manager keybindings/layout. Run `aerospace reload-config` after.*
- `configs/aerospace/*.plist` — LaunchAgents: `com.aerospace.display-profile.plist` (`← ~/Library/LaunchAgents/`, auto gap profile per display) and `com.aerospace.empty-watcher.plist` (`← ~/Library/LaunchAgents/`, empty-workspace daemon).
- `configs/aerospace/*.sh` — WM helper scripts run by aerospace/LaunchAgents: `apply-display-profile.sh`, `empty-workspace-watcher.sh`, `open-dock-app.sh`, `performance-mode.sh`, `secondary-bar-toggle.sh`, `track-workspace-mru.sh`.
- `configs/aerospace/doc.aerospace.md`, `features.aerospace.md` — AeroSpace reference/feature notes.
- `configs/sketchybar/sketchybarrc` — status-bar entry point (sources colors/icons, loads items + plugins) — dir `← ~/.config/sketchybar`. *Edit when: changing the status bar.*
- `configs/sketchybar/colors.sh`, `icons.sh` — shared palette and icon glyphs.
- `configs/sketchybar/items/*.sh` — one bar item definition per file (spaces, front_app, battery, wifi, etc.).
- `configs/sketchybar/plugins/*.sh` — update/event scripts backing the items; `icon_map.sh` maps apps to glyphs.
- `configs/borders/bordersrc` — JankyBorders window-border config — dir `← ~/.config/borders`.
- `configs/autoraise/config` — AutoRaise focus-follows-mouse tuning — `← ~/.config/AutoRaise/config` (also lowercase `autoraise/`). *Edit when: tuning rest-to-focus / poll timing.*
- `configs/autoraise/com.autoraise.daemon.plist` — AutoRaise LaunchAgent — `← ~/Library/LaunchAgents/`.
- `configs/vscode/settings.json` — VS Code user settings — `← ~/Library/Application Support/Code/User/settings.json`.
- `configs/iterm2/com.googlecode.iterm2.plist` — iTerm2 prefs (manual export/import; not symlinked).
- `configs/dot-obsidian/` — central Obsidian config (plugins, snippets, hotkeys, appearance, *.json settings). Not symlinked as a whole; the `obsi` launcher (`scripts/obsi`) plants per-file symlinks from each vault's `.obsidian/` to entries here. Per-vault runtime state (workspace.json, graph.json, file-recovery/, cache/, .trash/) is gitignored — see `.gitignore`.

## zsh
Shell setup; `zshrc.zsh` is the entry point that sources everything else.
- `zsh/zshrc.zsh` — `~/.zshrc` source-of-truth; sources every config + alias below — `← ~/.zshrc`. *Edit when: changing what loads at shell startup.*
- `zsh/configs/path.zsh` — exports `WORKSPACE`/`SCRIPTS`/`ZSH_*` path vars used everywhere. *Edit when: adding a new sourced dir or PATH entry.*
- `zsh/configs/*.zsh` — startup configs: `colors.zsh`, `oh-my-zsh.zsh` (theme/plugins), `git.zsh`, `nvm.zsh`, `iterm2.zsh`.
- `zsh/alias/*.zsh` — alias groups by topic: `osx.zsh`, `navigation.zsh`, `obsidian.zsh` (the `obsi` vault launcher → `scripts/obsi`), `git.zsh`, `installations.zsh`, `checkpoint.zsh`. *Edit when: adding a terminal alias.*

## scripts
Install, git, system, and checkpoint scripts.
- `scripts/installs/bootstrap.sh` — fresh-Mac entry point (CLT, Homebrew, git, clone repo) then hands off to `installation.sh`. Run remotely via curl one-liner (see file header).
- `scripts/installs/installation.sh` — install orchestrator; runs every other `install_*`/`setup_*` step in order, idempotently. *Edit when: adding/removing an install step.*
- `scripts/installs/setup_symlinks.sh` — creates all repo→system symlinks (the canonical map). *Edit when: adding/changing any symlink target.*
- `scripts/installs/install_*.sh` — one installer per tool/area (brew, node, claude, iterm2, vscode_ext, oh_my_zsh, database, touch_id_sudo, xcode_mas, window_manager, checkpoint_launchd).
- `scripts/installs/setup_macos.sh`, `setup_wallpaper.sh`, `clone_repos.sh` — macOS defaults, wallpaper, and repo cloning steps.
- `scripts/installs/helper_prompt.sh` — `log_*` color/prompt helpers sourced by install scripts.
- `scripts/git/g*.sh` — git workflow helpers (`gcommit`, `gcreate`, `gdelete`, `gpush`, `gstatus`); fronted by `zsh/alias/git.zsh`.
- `scripts/checkpoint_cronjob.sh` — LaunchAgent entry: auto-commits tracked repos on a schedule, logs to `logs/`. Invoked by `~/Library/LaunchAgents/com.teazyou.checkpoint.plist` (real file, not symlinked).
- `scripts/checkpoint_all.sh`, `checkpoint_functions.sh` — manual checkpoint runner + shared logic; `CHECKPOINT_FOLDERS` lists watched repos (`~/workspace`, `~/secondbrain`). *Edit when: changing which repos auto-checkpoint.*
- `scripts/aerospace-restart.sh` — full restart of the WM stack (aerospace, sketchybar, borders, LaunchAgents).
- `scripts/dstore.sh` — recursively delete `.DS_Store` files; used by the git scripts (`silent` mode).
- `scripts/obsi` — Obsidian vault launcher: opens a folder as a vault, planting per-file symlinks from its `.obsidian/` to the central `configs/dot-obsidian` config. Fronted by `zsh/alias/obsidian.zsh` (`obsi [folder]`). *Edit when: changing which central entries are shared (BLACKLIST) or the open mechanism.*

## functions
Shared SH helpers sourced by other scripts.
- `functions/brew.sh` — idempotent `brew` install/tap wrappers used by `scripts/installs/install_brew.sh`.

## Optional / low-touch
- `logs/` — runtime output, gitignored except `.gitkeep`: `checkpoint_cron.log`, `checkpoint_launchd.{out,err}.log`, `checkpoint_state/*.sig` (per-repo content fingerprints).
- `.claude/CLAUDE.md` — project instructions for Claude (intended purpose, constraints).
- `.gitignore` — ignores `.DS_Store`, `*.bak`, `logs/*`, install idempotency markers, and the scoped `configs/dot-obsidian/` per-vault runtime state (workspace.json, graph.json, file-recovery/, cache/, .trash/). *(Per-config `.gitignore` files are not used; rules are consolidated here.)*
- `request.md` — scratch/throwaway note (not part of the config system).
