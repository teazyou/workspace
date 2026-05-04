#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icons.sh"

window_state() {
  # Get focused window info from aerospace
  WINDOW_ID=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null)

  args=()

  if [ -z "$WINDOW_ID" ] || [ "$WINDOW_ID" = "" ]; then
    args+=(--set $NAME icon=$YABAI_GRID icon.color=$GREY label.drawing=off)
  else
    # Check if floating
    IS_FLOATING=$(aerospace list-windows --focused --format '%{is-floating}' 2>/dev/null)

    if [ "$IS_FLOATING" = "true" ]; then
      args+=(--set $NAME icon=$YABAI_FLOAT icon.color=$MAGENTA label.drawing=off)
    else
      args+=(--set $NAME icon=$YABAI_GRID icon.color=$ORANGE label.drawing=off)
    fi
  fi

  sketchybar -m "${args[@]}"
}

windows_on_spaces() {
  # Get all workspaces and their windows
  WORKSPACES=$(aerospace list-workspaces --all 2>/dev/null)

  args=()
  while IFS= read -r ws; do
    if [ -n "$ws" ]; then
      icon_strip=" "
      apps=$(aerospace list-windows --workspace "$ws" --format '%{app-name}' 2>/dev/null)
      if [ -n "$apps" ]; then
        while IFS= read -r app; do
          if [ -n "$app" ]; then
            icon_strip+=" $($HOME/.config/sketchybar/plugins/icon_map.sh "$app")"
          fi
        done <<< "$apps"
      fi
      args+=(--set space.$ws label="$icon_strip" label.drawing=on)
    fi
  done <<< "$WORKSPACES"

  if [ ${#args[@]} -gt 0 ]; then
    sketchybar -m "${args[@]}"
  fi
}

mouse_clicked() {
  # Toggle float for aerospace
  aerospace layout floating tiling 2>/dev/null
  window_state
}

case "$SENDER" in
  "mouse.clicked") mouse_clicked
  ;;
  "forced") exit 0
  ;;
  "window_focus") window_state
  ;;
  "windows_on_spaces") windows_on_spaces
  ;;
esac
