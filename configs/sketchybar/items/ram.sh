#!/bin/bash

# RAM shows RAW used GB (not %) with NO icon — it shares the cpu item's stats icon
# and sits right next to the cpu %. Middle element of the resources division; its
# label.padding_left is the gap from the cpu % (ELEMENT_GAP from theme.sh).
ram=(
  "${monitor_item_base[@]}"
  icon.drawing=off
  label.padding_left=$ELEMENT_GAP
  label.padding_right=0
  label=0GB
  update_freq=5
  script="$PLUGIN_DIR/ram.sh"
)

sketchybar --add item ram right \
           --set ram "${ram[@]}"
