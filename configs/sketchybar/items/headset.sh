#!/bin/bash

# Headset - LEFT edge of the audio division. Starts hidden (icon.drawing=off); the
# item stays drawing=on so its poller runs (a drawing=off item never runs its
# script). plugins/headset.sh sets the icon + paddings (theme.sh) when connected.
headset=(
  icon=$HEADSET_CONNECTED
  icon.font="$FONT:Normal:15.0"
  icon.color=$PINK
  icon.drawing=off
  icon.padding_left=0
  icon.padding_right=0
  label.drawing=off
  background.drawing=off
  padding_left=0
  padding_right=0
  script="$PLUGIN_DIR/headset.sh"
  update_freq=30
)

sketchybar --add item headset right \
           --set headset "${headset[@]}" \
           --subscribe headset system_woke
