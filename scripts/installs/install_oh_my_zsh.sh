#!/bin/bash
# scripts/installs/install_oh_my_zsh.sh
#
# Purpose:
#   Installs Oh-My-Zsh into ~/.oh-my-zsh.
#
# Why the env vars:
#   The official installer normally:
#     1. overwrites ~/.zshrc with its own template
#     2. starts a new zsh subshell
#     3. switches the user's login shell to /bin/zsh
#   We don't want any of that — our ~/.zshrc is a symlink into the workspace
#   (created later in setup_symlinks.sh) and macOS already defaults to zsh.
#   So we set:
#     KEEP_ZSHRC=yes  → don't touch ~/.zshrc
#     RUNZSH=no       → don't drop into a zsh subshell
#     CHSH=no         → don't try to chsh
#
# Idempotent: if ~/.oh-my-zsh exists we skip.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log_ok "OH-MY-ZSH already installed"
    exit 0
fi

log_wait "Installing OH-MY-ZSH..."
KEEP_ZSHRC=yes RUNZSH=no CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log_ok "OH-MY-ZSH installed"
else
    log_err "OH-MY-ZSH install failed"
    exit 1
fi
