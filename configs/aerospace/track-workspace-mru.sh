#!/bin/bash
# Appends focused workspace to MRU history, dedup, cap 20.
# Called from aerospace.toml's exec-on-workspace-change hook.
# Uses a mkdir-based lockdir to serialise concurrent writes (atomic on all FS).

ws="$1"
[[ -z "$ws" ]] && exit 0

file="/tmp/aerospace-ws-mru.state"
lock="/tmp/aerospace-ws-mru.lock"

# Spin briefly for the lock; bail after ~250ms so we never block aerospace.
for _ in 1 2 3 4 5; do
    if mkdir "$lock" 2>/dev/null; then
        trap 'rmdir "$lock" 2>/dev/null' EXIT
        { [[ -f "$file" ]] && grep -vFx "$ws" "$file"; echo "$ws"; } \
            | tail -n 20 > "$file.tmp" && mv "$file.tmp" "$file"
        exit 0
    fi
    sleep 0.05
done
exit 0
