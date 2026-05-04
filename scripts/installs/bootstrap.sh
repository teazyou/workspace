#!/bin/bash
# scripts/installs/bootstrap.sh
#
# Purpose:
#   Brings a brand-new macOS install up to the bare minimum required to
#   clone the workspace repo. Once the workspace is on disk, it hands off
#   to installation.sh which does everything else.
#
# Steps:
#   1. Xcode Command Line Tools (provides git, gcc, make, ...)
#   2. Rosetta 2 (Apple Silicon only)
#   3. Homebrew  (+ ensure it's on PATH for the rest of this script and
#                 for the installation.sh handoff)
#   4. Latest git from brew (CLT git is fine but brew tracks newer)
#   5. Clone teazyou/workspace via HTTPS (public repo, no auth needed)
#   6. Hand off to ~/workspace/scripts/installs/installation.sh
#
# Usage — one-line remote install on a fresh Mac:
#   curl -fsSL https://raw.githubusercontent.com/teazyou/workspace/master/scripts/installs/bootstrap.sh | bash
#
# Idempotent: re-running on a partially-set-up system skips finished steps.
#
# Note on previous flakiness:
#   This script used to have to be run two or three times. Two root causes:
#     (a) Homebrew's shellenv was only eval'd inside the "just installed
#         brew" branch. If brew was already installed but its shellenv
#         hadn't been added to the current shell yet (which is the case on
#         the very first run after install_brew.sh dies mid-way), brew
#         wasn't on PATH for the next steps.
#     (b) The handoff `exec bash installation.sh` relied on $PATH being
#         exported, but on a fresh Mac the user's shell hasn't been
#         restarted yet so /opt/homebrew/bin wasn't visible to children.
#   Both are now fixed by ALWAYS sourcing brew shellenv once brew exists,
#   regardless of whether we just installed it.

set -e

# Colours are inlined here because the workspace repo isn't on disk yet,
# so we can't source zsh/configs/colors.zsh. After installation.sh takes
# over, the proper helpers from scripts/installs/helper_prompt.sh take care of output.
CRE=$(printf '\033[0;31m')
CGR=$(printf '\033[0;32m')
CYE=$(printf '\033[0;33m')
CBL=$(printf '\033[0;34m')
CWH=$(printf '\033[0;38m')

log()  { printf "%s[ BOOTSTRAP ]%s %s\n" "$CBL" "$CWH" "$1"; }
ok()   { printf "%s[ OK ]%s %s\n"        "$CGR" "$CWH" "$1"; }
warn() { printf "%s[ W8 ]%s %s\n"        "$CYE" "$CWH" "$1"; }
err()  { printf "%s[ KO ]%s %s\n"        "$CRE" "$CWH" "$1"; }

REPO_URL="https://github.com/teazyou/workspace.git"
WORKSPACE="$HOME/workspace"

# Ensure brew is on PATH for the current bash process.
# Apple Silicon installs brew in /opt/homebrew, Intel in /usr/local. We
# call this both right after a fresh brew install AND defensively on
# re-runs where brew already exists but hasn't been eval'd yet.
ensure_brew_on_path() {
    if command -v brew &>/dev/null; then
        return 0
    fi
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

# 1. Xcode Command Line Tools --------------------------------------------
# CLT install is a GUI dialog. We trigger it then poll until it finishes.
log "Checking Xcode Command Line Tools..."
if xcode-select -p &>/dev/null; then
    ok "Xcode Command Line Tools already installed"
else
    warn "Triggering Xcode CLT installer (a GUI dialog will pop up)..."
    xcode-select --install || true
    warn "Waiting for Xcode CLT install to complete (polls every 5s)..."
    until xcode-select -p &>/dev/null; do sleep 5; done
    ok "Xcode Command Line Tools installed"
fi

# 2. Rosetta 2 (Apple Silicon only) --------------------------------------
# Some apps still ship x86_64 only; Rosetta lets them run on arm64 Macs.
if [[ "$(uname -m)" == "arm64" ]]; then
    log "Checking Rosetta 2..."
    if /usr/bin/pgrep -q oahd; then
        ok "Rosetta 2 already installed"
    else
        warn "Installing Rosetta 2..."
        softwareupdate --install-rosetta --agree-to-license
        ok "Rosetta 2 installed"
    fi
else
    log "Skipping Rosetta 2 (not Apple Silicon)"
fi

# 3. Homebrew -------------------------------------------------------------
log "Checking Homebrew..."
ensure_brew_on_path
if command -v brew &>/dev/null; then
    ok "Homebrew already installed"
else
    # The Homebrew installer needs sudo ONCE to chown /opt/homebrew (or
    # /usr/local on Intel). After install, `brew` itself runs without
    # sudo — that's the "don't use sudo" guidance you've heard. So:
    #   - The user has to be an Administrator (in the macOS admin group).
    #   - Sudo credentials must be cached before NONINTERACTIVE=1 kicks
    #     in, because in non-interactive mode brew won't prompt and just
    #     errors out with "Need sudo access on macOS" (which is what you
    #     hit). We pre-cache with `sudo -v` and keep the timestamp warm
    #     in the background so the install doesn't trip on a long
    #     download timing out the 5-min sudo window.

    # Hard-fail early if the user isn't an admin — the install can't
    # succeed at all in that case and there's no point pretending.
    if ! dseditgroup -o checkmember -m "$(whoami)" admin &>/dev/null; then
        err "User '$(whoami)' is not an Administrator on this Mac."
        err "Add this account to the admin group (System Settings → Users & Groups → Administrator) and re-run."
        exit 1
    fi

    warn "Homebrew install needs your password ONCE (to chown /opt/homebrew). brew itself runs without sudo afterwards."
    sudo -v
    # Background refresher: re-prime the sudo timestamp every 60s while
    # this script's PID is still alive. Dies automatically when we exit.
    ( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 60; done ) &
    SUDO_KEEPALIVE_PID=$!

    warn "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Stop the keepalive — brew is on disk now and the rest of the
    # script doesn't need sudo.
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true

    ensure_brew_on_path
    if ! command -v brew &>/dev/null; then
        err "Homebrew install finished but 'brew' is still not on PATH"
        exit 1
    fi
    ok "Homebrew installed"
fi

# 4. Git (latest, via brew) ----------------------------------------------
# CLT already provides git — but we install brew's git for newer releases.
log "Checking git..."
if brew list git &>/dev/null; then
    ok "git (brew) already installed"
else
    warn "Installing git via brew..."
    brew install git
    ok "git installed"
fi

# 5. Clone the workspace repo --------------------------------------------
# Workspace is a public repo so HTTPS clone needs no credentials.
log "Cloning $REPO_URL into $WORKSPACE ..."
if [[ -d "$WORKSPACE/.git" ]]; then
    ok "Workspace already cloned at $WORKSPACE"
else
    git clone "$REPO_URL" "$WORKSPACE"
    ok "Workspace cloned"
fi

# 6. Hand off to the main installer --------------------------------------
log "Bootstrap done — handing off to installation.sh"
# `exec` replaces this bash process with the installer.
# stdin is redirected from /dev/tty so prompts work even when bootstrap.sh
# was started via `curl ... | bash` (where stdin is the consumed pipe).
# We re-source brew shellenv one more time so it's exported into the
# environment that installation.sh inherits.
ensure_brew_on_path
exec bash "$WORKSPACE/scripts/installs/installation.sh" < /dev/tty
