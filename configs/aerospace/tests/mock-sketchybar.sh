#!/bin/bash
# Tiny deterministic SketchyBar stand-in for swap-workspaces_test.sh.

set -u

: "${MOCK_SKETCHY_LOG:?MOCK_SKETCHY_LOG is required}"
printf '%s\n' "$*" >> "$MOCK_SKETCHY_LOG"
