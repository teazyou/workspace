# Researcher A — sketchybar/bar side. READ-ONLY, no mutations made.

Pre-read done: `docs/vpn/guide-nordvpn-native.md` (full), `_index.md` (full). Also cross-read
`sprint/vpn-rework/02-research-b.md` (B's completed report, present at research time) for
CLI-side cross-validation — cited explicitly below wherever used, distinct from my own
tool-verified findings.

Verified live (read-only): `sketchybar --query {bar,vpn,connectivity,wifi,ethernet,time,date}`,
`vpnutil list`, `cat ~/.config/nordvpn-native/{country,enabled,refresh-needed,boot-id,fail-stamp}`,
`man sketchybar(1)/sketchybar-events(5)/sketchybar-items(5)`, whole-repo greps (scoped to avoid
`configs/dot-claude/` — that dir is Claude Code's own runtime/session cache, symlinked from
`~/.claude`; grepping into it just re-discovers earlier tool output, not repo config — excluded
throughout). No state mutated, no file edited, no git touched, no lint run.

Live snapshot: `country=be enabled=1 refresh-needed=ABSENT`. `vpnutil list`: Nord-BE=Connected,
FR/MY/SG/US/VN=Disconnected. No `/tmp/nordvpn-native.{click,lock}` present. Matches brief + B.

---

## Q1 — naming, membership, sketchybarrc diff

**Names:** `vpn_be` / `vpn_sn` (matches brief's example, greppable, no collision).

**Bracket-order vs add-order — settled empirically, not just from docs.** Live query proof:
`sketchybar --query connectivity` → `"bracket": ["vpn","wifi","ethernet"]` (add-list order from
`sketchybarrc:154`) but `bounding_rects` show actual X positions: wifi `origin.x=2184 size=22`,
ethernet `origin.x=2206 size=0` (currently collapsed/disconnected), vpn `origin.x=2206 size=48`.
Visual L→R = **wifi, ethernet, vpn** — the exact opposite grouping-feel of the bracket-add list
order. `man sketchybar-items(5):40-41`: *"The items will appear in the bar in the order in which
they are added."* Cross-checked against 3 more existing pairs, all consistent: `calendar.sh`
adds `time` before `date` (`items/calendar.sh:22,42`) → time ends up rightmost (query confirms
`time.origin.x=2508` > `date.origin.x=2431+size 69=2500`); `sketchybarrc:134-136` comment "source
battery (rightmost/last), then ram, then cpu" for the resources group; `sketchybarrc:141-147`'s
own comment for the current trio. **Rule (this exact sketchybar v2.24.0, right-side items):
each subsequent `--add item X right` lands X to the LEFT of every previously-added right item —
first add of a contiguous run = rightmost.** Bracket **membership list order is cosmetic only** —
confirmed by the mismatch above (list says vpn,wifi,ethernet; screen says wifi,ethernet,vpn) —
only WHICH names are listed matters (bracket paints across whichever items currently occupy that
visual span), never their order in the `--add bracket` call.

**Recommended visual order (open, cosmetic):** wifi, ethernet, vpn_be, vpn_sn (alphabetical,
matches the order user wrote "BE and SN"). `vpn_sn` becomes the division's true right edge
(owns `DIVISION_PAD`); `vpn_be` sits inner (owns `ELEMENT_GAP` both sides). Trivially flippable
by swapping which array gets which padding + which add-call comes first — flag as open decision,
zero functional impact either way.

**Recommended shape: keep ONE file `items/vpn.sh`** (not split into two files) defining both
items via a shared base array — mirrors the existing `monitor_item_base` pattern already used by
`cpu.sh`/`ram.sh` (`sketchybarrc:105-115`). Benefit: `sketchybarrc`'s source-order comment block
barely changes (still ONE `source "$ITEM_DIR/vpn.sh"` line, unchanged position relative to
ethernet/wifi) — the two-add ordering is self-contained/documented in vpn.sh's own header instead
of being implicit cross-file ordering. Alternative (split files) given below too since the task
asks for the exact diff either way.

**Exact sketchybarrc diff (recommended: single-file variant).**
Current (`configs/sketchybar/sketchybarrc:141-155`):
```
141: # Network connectivity group (L->R: wifi, ethernet, vpn). Right items are added
142: # right-most first, so source vpn (rightmost), then ethernet, then wifi (leftmost)
143: # — this puts ethernet immediately to the right of wifi. Leftmost division of the
144: # right-side cluster — no spacer after it.
145: source "$ITEM_DIR/vpn.sh"
146: source "$ITEM_DIR/ethernet.sh"
147: source "$ITEM_DIR/wifi.sh"
...
153: # Bracket for network connectivity group (ethernet + wifi + vpn)
154: sketchybar --add bracket connectivity vpn wifi ethernet \
155:            --set connectivity "${bracket_style[@]}"
```
New:
```
141: # Network connectivity group (L->R: wifi, ethernet, vpn_be, vpn_sn). Right items are
142: # added right-most first, so source vpn.sh (adds vpn_sn then vpn_be internally —
143: # see its own header), then ethernet, then wifi (leftmost). Leftmost division of
144: # the right-side cluster — no spacer after it.
145: source "$ITEM_DIR/vpn.sh"          # <- UNCHANGED line; file's own contents do 2 adds now
146: source "$ITEM_DIR/ethernet.sh"
147: source "$ITEM_DIR/wifi.sh"
...
153: # Bracket for network connectivity group (ethernet + wifi + vpn_be + vpn_sn)
154: sketchybar --add bracket connectivity vpn_be vpn_sn wifi ethernet \
155:            --set connectivity "${bracket_style[@]}"
```
Only the comments (141-144) + the bracket member list (154) actually change; source lines
145-147 are byte-identical. **Alternative (split-file) diff** if the human prefers one item per
file — replace 145 with two lines, and the internal add-order requirement moves from "inside
vpn.sh" to "which file is sourced first":
```
145: source "$ITEM_DIR/vpn_sn.sh"   # first of this run = rightmost = true division edge
146: source "$ITEM_DIR/vpn_be.sh"   # second = just to vpn_sn's left
147: source "$ITEM_DIR/ethernet.sh"
148: source "$ITEM_DIR/wifi.sh"
```
(then bracket line as above). Flag: with split files, the shared `--add event vpn_change` (see
Q2) must live in exactly ONE of the two files — recommend `vpn_sn.sh` since it sources first.

**Where relative to wifi/ethernet:** unchanged — both new items still sit to the RIGHT of
ethernet, i.e. at the division's outer/right end, exactly where the single `vpn` item sits today.

---

## Q2 — every hardcoded `vpn` reference (complete, file:line)

Grepped `configs/`, `scripts/`, `zsh/`, `docs/`, `_index.md` (dot-claude excluded — see header).

**Must become TWO (one call/name per item), or be reworked to stop hardcoding a single name:**
| File:line | Current | Required change |
|---|---|---|
| `configs/sketchybar/items/vpn.sh:11` | `vpn=(` (bash array var) | becomes `vpn_be=(` / `vpn_sn=(` (+ shared `vpn_base=(`) |
| `configs/sketchybar/items/vpn.sh:30` | `--add item vpn right` | 2 calls: `--add item vpn_sn right` then `--add item vpn_be right` (order = visual order, see Q1) |
| `configs/sketchybar/items/vpn.sh:31` | `--set vpn "${vpn[@]}"` | `--set vpn_sn "${vpn_sn[@]}"` / `--set vpn_be "${vpn_be[@]}"` |
| `configs/sketchybar/items/vpn.sh:32` | `--subscribe vpn system_woke wifi_change vpn_change` | 2 calls, one per new name; event-name list itself (`system_woke wifi_change vpn_change`) is UNCHANGED |
| `configs/sketchybar/plugins/vpn_click.sh:25` | `sketchybar --set vpn icon.color=...` (literal, NOT `$NAME`) | **bug if left as-is**: must become `--set "$NAME" ...` so the one shared click handler paints whichever icon was actually clicked (today it's hardcoded even though the file already uses `$NAME`-free logic elsewhere — this is the one concrete break point in this file) |
| `configs/aerospace/performance-mode.sh:54` | `--set vpn drawing=on update_freq=30 \` | 2 lines: `--set vpn_be drawing=on update_freq=30 \` + `--set vpn_sn drawing=on update_freq=30 \` |
| `configs/aerospace/performance-mode.sh:72` | `--set vpn drawing=off update_freq=0 \` | same, 2 lines, `drawing=off update_freq=0` |
| `configs/sketchybar/sketchybarrc:145` | `source "$ITEM_DIR/vpn.sh"` | unchanged (single-file plan) or → 2 lines (split-file plan), see Q1 |
| `configs/sketchybar/sketchybarrc:154` | `--add bracket connectivity vpn wifi ethernet` | `--add bracket connectivity vpn_be vpn_sn wifi ethernet` (member list only; order cosmetic, see Q1) |

**Comment-only (prose, not executable) — need wording pass but no logic change:**
`configs/sketchybar/items/vpn.sh:3-10` (header), `configs/sketchybar/plugins/vpn_click.sh:3-9`
(header), `configs/aerospace/performance-mode.sh:8,17` (division-member list + freq table),
`configs/sketchybar/plugins/wifi_click.sh:4` ("...and vpn, which also subscribes to
wifi_change..." → "...and vpn_be/vpn_sn, which also subscribe...") — **note: `wifi_click.sh`'s
actual CODE (`wifi_click.sh:14`, bare `sketchybar --trigger wifi_change`) needs ZERO change**, it
fires a broadcast event, name-agnostic by construction; only its comment goes stale.

**Confirmed STAY SINGLE (verified, not just assumed):**
- `vpn_change` **event name** — stays one event, shared by both items' `--subscribe`. Every
  emitter (`scripts/vpn/nord.sh:47,111,113,120,134,160`; `nord-connect.sh:85,91,97`;
  `vpn_click.sh:23` trap) fires it unaware of/uncoupled from bar item naming — confirmed no
  emitter references item names at all (only `sketchybar --trigger vpn_change`, an event token,
  not an item token). Only the **subscriber** side needs duplicating (both items subscribe to
  the same event, per row above).
- `system_woke`, `wifi_change` — built-in sketchybar events (`sketchybar-events(5)` EVENTS
  table), untouched, both new items keep subscribing to both, unchanged names.
- `configs/aerospace/aerospace.toml` — **zero `vpn` references found** (`grep -n -i vpn
  aerospace.toml` → exit 1, no match). Confirmed: its `after-startup-command` only calls
  `performance-mode.sh` by path, never names `vpn` inline. **No edit needed here.**
- `configs/aerospace/lib-paths.sh` — same, zero `vpn` references, confirmed via grep, no edit.
- `configs/sketchybar/icons.sh:63-65` (`VPN_CONNECTED`/`VPN_DISCONNECTED` Nerd-Font glyph
  exports) — already **dead/unused** today (`items/vpn.sh` actually uses the DIFFERENT
  `:nord_vpn:` sketchybar-app-font glyph, never these two). Stay dead/untouched under the
  recommended text-only design (Q3) — no glyph needed at all.
- `scripts/vpn/*`, `zsh/alias/vpn.zsh`, `zsh/zshrc.zsh:37` — CLI-side plumbing, unrelated to bar
  item naming, outside this assignment's scope (see B's report for that side; per B's Q6/Q8
  verdict, zero `scripts/vpn/*` changes are required for the bar rework).

---

## Q3 — text rendering: `icon=` vs `label=`

Both are structurally identical (`sketchybar-items(5)` "Text properties" table, lines 252-340:
`icon.*` and `label.*` share the exact same property schema — drawing/color/font/padding/`string`
(the actual text) — nothing technically prevents plain ASCII in either slot). This is a
convention choice, resolved by precedent + the fact the new design carries **no decorative
glyph at all** (user's spec: the whole icon IS the text "BE"/"SN", not glyph+annotation).

**Recommend: `label=` is the content, `icon.drawing=off`** (no icon at all) — mirrors
`items/calendar.sh`'s `time_item` (lines 10-20): `icon.drawing=off`, `label="$(date ...)"`,
`label.font="$FONT:Bold:14.0"` — the established pattern in this bar for "this item's whole
visible content is READABLE text, no glyph". Every other readable-text item (time, date, cpu %,
ram, battery %) uses `label` + `$FONT:Bold` at 12.0–14.0; `icon.font`/`sketchybar-app-font` is
reserved for decorative glyphs or pictorial state (wifi bars, ethernet plug, clock icon,
`:nord_vpn:` today) — none of which apply once the glyph is dropped.

**Font size — open cosmetic decision, recommend 14.0 Bold:** live query of the CURRENT vpn
item shows `label.font: "JetBrainsMono Nerd Font:Semibold:10.00"` (`items/vpn.sh:18`) — small,
because it was a SECONDARY annotation next to a dominant 16pt icon glyph. Now that BE/SN is the
ENTIRE content of the item, 10pt Semibold reads thin next to neighbouring primary text at 14pt
Bold (time/date/cpu%/ram/battery — all `$FONT:Bold:14.0`). Recommend bumping to
`label.font="$FONT:Bold:14.0"` for parity; global default (`sketchybarrc:58`,
`label.font="$FONT:Bold:12.0"`) is the minimal-diff fallback if the human wants a smaller
footprint; keeping 10.0 Semibold is also viable if a compact look is preferred. **Flag: aesthetic
open decision, not resolved here.**

**Concrete property set (both items, via shared `vpn_base`):**
```
icon.drawing=off                        # no glyph — confirmed layout-safe, see Q4
label.font="$FONT:Bold:14.0"            # or keep 10.0 Semibold — open decision above
background.drawing=off
padding_left=0
padding_right=0
click_script="$PLUGIN_DIR/vpn_click.sh" # shared, see Q5
script="$PLUGIN_DIR/vpn.sh"             # shared, see Q5
update_freq=30                          # see Q6
```
Per-item overrides: `label="BE"` / `label="SN"` (seed text, immutable content in steady state —
see Q8), `label.color=$GREY` (seed colour, corrected by the first script tick), plus the
per-item paddings from Q4.

---

## Q4 — padding math, 4-item division

**Old dynamic branch (`plugins/vpn.sh:32-37`) is fully removable.** It exists ONLY because the
old single item toggled `label.drawing` on/off (label shown only when connected/connecting,
hidden when off) — so whichever element (icon or label) was the last DRAWN one had to own the
division's right-edge `DIVISION_PAD`. **New items never toggle `label.drawing`** — label content
is near-static (always "BE"/"SN", swapping only to "…" while busy — text changes, drawn-ness
never does) — so the padding owner never needs to shift. **Fully static padding, no branch.**

**Empirical check — does a permanently-`off` icon's padding matter?** Verified via
`sketchybar --query time`: `icon.drawing=off`, yet `icon.padding_left=12 icon.padding_right=4`
are still the INHERITED, never-zeroed `defaults` values (`sketchybarrc:55-56`) — and the layout
is still correct (`time` bounding rect starts exactly where `date`'s trailing gap + `time`'s own
`label.padding_left=6` predicts, no extra 16px phantom gap from the unzeroed icon padding).
**Conclusion: a permanently-`off` icon's padding is excluded from layout entirely — no need to
manually zero `icon.padding_left/right` for vpn_be/vpn_sn.** (Contrast: `plugins/ethernet.sh:28`
DOES zero icon padding on hide — but that's a RUNTIME TOGGLE case (on↔off), possibly defensive
rather than strictly required; not directly informative for a padding that's `off` from
creation and never flips. Flagging the distinction rather than asserting ethernet's zeroing is
unnecessary.) Recommend following the simpler `time_item` precedent: don't set icon padding at
all, just `icon.drawing=off`.

**Final static padding table** (division L→R: wifi, ethernet, vpn_be, vpn_sn):
| item | icon.padding_left | icon.padding_right | label.padding_left | label.padding_right | notes |
|---|---|---|---|---|---|
| wifi | `DIVISION_PAD` | 0 | n/a (label off) | n/a | unchanged, owns left edge |
| ethernet | `ELEMENT_GAP`/0 (state-driven) | 0 | n/a (label off) | n/a | unchanged, hide-when-disconnected |
| vpn_be | (unset/moot, icon off) | (unset/moot) | `ELEMENT_GAP` | `ELEMENT_GAP` | inner item, both neighbours get a gap |
| vpn_sn | (unset/moot, icon off) | (unset/moot) | `ELEMENT_GAP` | `DIVISION_PAD` | owns the division's right edge |

(If the human instead flips the L-R order per Q1's open decision, swap vpn_be/vpn_sn's rows.)
`DIVISION_PAD == ELEMENT_GAP == 6` numerically today (`theme.sh:55-56`) but use the semantically
correct token, not a bare `6` — theme.sh's whole point is a single edit re-styling the bar.

---

## Q5 — one plugin/click-handler, two items

**Confirmed via `man sketchybar-items(5):226-230`** — `script`/`click_script` value type is
`<path>, <string>`, and the man page's own worked example (`:536-537`) passes a full multi-word
shell command as the `script` value (`script='sketchybar --set $NAME label="$(date ...)"'`) —
proving the property is executed through a shell, not exec'd as a bare path. **So
`script="$PLUGIN_DIR/vpn.sh be"` would work** (arrives as `$1`).

**Recommend NOT using that mechanism — use `$NAME` dispatch instead.** Confirmed via
`man sketchybar-events(5):30-37`: *"All scripts invoked by an item have access to... `$NAME`...
where `$NAME` is the name of the item that invoked the script"* — stated as universal, covering
BOTH `update_freq` routine ticks (where `$SENDER=routine`) AND event deliveries (where
`$SENDER`=the event name) AND click invocations (which additionally get `$BUTTON`/`$MODIFIER`).
Confirmed empirically too: every live plugin in this repo already relies on exactly this (`grep
'\$NAME' plugins/*.sh` → hits in `battery.sh:33`, `cpu.sh:13`, `ram.sh:23`, `date.sh:2`,
`time.sh:2`, `wifi.sh:24,28,37`, `ethernet.sh:25,28`, etc. — all read `$NAME`, none pass CLI
args). **`$NAME` is already the single, guaranteed-correct source of truth for "which item am
I" — a `script=".../vpn.sh be"` argument would be a REDUNDANT second source of truth that can
drift if the item is ever renamed without updating the string.** Recommend: one shared
`plugins/vpn.sh`, dispatch via `case "$NAME" in vpn_be) CC=be; LABEL=BE;; vpn_sn) CC=sg;
LABEL=SN;; esac` (small lookup table, 2 lines).

**`plugins/vpn_click.sh`: same shared-file recommendation, same `$NAME`→cc mapping** (ideally
the identical 2-line table, duplicated or factored into a tiny sourced snippet both scripts
`source` — minor DRY nicety, not required). Per B's Q3 (nord.sh:37-39 `cc_of()`): `nord.sh`
already accepts **both** the full name (`belgium`/`singapore`) AND the 2-letter code (`be`/`sg`)
as aliases — `belgium|be) echo be ;;` / `singapore|sg) echo sg ;;`. **This means the SAME 2-letter
code already needed for the "am I the active icon" file-comparison (Q8) also works directly as
the `nord` CLI argument** — no separate "full word" mapping needed, collapsing what looked like a
3-way (display-label / file-code / CLI-arg) mapping down to a clean 2-column table:
```
NAME      display-label   code (= country-file value = nord CLI arg)
vpn_be    BE              be
vpn_sn    SN              sg
```
**Bar's read-side must NOT call `nord status`** — per B's Q6, that path re-touches/clears
`refresh-needed` via a DNS-health sweep (`nord.sh:138-152`), a side effect unacceptable in a
30s-cadence poller. Continue reading `vpnutil list` + raw `cat $CFG_DIR/country` directly, exactly
as today's `plugins/vpn.sh:15-19` already does for the vpnutil part (the `country`/`enabled`
reads are NEW plumbing this rework adds — confirmed via B's Q6/Q8: today's `plugins/vpn.sh`
reads neither file at all).

---

## Q6 — polling cost + events

Today: 1 item, `update_freq=30`, 1×`vpnutil list` + 2×`jq` per tick (`plugins/vpn.sh:16-18`).

**Recommend: BOTH items keep independent `update_freq=30` + `--subscribe NAME system_woke
wifi_change vpn_change`** (identical subscribe list as today, just duplicated onto both names) —
**and** the shared `plugins/vpn.sh` paints BOTH items every time it runs (one `vpnutil list`
fetch → derive full state → single batched `sketchybar --set vpn_be ... --set vpn_sn ...` call),
regardless of which item's tick/event triggered that particular invocation.

Rationale, weighing the 3 options the brief poses:
- **(a) both poll, each paints only itself** — simplest, but 2 independent `vpnutil list` fetches
  microseconds apart could (rarely, self-healing next tick) paint from slightly different
  snapshots — a non-issue in practice but avoidable for free.
- **(b) one "driver" item polls+paints both, sibling has `update_freq=0`/no script/no
  subscriptions** — roughly halves subprocess count (1×`vpnutil list` per 30s instead of ~2×), but
  introduces a hidden driver→follower coupling **with zero precedent anywhere in this bar** —
  every existing multi-item pair (date+time, cpu+ram, wifi+ethernet) is two independently-polling
  scripts, never one driving the other. Concretely fragile per the brief's own hint: the passive
  sibling would go **permanently stale** (no self-heal) if ever its own `update_freq`/subscriptions
  silently diverge from the driver's in a future edit (e.g. `performance-mode.sh`, Q10, only
  needs to manage the driver's freq in this design — an easy site for a future half-edit to break
  the passive twin without any visible symptom until someone notices a frozen icon).
- **(c, recommended) both independently poll+subscribe (matches precedent, ROBUST — no
  driver/follower coupling to break), but the ONE shared script paints both targets per
  invocation** (consistency benefit of (b) without its staleness risk). Net cost vs today: ~2×
  `vpnutil list`/`jq` subprocess spawns per 30s window instead of ~1× — **negligible**: `ram.sh`/
  `cpu.sh` already poll at `update_freq=5` (6× more often) with no documented issue; `vpnutil` is
  a lightweight status query, not a network call.

**Failure mode of the option NOT recommended (b):** exactly what the brief flags — "a listen-only
item goes stale after a System-Settings-initiated change" — a manual System Settings VPN toggle
fires NEITHER `wifi_change` NOR `vpn_change` (only `nord.sh`/`nord-connect.sh` fire the latter), so
a passive item with `update_freq=0` and no subscriptions has **no self-heal path at all**, ever,
for that case — it would show stale state indefinitely until the next unrelated event happens to
also repaint it via the driver. Independent polling (recommended) bounds staleness to ≤30s
regardless of event coverage gaps.

---

## Q7 — per-icon busy "…"

**Confirmed with B (their Q7): the click lock MUST stay ONE shared `/tmp/nordvpn-native.click`
across both icons, never per-icon.** B's reasoning, which I adopt as the hard constraint: if the
lock were per-icon, a second click while the first is in flight would sail past its OWN
now-separate lock and reach `nord.sh`, which would then block up to ~60s inside its OWN
`lock_acquire` (`nord.sh:49-57`, per B's Q2 timing) before silently failing — the second icon
would show "…" for up to a full minute for nothing, worse UX than today's instant silent drop.
Keeping ONE shared lock preserves the existing instant-drop behaviour unchanged.

**Concrete mechanism (owner-token, additive to the existing lock — not a redesign):**
- Lock dir: `/tmp/nordvpn-native.click` — **unchanged** path, unchanged `mkdir`-atomic acquire
  semantics, unchanged 200s stale-steal window (see timing note below).
- **New:** immediately after the winning `mkdir` succeeds (before the instant busy repaint),
  `vpn_click.sh` writes `echo "$NAME" > "$CLICK_LOCK/owner"` (plain text, single line, the
  clicked item's own name — `vpn_be` or `vpn_sn`; equally could store the 2-letter `$CC`, `$NAME`
  is simpler since it's already the exact string the painter compares against).
- **Painter side (`plugins/vpn.sh`):** old blanket check `[ -d "$CLICK_LOCK" ] && COLOR=$YELLOW
  LABEL="…"` becomes conditional on ownership: `[ -d "$CLICK_LOCK" ] && [ "$(cat
  "$CLICK_LOCK/owner" 2>/dev/null)" = "$NAME" ]` → paint busy; **else paint this item's own
  normally-derived state** (even while the lock exists, if this item isn't the owner). This is
  the only actual logic change needed in the painter for busy handling.
- **What renders on each icon while ONE is busy:** the clicked/owner icon → YELLOW + `label="…"`
  (unchanged look). The sibling → its own normal derived colour (Q8's state table), computed from
  the SAME single `vpnutil list` fetch (Q6) — e.g. during a BE→SN switch, `vpn_sn` shows "…"
  while `vpn_be` (still "active" by the `country`-file rule until the switch actually succeeds,
  per B's Q1) shows its honest transient state (likely flashing ORANGE as `stop_all` tears it
  down) — an accurate, not-frozen rendering, not a bug.
- **Implementation gotcha to flag explicitly:** once an `owner` file lives INSIDE the lock dir,
  plain `rmdir` (used today at `vpn_click.sh:20,33` for stale-steal and normal release) **will
  fail** ("Directory not empty"). Both cleanup sites must change from `rmdir` to `rm -rf
  "$CLICK_LOCK"` (or explicit `rm -f "$CLICK_LOCK/owner"` before `rmdir`). This is a concrete,
  load-bearing one-line-times-two fix for whoever implements this — easy to miss since the
  `mkdir`-based ACQUIRE test itself is unaffected and still correct.
- **Stale timeout:** keep 200s. Per B's Q2 (code-derived, not measured): worst-case `nord <cc>`
  success ≈176–182s (pathological triple-worst-case stacking, unrealistic in practice), typical
  8–15s; worst-case failure ≈55–65s or a flat ~60s if the lock itself never frees. 200s still
  numerically covers the absolute worst case (~9% margin — thin but **pre-existing**, per B: `nord
  toggle`'s "on" branch already runs this identical chain today, so the 2-icon rework doesn't
  itself widen the number, only changes how often the lock gets contended). Not changing it here;
  flag the thin margin as a pre-existing fact, not a new problem introduced by this feature.
- **Missing/unreadable owner file fallback** (e.g., a lock dir left by some future/older code
  path without the file): recommend both icons paint normal derived state (fail toward "nobody
  is marked busy") rather than both showing "…" — simpler, and this path should essentially never
  occur since the same script that creates the lock writes the file a statement later.
- **Cross-cutting risk, worth flagging loudly (found via `sketchybar-events(5):51`):** *"All
  scripts are forced to terminate after 60 seconds."* If a `nord <cc>` call ever runs past 60s
  wall-clock (per B's Q2, realistically rare but the code allows it), sketchybar SIGKILLs the
  `click_script` process outright — a SIGKILL bypasses the bash `EXIT` trap entirely (traps only
  fire on normal exit or catchable signals), so `rm -rf "$CLICK_LOCK"` in the trap (`vpn_click.sh:
  23`) would NOT run, leaving the lock (+owner file) stale until the 200s steal window. This is a
  **pre-existing risk** (applies to today's single-icon design too, just never surfaced because
  nobody looked), surfaced here only because this rework is touching this exact file — not
  something to silently fix as part of this feature, flagging for the human/B to jointly decide
  whether it's worth hardening (e.g. `nord.sh` also being invoked in the background with `&` and
  the click script polling instead of blocking — a bigger redesign, likely overkill).

---

## Q8 — colour-state matrix, resolve the ORANGE collision

**Resolution direction (not silently picked): keep the user's literal new ORANGE meaning
("active, not connected"); relocate refresh-needed to a DIFFERENT token.** Reasoning: the user's
spec is explicit and specific about orange ("orange when not connected" for the active icon);
refresh-needed's colour is an implementation detail the user never mentioned — reassigning THAT
one, not the user's explicit instruction, is the change that respects what was actually asked.
(This also matches the exact framing of the brief's own Q8, which is written expecting this
resolution direction.)

**Free-token audit** (grep `\$TOKEN` across the ~8 live items + ~12 live plugins, excluding
`colors.sh` itself and confirmed-dead files `apple.sh`/`brew.sh`/`github.sh`/`spotify.sh`/
`front_app.sh`/`volume_click.sh`/`aerospace_mode.sh` — the last is ALSO dead: `grep -rn
aerospace_mode items plugins sketchybarrc` → zero hits, it's never sourced/referenced anywhere,
contra what its filename suggests):
| Token | Hex | Used live? | Verdict |
|---|---|---|---|
| `RED` | `0xFFCE3A5B` | no | free, but same red family as `PINK`/`0xffaa2222` — risks blending with "Connected" |
| `GREEN` | `0xFF638989` (actually a muted teal per RGB, not vivid green) | no | free |
| `BLUE` | `0xFF1E6E77` (deep teal) | no | free |
| `MAGENTA` | `0xffc6a0f6` (light lavender) | no | free, most visually distinct from the reds/orange/yellow already in this state machine |
| `GREY` | `0xff939ab7` | **yes** (the "not selected" state) | not free |
| `WARM_GRAY` | `0xFFD3CDC5` | no | free, but perceptually close to `GREY` (both desaturated) — risks confusion with "not selected" |
| `YELLOW`, `ORANGE`, `PINK` | — | yes | not free (busy/connecting, active-disconnected, connected) |

**Recommend `MAGENTA`** for refresh-needed — free, and the most hue-distinct option against a
division already using red/orange/yellow/grey. `BLUE`/`GREEN` are viable seconds; `RED` and
`WARM_GRAY` flagged as weaker choices (collision risk with `PINK`/`GREY` respectively at 16px in
a dark bar). **Open decision — flagging, not deciding**, per instructions.

**YELLOW/Connecting survival — flag the decision, don't silently pick.** Two real options:
1. **Keep distinct** (recommended): `Connecting` (from `vpnutil list`) gets its own branch,
   same `$YELLOW` token the busy overlay also uses (busy already visually "reads" as "something's
   happening", so sharing the hue is fine — they're mutually exclusive in practice, see below).
   Real value: the launchd watcher (`nord-connect.sh`) can auto-reconnect in the background
   WITHOUT holding the sketchybar click lock (that lock is click-path-only) — so a Wi-Fi-wake
   auto-reconnect is the one scenario where a live "Connecting" paint is actually independently
   observable (not masked by the busy overlay), giving the user real "it's working" feedback for
   a genuinely event-driven, zero-polling system whose whole selling point is invisible background
   self-healing. Cheap to keep (one `elif`).
2. **Fold into ORANGE/busy**: simpler palette (one fewer branch), loses that background-reconnect
   signal.
   **Recommendation: keep it distinct (option 1)** — flagging as the human's call to override.

**Full per-icon state table** (for icon with fixed code `MY_CC` ∈ {be, sg}; `country` = file
content; `conn_cc`/`connecting_cc` = live `vpnutil list` derivation; precedence top→bottom,
first match wins — mirrors today's override order at `plugins/vpn.sh:28,30`, busy still wins over
everything):

| # | Condition | Colour | Label |
|---|---|---|---|
| 1 | this icon is the click-lock **owner** (Q7) | YELLOW | `…` |
| 2 | `MY_CC != country` (not selected) | GREY | own fixed text (BE/SN) |
| 3 | `MY_CC == country` AND refresh-needed flag set | **MAGENTA** (proposed, open) | own fixed text |
| 4 | `MY_CC == country` AND `MY_CC == conn_cc` | PINK (red) | own fixed text |
| 5 | `MY_CC == country` AND `MY_CC == connecting_cc` | YELLOW (open decision above) | own fixed text |
| 6 | `MY_CC == country`, none of the above (off / disconnected / failed) | ORANGE | own fixed text |

Row 2 is **unconditional** on this icon's OWN live vpnutil status — per the user's literal words
("the one NOT in use = grey", no exception) — so the non-selected icon never needs its own
`vpnutil` sub-query at all, simplifying the derivation (matches B's Q1 pseudocode exactly, which
I received independently and it agrees).

**Refresh-needed is a single GLOBAL flag with no country payload** (`docs/vpn/guide-
nordvpn-native.md:23`, confirmed by B's Q5/Q8 code trace: `nord.sh:92` is a bare `touch`, no cc
written). By convention it can only describe the **active/selected** icon (row 3 above) since
failures only occur while ATTEMPTING a connect to the saved target — never the inactive icon.
Cross-reference: B's report proposes an OPTIONAL future hardening (retag the flag's content from
boolean-touch to the failing cc, `nord.sh:92` + `nord-connect.sh:96`) for precise
failure-attribution, explicitly deferred as "ship zero-change first" — I agree zero-change is
sufficient for the stated spec (which only asks for a busy indicator, not a failure-attribution
indicator); row 3 above works correctly as-is with the flag exactly as it exists today.

**Minor simplification worth stating plainly:** in the new design, each item's **label content is
near-static** — it is one of exactly 2 strings ever (its own fixed "BE"/"SN", or "…" while busy).
Unlike the old design (where the label used to carry the dynamically-derived connected country's
code), nothing about the STATE MACHINE drives label TEXT anymore except the busy override — the
entire rest of the redesign is purely about `label.color`. This is why Q4's dynamic-padding branch
disappears entirely (padding only ever depended on whether the label was drawn, which is now
always true).

---

## Q9 — neither-BE-nor-SN case

**Falls out of the state table for free — no special case needed.** If `country` is
fr/vn/us/my (or a hand-started 3rd config is Connected per B's Q1 case-c), then for BOTH icons
`MY_CC != country` → row 2 → **both render GREY**. This is the literal, least-surprising
consequence of the user's own rule ("not in use = grey") applied verbatim to both fixed slots —
requires no extra plugin logic beyond the existing `country`-file read already needed for the
core design. **Info needed: just `$CFG_DIR/country`'s content** (already being read for the
core derivation, nothing additional).

**Gotcha worth flagging prominently (own finding, confirmed via live `vpnutil list`):** the
displayed label is the literal string **"SN"**, but `$CFG_DIR/country`/`vpnutil` config names use
**"sg"** (`Nord-SG`, confirmed live) — never "sn" anywhere in any state file or config name. A
naive `[ "$COUNTRY" = "sn" ]` comparison would NEVER match, permanently misrendering the Singapore
icon as "not selected" even when Singapore genuinely is active. The `$NAME`→code lookup table in
Q5 (`vpn_sn` → code `sg`) is exactly the guard against this — flagging it here too since it's the
single easiest implementation mistake to make silently.

I did not additionally propose any extra affordance (tooltip, 3rd visual state, etc.) for the
neither-case beyond both-grey — the user's fixed 2-icon design deliberately has no room for a 3rd
country's identity, and both-grey is already an honest, correctly-derived signal ("neither of my
two shortcuts is active right now"). Not flagging as an open decision — fairly clear-cut given the
spec's own words, but noting B independently flagged the SAME fallback in their report (their
Q1/Q9 "known product-level gap, not a bug" section) as something the human should knowingly
accept, which I'd endorse rather than re-litigate.

---

## Q10 — performance-mode.sh exact replacement

Confirmed via full-file read: **only** lines 8, 17, 54, 72 mention `vpn`; nothing else in the
file or in `aerospace.toml`'s startup line needs touching (confirmed zero `vpn` hits in
`aerospace.toml` and `lib-paths.sh` via grep, see Q2).

**OFF-restore block** (`configs/aerospace/performance-mode.sh:51-60`) — replace line 54:
```
# before:
             --set vpn      drawing=on update_freq=30 \
# after:
             --set vpn_be   drawing=on update_freq=30 \
             --set vpn_sn   drawing=on update_freq=30 \
```
(assumes the Q6-recommended symmetric-both-poll design — both restored to 30. If the human
instead picks Q6's rejected "single driver" alternative, only the driver item's line is restored
to 30; the passive sibling's `update_freq` stays 0 in BOTH branches, never touched here, only its
`drawing` would still need toggling on/off with the rest — flagging this delta so it isn't missed
if that alternative is chosen instead.)

**ON-minimal block** (`configs/aerospace/performance-mode.sh:67-78`) — replace line 72:
```
# before:
             --set vpn      drawing=off update_freq=0 \
# after:
             --set vpn_be   drawing=off update_freq=0 \
             --set vpn_sn   drawing=off update_freq=0 \
```

**Comment updates** (prose only, no logic): line 8 `"...connectivity (vpn, wifi, ethernet)
divisions..."` → `"...connectivity (vpn_be, vpn_sn, wifi, ethernet) divisions..."`; line 17
`"...(battery 60, vpn 30, ethernet 30, wifi 30, cpu 5, ram 5)..."` → `"...(battery 60, vpn_be 30,
vpn_sn 30, ethernet 30, wifi 30, cpu 5, ram 5)..."`.

**Nothing else in this file changes:** the bracket-level lines (`--set resources ...`, `--set
connectivity background.drawing=... background.shadow.drawing=...`, lines 57-58/75-76) target the
BRACKET name `connectivity`, which is unchanged regardless of its members — zero edit needed
there. `spacer0`/`spacer1` lines untouched (unrelated to vpn). **Confirmed: `aerospace.toml`'s
`after-startup-command` needs zero changes** — it only invokes `performance-mode.sh` by path
(never names `vpn` inline, confirmed by grep, Q2) and `lib-paths.sh` (shared constants) has no
`vpn` references either.

---

# RECOMMENDED CONCRETE SHAPE (consolidated)

**Files touched (implementation, NOT done by me — read-only):**
- `configs/sketchybar/items/vpn.sh` — rewrite in place (same filename): `vpn_base=(...)` shared
  array + `vpn_sn=("${vpn_base[@]}" ...)` / `vpn_be=("${vpn_base[@]}" ...)`; ONE `--add event
  vpn_change`; two `--add item ... right` (vpn_sn first = rightmost, per Q1) + two `--set` + two
  `--subscribe ... system_woke wifi_change vpn_change`.
- `configs/sketchybar/plugins/vpn.sh` — rewrite in place: `$NAME`→{cc,label} 2-line lookup (Q5);
  one `vpnutil list` fetch; derive both icons' full state per Q8's table (reading `$CFG_DIR/
  country` newly — confirmed new plumbing per B); one batched `--set vpn_be ... --set vpn_sn
  ...` paint per invocation (Q6); busy-ownership check via `$CLICK_LOCK/owner` (Q7); never calls
  `nord status` (side effects, per B's Q6).
- `configs/sketchybar/plugins/vpn_click.sh` — rewrite in place: `$NAME`→cc lookup; `--set
  "$NAME"` (not hardcoded `vpn`); write `$CLICK_LOCK/owner` after the winning `mkdir`; decide
  `nord <mycode>` (grey-icon path) vs `nord toggle` (active-icon path) by comparing `$NAME`'s cc
  against `$CFG_DIR/country`; cleanup sites (`rmdir`→`rm -rf`, Q7 gotcha) at both the stale-steal
  branch and the EXIT trap.
- `configs/sketchybar/sketchybarrc` — comment + bracket-member-list edit only (Q1); source lines
  unchanged if single-file item approach is used.
- `configs/aerospace/performance-mode.sh` — 2 comment lines + 2 `--set` lines each become 2
  lines (Q10).
- No changes needed: `configs/aerospace/aerospace.toml`, `configs/aerospace/lib-paths.sh`,
  `configs/sketchybar/icons.sh`, `configs/sketchybar/theme.sh`, `configs/sketchybar/colors.sh`
  (only reads an existing/new token), `configs/sketchybar/plugins/wifi_click.sh` (comment-only
  tweak, no logic), `scripts/vpn/*` (per B's verdict: zero CLI changes required).

---

# OPEN DECISIONS (explicit list for the human — not resolved here)

1. **Visual L→R order**: vpn_be-then-vpn_sn (recommended, alphabetical) vs the reverse (Q1).
   Cosmetic, trivially flippable.
2. **Item file layout**: one `items/vpn.sh` with two arrays (recommended) vs split
   `vpn_be.sh`/`vpn_sn.sh` (Q1). Affects sketchybarrc churn size only.
3. **Label font size**: `$FONT:Bold:14.0` (recommended, matches other primary-text items) vs
   keep `Semibold:10.0` (smaller/old) vs global default `Bold:12.0` (Q3). Pure aesthetics.
4. **Polling strategy**: both items independently poll, shared script paints both (recommended,
   Q6) vs single "driver" item + passive sibling (rejected, staleness risk) vs both poll AND each
   paints only itself (simpler, tiny consistency-race risk, essentially harmless).
5. **Refresh-needed colour**: `MAGENTA` (recommended) vs `BLUE`/`GREEN` vs others (Q8). Purely a
   free-token pick.
6. **Connecting (YELLOW) survives as distinct state** (recommended, gives real feedback during
   silent launchd auto-reconnects) **vs folds into ORANGE** (simpler palette) — Q8, explicitly
   not silently picked.
7. **Owner-file fallback**: if unreadable, both icons paint normal (recommended, simpler) vs both
   show busy (old blanket behaviour, conservative) — Q7, very minor.
8. **(Shared with B) Refresh-needed cc-tagging** — B's optional hardening
   (`nord.sh:92`+`nord-connect.sh:96`, boolean→cc-tag) would let a FAILED grey-icon-click
   correctly blame the icon that was actually clicked instead of (today's shape) the old active
   icon going orange while the failed target reverts to plain grey. Both of us independently land
   on "ship zero-change first" — flagging jointly, not resolving.
9. **(Shared with B) Fallback rendering for `country` ∉ {be, sg}** — both-grey (falls out for
   free per Q9) — confirmed acceptable-by-derivation, but the human should knowingly accept it as
   "no 3rd-country affordance in a 2-icon bar" (B's "known product-level gap, not a bug").
10. **(Shared with B) Boot-reset always picks SN as active** — pure consequence of the existing
    `nord-connect.sh` boot→Singapore design (unrelated to this rework, pre-existing), surfaced
    again here because it now visibly picks one of exactly 2 named icons every reboot. Not
    decided by either researcher.
11. **(New, cross-cutting) sketchybar's 60s hard script-timeout** on `click_script`
    (`sketchybar-events(5):51`) vs B's worst-case `nord <cc>` timing (~176-182s pathological,
    per B's Q2) — a SIGKILL past 60s bypasses the bash EXIT trap, leaving the click lock (+ new
    owner file) stale until the 200s steal window. Pre-existing risk, surfaced by this rework
    touching the exact file; not fixed here, flagging for joint human/B decision on whether it's
    worth hardening (e.g., detaching `nord.sh` from the click script's own lifetime).

---

# DOCS REQUIRING EDIT (project rule: BOTH must land in the same change as any behaviour change)

**`_index.md`** (exact bullets):
- Line 39, `configs/sketchybar/items/*.sh` bullet — currently says "8 SOURCED items" (spaces,
  calendar, battery, ram, cpu, **vpn**, ethernet, wifi) and describes vpn as one state-driven
  item (red+country label / yellow / orange / grey) — becomes 9 items, vpn's clause splits into
  two-icon language (grey=not-selected, red=selected+connected, orange=selected+disconnected,
  refresh-needed colour per Q8's resolved decision).
- Line 40, `configs/sketchybar/plugins/*.sh` bullet — "the per-item updaters (ethernet, ram, cpu,
  **vpn**, battery) and `vpn_click.sh`" + the parenthetical `vpn_click.sh` description ("busy
  feedback + click lock → `nord toggle`") needs the new switch-vs-toggle branching (grey-click =
  `nord <cc>`, active-click = `nord toggle`) and the owner-token mechanism (Q7) mentioned.

**`docs/vpn/guide-nordvpn-native.md`** (exact sections):
- "Components" table, "Bar item" row (line 19) — single-icon description ("red+CC label=connected,
  yellow=connecting, grey=off, orange=refresh needed... Click = `vpn_click.sh`... runs `nord.sh
  toggle`") → two-icon description (grey=not-selected, red/orange=selected connected/disconnected,
  new refresh-needed colour, grey-click=`nord <cc>` vs active-click=`nord toggle`).
- "Stale pins / dead server" section (line 65, "...the bar's VPN icon turns orange...") — must
  reflect the NEW colour chosen for refresh-needed (Q8 decision), since orange is reassigned.
- "Verified test matrix" (line 78, "...bar states red/orange/grey + CC label...") — update once
  re-verified against the new 2-icon behaviour.

**Additional doc obligation found beyond the two named in the assignment (flagging since project
rule requires the AFFECTED guide, not just the two pre-named ones, to stay in sync) —
`docs/window-manager/guide-window-manager.md`:**
- Line 109/111 — performance-mode ON/OFF description lists `"connectivity (vpn, wifi,
  ethernet)"` and the restore-freq table `"(battery 60, vpn 30, ethernet 30, wifi 30, cpu 5, ram
  5)"` — same two-line-becomes-two-item edit as `_index.md`/`performance-mode.sh` (Q10).
- Line 151 — `sketchybarrc` bullet's item-source list ("...spaces, calendar, ram, cpu, battery,
  **vpn**, wifi, ethernet...") — becomes 9 names.
- Line 181 — icons.sh categories list mentions "vpn" as a category name — harmless/unaffected
  (icons.sh itself doesn't change, Q2), but worth a glance since it enumerates categories, not
  live wiring — low priority.
- Line 187 — "Active items" list ("...vpn.sh, wifi.sh, ethernet.sh (8 live...)") — becomes 9 live
  items.
- Line 190 — state-driven items description ("...vpn = NordVPN app glyph tinted by
  connection...") — becomes the two-icon grey/red/orange description (no glyph anymore, per Q3).
- Line 191 — poller-freq table ("...vpn 30, ethernet 30...") — same split as `_index.md`/
  `performance-mode.sh`.

This file was NOT named in the assignment's explicit "must update" list but directly documents
`items/vpn.sh` + `performance-mode.sh`'s exact item names/freqs — it WILL go stale without a
matching edit, per the project's own rule (CLAUDE.md: "update BOTH `_index.md` AND the affected
`docs/` guide in the same change").

---

# UNKNOWNS (explicitly marked, not guessed)

- Whether a duplicate `sketchybar --add event vpn_change` (if the split-file item layout is
  chosen and BOTH files naively re-added it) is idempotent/harmless or errors/duplicates —
  untested; moot under the recommended single-file design (event added exactly once regardless).
- Whether sketchybar's process-group signal delivery on its 60s hard-timeout also kills a
  still-running `nord.sh` child of a killed `click_script`, or leaves it orphaned — UNKNOWN,
  flagged in the open-decisions list above rather than asserted either way.
- Exact visual pixel-perceptual distance between candidate colour tokens at actual rendered
  16×16-ish icon size on a real display (I can only reason from decoded hex/RGB values, not a
  rendered screenshot) — recommendation (MAGENTA) is a reasoned pick, not a pixel-measured one.
