# 04 — Acceptance checklist: two VPN icons (BE / SN)

For a QA agent. Every item is independently verifiable with **read-only** commands, a
**non-mutating simulation** (§C), or one clearly-marked **user-performed live click**
(§F, optional). Nothing below changes VPN state except §F.

Setup for QA (run once):
```sh
cd /Users/teazyou/workspace
SB=~/.config/sketchybar          # symlink -> configs/sketchybar
D=/Users/teazyou/workspace/sprint/vpn-rework
```
Colour tokens (compare **case-insensitively** — sketchybar prints lowercase hex):
`GREY 0xff939ab7` · `PINK/red 0xffaa2222` · `ORANGE 0xffcc7b6e` ·
`YELLOW 0xffeed49f` · `MAGENTA 0xffc6a0f6`

Baseline captured at planning time (re-read, don't assume):
`cat ~/.config/nordvpn-native/country` → `be`; `Nord-BE` = Connected;
`refresh-needed` absent; `/tmp/performance-mode.state` absent (bar is full).

---

## A. Items exist, are shaped right, and the old one is gone

1. **Old item removed.** `sketchybar --query vpn` fails / returns no item named `vpn`.
   Also `grep -rn '\bvpn\b' configs/sketchybar/sketchybarrc configs/aerospace/performance-mode.sh`
   returns **no** line where `vpn` is used as an *item name* (only `vpn.sh` /
   `vpn_change` / `vpn_be` / `vpn_sn` may appear).
2. **Both items exist.** `sketchybar --query vpn_be` and `sketchybar --query vpn_sn`
   both succeed.
3. **Labels are the literal user strings.**
   `sketchybar --query vpn_be | jq -r .label.value` → `BE` (or `…` if a click is in
   flight); same for `vpn_sn` → `SN`. **Not** `SG`.
4. **Text, not glyph.** For both items:
   `jq -r '.icon.drawing'` → `off`, `jq -r '.label.drawing'` → `on`,
   `jq -r '.label.font'` → `JetBrainsMono Nerd Font:Bold:14.00`.
   `jq -r '.icon.value'` must NOT be `:nord_vpn:`.
5. **Wiring.** For both items `jq -c .scripting` shows
   `script` = `…/plugins/vpn.sh`, `click_script` = `…/plugins/vpn_click.sh`,
   `update_freq` = `30`.
6. **Both subscribe to the same three events.** `grep -n 'subscribe' configs/sketchybar/items/vpn.sh`
   shows two lines, each `system_woke wifi_change vpn_change`. `--add event vpn_change`
   appears exactly once (`grep -c 'add event vpn_change' configs/sketchybar/items/vpn.sh` → `1`).
7. **Bracket membership.** `sketchybar --query connectivity | jq -c .bracket` contains
   `vpn_be` and `vpn_sn` and does NOT contain `vpn`.
8. **Visual order is wifi, ethernet, BE, SN.**
   ```sh
   for i in wifi ethernet vpn_be vpn_sn; do printf "%-7s " $i; \
     sketchybar --query $i | jq -c '.bounding_rects."display-1".origin[0]'; done
   ```
   x must be non-decreasing in that order, and `vpn_sn` must be the largest x of the
   four. (`ethernet` may have width 0 when unplugged — that is expected.)
9. **No extra inter-item gap.** For both items
   `sketchybar --query vpn_be | jq -c '{p:[.geometry.padding_left,.geometry.padding_right]}'`
   → `[0,0]` (same for `vpn_sn`). If these are `8`, the `padding_left=0 padding_right=0`
   lines were dropped and the division will look wrong.
10. **Division edge pad.** `grep -n 'padding' configs/sketchybar/items/vpn.sh` shows
    `vpn_sn` with `label.padding_right=$DIVISION_PAD` and `vpn_be` with
    `label.padding_right=$ELEMENT_GAP`; both with `label.padding_left=$ELEMENT_GAP`.
    No hardcoded numbers (no bare `6`) — theme tokens only.

## B. Plugin logic (static read of `configs/sketchybar/plugins/vpn.sh`)

11. **Reads the selected country.** The file reads `$CFG_DIR/country` with fallback
    `sg`. (`grep -n 'country' configs/sketchybar/plugins/vpn.sh` → non-empty.)
12. **Singapore is compared as `sg`.** `grep -n '"sn"\|=sn\b' configs/sketchybar/plugins/vpn.sh
    configs/sketchybar/plugins/vpn_click.sh` returns **nothing** (SN is a display label
    only; every comparison uses `sg`).
13. **No `nord status` from the poller.** `grep -n 'nord' configs/sketchybar/plugins/vpn.sh`
    returns nothing (the painter must never shell out to the CLI — `nord status` has
    side effects on `refresh-needed`).
14. **Paints both items every run.** The final `sketchybar` call carries `--set vpn_be`
    **and** `--set vpn_sn`; there is exactly one `vpnutil list` invocation in the file.
15. **Precedence order** in the paint function is exactly: busy-owner → not-selected
    (grey) → refresh-needed (magenta) → connected (PINK) → connecting (YELLOW) →
    else ORANGE.
16. **No runtime padding/drawing churn.** The plugin sets only `label=` and
    `label.color=`; it must not set `label.drawing`, `icon.*`, or any `*padding*`.

## C. Live state rendering (read-only, no VPN mutation)

17. **Current truth matches the table.** Read the inputs, then the rendering:
    ```sh
    cat ~/.config/nordvpn-native/country; ls ~/.config/nordvpn-native/refresh-needed 2>&1
    /opt/homebrew/bin/vpnutil list
    for i in vpn_be vpn_sn; do printf "%-7s " $i; \
      sketchybar --query $i | jq -c '{l:.label.value,c:.label.color}'; done
    ```
    Assert against §A of the plan's truth table. With the planning-time baseline
    (`country=be`, Nord-BE Connected, no flag) the expected result is
    `vpn_be = BE / 0xffaa2222 (red)` and `vpn_sn = SN / 0xff939ab7 (grey)`.
18. **A forced repaint is idempotent.** `NAME=vpn_be $SB/plugins/vpn.sh` then
    `NAME=vpn_sn $SB/plugins/vpn.sh` — both leave the same two label/colour pairs as
    item 17 (proves the painter is name-agnostic and paints both).
19. **Busy attribution (simulated, safe).**
    ```sh
    mkdir /tmp/nordvpn-native.click && echo vpn_be > /tmp/nordvpn-native.click/owner
    NAME=vpn_sn $SB/plugins/vpn.sh
    for i in vpn_be vpn_sn; do printf "%-7s " $i; sketchybar --query $i | jq -c '{l:.label.value,c:.label.color}'; done
    ```
    Expect `vpn_be = … / 0xffeed49f (yellow)` and `vpn_sn` on its **real** colour
    (grey with the baseline). Then swap the owner to `vpn_sn`, repaint, and confirm
    the roles invert.
20. **Click is dropped while the lock is held (safe).** With the lock from item 19
    still present:
    ```sh
    time NAME=vpn_sn $SB/plugins/vpn_click.sh; echo "exit=$?"
    ```
    Must return in well under 1 s with exit 0, and `/opt/homebrew/bin/vpnutil list` +
    `cat ~/.config/nordvpn-native/country` must be **unchanged**.
21. **Stale lock is ignored by the painter (safe).** Age the lock past the window and
    repaint:
    ```sh
    touch -t 202001010000 /tmp/nordvpn-native.click
    NAME=vpn_be $SB/plugins/vpn.sh
    ```
    Both icons must show their real labels/colours again (no `…`).
22. **Cleanup after §C** (mandatory, leaves the machine as found):
    ```sh
    rm -f /tmp/nordvpn-native.click/owner; rmdir /tmp/nordvpn-native.click
    NAME=vpn_be $SB/plugins/vpn.sh
    ls -d /tmp/nordvpn-native.click 2>&1   # must be "No such file or directory"
    ```

## D. Click decision tree (stubbed — never calls the real `nord`)

23. **Build the stub and run both icons:**
    ```sh
    printf '#!/bin/bash\necho "$@" >> %s/nord-calls.log\n' "$D" > "$D/nord-stub.sh"
    : > "$D/nord-calls.log"
    sed "s|^NORD=.*|NORD=\"$D/nord-stub.sh\"|" $SB/plugins/vpn_click.sh > "$D/vpn_click_test.sh"
    grep -n '^NORD=' "$D/vpn_click_test.sh"        # confirm the stub took
    NAME=vpn_be bash "$D/vpn_click_test.sh"
    NAME=vpn_sn bash "$D/vpn_click_test.sh"
    cat "$D/nord-calls.log"
    ```
    With `country=be` the log must read exactly:
    ```
    toggle
    sg
    ```
    (selected icon → `toggle`; grey icon → its own country code). If `country` were
    `sg` at QA time the expected log is `be` then `toggle`. Confirm
    `/opt/homebrew/bin/vpnutil list` is unchanged and the real `nord.sh` was never run.
24. **Unknown `$NAME` is a no-op.** `NAME=vpn bash "$D/vpn_click_test.sh"; echo $?` → `0`,
    and `nord-calls.log` gains no line.
25. **The lock is released cleanly.** After item 23,
    `ls -d /tmp/nordvpn-native.click 2>&1` → "No such file or directory".
26. **Release never uses `rm -rf`.** `grep -n 'rm -rf' configs/sketchybar/plugins/vpn_click.sh`
    returns nothing; `grep -n 'release()' configs/sketchybar/plugins/vpn_click.sh` shows
    the helper, used at all three cleanup sites (steal, EXIT trap, pre-settle).
27. **The lock stays shared.** `grep -n 'CLICK_LOCK=' configs/sketchybar/plugins/vpn_click.sh
    configs/sketchybar/plugins/vpn.sh` → both are the literal `/tmp/nordvpn-native.click`
    with no `$NAME`/`$MY_CC` interpolation. **Per-icon locks are a hard fail.**
28. **Click paints only the clicked icon.** `grep -n 'sketchybar --set' configs/sketchybar/plugins/vpn_click.sh`
    shows exactly one `--set "$NAME"` and no hardcoded item name.
29. **QA scratch cleanup:** `rm -f "$D/nord-stub.sh" "$D/vpn_click_test.sh" "$D/nord-calls.log"`.

## E. Performance mode still works

30. **Names updated.** `grep -n 'vpn' configs/aerospace/performance-mode.sh` shows
    `vpn_be` and `vpn_sn` on both the `drawing=on update_freq=30` (OFF-restore) and
    `drawing=off update_freq=0` (ON-minimal) branches — 4 `--set` lines total — and no
    bare `--set vpn `.
31. **It runs without error** (the file uses `set -euo pipefail`, so a missing item
    name would abort it). Note the state first, run twice, confirm you end where you
    started:
    ```sh
    cat /tmp/performance-mode.state 2>/dev/null || echo "(absent)"
    ~/workspace/configs/aerospace/performance-mode.sh; echo "exit=$?"
    sketchybar --query vpn_be | jq -c '{d:.geometry.drawing,f:.scripting.update_freq}'
    ~/workspace/configs/aerospace/performance-mode.sh; echo "exit=$?"
    sketchybar --query vpn_be | jq -c '{d:.geometry.drawing,f:.scripting.update_freq}'
    ```
    Both runs exit 0; one pass shows `drawing=on, update_freq=30`, the other
    `drawing=off, update_freq=0`; the same must hold for `vpn_sn`. Restore the state
    file to what it was before.

## F. Live click (OPTIONAL — the only VPN-mutating test; user-performed or explicitly authorised)

32. Click the **grey** icon → it shows `…`, then within ~15 s it becomes red and the
    other icon turns grey; `cat ~/.config/nordvpn-native/country` shows the new code.
33. Click the **red** (selected) icon → `…`, then it turns **orange** (selected, not
    connected) and `vpnutil list` shows nothing Connected. Click it again → back to red.
34. During either action, clicking the **other** icon does nothing (dropped by the
    shared lock) and that other icon keeps rendering its own real colour, not `…`.
35. Restore the user's original country/enabled state afterwards (baseline was
    `country=be`, connected).

