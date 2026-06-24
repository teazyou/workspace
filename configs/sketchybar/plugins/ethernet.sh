#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/theme.sh"   # DIVISION_PAD, ELEMENT_GAP

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

# Show the icon only when connected; otherwise collapse it (icon.drawing=off +
# zero padding) so the connectivity group has no ethernet gap. The item stays
# drawing=on regardless so this poller keeps running.
if [ -n "$ETHERNET_STATUS" ]; then
  sketchybar --set $NAME icon.drawing=on icon=$ETHERNET_CONNECTED icon.color=$PINK \
                         icon.padding_left=$ELEMENT_GAP icon.padding_right=0
else
  sketchybar --set $NAME icon.drawing=off icon.padding_left=0 icon.padding_right=0
fi
