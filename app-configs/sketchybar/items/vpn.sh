#!/bin/bash

# CriticalElement style vpn - grey accent when disconnected
vpn=(
  icon=$VPN_DISCONNECTED
  icon.font="$FONT:Normal:15.0"
  icon.color=$PINK
  icon.padding_left=6
  icon.padding_right=8
  label.drawing=off
  background.drawing=off
  padding_left=0
  padding_right=0
  script="$PLUGIN_DIR/vpn.sh"
  update_freq=5
)

sketchybar --add item vpn right \
           --set vpn "${vpn[@]}" \
           --subscribe vpn system_woke
