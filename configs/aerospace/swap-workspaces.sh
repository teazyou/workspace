#!/bin/bash
#
# Swap the managed contents and supported tiling layout of two AeroSpace
# workspaces. Invoked by the service-mode digit bindings in aerospace.toml.
#
# This deliberately uses explicit window IDs throughout. AeroSpace's
# list-windows output is application/title ordered, not tree ordered, so the
# layout snapshot gets its tiled window order by walking focus --dfs-index; that
# index intentionally excludes floating windows.
#
# Supported tiling shapes:
#   * a flat h_tiles or v_tiles root
#   * the repository's balanced 2x2 grid: h_tiles root + v_tiles children
#     (and the rotated v_tiles root + h_tiles version)
# Floating windows and AeroSpace fullscreen state are moved/restored too.
# Unknown nested/accordion layouts are rejected before the first mutation.
#
# Bash 3.2 compatible: no associative arrays, mapfile, or readarray.

# Do not enable nounset here. macOS ships Bash 3.2, where expanding an empty
# indexed array under `set -u` is itself an error. Empty workspaces are a first-
# class swap case, and every externally supplied value below is validated.

SCRIPT_NAME=${0##*/}
AEROSPACE_BIN=${AEROSPACE_BIN:-aerospace}
SKETCHYBAR_BIN=${SKETCHYBAR_BIN:-sketchybar}
BORDERS_STOP_BIN=${BORDERS_STOP_BIN:-/usr/bin/killall}
BORDERS_START_BIN=${BORDERS_START_BIN:-"${HOME:-}/.config/borders/bordersrc"}
SWAP_LOCK_DIR=${SWAP_LOCK_DIR:-"${TMPDIR:-/tmp}/aerospace-workspace-swap.lock"}
# Deliberately stable rather than PID-derived: if an interrupted transaction
# leaves windows here, the next invocation refuses and makes the condition
# visible instead of silently selecting a different workspace.
SWAP_TEMP_WORKSPACE=${SWAP_TEMP_WORKSPACE:-aerospace-swap-staging}

# Test-only callers may set this to retain a concise diagnostic log. The normal
# binding is intentionally silent; a failed swap must not leave a notification
# or a Terminal window behind.
SWAP_LOG_FILE=${SWAP_LOG_FILE:-}

log() {
    if [ -n "$SWAP_LOG_FILE" ]; then
        printf '%s: %s\n' "$SCRIPT_NAME" "$*" >> "$SWAP_LOG_FILE"
    fi
}

warn() {
    log "warning: $*"
}

aero() {
    "$AEROSPACE_BIN" "$@"
}

contains_id() {
    # contains_id <needle> <array values...>
    local needle="$1"
    shift
    local value
    for value in "$@"; do
        [ "$value" = "$needle" ] && return 0
    done
    return 1
}

index_of_id() {
    # Prints the zero-based index, or nothing when absent.
    local needle="$1"
    shift
    local i=0
    local value
    for value in "$@"; do
        if [ "$value" = "$needle" ]; then
            printf '%s\n' "$i"
            return 0
        fi
        i=$((i + 1))
    done
    return 1
}

same_id_lists() {
    # same_id_lists <left name> <right name>; array names are internal only.
    local left_name="$1"
    local right_name="$2"
    local left_count right_count i
    eval "left_count=\${#${left_name}[@]}"
    eval "right_count=\${#${right_name}[@]}"
    [ "$left_count" -eq "$right_count" ] || return 1
    i=0
    while [ "$i" -lt "$left_count" ]; do
        local left_value right_value
        eval "left_value=\${${left_name}[${i}]}"
        eval "right_value=\${${right_name}[${i}]}"
        [ "$left_value" = "$right_value" ] || return 1
        i=$((i + 1))
    done
    return 0
}

same_id_sets() {
    # same_id_sets <left name> <right name>; ordering is intentionally ignored.
    local left_name="$1"
    local right_name="$2"
    local left_count right_count i left_value
    eval "left_count=\${#${left_name}[@]}"
    eval "right_count=\${#${right_name}[@]}"
    [ "$left_count" -eq "$right_count" ] || return 1
    i=0
    while [ "$i" -lt "$left_count" ]; do
        eval "left_value=\${${left_name}[${i}]}"
        # Both names are script-owned indexed arrays; eval only retrieves the
        # array value, while contains_id performs the comparison.
        eval "contains_id \"\$left_value\" \"\${${right_name}[@]}\"" || return 1
        i=$((i + 1))
    done
    return 0
}

root_layout_for_workspace() {
    local workspace="$1"
    local rows row found_ws root focused

    rows=$(aero list-workspaces --all \
        --format '%{workspace}|%{workspace-root-container-layout}|%{workspace-is-focused}') || return 1
    while IFS= read -r row; do
        [ -n "$row" ] || continue
        IFS='|' read -r found_ws root focused <<EOF
$row
EOF
        if [ "$found_ws" = "$workspace" ]; then
            printf '%s\n' "$root"
            return 0
        fi
    done <<EOF
$rows
EOF
    return 1
}

# Snapshot globals. snapshot_workspace resets all of them on each call.
SNAP_WORKSPACE=''
SNAP_ROOT=''
SNAP_WAS_FOCUSED='false'
SNAP_IDS=()
SNAP_PARENTS=()
SNAP_FULLSCREEN=()
SNAP_DFS=()
SNAP_TILED_DFS=()
SNAP_KIND=''

metadata_for_id() {
    # metadata_for_id <id>; prints "parent|fullscreen".
    local id="$1"
    local i=0
    while [ "$i" -lt "${#SNAP_IDS[@]}" ]; do
        if [ "${SNAP_IDS[$i]}" = "$id" ]; then
            printf '%s|%s\n' "${SNAP_PARENTS[$i]}" "${SNAP_FULLSCREEN[$i]}"
            return 0
        fi
        i=$((i + 1))
    done
    return 1
}

snapshot_dfs_order() {
    local workspace="$1"
    local i=0 id meta parent tiled_count=0 leaf_index=0

    SNAP_DFS=()
    SNAP_TILED_DFS=()

    # focus --dfs-index traverses rootTilingContainer leaf windows. Floating
    # windows are deliberately absent from that index space, even though they
    # are still listed/moved/restored elsewhere in this transaction.
    while [ "$leaf_index" -lt "${#SNAP_IDS[@]}" ]; do
        if [ "${SNAP_PARENTS[$leaf_index]}" != 'floating' ]; then
            tiled_count=$((tiled_count + 1))
        fi
        leaf_index=$((leaf_index + 1))
    done
    [ "$tiled_count" -eq 0 ] && return 0

    # list-windows is not usable for this: it sorts by app/title. The sequence
    # of focus --dfs-index calls is the authoritative tiled-tree order.
    aero workspace "$workspace" || return 1
    while [ "$i" -lt "$tiled_count" ]; do
        aero focus --dfs-index "$i" || return 1
        id=$(aero list-windows --focused --format '%{window-id}') || return 1
        [ -n "$id" ] || return 1
        contains_id "$id" "${SNAP_IDS[@]}" || return 1
        contains_id "$id" "${SNAP_DFS[@]}" && return 1
        meta=$(metadata_for_id "$id") || return 1
        parent=${meta%%|*}
        [ "$parent" != 'floating' ] || return 1
        SNAP_DFS+=("$id")
        SNAP_TILED_DFS+=("$id")
        i=$((i + 1))
    done
    return 0
}

snapshot_workspace() {
    local workspace="$1"
    local root rows row id fullscreen parent row_root

    SNAP_WORKSPACE="$workspace"
    SNAP_ROOT=''
    SNAP_WAS_FOCUSED='false'
    SNAP_IDS=()
    SNAP_PARENTS=()
    SNAP_FULLSCREEN=()
    SNAP_DFS=()
    SNAP_TILED_DFS=()
    SNAP_KIND=''

    root=$(root_layout_for_workspace "$workspace") || return 1
    [ -n "$root" ] || return 1
    SNAP_ROOT="$root"

    rows=$(aero list-windows --workspace "$workspace" \
        --format '%{window-id}|%{window-is-fullscreen}|%{window-parent-container-layout}|%{workspace-root-container-layout}') || return 1
    while IFS= read -r row; do
        [ -n "$row" ] || continue
        IFS='|' read -r id fullscreen parent row_root <<EOF
$row
EOF
        [ -n "$id" ] || return 1
        [ -n "$fullscreen" ] || return 1
        [ -n "$parent" ] || return 1
        # The per-window root is a consistency check, not the source of truth:
        # it is unavailable for an empty workspace.
        [ "$row_root" = "$SNAP_ROOT" ] || return 1
        contains_id "$id" "${SNAP_IDS[@]}" && return 1
        SNAP_IDS+=("$id")
        SNAP_FULLSCREEN+=("$fullscreen")
        SNAP_PARENTS+=("$parent")
    done <<EOF
$rows
EOF

    snapshot_dfs_order "$workspace" || return 1
    return 0
}

classify_snapshot() {
    local i parent tiled_count=0 all_flat=true all_grid=true expected_child

    case "$SNAP_ROOT" in
        h_tiles) expected_child='v_tiles' ;;
        v_tiles) expected_child='h_tiles' ;;
        *) return 1 ;;
    esac

    i=0
    while [ "$i" -lt "${#SNAP_IDS[@]}" ]; do
        parent="${SNAP_PARENTS[$i]}"
        if [ "$parent" = 'floating' ]; then
            :
        elif [ "$parent" = "$SNAP_ROOT" ]; then
            tiled_count=$((tiled_count + 1))
            all_grid=false
        elif [ "$parent" = "$expected_child" ]; then
            tiled_count=$((tiled_count + 1))
            all_flat=false
        else
            return 1
        fi
        i=$((i + 1))
    done

    # No tiled windows is a valid (and useful) flat workspace: retain its root
    # orientation for the next window that opens there.
    if [ "$tiled_count" -eq 0 ] || [ "$all_flat" = true ]; then
        SNAP_KIND='flat'
        return 0
    fi

    # list-windows exposes a leaf's parent layout but not a parent ID. With the
    # repository's fixed 2x2 construction, exactly four leaves with the
    # opposite parent orientation uniquely describes the supported grid. Any
    # richer nesting is refused instead of being silently flattened.
    if [ "$tiled_count" -eq 4 ] && [ "$all_grid" = true ]; then
        SNAP_KIND='grid'
        return 0
    fi
    return 1
}

