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
    background.corner_radius=10
    background.drawing=on
    click_script="aerospace workspace $sid"
    script="$PLUGIN_DIR/aerospace.sh $sid"
  )

  sketchybar --add item space.$sid left    \
             --set space.$sid "${space[@]}" \
             --subscribe space.$sid aerospace_workspace_change mouse.clicked

  # Add spacer after space.6 (between main and secondary workspaces)
  if [ "$sid" = "6" ]; then
    sketchybar --add item spaces_spacer_main left \
               --set spaces_spacer_main width=3 background.drawing=off icon.drawing=off label.drawing=off
  fi

  # Add spacer after space.9 (between secondary and third workspaces)
  if [ "$sid" = "9" ]; then
    sketchybar --add item spaces_spacer_secondary left \
               --set spaces_spacer_secondary width=3 background.drawing=off icon.drawing=off label.drawing=off
  fi
done

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

# Bracket for main workspaces (1-6) - CriticalElement pink border pill
spaces_main_bracket=(
  background.color=$DARK_BG
  background.corner_radius=10
  background.border_width=1
  background.border_color=$PINK
  blur_radius=2
  background.height=32
  background.drawing=on
)

sketchybar --add bracket spaces_main space.1 space.2 space.3 space.4 space.5 space.6 \
           --set spaces_main "${spaces_main_bracket[@]}"

# Bracket for secondary workspaces (7-9) - CriticalElement pink border pill
spaces_secondary_bracket=(
  background.color=$DARK_BG
  background.corner_radius=10
  background.border_width=1
  background.border_color=$PINK
  blur_radius=2
  background.height=32
  background.drawing=on
)

sketchybar --add bracket spaces_secondary space.7 space.8 space.9 \
           --set spaces_secondary "${spaces_secondary_bracket[@]}"

# Bracket for third workspace (0) - CriticalElement pink border pill
spaces_third_bracket=(
  background.color=$DARK_BG
  background.corner_radius=10
  background.border_width=1
  background.border_color=$PINK
  blur_radius=2
  background.height=32
  background.drawing=on
)

sketchybar --add bracket spaces_third space.0 \
           --set spaces_third "${spaces_third_bracket[@]}"
