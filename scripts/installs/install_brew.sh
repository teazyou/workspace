#!/bin/bash
# One inventory for installation, listing and receipt/artifact verification.
# --phase minimal|remaining|all (default all); --verify-only; --list.
# No upgrades/cleanup by default. --maintenance is an explicit manual operation
# only after the active AI/terminal host is safe; it cannot accompany a phase.
set -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/helper_prompt.sh"
source "$FUNCTIONS/brew.sh"
source "$INSTALLS/recovery_checks.sh"

MINIMAL_CASKS=(iterm2 chatgpt claude codex brave-browser)
REMAINING_FORMULAE=(python nvm sketchybar borders ripgrep mas gh)
REMAINING_CASKS=(visual-studio-code google-chrome spotify bitwarden nikitabobko/tap/aerospace font-hack-nerd-font font-sketchybar-app-font discord obsidian)

cask_artifact() {
    case "${1##*/}" in
        iterm2) verify_app '/Applications/iTerm.app' com.googlecode.iterm2 ;;
        chatgpt) verify_app '/Applications/ChatGPT.app' com.openai.codex ;;
        claude) verify_app '/Applications/Claude.app' com.anthropic.claudefordesktop ;;
        brave-browser) verify_app '/Applications/Brave Browser.app' com.brave.Browser ;;
        codex) verify_cli "$HOMEBREW_PREFIX/bin/codex" ;;
        visual-studio-code) verify_app '/Applications/Visual Studio Code.app' com.microsoft.VSCode ;;
        google-chrome) verify_app '/Applications/Google Chrome.app' com.google.Chrome ;;
        spotify) verify_app '/Applications/Spotify.app' com.spotify.client ;;
        bitwarden) verify_app '/Applications/Bitwarden.app' com.bitwarden.desktop ;;
        aerospace) verify_app '/Applications/AeroSpace.app' bobko.aerospace ;;
        discord) verify_app '/Applications/Discord.app' com.hnc.Discord ;;
        obsidian) verify_app '/Applications/Obsidian.app' md.obsidian ;;
        font-*)
            local font found=0
            while IFS= read -r font; do
                case "$font" in *.ttf|*.otf) [[ -s "$font" ]] && found=1 ;; esac
            done < <(brew list --cask "${1##*/}")
            [[ "$found" == 1 ]] || { echo "Font files absent: $1" >&2; return 1; } ;;
        *) return 1 ;;
    esac
}
formula_artifact() {
    case "$1" in
        nvm) test -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ;;
        python) "$HOMEBREW_PREFIX/bin/python3" --version ;;
        ripgrep) "$HOMEBREW_PREFIX/bin/rg" --version ;;
        *) "$HOMEBREW_PREFIX/bin/$1" --version ;;
    esac
}

install_brew_main() {
    local phase=all verify=0 list=0 target failed=0
    if [[ "${1:-}" == --maintenance ]]; then
        [[ $# == 1 ]] || return 2
        echo 'Explicit maintenance: ensure the AI/terminal host has a safe handoff first.'
        brew upgrade && brew cleanup && brew services cleanup
        return
    fi
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --phase) [[ $# -ge 2 ]] || return 2; phase=$2; shift 2 ;;
            --verify-only) verify=1; shift ;;
            --list) list=1; shift ;;
            *) echo "Unknown argument: $1" >&2; return 2 ;;
        esac
    done
    local formulae=() casks=()
    case "$phase" in
        minimal) casks=("${MINIMAL_CASKS[@]}") ;;
        remaining) formulae=("${REMAINING_FORMULAE[@]}"); casks=("${REMAINING_CASKS[@]}") ;;
        all) formulae=("${REMAINING_FORMULAE[@]}"); casks=("${MINIMAL_CASKS[@]}" "${REMAINING_CASKS[@]}") ;;
        *) echo "Invalid phase: $phase" >&2; return 2 ;;
    esac
    if [[ $list == 1 ]]; then
        for target in "${formulae[@]}"; do printf 'formula %s\n' "$target"; done
        for target in "${casks[@]}"; do printf 'cask %s\n' "$target"; done
        return 0
    fi
    export HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_INSTALL_UPGRADE=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
    HOMEBREW_PREFIX=$(brew --prefix) || return 1
    export HOMEBREW_PREFIX
    if [[ $verify == 0 && "$phase" != minimal ]]; then brewTap felixkratz/formulae || return 1; fi
    for target in "${formulae[@]}"; do
        if [[ $verify == 0 ]]; then brewInstall "$target" "$target" || { failed=1; continue; }; fi
        brew_formula_present "$target" && formula_artifact "$target" || { echo "Formula readiness failed: $target" >&2; failed=1; }
    done
    for target in "${casks[@]}"; do
        if [[ $verify == 0 ]]; then caskInstall "$target" "$target" || { failed=1; continue; }; fi
        brew list --cask "${target##*/}" >/dev/null 2>&1 && cask_artifact "$target" || { echo "Cask readiness failed: $target" >&2; failed=1; }
    done
    [[ $failed == 0 ]] || return 1
    echo "Selected $phase package receipts and artifacts verified; human first-open validation remains pending."
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then install_brew_main "$@"; fi