# Saved snapshots. They intentionally use parallel indexed arrays for Bash 3.2.
source_root=''
source_kind=''
source_ids=()
source_parents=()
source_fullscreen=()
source_dfs=()
source_tiled_dfs=()
target_root=''
target_kind=''
target_ids=()
target_parents=()
target_fullscreen=()
target_dfs=()
target_tiled_dfs=()

save_snapshot_as() {
    local which="$1"
    case "$which" in
        source)
            source_root="$SNAP_ROOT"
            source_kind="$SNAP_KIND"
            source_ids=("${SNAP_IDS[@]}")
            source_parents=("${SNAP_PARENTS[@]}")
            source_fullscreen=("${SNAP_FULLSCREEN[@]}")
            source_dfs=("${SNAP_DFS[@]}")
            source_tiled_dfs=("${SNAP_TILED_DFS[@]}")
            ;;
        target)
            target_root="$SNAP_ROOT"
            target_kind="$SNAP_KIND"
            target_ids=("${SNAP_IDS[@]}")
            target_parents=("${SNAP_PARENTS[@]}")
            target_fullscreen=("${SNAP_FULLSCREEN[@]}")
            target_dfs=("${SNAP_DFS[@]}")
            target_tiled_dfs=("${SNAP_TILED_DFS[@]}")
            ;;
        *) return 1 ;;
    esac
}

