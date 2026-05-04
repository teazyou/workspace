#!/bin/bash

# CriticalElement style title script for aerospace
# Shows the focused window title or app name

# Get the focused window info from aerospace
WINDOW_INFO=$(aerospace list-windows --focused --format '%{app-name}|||%{window-title}' 2>/dev/null)

if [ -z "$WINDOW_INFO" ]; then
    # No focused window - hide or show empty
    sketchybar --set title_proxy label=""
    sketchybar --animate circ 15 --set title y_offset=70
    sketchybar --set title label=""
else
    # Parse app name and window title
    APP_NAME=$(echo "$WINDOW_INFO" | cut -d'|' -f1)
    WINDOW_TITLE=$(echo "$WINDOW_INFO" | cut -d'|' -f4)

    # Use window title if available, otherwise app name
    if [ -n "$WINDOW_TITLE" ] && [ "$WINDOW_TITLE" != "null" ]; then
        LABEL="$WINDOW_TITLE"
    else
        LABEL="$APP_NAME"
    fi

    # Only update and animate if label changed
    CURRENT_LABEL=$(sketchybar --query title_proxy 2>/dev/null | grep -o '"value":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ "$CURRENT_LABEL" != "$LABEL" ]; then
        sketchybar --set title_proxy label="$LABEL"
        sketchybar --animate circ 15 --set title y_offset=70            \
                   --animate circ 10  --set title y_offset=7            \
                   --animate circ 15 --set title y_offset=0

        sketchybar --set title label="$LABEL"
    fi
fi
