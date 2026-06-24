#!/bin/bash

# Volume - RIGHT edge of the audio division. When muted, plugins/volume.sh hides
# the label; icon.padding_right then serves as the right edge pad (equal to the
# label's, since DIVISION_PAD == ELEMENT_GAP). Paddings from theme.sh.
volume=(
  icon=$VOLUME_100
  icon.font="$FONT:Normal:15.0"
  icon.color=$PINK
  icon.padding_left=$ELEMENT_GAP
  icon.padding_right=$ELEMENT_GAP
  label.font="$FONT:Bold:14.0"
  label.color=$PINK
  label.padding_left=0
  label.padding_right=$DIVISION_PAD
  background.drawing=off
  padding_left=0
  padding_right=0
  script="$PLUGIN_DIR/volume.sh"
  update_freq=5
)

sketchybar --add item volume right \
           --set volume "${volume[@]}" \
           --subscribe volume volume_change
