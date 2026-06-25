#!/bin/bash

# Network down - its OWN division (bracket traffic_down) and the SOLE poller for
# both traffic labels (see plugins/network_speed.sh). Static DIVISION_PAD on both
# edges since it's alone in its division.
network_down=(
  "${monitor_item_base[@]}"
  icon=$NETWORK_DOWN
  icon.padding_left=$DIVISION_PAD
  label.padding_right=$DIVISION_PAD
  label="0 B/s"
  update_freq=5
  script="$PLUGIN_DIR/network_speed.sh"
)

sketchybar --add item network_down right \
           --set network_down "${network_down[@]}"