# Restore globals, set by select_snapshot. Keep this explicit rather than using
# indirect array expansion on data that originated outside this script.
RESTORE_ROOT=''
RESTORE_KIND=''
RESTORE_IDS=()
RESTORE_PARENTS=()
RESTORE_FULLSCREEN=()
RESTORE_DFS=()
RESTORE_TILED_DFS=()

select_snapshot() {
    local which="$1"
    case "$which" in
        source)
            RESTORE_ROOT="$source_root"
            RESTORE_KIND="$source_kind"
            RESTORE_IDS=("${source_ids[@]}")
            RESTORE_PARENTS=("${source_parents[@]}")
            RESTORE_FULLSCREEN=("${source_fullscreen[@]}")
            RESTORE_DFS=("${source_dfs[@]}")
            RESTORE_TILED_DFS=("${source_tiled_dfs[@]}")
            ;;
        target)
            RESTORE_ROOT="$target_root"
            RESTORE_KIND="$target_kind"
            RESTORE_IDS=("${target_ids[@]}")
            RESTORE_PARENTS=("${target_parents[@]}")
            RESTORE_FULLSCREEN=("${target_fullscreen[@]}")
            RESTORE_DFS=("${target_dfs[@]}")
            RESTORE_TILED_DFS=("${target_tiled_dfs[@]}")
            ;;
        *) return 1 ;;
    esac
}

