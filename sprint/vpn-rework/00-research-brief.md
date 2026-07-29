# Research brief — VPN bar rework: 1 icon -> 2 icons (BE / SN)

Scope: research only. **Read-only** — no edits to any config/script, no git, no lint, no
osascript notifications. Scratch notes (if any) only under
`/Users/teazyou/workspace/sprint/vpn-rework/`. Report telegraphic/compressed.

## Target behaviour (user, verbatim)

- Two icons instead of one: **"BE"** and **"SN"** (Belgium, Singapore).
- The one NOT currently in use = **grey**.
- The one currently in use = **red** when connected, **orange** when not connected.
- Click grey icon -> switch to that country AND turn on (= `nord belgium` / `nord singapore`).
- Click active icon -> plain toggle (on<->off).
- While a status change is in flight, that icon's text becomes **"…"**.

## Settled interpretation (do NOT re-litigate; DO flag if code contradicts)

- "currently in use / installed" = currently **SELECTED TARGET COUNTRY** =
  `~/.config/nordvpn-native/country`. All 6 IKEv2 configs are permanently installed by the
  one-approval `.mobileconfig`, so "profile installed" cannot be the meaning.
- Labels are the literal strings `BE` / `SN` (SN, not the ISO `SG`) rendered as **text**, not
  the `:nord_vpn:` sketchybar-app-font glyph.
- Colours from `configs/sketchybar/colors.sh` (`PINK`=red, `ORANGE`, `GREY`, `YELLOW`);
  geometry from `configs/sketchybar/theme.sh` (`DIVISION_PAD`, `ELEMENT_GAP`, `GROUP_GAP`).

## Mandatory pre-reading (both researchers)

`/Users/teazyou/workspace/docs/vpn/guide-nordvpn-native.md` and
`/Users/teazyou/workspace/_index.md` **before** anything else. Note the hard invariants:
single-VPN-slot (never start while another is Connected/Connecting; strict
stop->confirm->start), shared `/tmp/nordvpn-native.lock`, no On-Demand, no polling in the
watcher, `enabled=0` written before stopping, reboot resets to sg.

## Known file inventory (verified, trust it)

| Path | Role now |
|---|---|
| `configs/sketchybar/items/vpn.sh` | single item `vpn`, right side, `:nord_vpn:` glyph, `update_freq=30`, subscribes `system_woke wifi_change vpn_change`, adds the `vpn_change` event |
| `configs/sketchybar/plugins/vpn.sh` | paints colour+CC label from `vpnutil list` JSON; ORANGE (refresh-needed) overrides all; busy look while `/tmp/nordvpn-native.click` exists |
| `configs/sketchybar/plugins/vpn_click.sh` | mkdir click lock (200s stale-steal), instant yellow "…", `nord toggle`, release + `sleep 1` |
| `configs/sketchybar/sketchybarrc` ~L141-155 | right-side source order (right-most sourced first) + `--add bracket connectivity vpn wifi ethernet` |
| `configs/aerospace/performance-mode.sh` ~L54 / ~L72 | hardcodes item name `vpn` (`drawing=on update_freq=30` / `drawing=off update_freq=0`) |
| `scripts/vpn/nord.sh` | the `nord` CLI (switch/on/off/toggle/status/list/refresh/rescue) |
| `scripts/vpn/nord-connect.sh` | LaunchAgent one-shot reconnect + boot reset |
| `~/.config/nordvpn-native/` | `country`, `enabled`, `refresh-needed`, `boot-id`, `servers`, `credentials`, `fail-stamp` |

Live state at brief time: `country=be`, `enabled=1`, no `refresh-needed`.

---

# ASSIGNMENT A — sketchybar / bar side

Goal: everything needed to write the item + plugin + rc + performance-mode changes without
guessing. Read `items/vpn.sh`, `plugins/vpn.sh`, `plugins/vpn_click.sh`, `sketchybarrc`
(whole right-side block), `theme.sh`, `colors.sh`, a comparable 2-item division
(`items/wifi.sh` + `items/ethernet.sh` + their plugins) and
`configs/aerospace/performance-mode.sh`.

**Questions**

1. **Naming + membership.** What item names should replace `vpn` (e.g. `vpn_be` / `vpn_sn`),
   and what is the exact resulting `sketchybarrc` diff — source order in the right-side
   block (remember: right items are added **right-most first**) so the visual L->R order in
   the connectivity division is deterministic, plus the exact new
   `--add bracket connectivity ...` member list? Does bracket membership order matter at
   all, or only the add order? Where must the two VPN items sit relative to wifi/ethernet to
   keep the current look?
