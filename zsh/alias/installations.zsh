# Aliases to re-run any individual install step from a normal shell.
# Each script in scripts/installs/ is idempotent, so calling these on an
# already-set-up system is safe — they will skip what's already done.
#
# The full system install is `installation` (runs all steps in order).

# Full orchestrator
alias installation="bash $SCRIPTS/installs/installation.sh"

# Individual steps
alias install_brew="bash $SCRIPTS/installs/install_brew.sh"
alias install_oh_my_zsh="bash $SCRIPTS/installs/install_oh_my_zsh.sh"
alias install_claude="bash $SCRIPTS/installs/install_claude.sh"
alias install_iterm2="bash $SCRIPTS/installs/install_iterm2.sh"
alias install_vscode_ext="bash $SCRIPTS/installs/install_vscode_ext.sh"
alias install_touch_id_sudo="bash $SCRIPTS/installs/install_touch_id_sudo.sh"
alias install_window_manager="bash $SCRIPTS/installs/install_window_manager.sh"
alias install_node="bash $SCRIPTS/installs/install_node.sh"
alias install_database="bash $SCRIPTS/installs/install_database.sh"
alias install_xcode="bash $SCRIPTS/installs/install_xcode_mas.sh"
alias setup_symlinks="bash $SCRIPTS/installs/setup_symlinks.sh"
alias setup_macos="bash $SCRIPTS/installs/setup_macos.sh"
alias setup_wallpaper="bash $SCRIPTS/installs/setup_wallpaper.sh"
alias clone_repos="bash $SCRIPTS/installs/clone_repos.sh"