capture_current_dfs() {
    # capture_current_dfs <workspace>; results in tiled-only CURRENT_DFS.
    local workspace="$1"
    local rows row id parent tiled_count=0 i=0
    CURRENT_DFS=()
    rows=$(aero list-windows --workspace "$workspace" \
        --format '%{window-id}|%{window-parent-container-layout}') || return 1
    while IFS= read -r row; do
        [ -n "$row" ] || continue
        IFS='|' read -r id parent <<EOF
$row
EOF
        [ -n "$id" ] && [ -n "$parent" ] || return 1
        [ "$parent" = 'floating' ] || tiled_count=$((tiled_count + 1))
    done <<EOF
$rows
EOF
    [ "$tiled_count" -eq 0 ] && return 0
    aero workspace "$workspace" || return 1
    while [ "$i" -lt "$tiled_count" ]; do
        aero focus --dfs-index "$i" || return 1
        id=$(aero list-windows --focused --format '%{window-id}') || return 1
        [ -n "$id" ] || return 1
        contains_id "$id" "${CURRENT_DFS[@]}" && return 1
        CURRENT_DFS+=("$id")
        i=$((i + 1))
    done
    return 0
}

reorder_by_dfs() {
    # Order only tiled leaves. Floating windows are not part of AeroSpace's
    # dfs-index/swap order; their own layout is restored separately. Each move
    # is an adjacent dfs-prev swap, never a
    # direction/geometry heuristic.
    local workspace="$1"
    local i wanted position j previous

    capture_current_dfs "$workspace" || return 1
    same_id_sets CURRENT_DFS RESTORE_DFS || return 1

    i=0
    while [ "$i" -lt "${#RESTORE_DFS[@]}" ]; do
        wanted="${RESTORE_DFS[$i]}"
        position=$(index_of_id "$wanted" "${CURRENT_DFS[@]}") || return 1
        j="$position"
        while [ "$j" -gt "$i" ]; do
            aero swap --window-id "$wanted" dfs-prev || return 1
            previous="${CURRENT_DFS[$((j - 1))]}"
            CURRENT_DFS[$j]="$previous"
            CURRENT_DFS[$((j - 1))]="$wanted"
            j=$((j - 1))
        done
        i=$((i + 1))
    done

    capture_current_dfs "$workspace" || return 1
    same_id_lists CURRENT_DFS RESTORE_DFS
}

restore_fullscreen_state() {
    local i
    i=0
    while [ "$i" -lt "${#RESTORE_IDS[@]}" ]; do
        if [ "${RESTORE_FULLSCREEN[$i]}" = 'true' ]; then
            aero fullscreen on --window-id "${RESTORE_IDS[$i]}" || return 1
        fi
        i=$((i + 1))
    done
    return 0
}

