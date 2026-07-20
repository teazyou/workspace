#!/bin/bash

# Battery - rightmost element of the resources division (its label.padding_right is
# the division's right inner pad). Paddings from theme.sh.
battery=(
  icon=$BATTERY_100
  icon.font="$FONT:Normal:15.0"
  icon.color=$PINK
  icon.padding_left=$ELEMENT_GAP
  icon.padding_right=$ELEMENT_GAP
  label.font="$FONT:Bold:14.0"
  label.color=$PINK
  label.padding_left=0
  label.padding_right=$DIVISION_PAD
  label="--%"
  background.drawing=off
  padding_left=0
  padding_right=0
  update_freq=60
  script="$PLUGIN_DIR/battery.sh"
)

sketchybar --add item battery right \
           --set battery "${battery[@]}" \
           --subscribe battery power_source_change system_woke
