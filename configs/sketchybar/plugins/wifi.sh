#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icons.sh"

HELPER_DIR="$HOME/.config/sketchybar/helpers"
RSSI_BIN="$HELPER_DIR/wifi_rssi"

# Self-build the CoreWLAN RSSI helper once if it's missing (needs Xcode CLT's
# swiftc). Reading the CURRENT link RSSI needs no scan and no Location permission,
# so it's cheap and non-disruptive. macOS 26 removed `airport` and neither
# networksetup nor ipconfig expose RSSI, hence the tiny helper.
if [ ! -x "$RSSI_BIN" ]; then
  swiftc -O "$HELPER_DIR/wifi_rssi.swift" -o "$RSSI_BIN" 2>/dev/null
fi

# Connected? (IPv4 on en0 — the reliable check on macOS 26.) Then read RSSI (dBm).
WIFI_IP=$(ipconfig getifaddr en0 2>/dev/null)
RSSI=""
[ -x "$RSSI_BIN" ] && RSSI=$("$RSSI_BIN" 2>/dev/null)

# ---- Strength icon ----------------------------------------------------------
if [ -z "$WIFI_IP" ]; then
  sketchybar --set "$NAME" icon=$WIFI_DISCONNECTED icon.color=$GREY
  exit 0
elif [ -z "$RSSI" ]; then
  # Connected but RSSI unreadable (no swiftc / helper failed): show the full glyph.
  sketchybar --set "$NAME" icon=$WIFI_CONNECTED icon.color=$PINK
  exit 0
elif [ "$RSSI" -ge -65 ]; then
  ICON=$WIFI_3
elif [ "$RSSI" -ge -75 ]; then
  ICON=$WIFI_2
else
  ICON=$WIFI_1
fi
sketchybar --set "$NAME" icon=$ICON icon.color=$PINK

# ---- Auto-reconnect on a weak HOME network ----------------------------------
# Acts ONLY when: connected to one of the listed home SSIDs AND signal is 1 bar
# (RSSI < WEAK_THRESHOLD) for DEBOUNCE consecutive polls AND no toggle in the last
# COOLDOWN seconds. Then bounces Wi-Fi off/on so macOS reassociates to the
# strongest AP. Disabled entirely when the SSID list is absent/empty — so this is
# opt-in and the strength icon above always works on its own.
HOME_FILE="$HOME/.config/sketchybar/wifi_home_ssids"
[ -f "$HOME_FILE" ] || exit 0

# Current SSID (cheap; ipconfig works on macOS 26 where networksetup is broken).
SSID=$(ipconfig getsummary en0 2>/dev/null | sed -n 's/^[[:space:]]*SSID : //p' | head -1)
[ -n "$SSID" ] || exit 0
grep -vE '^[[:space:]]*(#|$)' "$HOME_FILE" | grep -qxF -- "$SSID" || exit 0

WEAK_THRESHOLD=-75   # "1 bar"
DEBOUNCE=2           # consecutive weak polls before acting (ignores momentary dips)
COOLDOWN=180         # seconds between toggles (prevents flapping / reconnect loops)
CNT_FILE="/tmp/sketchybar_wifi_weak_count"
TS_FILE="/tmp/sketchybar_wifi_last_toggle"

if [ "$RSSI" -ge "$WEAK_THRESHOLD" ]; then
  echo 0 > "$CNT_FILE"   # signal recovered → reset the debounce counter
  exit 0
fi

CNT=$(( $(cat "$CNT_FILE" 2>/dev/null || echo 0) + 1 ))
echo "$CNT" > "$CNT_FILE"
[ "$CNT" -lt "$DEBOUNCE" ] && exit 0

NOW=$(date +%s)
LAST=$(cat "$TS_FILE" 2>/dev/null || echo 0)
[ $(( NOW - LAST )) -lt "$COOLDOWN" ] && exit 0

# Trigger: bounce Wi-Fi (backgrounded so we never block the bar) so macOS
# reassociates to the strongest available preferred network.
echo "$NOW" > "$TS_FILE"
echo 0 > "$CNT_FILE"
( networksetup -setairportpower en0 off; sleep 3; networksetup -setairportpower en0 on ) &
