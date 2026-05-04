#!/bin/bash
# scripts/installs/setup_macos.sh
#
# Purpose:
#   Applies system-wide macOS defaults to match the workspace setup.
#
#   These are all reversible (`defaults delete`) and only affect the
#   current user. They roughly match what's already configured on the
#   source machine.
#
# Categories:
#   - Finder    : show path bar, status bar, hidden files
#   - Keyboard  : fast key repeat, disable press-and-hold accents
#   - Dock      : auto-hide, smaller tile size
#   - Screenshots: ~/Pictures/Screenshots, png format
#   - Appearance: dark mode
#   - Save panels: expanded by default (so you see the full file picker)
#   - .DS_Store : disable on network/USB volumes
#
# After writing, restarts Finder + Dock so changes take effect immediately.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

log_step "macOS defaults"

# --- Finder -------------------------------------------------------------
log_wait "Finder: show path bar, status bar, hidden files"
defaults write com.apple.finder ShowPathbar       -bool true
defaults write com.apple.finder ShowStatusBar     -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true

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

# --- Dock ---------------------------------------------------------------
# AeroSpace tiles your windows, so the Dock is mostly out of the way.
log_wait "Dock: auto-hide, tile size 36"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int  36

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
