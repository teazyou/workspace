#!/bin/bash

source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/colors.sh"

VPN_STATUS=""

# NordVPN (NordLynx/WireGuard) brings up a utun with an IPv4 in 10.5.0.0/16
# when connected. The always-present IPv6-only utun interfaces are ignored.
# Fallback for OpenVPN mode: broaden to /inet (10|172|100)\./ if needed.
if ifconfig 2>/dev/null | awk '/^utun/{i=$1} /inet 10\.5\./{found=1} END{exit !found}'; then
  VPN_STATUS="connected"
fi

# Fallback: registered NetworkExtension VPN services (covers IKEv2/L2TP if ever configured)
if [ -z "$VPN_STATUS" ]; then
  VPN_STATUS=$(scutil --nc list 2>/dev/null | grep "(Connected)")
fi

if [ -n "$VPN_STATUS" ]; then
  ICON=$VPN_CONNECTED
  COLOR=$PINK
else
  ICON=$VPN_DISCONNECTED
  COLOR=$GREY
fi

sketchybar --set $NAME icon=$ICON icon.color=$COLOR
