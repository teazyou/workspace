#!/bin/bash

# Wi-Fi - LEFT edge of the connectivity division. Click toggles Wi-Fi power.
# Paddings from theme.sh.
wifi=(
  icon=$WIFI_CONNECTED
  icon.font="$FONT:Normal:15.0"
  icon.color=$PINK
  icon.padding_left=$DIVISION_PAD
  icon.padding_right=0
  label.drawing=off
  background.drawing=off
  padding_left=0
  padding_right=0
  click_script="$PLUGIN_DIR/wifi_click.sh"
  script="$PLUGIN_DIR/wifi.sh"
  update_freq=30
)

sketchybar --add item wifi right \
           --set wifi "${wifi[@]}" \
           --subscribe wifi wifi_change system_woke
