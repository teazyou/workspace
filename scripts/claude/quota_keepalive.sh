#!/bin/bash
#
# quota_keepalive.sh — keep the Claude Code 5-hour usage-limit block cycling.
#
# The subscription quota works in 5-hour blocks that start on the FIRST message
# sent. This script sends a near-zero-cost "hello" to the haiku model every run
# (launchd fires it hourly), so a new block starts at most ~1 h after
# the previous one expires. Net effect: after any long absence, the current
# block is already partly elapsed and resets sooner instead of restarting the
# full 5 hours on your first real prompt.
#
# EXPERIMENTAL — deliberately NOT wired into the fresh-Mac install flow
# (installation.sh / setup_symlinks.sh). Loaded by a standalone LaunchAgent:
#   plist:   configs/claude/com.teazyou.claude-quota-keepalive.plist
#            (symlinked into ~/Library/LaunchAgents/)
#   load:    launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.teazyou.claude-quota-keepalive.plist
#   DISABLE: launchctl bootout   gui/$UID/com.teazyou.claude-quota-keepalive
#            rm ~/Library/LaunchAgents/com.teazyou.claude-quota-keepalive.plist
#
# Mechanics: interactive `claude` (NOT -p print mode, soon API-wallet-gated)
# needs a TTY for its Ink UI — launchd provides none, so the call is wrapped in
# `script -q /dev/null` which allocates a pseudo-TTY. The session is killed
# after WAIT_SECONDS; the request has been sent by then, which is all that is
# needed to (re)arm the quota block.
#
# Requires: jq (for the one-time ~/tmp trust seeding). Logs one line per run.

CLAUDE_BIN="${QUOTA_KEEPALIVE_CLAUDE_BIN:-$HOME/.local/bin/claude}"
WORK_DIR="$HOME/tmp"
LOG_FILE="$HOME/workspace/logs/quota_keepalive.log"
WAIT_SECONDS=15

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"; }

if [ ! -x "$CLAUDE_BIN" ]; then
  log "KO claude binary not found: $CLAUDE_BIN"
  exit 1
fi

mkdir -p "$WORK_DIR"
cd "$WORK_DIR" || { log "KO cannot cd to $WORK_DIR"; exit 1; }

# Headless run cannot answer the folder-trust dialog, which would block the
# prompt from ever being submitted. Seed the trust flag for ~/tmp once.
CLAUDE_JSON="$HOME/.claude.json"
if [ -f "$CLAUDE_JSON" ] && command -v jq >/dev/null 2>&1; then
  if [ "$(jq -r --arg d "$WORK_DIR" '.projects[$d].hasTrustDialogAccepted // false' "$CLAUDE_JSON")" != "true" ]; then
    tmp_json=$(mktemp) &&
      jq --arg d "$WORK_DIR" '.projects[$d] = ((.projects[$d] // {}) + {hasTrustDialogAccepted: true})' \
        "$CLAUDE_JSON" > "$tmp_json" &&
      mv "$tmp_json" "$CLAUDE_JSON" &&
      log "OK seeded trust for $WORK_DIR in ~/.claude.json"
  fi
fi

script -q /dev/null "$CLAUDE_BIN" --model haiku "hello" >/dev/null 2>&1 &
WRAPPER_PID=$!

sleep "$WAIT_SECONDS"

# Collect the claude child before killing the pty wrapper (it gets reparented
# once the wrapper dies and would no longer be findable via -P).
CHILD_PIDS=$(pgrep -P "$WRAPPER_PID" 2>/dev/null | tr '\n' ' ')
kill "$WRAPPER_PID" $CHILD_PIDS 2>/dev/null
sleep 2
kill -9 "$WRAPPER_PID" $CHILD_PIDS 2>/dev/null

log "OK pinged haiku (wrapper pid $WRAPPER_PID, killed after ${WAIT_SECONDS}s)"
