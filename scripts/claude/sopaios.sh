#!/bin/sh
#
# sopaios.sh — launch Claude Code with the SOPAIOS plugin loaded from disk
# (development mode), i.e. `claude --plugin-dir <plugin> "$@"`.
#
# Consumer: the `sopaios` terminal alias (zsh/alias/claude.zsh);
# `sopaios [args]` behaves exactly like `claude [args]` + the plugin flag.
#
# Overridable via env:
#   SOPAIOS_PLUGIN_DIR   plugin working copy (default below)
#   SOPAIOS_CLAUDE_BIN   real claude binary (default below)

set -eu

PLUGIN_DIR="${SOPAIOS_PLUGIN_DIR:-/Users/teazyou/dev/client-edouard/.sopaios}"
CLAUDE_BIN="${SOPAIOS_CLAUDE_BIN:-$HOME/.local/bin/claude}"

if [ ! -d "$PLUGIN_DIR" ]; then
  echo "sopaios.sh: plugin dir not found: $PLUGIN_DIR" >&2
  exit 1
fi

if [ ! -x "$CLAUDE_BIN" ]; then
  echo "sopaios.sh: claude binary not found/executable: $CLAUDE_BIN" >&2
  exit 1
fi

exec "$CLAUDE_BIN" --plugin-dir "$PLUGIN_DIR" "$@"
