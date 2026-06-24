#!/bin/bash

# Network down - RIGHT element of the traffic division and the SOLE poller for both
# traffic labels (see plugins/network_speed.sh). label.padding_right is the
# division's right edge pad; icon.padding_left is the gap from up (theme.sh).
network_down=(
  "${monitor_item_base[@]}"
  icon=$NETWORK_DOWN
  icon.padding_left=$ELEMENT_GAP
  label.padding_right=$DIVISION_PAD
  label="0 B/s"
  update_freq=5
  script="$PLUGIN_DIR/network_speed.sh"
)

sketchybar --add item network_down right \
           --set network_down "${network_down[@]}"
