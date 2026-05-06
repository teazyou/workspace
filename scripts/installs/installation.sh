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

# Each step is wrapped in next_step() for readable section headings.
# Sub-scripts are invoked via `bash` so that `set -e` failures bubble up
# but don't poison the orchestrator's environment.
#
# next_step auto-numbers steps as "N/TOTAL — title". TOTAL is computed by
# grepping this very file for `next_step` calls, so adding/removing a step
# just means editing its own line — no other numbers need updating.
TOTAL_STEPS=$(grep -c '^next_step ' "${BASH_SOURCE[0]}")
STEP=0
next_step() {
    STEP=$((STEP + 1))
    log_step "$STEP/$TOTAL_STEPS — $1"
}

next_step "Homebrew taps + formulae + casks"
bash "$INSTALLS/install_brew.sh"

next_step "Oh-My-Zsh"
bash "$INSTALLS/install_oh_my_zsh.sh"

next_step "Symlinks (zshrc, aerospace, borders, sketchybar, vscode)"
bash "$INSTALLS/setup_symlinks.sh"

next_step "iTerm2 preferences (custom-folder mode)"
bash "$INSTALLS/install_iterm2.sh"

next_step "Claude Desktop + Claude Code (native install)"
bash "$INSTALLS/install_claude.sh"

next_step "VSCode extensions"
bash "$INSTALLS/install_vscode_ext.sh"

next_step "Touch ID for sudo"
bash "$INSTALLS/install_touch_id_sudo.sh"

next_step "macOS defaults"
bash "$INSTALLS/setup_macos.sh"

next_step "Wallpaper (solid black)"
bash "$INSTALLS/setup_wallpaper.sh"

next_step "Window manager services (sketchybar, borders, aerospace LaunchAgent)"
bash "$INSTALLS/install_window_manager.sh"

next_step "Node LTS via NVM"
bash "$INSTALLS/install_node.sh"

next_step "MySQL + PostgreSQL initial setup"
bash "$INSTALLS/install_database.sh"

next_step "Xcode via mas"
bash "$INSTALLS/install_xcode_mas.sh"

next_step "Clone secondbrain + create ~/dev"
bash "$INSTALLS/clone_repos.sh"

next_step "Obsidian iCloud setup (move ~/secondbrain to iCloud, hide .git)"
bash "$INSTALLS/obsidian_setup.sh"

next_step "Hourly checkpoint cronjob + Full Disk Access for cron"
bash "$INSTALLS/install_checkpoint_cronjob.sh"

log_info "All done"
log_ok "Workspace install complete. Open a new iTerm2 window to load the new shell."
log_ok "Tip: run 'reload' inside zsh to re-source ~/.zshrc at any time."
