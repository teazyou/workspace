#!/bin/bash
# scripts/installs/install_xcode_mas.sh
#
# Purpose:
#   Installs the full Xcode app from the Mac App Store via `mas` and
#   accepts its license.
#
# Why mas:
#   Xcode isn't available via Homebrew (Apple gates it through the Mac
#   App Store). The `mas` CLI lets us install App Store apps from a
#   shell — but only AFTER you've manually signed into the App Store.
#   Apple removed the `mas signin` command, so the sign-in step stays
#   manual; we pause and ask the user to do it.
#
# Xcode app store ID = 497799835
#
# Idempotent: skipped if /Applications/Xcode.app already exists.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

XCODE_ID="497799835"

# 1. Already installed? --------------------------------------------------
if [[ -d "/Applications/Xcode.app" ]]; then
    log_ok "Xcode already installed"
else
    # 2. Make sure mas is on PATH ----------------------------------------
    if ! command -v mas &>/dev/null; then
        log_err "mas CLI not found — did install_brew.sh run?"
        exit 1
    fi

    # 3. Ensure App Store sign-in (mas can't sign in for us) -------------
    if ! mas account &>/dev/null; then
        log_wait "App Store needs to be signed in before mas can install apps."
        prompt_command "Open the App Store app and sign in with your Apple ID." \
                       "open -a 'App Store'"
    fi

    # 4. Install Xcode ---------------------------------------------------
    log_wait "Installing Xcode via mas (this is a multi-GB download — be patient) ..."
    mas install "$XCODE_ID"
    log_ok "Xcode installed"
fi

# 5. Accept the Xcode license -------------------------------------------
# The license accept step requires sudo. Touch ID is already wired up by
# install_touch_id_sudo.sh (assuming that script ran before this one).
log_wait "Accepting Xcode license (requires sudo) ..."
sudo xcodebuild -license accept

# 6. Run first-launch component install ---------------------------------
# After a fresh Xcode install, a few additional components install on
# first launch. -runFirstLaunch handles that headlessly.
log_wait "Running xcodebuild -runFirstLaunch ..."
sudo xcodebuild -runFirstLaunch || true

log_ok "Xcode ready"
