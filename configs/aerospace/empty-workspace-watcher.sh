#!/bin/bash
# Polls every 500ms. If the focused workspace has zero windows, switches to
# the most-recently-focused non-empty workspace (per MRU history). If none
# of the MRU entries are still non-empty, picks the first non-empty workspace
# AeroSpace reports. If everything is empty, stays put (no bounce loop).
#
# Stateless per-tick check by design: we never inspect "previous focus" — the
# user is never deliberately on an empty workspace, so any empty focus is a
# bounce candidate.
#
# MRU state at /tmp/aerospace-ws-mru.state is written by track-workspace-mru.sh
# from aerospace.toml's exec-on-workspace-change hook. /tmp is wiped on reboot;
# that's intentional (fresh state each session).

mru_file="/tmp/aerospace-ws-mru.state"

while true; do
    focused_ws=$(aerospace list-workspaces --focused 2>/dev/null)
    if [[ -n "$focused_ws" ]]; then
        count=$(aerospace list-windows --workspace "$focused_ws" --count 2>/dev/null)
        if [[ "$count" == "0" ]]; then
            # Single query: all non-empty workspaces, one per line.
            nonempty=$(aerospace list-workspaces --monitor all --empty no 2>/dev/null)

            target=""
            if [[ -n "$nonempty" && -f "$mru_file" ]]; then
                # Walk MRU newest-first; pick first entry that is currently non-empty.
                while IFS= read -r ws; do
                    [[ -z "$ws" || "$ws" == "$focused_ws" ]] && continue
                    if printf '%s\n' "$nonempty" | grep -qFx "$ws"; then
                        target="$ws"
                        break
                    fi
                done < <(tail -r "$mru_file")
            fi

            # Fallback: first non-empty workspace AeroSpace knows about.
            if [[ -z "$target" && -n "$nonempty" ]]; then
                target=$(printf '%s\n' "$nonempty" | head -n 1)
            fi

            # If everything is empty, or target IS the focused empty ws, stay put.
            if [[ -n "$target" && "$target" != "$focused_ws" ]]; then
                # --fail-if-noop avoids firing exec-on-workspace-change for a no-op.
                aerospace workspace --fail-if-noop "$target" 2>/dev/null
            fi
        fi
    fi
    sleep 0.5
done
