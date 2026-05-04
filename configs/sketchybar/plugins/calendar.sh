#!/bin/bash

source "$HOME/.config/sketchybar/icons.sh"

sketchybar --set $NAME icon="$CALENDAR" label="$(date '+%a %d %b %I:%M %p')"
