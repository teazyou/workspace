# 08 — Review round 2 (adversarial, single pass) — VERDICT: **FAIL (1 finding, doc-only, one-clause fix)**

Date 2026-07-30. Reviewer method: read the 7 real diffs + `06-plan-dot.md`/`07-acceptance-dot.md`,
live `sketchybar --query`, stubbed non-mutating simulations (stub `CFG_DIR` + stub `vpnutil`, stub
`NORD`), `git diff/status/log/reflog` only. **Zero writes to any repo file. Zero git ops. Zero VPN
mutation** (`country` mtime 02:00:49, `enabled` mtime 03:59:32 — both untouched by this session).

**Implementation is functionally correct and complete.** The single blocking finding is one stale
clause in `_index.md`; everything else in the 50-item checklist passes on substance.

---

## FINDING 1 — `_index.md:40` still describes the click tree by the SUPERSEDED colour rule

`_index.md` plugins bullet, `vpn_click.sh` clause, verbatim:

> … → **`nord <cc>` on the grey icon**, `nord toggle` on **the selected one**

Before this change "grey" uniquely meant *not selected* (selected-but-off was ORANGE). After it,
**both** icons are grey whenever the tunnel is down — so "the grey icon" identifies nothing, and the
sentence tells a reader that clicking either grey icon dials it. Wrong for the selected one (that is
`nord toggle`). The dot is the only discriminator now — which is the entire point of the change.

- The SIBLING bullet (`_index.md:39`, items) WAS correctly rewritten to *dot-less* / *dotted*.
- Root cause: plan `06-plan-dot.md` §3.6 prescribed only ONE `_index.md:40` edit (the `vpn.sh`
  parenthetical) and never touched the `vpn_click.sh` clause. Implementer followed the plan verbatim
  — planner omission, not implementer deviation.
- Violates the project hard rule (index must be current in the SAME change) and the stated intent of
  checklist item 38 ("No stale colour claims anywhere"). Checklist item 36 as literally worded does
  pass, which is why it slipped QA.
- Fix = one clause: `grey icon` → `dot-less icon`, `the selected one` → `the dotted (selected) one`.
- Nothing else stale: `grep -rn 'grey icon|click grey|the grey' docs/ _index.md` → this line only.
  `_index.md:26` prose ("the sketchybar vpn item/plugin") is the sanctioned area-level exception.

---

## A. Mechanism / geometry / hygiene — PASS (3 literal-wording notes)

| # | result |
|---|---|
| 1 | theme.sh: exactly 4 exports (`SEL_DOT_GLYPH="●"`, `SIZE=12.0`, `ADVANCE=6`, `Y_OFFSET=-9`) + comment stating negative-y=DOWN, the `pad_L+advance+pad_R==0` identity, and hide-by-COLOUR-never-`icon.drawing`. `git diff` is append-only (lines 57-76, nothing above changed). **PASS** |
| 2 | `DOT_GLYPH/DOT_FONT/DOT_COLOR` only in `plugins/aerospace.sh` (51-53, 229). No collision. **PASS** |
| 3 | pads derived: `VPN_ELEMENT_W=$((ELEMENT_GAP+18+ELEMENT_GAP))`, `PAD_L=$(((W-SEL_DOT_ADVANCE)/2))`, `PAD_R=$((-(PAD_L+SEL_DOT_ADVANCE)))`. `grep '●' items/vpn.sh` → rc=1. Literal `18` commented verified-live. **PASS** — *note: `12`/`-18` do appear, but only as trailing `#` annotations on the deriving lines; zero magic numbers in code.* |
| 4 | `grep -n '0x'` over the 3 vpn files → **0 hits each**. `git diff -- colors.sh` → empty. **PASS** |
| 5 | one `icon.drawing` ASSIGNMENT, `=on`. `grep 'icon.drawing\|label.drawing\|padding'` over both plugins → rc=1. **PASS** — *note: grep returns 2 lines because line 24 is prose ("never icon.drawing: no dot = icon.color=$TRANSPARENT"); implementer's disclosure #1 confirmed truthful.* |
| 6 | both items: `{"iv":"●","if":"JetBrainsMono Nerd Font:Bold:12.00","iy":-9,"ipl":12,"ipr":-18,"id":"on"}` — exact. **PASS** |
| 7 | identity **re-derived live**: pads 0/0 → `vpn_be` 30→**36** (advance = 6 exactly), `connectivity` 85→91; restore 12/-18 → 30 / 85. `12+6-18=0`. **PASS** |
| 8 | `label.font=…Bold:14.00`, values `BE`/`SN`, `label.drawing=on`. **PASS** |

## B. Truth table by stubbed simulation — PASS (11/11 rows exact)

