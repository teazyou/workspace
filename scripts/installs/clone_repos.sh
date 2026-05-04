#!/bin/bash
# scripts/installs/clone_repos.sh
#
# Purpose:
#   Clones the personal repos that aren't part of the workspace itself
#   and creates the empty ~/dev folder.
#
# Repos:
#   - ~/secondbrain   (private)  → cloned via gh CLI after auth
#
# Folders:
#   - ~/dev   → created empty; the `dev` zsh function (zsh/alias/navigation.zsh)
#               cd's into here. No projects pre-cloned.
#
# No credentials are stored in this script — the workspace repo is public.
# Authentication for the private clone is handled via `gh auth login`,
# which prompts you through a browser flow.
#
# Idempotent: skips repos that are already cloned, mkdir -p for ~/dev.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

# --- 1. ~/dev folder ----------------------------------------------------
log_step "~/dev folder"
if [[ -d "$HOME/dev" ]]; then
    log_ok "~/dev already exists"
else
    mkdir -p "$HOME/dev"
    log_ok "~/dev created"
fi

# --- 2. Authenticate gh CLI for the private clone ----------------------
log_step "GitHub auth (for private repos)"
if ! command -v gh &>/dev/null; then
    log_err "gh CLI not found — did install_brew.sh run?"
    exit 1
fi

if gh auth status &>/dev/null; then
    log_ok "gh CLI already authenticated"
else
    log_wait "gh CLI needs to authenticate to GitHub before we can clone private repos."
    log_wait "The interactive flow will open your browser for the device-code login."
    prompt_continue "About to run 'gh auth login' — pick HTTPS / login with web browser."
    gh auth login
    log_ok "gh CLI authenticated"
fi

# --- 3. ~/secondbrain (private) ----------------------------------------
log_step "secondbrain"
if [[ -d "$HOME/secondbrain/.git" ]]; then
    log_ok "~/secondbrain already cloned"
else
    log_wait "Cloning teazyou/secondbrain → ~/secondbrain ..."
    gh repo clone teazyou/secondbrain "$HOME/secondbrain"
    log_ok "~/secondbrain cloned"
fi

log_ok "Repo cloning done"
