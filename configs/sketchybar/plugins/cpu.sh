#!/bin/bash

# One `ps` pass sums %CPU across all processes. NOTE: ps %CPU is a decayed
# (exponentially weighted since process start) average, not top's instantaneous
# sample — for a bar gauge the smoothed value is equivalent (arguably nicer: no
# spiky jitter) while costing one cheap fork instead of top's full snapshot.
TOTAL=$(ps -axo %cpu 2>/dev/null | awk '{s+=$1} END {printf "%d", s}')

sketchybar --set $NAME label="${TOTAL:-0}%"
