#!/bin/bash
# nord — NordVPN native IKEv2 CLI (zero-background design; see docs/vpn/guide-nordvpn-native.md).
#   nord <country>   switch: belgium|be france|fr singapore|sg vietnam|vn usa|us malaysia|my
#   nord on          reconnect the saved country (default singapore)
#   nord off         durable off (survives network changes; reboot re-enables by design)
#   nord toggle      on/off flip (used by the sketchybar vpn item click)
#   nord status      state + tunnels + exit IP + pinned-server health
#   nord list        countries, pinned servers, live statuses
#   nord refresh     regenerate the bundle with today's best servers (1 approval click)
#
# Control tool: vpnutil (brew timac/vpnstatus) — the only CLI able to start/stop the
# profile-installed IKEv2 configs. NEVER start a config while another is Connecting:
# two configs in "Connecting" deadlock macOS's single personal-VPN slot and blackhole
# all traffic (observed on macOS 26) — hence the strict stop->confirm->start sequence
# and the /tmp lock shared with nord-connect.sh (the launchd watcher) so the CLI and
# the watcher never drive vpnutil at the same time.
#
# Success detection: vpnutil's "Connected" can lag the tunnel by minutes (observed on
# slow servers), and exit-country checks are unreliable (VN pins are virtual locations
# that geolocate elsewhere; user may physically BE in the target country). So success =
# target reaches "Connected", OR (still "Connecting" but the public exit IP moved off
# the pre-start baseline).
set -uo pipefail

CFG_DIR="$HOME/.config/nordvpn-native"
VPNUTIL="/opt/homebrew/bin/vpnutil"
GEN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/nord-gen-bundle.sh"
FLAG="$CFG_DIR/refresh-needed"
LOCK="/tmp/nordvpn-native.lock"   # shared with nord-connect.sh

[ -x "$VPNUTIL" ] || { echo "vpnutil missing — brew install timac/vpnstatus/vpnutil" >&2; exit 1; }
mkdir -p "$CFG_DIR"

cc_of() {
  case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
    belgium|be) echo be ;; france|fr) echo fr ;; malaysia|my) echo my ;;
    singapore|sg) echo sg ;; usa|us|united-states) echo us ;; vietnam|vn) echo vn ;;
    *) return 1 ;;
  esac
}
name_of() { echo "Nord-$(echo "$1" | tr '[:lower:]' '[:upper:]')"; }

vlist() { "$VPNUTIL" list 2>/dev/null | jq -r '.VPNs[] | "\(.name) \(.status)"'; }
in_state() { vlist | awk -v s="$1" '$2==s {print $1}'; }

bar_refresh() { command -v sketchybar >/dev/null 2>&1 && sketchybar --trigger vpn_change 2>/dev/null; true; }

lock_acquire() { # wait for the watcher to finish (its mutating phase is bounded), then take the lock
  local i
  for i in $(seq 1 60); do
    mkdir "$LOCK" 2>/dev/null && { trap 'rmdir "$LOCK" 2>/dev/null' EXIT; return 0; }
    sleep 1
  done
  echo "ERROR: lock busy ($LOCK) for 60s — stale? rmdir it if no nord/watcher is running" >&2
  return 1
}

stop_all() { # stop every Nord config and WAIT until none is Connected/Connecting
  local round n
  for round in 1 2 3; do
    for n in $(in_state Connected; in_state Connecting); do "$VPNUTIL" stop "$n" >/dev/null 2>&1; done
    for _ in $(seq 1 20); do
      [ -z "$(in_state Connected; in_state Connecting)" ] && return 0
      sleep 1
    done
  done
  echo "ERROR: a config refuses to disconnect ($( (in_state Connected; in_state Connecting) | tr '\n' ' ')) — toggle it off in System Settings > VPN" >&2
  return 1
}

exit_ip()      { curl -s --max-time 6 ipinfo.io/json 2>/dev/null | jq -r '"\(.ip) \(.country) \(.city)"' 2>/dev/null; }
exit_ip_only() { curl -s --max-time 6 ipinfo.io/ip 2>/dev/null | tr -cd '0-9a-fA-F.:'; }

