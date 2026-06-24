#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/theme.sh"   # DIVISION_PAD, ELEMENT_GAP

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

  # Get bytes in and out for the interface. Count columns FROM THE RIGHT: physical
  # interfaces (en0) have an Address/MAC column but virtual/tunnel ones (utun* for
  # VPN) do NOT, so a fixed $7/$10 reads the wrong field on a tunnel (Obytes became
  # Coll=0 → upload always 0). The trailing layout is stable: ... Ibytes Opkts
  # Oerrs Obytes Coll → Ibytes=$(NF-4), Obytes=$(NF-1) for both interface kinds.
  STATS=$(netstat -ib | grep -w "$INTERFACE" | head -1)
  BYTES_IN=$(echo "$STATS" | awk '{print $(NF-4)}')
  BYTES_OUT=$(echo "$STATS" | awk '{print $(NF-1)}')

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

# Conditional visibility: show each direction only when its rate > 0, and hide the
# whole traffic division when both are idle.
#   - network_down is the SOLE POLLER, so the item must stay drawing=on (a
#     drawing=off item never runs its script) — we hide its icon+label instead.
#   - network_up is passive (no script), so it can be fully drawing=off.
#   - the `traffic` bracket is toggled so no empty pill lingers when idle.
DOWN_VIS=0; [ "$SPEED_IN" -gt 0 ]  && DOWN_VIS=1
UP_VIS=0;   [ "$SPEED_OUT" -gt 0 ] && UP_VIS=1

# Edge paddings (theme.sh): up is the LEFT element, down the RIGHT element of the
# traffic division. The element present at a division edge gets DIVISION_PAD on
# that side; the up<->down boundary gets ELEMENT_GAP. So the lone visible direction
# still has proper inner padding on both sides.
if [ "$UP_VIS" = 1 ]; then
  if [ "$DOWN_VIS" = 1 ]; then UP_RP=0; else UP_RP=$DIVISION_PAD; fi
  UP_ARGS=(drawing=on label="$LABEL_UP" label.padding_right=$UP_RP)
else
  UP_ARGS=(drawing=off)
fi

if [ "$DOWN_VIS" = 1 ]; then
  if [ "$UP_VIS" = 1 ]; then DN_LP=$ELEMENT_GAP; else DN_LP=$DIVISION_PAD; fi
  DOWN_ARGS=(icon.drawing=on label.drawing=on label="$LABEL_DOWN" icon.padding_left=$DN_LP)
else
  DOWN_ARGS=(icon.drawing=off label.drawing=off)
fi

if [ "$UP_VIS" = 1 ] || [ "$DOWN_VIS" = 1 ]; then TRAFFIC_DRAW=on; else TRAFFIC_DRAW=off; fi

sketchybar --set network_down "${DOWN_ARGS[@]}" \
           --set network_up "${UP_ARGS[@]}" \
           --set traffic drawing=$TRAFFIC_DRAW
