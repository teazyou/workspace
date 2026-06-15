#!/bin/bash

# CriticalElement style workspace indicator with multi-monitor support
# - Highlights active workspace on EACH monitor with distinct colors
# - Shows app names next to workspace number
# - Main monitor (focused): PINK
# - Secondary monitor (visible): GREEN
# - Third monitor (visible): ORANGE

source "$HOME/.config/sketchybar/colors.sh"

WORKSPACE_ID="$1"

# First workspace of each monitor group (main=1, built-in=7, sidecar=0).
# Must match the bracket grouping in items/spaces.sh and the
# [workspace-to-monitor-force-assignment] block in aerospace.toml.
GROUP_FIRST_WORKSPACES=" 1 7 0 "
IS_GROUP_FIRST=false
case "$GROUP_FIRST_WORKSPACES" in
  *" $WORKSPACE_ID "*) IS_GROUP_FIRST=true ;;
esac

# Last workspace of each monitor group (main=6, built-in=9, sidecar=0).
GROUP_LAST_WORKSPACES=" 6 9 0 "
IS_GROUP_LAST=false
case "$GROUP_LAST_WORKSPACES" in
  *" $WORKSPACE_ID "*) IS_GROUP_LAST=true ;;
esac

# Function to shorten common app names
shorten_app_name() {
    local app="$1"
    case "$app" in
        "Google Chrome") echo "Chrome" ;;
        "Visual Studio Code") echo "Code" ;;
        "Microsoft Edge") echo "Edge" ;;
        "Microsoft Word") echo "Word" ;;
        "Microsoft Excel") echo "Excel" ;;
        "Microsoft PowerPoint") echo "PPT" ;;
        "Microsoft Outlook") echo "Outlook" ;;
        "System Preferences") echo "Prefs" ;;
        "System Settings") echo "Settings" ;;
        "Activity Monitor") echo "Activity" ;;
        "Sublime Text") echo "Sublime" ;;
        "IntelliJ IDEA") echo "IDEA" ;;
        "Android Studio") echo "Android" ;;
        "Docker Desktop") echo "Docker" ;;
        "Brave Browser") echo "Brave" ;;
        *) echo "$app" ;;
    esac
}

# Get all visible workspaces across all monitors
VISIBLE_WORKSPACES=$(aerospace list-workspaces --monitor all --visible 2>/dev/null)

# Get the focused workspace (main monitor)
FOCUSED_WS=$(aerospace list-workspaces --focused 2>/dev/null)

# Determine if this workspace is visible and on which monitor
IS_VISIBLE=false
IS_FOCUSED=false
MONITOR_INDEX=0

if [ "$WORKSPACE_ID" = "$FOCUSED_WS" ]; then
    IS_FOCUSED=true
    IS_VISIBLE=true
fi

# Check if workspace is visible on any monitor
MONITOR_COUNT=0
for ws in $VISIBLE_WORKSPACES; do
    MONITOR_COUNT=$((MONITOR_COUNT + 1))
    if [ "$ws" = "$WORKSPACE_ID" ]; then
        IS_VISIBLE=true
        if [ "$ws" != "$FOCUSED_WS" ]; then
            MONITOR_INDEX=$MONITOR_COUNT
        fi
    fi
done

# Get apps in this workspace
APPS=""
APP_LIST=$(aerospace list-windows --workspace "$WORKSPACE_ID" --format '%{app-name}' 2>/dev/null)

if [ -n "$APP_LIST" ]; then
    while IFS= read -r app; do
        if [ -n "$app" ]; then
            SHORT_NAME=$(shorten_app_name "$app")
            if [ -z "$APPS" ]; then
                APPS="$SHORT_NAME"
            else
                APPS="$APPS $SHORT_NAME"
            fi
        fi
    done <<< "$APP_LIST"
fi

# Determine highlight color based on monitor - dark red theme
if [ "$IS_FOCUSED" = true ]; then
    # Main monitor (focused) - rich burgundy highlight
    BG_COLOR="0xffa33a55"
elif [ "$IS_VISIBLE" = true ]; then
    # Secondary/tertiary monitors - slightly darker
    if [ "$MONITOR_INDEX" -eq 2 ]; then
        BG_COLOR="0xff8a3048"
    elif [ "$MONITOR_INDEX" -ge 3 ]; then
        BG_COLOR="0xff75283d"
    else
        BG_COLOR="0xff8a3048"
    fi
else
    # Not visible - transparent
    BG_COLOR=$TRANSPARENT
fi

# Determine icon and label colors
# Focused: slightly reddish white for the active app visibility
# Visible (not focused): dark for contrast
# Inactive: dark red for app names
if [ "$IS_FOCUSED" = true ]; then
    ICON_COLOR="0xff1a1a2e"
    LABEL_COLOR="0xfffff0f3"  # Slightly reddish white
elif [ "$IS_VISIBLE" = true ]; then
    ICON_COLOR="0xff1a1a2e"
    LABEL_COLOR="0xff1a1a2e"
else
    ICON_COLOR="0xffcf6679"
    LABEL_COLOR="0xffb35060"  # Dark red (brighter)
fi

# Render in one of three states: occupied (number + apps), number-only
# (group-first or focused/visible empty), or a minimal dot (empty filler).
# Because the dot state swaps the icon glyph AND font, every non-dot branch
# must reset icon/icon.font back to the number so an item never gets stuck on
# the dot when an app appears.
FONT="JetBrainsMono Nerd Font"
NUM_FONT="$FONT:Bold:13.0"        # matches the static number font in spaces.sh
DOT_GLYPH="·"
DOT_FONT="$FONT:Bold:18.0"        # bigger + bold so the empty-marker dot is clearly visible
DOT_COLOR="0xff6e4250"            # dim placeholder matching the inactive theme

# Extra right padding for breathing room: after the leading number of a group
# (gap between e.g. 1 and 2) and after the last item of a group (gap before the
# bracket edge / separator).
EDGE_PAD_R=1
DOT_PAD_R=0
if [ "$IS_GROUP_FIRST" = true ] || [ "$IS_GROUP_LAST" = true ]; then
  EDGE_PAD_R=6
fi
if [ "$IS_GROUP_LAST" = true ]; then
  DOT_PAD_R=6
fi

ARGS=( --set space.$WORKSPACE_ID background.color=$BG_COLOR )

if [ -n "$APPS" ]; then
  # OCCUPIED: number + app names
  ARGS+=( icon="$WORKSPACE_ID" icon.font="$NUM_FONT" icon.color=$ICON_COLOR icon.padding_left=5 icon.padding_right=3 \
          label="$APPS" label.color=$LABEL_COLOR label.drawing=on padding_left=1 padding_right=$EDGE_PAD_R )
elif [ "$IS_GROUP_FIRST" = true ] || [ "$IS_VISIBLE" = true ]; then
  # NUMBER ONLY: group-first always, or focused/visible empty so position is visible
  ARGS+=( icon="$WORKSPACE_ID" icon.font="$NUM_FONT" icon.color=$ICON_COLOR icon.padding_left=5 icon.padding_right=0 \
          label="" label.drawing=off padding_left=1 padding_right=$EDGE_PAD_R )
else
  # DOT: empty, not group-first, not visible -> minimal width
  ARGS+=( icon="$DOT_GLYPH" icon.font="$DOT_FONT" icon.color=$DOT_COLOR icon.padding_left=2 icon.padding_right=2 \
          label="" label.drawing=off padding_left=0 padding_right=$DOT_PAD_R )
fi

sketchybar "${ARGS[@]}"
