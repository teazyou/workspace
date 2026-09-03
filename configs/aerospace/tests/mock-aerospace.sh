#!/bin/bash
# Minimal deterministic AeroSpace state-machine mock for swap-workspaces_test.
# State records: W|workspace|root, N|id|workspace|parent|fullscreen,
# O|workspace|comma-separated-tiled-DFS, F|focused-workspace, FW|focused-window.

set -u

: "${MOCK_STATE:?MOCK_STATE is required}"
: "${MOCK_LOG:?MOCK_LOG is required}"

cmd=${1:-}
shift || true
line="$cmd $*"
printf '%s\n' "$line" >> "$MOCK_LOG"

# Match AeroSpace's reserved-name rule so the transaction tests cannot accept
# a staging workspace that the live server would reject.
if [ "$cmd" = 'move-node-to-workspace' ] || [ "$cmd" = 'workspace' ]; then
    possible_workspace=${@: -1}
    case "$possible_workspace" in
        _*) exit 1 ;;
    esac
fi

if [ -n "${MOCK_FAIL_ON:-}" ] && [ "$line" = "$MOCK_FAIL_ON" ]; then
    exit 1
fi
if [ -n "${MOCK_FAIL_WINDOW_ID:-}" ]; then
    case "$line" in
        "move-node-to-workspace --window-id ${MOCK_FAIL_WINDOW_ID} "*) exit 1 ;;
    esac
fi

state_tmp() {
    printf '%s.mock-tmp-%s\n' "$MOCK_STATE" "$$"
}

focused_workspace() {
    awk -F'|' '$1 == "F" { print $2; exit }' "$MOCK_STATE"
}

focused_window() {
    awk -F'|' '$1 == "FW" { print $2; exit }' "$MOCK_STATE"
}

root_for() {
    awk -F'|' -v ws="$1" '$1 == "W" && $2 == ws { print $3; exit }' "$MOCK_STATE"
}

workspace_for() {
    awk -F'|' -v id="$1" '$1 == "N" && $2 == id { print $3; exit }' "$MOCK_STATE"
}

parent_for() {
    awk -F'|' -v id="$1" '$1 == "N" && $2 == id { print $4; exit }' "$MOCK_STATE"
}

order_for() {
    awk -F'|' -v ws="$1" '$1 == "O" && $2 == ws { print $3; exit }' "$MOCK_STATE"
}

set_order() {
    local ws="$1" ids="$2" tmp
    tmp=$(state_tmp)
    awk -F'|' -v ws="$ws" -v ids="$ids" '
        $1 == "O" && $2 == ws { print "O|" ws "|" ids; found=1; next }
        { print }
        END { if (!found) print "O|" ws "|" ids }
    ' "$MOCK_STATE" > "$tmp" && mv "$tmp" "$MOCK_STATE"
}

set_focused_workspace() {
    local ws="$1" tmp
    tmp=$(state_tmp)
    awk -F'|' -v ws="$ws" '
        $1 == "F" { print "F|" ws; found=1; next }
        { print }
        END { if (!found) print "F|" ws }
    ' "$MOCK_STATE" > "$tmp" && mv "$tmp" "$MOCK_STATE"
}

set_focused_window() {
    local id="$1" tmp
    tmp=$(state_tmp)
    awk -F'|' -v id="$id" '
        $1 == "FW" { print "FW|" id; found=1; next }
        { print }
        END { if (!found) print "FW|" id }
    ' "$MOCK_STATE" > "$tmp" && mv "$tmp" "$MOCK_STATE"
}

ensure_workspace() {
    local ws="$1" root
    root=$(root_for "$ws")
    [ -n "$root" ] && return 0
    printf 'W|%s|h_tiles\nO|%s|\n' "$ws" "$ws" >> "$MOCK_STATE"
}

set_window_workspace_and_parent() {
    local id="$1" ws="$2" parent="$3" tmp
    tmp=$(state_tmp)
    awk -F'|' -v id="$id" -v ws="$ws" -v parent="$parent" '
        $1 == "N" && $2 == id { print "N|" id "|" ws "|" parent "|" $5; next }
        { print }
    ' "$MOCK_STATE" > "$tmp" && mv "$tmp" "$MOCK_STATE"
}

set_window_parent() {
    local id="$1" parent="$2" tmp
    tmp=$(state_tmp)
    awk -F'|' -v id="$id" -v parent="$parent" '
        $1 == "N" && $2 == id { print "N|" $2 "|" $3 "|" parent "|" $5; next }
        { print }
    ' "$MOCK_STATE" > "$tmp" && mv "$tmp" "$MOCK_STATE"
}

