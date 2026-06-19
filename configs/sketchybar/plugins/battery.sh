#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icons.sh"

# One awk over `pmset -g batt` extracts the integer percentage (first NN%
# token) and an AC-power flag, replacing two grep|cut fork chains. Output:
# "<percent> <0|1>"; percent empty when no battery line is present.
read -r PERCENTAGE CHARGING <<< "$(pmset -g batt | awk '
  /AC Power/ { ac=1 }
  {
    if (match($0, /[0-9]+%/) && pct=="") { pct=substr($0, RSTART, RLENGTH-1) }
  }
  END { printf "%s %d", pct, ac }
')"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

case ${PERCENTAGE} in
  9[0-9]|100) ICON=$BATTERY_100 ;;
  [6-8][0-9]) ICON=$BATTERY_75 ;;
  [3-5][0-9]) ICON=$BATTERY_50 ;;
  [1-2][0-9]) ICON=$BATTERY_25 ;;
  *) ICON=$BATTERY_0 ;;
esac

if [[ "$CHARGING" == "1" ]]; then
  ICON=$BATTERY_CHARGING
fi

sketchybar --set $NAME icon=$ICON icon.color=$PINK label="${PERCENTAGE}%"
