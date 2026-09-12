# Match install_node.sh: Homebrew owns nvm.sh; NVM_DIR stores user Node versions.
export NVM_DIR="$HOME/.nvm"
if [[ -n "${HOMEBREW_PREFIX:-}" && -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ]]; then
    source "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
fi
