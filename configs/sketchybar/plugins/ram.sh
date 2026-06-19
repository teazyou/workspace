#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"

# Get memory usage using vm_stat. A single awk over the vm_stat output parses
# every "Pages …" line, strips the trailing dot, and computes the used%
# (active + wired + compressed) / (used + free + inactive + speculative) — the
# same arithmetic as before but collapsing ~18 echo|grep|awk|tr forks to one awk.
PERCENT=$(vm_stat | awk '
  /Pages free/                    { free=$3 }
  /Pages active/                  { active=$3 }
  /Pages inactive/                { inactive=$3 }
  /Pages speculative/             { speculative=$3 }
  /Pages wired down/              { wired=$4 }
  /Pages occupied by compressor/  { compressed=$5 }
  END {
    gsub(/\./, "", free); gsub(/\./, "", active); gsub(/\./, "", inactive)
    gsub(/\./, "", speculative); gsub(/\./, "", wired); gsub(/\./, "", compressed)
    used  = active + wired + compressed
    total = used + free + inactive + speculative
    if (total > 0) printf "%d", used * 100 / total; else printf "0"
  }
')

sketchybar --set $NAME label="${PERCENT}%" icon.color=$PINK
