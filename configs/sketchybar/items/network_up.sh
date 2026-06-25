#!/bin/bash

# Network up - its OWN division (bracket traffic_up). Shares monitor_item_base.
# Passive: plugins/network_speed.sh (driven by network_down) sets its label +
# visibility. Static DIVISION_PAD on both edges since it's alone in its division.
network_up=(
  "${monitor_item_base[@]}"
  icon=$NETWORK_UP
  icon.padding_left=$DIVISION_PAD
  label.padding_right=$DIVISION_PAD
  label="0 B/s"
)

sketchybar --add item network_up right \
           --set network_up "${network_up[@]}"
