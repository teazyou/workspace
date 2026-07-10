# `sopaios [args]` = `claude [args]` with the SOPAIOS plugin loaded from disk
# (--plugin-dir), so each session picks up the current working copy instead of
# a cached install. Same script backs the VS Code extension's
# `claudeCode.claudeProcessWrapper` setting. Lives at scripts/claude/sopaios.sh.
alias sopaios="$SCRIPTS/claude/sopaios.sh"
