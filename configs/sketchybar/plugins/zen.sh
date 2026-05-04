#!/bin/bash

zen_on() {
  sketchybar --set apple.logo drawing=off \
             --set '/space\..*/' drawing=off \
             --set aerospace.mode drawing=off \
             --set '/front_app\..*/' drawing=off \
             --set battery drawing=off \
             --set cpu drawing=off
}

zen_off() {
  sketchybar --set apple.logo drawing=on \
             --set '/space\..*/' drawing=on \
             --set aerospace.mode drawing=on \
             --set '/front_app\..*/' drawing=on \
             --set battery drawing=on \
             --set cpu drawing=on
}

if [ "$1" = "on" ]; then
  zen_on
elif [ "$1" = "off" ]; then
  zen_off
else
  CURRENT=$(sketchybar --query apple.logo | jq -r '.geometry.drawing')
  if [ "$CURRENT" = "on" ]; then
    zen_on
  else
    zen_off
  fi
fi
