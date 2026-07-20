#!/bin/bash
# Shared /tmp path contract and timing constants for the AeroSpace WM scripts.
#
# Single source of truth for the cross-script /tmp file paths (state files,
# per-workspace grace markers, per-monitor MRU files + lockdirs) and for the
# coupled grace/placement timing constants. Sourced by:
#   - apply-display-profile.sh  (SECONDARY_BAR_STATE)
#   - secondary-bar-toggle.sh   (SECONDARY_BAR_STATE)
#   - track-workspace-mru.sh    (mru_file/mru_lock)
#   - empty-workspace-watcher.sh(grace_file/mru_file, GRACE_SECONDS, POLL_INTERVAL)
#   - open-dock-app.sh          (grace_file, PLACEMENT_CAP_SECONDS)
#   - aerospace.toml startup    (SECONDARY_BAR_STATE)
#
# IMPORTANT: every consumer runs under `set -euo pipefail`. Every name a
# consumer references MUST be defined here or sourcing trips on an unset var.
# Bash 3.2 compatible (no associative arrays / mapfile).

# --- State files ---------------------------------------------------------
SECONDARY_BAR_STATE="/tmp/secondary-bar.state"

# --- Timing constants ----------------------------------------------------
# GRACE_SECONDS bounds how long open-dock-app.sh's per-workspace grace marker
# suppresses the empty-workspace-watcher bounce. PLACEMENT_CAP_SECONDS bounds
# how long the placement enforcer polls for the launching app's first window.
# Invariant: GRACE_SECONDS >= PLACEMENT_CAP_SECONDS so the marker never expires
# while the enforcer is still trying to place the window (otherwise the watcher
# could bounce the in-flight launch).
GRACE_SECONDS=20
PLACEMENT_CAP_SECONDS=18

# Poll cadence for the empty-workspace-watcher main loop (seconds). Coarse (2s)
# on purpose: every tick costs AeroSpace CLI calls (energy — 0.5s/3-call ticks
# measured ~8% sustained AeroSpace CPU), and a ~2s bounce latency for an
# emptied workspace is imperceptible.
POLL_INTERVAL=2

# Hard wall-clock cap (seconds) for a single `aerospace` CLI call via aero().
AERO_TIMEOUT="${AERO_TIMEOUT:-3}"

# --- AeroSpace call wrapper ---------------------------------------------
# `aerospace` is a thin client that talks to the AeroSpace.app server over a
# socket. If the server restarts or wedges (observed after a display change),
# an in-flight client call can block on that socket FOREVER. A bare
# `$(aerospace …)` inside a long-running loop then hangs the whole daemon: bash
# blocks waiting for the command substitution to finish, and launchd KeepAlive
# can't help because the process is alive — just stuck. (This is exactly how the
# empty-workspace-watcher silently died for >1 day.)
#
# `aero` runs `aerospace` with a hard timeout so a wedged server degrades to an
# empty/failed result the caller can skip and retry on the next tick, instead of
# a permanent hang. Stock macOS has no GNU `timeout`, so this is bash-native:
# run aerospace in the background, arm a watchdog that SIGKILLs it after
# AERO_TIMEOUT, and `wait` for whichever happens first.
#
# Safe inside `$(…)`: only aerospace writes to the captured stdout; the watchdog
# has its fds redirected to /dev/null so it never holds the command-substitution
# pipe open (otherwise every call would block for the full timeout). Returns
# aerospace's real exit code, or 137 (128+SIGKILL) when it was timed out.
# Bash 3.2 compatible (no `wait -n`, no associative arrays).
aero() {
    aerospace "$@" &
    local apid=$!
    { sleep "$AERO_TIMEOUT"; kill -9 "$apid" 2>/dev/null; } >/dev/null 2>&1 &
    local wpid=$!
    wait "$apid" 2>/dev/null
    local rc=$?
    # aerospace finished (or was killed): tear the watchdog down before it can
    # fire on a now-reaped (possibly reused) pid, and reap its `sleep` child so
    # none linger.
    kill "$wpid" 2>/dev/null
    pkill -P "$wpid" 2>/dev/null
    wait "$wpid" 2>/dev/null
    return "$rc"
}

# --- Path builders -------------------------------------------------------
# Per-workspace grace marker touched by open-dock-app.sh and read by the watcher.
grace_file() {
    printf '%s' "/tmp/aerospace-empty-watcher-grace-${1}"
}

# Per-monitor MRU state file (newest-last workspace list).
mru_file() {
    printf '%s' "/tmp/aerospace-ws-mru-mon-${1}.state"
}

# Per-monitor MRU writer lockdir.
mru_lock() {
    printf '%s' "/tmp/aerospace-ws-mru-mon-${1}.lock"
}

# Age in seconds of a file/dir by mtime (BSD stat). Echoes a large number when
# the path is missing so callers treat "absent" as "stale".
file_age_seconds() {
    local mtime
    mtime=$(stat -f %m "$1" 2>/dev/null) || mtime=""
    if [[ -z "$mtime" ]]; then
        printf '%s' 999999
        return 0
    fi
    printf '%s' "$(( $(date +%s) - mtime ))"
}
