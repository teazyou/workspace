#!/bin/bash

# CriticalElement style workspaces with multi-monitor support
# - Each workspace shows number + app names
# - Active workspace on each monitor gets highlighted with distinct colors
# - Main monitor: PINK, Secondary: GREEN, Third: ORANGE

SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "0")

# Register aerospace workspace change event
sketchybar --add event aerospace_workspace_change

# Create workspace items with background highlight support
for i in "${!SPACE_ICONS[@]}"
do
  sid=${SPACE_ICONS[i]}

  space=(
    icon=${SPACE_ICONS[i]}
    icon.font="$FONT:Bold:13.0"
    icon.color=$PINK
    icon.highlight_color=$WHITE
    icon.align=left
    icon.padding_left=5
    icon.padding_right=0
    padding_left=1
    padding_right=1
    label.font="$FONT:Bold:13.0"
    label.color=0xaaffffff
    label.padding_left=2
    label.padding_right=6
    label.drawing=on
    label=""
    background.color=$TRANSPARENT
    background.height=26
    # Radius kept smaller than the group bracket's so the shorter focus bubble
    # doesn't read as an over-rounded pill (see theme.sh SPACE_BUBBLE_RADIUS)
    background.corner_radius=$SPACE_BUBBLE_RADIUS
    background.drawing=on
    click_script="aerospace workspace $sid"
  )

  # No per-item script= / aerospace_workspace_change subscription anymore: the
  # hidden aerospace_coordinator item (added below) repaints ALL space items in a
  # single batched pass on each workspace change. Items keep only the click path.
  sketchybar --add item space.$sid left    \
             --set space.$sid "${space[@]}" \
             --subscribe space.$sid mouse.clicked

  # Add spacer after space.6 (between main and secondary workspaces)
  if [ "$sid" = "6" ]; then
    sketchybar --add item spaces_spacer_main left \
               --set spaces_spacer_main width=$GROUP_GAP background.drawing=off icon.drawing=off label.drawing=off
  fi

  # Add spacer after space.9 (between secondary and third workspaces)
  if [ "$sid" = "9" ]; then
    sketchybar --add item spaces_spacer_secondary left \
               --set spaces_spacer_secondary width=$GROUP_GAP background.drawing=off icon.drawing=off label.drawing=off
  fi
done

# Hidden coordinator: a single item that owns the aerospace_workspace_change
# subscription. On each workspace change it runs plugins/aerospace.sh ONCE, which
# repaints every space.N item in one batched --set (instead of N separate per-item
# script invocations).
#
# IMPORTANT: it must stay drawing=ON. Current sketchybar builds DO NOT execute an
# item's script while it is drawing=off (verified: a drawing=off item never fires
# its script on events, --update, or update_freq; flipping to drawing=on fires it
# every time). A drawing=off coordinator silently stopped repainting the bar, so
# the spaces never refreshed which app/space was focused. Instead we keep it drawn
# but visually invisible — width=0 with icon/label/background drawing off — so the
# script still runs but the item occupies no space and shows nothing.
sketchybar --add item aerospace_coordinator left \
           --set aerospace_coordinator drawing=on width=0 \
                 icon.drawing=off label.drawing=off background.drawing=off \
                 script="$PLUGIN_DIR/aerospace.sh" \
           --subscribe aerospace_coordinator aerospace_workspace_change

# Add new space button - CriticalElement style (DISABLED)
# sketchybar --add item new_space left                        \
#            --set      new_space icon.width=24               \
#                                 label.padding_right=2       \
#                                 icon.align=center           \
#                                 icon.padding_right=2        \
#                                 icon.padding_left=0         \
#                                 icon=+                      \
#                                 icon.color=$WHITE           \
#                                 background.drawing=off      \
#                                 label.drawing=off

# Shared style for the three spaces group brackets - black 70% fill + red outline
# (matches the right-side groups); the focus bubble (set per-item by aerospace.sh)
# layers on top. DISTINCT from sketchybarrc's bracket_style: it deliberately omits
# the background.padding_left/right=0 lines the right-side groups carry, so the
# left-group spacing is unchanged.
spaces_bracket_style=(
  background.color=$DARK_BG
  background.corner_radius=$DIVISION_RADIUS
  background.border_width=$DIVISION_BORDER_WIDTH
  background.border_color=$PINK
  blur_radius=$DIVISION_BLUR
  background.height=32
  background.drawing=on
  background.shadow.drawing=$DIVISION_SHADOW_DRAWING
  background.shadow.color=$DIVISION_SHADOW_COLOR
  background.shadow.angle=$DIVISION_SHADOW_ANGLE
  background.shadow.distance=$DIVISION_SHADOW_DISTANCE
)

# Bracket for main workspaces (1-6)
sketchybar --add bracket spaces_main space.1 space.2 space.3 space.4 space.5 space.6 \
           --set spaces_main "${spaces_bracket_style[@]}"

# Bracket for secondary workspaces (7-9)
sketchybar --add bracket spaces_secondary space.7 space.8 space.9 \
           --set spaces_secondary "${spaces_bracket_style[@]}"

# Bracket for third workspace (0)
sketchybar --add bracket spaces_third space.0 \
           --set spaces_third "${spaces_bracket_style[@]}"
