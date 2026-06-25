#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"

# RAM used as a RAW value in GB, matching Activity Monitor's "Memory Used" =
# App Memory + Wired + Compressed. App Memory is ANONYMOUS (app-allocated) pages —
# which includes app memory that's currently INACTIVE, not just active. The old
# formula used "active", which omitted inactive app memory and so read ~2 GB low
# vs Activity Monitor. (Neither counts file-backed "Cached Files".) A single awk
# over vm_stat strips trailing dots and converts to GB.
PAGE=$(sysctl -n hw.pagesize)
USED_GB=$(vm_stat | awk -v page="$PAGE" '
  /Anonymous pages/               { anon=$3 }
  /Pages wired down/              { wired=$4 }
  /Pages occupied by compressor/  { compressed=$5 }
  END {
    gsub(/\./, "", anon); gsub(/\./, "", wired); gsub(/\./, "", compressed)
    used = (anon + wired + compressed) * page
    printf "%.0f", used / 1073741824
  }
')

sketchybar --set $NAME label="${USED_GB:-0}GB" icon.color=$PINK