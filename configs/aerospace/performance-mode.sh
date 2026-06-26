#!/bin/bash
# Performance mode toggle — reduces macOS UI overhead (SketchyBar,
# display-profile LaunchAgent) for resource-intensive tasks.
# JankyBorders is intentionally left running (same as normal mode).

set -euo pipefail

source ~/workspace/configs/aerospace/lib-paths.sh

STATE_FILE="$PERFORMANCE_MODE_STATE"
DISPLAY_PROFILE_PLIST="$HOME/Library/LaunchAgents/com.aerospace.display-profile.plist"
GUI_DOMAIN="gui/$(id -u)"

# Performance mode hides cpu + ram (battery stays) and the whole traffic group,
# but KEEPS the volume/audio and connectivity groups visible.
#
# IMPORTANT — single writer for traffic: the traffic items (network_down/up, the
# traffic_* brackets, spacer_ud, spacer3) are owned by plugins/network_speed.sh.
# This script must NOT also set them, or the two writers race during a toggle and
# split a division's decision (bracket shown, member hidden) → an empty pill. So
# perf mode only flips the STATE FILE + the poller (network_down drawing/freq) and
# then runs network_speed.sh once; network_speed reads the state file and hides the
# whole traffic group itself, consistently. cpu/ram are independent, so we toggle
# them directly here.
RESOURCE_ITEMS=(cpu ram)
NET_SPEED="$HOME/.config/sketchybar/plugins/network_speed.sh"

# Inter-division spacers that stay one uniform GROUP_GAP between the always-visible
# groups (connectivity | resources | audio | calendar). The traffic spacers
# (spacer3 / spacer_ud) are NOT here — network_speed.sh draws them only when a
# direction is actually visible.
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

  # Write the state FIRST so any network_speed.sh run (the one we trigger below, or
  # an in-flight poll tick) sees performance mode = on and hides the traffic group.
  echo "on" > "$STATE_FILE"

  # Hide resources + stop the traffic poller (network_down). drawing=off collapses
  # the item and update_freq=0 stops its plugin; with network_down hidden the poller
  # won't run again until OFF restores it.
  sketchybar --set cpu drawing=off update_freq=0 \
             --set ram drawing=off update_freq=0 \
             --set network_down drawing=off update_freq=0

  # Let network_speed.sh hide the traffic divisions itself (it reads the state file)
  # — the SOLE writer of those items, so no race with the poller can split a pill.
  # NET_SPEED_PERF=1 marks this as the AUTHORITATIVE run: it waits out any in-flight
  # poll tick on network_speed.sh's writer lock so it is the LAST writer. This closes
  # C1 (a stale in-flight tick cannot win the last `--set` and re-show a division
  # after perf-ON has stopped the poller).
  NET_SPEED_PERF=1 "$NET_SPEED"

  # Keep the inter-group spacers between the still-visible groups.
  for spacer in "${SPACERS_KEEP[@]}"; do
    sketchybar --set "$spacer" drawing=on
  done

  echo "Performance mode ON"
}

performance_mode_off() {
  # Restart display-profile LaunchAgent — verify it actually loaded rather than
  # swallowing a bootstrap race, which would leave it unloaded until a full WM
  # restart.
  ensure_loaded "$DISPLAY_PROFILE_PLIST" || true

  # Clear the state FIRST so network_speed.sh (the run below + the resumed poller)
  # computes real traffic visibility instead of the perf-mode hide.
  rm -f "$STATE_FILE"

  # Restore resources and resume the traffic poller (network_down). The traffic
  # ITEMS/brackets/spacers are NOT touched here — network_speed.sh owns them, so
  # this script and the poller can never disagree and leave an empty pill.
  sketchybar --set cpu drawing=on update_freq=5 \
             --set ram drawing=on update_freq=5 \
             --set network_down drawing=on update_freq=5

  # Drop the stale byte counters frozen during perf mode so the first recompute
  # reports a real (near-zero) delta, not a giant spike from the perf-mode gap.
  rm -f /tmp/sketchybar_network/prev_bytes

  # Keep the inter-group spacers between the always-visible groups.
  for spacer in "${SPACERS_KEEP[@]}"; do
    sketchybar --set "$spacer" drawing=on
  done

  # Recompute traffic visibility now (state is cleared, cache reset → clean
  # baseline) so the correct state lands immediately instead of after one poll.
  # Authoritative run (same lock policy as ON) so it wins the last write against
  # any in-flight tick; the resumed poller then keeps it correct from here on.
  NET_SPEED_PERF=1 "$NET_SPEED"

  # Force a full refresh of the remaining restored items.
  sketchybar --update

  echo "Performance mode OFF"
}

# Toggle based on current state
if [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE")" == "on" ]]; then
  performance_mode_off
else
  performance_mode_on
fi
