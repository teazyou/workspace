#!/bin/bash
# NordVPN native IKEv2 — bundle generator.
# Fetches the current best IKEv2 server per country from the Nord API, renders ONE
# .mobileconfig containing 6 plain VPN payloads (Nord-BE/FR/SG/VN/US/MY — NO On-Demand:
# on macOS 26 an On-Demand config steals the single personal-VPN slot from every manual
# start and can deadlock into "both Connecting = no internet"; reconnection is handled
# by the launchd one-shots instead, see docs/vpn/guide-nordvpn-native.md) + the NordVPN
# Root CA. Payload UUIDs are stable (uuid5) so each regeneration REPLACES the installed
# profile instead of duplicating it.
#
# macOS 26 blocks headless profile installs, so the rendered bundle is `open`ed and the
# user approves it once in System Settings (General > Device Management). Servers are
# frozen at approval time — re-run via `nord refresh` when a pin goes stale.
#
# Reads service credentials from ~/.config/nordvpn-native/credentials (NORD_USER/NORD_PASS,
# chmod 600, NEVER committed). Everything rendered stays in ~/.config/nordvpn-native/.
set -euo pipefail

CFG_DIR="$HOME/.config/nordvpn-native"
CREDS="$CFG_DIR/credentials"
CA_DER="$CFG_DIR/nord-root.der"
OUT="$CFG_DIR/nord-bundle.mobileconfig"
MANIFEST="$CFG_DIR/servers"

[ -f "$CREDS" ] || { echo "missing $CREDS (NORD_USER/NORD_PASS)" >&2; exit 1; }
[ -f "$CA_DER" ] || { echo "missing $CA_DER (NordVPN Root CA)" >&2; exit 1; }
# shellcheck disable=SC1090
source "$CREDS"
[ -n "${NORD_USER:-}" ] && [ -n "${NORD_PASS:-}" ] || { echo "credentials file must define NORD_USER and NORD_PASS" >&2; exit 1; }

# country-code -> Nord API country id (bash 3.2 on macOS: no associative arrays)
id_of() {
  case "$1" in
    be) echo 21 ;; fr) echo 74 ;; my) echo 131 ;; sg) echo 195 ;; us) echo 228 ;; vn) echo 234 ;;
  esac
}

best_server() { # $1 = country id -> best ikev2 hostname
  curl -sg --max-time 20 "https://api.nordvpn.com/v1/servers/recommendations?filters[country_id]=$1&filters[servers_technologies][identifier]=ikev2&limit=1" | jq -er '.[0].hostname'
}

: > "$MANIFEST.tmp"
for cc in be fr my sg us vn; do
  host=$(best_server "$(id_of "$cc")") || { echo "API lookup failed for $cc" >&2; exit 1; }
  echo "$cc=$host" >> "$MANIFEST.tmp"
  echo "pin: $cc -> $host"
done
mv "$MANIFEST.tmp" "$MANIFEST"
chmod 600 "$MANIFEST"

export NORD_USER NORD_PASS CA_DER OUT MANIFEST
python3 - <<'PY'
import os, plistlib, uuid, hashlib

NS = uuid.UUID('6ba7b810-9dad-11d1-80b4-00c04fd430c8')
def suid(name):  # stable UUID per payload -> regeneration replaces the profile cleanly
    return str(uuid.uuid5(NS, 'com.teazyou.nordvpn.native.' + name)).upper()

# The TOP-LEVEL profile UUID must CHANGE whenever content changes, else macOS sees the
# same identifier+UUID as already-installed and silently ignores the update. Content-
# derived: same pins -> same UUID (no spurious re-approval), new pins -> new version.
with open(os.environ['MANIFEST'], 'rb') as f:
    content_tag = hashlib.sha256(f.read() + os.environ['NORD_USER'].encode()).hexdigest()

def vpn_payload(cc, host):
    name = 'Nord-' + cc.upper()
    return {
        'PayloadType': 'com.apple.vpn.managed',
        'PayloadVersion': 1,
        'PayloadIdentifier': 'com.teazyou.nordvpn.native.vpn.' + cc,
        'PayloadUUID': suid('vpn.' + cc),
        'PayloadDisplayName': name,
        'UserDefinedName': name,
        'VPNType': 'IKEv2',
        'IKEv2': {
            'RemoteAddress': host,
            'RemoteIdentifier': host,
            'AuthenticationMethod': 'None',
            'ExtendedAuthEnabled': 1,
            'AuthName': os.environ['NORD_USER'],
            'AuthPassword': os.environ['NORD_PASS'],
            'DeadPeerDetectionRate': 'Medium',
            # deliberately NO OnDemand keys — see header comment
        },
    }

pins = {}
with open(os.environ['MANIFEST']) as f:
    for line in f:
        cc, host = line.strip().split('=', 1)
        pins[cc] = host

with open(os.environ['CA_DER'], 'rb') as f:
    ca = f.read()

profile = {
    'PayloadType': 'Configuration',
    'PayloadVersion': 1,
    'PayloadIdentifier': 'com.teazyou.nordvpn.native',
    'PayloadUUID': suid('profile.' + content_tag),
    'PayloadDisplayName': 'NordVPN Native IKEv2',
    'PayloadDescription': 'Native IKEv2 NordVPN — 6 countries (BE FR MY SG US VN) + Root CA. No On-Demand; reconnection is event-driven via launchd.',
    'PayloadRemovalDisallowed': False,
    'PayloadContent':
        [vpn_payload(cc, pins[cc]) for cc in ['be', 'fr', 'my', 'sg', 'us', 'vn']] + [{
            'PayloadType': 'com.apple.security.root',
            'PayloadVersion': 1,
            'PayloadIdentifier': 'com.teazyou.nordvpn.native.ca',
            'PayloadUUID': suid('ca'),
            'PayloadDisplayName': 'NordVPN Root CA',
            'PayloadCertificateFileName': 'nord-root.der',
            'PayloadContent': ca,
        }],
}

out = os.environ['OUT']
with open(out, 'wb') as f:
    plistlib.dump(profile, f)
os.chmod(out, 0o600)
print('wrote', out)
PY

rm -f "$CFG_DIR/refresh-needed"
open "$OUT"
echo "Bundle opened — approve it in System Settings (General > Device Management > NordVPN Native IKEv2 > Install)."
