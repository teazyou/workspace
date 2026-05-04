#!/bin/bash

# CriticalElement style network down - pink accent
network_down=(
  icon=$NETWORK_DOWN
  icon.font="$FONT:Normal:15.0"
  icon.color=$PINK
  icon.padding_left=6
  icon.padding_right=2
  label.font="$FONT:Bold:14.0"
  label.color=$PINK
  label.padding_left=2
  label.padding_right=8
  label="0 B/s"
  background.drawing=off
  padding_left=0
  padding_right=0
  update_freq=5
  script="$PLUGIN_DIR/network_speed.sh"
)

sketchybar --add item network_down right \
           --set network_down "${network_down[@]}"
