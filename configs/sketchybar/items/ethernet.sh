#!/bin/bash

# Ethernet — only visible when an ethernet link is active. The item itself stays
# drawing=on (a drawing=off item never runs its script, so it could never detect a
# reconnect); instead plugins/ethernet.sh shows/hides the ICON. icon.drawing starts
# off so nothing flashes before the first poll.
ethernet=(
  icon=$ETHERNET_CONNECTED
  icon.font="$FONT:Normal:15.0"
  icon.color=$PINK
  icon.drawing=off
  icon.padding_left=0
  icon.padding_right=0
  label.drawing=off
  background.drawing=off
  padding_left=0
  padding_right=0
  script="$PLUGIN_DIR/ethernet.sh"
  update_freq=30
)

sketchybar --add item ethernet right \
           --set ethernet "${ethernet[@]}" \
           --subscribe ethernet system_woke
