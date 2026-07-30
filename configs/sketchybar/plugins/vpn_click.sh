#!/bin/bash

# Click handler SHARED by both vpn items (vpn_be, vpn_sn); $NAME says which one.
# 1. DECIDE: clicking the UNDERLINED icon (the currently SELECTED country,
#    ~/.config/nordvpn-native/country) toggles it on/off (`nord toggle`); clicking
#    the other (un-underlined) icon switches to that country and turns it on (`nord <cc>` —
#    which writes country + enabled and clears refresh-needed itself).
# 2. INSTANT feedback: paints the clicked icon busy (yellow "…") before acting.
# 3. CLICK LOCK: ONE lock shared by BOTH icons (/tmp/nordvpn-native.click) — a second
#    click on EITHER icon while an action is in flight is ignored (mkdir-atomic lock
#    dir; stolen if older than 200s = a crashed run — nord.sh's own timeouts bound a
#    healthy run well under that). The clicked item's name goes into
#    $CLICK_LOCK/owner so plugins/vpn.sh keeps the busy look on the RIGHT icon while
#    the other one keeps rendering its real state.
#    Keeping the lock SHARED is load-bearing for the single-VPN-slot rule: with
#    per-icon locks two nord.sh runs would race, and the loser would just block ~60s
#    on nord.sh's own /tmp/nordvpn-native.lock and silently do nothing.
source "$HOME/.config/sketchybar/colors.sh"

CFG_DIR="$HOME/.config/nordvpn-native"
CLICK_LOCK="/tmp/nordvpn-native.click"
CLICK_STALE=200                     # keep in sync with plugins/vpn.sh
NORD="$HOME/workspace/scripts/vpn/nord.sh"

# NOTE: "SN" is the display label only — Singapore's code everywhere else is `sg`.
case "${NAME:-}" in
  vpn_be) MY_CC=be ;;
  vpn_sn) MY_CC=sg ;;
  *) exit 0 ;;                      # not one of ours (e.g. run by hand without NAME)
esac

COUNTRY=$(cat "$CFG_DIR/country" 2>/dev/null); COUNTRY=${COUNTRY:-sg}
if [ "$MY_CC" = "$COUNTRY" ]; then ACTION=toggle; else ACTION="$MY_CC"; fi

release() { rm -f "$CLICK_LOCK/owner" 2>/dev/null; rmdir "$CLICK_LOCK" 2>/dev/null; }

now=$(date +%s)
if ! mkdir "$CLICK_LOCK" 2>/dev/null; then
  age=$(( now - $(stat -f %m "$CLICK_LOCK" 2>/dev/null || echo "$now") ))
  [ "$age" -lt "$CLICK_STALE" ] && exit 0   # action in flight — ignore the click
  release                                   # stale lock from a crashed run — steal it
  mkdir "$CLICK_LOCK" 2>/dev/null || exit 0
fi
echo "$NAME" > "$CLICK_LOCK/owner"
trap 'release; sketchybar --trigger vpn_change 2>/dev/null' EXIT

# Instant busy feedback. The underline only ever sits under the SELECTED icon, so
# recolour it with the busy colour on the toggle branch and leave it hidden otherwise:
# a switch click must NOT grow an underline on the icon it is switching TO — the
# selection moves only once nord.sh has written `country` (and plugins/vpn.sh repaints).
if [ "$ACTION" = toggle ]; then RULE=$YELLOW; else RULE=$TRANSPARENT; fi
sketchybar --set "$NAME" label="…" label.color="$YELLOW" icon.color="$RULE"

bash "$NORD" "$ACTION" >/dev/null 2>&1

# release + settle BEFORE the final repaint: nord.sh fires its own vpn_change on
# completion (while the lock is still held -> painted busy); triggering again too
# fast gets coalesced with it and the stale busy look sticks until the next tick.
release
sleep 1
