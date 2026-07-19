#!/bin/bash
#
# patch-watcher.sh — re-apply app patches automatically after an app UPDATES.
#
# Two hand-maintained patches in this repo are wiped by their app's own updater
# (each update ships a fresh bundle that has never seen our edits):
#   1. Obsidian window transparency       -> scripts/obsidian/patch-transparency.sh
#      invalidated by the OBSIDIAN APP version.
#   2. Claude Code VS Code panel styling   -> scripts/claude/patch-vscode-panel.sh
#      invalidated by the CLAUDE CODE EXTENSION version (NOT the VS Code app
#      version — the patch lives inside the extension's own files, so only an
#      extension bump undoes it).
#
# This watcher runs on a timer (launchd, every 30 min). Each tick it reads the
# current version of each tool, compares it to the last-recorded version in a
# state file, and if they differ (or nothing is recorded yet) re-runs ONLY that
# tool's patch, then records the new version so it doesn't re-run needlessly.
# The patch scripts are idempotent, so a first run with no state is harmless.
#
# OBSIDIAN SAFETY (defer while running):
#   patch-transparency.sh QUITS Obsidian if it is running (the asar is memory-
#   mapped while the app runs). So we NEVER patch Obsidian while it is open — we
#   log "deferred (Obsidian running)" and leave the recorded version unchanged,
#   so the update is retried on a later tick once the app is closed. The Claude
#   panel patch is safe to run anytime (it only edits files; the user just needs
#   a VS Code window reload later), so it is never deferred.
#
# FAILURE HANDLING:
#   On patch failure the recorded version is left unchanged, so the patch is
#   retried next tick. On success the new version is recorded.
#
# EXPERIMENTAL — deliberately NOT wired into the fresh-Mac install flow
# (installation.sh / setup_symlinks.sh). Loaded by a standalone LaunchAgent:
#   plist:   configs/claude/com.teazyou.patch-watcher.plist
#            (symlinked into ~/Library/LaunchAgents/)
#   load:    launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.teazyou.patch-watcher.plist
#   DISABLE: launchctl bootout   gui/$UID/com.teazyou.patch-watcher
#            rm ~/Library/LaunchAgents/com.teazyou.patch-watcher.plist
#
# The per-tick cost is a couple of plist/dir reads + a pgrep = a few ms, no
# network. See docs/scripts/version-watcher.md for the full rationale + how to
# change the interval.

export PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"

WORKSPACE="$HOME/workspace"
LOG_FILE="$WORKSPACE/logs/patch_watcher.log"
STATE_DIR="$WORKSPACE/logs/patch_state"
OBSIDIAN_PATCH="$WORKSPACE/scripts/obsidian/patch-transparency.sh"
CLAUDE_PATCH="$WORKSPACE/scripts/claude/patch-vscode-panel.sh"
OBSIDIAN_APP="/Applications/Obsidian.app"

mkdir -p "$STATE_DIR" "$(dirname "$LOG_FILE")"

# Self-trim the log to the last 1000 lines.
MAX_LINES=1000
if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt "$MAX_LINES" ]; then
  tail -n "$MAX_LINES" "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"; }

# --- version readers ---------------------------------------------------------

obsidian_version() {
  # CFBundleShortVersionString from the app bundle. Empty if not installed.
  [ -d "$OBSIDIAN_APP" ] || return 1
  defaults read "$OBSIDIAN_APP/Contents/Info" CFBundleShortVersionString 2>/dev/null
}

claude_ext_version() {
  # Newest anthropic.claude-code-* extension dir (same selection the patch
  # script uses: ls -dt … | head -1). Version parsed from the dir name:
  #   anthropic.claude-code-2.1.215-darwin-arm64  ->  2.1.215
  local dir name v
  dir=$(ls -dt "$HOME"/.vscode/extensions/anthropic.claude-code-*/ 2>/dev/null | head -1)
  [ -n "$dir" ] || return 1
  name=$(basename "$dir")
  v="${name#anthropic.claude-code-}"
  v="${v%%-darwin*}"
  [ -n "$v" ] || return 1
  printf '%s' "$v"
}

# --- generic tick handler ----------------------------------------------------
# args: <label> <state-filename> <current-version> <patch-script> <defer? 0|1>
handle_tool() {
  local label="$1" statefile="$2" current="$3" patch="$4" defer="$5"
  local path="$STATE_DIR/$statefile" recorded

  if [ -z "$current" ]; then
    return 0   # not installed — skip quietly, no log spam
  fi
  recorded=$(cat "$path" 2>/dev/null)

  if [ "$current" = "$recorded" ]; then
    return 0   # up to date, nothing to do
  fi

  if [ "$defer" = "1" ]; then
    log "$label update detected ($recorded -> $current) but deferred (Obsidian running); will retry"
    return 0   # leave recorded version unchanged so it retries when closed
  fi

  if [ ! -f "$patch" ]; then
    log "$label update detected ($recorded -> $current) but patch script missing: $patch"
    return 0
  fi

  log "$label update detected ($recorded -> $current) — applying patch"
  if /bin/bash "$patch" >> "$LOG_FILE" 2>&1; then
    printf '%s\n' "$current" > "$path"
    log "$label patched OK, recorded $current"
  else
    log "$label patch FAILED (exit $?); recorded version left at '$recorded' — will retry"
  fi
}

# --- Obsidian ----------------------------------------------------------------
OBS_VER=$(obsidian_version)
OBS_DEFER=0
if pgrep -x Obsidian >/dev/null 2>&1; then OBS_DEFER=1; fi
handle_tool "Obsidian" "obsidian.version" "$OBS_VER" "$OBSIDIAN_PATCH" "$OBS_DEFER"

# --- Claude Code VS Code extension -------------------------------------------
EXT_VER=$(claude_ext_version)
handle_tool "Claude-Code-ext" "claude-code-ext.version" "$EXT_VER" "$CLAUDE_PATCH" 0
