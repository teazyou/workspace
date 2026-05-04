#!/bin/bash

# CriticalElement style wifi - pink accent
wifi=(
  icon=$WIFI_CONNECTED
  icon.font="$FONT:Normal:15.0"
  icon.color=$PINK
  icon.padding_left=6
  icon.padding_right=6
  label.drawing=off
  background.drawing=off
  padding_left=0
  padding_right=0
  script="$PLUGIN_DIR/wifi.sh"
  update_freq=5
)

sketchybar --add item wifi right \
           --set wifi "${wifi[@]}" \
           --subscribe wifi wifi_change system_woke
