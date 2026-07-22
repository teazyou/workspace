#!/bin/bash

# Click handler for the vpn item (see docs/vpn/guide-nordvpn-native.md).
# 1. INSTANT feedback: paints the busy look (yellow icon + "…" label) before acting.
# 2. CLICK LOCK: a second click while an action is in flight is ignored (mkdir-atomic
#    lock dir; stolen if older than 200s = a crashed run — nord.sh's own internal
#    timeouts bound a healthy run well under that).
# plugins/vpn.sh renders the same busy look whenever the lock exists, so the 30s
# periodic repaint / vpn_change events can't overwrite the feedback mid-action.
source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/theme.sh"

CLICK_LOCK="/tmp/nordvpn-native.click"
NORD="$HOME/workspace/scripts/vpn/nord.sh"

now=$(date +%s)
if ! mkdir "$CLICK_LOCK" 2>/dev/null; then
  age=$(( now - $(stat -f %m "$CLICK_LOCK" 2>/dev/null || echo "$now") ))
  [ "$age" -lt 200 ] && exit 0          # action in flight — ignore the click
  rmdir "$CLICK_LOCK" 2>/dev/null       # stale lock from a crashed run — steal it
  mkdir "$CLICK_LOCK" 2>/dev/null || exit 0
fi
trap 'rmdir "$CLICK_LOCK" 2>/dev/null; sketchybar --trigger vpn_change 2>/dev/null' EXIT

sketchybar --set vpn icon.color="$YELLOW" label="…" label.drawing=on \
           label.color="$YELLOW" label.padding_right="$DIVISION_PAD" icon.padding_right="$ELEMENT_GAP"

bash "$NORD" toggle >/dev/null 2>&1

# release + settle BEFORE the final repaint: nord.sh fires its own vpn_change on
# completion (while the lock is still held -> painted busy); triggering again too
# fast gets coalesced with it and the stale busy look sticks until the next tick.
rmdir "$CLICK_LOCK" 2>/dev/null
sleep 1
