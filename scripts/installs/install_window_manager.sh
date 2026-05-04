#!/bin/bash
# scripts/installs/install_window_manager.sh
#
# Purpose:
#   Brings up the AeroSpace + SketchyBar + JankyBorders stack so it
#   starts at login and survives reboots.
#
# Architecture (matches the existing user setup, see configs/aerospace/aerospace.toml):
#   - AeroSpace launches itself at login (`start-at-login = true`)
#   - AeroSpace's `after-startup-command` runs sketchybar and borders for us
#   - The display-profile LaunchAgent polls every 5s and tweaks gaps when
#     monitors connect/disconnect
#
#   So the "service management" we need is just:
#     1. Make sure AeroSpace is running (it will start the others)
#     2. Make sure the display-profile LaunchAgent is loaded
#
#   We deliberately do NOT use `brew services start` for sketchybar/borders.
#   That would race against AeroSpace's own startup command and leave
#   them flapping in an "error" state in brew services list.
#
# Idempotent: process and launchctl checks short-circuit when already up.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

# --- 1. AeroSpace -------------------------------------------------------
# AeroSpace is a regular .app installed via brew cask. Launching it once
# is enough — `start-at-login = true` in aerospace.toml takes care of
# every subsequent boot.
log_step "AeroSpace"
if pgrep -xq AeroSpace; then
    log_ok "AeroSpace already running"
else
    if [[ ! -d "/Applications/AeroSpace.app" ]]; then
        log_err "AeroSpace.app missing in /Applications — was install_brew.sh run?"
        exit 1
    fi
    log_wait "Launching AeroSpace.app for the first time ..."
    open -a AeroSpace
    # Give it a moment to come up + run after-startup-command (sketchybar, borders).
    sleep 3
    log_ok "AeroSpace launched (menu-bar icon should appear)"
fi

# --- 2. Sketchybar + Borders (sanity check) -----------------------------
# AeroSpace's after-startup-command launches these. We just verify they
# came up — if they didn't, something is wrong with the aerospace config.
log_step "SketchyBar / Borders (launched by AeroSpace)"
if pgrep -xq sketchybar; then
    log_ok "sketchybar running"
else
    log_err "sketchybar NOT running — check aerospace.toml after-startup-command"
fi
if pgrep -xq borders; then
    log_ok "borders running"
else
    log_err "borders NOT running — check aerospace.toml after-startup-command"
fi

# --- 3. AeroSpace display-profile LaunchAgent ---------------------------
# Workspace-specific LaunchAgent that runs apply-display-profile.sh every
# 5 seconds. The plist itself was symlinked into ~/Library/LaunchAgents
# by setup_symlinks.sh.
log_step "AeroSpace display-profile LaunchAgent"
PLIST="$HOME/Library/LaunchAgents/com.aerospace.display-profile.plist"
LABEL="com.aerospace.display-profile"
UID_=$(id -u)

if [[ ! -e "$PLIST" ]]; then
    log_err "LaunchAgent symlink missing: $PLIST (setup_symlinks.sh should have created it)"
    exit 1
fi

if launchctl print "gui/$UID_/$LABEL" &>/dev/null; then
    log_ok "$LABEL already loaded"
else
    log_wait "Loading $LABEL into launchd ..."
    launchctl bootstrap "gui/$UID_" "$PLIST"
    log_ok "$LABEL loaded"
fi

log_ok "Window-manager stack up"
