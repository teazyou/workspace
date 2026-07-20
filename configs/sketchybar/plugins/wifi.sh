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
