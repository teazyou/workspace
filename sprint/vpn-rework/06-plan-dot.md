# 06 — Implementation plan: selection DOT replaces the orange colour

Planner output, round 2. Follows `03-plan.md` (implemented + QA-passed in `05-qa-round1.md`).
Implementer: follow in order; nothing here needs a judgement call. Paths absolute-from
`/Users/teazyou/workspace`. `configs/sketchybar` → `~/.config/sketchybar` is a SYMLINK, so
editing the repo file IS the live change.

## 0. Ground rules (unchanged from round 1)

- **No git** (no add/commit/push/stash/checkout). **No linting.** **No notifications.**
- **No VPN mutation.** Never run `nord <cc>` / `nord on|off|toggle` / `vpnutil start|stop`.
  Colour branches are exercised with stubs (stub `CFG_DIR` + stub `vpnutil`), as round 1 did.
- **Do NOT touch `scripts/vpn/*`**, `zsh/alias/vpn.zsh`, `configs/nordvpn/*`, `colors.sh`,
  `icons.sh`, `sketchybarrc`, `performance-mode.sh`, `wifi_click.sh`, `aerospace.toml`,
  `lib-paths.sh` — this change adds **no new item**, so no name-enumeration site moves.
- Scratch only under `/Users/teazyou/workspace/sprint/vpn-rework/`.
- After the edits: `sketchybar --reload`, then verify with `--query` before reporting done.
- Docs + `_index.md` edits (steps 5-7) are **part of this change**, not follow-up.

> **HEAD note (read before checking guardrails):** the round-1 work is **already committed** —
> the hourly checkpoint LaunchAgent swept it into `db1f3df checkpoint` (`git diff --stat
> 8e82bc7..db1f3df` = exactly the 9 round-1 files + the sprint docs). Working tree is clean
> except the `configs/dot-claude` submodule pointer. So the guardrail is **"the implementer
> ran no git command"**, not "HEAD == 8e82bc7". See checklist §F.

---

## 1. Spec → semantics (the ONE interpretation decision, stated openly)

User words: *"Instead of differenciating the one connected by using orange color, we will use
a small dot under the one selected (be or sn), the dot is same color as the icon, the 2 icon
or grey when disconnected and normal color when connected, the dot under appear on the one
active and match its color."*

Two channels, decoupled:

| channel | carries | rendering |
|---|---|---|
| **colour** (label + dot) | the **tunnel** state | grey = not connected · red (`$PINK`) = connected · yellow = connecting / click in flight · magenta = `nord refresh` needed |
| **dot** (under the label) | which country is **selected** (`~/.config/nordvpn-native/country`) | exactly one at a time, **always the same colour as the label above it** |

**Chosen reading (R2, per-icon truth):** an icon is red only if **that** country's tunnel is up;
the other icon stays grey. Rationale: "the 2 icons are grey when disconnected" is literally
satisfied (selected → grey+dot, other → grey), while painting the NON-selected country red
whenever the VPN is up would state a falsehood ("SN is your exit" when BE is). It is also the
smallest diff: one `$ORANGE` → `$GREY` swap + the dot.

**Rejected reading (R1, global colour):** both icons share one colour (red whenever the
selected tunnel is up). If the user actually meant R1, the flip is **one line** in
`plugins/vpn.sh`: replace `elif [ "$2" != "$COUNTRY" ]; then color=$GREY` with a pre-computed
global `STATE_COLOR` applied to both icons. Note this in the hand-off message so the user can
ask for it in one word.

Everything else keeps working unchanged: busy `…`, click decision tree (dotted icon →
`nord toggle`; dot-less icon → `nord <cc>` = switch AND on), the shared `/tmp` click lock +
`owner` file, the 200 s stale-steal, `vpn_change`, performance mode.

---

## 2. Dot mechanism — CHOSEN: re-purpose the item's own ICON slot