## G. Docs and index are in sync (project rule — same change, not follow-up)

36. `docs/vpn/guide-nordvpn-native.md` — the **Bar item** row describes two items
    (`BE`/`SN`), the grey/red/orange/yellow/magenta table, the grey→`nord <cc>` vs
    selected→`nord toggle` click split, and the shared lock + `owner` file.
37. Same file — every remaining "orange = refresh needed" statement is gone:
    `grep -n -i 'orange' docs/vpn/guide-nordvpn-native.md` must show orange only in
    its **new** meaning (selected + not connected). The `refresh-needed` mentions
    (state-dir contents line and the "Stale pins / dead server" paragraph) say
    **magenta**.
38. Same file — `## Caveats` gained the two new bullets: (a) only BE/SN are
    representable, other countries render both icons grey; (b) every reboot makes SN
    the selected icon.
39. `_index.md` line ~39 says **9 SOURCED items** and lists `vpn_be, vpn_sn` (not
    `vpn`); the vpn clause describes the five colours and the two click behaviours.
40. `_index.md` line ~40 (`plugins/*.sh`) describes `vpn.sh` painting both items and
    `vpn_click.sh` branching `nord <cc>` vs `nord toggle`.
41. `docs/window-manager/guide-window-manager.md` — lines ~109, ~111, ~151, ~187,
    ~190, ~191 all name `vpn_be`/`vpn_sn` (freq table lists `vpn_be 30, vpn_sn 30`),
    and the item count reads 9 live items.
