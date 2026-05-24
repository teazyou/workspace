#!/bin/bash
# Per-monitor MRU tracker. Called from aerospace.toml's exec-on-workspace-change
# with $AEROSPACE_FOCUSED_WORKSPACE as $1.
#
# Derives the monitor-id from the workspace (workspaces have static
# monitor assignment via aerospace.toml [workspace-to-monitor-force-assignment])
# and appends to /tmp/aerospace-ws-mru-mon-<mon-id>.state, dedup, cap 10
# (newest last). Uses mkdir-based lockdir per monitor to serialise writers.
#
# Bails after ~250ms if the lock is contended — never blocks aerospace.

ws="$1"
[[ -z "$ws" ]] && exit 0

mon=$(aerospace list-workspaces --all --format '%{monitor-id} %{workspace}' 2>/dev/null \
        | awk -v w="$ws" '$2==w {print $1; exit}')
[[ -z "$mon" ]] && exit 0

file="/tmp/aerospace-ws-mru-mon-${mon}.state"
lock="/tmp/aerospace-ws-mru-mon-${mon}.lock"

for _ in 1 2 3 4 5; do
    if mkdir "$lock" 2>/dev/null; then
        trap 'rmdir "$lock" 2>/dev/null' EXIT
        { [[ -f "$file" ]] && grep -vFx "$ws" "$file"; echo "$ws"; } \
            | tail -n 10 > "$file.tmp" && mv "$file.tmp" "$file"
        exit 0
    fi
    sleep 0.05
done
exit 0
