#!/bin/bash

# CriticalElement style ram - pink accent. Shares monitor_item_base (defined in
# sketchybarrc before this item is sourced); only the per-item overrides differ.
ram=(
  "${monitor_item_base[@]}"
  icon=󰘚
  icon.padding_left=6
  label.padding_right=8
  label=0%
  update_freq=5
  script="$PLUGIN_DIR/ram.sh"
)

sketchybar --add item ram right \
           --set ram "${ram[@]}"
