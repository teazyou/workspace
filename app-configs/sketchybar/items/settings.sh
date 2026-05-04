#!/bin/bash

# CriticalElement style settings - grey accent
settings=(
  icon=$SETTINGS
  icon.font="$FONT:Normal:16.0"
  icon.color=$PINK
  icon.padding_left=12
  icon.padding_right=12
  label.drawing=off
  background.color=$DARK_BG
  background.height=30
  background.corner_radius=15
  background.border_width=1
  background.border_color=$PINK
  background.padding_left=6
  background.padding_right=0
  blur_radius=2
  click_script="open -a 'System Settings'"
)

sketchybar --add item settings right \
           --set settings "${settings[@]}"
