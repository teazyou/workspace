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
#   ~/.config/borders                              → workspace/configs/borders
#   ~/.config/sketchybar                           → workspace/configs/sketchybar
#   ~/Library/Application Support/Code/User/settings.json
#                                                  → workspace/configs/vscode/settings.json
#
# Safety:
#   - If the target is already a symlink, we preserve it before replacement.
#   - If the target is a real file/folder, we move it into a unique <name>.bak.XXXXXX directory.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

# Replace whatever currently lives at $target with a symlink to $source.
# Pre-existing real files/folders are backed up to <name>.bak.XXXXXX/original.
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

    # Retain both wrong links and real files in a unique private directory.
    if [[ -e "$target" || -L "$target" ]]; then
        local backup
        backup=$(mktemp -d "$target.bak.XXXXXX")
        log_wait "$name: preserving existing target → $backup/original"
        if [[ -L "$target" ]]; then log_wait "$name: prior link → $(readlink "$target")"; fi
        mv "$target" "$backup/original"
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