disable_fullscreen_state() {
    local i
    i=0
    while [ "$i" -lt "${#RESTORE_IDS[@]}" ]; do
        if [ "${RESTORE_FULLSCREEN[$i]}" = 'true' ]; then
            aero fullscreen off --window-id "${RESTORE_IDS[$i]}" || return 1
        fi
        i=$((i + 1))
    done
    return 0
}

restore_floating_state() {
    # AeroSpace normally keeps a moved floating node floating. Set it
    # explicitly nevertheless: a version-specific move regression must not
    # silently turn a manually positioned window into a grid tile.
    local i
    i=0
    while [ "$i" -lt "${#RESTORE_IDS[@]}" ]; do
        if [ "${RESTORE_PARENTS[$i]}" = 'floating' ]; then
            aero layout --window-id "${RESTORE_IDS[$i]}" floating || return 1
        fi
        i=$((i + 1))
    done
    return 0
}

verify_restored_layout() {
    local workspace="$1"
    local i parent expected_child

    snapshot_workspace "$workspace" || return 1
    [ "$SNAP_ROOT" = "$RESTORE_ROOT" ] || return 1
    same_id_lists SNAP_DFS RESTORE_DFS || return 1

    case "$RESTORE_ROOT" in
        h_tiles) expected_child='v_tiles' ;;
        v_tiles) expected_child='h_tiles' ;;
        *) return 1 ;;
    esac

    i=0
    while [ "$i" -lt "${#SNAP_IDS[@]}" ]; do
        parent="${SNAP_PARENTS[$i]}"
        if contains_id "${SNAP_IDS[$i]}" "${RESTORE_TILED_DFS[@]}"; then
            if [ "$RESTORE_KIND" = 'flat' ]; then
                [ "$parent" = "$RESTORE_ROOT" ] || return 1
            else
                [ "$parent" = "$expected_child" ] || return 1
            fi
        else
            [ "$parent" = 'floating' ] || return 1
        fi
        i=$((i + 1))
    done
    return 0
}

restore_workspace() {
    # restore_workspace <destination workspace> <source|target snapshot>
    local workspace="$1"
    local which="$2"
    local orientation i

    select_snapshot "$which" || return 1

    # Saved fullscreen state was suspended for both workspaces before the first
    # move. Restore it only after the root/tree and DFS sequence are rebuilt.
    restore_floating_state || return 1
    aero flatten-workspace-tree --workspace "$workspace" || return 1
    case "$RESTORE_ROOT" in
        h_tiles) orientation='horizontal' ;;
        v_tiles) orientation='vertical' ;;
        *) return 1 ;;
    esac
    aero layout --workspace "$workspace" --root tiles "$orientation" || return 1
    reorder_by_dfs "$workspace" || return 1

    if [ "$RESTORE_KIND" = 'grid' ]; then
        [ "${#RESTORE_TILED_DFS[@]}" -eq 4 ] || return 1
        if [ "$RESTORE_ROOT" = 'h_tiles' ]; then
            # Pair each adjacent DFS pair into a vertical column under the
            # horizontal root. Normalization supplies the opposite orientation.
            aero join-with --window-id "${RESTORE_TILED_DFS[1]}" left || return 1
            aero join-with --window-id "${RESTORE_TILED_DFS[3]}" left || return 1
        else
            # Rotated 2x2: horizontal rows beneath a vertical root.
            aero join-with --window-id "${RESTORE_TILED_DFS[1]}" up || return 1
            aero join-with --window-id "${RESTORE_TILED_DFS[3]}" up || return 1
        fi
        aero balance-sizes --workspace "$workspace" || return 1
    fi

    verify_restored_layout "$workspace" || return 1
    restore_fullscreen_state
}

