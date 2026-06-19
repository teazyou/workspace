#!/bin/bash

# CriticalElement style cpu - pink accent. Shares monitor_item_base (defined in
# sketchybarrc before this item is sourced); only the per-item overrides differ.
cpu=(
  "${monitor_item_base[@]}"
  icon=󰍛
  icon.padding_left=6
  label.padding_right=6
  label=0%
  update_freq=5
  script="$PLUGIN_DIR/cpu.sh"
)

sketchybar --add item cpu right \
           --set cpu "${cpu[@]}"
