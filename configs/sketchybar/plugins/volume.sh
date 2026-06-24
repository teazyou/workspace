#!/bin/bash

source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/colors.sh"

# One osascript call returns e.g.
#   "output volume:50, input volume:75, alert volume:100, output muted:false"
# so we read both the level and the mute flag without a second fork.
SETTINGS=$(osascript -e 'get volume settings')
VOLUME=$(echo "$SETTINGS" | sed -n 's/.*output volume:\([0-9]*\).*/\1/p')
[ -z "$VOLUME" ] && VOLUME=0

case $VOLUME in
  [6-9][0-9]|100) ICON=$VOLUME_100 ;;
  [3-5][0-9]) ICON=$VOLUME_66 ;;
  [1-2][0-9]) ICON=$VOLUME_33 ;;
  [1-9]) ICON=$VOLUME_10 ;;
  0) ICON=$VOLUME_0 ;;
  *) ICON=$VOLUME_100 ;;
esac

# Muted: grey muted-speaker glyph and HIDE the percentage. Otherwise the normal
# red accent with the "NN%" label.
if echo "$SETTINGS" | grep -q 'output muted:true'; then
  sketchybar --set $NAME icon=$VOLUME_0 icon.color=$GREY label.drawing=off
else
  sketchybar --set $NAME icon=$ICON icon.color=$PINK label.drawing=on label="${VOLUME}%"
fi