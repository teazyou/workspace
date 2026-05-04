#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"

CACHE_DIR="/tmp/sketchybar_network"
mkdir -p "$CACHE_DIR"

# Get bytes from active network interface
get_bytes() {
  # Get primary interface (en0 for wifi, en1 for ethernet, etc.)
  INTERFACE=$(route -n get default 2>/dev/null | grep 'interface:' | awk '{print $2}')

  if [ -z "$INTERFACE" ]; then
    echo "0 0"
    return
  fi

  # Get bytes in and out for the interface
  STATS=$(netstat -ib | grep -w "$INTERFACE" | head -1)
  BYTES_IN=$(echo "$STATS" | awk '{print $7}')
  BYTES_OUT=$(echo "$STATS" | awk '{print $10}')

  echo "${BYTES_IN:-0} ${BYTES_OUT:-0}"
}

# Format bytes to human readable
format_speed() {
  local bytes=$1

  if [ "$bytes" -lt 0 ]; then
    bytes=0
  fi

  if [ "$bytes" -ge 1073741824 ]; then
    echo "$(echo "scale=1; $bytes/1073741824" | bc) G/s"
  elif [ "$bytes" -ge 1048576 ]; then
    echo "$(echo "scale=1; $bytes/1048576" | bc) M/s"
  elif [ "$bytes" -ge 1024 ]; then
    echo "$(echo "scale=1; $bytes/1024" | bc) K/s"
  else
    echo "$bytes B/s"
  fi
}

# Read current bytes
read -r BYTES_IN BYTES_OUT <<< "$(get_bytes)"

# Read previous bytes from cache (use separate files per direction to avoid race condition)
CACHE_FILE="$CACHE_DIR/prev_bytes_${NAME:-default}"
PREV_IN=0
PREV_OUT=0
if [ -f "$CACHE_FILE" ]; then
  read -r PREV_IN PREV_OUT < "$CACHE_FILE"
fi

# Save current bytes to cache
echo "$BYTES_IN $BYTES_OUT" > "$CACHE_FILE"

# Calculate speed (bytes per second, update_freq is 5 seconds)
SPEED_IN=$(( (BYTES_IN - PREV_IN) / 5 ))
SPEED_OUT=$(( (BYTES_OUT - PREV_OUT) / 5 ))

# Handle negative values (interface change or overflow)
[ "$SPEED_IN" -lt 0 ] && SPEED_IN=0
[ "$SPEED_OUT" -lt 0 ] && SPEED_OUT=0

# Update the appropriate item based on $NAME
if [ "$NAME" = "network_up" ]; then
  LABEL=$(format_speed $SPEED_OUT)
  sketchybar --set $NAME label="$LABEL"
elif [ "$NAME" = "network_down" ]; then
  LABEL=$(format_speed $SPEED_IN)
  sketchybar --set $NAME label="$LABEL"
fi
