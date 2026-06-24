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

source ~/workspace/configs/aerospace/lib-paths.sh

# Returns 0 if "<mon-id> <ws>" appears as a whole line in $1. Fork-free Bash 3.2
# membership test: wrap both the blob and the needle in newlines so a `case`
# glob only matches a complete line (no partial-line false positives).
contains_pair() {
    case "
$1
" in
        *"
$2
"*) return 0 ;;
    esac
    return 1
}

while true; do
    # --- Snapshot AeroSpace state once per tick ---
    orig_focused_mon=$(aero list-monitors --focused --format '%{monitor-id}' 2>/dev/null)
    visible_pairs=$(aero list-workspaces --monitor all --visible --format '%{monitor-id} %{workspace}' 2>/dev/null)
    nonempty_pairs=$(aero list-workspaces --monitor all --empty no --format '%{monitor-id} %{workspace}' 2>/dev/null)

    if [[ -z "$orig_focused_mon" || -z "$visible_pairs" ]]; then
        sleep "$POLL_INTERVAL"
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
        grace_marker="$(grace_file "$vis")"
        if [[ -f "$grace_marker" ]]; then
            age=$(( $(date +%s) - $(stat -f %m "$grace_marker" 2>/dev/null || echo 0) ))
            if [[ $age -lt $GRACE_SECONDS ]]; then
                continue
            fi
        fi

        # Workspaces assigned to this monitor (one per line).
        mon_ws_list=$(aero list-workspaces --monitor "$mon" --format '%{workspace}' 2>/dev/null)
        [[ -z "$mon_ws_list" ]] && continue

        # Non-empty workspaces on this monitor (filter the global non-empty list).
        mon_nonempty=$(printf '%s\n' "$nonempty_pairs" | awk -v m="$mon" '$1==m {print $2}')

        # 1) MRU walk (newest-last in the file → reverse with `tail -r`, BSD).
        target=""
        mru_path="$(mru_file "$mon")"
        if [[ -n "$mon_nonempty" && -f "$mru_path" ]]; then
            while IFS= read -r cand; do
                [[ -z "$cand" || "$cand" == "$vis" ]] && continue
                if printf '%s\n' "$mon_ws_list"  | grep -qFx "$cand" \
                && printf '%s\n' "$mon_nonempty" | grep -qFx "$cand"; then
                    target="$cand"
                    break
                fi
            done < <(tail -r "$mru_path" 2>/dev/null)
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
            aero workspace --fail-if-noop "$target" 2>/dev/null
        else
            aero workspace "$target" 2>/dev/null \
                && aero focus-monitor "$orig_focused_mon" 2>/dev/null
        fi
    done

    sleep "$POLL_INTERVAL"
done
