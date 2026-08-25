#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/theme.sh"   # DIVISION_PAD, ELEMENT_GAP

# Detect a real WIRED ethernet link. On this system (macOS 26-era) "status:
# active" alone is NOT reliable: en0 is Wi-Fi and also reports "status: active"
# whenever Wi-Fi is up, which made the icon show permanently. The discriminator
# is the media line from the SAME `ifconfig <iface>` output: an actual wired
# carrier reports a copper/fiber PHY type (e.g. "media: autoselect (1000baseT
# <full-duplex>)"), while Wi-Fi reports "media: autoselect [<ssid>]" and idle
# adapters never reach status:active at all ("media: none" or "(none)"). This
# avoids the networksetup round-trip entirely and covers USB/thunderbolt
# ethernet adapters, which surface as en* with a baseT/basex/fiber media line.
ETHERNET_STATUS=""

for IFACE in $(ifconfig -l 2>/dev/null); do
  case "$IFACE" in
    en[0-9]*)
      IF_OUT="$(ifconfig "$IFACE" 2>/dev/null)"
      if printf '%s' "$IF_OUT" | grep -q "status: active" &&
         printf '%s' "$IF_OUT" | grep -Eq 'media:.*(baseT|basex|fiber|100G|200G|400G)'; then
        ETHERNET_STATUS="active"
        break
      fi
      ;;
  esac
done

# Show the icon only when connected; otherwise collapse it (icon.drawing=off +
# zero padding) so the connectivity group has no ethernet gap. The item stays
# drawing=on regardless so this poller keeps running.
if [ -n "$ETHERNET_STATUS" ]; then
  sketchybar --set $NAME icon.drawing=on icon=$ETHERNET_CONNECTED icon.color=$PINK \
                         icon.padding_left=$ELEMENT_GAP icon.padding_right=0
else
  sketchybar --set $NAME icon.drawing=off icon.padding_left=0 icon.padding_right=0
fi