move_windows() {
    # move_windows <destination> <window ids...>
    local destination="$1"
    shift
    local id
    for id in "$@"; do
        aero move-node-to-workspace --window-id "$id" -- "$destination" || return 1
    done
    return 0
}

move_windows_best_effort() {
    # Rollback cannot abandon later captured IDs merely because an earlier
    # window was closed or another individual move failed.
    local destination="$1"
    shift
    local id failed=false
    for id in "$@"; do
        aero move-node-to-workspace --window-id "$id" -- "$destination" || failed=true
    done
    [ "$failed" = false ]
}

workspace_exists() {
    local workspace="$1"
    local all_workspaces ws
    all_workspaces=$(aero list-workspaces --all --format '%{workspace}') || return 2
    while IFS= read -r ws; do
        [ "$ws" = "$workspace" ] && return 0
    done <<EOF
$all_workspaces
EOF
    return 1
}

reserve_temporary_workspace() {
    # An existing empty workspace is harmless and reusable. An occupied one is
    # a discoverable crash leftover (or user conflict), so do not touch it.
    local exists_status count
    [ -n "$SWAP_TEMP_WORKSPACE" ] || return 1
    workspace_exists "$SWAP_TEMP_WORKSPACE"
    exists_status=$?
    case "$exists_status" in
        0)
            count=$(aero list-windows --workspace "$SWAP_TEMP_WORKSPACE" --count) || return 1
            case "$count" in
                ''|*[!0-9]*) return 1 ;;
            esac
            [ "$count" -eq 0 ] || {
                warn "reserved temporary workspace $SWAP_TEMP_WORKSPACE contains windows"
                return 1
            }
            ;;
        1) ;;
        *) return 1 ;;
    esac
    printf '%s\n' "$SWAP_TEMP_WORKSPACE"
}

suspend_snapshot_fullscreen() {
    # Called after both snapshots/layouts and temporary workspace reservation
    # have succeeded, but before the first window move.
    select_snapshot "$1" || return 1
    disable_fullscreen_state
}

BORDERS_SUSPENDED=false
LOCK_HELD=false

suspend_borders() {
    # Avoid flashing the active border while focus --dfs-index walks the grid.
    # Only promise a restart when the configured launcher exists and killall
    # confirms that a borders process was actually running.
    [ -x "$BORDERS_START_BIN" ] || return 0
    if "$BORDERS_STOP_BIN" borders >/dev/null 2>&1; then
        BORDERS_SUSPENDED=true
        log 'borders suspended'
    fi
    return 0
}

resume_borders() {
    [ "$BORDERS_SUSPENDED" = true ] || return 0
    BORDERS_SUSPENDED=false
    # Detach the relaunched process from this short-lived helper shell; without
    # nohup it can receive SIGHUP and disappear as soon as the swap exits.
    /usr/bin/nohup "$BORDERS_START_BIN" </dev/null >/dev/null 2>&1 &
    log 'borders restarted'
}

cleanup() {
    resume_borders
    if [ "$LOCK_HELD" = true ]; then
        rm -f "$SWAP_LOCK_DIR/pid" 2>/dev/null || true
        rmdir "$SWAP_LOCK_DIR" 2>/dev/null || true
    fi
}

acquire_lock() {
    # mkdir is atomic on macOS and needs no external flock dependency.
    if mkdir "$SWAP_LOCK_DIR" 2>/dev/null; then
        printf '%s\n' "$$" > "$SWAP_LOCK_DIR/pid" || {
            rmdir "$SWAP_LOCK_DIR" 2>/dev/null || true
            return 1
        }
        LOCK_HELD=true
        return 0
    fi

    # A hard-killed earlier invocation leaves its pid marker behind. Reclaim
    # only a lock whose recorded process no longer exists; an unreadable or
    # malformed marker remains protected rather than risking concurrent swaps.
    local holder
    holder=$(cat "$SWAP_LOCK_DIR/pid" 2>/dev/null || true)
    case "$holder" in
        ''|*[!0-9]*) ;;
        *)
            if ! kill -0 "$holder" 2>/dev/null; then
                rm -f "$SWAP_LOCK_DIR/pid" 2>/dev/null || true
                if rmdir "$SWAP_LOCK_DIR" 2>/dev/null && mkdir "$SWAP_LOCK_DIR" 2>/dev/null; then
                    printf '%s\n' "$$" > "$SWAP_LOCK_DIR/pid" || {
                        rmdir "$SWAP_LOCK_DIR" 2>/dev/null || true
                        return 1
                    }
                    LOCK_HELD=true
                    return 0
                fi
            fi
            ;;
    esac
    warn "another workspace swap is already running"
    return 1
}

