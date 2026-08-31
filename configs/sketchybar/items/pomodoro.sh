#!/bin/bash

# Pomodoro division, added in reverse because SketchyBar prepends right-side
# items. Visual order is preset, countdown, play/pause, reset.
pomodoro_reset=(
  icon=$POMODORO_RESET
  icon.font="$FONT:Normal:15.0"
  icon.color=$GREY
  icon.padding_left=$ELEMENT_GAP
  icon.padding_right=$DIVISION_PAD
  label.drawing=off
  background.drawing=off
  padding_left=0
  padding_right=0
  click_script="$PLUGIN_DIR/pomodoro.sh reset"
)

sketchybar --add item pomodoro_reset right \
           --set pomodoro_reset "${pomodoro_reset[@]}"

pomodoro_toggle=(
  icon=$POMODORO_PLAY
  icon.font="$FONT:Normal:15.0"
  icon.color=$GREEN
  icon.padding_left=$ELEMENT_GAP
  icon.padding_right=0
  label.drawing=off
  background.drawing=off
  padding_left=0
  padding_right=0
  click_script="$PLUGIN_DIR/pomodoro.sh toggle"
)

sketchybar --add item pomodoro_toggle right \
           --set pomodoro_toggle "${pomodoro_toggle[@]}"

pomodoro_countdown=(
  icon.drawing=off
  label="45:00"
  label.font="$FONT:Bold:14.0"
  label.color=$GREY
  label.padding_left=$ELEMENT_GAP
  label.padding_right=0
  background.drawing=off
  padding_left=0
  padding_right=0
  updates=on
  update_freq=0
  script="$PLUGIN_DIR/pomodoro.sh sync"
)

sketchybar --add item pomodoro_countdown right \
           --set pomodoro_countdown "${pomodoro_countdown[@]}" \
           --subscribe pomodoro_countdown system_woke

pomodoro_preset=(
  icon=$POMODORO_WORK
  icon.font="$FONT:Normal:15.0"
  icon.color=$PINK
  icon.padding_left=$DIVISION_PAD
  icon.padding_right=$ELEMENT_GAP
  label="45/15"
  label.font="$FONT:Bold:14.0"
  label.color=$PINK
  label.padding_left=0
  label.padding_right=0
  background.drawing=off
  padding_left=0
  padding_right=0
  click_script="$PLUGIN_DIR/pomodoro.sh cycle"
)

sketchybar --add item pomodoro_preset right \
           --set pomodoro_preset "${pomodoro_preset[@]}"
