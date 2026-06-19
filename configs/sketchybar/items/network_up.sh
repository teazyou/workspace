#!/bin/bash

# CriticalElement style network up - pink accent. Shares monitor_item_base
# (defined in sketchybarrc before this item is sourced); only the per-item
# overrides differ.
network_up=(
  "${monitor_item_base[@]}"
  icon=$NETWORK_UP
  icon.padding_left=8
  label.padding_right=6
  label="0 B/s"
  # Passive: no update_freq/script. network_down is the sole poller and sets this
  # item's label in the same batched --set (see plugins/network_speed.sh).
)

sketchybar --add item network_up right \
           --set network_up "${network_up[@]}"
