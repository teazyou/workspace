#!/bin/bash

# Front app display - shows current running app name
# Subscribes to front_app_switched event to update when app focus changes

front_app=(
  icon.drawing=off
  label.font="$FONT:Bold:14.0"
  label.color=0xffe05a6d
  label.padding_left=12
  label.padding_right=12
  background.drawing=off
  script="$PLUGIN_DIR/front_app.sh"
)

sketchybar --add item front_app left \
           --set front_app "${front_app[@]}" \
           --subscribe front_app front_app_switched aerospace_workspace_change
