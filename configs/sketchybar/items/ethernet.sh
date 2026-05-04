#!/bin/bash

# CriticalElement style ethernet - blue accent
ethernet=(
  icon=$ETHERNET_CONNECTED
  icon.font="$FONT:Normal:15.0"
  icon.color=$PINK
  icon.padding_left=8
  icon.padding_right=6
  label.drawing=off
  background.drawing=off
  padding_left=0
  padding_right=0
  script="$PLUGIN_DIR/ethernet.sh"
  update_freq=5
)

sketchybar --add item ethernet right \
           --set ethernet "${ethernet[@]}" \
           --subscribe ethernet system_woke
