# PATH
export KEYS_DKT=~/keys/dkt
export WORKSPACE=~/workspace
export SCRIPTS=~/workspace/scripts
export APP_CONFIGS=~/workspace/configs
export FUNCTIONS=~/workspace/functions
export ZSH_CONFIGS=$WORKSPACE/zsh/configs
export ZSH_ALIAS=$WORKSPACE/zsh/alias

# ZSH
export ZSH=~/.oh-my-zsh

# Native Homebrew first, then the sole native Claude CLI. New shells activate it.
case "$(uname -m)" in
    arm64) _workspace_brew=/opt/homebrew/bin/brew ;;
    x86_64) _workspace_brew=/usr/local/bin/brew ;;
    *) _workspace_brew= ;;
esac
if [[ -n "$_workspace_brew" && -x "$_workspace_brew" ]]; then
    eval "$("$_workspace_brew" shellenv)"
fi
unset _workspace_brew
export PATH_CLAUDE="$HOME/.local/bin"
export PATH="$PATH_CLAUDE:$PATH"
