# RUN THE FOLLOWING TO SETUP WORKSPACE:
# echo "source ~/workspace/zshrc.zsh" >> ~/.zshrc && source ~/.zshrc

echo Workspace Loading!

reload () { source ~/.zshrc }

# EXPORT PATH TO FALICIATE SCRIPTING AND SUCH
source ~/workspace/zsh/configs/path.zsh

# COLORS CONFIGS (SOME EXPORT FOR TERMINAL DECORATION IN SCRIPTS)
source $ZSH_CONFIGS/colors.zsh

# OH-MY-ZSH CONFIGS (THEME, PLUGINS, ETC)
source $ZSH_CONFIGS/oh-my-zsh.zsh

# GIT CONFIGS
source $ZSH_CONFIGS/git.zsh

# NVM CONFIGS
source $ZSH_CONFIGS/nvm.zsh

# ZSH CONFIG FROM INSTALLATION FOLDER
source $ZSH/oh-my-zsh.sh

# ALIAS
source $ZSH_ALIAS/osx.zsh
source $ZSH_ALIAS/navigation.zsh
source $ZSH_ALIAS/git.zsh
source $ZSH_ALIAS/installations.zsh

echo Workspace Loaded!