SketchyBar has no sub-label slot. All three candidate mechanisms were tested **live on this
machine** (2560x1440, 1:1 pixels — `UI Looks like 2560 x 1440`), measuring with
`sketchybar --query` + `screencapture` + a pure-stdlib PNG pixel probe. Evidence:

| # | mechanism | measured result | verdict |
|---|---|---|---|
| a | companion zero-width item + `●` label | needs the neighbour's width for centring **anyway**; a `width=0` item's background has zero width (nothing drawn) so a real width is needed ⇒ division grows 4-8 px; +1-2 items ⇒ 5 new enumeration sites (bracket, performance-mode ON+OFF, docs) | **rejected** (blast radius) |
| b | `label.background` / item `background` as a tiny pill | `label.background.padding_left/right` has **NO effect on width**: measured 28-30 px (= the full label rect) for padding ∈ {0, +7, −7, −14}. Item-level `background.padding_*` only **translates** the fill (width constant, x shifts by −padding_left: 0→x2195, 7→x2188, 13→x2182, −7→x2202). ⇒ a background can only ever be a full-width **underline**, never a dot | **rejected** (spec says *dot*) |
| c | the item's ICON slot, pulled back UNDER the label with a negative `icon.padding_right` | dot renders as a real round glyph, **5 px ink**, pixel-centred, and the layout is **byte-identical** to today (see §2.2) | **CHOSEN** |

### 2.1 How (c) works

The icon normally sits BESIDE the label. Give it the dot glyph, drop it below the text with
`icon.y_offset`, and pull it back on top of the label with a negative `icon.padding_right`
chosen so its net layout contribution is **exactly zero**:

```
icon.padding_left + <glyph advance> + icon.padding_right == 0
        12         +        6        +       (-18)        == 0
```

