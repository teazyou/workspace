#!/bin/bash

DISPLAY_ID="$1"

# Get the visible workspace on this display/monitor
VISIBLE_WS=$(aerospace list-workspaces --monitor "$DISPLAY_ID" --visible 2>/dev/null | head -1)

if [ -z "$VISIBLE_WS" ]; then
    sketchybar --set "$NAME" label=""
    exit 0
fi

# Get the focused window on that workspace
# First try to get the focused window app name on this workspace
FOCUSED_APP=$(aerospace list-windows --workspace "$VISIBLE_WS" --format '%{app-name}' 2>/dev/null | head -1)

if [ -z "$FOCUSED_APP" ]; then
    sketchybar --set "$NAME" label=""
else
    sketchybar --set "$NAME" label="$FOCUSED_APP"
fi
