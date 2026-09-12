#!/bin/bash
# scripts/installs/setup_dev.sh
#
# Creates ~/dev for the `dev` navigation function in zsh/alias/navigation.zsh.
# Existing projects are preserved; repeated runs leave the directory unchanged.

set -e

: "${INSTALLS:=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

log_step "~/dev folder"
if [[ -d "$HOME/dev" ]]; then
    log_ok "~/dev already exists"
else
    mkdir -p "$HOME/dev"
    log_ok "~/dev created"
fi
