#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/theme.sh"   # DIVISION_PAD, ELEMENT_GAP

# Show the icon only when a REAL wired ethernet link has carrier.
#
# Previous bug: matching "status: active" + a copper/fiber "media:" line on ANY
# en* interface was not enough. Wi-Fi en0 reports a bare "media: autoselect"
# (no baseT words), but an always-up USB CDC-NCM tether interface (en8 on this
# machine; e.g. phone/carrier tethering) reports "media: autoselect
# (100baseTX <full-duplex>)" + "status: active" with only a 169.254 link-local
# address. That tripped the old media-only check and lit the icon on plain
# Wi-Fi with no cable plugged.
#
# Real wired ports are exactly the hardware ports macOS lists via
# networksetup -listallhardwareports ("Hardware Port: X" / "Device: enY").
# A plugged USB-C / Thunderbolt RJ45 adapter always appears as its own entry
# there (e.g. "Ethernet Adapter", "USB 10/100/1000 LAN", "Thunderbolt 1"),
# so adapters keep working. Wi-Fi ("Wi-Fi" port) and tether/VM interfaces
# (no hardware port at all) can never match, and the Thunderbolt Bridge
# (bridge0) is dropped because it is not an en* device. Then within the
# device's own `ifconfig` output require "status: active" (carrier up) on a
# copper/fiber PHY media line (e.g. "1000baseT", "2500baseX", "10000baseSR");
# idle adapters are inactive and never qualify. Bash 3.2-safe.
WIRED_DEV=""

PORT_NAME=""
while IFS= read -r LINE; do
  case "$LINE" in
    "Hardware Port: "*)
      PORT_NAME="${LINE#Hardware Port: }"
      ;;
    "Device: en"*)
      case "$PORT_NAME" in
        # Built-in NICs, USB-C/TB RJ45 adapters, USB LAN dongles.
        *[Ee]thernet*|*[Tt]hunderbolt*|*[Ll][Aa][Nn]*|*[Gg]igabit*)
          DEV="${LINE#Device: }"
          IF_OUT="$(ifconfig "$DEV" 2>/dev/null)"
          if printf '%s' "$IF_OUT" | grep -q "status: active" &&
             printf '%s' "$IF_OUT" | grep -Eq 'media:.*base(TX|T|X|SR|LR|CR|SX|LX)'; then
            WIRED_DEV="$DEV"
            break
          fi
          ;;
      esac
      ;;
  esac
done < <(networksetup -listallhardwareports 2>/dev/null)

# Show the icon only when connected; otherwise collapse it (icon.drawing=off +
# zero padding) so the connectivity group has no ethernet gap. The item stays
# drawing=on regardless so this poller keeps running.
if [ -n "$WIRED_DEV" ]; then
  sketchybar --set $NAME icon.drawing=on icon=$ETHERNET_CONNECTED icon.color=$PINK \
                         icon.padding_left=$ELEMENT_GAP icon.padding_right=0
else
  sketchybar --set $NAME icon.drawing=off icon.padding_left=0 icon.padding_right=0
fi
