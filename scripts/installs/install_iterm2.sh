#!/bin/bash
# scripts/installs/install_iterm2.sh
#
# Purpose:
#   Wire iTerm2 to load its preferences from a workspace folder, so the
#   config travels with the repo instead of living only in macOS prefs.
#
# How it works:
#   iTerm2 supports a built-in feature called "Load preferences from a
#   custom folder or URL" (Preferences → General → Preferences). When set,
#   it reads/writes its plist to that folder instead of the default
#   ~/Library/Preferences/com.googlecode.iterm2.plist.
#
#   We point it at $WORKSPACE/configs/iterm2/. The repo already ships a
#   captured plist (com.googlecode.iterm2.plist) so a fresh install will
#   pick it up on first launch.
#
# Important:
#   iTerm2 must NOT be running when these defaults are written, otherwise
#   it will overwrite the file on quit. The script will pause and ask the
#   user to quit iTerm2 if it's currently open.
#
# Idempotent: if the custom-folder setting is already set correctly, skip.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

CUSTOM_DIR="$APP_CONFIGS/iterm2"
PLIST_NAME="com.googlecode.iterm2.plist"

# 1. Sanity checks -------------------------------------------------------
if [[ ! -d "$CUSTOM_DIR" ]]; then
    log_err "iTerm2 config folder missing: $CUSTOM_DIR"
    exit 1
fi
if [[ ! -f "$CUSTOM_DIR/$PLIST_NAME" ]]; then
    log_err "iTerm2 plist missing inside config folder: $CUSTOM_DIR/$PLIST_NAME"
    exit 1
fi

# 2. Already configured? -------------------------------------------------
CURRENT_FOLDER=$(defaults read com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null || echo "")
CURRENT_LOAD=$(defaults read com.googlecode.iterm2 LoadPrefsFromCustomFolder 2>/dev/null || echo "0")

if [[ "$CURRENT_FOLDER" == "$CUSTOM_DIR" && "$CURRENT_LOAD" == "1" ]]; then
    log_ok "iTerm2 already configured to load prefs from $CUSTOM_DIR"
    exit 0
fi

# 3. Make sure iTerm2 is not running ------------------------------------
# When iTerm2 quits it writes its current in-memory state back to the
# plist — this would clobber the version in the repo.
if pgrep -xq "iTerm2"; then
    log_wait "iTerm2 is currently running. We need it closed before configuring custom prefs."
    prompt_command "Please quit iTerm2 (⌘Q) so the new prefs path takes effect cleanly." \
                   "osascript -e 'quit app \"iTerm2\"'"
fi

# 4. Write the defaults --------------------------------------------------
log_wait "Setting iTerm2 PrefsCustomFolder → $CUSTOM_DIR"
defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$CUSTOM_DIR"

log_wait "Enabling LoadPrefsFromCustomFolder"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true

log_ok "iTerm2 will now load preferences from $CUSTOM_DIR on next launch"
