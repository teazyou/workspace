#!/bin/bash
# Shared /tmp path contract and timing constants for the AeroSpace WM scripts.
#
# Single source of truth for the cross-script /tmp state-file paths and timing
# constants. Sourced by:
#   - performance-mode.sh       (PERFORMANCE_MODE_STATE)
#   - open-dock-app.sh          (PLACEMENT_CAP_SECONDS)
#   - aerospace.toml startup    (PERFORMANCE_MODE_STATE)
#   - apply-display-profile.sh  (path contract only)
#
# IMPORTANT: every consumer runs under `set -euo pipefail`. Every name a
# consumer references MUST be defined here or sourcing trips on an unset var.
# Bash 3.2 compatible (no associative arrays / mapfile).

# --- State files ---------------------------------------------------------
PERFORMANCE_MODE_STATE="/tmp/performance-mode.state"

# --- Timing constants ----------------------------------------------------
# PLACEMENT_CAP_SECONDS bounds how long open-dock-app.sh's backgrounded
# placement enforcer polls for a launching app's first window before giving up.
PLACEMENT_CAP_SECONDS=18
