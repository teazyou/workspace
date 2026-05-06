#!/bin/bash
# scripts/installs/installation.sh
#
# Purpose:
#   Main orchestrator for the workspace install on a fresh macOS system.
#   bootstrap.sh prepares git/brew and clones the workspace, then `exec`s
#   into this script which runs every other install step in order.
#
#   Each step lives in its own sub-script under scripts/installs/. They
#   are all idempotent — re-running this orchestrator after a partial
#   install will skip finished work and resume from wherever it left off.
#
# Run manually:
#   bash ~/workspace/scripts/installs/installation.sh

set -e

# Export PATH variables used by every sub-script so they don't have to
# guess where the workspace lives.
export WORKSPACE="$HOME/workspace"
export SCRIPTS="$WORKSPACE/scripts"
export FUNCTIONS="$WORKSPACE/functions"
export INSTALLS="$SCRIPTS/installs"
export APP_CONFIGS="$WORKSPACE/configs"

# Source helper functions (colors + prompts).
# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

log_info "Workspace install starting"
log_wait "User: $(whoami)  |  Host: $(hostname)  |  Arch: $(uname -m)"

# Each step is wrapped in log_step() for readable section headings.
# Sub-scripts are invoked via `bash` so that `set -e` failures bubble up
# but don't poison the orchestrator's environment.

log_step "1/15 — Homebrew taps + formulae + casks"
bash "$INSTALLS/install_brew.sh"

log_step "2/15 — Oh-My-Zsh"
bash "$INSTALLS/install_oh_my_zsh.sh"

log_step "3/15 — Symlinks (zshrc, aerospace, borders, sketchybar, vscode)"
bash "$INSTALLS/setup_symlinks.sh"

log_step "4/15 — iTerm2 preferences (custom-folder mode)"
bash "$INSTALLS/install_iterm2.sh"

log_step "5/15 — Claude Desktop + Claude Code (native install)"
bash "$INSTALLS/install_claude.sh"

log_step "6/15 — VSCode extensions"
bash "$INSTALLS/install_vscode_ext.sh"

log_step "7/15 — Touch ID for sudo"
bash "$INSTALLS/install_touch_id_sudo.sh"

log_step "8/15 — macOS defaults"
bash "$INSTALLS/setup_macos.sh"

log_step "9/15 — Wallpaper (solid black)"
bash "$INSTALLS/setup_wallpaper.sh"

log_step "10/15 — Window manager services (sketchybar, borders, aerospace LaunchAgent)"
bash "$INSTALLS/install_window_manager.sh"

log_step "11/15 — Node LTS via NVM"
bash "$INSTALLS/install_node.sh"

log_step "12/15 — MySQL + PostgreSQL initial setup"
bash "$INSTALLS/install_database.sh"

log_step "13/15 — Xcode via mas"
bash "$INSTALLS/install_xcode_mas.sh"

log_step "14/15 — Clone secondbrain + create ~/dev"
bash "$INSTALLS/clone_repos.sh"

log_step "15/15 — Hourly checkpoint cronjob + Full Disk Access for cron"
bash "$INSTALLS/install_checkpoint_cronjob.sh"

log_info "All done"
log_ok "Workspace install complete. Open a new iTerm2 window to load the new shell."
log_ok "Tip: run 'reload' inside zsh to re-source ~/.zshrc at any time."
