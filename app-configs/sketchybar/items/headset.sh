#!/bin/bash

# CriticalElement style headset - grey accent when disconnected
headset=(
  icon=$HEADSET_DISCONNECTED
  icon.font="$FONT:Normal:15.0"
  icon.color=$PINK
  icon.padding_left=8
  icon.padding_right=8
  label.drawing=off
  background.drawing=off
  padding_left=0
  padding_right=0
  script="$PLUGIN_DIR/headset.sh"
  update_freq=5
)

sketchybar --add item headset right \
           --set headset "${headset[@]}" \
           --subscribe headset system_woke
