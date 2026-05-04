#!/bin/bash

source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/colors.sh"

# Check for connected Bluetooth headphones/headset
# Look for headphones under "Connected:" section only
HEADSET_STATUS=$(system_profiler SPBluetoothDataType 2>/dev/null | awk '/Connected:/{flag=1} /Not Connected:/{flag=0} flag && /Minor Type: Headphones|Minor Type: Headset/{print}')

if [ -n "$HEADSET_STATUS" ]; then
  ICON=$HEADSET_CONNECTED
  COLOR=$PINK
else
  ICON=$HEADSET_DISCONNECTED
  COLOR=$GREY
fi

sketchybar --set $NAME icon=$ICON icon.color=$COLOR
