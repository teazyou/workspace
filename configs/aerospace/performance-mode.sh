#!/bin/bash
# Performance mode toggle — reduces macOS UI overhead (SketchyBar,
# display-profile LaunchAgent) for resource-intensive tasks.
# JankyBorders is intentionally left running (same as normal mode).

set -euo pipefail

source ~/workspace/configs/aerospace/lib-paths.sh

STATE_FILE="$PERFORMANCE_MODE_STATE"
DISPLAY_PROFILE_PLIST="$HOME/Library/LaunchAgents/com.aerospace.display-profile.plist"
GUI_DOMAIN="gui/$(id -u)"

# SketchyBar items to hide/restore
ITEMS_WITH_LABEL=(volume network_down network_up)
ITEMS_ICON_ONLY=(headset)
BRACKETS=(audio traffic)
SPACERS=(spacer0 spacer1 spacer2 spacer3)

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

  # Hide sketchybar items
  for item in "${ITEMS_WITH_LABEL[@]}" "${ITEMS_ICON_ONLY[@]}"; do
    sketchybar --set "$item" drawing=off icon.drawing=off label.drawing=off update_freq=0
  done

  for bracket in "${BRACKETS[@]}"; do
    sketchybar --set "$bracket" drawing=off
  done

  for spacer in "${SPACERS[@]}"; do
    sketchybar --set "$spacer" drawing=off icon.drawing=off label.drawing=off update_freq=0
  done

  echo "on" > "$STATE_FILE"
  echo "Performance mode ON"
}

performance_mode_off() {
  # Restart display-profile LaunchAgent — verify it actually loaded rather than
  # swallowing a bootstrap race, which would leave it unloaded until a full WM
  # restart.
  ensure_loaded "$DISPLAY_PROFILE_PLIST" || true

  # Restore sketchybar items (with labels)
  for item in "${ITEMS_WITH_LABEL[@]}"; do
    sketchybar --set "$item" drawing=on icon.drawing=on label.drawing=on update_freq=5
  done

  # Restore icon-only items (label stays off)
  for item in "${ITEMS_ICON_ONLY[@]}"; do
    sketchybar --set "$item" drawing=on icon.drawing=on update_freq=5
  done

  for bracket in "${BRACKETS[@]}"; do
    sketchybar --set "$bracket" drawing=on
  done

  for spacer in "${SPACERS[@]}"; do
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
