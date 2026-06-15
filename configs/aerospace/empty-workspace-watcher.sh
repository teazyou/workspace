#!/bin/bash
# Per-monitor empty-workspace watcher. Polls every 500ms.
#
# For each monitor:
#   - If its currently visible workspace has any windows → skip.
#   - If a fresh grace marker exists for that visible workspace → skip
#     (open-dock-app.sh touches /tmp/aerospace-empty-watcher-grace-<ws>
#     during in-flight app launches; mtime < 20s = still in flight).
#   - Otherwise bounce that monitor's visible workspace to a non-empty
#     workspace assigned to that same monitor:
#       1. Walk per-monitor MRU /tmp/aerospace-ws-mru-mon-<mon-id>.state
#          newest-first, pick first entry that (a) is on this monitor and
#          (b) is currently non-empty.
#       2. Fallback: first workspace AeroSpace lists for this monitor
#          that is currently non-empty.
#       3. Hard fallback: every ws on this monitor is empty → bounce to the
#          first ws AeroSpace lists for this monitor (aerospace.toml
#          assignment order; today: ws1 for main, ws7 for secondary, ws0 for the Sidecar/third monitor).
#       4. If target equals the (empty) visible ws → stay put.
#
# Bouncing a non-focused monitor: `aerospace workspace <target>` switches
# that monitor's visible ws AND steals focus to that monitor. We then
# call `aerospace focus-monitor <orig-mon-id>` to return focus. ~100ms
# borders flicker is accepted by the user.
#
# Bouncing the focused monitor: `aerospace workspace --fail-if-noop <target>`
# (no focus restore needed — focus stays on this monitor because the
# target workspace is also on this monitor).
#
# Bash 3.2 (macOS /bin/bash): no associative arrays, no mapfile. We use
# parallel arrays and grep-against-blob for membership tests.
#
# focus-monitor uses GLOB patterns for names — names like "Sidecar Display
# (AirPlay)" break literal-name matching. We use the numeric monitor-id
# instead (verified to work with `aerospace focus-monitor <id>`).

grace_seconds=20

# Returns 0 if "<mon-id> <ws>" appears as a line in $1.
contains_pair() {
    printf '%s\n' "$1" | grep -qFx "$2"
}

while true; do
    # --- Snapshot AeroSpace state once per tick ---
    orig_focused_mon=$(aerospace list-monitors --focused --format '%{monitor-id}' 2>/dev/null)
    visible_pairs=$(aerospace list-workspaces --monitor all --visible --format '%{monitor-id} %{workspace}' 2>/dev/null)
    nonempty_pairs=$(aerospace list-workspaces --monitor all --empty no --format '%{monitor-id} %{workspace}' 2>/dev/null)

    if [[ -z "$orig_focused_mon" || -z "$visible_pairs" ]]; then
        sleep 0.5
        continue
    fi

    # Build parallel arrays of (mon_id, visible_ws) per visible row.
    mon_ids=()
    visible_ws=()
    while IFS=' ' read -r m w; do
        [[ -z "$m" || -z "$w" ]] && continue
        mon_ids+=("$m")
        visible_ws+=("$w")
    done <<< "$visible_pairs"

    # --- Per-monitor pass, deterministic order (as AeroSpace returns it) ---
    for i in "${!mon_ids[@]}"; do
        mon="${mon_ids[$i]}"
        vis="${visible_ws[$i]}"

        # Skip if the visible ws has windows.
        if contains_pair "$nonempty_pairs" "$mon $vis"; then
            continue
        fi

        # Skip if a fresh grace marker exists for this monitor's visible ws.
        grace_file="/tmp/aerospace-empty-watcher-grace-${vis}"
        if [[ -f "$grace_file" ]]; then
            age=$(( $(date +%s) - $(stat -f %m "$grace_file" 2>/dev/null || echo 0) ))
            if [[ $age -lt $grace_seconds ]]; then
                continue
            fi
        fi

        # Workspaces assigned to this monitor (one per line).
        mon_ws_list=$(aerospace list-workspaces --monitor "$mon" --format '%{workspace}' 2>/dev/null)
        [[ -z "$mon_ws_list" ]] && continue

        # Non-empty workspaces on this monitor (filter the global non-empty list).
        mon_nonempty=$(printf '%s\n' "$nonempty_pairs" | awk -v m="$mon" '$1==m {print $2}')

        # 1) MRU walk (newest-last in the file → reverse with `tail -r`, BSD).
        target=""
        mru_file="/tmp/aerospace-ws-mru-mon-${mon}.state"
        if [[ -n "$mon_nonempty" && -f "$mru_file" ]]; then
            while IFS= read -r cand; do
                [[ -z "$cand" || "$cand" == "$vis" ]] && continue
                if printf '%s\n' "$mon_ws_list"  | grep -qFx "$cand" \
                && printf '%s\n' "$mon_nonempty" | grep -qFx "$cand"; then
                    target="$cand"
                    break
                fi
            done < <(tail -r "$mru_file" 2>/dev/null)
        fi

        # 2) Fallback: first non-empty workspace AeroSpace lists for this monitor.
        if [[ -z "$target" && -n "$mon_nonempty" ]]; then
            while IFS= read -r cand; do
                [[ -z "$cand" || "$cand" == "$vis" ]] && continue
                if printf '%s\n' "$mon_nonempty" | grep -qFx "$cand"; then
                    target="$cand"
                    break
                fi
            done <<< "$mon_ws_list"
        fi

        # 3) Hard fallback: monitor is fully empty -> bounce to the first ws
        #    AeroSpace lists for this monitor. Order follows aerospace.toml's
        #    [workspace-to-monitor-force-assignment] / persistent-workspaces
        #    declaration order (today: ws1 for main, ws7 for secondary, ws0 for the Sidecar/third monitor).
        #    L113 guard below naturally no-ops when we are already on that ws.
        if [[ -z "$target" ]]; then
            target=$(printf '%s\n' "$mon_ws_list" | awk 'NF{print; exit}')
        fi

        # Nothing usable, or target is the empty visible ws → stay put.
        [[ -z "$target" || "$target" == "$vis" ]] && continue

        if [[ "$mon" == "$orig_focused_mon" ]]; then
            aerospace workspace --fail-if-noop "$target" 2>/dev/null
        else
            aerospace workspace "$target" 2>/dev/null \
                && aerospace focus-monitor "$orig_focused_mon" 2>/dev/null
        fi
    done

    sleep 0.5
done