Stub confirmed rewritten (`CFG_DIR`/`VPNUTIL` → `$D/stub`). No `nord`, no `vpnutil start|stop`.

| # | scenario | measured (label / label.color / icon.color) |
|---|---|---|
| 10 | off, country=be | `BE grey/grey` · `SN grey/0x0` — **no orange survived** |
| 11 | off, country=sg | `BE grey/0x0` · `SN grey/grey` |
| 12 | connected BE | `BE 0xffaa2222/0xffaa2222` · `SN grey/0x0` |
| 13 | connected SG | `BE grey/0x0` · `SN 0xffaa2222/0xffaa2222` |
| 14 | connecting sg | `BE grey/0x0` · `SN 0xffeed49f/0xffeed49f` |
| 15 | refresh+connected be | `BE 0xffc6a0f6/0xffc6a0f6` · `SN grey/0x0` (magenta beats red) |
| 16 | country=fr | both grey, both `0x0` |
| 17 | country file missing | == row 11 (fallback sg) |
| 18 | `vpnutil` output "not json" | == row 10, no crash, labels intact |
| 19a | owner=vpn_be (selected) | `BE …/yellow/yellow` · `SN grey/0x0` |
| 19b | owner=vpn_sn (NOT selected) | `SN …/yellow/**0x0**` · `BE BE/grey/**grey**` (BE keeps its dot) |
| 20 | backdated lock | ignored → == row 10, no stuck `…` |
| 21 | cleanup | lock dir gone, stub+test files gone, real painter re-run; `country=be`, `enabled=0`, all 6 Disconnected, no `refresh-needed` — **identical to pre-review** |

## C. Layout neutrality — PASS

- 22 rects byte-identical across dot-red / dot-hidden / restored: `vpn_be` **30**, `vpn_sn` **31**,
  `connectivity` **85** (wifi glyph 22) — and **83** after `--reload` (wifi glyph 20); both values
  are the documented healthy pair.
- 23 `vpn_sn.x − vpn_be.x = 2252−2222 = 30` ✓; `connectivity.x == wifi.x` (2202) ✓; order
  wifi 2202 ≤ ethernet 2222 (w=0, unplugged) ≤ vpn_be 2222 ≤ vpn_sn 2252 ✓.
- 24 item paddings `[0,0]`, label paddings `[6,6]` both items; `grep padding items/vpn.sh` → tokens only.
- 25 **OPTIONAL pixel probe: COULD NOT BE RUN — see residual risk 1.** Reasoned equivalently instead:
  bracket `background.height=32`, bracket `y_offset=2`, bar height 58 @ y −6 ⇒ pill ≈ screen rows 5-37;
  label 14 pt @ `y_offset=0` ⇒ ink ≈ rows 15-24; dot 12 pt @ `y_offset=-9` ⇒ ink centre ≈ row 29,
  ink ≈ rows 27-31. Horizontally: icon starts at `element_left+12`, inks 5 px ⇒ +13…+17, element
  centre 15 ⇒ **centred**; label ink +6…+24 ⇒ dot overlaps the label's x-span but sits 9 px lower ⇒
  no collision. All three independently reproduce the planner's measured 28-32 / 15-24 / 5-34 within
  1-3 px. Geometry corroborates "small centred dot below the text", inside the pill.

## D. No round-1 regression — PASS

- 26 stub click log = exactly `toggle` then `sg` (country=be). Real `nord.sh` never ran; `country`/
  `enabled`/`vpnutil list` unchanged after.
- 27 ONE `sketchybar --set "$NAME"` (grep -c = 1) carrying `label=` + `label.color=` + `icon.color="$DOT"`;
  `DOT=$YELLOW` gated on `[ "$ACTION" = toggle ]`, else `$TRANSPARENT`. No hardcoded item name.
- 28 `CLICK_LOCK="/tmp/nordvpn-native.click"` literal + identical in BOTH plugins (no `$NAME`/`$MY_CC`
  interpolation); `release()` at all 3 sites (steal / EXIT trap / pre-settle); no `rm -rf`;
  `CLICK_STALE=200` in both.
- 29 `NAME=vpn` → exit 0, no log line; `NAME` unset → exit 0, no log line. `add event vpn_change` = 1.
  Two `--subscribe … system_woke wifi_change vpn_change`. Exactly one `"$VPNUTIL" list`. Exactly one
  `sketchybar` invocation in the poller (line 70, batched `ARGS`). `grep nord plugins/vpn.sh` →
  comments/paths only.
- 30 bracket `["vpn_be","vpn_sn","wifi","ethernet"]`; `--query vpn` → not found; `git diff --stat` on
  sketchybarrc + performance-mode.sh + wifi_click.sh → **empty**. No new item ⇒ no enumeration site moved.
