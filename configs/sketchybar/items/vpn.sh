#!/bin/bash

# VPN - RIGHT edge of the connectivity division. NordVPN app glyph (sketchybar-app-
# font, monochrome so it tints); plugins/vpn.sh toggles ONLY the colour (red when
# connected, grey when off). Click opens NordVPN. Paddings from theme.sh.
vpn=(
  icon=":nord_vpn:"
  icon.font="sketchybar-app-font:Regular:16.0"
  icon.color=$GREY
  icon.padding_left=$ELEMENT_GAP
  icon.padding_right=$DIVISION_PAD
  label.drawing=off
  background.drawing=off
  padding_left=0
  padding_right=0
  click_script="open -a NordVPN"
  script="$PLUGIN_DIR/vpn.sh"
  update_freq=5
)

sketchybar --add item vpn right \
           --set vpn "${vpn[@]}" \
           --subscribe vpn system_woke wifi_change
