#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/theme.sh"   # DIVISION_PAD, ELEMENT_GAP

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

# Show the headset icon only when a headset is connected; otherwise collapse it
# (icon.drawing=off + zero padding) so the audio group has no empty slot. The item
# stays drawing=on regardless so this poller keeps running.
if [ -n "$HEADSET_STATUS" ]; then
  sketchybar --set $NAME icon.drawing=on icon=$HEADSET_CONNECTED icon.color=$PINK \
                         icon.padding_left=$DIVISION_PAD icon.padding_right=0
else
  sketchybar --set $NAME icon.drawing=off icon.padding_left=0 icon.padding_right=0
fi
