#!/usr/bin/env bash
#
# aerospace-restart.sh — full restart of the window-manager stack.
#
# Stops then restarts everything described in docs/window-manager/guide-window-manager.md:
#   - AeroSpace               (tiling WM; launches sketchybar + borders on startup)
#   - sketchybar              (status bar)
#   - borders / JankyBorders  (window borders)
#
# Also the way to re-apply the per-monitor gaps + the workspace 7-9 assignment
# after a monitor change: AeroSpace's after-startup-command re-runs
# apply-display-profile.sh.
#
# Wired to the `aerospace-restart` alias (see zsh/alias/osx.zsh).

set -u

echo "==> Stopping window-manager stack"

# sketchybar/borders are spawned by AeroSpace
for proc in AeroSpace sketchybar borders; do
  killall "$proc" 2>/dev/null && echo "    killed $proc"
done

# Give processes a moment to fully tear down
sleep 1

echo "==> Starting window-manager stack"

# AeroSpace first — its after-startup-command relaunches sketchybar + borders and
# regenerates the per-monitor gaps
open -a AeroSpace && echo "    started AeroSpace (+ sketchybar + borders)"

echo "==> Done."
