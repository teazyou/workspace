# 03 — Implementation plan: two VPN icons (BE / SN)

Planner output. Implementer: follow in order; nothing here needs a judgement call.
All paths absolute-from-repo-root `/Users/teazyou/workspace`. Repo files are SYMLINKED
into place (`configs/sketchybar` → `~/.config/sketchybar`), so editing the repo file IS
the live change.

## 0. Ground rules for the implementer

- **Do NOT touch `scripts/vpn/*`.** Verified: `nord <cc>` already does switch+enable+
  write-country+clear-flag+trigger `vpn_change`; `nord toggle` already does on/off.
  Zero CLI change is required. Do not "improve" nord.sh while you're in there.
- **No `osascript display notification`** anywhere. **No linting.** **No git**
  (no add/commit/push/stash/checkout).
- Scratch files only under `/Users/teazyou/workspace/sprint/vpn-rework/`.
- After the sketchybar edits: `sketchybar --reload`, then verify with
  `sketchybar --query …` before reporting done.
- Docs + `_index.md` edits (steps 5–7) are **part of this change**, not follow-up.

## 1. Decisions already made (do not re-open)

| Question | Decision |
|---|---|
| Item names | `vpn_be`, `vpn_sn` |
| Visual L→R | wifi, ethernet, **BE, SN** ⇒ add `vpn_sn` FIRST (right items are added right-most first — verified live: wifi x=2184 < ethernet 2206 < vpn 2206, source order was vpn→ethernet→wifi) |
| File layout | ONE `items/vpn.sh` defining both items (single `--add event vpn_change`, no sketchybarrc source-order churn) |
| Text rendering | `icon.drawing=off`; the **label** carries `BE`/`SN`. No `:nord_vpn:` glyph, no `icons.sh` change |
| Label font | `$FONT:Bold:14.0` (matches time/date/cpu/ram/battery primary text) |
| "In use" = | `~/.config/nordvpn-native/country` (the selected target), NOT vpnutil's connected config |
| Polling | BOTH items keep `update_freq=30` + subscribe `system_woke wifi_change vpn_change`; the shared `plugins/vpn.sh` paints **both** items on every invocation from one `vpnutil list` snapshot (name-agnostic — no `$NAME` branch in the painter) |
| Click lock | ONE shared `/tmp/nordvpn-native.click` (unchanged path), now carrying an `owner` file naming the clicked item |
| refresh-needed colour | moves **orange → `$MAGENTA`** (orange is now "selected but not connected", per the user spec). Applies to the SELECTED icon only |
| Connecting | stays a distinct `$YELLOW` state (one `elif`; preserves today's behaviour) |
| `country` ∉ {be,sg} | both icons GREY (falls out of the rule; documented as a known gap) |
| `scripts/vpn/*` | **unchanged** — incl. NOT adding the optional boot-reset `vpn_change` trigger and NOT cc-tagging `refresh-needed` |

Load-bearing facts verified live (don't re-derive):
- `$NAME` is set for `script`, `click_script` and event-delivered runs (`man
  sketchybar-events`, and every existing plugin relies on it).
- An item with `icon.drawing=off` contributes **zero** icon padding to layout
  (`ram`: `icon.drawing=off`, `icon.padding_left=12/right=6`, yet `cpu` ends at
  x=2313 and `ram` starts at x=2313 — no gap). So the new items need no icon padding.
- An item that sets `padding_left=0 padding_right=0` gets 0 inter-item gap
  (cpu/ram/battery/wifi/vpn all do; date/time don't and inherit 8 ⇒ an 8 px gap).
  **Both new items MUST keep `padding_left=0 padding_right=0`.**
- `nord.sh:37-38` accepts `be` and `sg` as country aliases ⇒ the same 2-letter code
  works as the `country`-file value, the vpnutil suffix, and the CLI argument.
- **`SN` is a display label only.** The code/file/config value for Singapore is
  `sg` / `Nord-SG`. Never compare against the literal `"sn"`.
- sketchybar SIGKILLs any script after 60 s (`man sketchybar-events`) — the EXIT trap
  will NOT run then. Mitigated in step 3 by making the painter ignore a lock older
  than the 200 s steal window (so a "…" can never stick forever).

---

## 2. `configs/sketchybar/items/vpn.sh` — full rewrite (same filename)

Replace the entire file with:

```bash
#!/bin/bash

# VPN — RIGHT end of the connectivity division. TWO text items, "BE" (Belgium) and
# "SN" (Singapore) = the two most-used exits. Visual order is BE then SN, so vpn_sn
# is added FIRST (right-side items are added right-most first, like the rest of the
# bar). No glyph: the label IS the content (icon.drawing=off, same shape as the time
# item) — an icon.drawing=off item contributes no icon padding to the layout.
#
# plugins/vpn.sh repaints BOTH items from one vpnutil snapshot on every run:
#   grey    = not the selected target country (~/.config/nordvpn-native/country)
#   red     = selected AND connected
#   yellow  = selected AND connecting  (also the in-flight "…" busy look)
#   orange  = selected AND not connected (off / failed / reconnecting)
#   magenta = selected AND a pinned server is dead -> run `nord refresh`
#
# Click = plugins/vpn_click.sh: clicking the GREY icon switches to that country and
# turns it on (`nord be` / `nord sg`); clicking the SELECTED icon toggles it on/off
# (`nord toggle`). Instant busy feedback (yellow "…") on the clicked icon + ONE
# SHARED click lock (/tmp/nordvpn-native.click) for both icons, whose `owner` file
# says which icon to keep busy. Paddings from theme.sh. The custom `vpn_change`
# event is triggered by nord.sh/nord-connect.sh after every state change.
vpn_base=(
  icon.drawing=off
  label.font="$FONT:Bold:14.0"
  label.color=$GREY
  background.drawing=off
  padding_left=0
  padding_right=0
  click_script="$PLUGIN_DIR/vpn_click.sh"
  script="$PLUGIN_DIR/vpn.sh"
  update_freq=30
)

# Singapore — added first => right-most element of the whole connectivity division,
# so its label carries the division's right inner pad (DIVISION_PAD).
vpn_sn=(
  "${vpn_base[@]}"
  label="SN"
  label.padding_left=$ELEMENT_GAP
  label.padding_right=$DIVISION_PAD
)

# Belgium — inner element: a plain element gap on both sides (its left gap is the
# one that used to sit on the old single item's icon.padding_left).
vpn_be=(
  "${vpn_base[@]}"
  label="BE"
  label.padding_left=$ELEMENT_GAP
  label.padding_right=$ELEMENT_GAP
)

sketchybar --add event vpn_change \
           --add item vpn_sn right \
           --set vpn_sn "${vpn_sn[@]}" \
           --subscribe vpn_sn system_woke wifi_change vpn_change \
           --add item vpn_be right \
           --set vpn_be "${vpn_be[@]}" \
           --subscribe vpn_be system_woke wifi_change vpn_change
```

Notes: `$GREY`, `$FONT`, `$ELEMENT_GAP`, `$DIVISION_PAD`, `$PLUGIN_DIR` all come from
sketchybarrc's sourced env (items are sourced in the same shell) — same as today.

---

## 3. `configs/sketchybar/plugins/vpn.sh` — full rewrite (same filename)

Replace the entire file with:

```bash
#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"
PATH="/opt/homebrew/bin:$PATH"               # jq (sketchybar's env has no homebrew PATH)

# Repaints BOTH vpn items (vpn_be, vpn_sn) from ONE vpnutil snapshot, whichever of
# them invoked this script (30s tick, or vpn_change / wifi_change / system_woke) —
# so an event delivered to only one item can never leave the other one stale, and
# both always render from the same snapshot. Deliberately name-agnostic: $NAME is
# NOT read here (only plugins/vpn_click.sh needs it).
#
# Native NordVPN IKEv2 state; see docs/vpn/guide-nordvpn-native.md.
#   grey    = not the selected target country (CFG_DIR/country)
#   red     = selected + connected
#   yellow  = selected + connecting, or this icon owns the in-flight click
#   orange  = selected + not connected (off / failed / reconnecting)
#   magenta = selected + a pinned server is dead -> run `nord refresh` (flag file)
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
  else                                             color=$ORANGE
  fi
  ARGS+=(--set "$1" label="$label" label.color="$color")
}

paint vpn_be be BE
paint vpn_sn sg SN

sketchybar "${ARGS[@]}"
```

Removed on purpose: the `theme.sh` source and the dynamic icon/label padding branch —
the labels are now always drawn, so the padding owner never shifts (that branch only
existed because the old single item toggled `label.drawing`).

---

## 4. `configs/sketchybar/plugins/vpn_click.sh` — full rewrite (same filename)

Replace the entire file with:

```bash
#!/bin/bash

# Click handler SHARED by both vpn items (vpn_be, vpn_sn); $NAME says which one.
# 1. DECIDE: clicking the icon of the currently SELECTED country
#    (~/.config/nordvpn-native/country) toggles it on/off (`nord toggle`); clicking
#    the other (grey) icon switches to that country and turns it on (`nord <cc>` —
#    which writes country + enabled and clears refresh-needed itself).
# 2. INSTANT feedback: paints the clicked icon busy (yellow "…") before acting.
# 3. CLICK LOCK: ONE lock shared by BOTH icons (/tmp/nordvpn-native.click) — a second
#    click on EITHER icon while an action is in flight is ignored (mkdir-atomic lock
#    dir; stolen if older than 200s = a crashed run — nord.sh's own timeouts bound a
#    healthy run well under that). The clicked item's name goes into
#    $CLICK_LOCK/owner so plugins/vpn.sh keeps the busy look on the RIGHT icon while
#    the other one keeps rendering its real state.
#    Keeping the lock SHARED is load-bearing for the single-VPN-slot rule: with
#    per-icon locks two nord.sh runs would race, and the loser would just block ~60s
#    on nord.sh's own /tmp/nordvpn-native.lock and silently do nothing.
source "$HOME/.config/sketchybar/colors.sh"

CFG_DIR="$HOME/.config/nordvpn-native"
CLICK_LOCK="/tmp/nordvpn-native.click"
CLICK_STALE=200                     # keep in sync with plugins/vpn.sh
NORD="$HOME/workspace/scripts/vpn/nord.sh"

# NOTE: "SN" is the display label only — Singapore's code everywhere else is `sg`.
case "${NAME:-}" in
  vpn_be) MY_CC=be ;;
  vpn_sn) MY_CC=sg ;;
  *) exit 0 ;;                      # not one of ours (e.g. run by hand without NAME)
esac

COUNTRY=$(cat "$CFG_DIR/country" 2>/dev/null); COUNTRY=${COUNTRY:-sg}
if [ "$MY_CC" = "$COUNTRY" ]; then ACTION=toggle; else ACTION="$MY_CC"; fi

release() { rm -f "$CLICK_LOCK/owner" 2>/dev/null; rmdir "$CLICK_LOCK" 2>/dev/null; }

now=$(date +%s)
if ! mkdir "$CLICK_LOCK" 2>/dev/null; then
  age=$(( now - $(stat -f %m "$CLICK_LOCK" 2>/dev/null || echo "$now") ))
  [ "$age" -lt "$CLICK_STALE" ] && exit 0   # action in flight — ignore the click
  release                                   # stale lock from a crashed run — steal it
  mkdir "$CLICK_LOCK" 2>/dev/null || exit 0
fi
echo "$NAME" > "$CLICK_LOCK/owner"
trap 'release; sketchybar --trigger vpn_change 2>/dev/null' EXIT

sketchybar --set "$NAME" label="…" label.color="$YELLOW"

bash "$NORD" "$ACTION" >/dev/null 2>&1

# release + settle BEFORE the final repaint: nord.sh fires its own vpn_change on
# completion (while the lock is still held -> painted busy); triggering again too
# fast gets coalesced with it and the stale busy look sticks until the next tick.
release
sleep 1
```

Three behavioural deltas vs today, all deliberate:
1. `--set "$NAME"` instead of the hardcoded `--set vpn` (today's file hardcodes it —
   that would paint a non-existent item after this change).
2. `nord toggle` becomes `nord "$ACTION"` where ACTION ∈ {`toggle`, `be`, `sg`}.
3. `rmdir` alone → `release()` (`rm -f owner` then `rmdir`) at all three cleanup
   sites, because the lock dir is no longer empty. **Deliberately not `rm -rf`.**

---

## 5. `configs/sketchybar/sketchybarrc` — 2 small edits

**Edit A — lines 141-144 (comment only).** Replace:

```
# Network connectivity group (L->R: wifi, ethernet, vpn). Right items are added
# right-most first, so source vpn (rightmost), then ethernet, then wifi (leftmost)
# — this puts ethernet immediately to the right of wifi. Leftmost division of the
# right-side cluster — no spacer after it.
```
with:
```
# Network connectivity group (L->R: wifi, ethernet, vpn_be, vpn_sn). Right items are
# added right-most first, so source vpn.sh first (it adds vpn_sn then vpn_be
# internally — see its header), then ethernet, then wifi (leftmost) — this puts
# ethernet immediately to the right of wifi. Leftmost division of the right-side
# cluster — no spacer after it.
```

Lines 145-147 (`source "$ITEM_DIR/vpn.sh"` / `ethernet.sh` / `wifi.sh`) stay **byte-identical**.

**Edit B — lines 153-154.** Replace:

```
# Bracket for network connectivity group (ethernet + wifi + vpn)
sketchybar --add bracket connectivity vpn wifi ethernet \
```
with:
```
# Bracket for network connectivity group (wifi + ethernet + vpn_be + vpn_sn)
sketchybar --add bracket connectivity vpn_be vpn_sn wifi ethernet \
```
(Member-list order is cosmetic — verified: today's list says `vpn wifi ethernet`
while the screen shows wifi, ethernet, vpn. Only the NAMES matter.)

---

## 6. `configs/aerospace/performance-mode.sh` — 4 edits

This file runs under `set -euo pipefail` and hardcodes the item name, so a missed
edit here **kills the startup toggle**. Do not skip.

- **Line 8** — `#   - The resources (cpu, ram, battery) and connectivity (vpn, wifi, ethernet)`
  → `#   - The resources (cpu, ram, battery) and connectivity (vpn_be, vpn_sn, wifi,`
  (and continue the existing wrap on line 9 with `#     ethernet) divisions are hidden.`)
- **Line 17** — `(battery 60, vpn 30, ethernet 30, wifi 30, cpu 5, ram 5)`
  → `(battery 60, vpn_be 30, vpn_sn 30, ethernet 30, wifi 30, cpu 5, ram 5)`
- **Line 54** (OFF-restore branch) — replace
  `             --set vpn      drawing=on update_freq=30 \`
  with the two lines
  ```
             --set vpn_be   drawing=on update_freq=30 \
             --set vpn_sn   drawing=on update_freq=30 \
  ```
- **Line 72** (ON-minimal branch) — replace
  `             --set vpn      drawing=off update_freq=0 \`
  with the two lines
  ```
             --set vpn_be   drawing=off update_freq=0 \
             --set vpn_sn   drawing=off update_freq=0 \
  ```

Nothing else in this file changes: the `--set connectivity background.*` lines target
the BRACKET (name unchanged, members irrelevant). Verified: `configs/aerospace/
aerospace.toml` and `configs/aerospace/lib-paths.sh` contain **zero** `vpn` references
— no edit there.

---

## 7. `docs/vpn/guide-nordvpn-native.md` — authoritative guide (4 edits)

- **Line 19, "Bar item" table row.** Replace the whole 3rd cell with:
  > two text items — **BE** (Belgium) and **SN** (Singapore, code `sg`). Per icon:
  > **grey** = not the selected country, **red** = selected + connected, **yellow** =
  > selected + connecting, **orange** = selected + not connected (off/failed),
  > **magenta = refresh needed**. Click = `vpn_click.sh`: grey icon → `nord <cc>`
  > (switch + on), selected icon → `nord toggle`; it paints that icon busy (yellow
  > "…") instantly and ignores re-clicks on EITHER icon until the action ends (200 s
  > stale-steal). ONE shared click lock `/tmp/nordvpn-native.click`, whose `owner`
  > file names the clicked item so `plugins/vpn.sh` keeps the busy look on the right
  > icon while the other keeps rendering its real state.
- **Line 23** (`~/.config/nordvpn-native/` contents) — `refresh-needed` (flag file →
  bar turns orange) → **`refresh-needed` (flag file → the selected country's bar icon
  turns magenta)**.
- **Line 65, "Stale pins / dead server"** — "the bar's VPN icon turns **orange**" →
  "the selected country's bar icon turns **magenta**".
- **Line 78, "Verified test matrix"** — "bar states red/orange/grey + CC label" →
  "bar states red/orange/grey + CC label (**superseded 2026-07-30 by the two-icon
  BE/SN bar — see the Bar item row; re-verify per that table**)".
- **`## Caveats` (line 69) — append two bullets:**
  - `- The bar shows only **BE** and **SN**. The CLI still supports all 6 countries; if the selected country is fr/my/us/vn (or someone starts a config by hand in System Settings), **both** icons render grey and the real exit is not represented on the bar. Known 2-icon limitation, not a bug.`
  - `- Because every reboot resets the target to Singapore (design decision 5), **SN is always the selected/active icon right after a reboot**, whatever was selected before.`

---

## 8. `_index.md` — 2 bullet edits

- **Line 39** (`configs/sketchybar/items/*.sh`): `**8 SOURCED items** are live (spaces,
  calendar, battery, ram, cpu, vpn, ethernet, wifi)` → `**9 SOURCED items** are live
  (spaces, calendar, battery, ram, cpu, vpn_be, vpn_sn, ethernet, wifi)`; and replace
  the vpn clause `vpn = native-IKEv2 NordVPN state (…)` with:
  > vpn_be/vpn_sn = two text icons (**BE**/**SN**) for the two most-used native-IKEv2
  > NordVPN exits — grey = not the selected country (`~/.config/nordvpn-native/country`),
  > red = selected+connected, yellow = selected+connecting, orange = selected+not
  > connected, magenta = `nord refresh` needed; click grey = `nord <cc>` (switch+on),
  > click selected = `nord toggle`, with instant busy "…" on the clicked icon and one
  > shared click lock; custom `vpn_change` event triggered by the `scripts/vpn/` stack
- **Line 40** (`configs/sketchybar/plugins/*.sh`): `the per-item updaters (ethernet,
  ram, cpu, vpn, battery)` → `the per-item updaters (ethernet, ram, cpu, battery) and
  `vpn.sh` (paints BOTH vpn items from one vpnutil snapshot)`; and
  `` `vpn_click.sh` (vpn click handler: busy feedback + click lock → `nord toggle`) ``
  → `` `vpn_click.sh` (shared handler for both vpn icons: `$NAME` → cc, busy feedback +
  one shared click lock with an `owner` file → `nord <cc>` on the grey icon,
  `nord toggle` on the selected one) ``.

---

## 9. `docs/window-manager/guide-window-manager.md` — 5 line edits

Same project rule ("update the affected guide"); this file documents the exact item
names and freqs, so it goes stale without these.

- **Line 109** — `connectivity (vpn, wifi, ethernet) divisions` → `connectivity
  (vpn_be, vpn_sn, wifi, ethernet) divisions`
- **Line 111** — `(battery 60, vpn 30, ethernet 30, wifi 30, cpu 5, ram 5)` →
  `(battery 60, vpn_be 30, vpn_sn 30, ethernet 30, wifi 30, cpu 5, ram 5)`
- **Line 151** — item list `…, battery, vpn, wifi, ethernet` → `…, battery, vpn_be +
  vpn_sn (both from items/vpn.sh), wifi, ethernet`
- **Line 187** — `Active items: … vpn.sh, wifi.sh, ethernet.sh (8 live; …)` →
  `Active items: … vpn.sh (defines TWO items: vpn_be + vpn_sn), wifi.sh, ethernet.sh
  (9 live items from 8 files; …)`
- **Line 190** — `vpn = NordVPN app glyph tinted by connection` → `vpn_be/vpn_sn = two
  text icons "BE"/"SN"; grey = not the selected country, red = selected+connected,
  yellow = selected+connecting, orange = selected+not connected, magenta = `nord
  refresh` needed`
- **Line 191** — `battery 60, vpn 30, ethernet 30, wifi 30, cpu 5, ram 5` →
  `battery 60, vpn_be 30, vpn_sn 30, ethernet 30, wifi 30, cpu 5, ram 5`
- Line 181 (icons.sh categories) — **no change** (`icons.sh` itself is untouched; its
  `VPN_CONNECTED`/`VPN_DISCONNECTED` exports were already unused and stay unused).

Also **line 4 of `configs/sketchybar/plugins/wifi_click.sh`** (comment only, no logic):
`and vpn, which also subscribes to wifi_change` → `and vpn_be/vpn_sn, which also
subscribe to wifi_change`. Its code (`sketchybar --trigger wifi_change`) is
name-agnostic and stays untouched.

---

## 10. Apply + smoke order

1. Steps 2 → 3 → 4 → 5 → 6 (code), then 7 → 8 → 9 (docs).
2. `sketchybar --reload`
3. `sketchybar --query vpn_be` / `vpn_sn` / `connectivity` — see checklist.
4. Hand off to QA with `04-acceptance.md`.

---

# A. Per-icon state → colour truth table

Computed once per `plugins/vpn.sh` run, then applied to each icon:

- `COUNTRY` = `cat ~/.config/nordvpn-native/country` (fallback `sg`)
- `CONN_CC` = `vpnutil list` → first `Connected` name, minus `Nord-`, lowercased, else `""`
- `CONNECTING_CC` = same for `Connecting`, else `""`
- `REFRESH` = `~/.config/nordvpn-native/refresh-needed` exists
- `BUSY` = contents of `/tmp/nordvpn-native.click/owner`, but only if the lock dir
  exists **and** is younger than 200 s; else `""`

For icon `N` ∈ {`vpn_be`, `vpn_sn`} with code `C` ∈ {`be`, `sg`} and text `T` ∈ {`BE`, `SN`} —
**first matching row wins**:

| # | Condition | `label` | `label.color` | Meaning |
|---|---|---|---|---|
| 1 | `BUSY == N` | `…` | `$YELLOW` | this icon's click is in flight |
| 2 | `C != COUNTRY` | `T` | `$GREY` | not the selected country (unconditional — no vpnutil check) |
| 3 | `REFRESH` set | `T` | `$MAGENTA` | selected; a pinned server is dead → `nord refresh` |
| 4 | `C == CONN_CC` | `T` | `$PINK` (the red) | selected **and** connected |
| 5 | `C == CONNECTING_CC` | `T` | `$YELLOW` | selected, tunnel coming up |
| 6 | else | `T` | `$ORANGE` | selected **and not** connected (off / failed / waiting) |

Rows 3-6 all imply `C == COUNTRY`. Precedence mirrors today's (`refresh` overrode
connected; busy overrode everything). Nothing ever changes `label.drawing`,
`icon.*`, or any padding at runtime.

Worked examples (live state at planning time was `country=be`, `Nord-BE=Connected`):
| Situation | BE icon | SN icon |
|---|---|---|
| country=be, BE connected | red `BE` | grey `SN` |
| country=be, `nord off` | orange `BE` | grey `SN` |
| country=sg, SG connecting | grey `BE` | yellow `SN` |
| country=sg, connected, dead pin flag | grey `BE` | magenta `SN` |
| country=fr (via terminal) | grey `BE` | grey `SN` |
| click on SN while country=be | orange `BE` (BE is being torn down) | yellow `…` |

# B. Click decision tree (`plugins/vpn_click.sh`)

```
$NAME ──> vpn_be : MY_CC=be
     ──> vpn_sn : MY_CC=sg
     ──> anything else : exit 0

COUNTRY = cat ~/.config/nordvpn-native/country   (fallback sg)

MY_CC == COUNTRY ?
  ├─ yes  (this is the SELECTED / non-grey icon) ──> nord toggle
  │        nord.sh: anything Connected/Connecting -> `nord off`, else -> `nord on`
  │        (`nord on` reconnects COUNTRY == MY_CC)
  └─ no   (this is a GREY icon)                  ──> nord <MY_CC>   (be | sg)
           nord.sh switch branch: enabled=1 -> stop_all -> start Nord-<CC>
           -> write country=<CC> + clear refresh-needed -> trigger vpn_change
```
Guarded by the lock: if the shared lock exists and is <200 s old, the click exits 0
immediately (no paint, no nord call). If it is ≥200 s old it is stolen first.

Note (accepted, documented): if a *third* country is connected by hand, clicking the
selected icon takes the `toggle` branch and `nord toggle` sees "something is
connected" → runs `nord off`, stopping that third country. Consequence of `toggle`
being global, not per-cc; only reachable via the known 2-icon gap.

# C. Concurrency: busy "…" and the click lock with two icons

- **One lock, both icons:** `/tmp/nordvpn-native.click` (mkdir-atomic), path unchanged.
  Per-icon locks are forbidden — two concurrent `nord.sh` runs would contend for
  macOS's single personal-VPN slot; the loser would block ~60 s on nord.sh's own
  `/tmp/nordvpn-native.lock` and silently do nothing, which is worse than an instant
  drop. **Only one VPN action can ever be in flight.**
- **Ownership:** right after the winning `mkdir`, the click script writes its `$NAME`
  to `$CLICK_LOCK/owner`. That is the ONLY new piece of machinery in this change.
- **Who paints what:**
  - the click script paints only `$NAME` (instant `…` + yellow) once, at click time;
  - `plugins/vpn.sh` (30 s tick / `vpn_change` / `wifi_change` / `system_woke`,
    invoked by either item) repaints **both** icons: the owner gets `…`+yellow, the
    other one gets its normally-derived colour from the same snapshot — so during a
    BE→SN switch you see `BE` go orange while `SN` shows `…`.
- **Second click, either icon, while busy:** `mkdir` fails, lock age <200 s → `exit 0`.
  Silently dropped; no paint, no nord call. Unchanged from today.
- **Stale lock (crashed / SIGKILLed run):** two independent recoveries, both keyed to
  the same 200 s window —
  1. *click path:* age ≥200 s → `release()` then re-`mkdir` (steal);
  2. *paint path:* age ≥200 s → `BUSY` is treated as empty, so both icons return to
     their real colours even if nobody clicks again. (New; closes the "… sticks
     forever" hole that a 60 s sketchybar SIGKILL of the click script would open,
     since SIGKILL bypasses the EXIT trap.)
- **Release is `rm -f "$CLICK_LOCK/owner"` then `rmdir "$CLICK_LOCK"`** at all three
  sites (steal, EXIT trap, pre-settle release). Never `rm -rf`. `rmdir` still refuses
  to remove a non-empty dir, which is the safety property we keep.
- **Timing headroom (from nord.sh's own constants):** `nord <cc>` typical 8-15 s,
  worst realistic <60 s, pathological ~180 s; `nord toggle`→off typical 2-5 s. The
  200 s window is unchanged from today and covers these. Not widened by this change.
- **vs the launchd watcher:** unchanged. `nord-connect.sh` takes
  `/tmp/nordvpn-native.lock` non-blocking and exits instantly if the CLI holds it; the
  click lock is click-path-only and the watcher never touches it. A watcher-initiated
  reconnect therefore shows as yellow `Connecting` (row 5), not as `…`.

# D. Explicitly NOT done (and why)

- No change to `scripts/vpn/nord.sh`, `nord-connect.sh`, `nord-gen-bundle.sh`,
  `zsh/alias/vpn.zsh`, `configs/nordvpn/*.plist` — the CLI contract already covers
  both click actions.
- Not adding a `vpn_change` trigger after the boot-reset write in `nord-connect.sh`
  (self-heals within 30 s via the poll).
- Not cc-tagging `refresh-needed` (stays a global boolean; shown on the selected icon).
- No change to `icons.sh`, `theme.sh`, `colors.sh` (only reads existing tokens),
  `aerospace.toml`, `lib-paths.sh`.
- No new lock, no new state file, no daemon, no notification.
