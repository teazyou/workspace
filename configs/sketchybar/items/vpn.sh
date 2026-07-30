#!/bin/bash

# VPN — RIGHT end of the connectivity division. TWO text items, "BE" (Belgium) and
# "SN" (Singapore) = the two most-used exits. Visual order is BE then SN, so vpn_sn
# is added FIRST (right-side items are added right-most first, like the rest of the
# bar). The label IS the content; the icon slot carries no icon — it carries the
# SELECTION UNDERLINE (see below).
#
# plugins/vpn.sh repaints BOTH items from one vpnutil snapshot on every run, on TWO
# independent channels:
#   colour    = the tunnel state:  grey = not connected · red = connected ·
#               yellow = connecting (also the in-flight "…" busy look) ·
#               magenta = a pinned server is dead -> run `nord refresh`
#   UNDERLINE = which country is SELECTED (~/.config/nordvpn-native/country): exactly
#               one thin rule at a time, always the SAME colour as the label above it.
# So "grey BE underlined / grey SN" = VPN off, BE is what a click would dial; "red BE
# underlined / grey SN" = connected via BE. (The old orange "selected but not
# connected" colour is gone — marking the selected country is the underline's job.)
#
# UNDERLINE geometry (theme.sh SEL_UNDERLINE_*): the icon slot normally sits BESIDE
# the label, so the negative icon.padding_right below pulls it back UNDER the label
# with a net layout contribution of exactly ZERO (pad_left + advance + pad_right =
# 8+14-22 = 0) — the element stays 30 px wide and the division never shifts. Presence
# is a COLOUR, never icon.drawing: no underline = icon.color=$TRANSPARENT. Seeded
# unmarked; the first plugins/vpn.sh run paints the real state.
#
# Click = plugins/vpn_click.sh: clicking the icon WITHOUT the underline switches to
# that country and turns it on (`nord be` / `nord sg`); clicking the UNDERLINED
# (selected) icon toggles it on/off (`nord toggle`). Instant busy feedback ("…") on the
# clicked icon + ONE SHARED click lock (/tmp/nordvpn-native.click) for both icons,
# whose `owner` file says which icon to keep busy. Paddings from theme.sh. The custom
# `vpn_change` event is triggered by nord.sh/nord-connect.sh after every state change.

# Selection-underline paddings — derived, not magic: an element is
# ELEMENT_GAP + <2 monospace chars at 14 pt = 18 px> + ELEMENT_GAP = 30 px wide
# (verified live: `sketchybar --query vpn_be | jq '.bounding_rects."display-1".size[0]'`
# -> 30; vpn_sn measures 31, so its rule sits 0.5 px left of centre — invisible, and
# deliberately kept on the same constant for both).
VPN_ELEMENT_W=$(( ELEMENT_GAP + 18 + ELEMENT_GAP ))
VPN_RULE_PAD_L=$(( (VPN_ELEMENT_W - SEL_UNDERLINE_ADVANCE) / 2 ))  #   8 -> ink centred
VPN_RULE_PAD_R=$(( -(VPN_RULE_PAD_L + SEL_UNDERLINE_ADVANCE) ))    # -22 -> zero net width

vpn_base=(
  icon="$SEL_UNDERLINE_GLYPH"
  icon.font="$FONT:Regular:$SEL_UNDERLINE_SIZE"
  icon.color=$TRANSPARENT
  icon.y_offset=$SEL_UNDERLINE_Y_OFFSET
  icon.padding_left=$VPN_RULE_PAD_L
  icon.padding_right=$VPN_RULE_PAD_R
  icon.drawing=on
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
