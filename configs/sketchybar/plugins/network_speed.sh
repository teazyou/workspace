#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/theme.sh"   # DIVISION_PAD, ELEMENT_GAP

CACHE_DIR="/tmp/sketchybar_network"
mkdir -p "$CACHE_DIR"

# --- Writer lock (C1: serialize this run against performance-mode.sh) ---------
# This poller AND performance-mode.sh (via its synchronous call to THIS script)
# both decide traffic visibility from the same /tmp/performance-mode.state. A poll
# tick already in flight when perf-ON runs could read state=off, get preempted
# before its final `--set`, then resume and re-show a division on top of the
# now-hidden state — and because perf-ON stops the poller (network_down
# update_freq=0) nothing recomputes, so the stale division stays FROZEN visible.
#
# An mkdir-based advisory lock (bash 3.2 safe; no flock/declare -A; mirrors
# track-workspace-mru.sh's lockdir idiom) makes the perf-state read + visibility
# compute + final `--set` one atomic critical section. The lock is acquired here
# and held through the final `--set` (released by the EXIT trap).
#
# Two callers, two policies — this is what closes C1 (proven: a generic
# "give up after a short wait, proceed lock-free" fallback does NOT close it,
# because a slow stale tick can then win the last write after perf-ON returns):
#
#   * POLL TICK (default): bounded ~250ms wait so the 5s poller NEVER hangs. If
#     it can't acquire, it SKIPS this tick entirely (exit, no `--set`). A tick
#     therefore only ever writes while it HOLDS the lock — and while it holds the
#     lock, perf-ON cannot yet have written `on` (perf-ON blocks on the same
#     lock). So a stale tick's `--set` can never land *after* a perf write.
#
#   * PERF-TRIGGERED run (NET_SPEED_PERF=1, set by performance-mode.sh): this run
#     must be the AUTHORITATIVE last writer, so it waits up to ~3.5s for the lock —
#     long enough to outlast any live holder (a real tick holds it well under a
#     second). It NEVER breaks a LIVE lock (that would reintroduce C1); only the 3s
#     stale-breaker reclaims a lock whose holder is presumed dead. So perf-ON gets
#     to write the truth (state=on → hidden) LAST.
#
# Convergence (perf-ON path), both orderings end HIDDEN after perf-ON returns:
#   tick-first : tick holds lock, plans SHOW; perf-ON writes `on`, stops poller,
#                then waits → tick fires stale SHOW, releases → perf-ON takes the
#                lock, reads `on`, HIDES. Final = hidden.
#   perf-first : perf-ON takes lock, reads `on`, HIDES; a late tick then takes the
#                lock, re-reads `on`, HIDES (no-op). Final = hidden.
LOCK_DIR="$CACHE_DIR/writer.lock"

# Stale-lock breaker (self-healing): a real holder keeps the lock for well under a
# second (one `--set`); if a lockdir is older than 3s assume the holder died (EXIT
# trap is skipped on SIGKILL) and reclaim it so a dead holder can't wedge the poller.
if [ -d "$LOCK_DIR" ]; then
  lock_mtime=$(stat -f %m "$LOCK_DIR" 2>/dev/null)
  if [ -n "$lock_mtime" ] && [ "$(( $(date +%s) - lock_mtime ))" -gt 3 ]; then
    rmdir "$LOCK_DIR" 2>/dev/null
  fi
fi

# NEVER break a held lock to run concurrently — that destroys mutual exclusion and
# C1 comes back (a still-running stale tick would `--set` after the breaker did).
# Strict exclusion is preserved: the ONLY lock-removal of a held lock is the
# self-healing stale-breaker above (holder presumed DEAD after 3s, EXIT trap
# skipped on SIGKILL). A live holder is always waited out.
if [ "${NET_SPEED_PERF:-0}" = "1" ]; then
  # Authoritative run (perf-ON / perf-OFF): MUST be the last writer, so it waits
  # for the lock long enough to outlast any live holder. A real poll tick holds the
  # lock only for its netstat + arg-assembly + one `--set` — well under a second;
  # ~3.5s of wait covers even a heavily-preempted tick. Past that the holder is
  # treated as dead and the stale-breaker (3s) will have reclaimed the lockdir, so
  # the next mkdir here succeeds — never a concurrent break of a LIVE lock.
  for _ in $(seq 1 70); do
    if mkdir "$LOCK_DIR" 2>/dev/null; then break; fi
    # Re-run the stale-breaker each spin so a holder that dies mid-wait is reclaimed.
    if [ -d "$LOCK_DIR" ]; then
      lm=$(stat -f %m "$LOCK_DIR" 2>/dev/null)
      [ -n "$lm" ] && [ "$(( $(date +%s) - lm ))" -gt 3 ] && rmdir "$LOCK_DIR" 2>/dev/null
    fi
    sleep 0.05
  done
  trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
