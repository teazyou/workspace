#!/bin/bash

# CriticalElement style ram - pink accent
ram=(
  icon=󰘚
  icon.font="$FONT:Normal:15.0"
  icon.color=$PINK
  icon.padding_left=6
  icon.padding_right=2
  label.font="$FONT:Bold:14.0"
  label.color=$PINK
  label.padding_left=2
  label.padding_right=8
  label=0%
  background.drawing=off
  padding_left=0
  padding_right=0
  update_freq=5
  script="$PLUGIN_DIR/ram.sh"
)

sketchybar --add item ram right \
           --set ram "${ram[@]}"
