#!/bin/bash
# Tiny stand-in for killall and bordersrc in workspace-swap tests.

set -u

: "${MOCK_BORDERS_LOG:?MOCK_BORDERS_LOG is required}"

if [ "$#" -gt 0 ]; then
    printf 'stop %s\n' "$*" >> "$MOCK_BORDERS_LOG"
else
    printf 'start\n' >> "$MOCK_BORDERS_LOG"
fi