set_window_fullscreen() {
    local id="$1" fullscreen="$2" tmp
    tmp=$(state_tmp)
    awk -F'|' -v id="$id" -v fullscreen="$fullscreen" '
        $1 == "N" && $2 == id { print "N|" $2 "|" $3 "|" $4 "|" fullscreen; next }
        { print }
    ' "$MOCK_STATE" > "$tmp" && mv "$tmp" "$MOCK_STATE"
}

set_root() {
    local ws="$1" root="$2" tmp
    tmp=$(state_tmp)
    awk -F'|' -v ws="$ws" -v root="$root" '
        $1 == "W" && $2 == ws { print "W|" ws "|" root; next }
        { print }
    ' "$MOCK_STATE" > "$tmp" && mv "$tmp" "$MOCK_STATE"
}

remove_from_order() {
    local ws="$1" id="$2" old ids='' item first=true
    old=$(order_for "$ws")
    local_old_ifs=$IFS
    IFS=,
    for item in $old; do
        [ -n "$item" ] || continue
        [ "$item" = "$id" ] && continue
        if [ "$first" = true ]; then ids="$item"; first=false; else ids="$ids,$item"; fi
    done
    IFS=$local_old_ifs
    set_order "$ws" "$ids"
}

append_to_order() {
    local ws="$1" id="$2" old
    old=$(order_for "$ws")
    if [ -n "$old" ]; then set_order "$ws" "$old,$id"; else set_order "$ws" "$id"; fi
}

set_nonfloating_parents_to_root() {
    local ws="$1" root="$2" tmp
    tmp=$(state_tmp)
    awk -F'|' -v ws="$ws" -v root="$root" '
        $1 == "N" && $3 == ws && $4 != "floating" { print "N|" $2 "|" $3 "|" root "|" $5; next }
        { print }
    ' "$MOCK_STATE" > "$tmp" && mv "$tmp" "$MOCK_STATE"
}

argument_after() {
    local wanted="$1"
    shift
    while [ "$#" -gt 0 ]; do
        if [ "$1" = "$wanted" ]; then
            shift
            printf '%s\n' "${1:-}"
            return 0
        fi
        shift
    done
    return 1
}

