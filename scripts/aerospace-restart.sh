#!/usr/bin/env bash
#
# aerospace-restart.sh — full restart of the window-manager stack.
#
# Stops then restarts everything described in docs/window-manager/guide-window-manager.md:
#   - AeroSpace               (tiling WM; launches sketchybar + borders on startup)
#   - sketchybar              (status bar)
#   - borders / JankyBorders  (window borders)
#   - com.autoraise.daemon    LaunchAgent (focus-follows-mouse / AutoRaise)
#
# Also the way to re-apply the per-monitor gaps + the workspace 7-9 assignment
# after a monitor change: AeroSpace's after-startup-command re-runs
# apply-display-profile.sh.
#
# Wired to the `aerospace-restart` alias (see zsh/alias/osx.zsh).

set -u

DOMAIN="gui/$(id -u)"
AGENT="com.autoraise.daemon"
AGENT_PLIST="$HOME/Library/LaunchAgents/$AGENT.plist"

echo "==> Stopping window-manager stack"

# AutoRaise is KeepAlive, so its agent is booted out (not just killed) —
# otherwise launchd respawns it immediately.
launchctl bootout "$DOMAIN/$AGENT" 2>/dev/null && echo "    unloaded $AGENT"

# Kill the rest (sketchybar/borders are spawned by AeroSpace, AutoRaise by its agent)
for proc in AeroSpace sketchybar borders AutoRaise; do
  killall "$proc" 2>/dev/null && echo "    killed $proc"
done

# Give launchd/processes a moment to fully tear down
sleep 1

echo "==> Starting window-manager stack"

# AeroSpace first — its after-startup-command relaunches sketchybar + borders and
# regenerates the per-monitor gaps
open -a AeroSpace && echo "    started AeroSpace (+ sketchybar + borders)"

# Wait for AeroSpace to be ready before bringing AutoRaise back, so the two don't
# fight over focus mid-startup. Break on a readiness query, not mere process
# existence — pgrep can succeed while the socket is still initializing.
for _ in 1 2 3 4 5 6 7 8 9 10; do
  aerospace list-workspaces --focused >/dev/null 2>&1 && break
  sleep 0.5
done

launchctl bootstrap "$DOMAIN" "$AGENT_PLIST" 2>/dev/null && echo "    loaded $AGENT"

echo "==> Done."
