#!/bin/bash
# Opens a persistent Dock app by its position (0-indexed)
# Usage: open-dock-app.sh <position>

position="${1:-0}"
app_path=$(/usr/libexec/PlistBuddy -c "Print :persistent-apps:${position}:tile-data:file-data:_CFURLString" ~/Library/Preferences/com.apple.dock.plist 2>/dev/null)

if [[ -n "$app_path" ]]; then
    # Remove file:// prefix and URL decode
    app_path="${app_path#file://}"
    app_path=$(python3 -c "import urllib.parse; print(urllib.parse.unquote('$app_path'))")
    open "$app_path"
fi
