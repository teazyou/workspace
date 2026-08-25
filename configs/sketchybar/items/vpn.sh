#!/bin/bash

# VPN — RIGHT end of the connectivity division. TWO text items, "BE" (Belgium) and
# "SN" (Singapore) = the two most-used exits. Visual order is BE then SN, so vpn_sn
# is added FIRST (right-side items are added right-most first, like the rest of the
# bar). The label IS the whole element — there is no icon: `icon.drawing=off` and no
# icon paddings, so an element measures exactly ELEMENT_GAP + <2 chars @14pt = 18 px>
# + ELEMENT_GAP = 30 px (vpn_sn measures 31 — its right pad is DIVISION_PAD).
#
# plugins/vpn.sh repaints BOTH items from one vpnutil snapshot on every run. Only
# vpn_sn owns the script/timer/subscription (single invocation per event — the
# plugin repaints both icons itself). COLOUR IS
# THE ONLY CHANNEL:
#   grey    = this country is not connected (off, failed, or simply not the one in use)
#   red     = connected through this country
#   yellow  = connecting, or this icon owns the in-flight "…" click
#   magenta = a pinned server is dead -> run `nord refresh`
# There is deliberately NO "which one is selected" marker: when both read grey the VPN
# is simply off, and which country a `nord on` would dial is not worth bar real estate
# (the old orange colour, then a selection dot, then a selection underline all tried to
# say it — all removed 2026-07-30; `nord status` still tells you).
#
# Click = plugins/vpn_click.sh, and the visible colour is enough to predict it: clicking
# a GREY icon connects that country (`nord be` / `nord sg`, or `nord toggle` when it is
# already the selected one — same outcome), clicking the RED one disconnects
# (`nord toggle`). Instant busy feedback ("…") on the clicked icon + ONE SHARED click
# lock (/tmp/nordvpn-native.click) for both icons, whose `owner` file says which icon to
# keep busy. Paddings from theme.sh. The custom `vpn_change` event is triggered by
# nord.sh/nord-connect.sh after every state change.

vpn_base=(
  icon.drawing=off
  label.font="$FONT:Bold:14.0"
  label.color=$GREY
  background.drawing=off
  padding_left=0
  padding_right=0
  click_script="$PLUGIN_DIR/vpn_click.sh"
)

# Singapore — added first => right-most element of the whole connectivity division,
# so its label carries the division's right inner pad (DIVISION_PAD). Sole owner of
# the plugin script + timer + subscriptions: plugins/vpn.sh repaints BOTH items.
vpn_sn=(
  "${vpn_base[@]}"
  label="SN"
  label.padding_left=$ELEMENT_GAP
  label.padding_right=$DIVISION_PAD
  script="$PLUGIN_DIR/vpn.sh"
  update_freq=30
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
           --set vpn_be "${vpn_be[@]}"
