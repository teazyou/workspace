#!/bin/bash

# CriticalElement style network down - pink accent. Shares monitor_item_base
# (defined in sketchybarrc before this item is sourced); only the per-item
# overrides differ. network_down is the sole poller for both traffic labels.
network_down=(
  "${monitor_item_base[@]}"
  icon=$NETWORK_DOWN
  icon.padding_left=6
  label.padding_right=8
  label="0 B/s"
  update_freq=5
  script="$PLUGIN_DIR/network_speed.sh"
)

sketchybar --add item network_down right \
           --set network_down "${network_down[@]}"
