#!/bin/bash
# Open / focus the Dock app at <position> (0-indexed).
#
# - App not running       → switch to workspace (position + 1), then open it
# - App running, from elsewhere → focus last window we focused for this app
# - App running, already focused → cycle to next window
#
# State (last-focused window id per app) lives in /tmp/dock-cycle-<bundle_id>.state
# and is only used as a tiebreaker when returning from another app.

position="${1:-0}"
workspace=$((position + 1))

app_path=$(/usr/libexec/PlistBuddy -c "Print :persistent-apps:${position}:tile-data:file-data:_CFURLString" ~/Library/Preferences/com.apple.dock.plist 2>/dev/null)
[[ -z "$app_path" ]] && exit 0

app_path="${app_path#file://}"
app_path=$(python3 -c "import urllib.parse; print(urllib.parse.unquote('$app_path'))")

bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app_path/Contents/Info.plist" 2>/dev/null)

# Fallback: no bundle id → behave like the old script
if [[ -z "$bundle_id" ]]; then
    open "$app_path"
    exit 0
fi

state_file="/tmp/dock-cycle-${bundle_id}.state"

# Live query of all windows for this app. NOTE: `--all` conflicts with filtering
# flags in aerospace, so we use `--monitor all` instead.
windows=()
workspaces_by_window=()
while IFS='|' read -r wid wsn; do
    [[ -n "$wid" ]] || continue
    windows+=("$wid")
    workspaces_by_window+=("$wsn")
done < <(aerospace list-windows --monitor all --app-bundle-id "$bundle_id" --format '%{window-id}|%{workspace}' 2>/dev/null)

# App not running → workspace-target then launch
if [[ ${#windows[@]} -eq 0 ]]; then
    aerospace workspace "$workspace"
    open "$app_path"
    exit 0
fi

focused=$(aerospace list-windows --focused --format '%{window-id}|%{app-bundle-id}' 2>/dev/null)
focused_id="${focused%%|*}"
focused_bundle="${focused##*|}"

next=""
if [[ "$focused_bundle" == "$bundle_id" ]]; then
    # Already on this app → cycle from current position
    for i in "${!windows[@]}"; do
        if [[ "${windows[$i]}" == "$focused_id" ]]; then
            next="${windows[$(( (i + 1) % ${#windows[@]} ))]}"
            break
        fi
    done
else
    # Coming from another app → return to last known window for this app
    last=$(cat "$state_file" 2>/dev/null)
    if [[ -n "$last" ]]; then
        for w in "${windows[@]}"; do
            if [[ "$w" == "$last" ]]; then
                next="$last"
                break
            fi
        done
    fi
fi

# Fallback: first window
next="${next:-${windows[0]}}"

# Look up target window's workspace; switch there explicitly before focusing
# so cross-workspace focus is reliable and macOS-level activation fires
# (borders / sketchybar follow).
next_ws=""
for i in "${!windows[@]}"; do
    if [[ "${windows[$i]}" == "$next" ]]; then
        next_ws="${workspaces_by_window[$i]}"
        break
    fi
done

[[ -n "$next_ws" ]] && aerospace workspace "$next_ws"
aerospace focus --window-id "$next"
echo "$next" > "$state_file"
