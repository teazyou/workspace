#!/bin/bash

source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/colors.sh"

# Get actual ethernet interfaces (exclude Wi-Fi which is usually en0)
# Use networksetup to find real ethernet adapters
ETHERNET_STATUS=""

while IFS= read -r line; do
  if [[ "$line" =~ ^Device:\ (en[0-9]+)$ ]]; then
    IFACE="${BASH_REMATCH[1]}"
    if ifconfig "$IFACE" 2>/dev/null | grep -q "status: active"; then
      ETHERNET_STATUS="active"
      break
    fi
  fi
done < <(networksetup -listallhardwareports | grep -A1 "Ethernet Adapter\|Thunderbolt Ethernet\|USB.*LAN")

if [ -n "$ETHERNET_STATUS" ]; then
  ICON=$ETHERNET_CONNECTED
  COLOR=$PINK
else
  ICON=$ETHERNET_DISCONNECTED
  COLOR=$GREY
fi

sketchybar --set $NAME icon=$ICON icon.color=$COLOR
