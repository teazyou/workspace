#!/bin/bash
# scripts/installs/install_claude.sh
#
# Purpose:
#   Native (non-brew) install of:
#     1. Claude Desktop  — via the official .zip from downloads.claude.ai
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
    # Anthropic publishes a JSON manifest of releases. Each entry has an
    # `updateTo.url` pointing at a versioned .zip on downloads.claude.ai.
    # The previous "/api/desktop/.../latest/redirect" URL we used does
    # not exist (returns 403) — only the manifest below is correct.
    RELEASES_URL="https://downloads.claude.ai/releases/darwin/universal/RELEASES.json"
    ZIP_PATH="/tmp/claude-desktop.zip"
    EXTRACT_DIR="/tmp/claude-desktop-extract"

    log_wait "Fetching Claude Desktop release manifest ..."
    RELEASES_JSON=$(curl -fsSL "$RELEASES_URL")
    if [[ -z "$RELEASES_JSON" ]]; then
        log_err "Could not fetch $RELEASES_URL"
        exit 1
    fi

    # Pick the first release in the manifest (Anthropic lists newest first).
    # Use python3 (always present on macOS) so we don't depend on jq.
    DOWNLOAD_URL=$(printf '%s' "$RELEASES_JSON" | python3 -c '
import json, sys
data = json.load(sys.stdin)
releases = data.get("releases") or []
if not releases:
    sys.exit(1)
print(releases[0]["updateTo"]["url"])
')

    if [[ -z "$DOWNLOAD_URL" ]]; then
        log_err "Could not parse latest Claude Desktop URL from RELEASES.json"
        exit 1
    fi

    log_wait "Downloading Claude Desktop .zip from $DOWNLOAD_URL ..."
    curl -fL -o "$ZIP_PATH" "$DOWNLOAD_URL"

    log_wait "Extracting .zip ..."
    rm -rf "$EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"
    # `ditto` preserves the .app bundle metadata (codesign, quarantine bit
    # placement) better than `unzip` on macOS — recommended for .app zips.
    ditto -x -k "$ZIP_PATH" "$EXTRACT_DIR"

    APP_PATH=$(find "$EXTRACT_DIR" -maxdepth 2 -name "*.app" -print -quit)
    if [[ -z "$APP_PATH" ]]; then
        log_err "No .app found inside $ZIP_PATH"
        exit 1
    fi

    log_wait "Copying $(basename "$APP_PATH") to /Applications ..."
    rm -rf "/Applications/$(basename "$APP_PATH")"
    cp -R "$APP_PATH" /Applications/

    # Strip the Gatekeeper quarantine flag so the app opens without
    # macOS prompting "downloaded from the internet" on first launch.
    xattr -dr com.apple.quarantine "/Applications/$(basename "$APP_PATH")" 2>/dev/null || true

    rm -f "$ZIP_PATH"
    rm -rf "$EXTRACT_DIR"

    log_ok "Claude Desktop installed → /Applications/$(basename "$APP_PATH")"
fi

# --- 2. Claude Code CLI -------------------------------------------------
# We check the binary path directly rather than `command -v claude`, because
# this script runs in a bash subshell that does NOT source ~/.zshrc — so
# ~/.local/bin (the install target) isn't on PATH for `command -v` even
# though the binary is present. That made every re-run reinstall.
log_step "Claude Code CLI"

CLAUDE_BIN="$HOME/.local/bin/claude"

if [[ -x "$CLAUDE_BIN" ]]; then
    log_ok "Claude Code already installed at $CLAUDE_BIN"
else
    log_wait "Installing Claude Code (curl | bash from claude.ai/install.sh) ..."
    curl -fsSL https://claude.ai/install.sh | bash

    if [[ -x "$CLAUDE_BIN" ]]; then
        log_ok "Claude Code installed → $CLAUDE_BIN"
    else
        log_err "Claude Code install completed but binary not found at $CLAUDE_BIN"
        exit 1
    fi
fi
