#!/bin/bash

# CPU carries the single stats icon for the whole cpu+ram readout, then its own
# "NN%". RAM (no icon) sits immediately to its right showing raw GB used, so the
# pair reads "<stats> 15% 32GB". cpu is the LEFT edge of the resources division;
# paddings from theme.sh (icon.padding_right = ELEMENT_GAP via monitor_item_base).
cpu=(
  "${monitor_item_base[@]}"
  icon=$STATS
  icon.padding_left=$DIVISION_PAD
  label.padding_right=0
  label=0%
  update_freq=5
  script="$PLUGIN_DIR/cpu.sh"
)

sketchybar --add item cpu right \
           --set cpu "${cpu[@]}"
