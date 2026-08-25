#!/bin/bash
# Shared /tmp path contract and timing constants for the AeroSpace WM scripts.
#
# Single source of truth for the cross-script /tmp state-file paths and timing
# constants. Sourced by:
#   - open-dock-app.sh          (PLACEMENT_CAP_SECONDS)
#
# NOTE: consumers deliberately run WITHOUT strict-mode flags. Do NOT add
# `set -e` here or in consumers — benign nonzero exits (e.g. aerospace focus
# races) would abort scripts; do NOT use `set -u` — bash 3.2 faults on empty-
# array "${arr[@]}" expansion. Every name referenced is defined above.
# Bash 3.2 compatible (no associative arrays / mapfile).

# --- Timing constants ----------------------------------------------------
# PLACEMENT_CAP_SECONDS bounds how long open-dock-app.sh's backgrounded
# placement enforcer polls for a launching app's first window before giving up.
PLACEMENT_CAP_SECONDS=18
