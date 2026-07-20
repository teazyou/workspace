#!/bin/bash

# One clock icon, then date + time side by side: "<clock> Thu 25 04:13".
# Paddings come from theme.sh: DIVISION_PAD = inner edge of the division,
# ELEMENT_GAP = gap between elements. date is the LEFT edge, time the RIGHT edge.

# Time item - rightmost in the group: time only, no icon. Its label.padding_right
# is the division's right inner pad (the bar's BAR_SIDE_PADDING still owns the gap
# from the division edge to the screen edge).
time_item=(
  icon.drawing=off
  label.font="$FONT:Bold:14.0"
  label.color=$PINK
  label.padding_left=$ELEMENT_GAP
  label.padding_right=$DIVISION_PAD
  label="$(date '+%H:%M')"
  background.drawing=off
  update_freq=60
  script="$PLUGIN_DIR/time.sh"
)

sketchybar --add item time right       \
           --set time "${time_item[@]}"

# Date item - clock icon + day, sits to the LEFT of the time.
date_item=(
  icon=󱑎
  icon.font="$FONT:Normal:15.0"
  icon.color=$PINK
  icon.padding_left=$DIVISION_PAD
  icon.padding_right=$ELEMENT_GAP
  label.font="$FONT:Bold:14.0"
  label.color=$PINK
  label.padding_left=0
  label.padding_right=0
  label="$(date '+%a %d')"
  background.drawing=off
  update_freq=60
  script="$PLUGIN_DIR/date.sh"
)

sketchybar --add item date right       \
           --set date "${date_item[@]}" \
           --subscribe date system_woke