- 31 perf-mode round-trip under `set -euo pipefail`: run1 exit 0 → `drawing=off/freq=0` + state "on";
  run2 exit 0 → `drawing=on/freq=30`, `icon.color=0xff939ab7` (real colour restored by its
  `sketchybar --update`), state file removed. Ended exactly as found (absent). Bracket + rects intact.
  Cross-check: `performance-mode.sh` touches only item-level `drawing`/`update_freq` — never `icon.*`
  — so label and dot hide/show together, as documented.
- 32 scratch clean: `ls sprint/vpn-rework` = the numbered `.md` docs only (+ this 08 file).
- extra: ORANGE branch fully dead — remaining `ORANGE` refs are `colors.sh:10` (definition kept, no
  palette change), `aerospace_mode.sh:21` + `brew.sh:10` (both confirmed NOT sourced by sketchybarrc),
  `items/spaces.sh:6` (comment). `grep -rni cc7b6e` outside colors.sh → rc=1. Nothing depended on it.
- extra: no `"sn"`/`=sn` literal in either plugin (rc=1); `SEL_DOT_SIZE=12.0` (a float) is used only
  in `icon.font`, never inside `$(( ))` — no arithmetic breakage.

## E. Docs + index sync — PASS except FINDING 1

- 33 vpn-guide Bar-item row: two channels, colour legend grey/red/yellow/magenta, DOT = selected
  country + always that label's colour + exactly one at a time, icon-slot mechanism + negative
  `icon.padding_right` + zero layout width + `icon.color=$TRANSPARENT` + theme.sh `SEL_DOT_*`; click
  split dot-less→`nord <cc>` / dotted→`nord toggle`; busy `…`, 200 s stale-steal, shared lock + `owner`
  all preserved verbatim. **PASS**
- 34 `grep -i orange` in the vpn guide → 1 hit, the test-matrix line, explicitly marked superseded.
  `refresh-needed` state-dir line (23) and Stale-pins paragraph (65) still say **magenta**. **PASS**
- 35 BE/SN caveat (75) now adds "**and no dot is drawn at all** — the 'nothing selected on the bar'
  look is the tell". **PASS**
- 36 `_index.md:36` theme.sh bullet lists `SEL_DOT_*` + icon-slot/zero-cost wording ✓; `:39` items
  bullet = two channels, no orange ✓; `:40` plugins bullet = "label colour = tunnel state, icon slot =
  the selection dot" ✓. **PASS as worded** — but see FINDING 1 for the untouched click clause on the
  same line.
- 37 WM guide 163 token list has all four `SEL_DOT_*` ✓; **new** line 164 "SELECTION DOT lesson"
  (backgrounds can't be shrunk to a dot — `label.background.padding_*` no width effect, item
  `background.padding_*` only translates; hence icon slot + negative `icon.padding_right`; show/hide by
  COLOUR never `icon.drawing`) ✓; line 191 state-driven rewritten ✓. **PASS**
