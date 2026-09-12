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
#     for years without manual version bumps.
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
brewInstall "SKETCHYBAR" "sketchybar"  # custom status bar (window-manager stack)
brewInstall "BORDERS"    "borders"     # JankyBorders — colored window borders
brewInstall "RIPGREP"    "ripgrep"     # fast grep replacement, used by Claude Code
brewInstall "MAS"        "mas"         # Mac App Store CLI (used by install_xcode_mas.sh)
brewInstall "GH"         "gh"          # GitHub CLI (also used by the optional SketchyBar GitHub plugin)

# --- CASKS -----------------------------------------------------------------
log_step "Brew casks"

caskInstall "ITERM"             "iterm2"
caskInstall "VSCODE"            "visual-studio-code"
caskInstall "GOOGLE-CHROME"     "google-chrome"
caskInstall "CHATGPT"           "chatgpt"  # ChatGPT.app desktop; retained internal identity com.openai.codex
caskInstall "CODEX-CLI"         "codex"    # terminal command (bin/codex)
caskInstall "SPOTIFY"           "spotify"
caskInstall "BITWARDEN"         "bitwarden"
caskInstall "AEROSPACE"         "nikitabobko/tap/aerospace"  # tiling window manager (lives in its own tap)
caskInstall "FONT-NERD"         "font-hack-nerd-font"  # required by sketchybar icons
caskInstall "FONT-SKETCHYBAR"   "font-sketchybar-app-font"  # app icons in the spaces strip (plugins/icon_map.sh)
caskInstall "DISCORD"           "discord"
caskInstall "OBSIDIAN"          "obsidian"             # central configuration and the obsi vault launcher

# --- CLEANUP ---------------------------------------------------------------
# These three commands are nice-to-have, not critical. A single broken
# cask (e.g. one that needs a sudo prompt during upgrade) used to abort
# the whole installer because `set -e` propagates the exit code. We
# tolerate failures here so the rest of the pipeline keeps going.
log_step "Brew upgrade + cleanup"

log_wait "Running 'brew upgrade'..."
brew upgrade || log_err "brew upgrade returned non-zero (continuing)"
log_ok "Brew upgrade done"

log_wait "Running 'brew cleanup'..."
brew cleanup           || log_err "brew cleanup returned non-zero (continuing)"
brew services cleanup  || log_err "brew services cleanup returned non-zero (continuing)"
log_ok "Brew cleanup done"

log_ok "Brew install complete"