rollback() {
    # Best effort only: do not let one already-closed window prevent the rest of
    # the captured windows being returned. Layout rebuilds are likewise attempted
    # independently. The empty temporary workspace then disappears naturally.
    warn 'swap failed after mutation; attempting rollback'
    # A successful first rebuild might already have restored fullscreen. Put
    # both sets back into a movable state before their IDs are returned.
    suspend_snapshot_fullscreen source || warn 'could not suspend every source fullscreen window'
    suspend_snapshot_fullscreen target || warn 'could not suspend every target fullscreen window'
    move_windows_best_effort "$ORIGINAL_WORKSPACE" "${source_ids[@]}" || warn 'could not return every source window'
    move_windows_best_effort "$TARGET_WORKSPACE" "${target_ids[@]}" || warn 'could not return every target window'
    restore_workspace "$ORIGINAL_WORKSPACE" source || warn 'could not fully restore source layout'
    restore_workspace "$TARGET_WORKSPACE" target || warn 'could not fully restore target layout'
    aero workspace "$ORIGINAL_WORKSPACE" >/dev/null 2>&1 || true
}

restore_preflight_focus() {
    # DFS capture has to visit the target workspace. On a validation/reservation
    # failure nothing has moved yet, so restore both the original workspace and
    # its exact focused window without invoking the success-only bar/mouse hooks.
    aero workspace "$ORIGINAL_WORKSPACE" >/dev/null 2>&1 || true
    if [ -n "$ORIGINAL_FOCUSED_WINDOW" ] && \
       { contains_id "$ORIGINAL_FOCUSED_WINDOW" "${source_ids[@]}" || \
         contains_id "$ORIGINAL_FOCUSED_WINDOW" "${SNAP_IDS[@]}"; }; then
        aero focus --window-id "$ORIGINAL_FOCUSED_WINDOW" >/dev/null 2>&1 || true
    fi
}

finish_success() {
    # The script changes workspaces while taking DFS snapshots/rebuilding. Put
    # focus back on the original physical workspace, select the first window now
    # listed there, repaint the bar, then apply the keyboard-focus mouse policy.
    local incoming_window='' listed_windows candidate
    aero workspace "$ORIGINAL_WORKSPACE" || return 1
    listed_windows=$(aero list-windows --workspace "$ORIGINAL_WORKSPACE" \
        --format '%{window-id}') || return 1
    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        if aero focus --window-id "$candidate" >/dev/null 2>&1; then
            incoming_window="$candidate"
            break
        fi
    done <<EOF
$listed_windows
EOF
    "$SKETCHYBAR_BIN" --trigger aerospace_workspace_change \
        "FOCUSED_WORKSPACE=$ORIGINAL_WORKSPACE" >/dev/null 2>&1 || true
    if [ -n "$incoming_window" ]; then
        if ! aero move-mouse window-lazy-center >/dev/null 2>&1; then
            aero move-mouse monitor-lazy-center >/dev/null 2>&1 || true
        fi
    else
        # An empty incoming workspace has no focused window to center on.
        aero move-mouse monitor-lazy-center >/dev/null 2>&1 || true
    fi
    return 0
}

usage() {
    printf 'Usage: %s <workspace digit 0-9>\n' "$SCRIPT_NAME" >&2
}

