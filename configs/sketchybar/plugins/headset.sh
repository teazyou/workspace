#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icons.sh"

# Check for a connected Bluetooth headphone/headset.
# Uses ioreg (milliseconds) instead of `system_profiler SPBluetoothDataType`
# (0.5-3s per call). IOBluetoothDevice entries expose a connection flag and a
# minor device class; the headphone/headset minor classes are 0x6 and 0x4 under
# the Audio/Video major class. Match a device that is BOTH connected AND one of
# those minor classes within the same registry node.
HEADSET_STATUS=$(ioreg -r -c IOBluetoothDevice -l 2>/dev/null | awk '
  /IOBluetoothDevice/        { connected=0; minor=0 }
  /"device-isConnected"/     { if ($0 ~ /Yes|= 1|= true/) connected=1 }
  /"DeviceMinorClassOfDevice"/ { if ($0 ~ /= (4|6)$/ || $0 ~ /= (4|6)[^0-9]/) minor=1 }
  connected && minor         { print "1"; exit }
')

if [ -n "$HEADSET_STATUS" ]; then
  ICON=$HEADSET_CONNECTED
  COLOR=$PINK
else
  ICON=$HEADSET_DISCONNECTED
  COLOR=$GREY
fi

sketchybar --set $NAME icon=$ICON icon.color=$COLOR