else
  # Poll tick: bounded ~250ms wait; if contended, SKIP this tick (never block the
  # 5s poller, never write lock-free). A tick therefore only ever writes while it
  # HOLDS the lock — so it can't write after a perf run that's waiting on the lock.
  HAVE_LOCK=0
  for _ in 1 2 3 4 5; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      HAVE_LOCK=1
      trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
      break
    fi
    sleep 0.05
  done
  [ "$HAVE_LOCK" = 1 ] || exit 0
fi

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
# A direction's division shows only when its rate clears MIN_RATE — set high enough
# to ignore the constant background trickle (VPN keepalive, telemetry, sync deltas;
# observed ~0.1-2.5 KB/s on this machine) so an idle direction's division actually
# disappears. Raise if background still triggers it, lower to catch lighter traffic.
MIN_RATE=5120   # bytes/s (5 KB/s)
DOWN_VIS=0; [ "$SPEED_IN" -ge "$MIN_RATE" ]  && DOWN_VIS=1
UP_VIS=0;   [ "$SPEED_OUT" -ge "$MIN_RATE" ] && UP_VIS=1

# Performance mode hides the whole traffic group. Honor it HERE so this poller and
# performance-mode.sh can never DISAGREE about visibility. They are two independent
# writers of the same six traffic items; when a perf-mode toggle overlapped a poll
# tick, their separate `--set` calls interleaved and split the decision — one drew a
# bracket while the other hid its member item, leaving a bracket around a hidden
# member: an EMPTY pill (frozen, because perf-on then stops this poller). With both
# writers computing the SAME result, any overlap converges to one consistent state.
# State file path is owned by performance-mode.sh (PERFORMANCE_MODE_STATE).
#
# This read is INSIDE the writer lock acquired at the top, held through the final
# `--set` below (released by the EXIT trap) — so a poll tick and the perf-triggered
# run can't interleave: whichever runs LAST re-reads the state here and writes a
# result consistent with it. Tick-first: it finishes its `--set` before perf-ON can
# write `on`. Perf-first: the tick blocks, then reads `on` here and hides. Both
# orderings converge to hidden after perf-ON returns (C1 fix).
if [ "$(cat /tmp/performance-mode.state 2>/dev/null)" = "on" ]; then
  DOWN_VIS=0
  UP_VIS=0
fi

# Up and down are SEPARATE divisions (brackets traffic_up / traffic_down), each
# with static DIVISION_PAD edges (set in the item files) and shown only when its
# direction has traffic. network_down is the sole poller so its item stays
# drawing=on (toggle icon+label); network_up is passive (toggle drawing).
if [ "$DOWN_VIS" = 1 ]; then
  DOWN_ARGS=(icon.drawing=on label.drawing=on label="$LABEL_DOWN"); TD=on
else
  DOWN_ARGS=(icon.drawing=off label.drawing=off); TD=off
fi
if [ "$UP_VIS" = 1 ]; then
  UP_ARGS=(drawing=on label="$LABEL_UP"); TU=on
else
  UP_ARGS=(drawing=off); TU=off
fi

# Layout L->R: up | spacer_ud | down | spacer3 | connectivity. spacer_ud only when
# BOTH divisions show; spacer3 (gap to connectivity) whenever EITHER shows.
SUD=off; [ "$UP_VIS" = 1 ] && [ "$DOWN_VIS" = 1 ] && SUD=on
S3=off;  { [ "$UP_VIS" = 1 ] || [ "$DOWN_VIS" = 1 ]; } && S3=on

# EMPTY-PILL FIX — a SketchyBar bracket paints via TWO independent layers that the
# item-level `drawing` flag does NOT control: the fill (background.drawing) AND the
# drop shadow (background.shadow.drawing). Two traps, both verified via --query:
#   1. `drawing=off` does NOT stop either paint layer — it only FREEZES the bracket's
#      geometry at its last tracked width. So `drawing=off` while the member is hidden
#      leaves an ~82px-wide frozen rectangle still painting its fill+shadow = the
#      EMPTY PILL. (background.drawing=off kills the fill; background.shadow.drawing=off
#      kills the shadow — a softened ~50% black box that reads as a grey pill.)
#   2. So we keep the bracket drawing=ON permanently (it then TRACKS its member and
#      COLLAPSES to ~2px when the member is empty, instead of freezing wide) and toggle
#      BOTH paint layers ($TD/$TU) to show/hide it. (The perf-mode/lock work above fixed
#      a different, rarer symptom; THIS is the normal-mode empty pill.)
sketchybar --set network_down "${DOWN_ARGS[@]}" \
           --set network_up "${UP_ARGS[@]}" \
           --set traffic_down drawing=on background.drawing=$TD background.shadow.drawing=$TD \
           --set traffic_up drawing=on background.drawing=$TU background.shadow.drawing=$TU \
           --set spacer_ud drawing=$SUD \
           --set spacer3 drawing=$S3