42. **No stale single-item references anywhere.**
    `grep -rn 'items/vpn.sh' docs/ _index.md` and
    `grep -rn -w 'vpn' docs/ _index.md` — every hit must be `vpn_be`/`vpn_sn`/
    `vpn.sh`/`vpn_click.sh`/`vpn_change`/`nord`/prose, never a bar item named `vpn`
    (exception: `docs/window-manager/guide-window-manager.md` line ~181 lists
    `icons.sh` *categories*, where "vpn" is a legitimate category name).

## H. Blast-radius guardrails (must all be true)

43. **`scripts/vpn/` untouched.** `git diff --stat -- scripts/vpn/` is empty (running
    `git diff`/`git status` is read-only and allowed; **no** add/commit/push/stash).
    Same for `zsh/alias/vpn.zsh`, `configs/nordvpn/`, `configs/sketchybar/icons.sh`,
    `configs/sketchybar/theme.sh`, `configs/sketchybar/colors.sh`,
    `configs/aerospace/aerospace.toml`, `configs/aerospace/lib-paths.sh`.
44. **Changed-file set is exactly:** `configs/sketchybar/items/vpn.sh`,
    `configs/sketchybar/plugins/vpn.sh`, `configs/sketchybar/plugins/vpn_click.sh`,
    `configs/sketchybar/sketchybarrc`, `configs/sketchybar/plugins/wifi_click.sh`
    (comment only), `configs/aerospace/performance-mode.sh`,
    `docs/vpn/guide-nordvpn-native.md`, `docs/window-manager/guide-window-manager.md`,
    `_index.md` (+ this sprint folder). Verify with `git status --short`.
45. **No notifications.** `grep -rn 'display notification\|osascript' configs/sketchybar
    configs/aerospace` returns nothing new (must be zero hits in the changed files).
46. **No linting was run and no linter/formatter config was added** — no new
    `.shellcheckrc`/`.editorconfig`, no reformatting churn in the diff (the diff of
    each touched file should contain only intended lines).
47. **No git operations were performed.** `git log -1 --format=%H` matches the commit
    that was HEAD before the work (`8e82bc7` at planning time), the working tree is
    dirty with the item-44 files, and nothing is staged (`git diff --cached` empty).
48. **No files written outside the repo** except the transient `/tmp/nordvpn-native.click`
    used in §C (removed by item 22), and no scratch outside
    `/Users/teazyou/workspace/sprint/vpn-rework/`.
49. **Bar was reloaded and is healthy after the change.** `sketchybar --reload` ran;
    `sketchybar --query bar | jq -r .display` → `main`; the connectivity bracket still
    paints (item 7) and no sketchybar error output was produced.
50. **The single-VPN-slot invariant is intact:** no code path in the changed files
    calls `vpnutil start`/`stop` directly (`grep -rn 'vpnutil start\|vpnutil stop'
    configs/sketchybar` → nothing). All state changes still go through `nord.sh`.