main() {
    [ "$#" -eq 1 ] || { usage; return 2; }
    TARGET_WORKSPACE=${1:-}
    case "$TARGET_WORKSPACE" in
        [0-9]) ;;
        *) usage; return 2 ;;
    esac

    # Read this before acquiring a lock so the self-target path is a strict
    # AeroSpace no-op (no temp workspace, layout/focus mutation, bar repaint,
    # or mouse movement). Recheck after acquiring the lock below for races.
    ORIGINAL_WORKSPACE=$(aero list-workspaces --focused --format '%{workspace}') || return 1
    [ -n "$ORIGINAL_WORKSPACE" ] || return 1
    if [ "$ORIGINAL_WORKSPACE" = "$TARGET_WORKSPACE" ]; then
        return 0
    fi

    acquire_lock || return 1
    trap cleanup EXIT HUP INT TERM

    ORIGINAL_WORKSPACE=$(aero list-workspaces --focused --format '%{workspace}') || return 1
    [ -n "$ORIGINAL_WORKSPACE" ] || return 1
    if [ "$ORIGINAL_WORKSPACE" = "$TARGET_WORKSPACE" ]; then
        return 0
    fi

    suspend_borders

    # Snapshot focus metadata before the DFS walks intentionally change focus.
    # AeroSpace has no per-unfocused-workspace focused-window query; the contract
    # here is to restore the originally focused *workspace* at completion.
    ORIGINAL_FOCUSED_WINDOW=$(aero list-windows --focused --format '%{window-id}' 2>/dev/null || true)
    log "source=$ORIGINAL_WORKSPACE target=$TARGET_WORKSPACE focused-window=$ORIGINAL_FOCUSED_WINDOW"

    if ! snapshot_workspace "$ORIGINAL_WORKSPACE"; then
        restore_preflight_focus
        return 1
    fi
    if ! classify_snapshot; then
        warn "unsupported layout on workspace $ORIGINAL_WORKSPACE"
        restore_preflight_focus
        return 1
    fi
    if ! save_snapshot_as source; then
        restore_preflight_focus
        return 1
    fi

    if ! snapshot_workspace "$TARGET_WORKSPACE"; then
        restore_preflight_focus
        return 1
    fi
    if ! classify_snapshot; then
        warn "unsupported layout on workspace $TARGET_WORKSPACE"
        restore_preflight_focus
        return 1
    fi
    if ! save_snapshot_as target; then
        restore_preflight_focus
        return 1
    fi

    if [ "$SWAP_TEMP_WORKSPACE" = "$ORIGINAL_WORKSPACE" ] || \
       [ "$SWAP_TEMP_WORKSPACE" = "$TARGET_WORKSPACE" ]; then
        warn 'reserved temporary workspace must differ from both swap endpoints'
        restore_preflight_focus
        return 1
    fi
    if ! TEMPORARY_WORKSPACE=$(reserve_temporary_workspace); then
        restore_preflight_focus
        return 1
    fi
    log "temporary=$TEMPORARY_WORKSPACE source-layout=$source_kind target-layout=$target_kind"

    # No mutation before both snapshots/layout validation and the temporary-name
    # reservation have succeeded. Fullscreen suspension itself is a mutation,
    # so every failure from here enters the rollback path.
    MUTATED=false
    MUTATED=true
    if ! suspend_snapshot_fullscreen source; then
        :
    elif ! suspend_snapshot_fullscreen target; then
        :
    elif ! move_windows "$TEMPORARY_WORKSPACE" "${source_ids[@]}"; then
        :
    else
        if ! move_windows "$ORIGINAL_WORKSPACE" "${target_ids[@]}"; then
            :
        elif ! move_windows "$TARGET_WORKSPACE" "${source_ids[@]}"; then
            :
        elif ! restore_workspace "$ORIGINAL_WORKSPACE" target; then
            :
        elif ! restore_workspace "$TARGET_WORKSPACE" source; then
            :
        elif ! finish_success; then
            :
        else
            return 0
        fi
    fi

    [ "$MUTATED" = true ] && rollback
    return 1
}

main "$@"
