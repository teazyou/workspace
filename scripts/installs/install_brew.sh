#!/bin/bash
# scripts/installs/install_brew.sh
#
# Purpose:
#   Installs Homebrew taps, formulae, and casks for the workspace.
#   Uses brewInstall / caskInstall / brewTap from functions/brew.sh, which
#   short-circuit when an app is already present.
#
# Notes:
#   - We always pin to LATEST (no @<version>) so this script keeps working
#     for years without manual version bumps. PostgreSQL is the one
#     exception — Homebrew has no unversioned formula, so we detect the
#     highest postgresql@N at runtime.
#   - Reordering this list is fine. Each line is independent.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"
# shellcheck source=/dev/null
source "$FUNCTIONS/brew.sh"

# --- TAPS ------------------------------------------------------------------
# felixkratz/formulae provides the sketchybar (status bar) and borders
# (window border tinting) formulae used by the window-manager setup.
log_step "Brew taps"
brewTap "felixkratz/formulae"

# --- FORMULAE --------------------------------------------------------------
log_step "Brew formulae"

brewInstall "PYTHON"     "python"      # python3 + pip (system Python is locked to 3.9)
brewInstall "NVM"        "nvm"         # Node Version Manager — Node itself is installed in install_node.sh
brewInstall "MYSQL"      "mysql"       # initial setup runs in install_database.sh
brewInstall "SKETCHYBAR" "sketchybar"  # custom status bar (window-manager stack)
brewInstall "BORDERS"    "borders"     # JankyBorders — colored window borders
brewInstall "RIPGREP"    "ripgrep"     # fast grep replacement, used by Claude Code
brewInstall "OLLAMA"     "ollama"      # local LLM runner
brewInstall "GEMINI-CLI" "gemini-cli"  # Google Gemini CLI
brewInstall "OPENCODE"   "opencode"    # opencode AI tool
brewInstall "MAS"        "mas"         # Mac App Store CLI (used by install_xcode_mas.sh)
brewInstall "GH"         "gh"          # GitHub CLI (used by clone_repos.sh for private repo auth)

# PostgreSQL: Homebrew only ships versioned formulae. Pick the highest
# postgresql@N currently available so this works in 2026, 2027, ...
log_wait "Detecting latest postgresql@N formula..."
PG_LATEST=$(brew formulae 2>/dev/null \
    | grep -E '^postgresql@[0-9]+$' \
    | sort -t '@' -k 2 -n \
    | tail -1)
if [[ -n "$PG_LATEST" ]]; then
    log_ok "Latest detected: $PG_LATEST"
    brewInstall "POSTGRESQL" "$PG_LATEST"
else
    log_err "Could not detect latest postgresql formula — falling back to postgresql@17"
    brewInstall "POSTGRESQL" "postgresql@17"
fi

# --- CASKS -----------------------------------------------------------------
log_step "Brew casks"

caskInstall "ITERM"             "iterm2"
caskInstall "VSCODE"            "visual-studio-code"
caskInstall "BRAVE"             "brave-browser"
caskInstall "SPOTIFY"           "spotify"
caskInstall "DBEAVER"           "dbeaver-community"
caskInstall "KEEPING-YOU-AWAKE" "keepingyouawake"
caskInstall "TRANSMISSION"      "transmission"
caskInstall "VLC"               "vlc"
caskInstall "NORDVPN"           "nordvpn"
caskInstall "BITWARDEN"         "bitwarden"
caskInstall "ONYX"              "onyx"
caskInstall "AEROSPACE"         "aerospace"            # tiling window manager
caskInstall "FONT-NERD"         "font-hack-nerd-font"  # required by sketchybar icons
caskInstall "CLEANMYMAC"        "cleanmymac"
caskInstall "DISCORD"           "discord"
caskInstall "OBSIDIAN"          "obsidian"             # used by ~/secondbrain workflow
caskInstall "GOOGLE-DRIVE"      "google-drive"

# --- CLEANUP ---------------------------------------------------------------
log_step "Brew upgrade + cleanup"

log_wait "Running 'brew upgrade'..."
brew upgrade
log_ok "Brew upgrade done"

log_wait "Running 'brew cleanup'..."
brew cleanup
brew services cleanup
log_ok "Brew cleanup done"

log_ok "Brew install complete"
