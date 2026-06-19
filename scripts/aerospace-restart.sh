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

# Unload LaunchAgents. display-profile is RunAtLoad + StartInterval (no KeepAlive);
# empty-watcher + AutoRaise are KeepAlive. All three are booted out (not just
# killed) so launchd doesn't immediately respawn the KeepAlive ones.
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

# Wait for AeroSpace to be ready before the agents that depend on it. Break on a
# readiness query (the socket the agents talk to is up), not mere process
# existence — pgrep can succeed while the socket is still initializing.
for _ in 1 2 3 4 5 6 7 8 9 10; do
  aerospace list-workspaces --focused >/dev/null 2>&1 && break
  sleep 0.5
done

# If performance mode is ON, it deliberately boots out the display-profile agent;
# don't re-bootstrap it here or we'd leave it running while perf mode is nominally
# ON. empty-watcher + AutoRaise still load unconditionally.
PERF_STATE=""
[[ -f /tmp/performance-mode.state ]] && PERF_STATE="$(cat /tmp/performance-mode.state 2>/dev/null)"

# Reload LaunchAgents (display-profile reloads config, empty-watcher + AutoRaise daemons)
for agent in "${AGENTS[@]}"; do
  if [[ "$agent" == "com.aerospace.display-profile" && "$PERF_STATE" == "on" ]]; then
    echo "    skipped $agent (performance mode ON)"
    continue
  fi
  launchctl bootstrap "$DOMAIN" "$AGENTS_DIR/$agent.plist" 2>/dev/null \
    && echo "    loaded $agent"
done

echo "==> Done."
