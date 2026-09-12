#!/bin/bash
# Sole caller: install_brew.sh. No work at source time. Failures propagate.
# Supported Homebrew controls suppress cleanup and upgrades of already installed
# targets/dependents. Required dependencies can still change: inspect --dry-run
# in a supervised session before each missing target and defer host disruption.
brew_formula_present() {
    brew list --formula -1 2>/dev/null | grep -Eq "^${1##*/}(@.+)?$"
}
brewInstall() {
    if brew_formula_present "$2"; then return 0; fi
    brew install --dry-run --formula "$2" || return 1
    brew install --formula "$2" || { echo "Formula install failed: $2" >&2; return 1; }
    brew_formula_present "$2"
}
caskInstall() {
    if brew list --cask "${2##*/}" >/dev/null 2>&1; then return 0; fi
    brew install --dry-run --cask "$2" || return 1
    brew install --cask "$2" || { echo "Cask install failed: $2" >&2; return 1; }
    brew list --cask "${2##*/}" >/dev/null 2>&1
}
brewTap() {
    if brew tap | grep -Fxq "$1"; then return 0; fi
    brew tap "$1" || { echo "Tap failed: $1" >&2; return 1; }
}