2. **Every hardcoded `vpn` reference.** Grep the WHOLE repo (`configs/`, `scripts/`, `zsh/`,
   `docs/`, `_index.md`) for the item name `vpn` used as a sketchybar item/bracket/event
   token — `--set vpn`, `--update vpn`, `--subscribe vpn`, `NAME=vpn`, performance-mode's two
   lines, anything in `aerospace.toml` startup. Produce the complete list with
   file:line so nothing is missed. Which of them must become two names, which stay one
   (the `vpn_change` **event** name stays single — confirm)?
3. **Text rendering.** For a literal "BE"/"SN": should it be `icon=` (text, `$FONT` +
   which weight/size) or `label=`, and why — given the plugin recolours it and the item may
   also want an app-font glyph. What exact font string/size matches the bar's other text
   items? Give the concrete property set (`icon.font`, `label.drawing`, colours) for both
   items.
4. **Padding math for a 4-item division.** Current `plugins/vpn.sh` flips
   `icon.padding_right`/`label.padding_right` between `ELEMENT_GAP` and `DIVISION_PAD`
   depending on whether the label is drawn, because `vpn` is the division's right EDGE.
   With two always-drawn VPN items: which one owns the right-edge `DIVISION_PAD`, what does
   the inner one use, and is the dynamic padding branch still needed at all (state the
   final static padding table for wifi/ethernet/vpn_x now that ethernet still
   hides-when-disconnected)?
5. **One plugin, two items.** Can/should a single `plugins/vpn.sh` serve both items —
   via `$NAME` mapped to a country, or via an argument in
   `script="$PLUGIN_DIR/vpn.sh be"`? Verify sketchybar actually passes args in `script=`
   and that `$NAME` is set for both `update_freq` ticks and event deliveries. Same question
   for `vpn_click.sh` (how does it learn which icon was clicked — `$NAME` in `click_script`?).
6. **Polling cost + events.** Each tick currently runs `vpnutil list` + 2 `jq`. With two
   items at `update_freq=30` that doubles. Options to evaluate: both items poll; only one
   polls and repaints both (`sketchybar --set` on the sibling); one shared "driver"
   invocation. What do the two items need to `--subscribe` (keep `system_woke wifi_change
   vpn_change`?), and what `update_freq` for each? Recommend one, with the failure mode of
   each (e.g. an item that never polls but only listens can go stale after a
   System-Settings-initiated change).
7. **Per-icon busy "…".** The click lock `/tmp/nordvpn-native.click` is global and
   `plugins/vpn.sh` repaints the busy look from its existence. Since only ONE VPN action can
   be in flight (single slot), does the lock need to become per-icon, or global + an owner
   token (which icon/country initiated it) that the painter reads? Specify the concrete
   mechanism (path, contents, atomic-create semantics, stale timeout, cleanup on the EXIT
   trap) and what each of the two icons renders while the other one is busy.
8. **Colour-state matrix — resolve the ORANGE collision.** Today ORANGE = "pinned server dead
   / `nord refresh` needed" and overrides everything; the new spec makes ORANGE = "active
   country but not connected". Enumerate the full per-icon state table (active vs inactive x
   connected / connecting / disconnected / busy / refresh-needed) and propose how to signal
   refresh-needed without ambiguity (different colour? label suffix? which colour token from
   colors.sh is free?). Also: today `YELLOW` = Connecting — does it survive, or does
   Connecting fold into ORANGE/busy? Flag the decision, don't silently pick.
9. **Neither-BE-nor-SN case.** If `country` is `fr`/`vn`/`us`/`my` (or a 3rd country is
   Connected), what should the two icons show? Propose the least-surprising rendering and
   say what info the plugin needs to detect it.
10. **performance-mode.sh.** Give the exact replacement for both blocks (ON and OFF),
    including the `update_freq` values each new item must be restored to, and confirm
    nothing else in that script or in `aerospace.toml`'s startup line needs touching.

**Deliverable A:** file:line-anchored findings + a recommended concrete shape (item names,
property sets, sketchybarrc ordering, plugin/click-handler contract, state table). Explicit
list of open decisions for the human. Name the `_index.md` bullets and
`docs/vpn/guide-nordvpn-native.md` sections that will need editing (both MUST be updated in
the same change).

---

# ASSIGNMENT B — nord CLI + state / locking side

