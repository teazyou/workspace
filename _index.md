# Repository Index — `~/workspace`

> Centralized macOS environment configuration: app configs, shell setup, helper functions, and install/system scripts. This repo is the **source of truth**; most files are symlinked into the locations each app expects (`repo file ← system path`). See `setup_symlinks.sh` for the canonical wiring.
>
> **KEEP THIS CURRENT:** when you add, move, remove, or rename a file, or change a symlink target, update the matching entry here in the same change.

```
configs/    app configs (aerospace, sketchybar, borders, autoraise, vscode, iterm2)
zsh/        ~/.zshrc + sourced configs and aliases
scripts/    install/system scripts (installs/, git/, checkpoint, obsi)
functions/  shared SH helpers sourced by scripts
prompts/    reusable copy-paste Claude prompts (workflow launchers)
logs/       runtime logs + checkpoint state (gitignored)
```

## configs
App configuration; the window-manager stack (aerospace + sketchybar + borders + autoraise) is the most-edited area.
- `configs/guide-window-manager.md` — overview of the aerospace + borders + sketchybar + autoraise setup. *Read before and after Editing when: documenting window manager behavior.*
- `configs/aerospace/aerospace.toml` — AeroSpace tiling WM config (workspaces, keybindings, gaps) — `← ~/.aerospace.toml`. *Edit when: changing window-manager keybindings/layout. Run `aerospace reload-config` after.*
- `configs/aerospace/*.plist` — LaunchAgents: `com.aerospace.display-profile.plist` (`← ~/Library/LaunchAgents/`, auto gap profile per display) and `com.aerospace.empty-watcher.plist` (`← ~/Library/LaunchAgents/`, empty-workspace daemon).
- `configs/aerospace/*.sh` — WM helper scripts run by aerospace/LaunchAgents: `apply-display-profile.sh` (auto top-gaps **and** the workspace 7-9 monitor assignment — flips between `'built-in.*'` and `'secondary'` per which display is main, so home/travel both work), `empty-workspace-watcher.sh`, `open-dock-app.sh`, `performance-mode.sh`, `secondary-bar-toggle.sh`, `track-workspace-mru.sh`.
- `configs/aerospace/doc.aerospace.md`, `features.aerospace.md` — AeroSpace reference/feature notes.
- `configs/sketchybar/sketchybarrc` — status-bar entry point (sources colors/icons/theme, loads items + plugins) — dir `← ~/.config/sketchybar`. *Edit when: changing the status bar.*
- `configs/sketchybar/colors.sh`, `icons.sh` — shared palette and icon glyphs.
- `configs/sketchybar/theme.sh` — **visual template / single source of truth** for "division" geometry (corner radius, border, blur, drop shadow, inter-division gap). Sourced by sketchybarrc before items; every bracket on both sides, in normal + performance mode, pulls from these tokens. *Edit when: restyling the bar's overall pill/division look (radius, shadow, spacing).*
- `configs/sketchybar/items/*.sh` — one bar item definition per file (spaces, front_app, battery, wifi, etc.).
- `configs/sketchybar/plugins/*.sh` — update/event scripts backing the items; `icon_map.sh` maps apps to glyphs.
- `configs/borders/bordersrc` — JankyBorders window-border config — dir `← ~/.config/borders`.
- `configs/autoraise/config` — AutoRaise focus-follows-mouse tuning — `← ~/.config/AutoRaise/config` (also lowercase `autoraise/`). *Edit when: tuning rest-to-focus / poll timing.*
- `configs/autoraise/com.autoraise.daemon.plist` — AutoRaise LaunchAgent — `← ~/Library/LaunchAgents/`.
- `configs/vscode/settings.json` — VS Code user settings — `← ~/Library/Application Support/Code/User/settings.json`. *Read `configs/vscode/guide-transparency.md` before editing theme/colour/transparency settings.*
- `configs/vscode/guide-transparency.md` — how the see-through VS Code look works: the Vibrancy Continued extension, the `type:"transparent"` + `forceFramelessWindow` settings that enable true (non-blurred) transparency, the layered alpha model, and the Claude Code panel (`sideBar.background`) + command-palette widget fixes. *Read before and after editing when: changing VS Code theme/colour/transparency settings.*
- `configs/vscode/custom.css` — custom workbench CSS injected by Vibrancy Continued via `vscode_vibrancy.imports` in settings.json (no Custom-CSS extension needed). Used for things VS Code has no native setting for — currently the 4px bright-red active-tab accent bar. *Edit when: tweaking the injected CSS; run "Reload Vibrancy" after. Documented in guide-transparency.md.*
- `configs/vscode/guide-claude-code.md` — all visual customizations to the **Claude Code chat panel** (grey chat boxes, floating/sticky message compaction, full-width input, compact spacing, shrunk toolbar) + a one-command script to re-apply them. These edits live in the extension's `~/.vscode/extensions/anthropic.claude-code-*/webview/index.css` (a webview iframe, unreachable from settings.json/custom.css) and are **lost on every Claude Code update** — the script reproduces them. *Edit when: changing the Claude Code panel look, or after a Claude Code update wipes the patches.*
- `configs/iterm2/com.googlecode.iterm2.plist` — iTerm2 prefs (manual export/import; not symlinked).
- `configs/dot-obsidian/` — central Obsidian config (plugins, snippets, hotkeys, appearance, *.json settings). Not symlinked as a whole; the `obsi` launcher (`scripts/obsi`) plants per-file symlinks from each vault's `.obsidian/` to entries here. Per-vault runtime state (workspace.json, graph.json, file-recovery/, cache/, .trash/) is gitignored — see `.gitignore`.
- `configs/dot-claude/` — **private git submodule** (`https://github.com/teazyou/dot-claude.git`) that **is** `~/.claude` (Claude Code): on each machine `~/.claude` is a whole-folder **symlink** → `configs/dot-claude`, so everything Claude Code writes lands in this submodule. Allowlist-style `.gitignore` (ignore-all + re-allow `settings.json`, `CLAUDE.md`, `keybindings.json`, and the `agents/ commands/ skills/ output-styles/ workflows/ hooks/` dirs; credential denylist) commits only safe config — all runtime/secret data (`projects/`, `sessions/`, `history.jsonl`, …) physically lives here but is gitignored. Secrets are protected three ways: gitignored, private repo, and a mirrored defensive allowlist for `configs/dot-claude/` in this repo's root `.gitignore` (active only if it ever stops being a submodule). *Edit when: changing which `~/.claude` config is backed up or the allowlist; keep the two allowlists in sync. On a fresh Mac this is wired by `scripts/installs/setup_dot_claude.sh`.*