Presence is a **COLOUR, never `icon.drawing`**: `icon.color=$TRANSPARENT` hides the dot with
zero layout effect (`icon.drawing=off` would remove the glyph's advance and shift the label).

### 2.2 Measured geometry (reproduce these; they are the acceptance numbers)

Solved empirically: with `icon.padding_left=0 icon.padding_right=0` the item grew 30 → 36 px
⇒ the `●` glyph advance at `:Bold:12.0` is **6 px**; hence `pad_left=(30−6)/2=12`,
`pad_right=−(12+6)=−18`.

| quantity | value | how measured |
|---|---|---|
| `vpn_be` item width | **30 px** — unchanged with the dot on, off, or `icon.drawing=off` | `--query … .bounding_rects."display-1".size[0]` |
| `vpn_sn` item width | **31 px** — unchanged | same |
| `connectivity` bracket width | **85 px** (wifi icon 22 px) / **83 px** (wifi 20 px — the RSSI glyph varies) — unchanged by the dot | same |
| label ink, relative to element left edge | **+7 … +23 px**, rows **15-24** — identical before/after (pre-change capture: abs 2201-2217 @ item 2194; with the dot: 2203-2219 @ item 2196) | pixel probe |
| dot ink | **5 px wide**, rows **28-32**, centred (`element_left+13 … +17`, centre = element centre) | pixel probe |
| division pill | rows **5-34** ⇒ dot sits 3 px under the label ink, 2 px above the pill's bottom edge | pixel probe |
| `icon.color=$TRANSPARENT` | **zero** non-background pixels in rows 25-34 ⇒ dot fully hidden | pixel probe |
| how `--query` reports it | `.icon.color` = **`"0x0"`** (not `0x00000000`) | `--query` |

Font sizes also measured: `:Bold:8.0` → advance 4 / ink 3 px (too faint), `:Bold:10.0` → 5 / 4,
`:Bold:12.0` → **6 / 5** (chosen). At `y_offset=-10` the ink sat at rows 29-33 = 1 px off the
pill edge; **-9** centres it in the 25-34 gap.

**Residual visual risk (honest):** I cannot see the screen. Both target states were rendered
live and read back as images: grey `BE`+grey dot / grey `SN`, and red `BE`+red dot / grey `SN`
— both correct. Remaining risks: (1) `vpn_sn` is 31 px wide so its dot is **0.5 px left** of
that element's centre (invisible; same constant used for both by design); (2) on a HiDPI
(Retina) external display the numbers are the same in POINTS, so it scales — but the ink would
be re-rasterised, untested; (3) taste — 5 px may read as "big" or "small" to the user; the size
is one token (`SEL_DOT_SIZE`).

---

## 3. Edits, in dependency order

### 3.1 `configs/sketchybar/theme.sh` — APPEND a new token block (end of file)

theme.sh is the documented single source of truth for division geometry, so all dot geometry
lives here (no magic numbers in items/*.sh). The glyph is kept **next to** its metrics
deliberately: `SEL_DOT_ADVANCE` is only valid for that glyph at that size, so splitting them
(glyph → `icons.sh`) would invite silent drift. Prefix `SEL_DOT_` and not `DOT_` on purpose:
`plugins/aerospace.sh` already uses local `DOT_GLYPH`/`DOT_FONT`/`DOT_COLOR` vars for the
empty-workspace marker (it does not source theme.sh today — keep it impossible to collide).

```bash

# ── Selection dot ────────────────────────────────────────────────────────────
# The "this is the selected one" marker: a small round glyph drawn UNDER an
# element's label (only user today: the active VPN country — items/vpn.sh +
# plugins/vpn.sh). SketchyBar has no sub-label slot, so the element's own ICON
# slot is re-purposed. The icon normally sits BESIDE the label, so it is pulled
# back UNDER it with a NEGATIVE icon.padding_right, chosen so that
#     icon.padding_left + SEL_DOT_ADVANCE + icon.padding_right == 0
# i.e. the dot costs ZERO layout width — the element and its whole division
# measure the same whether the dot shows or not. Presence is therefore a
# COLOUR, never `icon.drawing`: no dot = icon.color=$TRANSPARENT (drawing=off
# would remove the glyph's advance and shift the label).
# Verified live (2560x1440 @1:1, --query + screencapture pixel probe): at
# :Bold:12.0 the glyph advances 6 px and inks 5 px; on a 30 px element the ink
# lands centred (element_left+13..+17) at rows 28-32 — 3 px under the label ink
# (rows 15-24) and 2 px above the division's bottom edge (row 34).
export SEL_DOT_GLYPH="●"      # U+25CF BLACK CIRCLE (present in JetBrainsMono Nerd Font)
export SEL_DOT_SIZE=12.0      # font size — calibrated PAIR with SEL_DOT_ADVANCE, change both
export SEL_DOT_ADVANCE=6      # px the glyph advances at SEL_DOT_SIZE (measured; centring needs it)
export SEL_DOT_Y_OFFSET=-9    # NEGATIVE = DOWN (verified): under the label, inside the pill
```

Nothing else in theme.sh changes.

### 3.2 `configs/sketchybar/items/vpn.sh` — header rewrite + dot block in `vpn_base`

Replace the file header (lines 3-21) and `vpn_base` (lines 22-32) with the text below. The
`vpn_sn` / `vpn_be` arrays and the final `sketchybar --add …` call stay **byte-identical**.

```bash
# VPN — RIGHT end of the connectivity division. TWO text items, "BE" (Belgium) and
# "SN" (Singapore) = the two most-used exits. Visual order is BE then SN, so vpn_sn
# is added FIRST (right-side items are added right-most first, like the rest of the
# bar). The label IS the content; the icon slot carries no icon — it carries the
# SELECTION DOT (see below).
#
# plugins/vpn.sh repaints BOTH items from one vpnutil snapshot on every run, on TWO
# independent channels:
#   colour = the tunnel state:  grey = not connected · red = connected ·
#            yellow = connecting (also the in-flight "…" busy look) ·
#            magenta = a pinned server is dead -> run `nord refresh`
#   DOT    = which country is SELECTED (~/.config/nordvpn-native/country): exactly
#            one dot at a time, always the SAME colour as the label above it.
# So "grey BE +dot / grey SN" = VPN off, BE is what a click would dial; "red BE +dot
# / grey SN" = connected via BE. (The old orange "selected but not connected" colour
# is gone — marking the selected country is the dot's job now.)
#
# DOT geometry (theme.sh SEL_DOT_*): the icon slot normally sits BESIDE the label, so
# the negative icon.padding_right below pulls it back UNDER the label with a net
# layout contribution of exactly ZERO (pad_left + advance + pad_right = 12+6-18 = 0)
# — the element stays 30 px wide and the division never shifts. Presence is a COLOUR,
# never icon.drawing: no dot = icon.color=$TRANSPARENT. Seeded dot-less; the first
# plugins/vpn.sh run paints the real state.
#
# Click = plugins/vpn_click.sh: clicking the icon WITHOUT the dot switches to that
# country and turns it on (`nord be` / `nord sg`); clicking the DOTTED (selected)
# icon toggles it on/off (`nord toggle`). Instant busy feedback (yellow "…") on the
# clicked icon + ONE SHARED click lock (/tmp/nordvpn-native.click) for both icons,
# whose `owner` file says which icon to keep busy. Paddings from theme.sh. The custom
# `vpn_change` event is triggered by nord.sh/nord-connect.sh after every state change.

# Selection-dot paddings — derived, not magic: an element is
# ELEMENT_GAP + <2 monospace chars at 14 pt = 18 px> + ELEMENT_GAP = 30 px wide
# (verified live: `sketchybar --query vpn_be | jq '.bounding_rects."display-1".size[0]'`
# -> 30; vpn_sn measures 31, so its dot sits 0.5 px left of centre — invisible, and
# deliberately kept on the same constant for both).
VPN_ELEMENT_W=$(( ELEMENT_GAP + 18 + ELEMENT_GAP ))
VPN_DOT_PAD_L=$(( (VPN_ELEMENT_W - SEL_DOT_ADVANCE) / 2 ))    #  12 -> ink centred
VPN_DOT_PAD_R=$(( -(VPN_DOT_PAD_L + SEL_DOT_ADVANCE) ))       # -18 -> zero net width

vpn_base=(
  icon="$SEL_DOT_GLYPH"
  icon.font="$FONT:Bold:$SEL_DOT_SIZE"
  icon.color=$TRANSPARENT
  icon.y_offset=$SEL_DOT_Y_OFFSET
  icon.padding_left=$VPN_DOT_PAD_L
  icon.padding_right=$VPN_DOT_PAD_R
  icon.drawing=on
  label.font="$FONT:Bold:14.0"
  label.color=$GREY
  background.drawing=off
  padding_left=0
  padding_right=0
  click_script="$PLUGIN_DIR/vpn_click.sh"
  script="$PLUGIN_DIR/vpn.sh"
  update_freq=30
)
```

- `icon.drawing=off` is **gone** (it is now `on`, permanently).
- `$TRANSPARENT`, `$GREY`, `$FONT`, `$ELEMENT_GAP`, `$DIVISION_PAD`, `$PLUGIN_DIR` and the new
  `$SEL_DOT_*` all come from sketchybarrc's sourced env (colors.sh + theme.sh, same shell).
  **No new palette entry** — `TRANSPARENT` already exists (colors.sh:13).

### 3.3 `configs/sketchybar/plugins/vpn.sh` — legend + colour chain + dot

**(a)** Replace the legend block (lines 12-19) with:

```bash
# Native NordVPN IKEv2 state; see docs/vpn/guide-nordvpn-native.md. TWO channels:
#   colour = the tunnel state, per icon:
#     grey    = not connected (off / failed / or simply not the selected country)
#     red     = connected
#     yellow  = connecting, or this icon owns the in-flight click
#     magenta = selected + a pinned server is dead -> run `nord refresh` (flag file)
#   dot (the icon slot, theme.sh SEL_DOT_*) = drawn under the SELECTED country only
#     (CFG_DIR/country), always in the SAME colour as its label; hidden with
#     icon.color=$TRANSPARENT so the layout never shifts.
# A non-selected country is ALWAYS grey (nothing dials it) — "selected but off" vs
# "not selected" are both grey and are told apart by the DOT. There is no orange.
# NEVER call `nord status` from here: its DNS sweep re-touches/clears the
# refresh-needed flag — a side effect a 30s poller must not have.
```

**(b)** Replace `paint()` (lines 47-58) with:

```bash
ARGS=()
paint() {  # $1=item name  $2=country code  $3=idle text
  local color dot=$TRANSPARENT label="$3"
  if   [ "$BUSY" = "$1" ];                    then color=$YELLOW; label="…"
  elif [ "$2" != "$COUNTRY" ];                then color=$GREY
  elif [ -f "$CFG_DIR/refresh-needed" ];      then color=$MAGENTA
  elif [ "$2" = "$CONN_CC" ];                 then color=$PINK
  elif [ "$2" = "$CONNECTING_CC" ];           then color=$YELLOW
  else                                             color=$GREY
  fi
  # The dot marks the SELECTED country and always matches the colour above it.
  if [ "$2" = "$COUNTRY" ]; then dot=$color; fi
  ARGS+=(--set "$1" label="$label" label.color="$color" icon.color="$dot")
}
```

Exactly two behavioural deltas: `color=$ORANGE` → `color=$GREY` (last branch) and the
`icon.color` channel. Lines 1-46 and 60-63 (`paint vpn_be be BE` / `paint vpn_sn sg SN` /
the single batched `sketchybar "${ARGS[@]}"`) are untouched. `if`, not `[ … ] && dot=…`, so
the function never returns non-zero on the no-dot path.

### 3.4 `configs/sketchybar/plugins/vpn_click.sh` — keep the dot in sync with the busy paint

Replace line 47 (`sketchybar --set "$NAME" label="…" label.color="$YELLOW"`) with:

```bash
# Instant busy feedback. The dot only ever sits under the SELECTED icon, so recolour
# it with the busy colour on the toggle branch and leave it hidden otherwise: a
# switch click must NOT grow a dot on the icon it is switching TO — the selection
# moves only once nord.sh has written `country` (and plugins/vpn.sh repaints).
if [ "$ACTION" = toggle ]; then DOT=$YELLOW; else DOT=$TRANSPARENT; fi
sketchybar --set "$NAME" label="…" label.color="$YELLOW" icon.color="$DOT"
```

Also extend the header bullet 1 (line 4-7) wording `clicking the icon of the currently
SELECTED country` → `clicking the DOTTED icon (the currently SELECTED country,` … and
`the other (grey) icon` → `the other (dot-less) icon`. No logic change; `$ACTION` already
exists (line 33). Everything else — lock, `owner`, `release()`, trap, `sleep 1` — untouched.

### 3.5 `docs/vpn/guide-nordvpn-native.md` (authoritative — same change, not follow-up)

- **Line 19, "Bar item" 3rd cell** — replace the colour sentence with:
  > two text items — **BE** (Belgium) and **SN** (Singapore, code `sg`) — on two channels.
  > **Colour = the tunnel:** grey = not connected, red = connected, yellow = connecting,
  > magenta = `nord refresh` needed. **A small DOT under one label = the selected country**
  > (`~/.config/nordvpn-native/country`), always in that label's colour, exactly one at a
  > time (it is the element's icon slot pulled under the label with a negative
  > `icon.padding_right`, so it costs zero layout width; hidden via
  > `icon.color=$TRANSPARENT`, geometry from theme.sh `SEL_DOT_*`). So grey+dot = "off, this
  > is what a click dials"; red+dot = "connected via this one". Click = `vpn_click.sh`:
  > dot-less icon → `nord <cc>` (switch + on), dotted icon → `nord toggle`; …
  (keep the rest of the cell — busy "…", 200 s stale-steal, shared lock + `owner` — verbatim).
- **Line 23** — `refresh-needed` (flag file → the selected country's bar icon turns magenta)
  stays correct: **no edit**.
- **Line 65 "Stale pins"** — already says magenta: **no edit**.
- **Line 80 "Verified test matrix"** — `bar states red/orange/grey + CC label (**superseded
  2026-07-30 by the two-icon BE/SN bar …**)` → `bar states red/orange/grey + CC label
  (**superseded 2026-07-30: two-icon BE/SN bar, then the colour+dot scheme — no orange
  remains; see the Bar item row and re-verify per that table**)`.
- **`## Caveats`, line 75** — append to the BE/SN bullet: `… **both** bar icons render grey
  **and no dot is drawn at all** — the "nothing selected on the bar" look is the tell.`

### 3.6 `_index.md`

- **Line 36 (theme.sh bullet)** — after `plus `DIVISION_PAD`/`ELEMENT_GAP` for inner edge +
  element spacing` insert: `, plus `SEL_DOT_*` (the selection-dot marker: glyph, size, measured
  glyph advance and y-offset — the dot is an element's ICON slot pulled under its label with a
  negative padding so it costs zero layout width)`.
- **Line 39 (items bullet)** — replace the vpn clause colour list with:
  > vpn_be/vpn_sn = two text icons (**BE**/**SN**) for the two most-used native-IKEv2 NordVPN
  > exits, on two channels — colour = the tunnel (grey = not connected, red = connected,
  > yellow = connecting, magenta = `nord refresh` needed) and a small **dot** under exactly
  > one label = the selected country (`~/.config/nordvpn-native/country`), in that label's
  > colour, zero-layout-cost via the icon slot (theme.sh `SEL_DOT_*`); click the dot-less icon
  > = `nord <cc>` (switch+on), click the dotted one = `nord toggle`, with instant busy "…" on
  > the clicked icon and one shared click lock; custom `vpn_change` event triggered by the
  > `scripts/vpn/` stack
- **Line 40 (plugins bullet)** — `` `vpn.sh` (paints BOTH vpn items from one vpnutil
  snapshot) `` → `` `vpn.sh` (paints BOTH vpn items from one vpnutil snapshot: label colour =
  tunnel state, icon slot = the selection dot) ``.

### 3.7 `docs/window-manager/guide-window-manager.md`

- **Line 163 (theme.sh token list)** — append after `ELEMENT_GAP (gap between elements inside
  a division)`: `, `SEL_DOT_GLYPH`/`SEL_DOT_SIZE`/`SEL_DOT_ADVANCE`/`SEL_DOT_Y_OFFSET` (the
  selection-dot marker)`.
- **theme.sh section, new bullet after line 164** (the hard-won lesson, in the same spirit as
  the empty-pill note):
  > - SELECTION DOT lesson: SketchyBar has no sub-label slot, and neither `label.background`
  >   nor the item `background` can be shrunk to a dot — `label.background.padding_*` does not
  >   change the fill's width at all and the item background's padding only TRANSLATES it
  >   (both verified by pixel-probing `screencapture` output), so a background can only be a
  >   full-width underline. The dot is therefore an element's ICON slot, dropped below the
  >   text with `icon.y_offset` (negative = DOWN) and pulled back under it with a NEGATIVE
  >   `icon.padding_right` such that `pad_left + SEL_DOT_ADVANCE + pad_right == 0` → zero
  >   layout cost. Show/hide is a COLOUR (`icon.color=$TRANSPARENT`), NEVER `icon.drawing`:
  >   `drawing=off` removes the glyph's advance and shifts the label.
- **Line 190 (state-driven items)** — replace the vpn clause with: `vpn_be/vpn_sn = two text
  icons "BE"/"SN" on two channels — colour = tunnel (grey = not connected, red = connected,
  yellow = connecting, magenta = `nord refresh` needed), plus a small dot under the SELECTED
  country's label in that label's colour (icon slot, theme.sh `SEL_DOT_*`, zero layout cost);
  no orange anywhere`.
- Lines 109, 111, 151, 187, 189, 191 — **no change** (item names, counts, freqs, padding
  tokens all still accurate).

---

## 4. Apply + smoke order

1. 3.1 → 3.2 → 3.3 → 3.4 (code), then 3.5 → 3.6 → 3.7 (docs).
2. `sketchybar --reload`; wait ~2 s.
3. `sketchybar --query vpn_be | jq -c '{iv:.icon.value,if:.icon.font,iy:.icon.y_offset,ipl:.icon.padding_left,ipr:.icon.padding_right,id:.icon.drawing,ic:.icon.color,lc:.label.color}'`
   → `{"iv":"●","if":"JetBrainsMono Nerd Font:Bold:12.00","iy":-9,"ipl":12,"ipr":-18,"id":"on", …}`
4. Widths: `vpn_be` = 30, `vpn_sn` = 31, `connectivity` = 83 or 85 (wifi RSSI glyph varies).
5. Hand off to QA with `07-acceptance-dot.md`.

---

# A. Truth table — state → (label, label colour, dot, dot colour)

Inputs, computed ONCE per `plugins/vpn.sh` run (all unchanged from round 1):
`COUNTRY` = `cat ~/.config/nordvpn-native/country` (fallback `sg`) · `CONN_CC` / `CONNECTING_CC`
= first `Connected`/`Connecting` name from one `vpnutil list`, minus `Nord-`, lowercased ·
`REFRESH` = `refresh-needed` exists · `BUSY` = `owner` of the click lock if it is <200 s old.

Per icon `N` ∈ {`vpn_be`,`vpn_sn`}, code `C` ∈ {`be`,`sg`}, text `T` ∈ {`BE`,`SN`} —
**first matching row wins**; the dot is orthogonal: `dot ⇔ C == COUNTRY`, `dot colour = label colour`.

| # | condition | `label` | `label.color` | dot? | `icon.color` |
|---|---|---|---|---|---|
| 1 | `BUSY == N` | `…` | `$YELLOW` | iff `C==COUNTRY` | `$YELLOW` / `$TRANSPARENT` |
| 2 | `C != COUNTRY` | `T` | `$GREY` | no | `$TRANSPARENT` |
| 3 | `REFRESH` | `T` | `$MAGENTA` | yes | `$MAGENTA` |
| 4 | `C == CONN_CC` | `T` | `$PINK` | yes | `$PINK` |
| 5 | `C == CONNECTING_CC` | `T` | `$YELLOW` | yes | `$YELLOW` |
| 6 | else | `T` | `$GREY` | yes | `$GREY` |

Rows 3-6 imply `C == COUNTRY`. **Rows 2 and 6 share a colour and differ ONLY by the dot** —
that is the whole point of this change.

## Per-scenario expansion (both icons)

| scenario | BE icon | SN icon |
|---|---|---|
| disconnected, `country=be` | grey `BE` + **grey dot** | grey `SN`, no dot |
| disconnected, `country=sg` | grey `BE`, no dot | grey `SN` + **grey dot** |
| connected to BE (`country=be`) | red `BE` + **red dot** | grey `SN`, no dot |
| connected to SG (`country=sg`) | grey `BE`, no dot | red `SN` + **red dot** |
| connecting (`country=sg`, Nord-SG `Connecting`) | grey `BE`, no dot | yellow `SN` + **yellow dot** |
| refresh-needed (`country=be`, any tunnel state) | magenta `BE` + **magenta dot** | grey `SN`, no dot |
| busy — click on the DOTTED icon (`toggle`, `country=be`) | yellow `…` + **yellow dot** | grey `SN`, no dot |
| busy — click on the DOT-LESS icon (switch to sg, `country` still `be`) | its real colour + **its dot** (grey/red → grey once torn down) | yellow `…`, **no dot** (selection moves only after `nord` writes `country`) |
| `country` file missing/empty | falls back to `sg` ⇒ identical to the `country=sg` rows | ⇑ |
| `vpnutil` missing / broken output | `CONN_CC`/`CONNECTING_CC` empty ⇒ row 6 for the selected icon: grey + **grey dot**; other grey, no dot | ⇑ |
| `country` ∈ {fr,my,us,vn} (CLI-only exit) | grey `BE`, no dot | grey `SN`, no dot — **no dot anywhere** (known 2-icon gap, now self-evident) |
| performance mode ON | item `drawing=off` — label AND dot hidden together, no extra work | ⇑ |

## The removed ORANGE branch

- Only consumer: `configs/sketchybar/plugins/vpn.sh:55` (`else color=$ORANGE`) → becomes `$GREY`.
- Every other `ORANGE` reference is untouched and unaffected: `colors.sh:10` (the definition —
  **kept**, no palette change), `plugins/aerospace_mode.sh:21` and `plugins/brew.sh:10` (both
  DEAD, not sourced), `items/spaces.sh:6` (a comment). **Nothing else depended on it.**
- Information loss: none that mattered. "selected + not connected" (was orange) and "not
  selected" (grey) now share a colour, disambiguated by the dot. "Broken `vpnutil`" also used
  to land on orange, i.e. it was already indistinguishable from off/failed — it now lands on
  grey+dot with exactly the same information content.
- Prose sweep: every remaining "orange" in `docs/` and `_index.md` (guide line 19 + line 80,
  `_index.md:39`, WM guide line 190) is rewritten in §3.5-3.7. After this change
  `grep -rni orange docs/ _index.md` must return **no** statement about a live bar colour.

# B. Round-1 acceptance items this change SUPERSEDES

`04-acceptance.md` / `05-qa-round1.md` must not be silently contradicted. Superseded:

| round-1 item | was | now |
|---|---|---|
| 4 | `.icon.drawing` → `off`; `.icon.value` not `:nord_vpn:` | `.icon.drawing` → **`on`**; `.icon.value` → **`●`** (still not `:nord_vpn:`) |
| 10 | "no bare numbers" in items/vpn.sh | still no bare numbers — the dot pads are DERIVED from `$SEL_DOT_ADVANCE` + `ELEMENT_GAP`; the single literal `18` (2-char label width) is documented + verified live |
| 15 | precedence … → connecting (YELLOW) → else **ORANGE** | … → connecting (YELLOW) → else **GREY** |
| 16 | the plugin sets ONLY `label=` + `label.color=` | sets `label=`, `label.color=`, **`icon.color=`**; still never `icon.drawing`, `label.drawing` or any `*padding*` |
| 28 | click paints exactly one `--set "$NAME"` | unchanged (one `--set "$NAME"`, now carrying `icon.color` too) |
| 33 | live click on the red icon → turns **orange** | → turns **grey but keeps its dot** |
| 37 | "orange only in its new meaning" | **no** live-colour "orange" statement may remain anywhere |

Everything else from round 1 stands and must still pass (see checklist §D).

# C. Explicitly NOT done (and why)

- No new bar item ⇒ **no** edit to `sketchybarrc` (bracket membership), `performance-mode.sh`
  (both branches + header), `wifi_click.sh`, or any other name-enumeration site.
- No `scripts/vpn/*`, `zsh/alias/vpn.zsh`, `configs/nordvpn/*` change — the CLI contract is
  untouched by a rendering change.
- No `colors.sh` change: `$TRANSPARENT`, `$GREY`, `$PINK`, `$YELLOW`, `$MAGENTA` all already
  exist. `$ORANGE` stays defined (other, dead, references).
- No `icons.sh` change: the dot glyph lives with its metrics in theme.sh (see §3.1 rationale);
  the unused `VPN_CONNECTED`/`VPN_DISCONNECTED` exports stay unused.
- No `label.drawing`/`icon.drawing` toggling at runtime, no animation, no new state file, no
  new lock, no notification.
