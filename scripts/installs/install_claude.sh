#!/bin/bash
# scripts/installs/install_claude.sh
#
# Purpose:
#   Native (non-brew) install of:
#     1. Claude Desktop  — via the official .dmg from claude.ai
#     2. Claude Code CLI — via the official curl-piped installer
#
#   Native install is preferred over `brew install --cask claude` because
#   the brew cask sometimes lags the official release channel and the
#   updates can be unstable.
#
# Idempotent:
#   - Claude Desktop: skipped if /Applications/Claude.app exists
#   - Claude Code:    skipped if `claude` is already on PATH

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

# --- 1. Claude Desktop --------------------------------------------------
log_step "Claude Desktop"

if [[ -d "/Applications/Claude.app" ]]; then
    log_ok "Claude Desktop already installed"
else
    DMG_URL="https://claude.ai/api/desktop/darwin/universal/dmg/latest/redirect"
    DMG_PATH="/tmp/claude-desktop.dmg"

    log_wait "Downloading Claude Desktop .dmg ..."
    curl -fL -o "$DMG_PATH" "$DMG_URL"

    log_wait "Mounting .dmg ..."
    # `hdiutil attach` prints the mount point on the last line of stdout;
    # we capture it so we don't have to hardcode the volume name.
    MOUNT_POINT=$(hdiutil attach "$DMG_PATH" -nobrowse -quiet \
        | tail -1 \
        | awk -F'\t' '{print $NF}' \
        | sed 's/^ *//')

    if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
        log_err "Could not detect dmg mount point"
        exit 1
    fi

    # Find the .app inside the mounted volume (name may vary slightly
    # across releases — "Claude.app" / "Claude Desktop.app").
    APP_PATH=$(find "$MOUNT_POINT" -maxdepth 1 -name "*.app" -print -quit)
    if [[ -z "$APP_PATH" ]]; then
        log_err "No .app found in mounted dmg ($MOUNT_POINT)"
        hdiutil detach "$MOUNT_POINT" -quiet || true
        exit 1
    fi

    log_wait "Copying $(basename "$APP_PATH") to /Applications ..."
    cp -R "$APP_PATH" /Applications/

    log_wait "Detaching dmg ..."
    hdiutil detach "$MOUNT_POINT" -quiet
    rm -f "$DMG_PATH"

    # Strip the Gatekeeper quarantine flag so the app opens without
    # macOS prompting "downloaded from the internet" on first launch.
    xattr -dr com.apple.quarantine "/Applications/$(basename "$APP_PATH")" 2>/dev/null || true

    log_ok "Claude Desktop installed → /Applications/$(basename "$APP_PATH")"
fi

# --- 2. Claude Code CLI -------------------------------------------------
log_step "Claude Code CLI"

if command -v claude &>/dev/null; then
    log_ok "Claude Code already installed at $(command -v claude)"
else
    log_wait "Installing Claude Code (curl | bash from claude.ai/install.sh) ..."
    curl -fsSL https://claude.ai/install.sh | bash

    # The installer drops the binary in ~/.local/bin (already exported in
    # zsh/configs/path.zsh as $PATH_CLAUDE). Verify it landed.
    if [[ -x "$HOME/.local/bin/claude" ]]; then
        log_ok "Claude Code installed → $HOME/.local/bin/claude"
    else
        log_err "Claude Code install completed but binary not found at ~/.local/bin/claude"
        exit 1
    fi
fi
