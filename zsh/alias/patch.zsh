# `workspace-patch` re-applies ALL local app patches in one command:
#   • Obsidian transparency asar patch (scripts/obsidian/patch-transparency.sh)
#   • Claude Code VS Code panel patch  (scripts/claude/patch-vscode-panel.sh)
# Run after an Obsidian or Claude Code update. NOTE: it QUITS Obsidian if running.
# The runner lives at scripts/workspace-patch.sh; see docs/obsidian/transparency.md
# and docs/vscode/claude-code-panel.md for what each patch does.
alias workspace-patch="bash $SCRIPTS/workspace-patch.sh"