## zsh
Shell setup; `zshrc.zsh` is the entry point that sources everything else.
- `zsh/zshrc.zsh` — `~/.zshrc` source-of-truth; sources every config + alias below — `← ~/.zshrc`. *Edit when: changing what loads at shell startup.*
- `zsh/configs/path.zsh` — exports `WORKSPACE`/`SCRIPTS`/`ZSH_*` path vars used everywhere. *Edit when: adding a new sourced dir or PATH entry.*
- `zsh/configs/*.zsh` — startup configs: `colors.zsh`, `oh-my-zsh.zsh` (theme/plugins), `git.zsh`, `nvm.zsh`, `iterm2.zsh`.
- `zsh/alias/*.zsh` — alias groups by topic: `osx.zsh`, `navigation.zsh`, `obsidian.zsh` (the `obsi` vault launcher → `scripts/obsi`), `git.zsh`, `installations.zsh`, `checkpoint.zsh`, `wallpapers.zsh` (the `wallpapers-treatment` launcher → `scripts/wallpapers_treatment.sh`). *Edit when: adding a terminal alias.*

## scripts
Install, git, system, and checkpoint scripts.
- `scripts/installs/bootstrap.sh` — fresh-Mac entry point (CLT, Homebrew, git, clone repo) then hands off to `installation.sh`. Run remotely via curl one-liner (see file header).
- `scripts/installs/installation.sh` — install orchestrator; runs every other `install_*`/`setup_*` step in order, idempotently. *Edit when: adding/removing an install step.*
- `scripts/installs/setup_symlinks.sh` — creates all repo→system symlinks (the canonical map). *Edit when: adding/changing any symlink target.*
- `scripts/installs/install_*.sh` — one installer per tool/area (brew, node, claude, iterm2, vscode_ext, oh_my_zsh, database, touch_id_sudo, xcode_mas, window_manager, checkpoint_launchd).
- `scripts/installs/setup_macos.sh`, `setup_wallpaper.sh`, `clone_repos.sh` — macOS defaults, wallpaper, and repo cloning steps.
- `scripts/installs/setup_dot_claude.sh` — fresh-machine step (runs after `clone_repos.sh`, once `gh` is authenticated): `gh auth setup-git` → `git submodule update --init configs/dot-claude` (the PRIVATE submodule) → symlink `~/.claude → configs/dot-claude` (backing up any real `~/.claude` to a timestamped `~/.claude.bak.<ts>`, never deleting it). Idempotent. *Edit when: changing how `~/.claude` is wired on a new Mac.*
- `scripts/installs/helper_prompt.sh` — `log_*` color/prompt helpers sourced by install scripts.
- `scripts/git/g*.sh` — git workflow helpers (`gcommit`, `gcreate`, `gdelete`, `gpush`, `gstatus`); fronted by `zsh/alias/git.zsh`.
- `scripts/checkpoint_cronjob.sh` — LaunchAgent entry: auto-commits tracked repos on a schedule, logs to `logs/`. Invoked by `~/Library/LaunchAgents/com.teazyou.checkpoint.plist` (real file, not symlinked).
- `scripts/checkpoint_all.sh`, `checkpoint_functions.sh` — manual checkpoint runner + shared logic; `CHECKPOINT_FOLDERS` lists watched repos (`~/workspace/configs/dot-claude` (submodule, listed first so it commits before the parent gitlink), `~/workspace`, `~/secondbrain`). *Edit when: changing which repos auto-checkpoint.*
- `scripts/aerospace-restart.sh` — full restart of the WM stack (aerospace, sketchybar, borders, LaunchAgents).
- `scripts/wallpapers_treatment.sh` — batch-applies an ImageMagick "profile" (e.g. `blur-4`) to every wallpaper under `~/gdrive/wallpapers/originals/<category>/`, writing processed copies into `~/gdrive/wallpapers/modified/<profile-name>/<profile-name>-<category>/` (originals never modified; idempotent — skips already-processed images). `originals/` is the source of truth: a clean pass first prunes `modified/` to mirror it (removes any profile subfolder/image whose original is gone, even for profiles no longer in the array). Failed conversions are retried up to 3 rounds. Self-installs ImageMagick via Homebrew if missing. Profiles are an array at the top of the file (`"<name>|<magick options>"`); fronted by `zsh/alias/wallpapers.zsh` (`wallpapers-treatment <profile-name>`). Bash 3.2-compatible. *Edit when: adding/changing a profile.*
- `scripts/dstore.sh` — recursively delete `.DS_Store` files; used by the git scripts (`silent` mode).
- `scripts/obsi` — Obsidian vault launcher: opens a folder as a vault, planting per-file symlinks from its `.obsidian/` to the central `configs/dot-obsidian` config. Fronted by `zsh/alias/obsidian.zsh` (`obsi [folder]`). *Edit when: changing which central entries are shared (BLACKLIST) or the open mechanism.*
## functions
Shared SH helpers sourced by other scripts.
- `functions/brew.sh` — idempotent `brew` install/tap wrappers used by `scripts/installs/install_brew.sh`.

