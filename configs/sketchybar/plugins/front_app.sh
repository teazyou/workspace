#!/usr/bin/env bash

# Use $INFO from event, or query current app on initial load
if [ -n "$INFO" ]; then
  APP_NAME="$INFO"
else
  APP_NAME=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null)
fi

sketchybar --set $NAME label="$APP_NAME"
