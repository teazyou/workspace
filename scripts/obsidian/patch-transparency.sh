#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Obsidian real (blur-free) window transparency — main-process asar patch.
#
# WHAT IT DOES
#   Obsidian's main vault window is already created with
#   backgroundColor:"#00000000" but WITHOUT Electron's `transparent:true`, so
#   the transparent colour composites onto an OPAQUE backing → you never see the
#   desktop. macOS's built-in "Translucent window" only adds the frosted VIBRANCY
#   blur (and is broken/grey on macOS 26). This patch injects `transparent:!0`
#   into that BrowserWindow options object inside obsidian.asar, giving CRISP,
#   blur-free window transparency — the same technique VS Code's "Vibrancy
#   Continued" uses via its `type:"transparent"` mode.
#
#   The visible amount is driven entirely by the CSS snippet
#   configs/dot-obsidian/snippets/transparency.css (var --wallpaper-alpha) —
#   text is left opaque so it stays readable. This script only unlocks the
#   window backing; the snippet + `transparency` in appearance.json do the rest.
#
# WHY A SCRIPT (re-apply model)
#   obsidian.asar is REPLACED by every Obsidian update, wiping the patch — exact
#   same maintenance model as the VS Code Claude-panel patch. Re-run this after
#   each update. Idempotent + safe to re-run any time.
#
# INTEGRITY / SIGNING
#   Only app.asar (the 73KB loader) is covered by Info.plist ElectronAsarIntegrity;
#   obsidian.asar (the 24MB main bundle we patch) is NOT — so no integrity-hash
#   recompute is needed. We DO re-sign the app ad-hoc afterwards so the modified
#   bundle still launches under the hardened runtime.
#
# USAGE
#   scripts/obsidian/patch-transparency.sh            # apply (default)
#   scripts/obsidian/patch-transparency.sh --restore  # revert to stock asar
#   OBSIDIAN_APP=/path/to/Obsidian.app  scripts/obsidian/patch-transparency.sh
#
# See docs/obsidian/transparency.md for the full mechanism, the CSS knob, and
# the macOS-26 context.
# ---------------------------------------------------------------------------
set -euo pipefail

APP="${OBSIDIAN_APP:-/Applications/Obsidian.app}"
ASAR="$APP/Contents/Resources/obsidian.asar"
BAK="$ASAR.orig-transparency-bak"
# Unique anchor for the MAIN vault window options object (verified: exactly one
# occurrence in obsidian.asar/main.js; the pop-out + starter windows use
# different backgroundColor values so they are not matched).
ANCHOR='backgroundColor:"#00000000",trafficLightPosition:'
PATCHED='transparent:!0,backgroundColor:"#00000000",trafficLightPosition:'

log() { printf '  %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[ -d "$APP" ]  || die "Obsidian.app not found at $APP (set OBSIDIAN_APP=)"
[ -f "$ASAR" ] || die "obsidian.asar not found at $ASAR"
command -v node >/dev/null || die "node not found (needed for @electron/asar)"

# --- quit Obsidian if running (asar is memory-mapped while it runs) -----------
if pgrep -x Obsidian >/dev/null; then
  log "Obsidian is running — quitting it..."
  osascript -e 'quit app "Obsidian"' 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x Obsidian >/dev/null || break; sleep 0.5; done
  pgrep -x Obsidian >/dev/null && { pkill -x Obsidian || true; sleep 1; }
fi

resign() {  # re-sign ad-hoc + drop quarantine so the modified bundle launches
  log "Re-signing app (ad-hoc) + clearing quarantine..."
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || log "WARN: codesign failed (app may still launch)"
  xattr -cr "$APP" 2>/dev/null || true
}

# --- restore mode ------------------------------------------------------------
if [ "${1:-}" = "--restore" ]; then
  [ -f "$BAK" ] || die "no backup at $BAK — nothing to restore"
  log "Restoring stock obsidian.asar from backup..."
  cp "$BAK" "$ASAR"
  resign
  log "Restored. Relaunch Obsidian."
  exit 0
fi

# --- apply mode --------------------------------------------------------------
# Idempotency: inspect the LIVE asar (fast header scan) for our injected token.
if node -e '
  const {readFileSync}=require("fs");
  const asar=process.argv[1];
  const b=readFileSync(asar);
  process.exit(b.includes("transparent:!0,backgroundColor:\"#00000000\",trafficLightPosition:")?0:1);
' "$ASAR" 2>/dev/null; then
  log "Already patched (transparent:!0 present) — nothing to do."
  exit 0
fi

[ -f "$BAK" ] || { log "Backing up stock asar → $(basename "$BAK")"; cp "$ASAR" "$BAK"; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
log "Extracting obsidian.asar..."
npx --yes @electron/asar extract "$ASAR" "$TMP/u" >/dev/null 2>&1 || die "asar extract failed"
MAIN="$TMP/u/main.js"
[ -f "$MAIN" ] || die "main.js missing in extracted asar"

n=$(grep -oF "$ANCHOR" "$MAIN" | wc -l | tr -d ' ')
[ "$n" = "1" ] || die "expected exactly 1 anchor, found $n — bundle changed; re-derive the patch (see docs/obsidian/transparency.md)"

log "Injecting transparent:!0 into the main-window options..."
perl -i -pe "s/\Q$ANCHOR\E/$PATCHED/" "$MAIN"
grep -qF "$PATCHED" "$MAIN" || die "injection did not take"

log "Repacking obsidian.asar..."
npx --yes @electron/asar pack "$TMP/u" "$ASAR" >/dev/null 2>&1 || die "asar pack failed"
chmod 755 "$ASAR"
resign

log "Done. Enable the 'transparency' snippet (already in appearance.json) and relaunch Obsidian."
