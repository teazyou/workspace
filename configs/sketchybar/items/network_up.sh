#!/bin/bash

# Network up - LEFT element of the traffic division. Shares monitor_item_base.
# Passive: plugins/network_speed.sh (driven by network_down) sets its label,
# visibility, and dynamic right padding (gap to down, or right edge when down is
# hidden). icon.padding_left is the division's left edge pad (theme.sh).
network_up=(
  "${monitor_item_base[@]}"
  icon=$NETWORK_UP
  icon.padding_left=$DIVISION_PAD
  label.padding_right=0
  label="0 B/s"
)

sketchybar --add item network_up right \
           --set network_up "${network_up[@]}"
