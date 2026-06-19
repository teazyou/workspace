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

source ~/workspace/configs/aerospace/lib-paths.sh

ws="$1"
[[ -z "$ws" ]] && exit 0

mon=$(aerospace list-workspaces --all --format '%{monitor-id} %{workspace}' 2>/dev/null \
        | awk -v w="$ws" '$2==w {print $1; exit}')
[[ -z "$mon" ]] && exit 0

file="$(mru_file "$mon")"
lock="$(mru_lock "$mon")"

# Reclaim an orphaned lockdir: the EXIT trap that removes $lock is skipped on
# SIGKILL, which would otherwise block MRU writes for this monitor forever. If
# the lockdir exists and is older than ~2s (far longer than the ~250ms a real
# writer holds it), assume it's stale and remove it.
if [[ -d "$lock" ]]; then
    lock_mtime=$(stat -f %m "$lock" 2>/dev/null)
    if [[ -n "$lock_mtime" ]] && (( $(date +%s) - lock_mtime > 2 )); then
        rmdir "$lock" 2>/dev/null
    fi
fi

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
