#!/usr/bin/env bash
# workspace-patch — re-apply ALL local app patches in one command.
# Fronted by the `workspace-patch` alias (zsh/alias/patch.zsh).
#
# Runs, in order:
#   1. Obsidian transparency asar patch  → scripts/obsidian/patch-transparency.sh
#      NOTE: this QUITS Obsidian if it is running (the asar can't be swapped live).
#   2. Claude Code VS Code panel patch   → scripts/claude/patch-vscode-panel.sh
#      Reload the VS Code window afterwards (Cmd+Shift+P → Developer: Reload Window).
#
# Both patches are idempotent — safe to re-run any time. Run after an Obsidian or
# Claude Code update. (A version-watcher LaunchAgent can do this automatically —
# see docs/scripts/version-watcher.md.)
#
# -e is intentionally OFF so a failure in one patch doesn't skip the other.
set -uo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> [1/2] Obsidian transparency patch"
"$SCRIPTS_DIR/obsidian/patch-transparency.sh" || echo "  (obsidian patch returned nonzero — see output above)"

echo
echo "==> [2/2] Claude Code VS Code panel patch"
"$SCRIPTS_DIR/claude/patch-vscode-panel.sh" || echo "  (claude panel patch returned nonzero — see output above)"

echo
echo "==> Done. Relaunch Obsidian; reload the VS Code window (Cmd+Shift+P → Developer: Reload Window)."
