#!/bin/bash

source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/colors.sh"

# Check if Wi-Fi interface has an IP address (works on macOS 26+)
WIFI_IP=$(ipconfig getifaddr en0 2>/dev/null)

if [ -n "$WIFI_IP" ]; then
  ICON=$WIFI_CONNECTED
  COLOR=$PINK
else
  ICON=$WIFI_DISCONNECTED
  COLOR=$GREY
fi

sketchybar --set $NAME icon=$ICON icon.color=$COLOR
