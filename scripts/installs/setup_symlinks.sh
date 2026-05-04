#!/bin/bash
# scripts/installs/setup_symlinks.sh
#
# Purpose:
#   Creates the symlinks that wire workspace config files to the locations
#   each app expects them in. The workspace folder is the source of truth;
#   every config below is a link pointing into it.
#
# Symlink map:
#   ~/.zshrc                                       → workspace/zsh/zshrc.zsh
#   ~/.aerospace.toml                              → workspace/configs/aerospace/aerospace.toml
#   ~/Library/LaunchAgents/com.aerospace.display-profile.plist
#                                                  → workspace/configs/aerospace/com.aerospace.display-profile.plist
#   ~/.config/borders                              → workspace/configs/borders
#   ~/.config/sketchybar                           → workspace/configs/sketchybar
#   ~/Library/Application Support/Code/User/settings.json
#                                                  → workspace/configs/vscode/settings.json
#
# Safety:
#   - If the target is already a symlink, we replace it.
#   - If the target is a real file/folder, we move it aside to <name>.bak.<ts>.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

# Replace whatever currently lives at $target with a symlink to $source.
# Pre-existing real files/folders are backed up to <name>.bak.<unix-ts>.
make_link() {
    local source=$1
    local target=$2
    local name=$3

    if [[ ! -e "$source" ]]; then
        log_err "$name: source missing → $source"
        return 1
    fi

    # Already correct → no-op
    if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
        log_ok "$name: already linked"
        return 0
    fi

    # Wrong link → just remove it
    if [[ -L "$target" ]]; then
        log_wait "$name: replacing existing symlink"
        rm "$target"
    # Real file/folder → back up
    elif [[ -e "$target" ]]; then
        local backup="$target.bak.$(date +%s)"
        log_wait "$name: backing up existing file → $backup"
        mv "$target" "$backup"
    fi

    mkdir -p "$(dirname "$target")"
    ln -s "$source" "$target"
    log_ok "$name: linked → $target"
}

log_step "Symlinks"

# --- shell ---
make_link "$WORKSPACE/zsh/zshrc.zsh" \
          "$HOME/.zshrc" \
          "ZSHRC"

# --- aerospace ---
make_link "$APP_CONFIGS/aerospace/aerospace.toml" \
          "$HOME/.aerospace.toml" \
          "AEROSPACE-CONFIG"

make_link "$APP_CONFIGS/aerospace/com.aerospace.display-profile.plist" \
          "$HOME/Library/LaunchAgents/com.aerospace.display-profile.plist" \
          "AEROSPACE-LAUNCHAGENT"

# --- borders / sketchybar ---
make_link "$APP_CONFIGS/borders" \
          "$HOME/.config/borders" \
          "BORDERS"

make_link "$APP_CONFIGS/sketchybar" \
          "$HOME/.config/sketchybar" \
          "SKETCHYBAR"

# --- vscode ---
make_link "$APP_CONFIGS/vscode/settings.json" \
          "$HOME/Library/Application Support/Code/User/settings.json" \
          "VSCODE-SETTINGS"

log_ok "Symlinks done"
