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
#   3. Homebrew
#   4. Latest git from brew (CLT git is fine but brew tracks newer)
#   5. Clone teazyou/workspace via HTTPS (public repo, no auth needed)
#   6. Hand off to ~/workspace/scripts/installs/installation.sh
#
# Usage — one-line remote install on a fresh Mac:
#   curl -fsSL https://raw.githubusercontent.com/teazyou/workspace/master/scripts/installs/bootstrap.sh | bash
#
# Idempotent: re-running on a partially-set-up system skips finished steps.

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
if command -v brew &>/dev/null; then
    ok "Homebrew already installed"
else
    warn "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to current shell PATH (Apple Silicon → /opt/homebrew, Intel → /usr/local).
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
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
exec bash "$WORKSPACE/scripts/installs/installation.sh" < /dev/tty
