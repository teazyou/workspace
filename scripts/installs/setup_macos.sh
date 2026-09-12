#!/bin/bash
# scripts/installs/setup_macos.sh
#
# Purpose:
#   Applies system-wide macOS defaults to match the workspace setup.
#
#   These affect only the current user. Captured keys have scoped backups;
#   the existing baseline settings below retain their original behavior.
#
# Categories:
#   - Finder    : path/status/hidden files, list view, Recents for new windows
#   - Keyboard  : fast key repeat, disable press-and-hold accents
#   - Dock      : captured size 52, behavior, ordered portable apps + Downloads
#   - Shortcuts/input sources: see configs/macos/preferences.json and helper notices
#   - Screenshots: ~/Pictures/Screenshots, png format
#   - Appearance: dark mode
#   - Save panels: expanded by default (so you see the full file picker)
#   - .DS_Store : disable on network/USB volumes
#
# After writing, restarts Finder + Dock so changes take effect immediately.

set -e

# shellcheck source=/dev/null
INSTALLS="${INSTALLS:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
source "$INSTALLS/helper_prompt.sh"

log_step "macOS defaults"

# --- Captured portable preferences --------------------------------------
# CFPreferences merges only managed keys; the Swift helper keeps private,
# scoped before-values and uses public TIS APIs for enabled input sources.
# CLT (from bootstrap) supplies Swift. This stage runs after app installation.
log_wait "Restore captured Finder, Dock (52), shortcuts, and input sources"
xcrun swift "$INSTALLS/apply_macos.swift" "$APP_CONFIGS/macos/preferences.json"

# --- Keyboard -----------------------------------------------------------
# KeyRepeat=2 is the fastest non-zero rate; InitialKeyRepeat=15 is the
# shortest delay before repeat kicks in. Press-and-hold disabled so
# holding a vowel types repeats instead of opening the accent palette.
log_wait "Keyboard: fast key repeat, disable press-and-hold accents"
defaults write NSGlobalDomain KeyRepeat              -int 2
defaults write NSGlobalDomain InitialKeyRepeat       -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# --- Screenshots --------------------------------------------------------
log_wait "Screenshots: location → ~/Pictures/Screenshots, format → png"
mkdir -p "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture location "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture type     -string "png"

# --- Appearance ---------------------------------------------------------
log_wait "Appearance: dark mode"
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"

# --- Save / open panels -------------------------------------------------
log_wait "Save panels: expanded by default"
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode    -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2   -bool true

# --- .DS_Store discipline -----------------------------------------------
log_wait ".DS_Store: disable on network and USB volumes"
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores     -bool true

# --- Apply --------------------------------------------------------------
log_wait "Restarting Finder + Dock to apply changes ..."
killall Finder 2>/dev/null || true
killall Dock   2>/dev/null || true

log_ok "macOS defaults applied"
