#!/bin/bash
# Performance mode toggle — strips SketchyBar down to the essentials (spaces +
# calendar) and stops the hidden divisions' pollers, cutting the bar's periodic
# wakeups during resource-intensive work.
#
# ON — the DEFAULT: aerospace.toml's after-startup-command clears the state
# file and runs this script, so every AeroSpace (re)start lands here.
#   - The resources (cpu, ram, battery) and connectivity (vpn, wifi, ethernet)
#     divisions are hidden.
#   - Their pollers are stopped: every member gets update_freq=0 (and the
#     bar-wide default updates=when_shown gates their subscribed events off
#     while hidden anyway).
#   - The inter-division spacers (spacer0/1) are hidden too: only the
#     calendar division remains on the right, so no inter-division gaps exist.
# OFF — toggle via service mode: alt+shift+; then p (aerospace.toml).
#   - Everything restored: drawing=on + the exact original freqs from
#     items/*.sh (battery 60, vpn 30, ethernet 30, wifi 30, cpu 5, ram 5),
#     then a forced update so the frozen labels repopulate NOW and the
#     state-driven ethernet item (hide-when-disconnected) recomputes its own
#     icon visibility.
#
# BRACKET HIDING (the historical empty-pill lesson): a SketchyBar bracket
# paints via TWO independent layers — fill (background.drawing) AND drop
# shadow (background.shadow.drawing) — and the item-level `drawing` flag
# controls NEITHER: bracket drawing=off just FREEZES the bracket at its last
# geometry while both layers keep painting (= a frozen empty pill). So each
# division bracket stays drawing=on and BOTH paint layers toggle together.
#
# Unlike the old (removed) performance mode, this one does NOT touch the
# display-profile LaunchAgent (it stays always-loaded), and there is no
# traffic group anymore. JankyBorders is untouched as well. (The audio
# division — volume + headset — was removed from the bar entirely, 2026-07,
# so it is no longer part of the managed set.)
#
# State: /tmp/performance-mode.state (PERFORMANCE_MODE_STATE in lib-paths.sh).
# Clean-state convention: file absent/empty => the next run lands in the
# startup default (here: ON, which writes "on"; toggling OFF removes the file).

set -euo pipefail

source ~/workspace/configs/aerospace/lib-paths.sh
# theme.sh: DIVISION_SHADOW_DRAWING — restore the brackets' shadow layer to
# the theme's value instead of hardcoding `on`, so theme.sh stays the single
# source of truth for whether divisions cast shadows.
source "$HOME/.config/sketchybar/theme.sh"

STATE_FILE="$PERFORMANCE_MODE_STATE"

if [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE")" == "on" ]]; then
  # ── OFF: full bar back (one batched call, then state, then forced update) ──
  sketchybar --set cpu      drawing=on update_freq=5 \
             --set ram      drawing=on update_freq=5 \
             --set battery  drawing=on update_freq=60 \
             --set vpn      drawing=on update_freq=30 \
             --set wifi     drawing=on update_freq=30 \
             --set ethernet drawing=on update_freq=30 \
             --set resources    background.drawing=on background.shadow.drawing=$DIVISION_SHADOW_DRAWING \
             --set connectivity background.drawing=on background.shadow.drawing=$DIVISION_SHADOW_DRAWING \
             --set spacer0 drawing=on \
             --set spacer1 drawing=on
  rm -f "$STATE_FILE"
  # Repopulate immediately: run every plugin once so the restored pollers
  # don't show stale/seed labels until their first timer tick, and so
  # ethernet recomputes its connected-state icon visibility.
  sketchybar --update
  echo "Performance mode OFF"
else
  # ── ON: minimal bar (spaces + calendar only), one batched call ──
  sketchybar --set cpu      drawing=off update_freq=0 \
             --set ram      drawing=off update_freq=0 \
             --set battery  drawing=off update_freq=0 \
             --set vpn      drawing=off update_freq=0 \
             --set wifi     drawing=off update_freq=0 \
             --set ethernet drawing=off update_freq=0 \
             --set resources    background.drawing=off background.shadow.drawing=off \
             --set connectivity background.drawing=off background.shadow.drawing=off \
             --set spacer0 drawing=off \
             --set spacer1 drawing=off
  echo "on" > "$STATE_FILE"
  echo "Performance mode ON"
fi
