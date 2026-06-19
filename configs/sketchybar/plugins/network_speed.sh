#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"

CACHE_DIR="/tmp/sketchybar_network"
mkdir -p "$CACHE_DIR"

# Poll interval in seconds used to convert the byte delta into a per-second rate.
# MUST match items/network_down.sh's update_freq (network_down is the sole poller;
# network_up is passive). Change both together.
UPDATE_FREQ=5

# Get bytes from active network interface
get_bytes() {
  # Get primary interface (en0 for wifi, en1 for ethernet, etc.)
  INTERFACE=$(route -n get default 2>/dev/null | grep 'interface:' | awk '{print $2}')

  if [ -z "$INTERFACE" ]; then
    echo "none 0 0"
    return
  fi

  # Get bytes in and out for the interface
  STATS=$(netstat -ib | grep -w "$INTERFACE" | head -1)
  BYTES_IN=$(echo "$STATS" | awk '{print $7}')
  BYTES_OUT=$(echo "$STATS" | awk '{print $10}')

  echo "$INTERFACE ${BYTES_IN:-0} ${BYTES_OUT:-0}"
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

# Single-poller model: network_down is the sole poller (its update_freq drives
# this script); network_up is passive and gets its label in the same batched set
# below. The route+netstat pipeline already computes BOTH directions, so there is
# one shared cache and one computation per tick instead of running it twice.

# Read current interface + bytes
read -r INTERFACE BYTES_IN BYTES_OUT <<< "$(get_bytes)"

# Read previous interface + bytes from the single shared cache
CACHE_FILE="$CACHE_DIR/prev_bytes"
PREV_IFACE=""
PREV_IN=0
PREV_OUT=0
if [ -f "$CACHE_FILE" ]; then
  read -r PREV_IFACE PREV_IN PREV_OUT < "$CACHE_FILE"
fi

# Save current interface + bytes to cache
echo "$INTERFACE $BYTES_IN $BYTES_OUT" > "$CACHE_FILE"

# Calculate speed (bytes per second; UPDATE_FREQ matches the item update_freq).
# On the first run or an interface flip, the new interface's counters are
# unrelated to the cached ones, so zero the delta for this tick instead of
# reporting a bogus spike.
if [ -z "$PREV_IFACE" ] || [ "$PREV_IFACE" != "$INTERFACE" ]; then
  SPEED_IN=0
  SPEED_OUT=0
else
  SPEED_IN=$(( (BYTES_IN - PREV_IN) / UPDATE_FREQ ))
  SPEED_OUT=$(( (BYTES_OUT - PREV_OUT) / UPDATE_FREQ ))
fi

# Handle negative values (overflow)
[ "$SPEED_IN" -lt 0 ] && SPEED_IN=0
[ "$SPEED_OUT" -lt 0 ] && SPEED_OUT=0

# One batched set drives BOTH labels from this single poll.
LABEL_DOWN=$(format_speed $SPEED_IN)
LABEL_UP=$(format_speed $SPEED_OUT)
sketchybar --set network_down label="$LABEL_DOWN" \
           --set network_up label="$LABEL_UP"
