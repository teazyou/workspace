#!/bin/bash

# CriticalElement style network up - pink accent
network_up=(
  icon=$NETWORK_UP
  icon.font="$FONT:Normal:15.0"
  icon.color=$PINK
  icon.padding_left=8
  icon.padding_right=2
  label.font="$FONT:Bold:14.0"
  label.color=$PINK
  label.padding_left=2
  label.padding_right=6
  label="0 B/s"
  background.drawing=off
  padding_left=0
  padding_right=0
  update_freq=5
  script="$PLUGIN_DIR/network_speed.sh"
)

sketchybar --add item network_up right \
           --set network_up "${network_up[@]}"
