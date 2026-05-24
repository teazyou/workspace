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
grace_seconds=20

while true; do
    focused_ws=$(aerospace list-workspaces --focused 2>/dev/null)
    if [[ -n "$focused_ws" ]]; then
        # Per-workspace grace period: open-dock-app.sh touches
        # /tmp/aerospace-empty-watcher-grace-<ws> when it pre-switches to a
        # target workspace and launches a new app. Skip ticks while the
        # marker for the currently focused workspace is fresh so we don't
        # bounce off the target before the app's first window appears.
        # Daemon still bounces normally for any OTHER empty workspace.
        grace_file="/tmp/aerospace-empty-watcher-grace-${focused_ws}"
        if [[ -f "$grace_file" ]]; then
            age=$(( $(date +%s) - $(stat -f %m "$grace_file" 2>/dev/null || echo 0) ))
            if [[ $age -lt $grace_seconds ]]; then
                sleep 0.5
                continue
            fi
        fi

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