Goal: everything needed to know whether the CLI must change at all, and exactly what the bar
may call and read. Read `scripts/vpn/nord.sh` fully, `scripts/vpn/nord-connect.sh` fully,
`zsh/alias/vpn.zsh`, `configs/nordvpn/com.teazyou.nordvpn-native.plist`, and the guide's
"Concurrency & correctness rules" + "Flows".

**Questions**

1. **What defines "currently active country", exactly?** `nord.sh` writes
   `$CFG_DIR/country` **only after a SUCCESSFUL connect** (`nord.sh` ~L112), `nord off` does
   not touch it, and `nord-connect.sh` resets it to `sg` on a new `boot-id`. Enumerate every
   divergence between `country` and reality: failed switch, off state, hand-started config in
   System Settings, post-reboot, `refresh-needed`, watcher-initiated connect. For each, say
   what the bar would show if it trusts `country` alone vs `country` + `vpnutil list`.
   Recommend the exact derivation rule (pseudo-code) for `active_cc`.
2. **Is `nord <country>` safe to call from a click handler, and for how long does it block?**
   Compute the worst-case wall time from the code paths: `lock_acquire` (60x1s),
   `stop_all` (3 rounds x 20x1s), `start_cc` (45s + `exit_ip_only` curls at `--max-time 6`),
   final `exit_ip`. Give best/typical/worst numbers. Compare against the click lock's 200s
   stale-steal in `plugins/vpn_click.sh` — does 200s still cover it, or must it change?
   Any risk of two `nord` processes overlapping (CLI vs watcher) that the current lock does
   not already cover?
3. **Does `nord <cc>` already do exactly what "click the grey icon" needs?** Verify it:
   (a) writes `enabled=1`, (b) stops everything first (single-slot safe), (c) starts the
   target, (d) writes `country`, (e) clears `refresh-needed`, (f) fires `vpn_change`. State
   whether the click path can be a plain `nord belgium` / `nord singapore` with zero CLI
   changes, or whether something is missing.
4. **Toggle semantics on the active icon.** `nord toggle` = off if anything is
   Connected/Connecting, else `nord on` (which reads `country`, default sg). Confirm this
   matches "toggle its status" in both directions, including: active icon clicked while a
   DIFFERENT country is connected; active icon clicked while `country` is a non-BE/SN
   country; active icon clicked while `refresh-needed`. Any case where `toggle` does
   something surprising for the new 2-icon model?
5. **Failure feedback path.** On a failed `start_cc`: `country` unchanged, `refresh-needed`
   touched, `bar_refresh` fired, exit 1. Under the new model the icon would fall back to
   "the old active country" — is that acceptable, or is a "pending/target" signal needed?
   If a signal is needed, specify: filename under `~/.config/nordvpn-native/` (or `/tmp`),
   who writes/clears it, whether `nord-connect.sh` and the boot reset must know about it,
   and the risk of it going stale. Prefer the minimal-change option and say so.
6. **Does the CLI need any new/changed subcommand?** Evaluate whether the bar needs anything
   beyond `nord <cc>` and `nord toggle` (e.g. a fast read-only `nord active-cc`, or a
   `--quiet`/non-blocking mode so the click handler returns sooner). Weigh against the rule
   "do not break existing commands". If the answer is "no change needed", say so plainly.
7. **Concurrency with two clickable icons.** With ONE global click lock, a click on the
   second icon while the first is in flight is silently dropped. Is that the right behaviour
   given the single-VPN-slot invariant (vs queueing, vs cancelling)? What happens if the
   launchd watcher fires mid-click (resolv.conf changes on every tunnel transition) — trace
   it through `lock_acquire` / the watcher's non-blocking `mkdir` and confirm no deadlock or
   double-start is possible with the new flow.
8. **Consumers of the state files + the `vpn_change` event.** Grep the repo for readers of
   `~/.config/nordvpn-native/country|enabled|refresh-needed` and for
   `sketchybar --trigger vpn_change` / `--set vpn`. Confirm no other script would break when
   the bar item is renamed/split. Does anything need to fire `vpn_change` in a new situation
   (e.g. target country changed but connection state didn't)?
9. **Boot reset expectation check.** Reboot forces `country=sg` + `enabled=1`, so SN becomes
   the active icon after every restart. Confirm from the code, and flag it as a
   product-level consequence for the human (do not decide it).

**Deliverable B:** file:line-anchored findings, the recommended `active_cc` derivation rule,
concrete timing numbers for question 2, a clear verdict on whether `scripts/vpn/*` must
change at all (and if yes, the minimal diff shape). Explicit list of open decisions. Name the
`_index.md` bullets and `docs/vpn/guide-nordvpn-native.md` sections that will need editing.
