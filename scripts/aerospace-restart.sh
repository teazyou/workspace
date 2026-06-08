#!/usr/bin/env bash
#
# aerospace-restart.sh — full restart of the window-manager stack.
#
# Stops then restarts everything described in configs/guide-window-manager.md:
#   - AeroSpace               (tiling WM; launches sketchybar + borders on startup)
#   - sketchybar              (status bar)
#   - borders / JankyBorders  (window borders)
#   - com.aerospace.display-profile   LaunchAgent (auto gap profile)
#   - com.aerospace.empty-watcher     LaunchAgent (empty-workspace daemon)
#   - com.autoraise.daemon            LaunchAgent (focus-follows-mouse / AutoRaise)
#
# Wired to the `aerostart` alias (see zsh/alias/osx.zsh).

set -u

DOMAIN="gui/$(id -u)"
AGENTS_DIR="$HOME/Library/LaunchAgents"
AGENTS=(
  com.aerospace.display-profile
  com.aerospace.empty-watcher
  com.autoraise.daemon
)

echo "==> Stopping window-manager stack"

# Unload LaunchAgents (KeepAlive=true, so they must be booted out, not just killed)
for agent in "${AGENTS[@]}"; do
  launchctl bootout "$DOMAIN/$agent" 2>/dev/null && echo "    unloaded $agent"
done

# Kill the rest (sketchybar/borders are spawned by AeroSpace, AutoRaise by its agent)
for proc in AeroSpace sketchybar borders AutoRaise; do
  killall "$proc" 2>/dev/null && echo "    killed $proc"
done

# Give launchd/processes a moment to fully tear down
sleep 1

echo "==> Starting window-manager stack"

# AeroSpace first — its after-startup-command relaunches sketchybar + borders
open -a AeroSpace && echo "    started AeroSpace (+ sketchybar + borders)"

# Wait for AeroSpace to be up before the agents that depend on it
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pgrep -x AeroSpace >/dev/null 2>&1 && break
  sleep 0.5
done

# Reload LaunchAgents (display-profile reloads config, empty-watcher + AutoRaise daemons)
for agent in "${AGENTS[@]}"; do
  launchctl bootstrap "$DOMAIN" "$AGENTS_DIR/$agent.plist" 2>/dev/null \
    && echo "    loaded $agent"
done

echo "==> Done."
