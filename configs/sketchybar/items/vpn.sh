#!/bin/bash

# VPN - RIGHT edge of the connectivity division. NordVPN app glyph (sketchybar-app-
# font, monochrome so it tints); plugins/vpn.sh sets colour + country label from the
# NATIVE IKEv2 tunnels (vpnutil): red=connected (+CC label), yellow=connecting,
# grey=off, ORANGE=pinned server dead -> `nord refresh`. Click = plugins/vpn_click.sh:
# instant busy feedback (yellow "…") + click lock (re-clicks ignored until the toggle
# finishes or 200s stale-timeout), then runs scripts/vpn/nord.sh toggle. Paddings from
# theme.sh. Custom `vpn_change` event is triggered by nord.sh/nord-connect.sh after
# every state change.
vpn=(
  icon=":nord_vpn:"
  icon.font="sketchybar-app-font:Regular:16.0"
  icon.color=$GREY
  icon.padding_left=$ELEMENT_GAP
  icon.padding_right=$DIVISION_PAD
  label.drawing=off
  label.font="$FONT:Semibold:10.0"
  label.padding_left=0
  label.padding_right=0
  background.drawing=off
  padding_left=0
  padding_right=0
  click_script="$PLUGIN_DIR/vpn_click.sh"
  script="$PLUGIN_DIR/vpn.sh"
  update_freq=30
)

sketchybar --add event vpn_change \
           --add item vpn right \
           --set vpn "${vpn[@]}" \
           --subscribe vpn system_woke wifi_change vpn_change
