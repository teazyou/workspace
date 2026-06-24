#!/bin/bash

# Click handler for the wifi item: toggle Wi-Fi power, then refresh the wifi (and
# vpn, which also subscribes to wifi_change) items so the icon updates immediately
# instead of waiting for the next 5s poll.
DEVICE="en0"

if [ "$(networksetup -getairportpower "$DEVICE" | awk '{print $NF}')" = "On" ]; then
  networksetup -setairportpower "$DEVICE" off
else
  networksetup -setairportpower "$DEVICE" on
fi

sketchybar --trigger wifi_change
