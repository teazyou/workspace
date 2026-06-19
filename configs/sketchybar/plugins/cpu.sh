#!/bin/bash

# Single awk over the last "CPU usage" line of `top` parses the user ($3) and
# sys ($5) percentages, strips the '%', sums them and truncates to an integer —
# replacing the echo|awk|tr|bc|cut fork chain. Empty/absent fields print "0".
TOTAL=$(top -l 1 -n 0 2>/dev/null | awk '
  /^CPU/ {
    usr=$3; sys=$5; sub(/%/, "", usr); sub(/%/, "", sys); line=1
  }
  END { if (line) printf "%d", usr + sys; else printf "0" }
')

sketchybar --set $NAME label="${TOTAL:-0}%"
