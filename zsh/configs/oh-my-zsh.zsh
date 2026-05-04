ZSH_THEME="gallois"

# For Hyphen: Case-sensitive completion must be off. _ and - will be interchangeable.
# CASE_SENSITIVE="true"
HYPHEN_INSENSITIVE="true"

# zstyle ':omz:update' mode disabled  # disable automatic updates
zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time
zstyle ':omz:update' frequency 1 # auto-update frequency in days

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# LANG, SOME REQUIRES IT
export LANG=en_US.UTF-8

# Standard plugins can be found in $ZSH/plugins/ # Custom plugins may be added to $ZSH_CUSTOM/plugins/ # Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(git)