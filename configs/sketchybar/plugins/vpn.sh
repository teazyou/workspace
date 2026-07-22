#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/theme.sh"   # DIVISION_PAD / ELEMENT_GAP tokens
PATH="/opt/homebrew/bin:$PATH"               # jq (sketchybar's env has no homebrew PATH)

# Native NordVPN IKEv2 state (see docs/vpn/guide-nordvpn-native.md).
# Colour: red = connected, yellow = connecting, grey = off.
# ORANGE overrides everything = a pinned server is dead -> run `nord refresh`
# (flag file written by scripts/vpn/nord.sh / nord-connect.sh).
CFG_DIR="$HOME/.config/nordvpn-native"
VPNUTIL="/opt/homebrew/bin/vpnutil"

CONN=""; CONNECTING=""
if [ -x "$VPNUTIL" ]; then
  JSON=$("$VPNUTIL" list 2>/dev/null)
  CONN=$(echo "$JSON" | jq -r 'first(.VPNs[]|select(.status=="Connected").name)//""' 2>/dev/null)
  CONNECTING=$(echo "$JSON" | jq -r 'first(.VPNs[]|select(.status=="Connecting").name)//""' 2>/dev/null)
fi

if [ -n "$CONN" ]; then
  COLOR=$PINK LABEL="${CONN#Nord-}"
elif [ -n "$CONNECTING" ]; then
  COLOR=$YELLOW LABEL="${CONNECTING#Nord-}"
else
  COLOR=$GREY LABEL=""
fi
[ -f "$CFG_DIR/refresh-needed" ] && COLOR=$ORANGE
# a click action is in flight (plugins/vpn_click.sh holds the lock): busy look wins
[ -d /tmp/nordvpn-native.click ] && COLOR=$YELLOW LABEL="…"

if [ -n "$LABEL" ]; then
  sketchybar --set "$NAME" icon.color="$COLOR" label="$LABEL" label.drawing=on \
             label.color="$COLOR" label.padding_right="$DIVISION_PAD" icon.padding_right="$ELEMENT_GAP"
else
  sketchybar --set "$NAME" icon.color="$COLOR" label.drawing=off \
             label.padding_right=0 icon.padding_right="$DIVISION_PAD"
fi
