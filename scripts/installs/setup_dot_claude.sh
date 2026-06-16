#!/bin/bash
# scripts/installs/setup_dot_claude.sh
#
# Purpose:
#   Reproduce, on a fresh machine, the ~/.claude setup that this repo uses:
#     - configs/dot-claude is a PRIVATE git submodule (the real Claude Code
#       config + runtime store, allowlist-gitignored so only safe config is
#       committed).
#     - ~/.claude is a whole-folder SYMLINK → workspace/configs/dot-claude.
#
#   Because the submodule is PRIVATE, it can only be cloned once gh is
#   authenticated — which happens in clone_repos.sh. This script therefore
#   runs AFTER clone_repos.sh in installation.sh. It wires git's HTTPS to the
#   gh token via `gh auth setup-git`, then inits the submodule, then symlinks.
#
# Idempotent:
#   - gh auth setup-git is safe to re-run.
#   - submodule update --init is skipped (no-op) if already initialized.
#   - if ~/.claude is already the correct symlink → left as-is.
#   - if ~/.claude is a real dir/file (e.g. Claude Code created one) → it is
#     MOVED to a timestamped ~/.claude.bak.<unix-ts> (never rm -rf'd — that
#     dir may hold user data; note the macOS OAuth token lives in Keychain,
#     not in ~/.claude, so moving the dir does NOT log the user out). The
#     timestamped name (mirroring setup_symlinks.sh's make_link) can never
#     collide, so no clobber-guard is needed.
#
# Run manually (after gh is authenticated):
#   bash ~/workspace/scripts/installs/setup_dot_claude.sh

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

SUBMODULE_PATH="configs/dot-claude"
SRC="$WORKSPACE/$SUBMODULE_PATH"        # real submodule working tree
LINK="$HOME/.claude"                    # the symlink we want: ~/.claude → $SRC

# --- 1. Make git's HTTPS use the gh token (so the PRIVATE submodule clones) ---
log_step "dot-claude: git auth"
if ! command -v gh &>/dev/null; then
    log_err "gh CLI not found — did install_brew.sh run?"
    exit 1
fi
if ! gh auth status &>/dev/null; then
    log_err "gh CLI is not authenticated. Run clone_repos.sh first (it does 'gh auth login'),"
    log_err "or run 'gh auth login' manually, then re-run this script."
    exit 1
fi
log_wait "Configuring git to use the gh credential helper for HTTPS..."
gh auth setup-git
log_ok "git HTTPS wired to gh token"

# --- 2. Initialize the PRIVATE configs/dot-claude submodule -------------------
log_step "dot-claude: submodule"
if [[ ! -f "$WORKSPACE/.gitmodules" ]]; then
    log_err "$WORKSPACE/.gitmodules missing — expected the dot-claude submodule to be committed."
    exit 1
fi
# `git -C` keeps us in the workspace repo without cd'ing.
# A populated submodule has real files (e.g. settings.json) under $SRC; an
# uninitialized one is an empty dir. Init only when not yet populated.
if [[ -e "$SRC/settings.json" ]] || [[ -n "$(ls -A "$SRC" 2>/dev/null)" && -e "$SRC/.git" ]]; then
    log_ok "Submodule already initialized → $SRC"
else
    log_wait "Initializing private submodule $SUBMODULE_PATH (HTTPS clone via gh token)..."
    git -C "$WORKSPACE" submodule update --init "$SUBMODULE_PATH"
    log_ok "Submodule initialized → $SRC"
fi

# Sanity: the submodule working tree must now exist and be non-empty.
if [[ ! -d "$SRC" ]] || [[ -z "$(ls -A "$SRC" 2>/dev/null)" ]]; then
    log_err "Submodule path $SRC is missing or empty after init — clone likely failed (auth/network)."
    exit 1
fi

# --- 3. Point ~/.claude at the submodule (whole-folder symlink) ---------------
log_step "dot-claude: ~/.claude symlink"

# Already the correct symlink → done.
if [[ -L "$LINK" && "$(readlink "$LINK")" == "$SRC" ]]; then
    log_ok "~/.claude already linked → $SRC"
else
    # Wrong symlink → just remove it (it owns no data).
    if [[ -L "$LINK" ]]; then
        log_wait "~/.claude is a symlink to the wrong target — replacing it"
        rm "$LINK"
    # Real dir/file (Claude Code may have created it) → back up, never delete.
    elif [[ -e "$LINK" ]]; then
        backup="$LINK.bak.$(date +%s)"
        log_wait "~/.claude is a real directory — backing it up → $backup"
        log_wait "(your OAuth token is in the macOS Keychain, not here, so this won't log you out)"
        mv "$LINK" "$backup"
    fi
    ln -s "$SRC" "$LINK"
    log_ok "~/.claude linked → $SRC"
fi

# --- 4. Verify ----------------------------------------------------------------
if [[ -L "$LINK" && "$(readlink "$LINK")" == "$SRC" && -e "$LINK/settings.json" ]]; then
    log_ok "dot-claude setup complete — ~/.claude → $SRC (settings.json resolves)"
else
    log_err "dot-claude verification failed: ~/.claude does not resolve to $SRC/settings.json"
    exit 1
fi
