#!/bin/bash

# VPN — RIGHT end of the connectivity division. TWO text items, "BE" (Belgium) and
# "SN" (Singapore) = the two most-used exits. Visual order is BE then SN, so vpn_sn
# is added FIRST (right-side items are added right-most first, like the rest of the
# bar). No glyph: the label IS the content (icon.drawing=off, same shape as the time
# item) — an icon.drawing=off item contributes no icon padding to the layout.
#
# plugins/vpn.sh repaints BOTH items from one vpnutil snapshot on every run:
#   grey    = not the selected target country (~/.config/nordvpn-native/country)
#   red     = selected AND connected
#   yellow  = selected AND connecting  (also the in-flight "…" busy look)
#   orange  = selected AND not connected (off / failed / reconnecting)
#   magenta = selected AND a pinned server is dead -> run `nord refresh`
#
# Click = plugins/vpn_click.sh: clicking the GREY icon switches to that country and
# turns it on (`nord be` / `nord sg`); clicking the SELECTED icon toggles it on/off
# (`nord toggle`). Instant busy feedback (yellow "…") on the clicked icon + ONE
# SHARED click lock (/tmp/nordvpn-native.click) for both icons, whose `owner` file
# says which icon to keep busy. Paddings from theme.sh. The custom `vpn_change`
# event is triggered by nord.sh/nord-connect.sh after every state change.
vpn_base=(
  icon.drawing=off
  label.font="$FONT:Bold:14.0"
  label.color=$GREY
  background.drawing=off
  padding_left=0
  padding_right=0
  click_script="$PLUGIN_DIR/vpn_click.sh"
  script="$PLUGIN_DIR/vpn.sh"
  update_freq=30
)

# Singapore — added first => right-most element of the whole connectivity division,
# so its label carries the division's right inner pad (DIVISION_PAD).
vpn_sn=(
  "${vpn_base[@]}"
  label="SN"
  label.padding_left=$ELEMENT_GAP
  label.padding_right=$DIVISION_PAD
)

# Belgium — inner element: a plain element gap on both sides (its left gap is the
# one that used to sit on the old single item's icon.padding_left).
vpn_be=(
  "${vpn_base[@]}"
  label="BE"
  label.padding_left=$ELEMENT_GAP
  label.padding_right=$ELEMENT_GAP
)

sketchybar --add event vpn_change \
           --add item vpn_sn right \
           --set vpn_sn "${vpn_sn[@]}" \
           --subscribe vpn_sn system_woke wifi_change vpn_change \
           --add item vpn_be right \
           --set vpn_be "${vpn_be[@]}" \
           --subscribe vpn_be system_woke wifi_change vpn_change
