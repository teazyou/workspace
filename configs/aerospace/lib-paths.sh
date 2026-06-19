#!/bin/bash
# Shared /tmp path contract and timing constants for the AeroSpace WM scripts.
#
# Single source of truth for the cross-script /tmp file paths (state files,
# per-workspace grace markers, per-monitor MRU files + lockdirs) and for the
# coupled grace/placement timing constants. Sourced by:
#   - apply-display-profile.sh  (SECONDARY_BAR_STATE)
#   - performance-mode.sh       (PERFORMANCE_MODE_STATE)
#   - secondary-bar-toggle.sh   (SECONDARY_BAR_STATE)
#   - track-workspace-mru.sh    (mru_file/mru_lock)
#   - empty-workspace-watcher.sh(grace_file/mru_file, GRACE_SECONDS, POLL_INTERVAL)
#   - open-dock-app.sh          (grace_file, PLACEMENT_CAP_SECONDS)
#   - aerospace.toml startup    (PERFORMANCE_MODE_STATE, SECONDARY_BAR_STATE)
#
# IMPORTANT: every consumer runs under `set -euo pipefail`. Every name a
# consumer references MUST be defined here or sourcing trips on an unset var.
# Bash 3.2 compatible (no associative arrays / mapfile).

# --- State files ---------------------------------------------------------
PERFORMANCE_MODE_STATE="/tmp/performance-mode.state"
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

# Poll cadence for the empty-workspace-watcher main loop (seconds).
POLL_INTERVAL=0.5

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