start_cc() { # $1=cc — start target, wait 45s for Connected, else accept routing-moved; never leave a dangling Connecting
  local name base cur
  name=$(name_of "$1")
  vlist | awk '{print $1}' | grep -qx "$name" || {
    echo "config $name not installed — run 'nord refresh' and approve the profile" >&2; return 1; }
  base=$(exit_ip_only)   # nothing is connected here -> this is the raw (non-VPN) exit
  "$VPNUTIL" start "$name" >/dev/null 2>&1
  for _ in $(seq 1 45); do
    sleep 1
    in_state Connected | grep -qx "$name" && return 0
  done
  if in_state Connecting | grep -qx "$name"; then
    cur=$(exit_ip_only)
    [ -n "$cur" ] && [ -n "$base" ] && [ "$cur" != "$base" ] && {
      echo "note: $name still reports Connecting but routing moved — accepted" >&2; return 0; }
  fi
  "$VPNUTIL" stop "$name" >/dev/null 2>&1   # a stuck Connecting blackholes ALL traffic
  touch "$FLAG"
  echo "ERROR: $name did not connect in 45s — pinned server may be dead. Try 'nord refresh'." >&2
  return 1
}

case "${1:-status}" in
  on|off|toggle|status|list|refresh) cmd="$1" ;;
  *) cc=$(cc_of "$1") || { echo "unknown country: $1 (belgium france singapore vietnam usa malaysia)" >&2; exit 1; }
     cmd=switch ;;
esac

case "$cmd" in
  switch|on)
    if [ "$cmd" = on ]; then
      cc=$(cc_of "$(cat "$CFG_DIR/country" 2>/dev/null || echo sg)" || echo sg)
    fi
    lock_acquire || exit 1
    echo 1 > "$CFG_DIR/enabled"
    stop_all || exit 1
    start_cc "$cc" || { bar_refresh; exit 1; }
    echo "$cc" > "$CFG_DIR/country"; rm -f "$FLAG"
    bar_refresh
    echo "connected: $(name_of "$cc") — exit: $(exit_ip)"
    ;;
  off)
    echo 0 > "$CFG_DIR/enabled"   # write FIRST so the watcher aborts even mid-run
    lock_acquire || exit 1
    stop_all || exit 1
    bar_refresh
    echo "VPN off (durable — reboot re-enables and reverts to singapore)"
    ;;
  toggle)
    if [ -n "$(in_state Connected; in_state Connecting)" ]; then exec "$0" off; else exec "$0" on; fi
    ;;
  status)
    echo "target country : $(cat "$CFG_DIR/country" 2>/dev/null || echo '(none — defaults to sg)')"
    echo "enabled        : $(cat "$CFG_DIR/enabled" 2>/dev/null || echo 1)"
    echo "tunnels:"; vlist | sed 's/^/  /'
    echo "exit           : $(exit_ip)"
    if [ -f "$CFG_DIR/servers" ]; then
      dead=""
      while IFS='=' read -r c h; do
        host -W 3 "$h" >/dev/null 2>&1 || dead="$dead $c($h)"
      done < "$CFG_DIR/servers"
      if [ -n "$dead" ]; then touch "$FLAG"; echo "DEAD PINS:$dead -> run 'nord refresh'"; else rm -f "$FLAG"; echo "pinned servers : all alive"; fi
      bar_refresh
    fi
    [ -f "$FLAG" ] && echo "REFRESH NEEDED — run 'nord refresh' (1 approval click)"
    ;;
  list)
    echo "countries: belgium(be) france(fr) singapore(sg) vietnam(vn) usa(us) malaysia(my)"
    [ -f "$CFG_DIR/servers" ] && { echo "pins:"; sed 's/^/  /' "$CFG_DIR/servers"; }
    echo "tunnels:"; vlist | sed 's/^/  /'
    ;;
  refresh)
    bash "$GEN"
    bar_refresh
    echo "After approving in System Settings, run 'nord <country>' or 'nord on'."
    ;;
esac
exit 0
