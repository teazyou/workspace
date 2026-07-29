# 05 — QA round 1 (adversarial gate) — VERDICT: **PASS**

Date 2026-07-30. Method: read real files + live `sketchybar --query` / `vpnutil list` / `git diff`, plus two non-mutating simulations (stubbed `nord`, stubbed `vpnutil`+CFG_DIR). **No VPN state changed** — baseline `country=be`, `enabled=1`, `Nord-BE Connected`, no `refresh-needed` — identical before and after QA.

## A. Items (1-10) — PASS
- 1 `sketchybar --query vpn` → `[!] item 'vpn' not found`. `grep -rn '\bvpn\b'` on sketchybarrc + performance-mode.sh → only `vpn.sh` (source line + comment).
- 2-5 both items exist; `label.value` = literal `BE` / `SN` (not SG); `icon.drawing=off`, `label.drawing=on`, `label.font=JetBrainsMono Nerd Font:Bold:14.00`, `icon.value=""` (no `:nord_vpn:`); script/click_script → `plugins/vpn.sh` / `plugins/vpn_click.sh`, `update_freq=30`.
- 6 two `--subscribe` lines, each `system_woke wifi_change vpn_change`; `add event vpn_change` count = 1.
- 7 `connectivity.bracket = ["vpn_be","vpn_sn","wifi","ethernet"]`, no `vpn`.
- 8 x-origins: wifi 2172 → ethernet 2194 (w=0, unplugged) → vpn_be 2194 → vpn_sn 2224. Non-decreasing, vpn_sn largest.
- 9 `padding_left/right = [0,0]` both.
- 10 tokens only: `vpn_sn` L=`$ELEMENT_GAP` R=`$DIVISION_PAD`; `vpn_be` L/R=`$ELEMENT_GAP`. No bare numbers.

## B. Plugin logic (11-16) — PASS
- 11 `CFG_DIR/country`, fallback `sg`; 12 no `"sn"`/`=sn` literal in either plugin (rc=1); 13 no `nord` invocation in the poller (only comments/paths); 14 exactly one `"$VPNUTIL" list`, final call carries `--set vpn_be` and `--set vpn_sn` (built in `ARGS`, one `sketchybar` call); 15 precedence exactly busy → grey → magenta → red → yellow → orange; 16 only `label=` + `label.color=` set at runtime.

## C. Live rendering (17-22) — PASS
- 17 baseline paints `vpn_be BE/0xffaa2222` + `vpn_sn SN/0xff939ab7` = truth table.
- 18 repaint invoked as `vpn_be`, as `vpn_sn`, and with **no** `$NAME` → identical output (painter is name-agnostic).
- 19 owner=vpn_be → `vpn_be …/yellow`, `vpn_sn SN/grey`; owner swapped → roles invert exactly.
- 20 click while lock held: 0.01 s, exit 0, owner file untouched, `country`/`vpnutil` unchanged.
- 21 backdated lock → painter renders real labels (no stuck `…`); the click script correctly **steals** the stale lock (stub ran, lock released).
- 22 lock dir removed; `/tmp/nordvpn-native.click` absent.
- **Extra (beyond checklist), stubbed CFG_DIR+vpnutil:** country=fr → BOTH grey (documented caveat); sg Connecting → SN yellow; sg nothing connected → SN orange; sg + refresh-needed → SN magenta (beats connected); missing `country` file → defaults sg; broken vpnutil output → selected orange, other grey. All correct.

## D. Click decision tree (23-29) — PASS
- 23 stub log with `country=be` = exactly `toggle` (vpn_be) then `sg` (vpn_sn). Real `nord.sh` never ran; `vpnutil list` + `country` + `enabled` unchanged.
- 24 `NAME=vpn` → exit 0, no log line; `$NAME` unset → exit 0, no log line.
- 25 lock gone after each run. 26 no `rm -rf`; `release()` used at all 3 sites (steal / EXIT trap / pre-settle). 27 `CLICK_LOCK="/tmp/nordvpn-native.click"` literal + identical in both plugins — no per-icon lock. 28 exactly one `sketchybar --set "$NAME"`, no hardcoded name. 29 scratch deleted (sprint dir = the 5 planning docs only).
- `nord.sh` cross-check: `cc_of` accepts `be`/`sg`; `switch` writes `enabled=1` → `stop_all` → `start_cc` → `country` → `bar_refresh`, i.e. grey-click really is "switch **and** turn on".

## E. Performance mode (30-31) — PASS
4 `--set` lines (vpn_be+vpn_sn on both branches), no bare `--set vpn `. Round-tripped: run1 ON → drawing=off/freq=0 + state "on"; run2 OFF → drawing=on/freq=30 + state file removed. Both exit 0. Ended at the original baseline (state file absent, full bar, bracket + order intact).

## F. Live click (32-35) — NOT RUN (optional, VPN-mutating, user-performed). Non-blocking.

## G. Docs/index (36-42) — PASS
Bar-item row rewritten (2 items, 5 colours, grey→`nord <cc>` vs selected→`nord toggle`, shared lock + `owner`); state-dir line and stale-pins paragraph now say **magenta**; the only remaining "orange" hits are the new meaning + the test-matrix line explicitly marked superseded; both new Caveats bullets present. `_index.md` = 9 SOURCED items with `vpn_be, vpn_sn` + full colour/click description; plugins bullet updated. WM guide lines 109/111/151/187/190/191 all `vpn_be`/`vpn_sn`, "9 live items from 8 files", freq table `vpn_be 30, vpn_sn 30`. Only surviving bare `vpn` = WM guide line 181 (icons.sh *category* list — the sanctioned exception).

## H. Guardrails (43-50) — PASS
- 43 `git diff --stat` empty for scripts/vpn/, zsh/alias/vpn.zsh, configs/nordvpn/, icons.sh, theme.sh, colors.sh, aerospace.toml, lib-paths.sh.
- 44 changed set = exactly the 9 expected files; only untracked path = `sprint/`.
- 45 zero `osascript`/notification hits in any changed file (existing hits live only in the dead spotify.sh/front_app.sh templates + a commented aerospace.toml line — untouched).
- 46 no `.shellcheckrc`/`.editorconfig`/prettier config; `git diff --summary` empty (no mode/rename churn); files still UTF-8 + exec bit `755`; `…` = U+2026 (`e2 80 a6`).
- 47 HEAD still `8e82bc7`, index empty, reflog top 3 unchanged.
- 48 nothing written outside the repo except the transient click lock (removed); scratch confined to `sprint/vpn-rework/`.
- 49 bar healthy: both items + bracket present and painting; `display=main` line in sketchybarrc byte-unchanged. **Checklist-command defect (not an impl defect):** `sketchybar --query bar` on this build exposes no `display` key (keys: blur_radius…y_offset) so `jq -r .display` → `null`; verified equivalently. Implementer's deviation #1 confirmed truthful.
- 50 no `vpnutil start|stop` anywhere under configs/sketchybar.

## Non-blocking notes
1. §F untested — user should click once per icon to confirm end-to-end.
2. `nord <cc>` writes `country` **after** a successful connect (`nord.sh:112`), so a failed grey-icon click leaves the *old* icon selected (turns orange) and the clicked one grey until it succeeds. Pre-existing nord.sh behaviour, unchanged, arguably correct — worth knowing.
3. `_index.md:26` still reads "the sketchybar vpn item/plugin" (singular prose, points at the area not an item name) — covered by the checklist's prose exception; optional polish.
