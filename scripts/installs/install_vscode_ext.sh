#!/bin/bash
# scripts/installs/install_vscode_ext.sh
#
# Purpose:
#   Re-installs the VSCode extensions used in this workspace.
#
#   Brew's `visual-studio-code` cask normally installs the `code` CLI
#   shim into /opt/homebrew/bin so it's already on PATH. If for some
#   reason it isn't, we fall back to the absolute path inside the .app
#   bundle.
#
# Extension list:
#   - bracketpaircolordlw.bracket-pair-color-dlw  (colored bracket pairs)
#   - chunsen.bracket-select                       (bracket selection helper)
#   - eamodio.gitlens                              (git blame/history overlay)
#
# Idempotent: `code --install-extension` is a no-op when the extension
# is already present.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

# Resolve the `code` CLI. Brew cask normally puts it on PATH; if not,
# the absolute path inside the .app always exists once VSCode is installed.
if command -v code &>/dev/null; then
    CODE_BIN=$(command -v code)
elif [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
    CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
else
    log_err "VSCode CLI ('code') not found. Open VSCode at least once first."
    prompt_continue "Open VSCode (⌘Space → 'Visual Studio Code'), then close it, then resume."
    if [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
        CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    else
        log_err "Still cannot find the VSCode CLI — aborting extension install"
        exit 1
    fi
fi

log_wait "Using VSCode CLI: $CODE_BIN"

# List of extensions to install. Add new ones here.
EXTENSIONS=(
    "bracketpaircolordlw.bracket-pair-color-dlw"
    "chunsen.bracket-select"
    "eamodio.gitlens"
)

for ext in "${EXTENSIONS[@]}"; do
    log_wait "Installing VSCode extension: $ext"
    "$CODE_BIN" --install-extension "$ext" --force
    log_ok "$ext"
done

log_ok "VSCode extensions installed"
