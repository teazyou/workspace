#!/bin/bash

# `ps` reports each process in percent of one logical CPU. Normalize the summed
# core-percent total to whole-machine capacity. Its %CPU is a decayed
# (exponentially weighted since process start) average, not top's instantaneous
# sample — for a bar gauge the smoothed value is equivalent (arguably nicer: no
# spiky jitter) while avoiding top's full snapshot.
CPU_COUNT=$(sysctl -n hw.logicalcpu 2>/dev/null)
TOTAL=$(LC_ALL=C ps -axo %cpu 2>/dev/null | LC_ALL=C awk -v cpu_count="${CPU_COUNT:-1}" '
  BEGIN {
    if (cpu_count !~ /^[1-9][0-9]*$/) cpu_count = 1
  }
  $1 ~ /^[0-9]+([.][0-9]+)?$/ { total += $1 }
  END {
    total /= cpu_count
    if (total > 100) total = 100
    printf "%d", total
  }
')

sketchybar --set $NAME label="${TOTAL:-0}%"
