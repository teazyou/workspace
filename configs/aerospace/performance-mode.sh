#!/bin/bash
# Performance mode toggle — reduces macOS UI overhead (SketchyBar,
# display-profile LaunchAgent) for resource-intensive tasks.
# JankyBorders is intentionally left running (same as normal mode).

set -euo pipefail

source ~/workspace/configs/aerospace/lib-paths.sh

STATE_FILE="$PERFORMANCE_MODE_STATE"
DISPLAY_PROFILE_PLIST="$HOME/Library/LaunchAgents/com.aerospace.display-profile.plist"
GUI_DOMAIN="gui/$(id -u)"

# SketchyBar items hidden in performance mode (their pollers stop too). We hide
# cpu + ram (battery stays) and the traffic group, but KEEP the volume/audio and
# connectivity groups visible. Toggling the item-level `drawing` hides the whole
# item while preserving each item's own icon/label config (ram has no icon, volume
# has its muted state), so we don't force icon.drawing here.
ITEMS_HIDE=(cpu ram network_down network_up)
BRACKETS=(traffic)

# Inter-division spacers. Only the traffic group is hidden now, so only spacer3
# (its leading spacer) is dropped; spacer0/1/2 stay so connectivity | resources |
# audio | calendar keep one uniform GROUP_GAP between them — same as normal mode.
SPACERS_ALL=(spacer0 spacer1 spacer2 spacer3)
SPACERS_HIDE=(spacer3)
SPACERS_KEEP=(spacer0 spacer1 spacer2)

# Bootstrap a LaunchAgent and verify it actually loaded, rather than swallowing
# a bootstrap race with `|| true`. If the verify fails, retry once after a short
# settle, then kickstart it. Returns 0 on success, 1 if it still isn't loaded.
ensure_loaded() {
  local plist="$1"
  local label
  label="$(basename "$plist" .plist)"

  launchctl bootstrap "$GUI_DOMAIN" "$plist" 2>/dev/null || true
  if launchctl print "$GUI_DOMAIN/$label" >/dev/null 2>&1; then
    return 0
  fi

  sleep 0.3
  launchctl bootstrap "$GUI_DOMAIN" "$plist" 2>/dev/null || true
  if launchctl print "$GUI_DOMAIN/$label" >/dev/null 2>&1; then
    launchctl kickstart "$GUI_DOMAIN/$label" 2>/dev/null || true
    return 0
  fi

  return 1
}

performance_mode_on() {
  # Stop display-profile LaunchAgent
  launchctl bootout "$GUI_DOMAIN" "$DISPLAY_PROFILE_PLIST" 2>/dev/null || true

  # Hide sketchybar items (whole-item drawing off also stops their pollers)
  for item in "${ITEMS_HIDE[@]}"; do
    sketchybar --set "$item" drawing=off update_freq=0
  done

  for bracket in "${BRACKETS[@]}"; do
    sketchybar --set "$bracket" drawing=off
  done

  for spacer in "${SPACERS_HIDE[@]}"; do
    sketchybar --set "$spacer" drawing=off
  done
  for spacer in "${SPACERS_KEEP[@]}"; do
    sketchybar --set "$spacer" drawing=on
  done

  echo "on" > "$STATE_FILE"
  echo "Performance mode ON"
}

performance_mode_off() {
  # Restart display-profile LaunchAgent — verify it actually loaded rather than
  # swallowing a bootstrap race, which would leave it unloaded until a full WM
  # restart.
  ensure_loaded "$DISPLAY_PROFILE_PLIST" || true

  # Restore the hidden items (item-level drawing only; each item keeps its own
  # icon/label config and the next poll repaints values/visibility).
  for item in "${ITEMS_HIDE[@]}"; do
    sketchybar --set "$item" drawing=on update_freq=5
  done

  for bracket in "${BRACKETS[@]}"; do
    sketchybar --set "$bracket" drawing=on
  done

  for spacer in "${SPACERS_ALL[@]}"; do
    sketchybar --set "$spacer" drawing=on
  done

  # Force full refresh
  sketchybar --update

  rm -f "$STATE_FILE"
  echo "Performance mode OFF"
}

# Toggle based on current state
if [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE")" == "on" ]]; then
  performance_mode_off
else
  performance_mode_on
fi
