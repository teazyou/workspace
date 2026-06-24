#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"

# RAM used as a RAW value in GB (not a percentage). Used = active + wired +
# compressed pages × page size, the same "used" numerator as before. A single awk
# over vm_stat strips the trailing dots and converts to GB.
PAGE=$(sysctl -n hw.pagesize)
USED_GB=$(vm_stat | awk -v page="$PAGE" '
  /Pages active/                  { active=$3 }
  /Pages wired down/              { wired=$4 }
  /Pages occupied by compressor/  { compressed=$5 }
  END {
    gsub(/\./, "", active); gsub(/\./, "", wired); gsub(/\./, "", compressed)
    used = (active + wired + compressed) * page
    printf "%.0f", used / 1073741824
  }
')

sketchybar --set $NAME label="${USED_GB:-0}GB" icon.color=$PINK