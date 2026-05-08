#!/bin/bash
# Toggle SketchyBar visibility on the secondary monitor.
# Orthogonal to performance-mode: only flips the bar's display target
# and prepends/removes a secondary outer.top override so windows on the
# secondary monitor reclaim the freed bar space (or release it back).
# Per-item drawing state is left alone — performance mode is unaffected.

set -euo pipefail

STATE_FILE="/tmp/secondary-bar.state"
AEROSPACE_CONFIG="$HOME/.aerospace.toml"
OVERRIDE='{ monitor.secondary = 10 }, '

# Idempotent edit of the outer.top line. Uses awk + temp file + cp (not mv)
# to write through the symlink at ~/.aerospace.toml, matching the pattern
# used by apply-display-profile.sh.
modify_outer_top() {
  local action="$1"  # "add" or "remove"
  local tmp_file
  tmp_file=$(mktemp)

  awk -v action="$action" -v override="$OVERRIDE" '
  /^[[:space:]]*outer\.top/ {
    if (action == "add" && index($0, "monitor.secondary") == 0) {
      pos = index($0, "[")
      if (pos > 0) {
        $0 = substr($0, 1, pos) override substr($0, pos+1)
      }
    } else if (action == "remove") {
      pos = index($0, override)
      if (pos > 0) {
        $0 = substr($0, 1, pos-1) substr($0, pos+length(override))
      }
    }
  }
  { print }
  ' "$AEROSPACE_CONFIG" > "$tmp_file"

  cp "$tmp_file" "$AEROSPACE_CONFIG"
  rm -f "$tmp_file"
}

if [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE")" == "off" ]]; then
  sketchybar --bar display=all
  rm -f "$STATE_FILE"
  modify_outer_top remove
  echo "Secondary bar ON"
else
  sketchybar --bar display=main
  echo "off" > "$STATE_FILE"
  modify_outer_top add
  echo "Secondary bar OFF"
fi

aerospace reload-config
