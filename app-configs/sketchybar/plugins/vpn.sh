#!/bin/bash

source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/colors.sh"

VPN_STATUS=""

# Check NordVPN connection status
NORDVPN_STATUS=$(defaults read com.nordvpn.macos isAppWasConnectedToVPN 2>/dev/null)
if [ "$NORDVPN_STATUS" = "1" ]; then
  VPN_STATUS="connected"
fi

# Fallback: Check system VPN connections
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
