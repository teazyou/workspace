#!/bin/bash
# scripts/installs/install_node.sh
#
# Purpose:
#   Initialises NVM and installs the latest LTS Node release.
#
#   `nvm` itself was installed in install_brew.sh. NVM is sourced from
#   $(brew --prefix)/opt/nvm/nvm.sh so this works regardless of where
#   brew lives (Apple Silicon /opt/homebrew vs Intel /usr/local).
#
# Idempotent: NVM's `install` command is a no-op when the requested
# version (LTS) is already present.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

# Ensure NVM_DIR exists and source nvm.sh from brew.
export NVM_DIR="$HOME/.nvm"
mkdir -p "$NVM_DIR"

NVM_SH="$(brew --prefix)/opt/nvm/nvm.sh"
if [[ ! -s "$NVM_SH" ]]; then
    log_err "NVM not found at $NVM_SH — was nvm installed by install_brew.sh?"
    exit 1
fi

# shellcheck source=/dev/null
. "$NVM_SH"

log_wait "Installing Node LTS via NVM ..."
nvm install --lts
nvm alias default 'lts/*'
nvm use --lts

log_ok "Node $(node --version) installed via NVM (default = LTS)"
