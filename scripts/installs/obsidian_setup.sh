#!/bin/bash
# scripts/installs/obsidian_setup.sh
#
# Purpose:
#   After clone_repos.sh has cloned ~/secondbrain (the Obsidian vault),
#   this script moves that folder into iCloud Drive so the vault is
#   available on iPhone/iPad through Obsidian Mobile, while keeping
#   the git history out of iCloud sync.
#
# Steps:
#   1. Renames ~/secondbrain/.git → .git.nosync   (the .nosync suffix
#      tells iCloud Drive to skip the folder, so the entire git history
#      stays local and never uploads).
#   2. Creates a ~/secondbrain/.git symlink pointing at .git.nosync so
#      git tools keep working transparently.
#   3. Moves ~/secondbrain → ~/Library/Mobile Documents/com~apple~CloudDocs/Obsidian/SecondBrain.
#   4. Creates a ~/secondbrain symlink pointing back at the iCloud copy
#      so all existing tooling (vault paths, scripts, shell aliases)
#      keeps working unchanged.
#
# Prerequisites:
#   - ~/secondbrain has been cloned (clone_repos.sh ran first).
#   - iCloud Drive is enabled. If not, the script pauses and asks the
#     user to enable it in System Settings → Apple ID → iCloud.
#
# Idempotent: if ~/secondbrain is already a symlink to the iCloud copy,
# the script logs OK and exits cleanly.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
ICLOUD_DEST="$ICLOUD/Obsidian/SecondBrain"

# --- 1. Already done? -------------------------------------------------------
log_step "secondbrain → iCloud setup"

if [[ -L "$HOME/secondbrain" ]] && [[ "$(readlink "$HOME/secondbrain")" == "$ICLOUD_DEST" ]]; then
    log_ok "~/secondbrain already symlinked to iCloud — nothing to do"
    exit 0
fi

# --- 2. Verify ~/secondbrain is a legit cloned vault -----------------------
# Returns:
#   0 = folder exists, has .git, is a valid git repo
#   1 = ~/secondbrain does not exist (or is a broken symlink)
#   2 = folder exists but has no .git
#   3 = .git exists but it isn't a valid git repository
check_secondbrain() {
    [[ -d "$HOME/secondbrain" ]] || return 1
    [[ -e "$HOME/secondbrain/.git" ]] || return 2
    git -C "$HOME/secondbrain" rev-parse --git-dir >/dev/null 2>&1 || return 3
    return 0
}

while true; do
    sb_status=0; check_secondbrain || sb_status=$?
    case "$sb_status" in
        0) log_ok "~/secondbrain verified (cloned vault with valid .git)"; break ;;
        1) log_err "~/secondbrain does not exist — clone_repos.sh must run first" ;;
        2) log_err "~/secondbrain exists but has no .git folder" ;;
        3) log_err "~/secondbrain/.git is not a valid git repository" ;;
    esac

    log_wait "Fix the issue (e.g. re-clone, or restore the .git folder), then retry."
    printf "%s[r] Retry  [s] Skip:%s " "$CYE" "$CWH"
    read -r choice < /dev/tty
    case "$choice" in
        s|S) log_wait "Skipped — Obsidian iCloud setup not performed"; exit 0 ;;
        *)   ;;  # anything else = retry
    esac
done

# --- 3. Make sure iCloud Drive is enabled ----------------------------------
if [[ ! -d "$ICLOUD" ]]; then
    log_wait "iCloud Drive is not enabled on this Mac."
    log_wait "Open System Settings → Apple ID → iCloud → iCloud Drive and turn it on."
    prompt_continue "Press ENTER once iCloud Drive is enabled..."
fi

if [[ ! -d "$ICLOUD" ]]; then
    log_err "iCloud Drive still not available at: $ICLOUD"
    exit 1
fi

# --- 4. Conflict check: iCloud destination must not already exist ----------
if [[ -d "$ICLOUD_DEST" ]]; then
    log_err "An Obsidian/SecondBrain folder already exists in iCloud:"
    log_err "  $ICLOUD_DEST"
    log_err "Refusing to overwrite. Resolve manually then re-run."
    exit 1
fi

# --- 5. Rename .git → .git.nosync so iCloud skips it -----------------------
if [[ -d "$HOME/secondbrain/.git" ]] && [[ ! -L "$HOME/secondbrain/.git" ]]; then
    log_wait "Renaming .git → .git.nosync (iCloud will skip this folder)..."
    mv "$HOME/secondbrain/.git" "$HOME/secondbrain/.git.nosync"
    ln -s .git.nosync "$HOME/secondbrain/.git"
    log_ok ".git renamed and symlinked"
else
    log_ok ".git already prepared"
fi

# --- 6. Sanity: git still works through the symlink ------------------------
if ! git -C "$HOME/secondbrain" status >/dev/null 2>&1; then
    log_err "git status failed after .git rename — aborting before move"
    exit 1
fi
log_ok "git status works through .git symlink"

# --- 7. Move ~/secondbrain into iCloud -------------------------------------
log_wait "Moving ~/secondbrain → $ICLOUD_DEST ..."
mkdir -p "$ICLOUD/Obsidian"
mv "$HOME/secondbrain" "$ICLOUD_DEST"
log_ok "Moved to iCloud"

# --- 8. Create symlink back at ~/secondbrain -------------------------------
ln -s "$ICLOUD_DEST" "$HOME/secondbrain"
log_ok "~/secondbrain → iCloud symlink created"

log_ok "Obsidian iCloud setup done"