## prompts
Reusable copy-paste Claude prompts; not sourced by anything — saved so a task can be re-launched verbatim in a fresh session.
- `prompts/workflow/window-manager-code-review.md` — paste-prompt that launches the multi-agent dynamic Workflow (study → review → plan → coherence → implement → verify → report) over the window-manager config stack. Its first step is a **study** agent (Opus, xhigh) that reads `guide-window-manager.md` (and the config folders) and returns the config-unit and lens lists (also written to `_spec/workflow-spec.json` as an artifact); the Workflow then fans out the fixed split strategy (one sub-agent per config-unit × lens) over those lists at runtime — one self-contained autonomous run. All artifacts go to a freshly-recreated `./window-manager-code-review/` at the repo root. *Edit when: changing the review pipeline's steps/units/lenses.*

## Optional / low-touch
- `logs/` — runtime output, gitignored except `.gitkeep`: `checkpoint_cron.log`, `checkpoint_launchd.{out,err}.log`, `checkpoint_state/*.sig` (per-repo content fingerprints).
- `.claude/CLAUDE.md` — project instructions for Claude (intended purpose, constraints).
- `.gitignore` — ignores `.DS_Store`, `*.bak`, `logs/*`, install idempotency markers, and the scoped `configs/dot-obsidian/` per-vault runtime state (workspace.json, graph.json, file-recovery/, cache/, .trash/). *(Per-config `.gitignore` files are not used; rules are consolidated here.)*
- `request.md` — scratch/throwaway note (not part of the config system).