case "$cmd" in
    list-workspaces)
        format=$(argument_after --format "$@" || true)
        if [ "${1:-}" = '--focused' ]; then
            printf '%s\n' "$(focused_workspace)"
        elif [ "${1:-}" = '--all' ]; then
            focused=$(focused_workspace)
            awk -F'|' -v fmt="$format" -v focused="$focused" '
                $1 == "W" {
                    if (fmt == "%{workspace}") print $2
                    else print $2 "|" $3 "|" ($2 == focused ? "true" : "false")
                }
            ' "$MOCK_STATE"
        fi
        ;;
    list-windows)
        if [ "${1:-}" = '--focused' ]; then
            printf '%s\n' "$(focused_window)"
            exit 0
        fi
        ws=$(argument_after --workspace "$@" || true)
        [ -n "$ws" ] || exit 1
        if printf '%s\n' "$*" | /usr/bin/grep -q -- '--count'; then
            awk -F'|' -v ws="$ws" '$1 == "N" && $3 == ws { n++ } END { print n + 0 }' "$MOCK_STATE"
        elif printf '%s\n' "$*" | /usr/bin/grep -q 'window-is-fullscreen'; then
            root=$(root_for "$ws")
            awk -F'|' -v ws="$ws" -v root="$root" '$1 == "N" && $3 == ws { print $2 "|" $5 "|" $4 "|" root }' "$MOCK_STATE"
        elif printf '%s\n' "$*" | /usr/bin/grep -q 'window-parent-container-layout'; then
            awk -F'|' -v ws="$ws" '$1 == "N" && $3 == ws { print $2 "|" $4 }' "$MOCK_STATE"
        else
            awk -F'|' -v ws="$ws" '$1 == "N" && $3 == ws { print $2 }' "$MOCK_STATE"
        fi
        ;;
    workspace)
        ws=${@: -1}
        ensure_workspace "$ws"
        set_focused_workspace "$ws"
        first=$(order_for "$ws")
        first=${first%%,*}
        set_focused_window "$first"
        ;;
    focus)
        if [ "${1:-}" = '--dfs-index' ]; then
            index=${2:-}
            ws=$(focused_workspace)
            ids=$(order_for "$ws")
            old_ifs=$IFS
            IFS=,
            set -- $ids
            IFS=$old_ifs
            eval "id=\${$((index + 1)):-}"
            [ -n "$id" ] || exit 1
            set_focused_window "$id"
        elif [ "${1:-}" = '--window-id' ]; then
            set_focused_window "${2:-}"
            set_focused_workspace "$(workspace_for "${2:-}")"
        fi
        ;;
    move-node-to-workspace)
        id=$(argument_after --window-id "$@" || true)
        destination=${@: -1}
        old_ws=$(workspace_for "$id")
        parent=$(parent_for "$id")
        [ -n "$old_ws" ] || exit 1
        ensure_workspace "$destination"
        if [ "$parent" = 'floating' ]; then new_parent='floating'; else new_parent=$(root_for "$destination"); fi
        # The mock O records only the tiling-root DFS, matching live
        # focus --dfs-index. Floating windows are tracked as N records but do
        # not enter the DFS sequence.
        if [ "$parent" != 'floating' ]; then
            remove_from_order "$old_ws" "$id"
            append_to_order "$destination" "$id"
        fi
        set_window_workspace_and_parent "$id" "$destination" "$new_parent"
        ;;
    flatten-workspace-tree)
        ws=$(argument_after --workspace "$@" || true)
        set_nonfloating_parents_to_root "$ws" "$(root_for "$ws")"
        ;;
    layout)
        id=$(argument_after --window-id "$@" || true)
        if [ -n "$id" ]; then
            old_ws=$(workspace_for "$id")
            old_parent=$(parent_for "$id")
            [ "$old_parent" = 'floating' ] || remove_from_order "$old_ws" "$id"
            set_window_parent "$id" floating
        else
            ws=$(argument_after --workspace "$@" || true)
            orientation=${@: -1}
            if [ "$orientation" = horizontal ]; then root='h_tiles'; else root='v_tiles'; fi
            set_root "$ws" "$root"
            set_nonfloating_parents_to_root "$ws" "$root"
        fi
        ;;
    swap)
        id=$(argument_after --window-id "$@" || true)
        ws=$(focused_workspace)
        old=$(order_for "$ws")
        old_ifs=$IFS
        IFS=,
        set -- $old
        IFS=$old_ifs
        found=0 index=1
        while [ "$index" -le "$#" ]; do
            eval "item=\${$index}"
            if [ "$item" = "$id" ]; then found="$index"; break; fi
            index=$((index + 1))
        done
        [ "$found" -gt 1 ] || exit 1
        previous_index=$((found - 1))
        eval "previous=\${$previous_index}"
        rebuilt='' first=true index=1
        while [ "$index" -le "$#" ]; do
            if [ "$index" -eq "$previous_index" ]; then item="$id"
            elif [ "$index" -eq "$found" ]; then item="$previous"
            else eval "item=\${$index}"
            fi
            if [ "$first" = true ]; then rebuilt="$item"; first=false; else rebuilt="$rebuilt,$item"; fi
            index=$((index + 1))
        done
        set_order "$ws" "$rebuilt"
        ;;
    join-with)
        id=$(argument_after --window-id "$@" || true)
        direction=${@: -1}
        ws=$(workspace_for "$id")
        root=$(root_for "$ws")
        ids=$(order_for "$ws")
        old_ifs=$IFS
        IFS=,
        set -- $ids
        IFS=$old_ifs
        previous=''
        for item in "$@"; do
            if [ "$item" = "$id" ]; then break; fi
            previous="$item"
        done
        [ -n "$previous" ] || exit 1
        if [ "$root" = h_tiles ] && [ "$direction" = left ]; then child='v_tiles';
        elif [ "$root" = v_tiles ] && [ "$direction" = up ]; then child='h_tiles';
        else exit 1
        fi
        set_window_parent "$previous" "$child"
        set_window_parent "$id" "$child"
        ;;
    balance-sizes|move-mouse)
        ;;
    fullscreen)
        action=${1:-}
        id=$(argument_after --window-id "$@" || true)
        [ "$action" = on ] && set_window_fullscreen "$id" true
        [ "$action" = off ] && set_window_fullscreen "$id" false
        ;;
    *)
        printf 'unsupported mock command: %s\n' "$cmd" >&2
        exit 1
        ;;
esac

exit 0
