#!/bin/sh
#
# sopaios.sh — launch Claude Code with the SOPAIOS plugin loaded from disk
# (development mode), i.e. `claude --plugin-dir <plugin> "$@"`.
#
# Two consumers:
#   1. Terminal — the `sopaios` alias (zsh/alias/claude.zsh) calls this script;
#      `sopaios [args]` behaves exactly like `claude [args]` + the plugin flag.
#   2. VS Code — the anthropic.claude-code extension has no setting for CLI
#      args, but its `claudeCode.claudeProcessWrapper` setting ("Executable
#      path used to launch the Claude process") is spawned AS the claude
#      executable, receiving only the extension's own runtime flags. Pointing
#      that setting at this script's absolute path injects --plugin-dir ahead
#      of them. VS Code must be reloaded for a setting change to take effect.
#
# Overridable via env:
#   SOPAIOS_PLUGIN_DIR   plugin working copy (default below)
#   SOPAIOS_CLAUDE_BIN   real claude binary (default below)
#
# The claude path is absolute on purpose: the VS Code extension host's PATH is
# not the interactive shell's PATH, so a bare `claude` may not resolve.

set -eu

PLUGIN_DIR="${SOPAIOS_PLUGIN_DIR:-/Users/teazyou/dev/client-edouard/.sopaios}"
CLAUDE_BIN="${SOPAIOS_CLAUDE_BIN:-$HOME/.local/bin/claude}"

if [ ! -d "$PLUGIN_DIR" ]; then
  echo "sopaios.sh: plugin dir not found: $PLUGIN_DIR" >&2
  exit 1
fi

# The extension resolves `executableArgs` from a bundled CLI it ships. On this
# install it ships none, so executableArgs is [] and we are spawned directly.
# If a future version bundles one, we are instead invoked as
#   sopaios.sh <node> <cli.js> ...args
# and must exec that pair rather than CLAUDE_BIN. Detect it: arg 1 an existing
# executable file + arg 2 a .js file.
if [ $# -ge 2 ] && [ -x "$1" ] && [ ! -d "$1" ] && [ "${2%.js}" != "$2" ] && [ -f "$2" ]; then
  node="$1"
  cli="$2"
  shift 2
  exec "$node" "$cli" --plugin-dir "$PLUGIN_DIR" "$@"
fi

if [ ! -x "$CLAUDE_BIN" ]; then
  echo "sopaios.sh: claude binary not found/executable: $CLAUDE_BIN" >&2
  exit 1
fi

exec "$CLAUDE_BIN" --plugin-dir "$PLUGIN_DIR" "$@"
