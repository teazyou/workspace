#!/bin/bash
# Performance mode toggle — reduces macOS UI overhead (SketchyBar,
# JankyBorders, display-profile LaunchAgent) for resource-intensive tasks.

set -euo pipefail

STATE_FILE="/tmp/performance-mode.state"
DISPLAY_PROFILE_PLIST="$HOME/Library/LaunchAgents/com.aerospace.display-profile.plist"
GUI_DOMAIN="gui/$(id -u)"

# SketchyBar items to hide/restore
ITEMS_WITH_LABEL=(volume ram cpu battery network_down network_up)
ITEMS_ICON_ONLY=(headset vpn wifi ethernet)
BRACKETS=(audio traffic resources connectivity)
SPACERS=(spacer0 spacer1 spacer2 spacer3)

gaming_mode_on() {
  # Stop JankyBorders
  killall borders 2>/dev/null || true

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

gaming_mode_off() {
  # Restart JankyBorders
  borders active_color=0xffe08030 inactive_color=0xff3a2a35 width=2.0 style=round hidpi=on order=above &

  # Restart display-profile LaunchAgent
  launchctl bootstrap "$GUI_DOMAIN" "$DISPLAY_PROFILE_PLIST" 2>/dev/null || true

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
  gaming_mode_off
else
  gaming_mode_on
fi
