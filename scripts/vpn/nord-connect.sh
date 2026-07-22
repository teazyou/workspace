#!/bin/bash
# nord-connect — event-driven one-shot fired by the com.teazyou.nordvpn-native LaunchAgent
# (RunAtLoad at login + WatchPaths on resolv.conf = every network change, including the
# ones our own tunnels cause). NO polling, NO resident process: runs for seconds and exits.
#
# Duties:
#   - first run after a REBOOT (detected via kern.boottime stored in boot-id — NOT a /tmp
#     marker, which macOS deletes after 3 days of uptime): reset state to
#     country=singapore + enabled=1 — "on restart the VPN always comes back, on Singapore".
#   - if enabled and NOTHING is connected: reconnect the saved country (wake, coffee-shop
#     Wi-Fi, tunnel drop). If ANY Nord config is already Connected -> leave it alone. If
#     one is Connecting -> exit (a second start would deadlock the single personal-VPN
#     slot — observed on macOS 26).
#
# Coordination: shares /tmp/nordvpn-native.lock with nord.sh. The lock is taken ONLY
# around the mutating phase (after the network wait) and non-blocking: if the CLI holds
# it, the CLI is in charge — exit silently.
set -uo pipefail

CFG_DIR="$HOME/.config/nordvpn-native"
VPNUTIL="/opt/homebrew/bin/vpnutil"
LOCK="/tmp/nordvpn-native.lock"

log() { echo "$(date '+%F %T') $*"; }

[ -x "$VPNUTIL" ] || exit 0
mkdir -p "$CFG_DIR"

# --- boot detection: kern.bootsessionuuid is stable across sleep/wake and unique per
# boot. (kern.boottime is NOT: it gets recalculated after wake — observed 2026-07-22:
# every wake looked like a reboot, force-re-enabling the VPN the user had turned off.)
BOOT_ID=$(sysctl -n kern.bootsessionuuid 2>/dev/null || echo unknown)
if [ "$BOOT_ID" != "$(cat "$CFG_DIR/boot-id" 2>/dev/null)" ]; then
  echo sg > "$CFG_DIR/country"
  echo 1  > "$CFG_DIR/enabled"
  echo "$BOOT_ID" > "$CFG_DIR/boot-id"
  log "boot: state reset to singapore/enabled"
fi

# --- cheap pre-filters (no lock) ---
[ "$(cat "$CFG_DIR/enabled" 2>/dev/null || echo 1)" = "1" ] || exit 0
states=$("$VPNUTIL" list 2>/dev/null | jq -r '.VPNs[].status' 2>/dev/null)
echo "$states" | grep -q Connected  && exit 0   # something is up — respect it
echo "$states" | grep -q Connecting && exit 0   # in flux — never start a second config

cc=$(cat "$CFG_DIR/country" 2>/dev/null || echo sg)
name="Nord-$(echo "$cc" | tr '[:lower:]' '[:upper:]')"
"$VPNUTIL" list 2>/dev/null | jq -e --arg n "$name" '.VPNs[]|select(.name==$n)' >/dev/null 2>&1 || exit 0  # bundle not approved yet

# --- failure cooldown: after a failed attempt, don't retry for 10 min on the SAME
# network (fingerprint = default-route interface+gateway). Without this, a network
# that can't reach the VPN server gets a connect->blackhole->fail->retry storm that
# makes the whole machine's internet unusable (observed on home Wi-Fi 2026-07-22).
net_fp() { route -n get default 2>/dev/null | awk '/interface:|gateway:/{printf "%s-", $2}'; }  # single token, read-safe
FAIL_STAMP="$CFG_DIR/fail-stamp"
if [ -f "$FAIL_STAMP" ]; then
  read -r fail_ts fail_fp < <(head -1 "$FAIL_STAMP") || true
  now=$(date +%s)
  if [ $((now - ${fail_ts:-0})) -lt 600 ] && [ "$(net_fp)" = "${fail_fp:-}" ]; then
    exit 0   # same network, recent failure — cool down (log once at failure time, not per skip)
  fi
fi

# --- wait for usable network (max ~120s), still lock-free. The IP-literal probe
# keeps this working when a dead tunnel left a broken scoped DNS resolver behind. ---
net_up() { route -n get default >/dev/null 2>&1 && { curl -Is --max-time 3 http://captive.apple.com >/dev/null 2>&1 || curl -Is --max-time 3 http://1.1.1.1 >/dev/null 2>&1; }; }
for _ in $(seq 1 40); do net_up && break; sleep 3; done
net_up || { log "no network after 120s — giving up"; exit 0; }

# --- mutating phase, under the shared lock ---
mkdir "$LOCK" 2>/dev/null || exit 0            # CLI (or another watcher run) is in charge
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# re-check everything after acquiring the lock (CLI may have acted meanwhile)
[ "$(cat "$CFG_DIR/enabled" 2>/dev/null || echo 1)" = "1" ] || exit 0
states=$("$VPNUTIL" list 2>/dev/null | jq -r '.VPNs[].status' 2>/dev/null)
echo "$states" | grep -qE 'Connected|Connecting' && exit 0

base=$(curl -s --max-time 6 ipinfo.io/ip 2>/dev/null | tr -cd '0-9a-fA-F.:')
log "reconnecting $name"
"$VPNUTIL" start "$name" >/dev/null 2>&1
for _ in $(seq 1 30); do
  sleep 1
  s=$("$VPNUTIL" status "$name" 2>/dev/null | awk '{print $2}')
  [ "$s" = "Connected" ] && { log "connected $name"; rm -f "$CFG_DIR/refresh-needed" "$FAIL_STAMP"; command -v sketchybar >/dev/null && sketchybar --trigger vpn_change 2>/dev/null; exit 0; }
done
# vpnutil status can lag: accept if routing moved off the baseline
cur=$(curl -s --max-time 6 ipinfo.io/ip 2>/dev/null | tr -cd '0-9a-fA-F.:')
if [ -n "$cur" ] && [ -n "$base" ] && [ "$cur" != "$base" ]; then
  log "connected $name (status lagging, routing moved)"; rm -f "$CFG_DIR/refresh-needed" "$FAIL_STAMP"
  command -v sketchybar >/dev/null && sketchybar --trigger vpn_change 2>/dev/null; exit 0
fi
"$VPNUTIL" stop "$name" >/dev/null 2>&1        # never leave a dangling Connecting (blackholes traffic)
echo "$(date +%s) $(net_fp)" > "$FAIL_STAMP"   # arm the 10-min same-network cooldown
log "FAILED to connect $name (stopped cleanly) — cooling down 10min on this network; if it persists, run 'nord refresh'"
touch "$CFG_DIR/refresh-needed"
command -v sketchybar >/dev/null && sketchybar --trigger vpn_change 2>/dev/null
exit 1
