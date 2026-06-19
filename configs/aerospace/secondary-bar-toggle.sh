#!/bin/bash
# Toggle SketchyBar visibility on the secondary monitors.
# Orthogonal to performance-mode: only flips the bar's display target and
# writes the bar state, then delegates outer.top regeneration to
# apply-display-profile.sh (the single source of truth for top gaps) so
# windows on the non-main monitors reclaim the freed bar space (or release
# it back). Per-item drawing state is left alone — performance mode is
# unaffected.

set -euo pipefail

source ~/workspace/configs/aerospace/lib-paths.sh

STATE_FILE="$SECONDARY_BAR_STATE"

if [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE")" == "off" ]]; then
  sketchybar --bar display=all
  rm -f "$STATE_FILE"
  echo "Secondary bar ON"
else
  sketchybar --bar display=main
  echo "off" > "$STATE_FILE"
  echo "Secondary bar OFF"
fi

# Regenerate outer.top from the new bar state. apply-display-profile.sh
# reads the state file we just wrote and runs `aerospace reload-config`
# itself, so no extra reload here (avoids a double reload).
"$(dirname "$0")/apply-display-profile.sh" --force
