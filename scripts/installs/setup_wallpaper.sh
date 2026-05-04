#!/bin/bash
# scripts/installs/setup_wallpaper.sh
#
# Purpose:
#   Sets the desktop wallpaper to a solid black.
#
#   macOS ships a built-in solid-black image at:
#     /System/Library/Desktop Pictures/Solid Colors/Black.png
#
#   We use that — no need to bundle a PNG in the repo. If for some reason
#   it's missing on a future macOS version, we fall back to generating a
#   1×1 black PNG via the system `sips` tool.
#
# Note:
#   macOS Sonoma+ caches the wallpaper aggressively. After setting, we
#   invalidate the cache so the change takes effect on next login.

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

SYSTEM_BLACK="/System/Library/Desktop Pictures/Solid Colors/Black.png"
FALLBACK_PNG="$APP_CONFIGS/wallpaper/black.png"

# 1. Decide which image to use ------------------------------------------
if [[ -f "$SYSTEM_BLACK" ]]; then
    WALLPAPER="$SYSTEM_BLACK"
    log_wait "Using built-in macOS solid black: $SYSTEM_BLACK"
else
    log_wait "macOS solid black missing — generating a 1×1 black PNG fallback"
    mkdir -p "$(dirname "$FALLBACK_PNG")"
    # Generate a 1×1 PNG and recolor it black using `sips` (built into macOS).
    # We start from a tiny known-good PNG and overwrite its pixel.
    python3 - <<PY
import struct, zlib
sig  = b'\x89PNG\r\n\x1a\n'
def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)
idat = zlib.compress(b'\x00\x00\x00\x00')   # filter byte + RGB(0,0,0)
png  = sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")
open("$FALLBACK_PNG", "wb").write(png)
PY
    WALLPAPER="$FALLBACK_PNG"
fi

# 2. Apply wallpaper to every desktop -----------------------------------
# `every desktop` covers all spaces / displays in a multi-monitor setup.
log_wait "Setting desktop picture on all desktops ..."
osascript <<APPLESCRIPT
tell application "System Events"
    tell every desktop
        set picture to "$WALLPAPER"
    end tell
end tell
APPLESCRIPT

# 3. Invalidate Sonoma+ wallpaper cache ---------------------------------
DESKTOP_DB="$HOME/Library/Application Support/Dock/desktoppicture.db"
if [[ -f "$DESKTOP_DB" ]]; then
    log_wait "Invalidating Dock wallpaper cache ..."
    rm -f "$DESKTOP_DB"
    killall Dock 2>/dev/null || true
fi

log_ok "Wallpaper set to solid black"
