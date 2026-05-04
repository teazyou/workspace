#!/bin/bash

# CriticalElement style volume - pink accent
volume=(
  icon=$VOLUME_100
  icon.font="$FONT:Normal:15.0"
  icon.color=$PINK
  icon.padding_left=8
  icon.padding_right=2
  label.font="$FONT:Bold:14.0"
  label.color=$PINK
  label.padding_left=2
  label.padding_right=8
  background.drawing=off
  padding_left=0
  padding_right=0
  script="$PLUGIN_DIR/volume.sh"
  update_freq=5
)

sketchybar --add item volume right \
           --set volume "${volume[@]}" \
           --subscribe volume volume_change