- 38 `grep -rni orange docs/ _index.md` → 2 hits: the superseded test-matrix line + WM 191's negation
  "no orange anywhere" (a negation, not a live-colour claim — implementer's disclosure #2 truthful).
  `grep 'selected + not connected'` → rc=1. **PASS on orange; FAILS on intent via FINDING 1.**
- 39 `grep -rn SEL_DOT docs/ _index.md` → hits in all three (vpn guide 19, WM 163/164/191, `_index` 36/39/40). **PASS**

## F. Guardrails — PASS

- 40 changed set = exactly the 7 planned tracked files + `configs/dot-claude` (**pointer NOT moved** —
  same sha `f650322`, only `-dirty`, pre-existing) + 2 untracked sprint docs. Nothing else.
- 41 empty diffs confirmed: `scripts/vpn/`, `zsh/alias/vpn.zsh`, `configs/nordvpn/`, `colors.sh`,
  `icons.sh`, `sketchybarrc`, all of `configs/aerospace/`, `wifi_click.sh`.
- 42 `git diff --cached` empty. HEAD = `db1f3df` "checkpoint" (the hourly LaunchAgent, committed
  04:00:03 — before the 04:35 edits). `git log --oneline -5` = only `checkpoint` + pre-existing
  subjects. `git reflog -5` = plain `commit:` entries only, no amend/reset/checkout/stash. **No git
  write by implementer or reviewer.**
- 43 `git diff --summary` empty (no mode/rename churn). No `.shellcheckrc`/`.editorconfig`/prettier.
  All 4 code files `-rwxr-xr-x` + "Bourne-Again shell script, UTF-8". `●` = `e2 97 8f`, `…` = `e2 80 a6`
  (verified against the bytes actually inside theme.sh / plugins/vpn.sh). Full diffs reviewed
  line-by-line: intended lines only, no whitespace reflow.
- 44 no `osascript` / `display notification` in any of the 4 changed config files (rc=1).
- 45 no `vpnutil start|stop`, no `nord.sh` in the poller (rc=1); `vpn_click.sh` is the only `nord.sh`
  caller. Post-review `country=be`, `enabled=0`, all 6 Disconnected, `refresh-needed` absent.
- 46 only out-of-repo write = the transient `/tmp/nordvpn-native.click` (§B item 19), removed in 21;
  all reviewer scratch confined to `sprint/vpn-rework/` and deleted.
- 47 `sketchybar --reload` → rc 0, no error output; both items + bracket paint; full item list intact
  (30 items); `sketchybarrc:35 display=main` byte-unchanged (`git diff` on sketchybarrc empty — this
  build's `--query bar` still exposes no `display` key, round-1 finding re-confirmed).
- 48 all 7 round-1 supersessions read as `06-plan-dot.md` §B states (4 → `on`/`●`; 10 → derived pads +
  documented `18`; 15 → precedence ends GREY; 16 → `icon.color` added, still no `*drawing*`/`*padding*`;
  28 → one `--set`; 33 → verified by simulation rows 10/12; 37 → see item 38). Items 26-31 confirm no
  other round-1 item silently broke.
- 49 **USER-VISIBLE SPEC: satisfied.** disconnected ⇒ both labels grey, dot only under the selected
  one and grey (row 10/11); connected ⇒ selected label red + red dot, other grey with no dot (row
  12/13). No orange anywhere. R1-vs-R2 semantics = product question, not a defect (one-line
  alternative documented in `06-plan-dot.md` §1).
- 50 OPTIONAL live click — correctly NOT run (VPN-mutating, user-performed).

---

## Residual risks / non-blocking notes

1. **Pixel probe unverifiable from this session (honest).** `screencapture` from the reviewer's
   sandboxed process returns desktop-only content — proven: a full `-R0,0,2560,60` top-strip capture
   has `max_channel=42` and **0 pixels > 120** across all 153 600 (bar text would be ~180+). No
   Screen Recording permission ⇒ the bar window is excluded. The "it looks like a small centred dot"
   claim therefore rests on the planner's earlier capture + the coordinate reasoning in C25 above,
   not on independent reviewer ink measurement. Item 25 is OPTIONAL, so not a failure — but the
   visual is the one thing neither QA nor review re-measured.
2. **No dot for ~10-30 s after `sketchybar --reload`** (measured: dot appeared between t=8 s and
   t=12 s). `items/vpn.sh` seeds `icon.color=$TRANSPARENT` and the real state only lands on the first
   poll — so the bar transiently shows the exact "no dot anywhere" look the docs define as the
   fr/my/us/vn tell. Documented in the header ("Seeded dot-less"); invisible at AeroSpace startup
   (performance mode ON hides the division). Same class as round 1's seeded-grey labels. Cosmetic.
3. `vpn_sn` is 31 px so its dot sits 0.5 px left of that element's true centre (same constant used
   for both by design). HiDPI/Retina re-rasterisation untested. Dot ink 5 px is a taste call, one
   token (`SEL_DOT_SIZE`, + `SEL_DOT_ADVANCE` must move with it).
4. **VPN state delta vs `05-qa-round1.md` is NOT the implementer's.** Round-1 baseline was
   `enabled=1` / `Nord-BE Connected`; today it is `enabled=0` / all Disconnected. mtime proof:
   `enabled` last written **03:59:32**, i.e. before the round-2 planner (04:28) and long before the
   implementer's edits (04:35-04:36); `country` last written 02:00:49. Consistent with the user
   performing round-1's optional live-click test. Nothing in this session or the last touched it.
5. Pre-existing, out of scope: `plugins/vpn.sh:4` prepends `/opt/homebrew/bin` "for jq", but
   `/opt/homebrew/bin/jq` does not exist on this machine — `jq` resolves from `/usr/bin/jq`
   (Apple-shipped). Harmless, unchanged by this work, worth knowing if PATH is ever trimmed.

## Verdict

Code: **correct, minimal, complete** — 1 colour-branch swap + 1 orthogonal `icon.color` channel +
4 theme tokens + derived pads. Zero layout cost proven live. All 11 truth-table rows exact. Zero
regressions. Zero git ops. Zero VPN mutation. Docs 6/7 clauses updated in the same change.

Blocking: **FINDING 1** — one stale clause in `_index.md:40`. Fix it, then this ships.
