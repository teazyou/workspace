#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"
PATH="/opt/homebrew/bin:$PATH"               # jq (sketchybar's env has no homebrew PATH)

# Repaints BOTH vpn items (vpn_be, vpn_sn) from ONE vpnutil snapshot. Invoked by
# vpn_sn only (it is the sole owner of script=, update_freq and the subscriptions) —
# so an event delivered to one item can never leave the other one stale, and
# both always render from the same snapshot. Deliberately name-agnostic: $NAME is
# NOT read here (only plugins/vpn_click.sh needs it).
#
# Native NordVPN IKEv2 state; see docs/vpn/guide-nordvpn-native.md. COLOUR IS THE ONLY
# CHANNEL, per icon:
#     grey    = not connected (off / failed / or simply not the selected country)
#     red     = connected
#     yellow  = connecting, or this icon owns the in-flight click
#     magenta = selected + a pinned server is dead -> run `nord refresh` (flag file)
# A non-selected country is ALWAYS grey (nothing dials it), so "selected but off" and
# "not selected" both read grey ON PURPOSE — with the VPN down, which one `nord on`
# would dial is not worth marking. There is no orange, and no selection marker: the
# CFG_DIR/country read below only picks which icon may go red/yellow/magenta.
# NEVER call `nord status` from here: its DNS sweep re-touches/clears the
# refresh-needed flag — a side effect a 30s poller must not have.
CFG_DIR="$HOME/.config/nordvpn-native"
VPNUTIL="/opt/homebrew/bin/vpnutil"
CLICK_LOCK="/tmp/nordvpn-native.click"
CLICK_STALE=200                              # keep in sync with plugins/vpn_click.sh

COUNTRY=$(cat "$CFG_DIR/country" 2>/dev/null); COUNTRY=${COUNTRY:-sg}

CONN=""; CONNECTING=""
if [ -x "$VPNUTIL" ]; then
  JSON=$("$VPNUTIL" list 2>/dev/null)
  CONN=$(echo "$JSON" | jq -r 'first(.VPNs[]|select(.status=="Connected").name)//""' 2>/dev/null)
  CONNECTING=$(echo "$JSON" | jq -r 'first(.VPNs[]|select(.status=="Connecting").name)//""' 2>/dev/null)
fi
CONN_CC=$(echo "${CONN#Nord-}"       | tr '[:upper:]' '[:lower:]')
CONNECTING_CC=$(echo "${CONNECTING#Nord-}" | tr '[:upper:]' '[:lower:]')

# Busy: plugins/vpn_click.sh holds the SHARED click lock and named the clicked item
# inside it. A lock older than the steal window is treated as dead (a crashed run —
# sketchybar SIGKILLs any script at 60s, which bypasses the click script's EXIT
# trap), so a stale "…" can never stick forever.
BUSY=""
if [ -d "$CLICK_LOCK" ]; then
  now=$(date +%s)
  age=$(( now - $(stat -f %m "$CLICK_LOCK" 2>/dev/null || echo "$now") ))
  [ "$age" -lt "$CLICK_STALE" ] && BUSY=$(cat "$CLICK_LOCK/owner" 2>/dev/null)
fi

ARGS=()
paint() {  # $1=item name  $2=country code  $3=idle text
  local color label="$3"
  if   [ "$BUSY" = "$1" ];                    then color=$YELLOW; label="…"
  elif [ "$2" != "$COUNTRY" ];                then color=$GREY
  elif [ -f "$CFG_DIR/refresh-needed" ];      then color=$MAGENTA
  elif [ "$2" = "$CONN_CC" ];                 then color=$PINK
  elif [ "$2" = "$CONNECTING_CC" ];           then color=$YELLOW
  else                                             color=$GREY
  fi
  ARGS+=(--set "$1" label="$label" label.color="$color")
}

paint vpn_be be BE
paint vpn_sn sg SN

sketchybar "${ARGS[@]}"
