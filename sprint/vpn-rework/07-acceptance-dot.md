# 07 — Acceptance checklist: selection DOT replaces the orange colour

For a QA agent. Every item is verifiable with **read-only** commands, a **non-mutating
simulation** (§B, stubbed `CFG_DIR` + stubbed `vpnutil` — never the real `nord`), or a
**runtime-only** `--set` that the next 30 s poll self-heals (§C). **Nothing below changes VPN
state.** Plan under test: `06-plan-dot.md`.

Setup (run once):
```sh
cd /Users/teazyou/workspace
SB=~/.config/sketchybar                      # symlink -> configs/sketchybar
D=/Users/teazyou/workspace/sprint/vpn-rework
```
Colour tokens — compare **case-insensitively**, `--query` prints lowercase hex:
`GREY 0xff939ab7` · `PINK/red 0xffaa2222` · `YELLOW 0xffeed49f` · `MAGENTA 0xffc6a0f6` ·
**`TRANSPARENT` is reported as `0x0`, NOT `0x00000000`** · `ORANGE 0xffcc7b6e` must appear
**nowhere** in the vpn rendering.

Baseline captured at planning time (re-read, don't assume): `cat
~/.config/nordvpn-native/country` → `be`; **all** `vpnutil` configs `Disconnected`;
`refresh-needed` absent; `/tmp/performance-mode.state` absent (bar full). Reference geometry
recorded live: `vpn_be` width **30**, `vpn_sn` width **31**, `connectivity` width **83 or 85**
(the wifi RSSI glyph is 20 or 22 px wide — both values are healthy).

---

## A. Dot mechanism, geometry and static hygiene

1. **theme.sh owns the dot.** `grep -n 'SEL_DOT' configs/sketchybar/theme.sh` shows exactly
   four exports: `SEL_DOT_GLYPH="●"`, `SEL_DOT_SIZE=12.0`, `SEL_DOT_ADVANCE=6`,
   `SEL_DOT_Y_OFFSET=-9`, under a comment block that states (a) negative `y_offset` = DOWN,
   (b) the zero-layout-cost padding identity, (c) that hiding is a COLOUR not `icon.drawing`.
   No other theme.sh line changed (`git diff -- configs/sketchybar/theme.sh` is an append only).
2. **No `DOT_`-prefix collision.** `grep -rn '\bDOT_GLYPH\|\bDOT_FONT\|\bDOT_COLOR' configs/sketchybar`
   shows those names ONLY in `plugins/aerospace.sh` (its own empty-workspace marker); theme.sh
   uses the `SEL_DOT_*` prefix.
3. **items/vpn.sh derives the pads, no magic numbers.**
   `grep -n 'VPN_ELEMENT_W\|VPN_DOT_PAD\|icon\.' configs/sketchybar/items/vpn.sh` shows
   `VPN_ELEMENT_W=$(( ELEMENT_GAP + 18 + ELEMENT_GAP ))`,
   `VPN_DOT_PAD_L=$(( (VPN_ELEMENT_W - SEL_DOT_ADVANCE) / 2 ))`,
   `VPN_DOT_PAD_R=$(( -(VPN_DOT_PAD_L + SEL_DOT_ADVANCE) ))`, and an `icon.*` block that uses
   `$SEL_DOT_GLYPH`, `$SEL_DOT_SIZE`, `$SEL_DOT_Y_OFFSET`, `$VPN_DOT_PAD_L`, `$VPN_DOT_PAD_R`,
   `$TRANSPARENT` — **no literal `12`, `-18`, `-9`, `●` or hex**. The one literal `18` (2-char
   label width) is commented as verified-live.
4. **No hardcoded colours anywhere in the three vpn files.**
   `grep -n '0x' configs/sketchybar/items/vpn.sh configs/sketchybar/plugins/vpn.sh configs/sketchybar/plugins/vpn_click.sh`
   → **no hits**. `git diff -- configs/sketchybar/colors.sh` → **empty** (no new palette entry).
5. **`icon.drawing` is `on` and never toggled at runtime.**
   `grep -n 'icon.drawing' configs/sketchybar/items/vpn.sh` → exactly one line, `=on`;
   `grep -n 'icon.drawing\|label.drawing\|padding' configs/sketchybar/plugins/vpn.sh configs/sketchybar/plugins/vpn_click.sh`
   → **no hits** (presence is a colour, so nothing can shift).
6. **Live item properties** (after `sketchybar --reload`; both items):
   ```sh
   for i in vpn_be vpn_sn; do printf "%-7s " $i; sketchybar --query $i | \
     jq -c '{iv:.icon.value,if:.icon.font,iy:.icon.y_offset,ipl:.icon.padding_left,ipr:.icon.padding_right,id:.icon.drawing}'; done
   ```
   Both → `{"iv":"●","if":"JetBrainsMono Nerd Font:Bold:12.00","iy":-9,"ipl":12,"ipr":-18,"id":"on"}`.
7. **Zero-layout-cost identity holds.** `ipl + 6 + ipr == 0` i.e. `12 + 6 - 18 = 0` (the `6` is
   `SEL_DOT_ADVANCE`; re-derive it if you want: `sketchybar --set vpn_be icon.padding_left=0
   icon.padding_right=0`, the item width grows 30 → **36**, then restore with
   `sketchybar --set vpn_be icon.padding_left=12 icon.padding_right=-18`).
8. **Label still 14 pt text, not a glyph.** `jq -r '.label.font'` → `JetBrainsMono Nerd
   Font:Bold:14.00`; `.label.value` → `BE` / `SN` (or `…` mid-click); `.label.drawing` → `on`.

## B. Truth table by simulation (stubbed — no VPN mutation, no `nord` call)

9. **Build the stub** (writes only inside `$D`):
   ```sh
   mkdir -p $D/stub
   printf '#!/bin/bash\ncat "$(dirname "$0")/snapshot.json"\n' > $D/stub/vpnutil; chmod +x $D/stub/vpnutil
   sed -e "s|^CFG_DIR=.*|CFG_DIR=\"$D/stub\"|" -e "s|^VPNUTIL=.*|VPNUTIL=\"$D/stub/vpnutil\"|" \
       $SB/plugins/vpn.sh > $D/vpn_test.sh
   grep -n '^CFG_DIR=\|^VPNUTIL=' $D/vpn_test.sh        # BOTH must point into $D/stub
   sim(){ [ -n "$1" ] && printf '%s' "$1" > $D/stub/country || rm -f $D/stub/country
          printf '%s' "$2" > $D/stub/snapshot.json
          if [ "$3" = refresh ]; then touch $D/stub/refresh-needed; else rm -f $D/stub/refresh-needed; fi
          bash $D/vpn_test.sh; sleep 0.4
          for i in vpn_be vpn_sn; do printf "%-7s " $i
            sketchybar --query $i | jq -c '{l:.label.value,lc:.label.color,dot:.icon.color}'; done; }
   OFF='{"VPNs":[{"name":"Nord-BE","status":"Disconnected"},{"name":"Nord-SG","status":"Disconnected"}]}'
   BEC='{"VPNs":[{"name":"Nord-BE","status":"Connected"},{"name":"Nord-SG","status":"Disconnected"}]}'
   SGC='{"VPNs":[{"name":"Nord-BE","status":"Disconnected"},{"name":"Nord-SG","status":"Connected"}]}'
   SGN='{"VPNs":[{"name":"Nord-BE","status":"Disconnected"},{"name":"Nord-SG","status":"Connecting"}]}'
   ```
10. **Disconnected, `country=be`** — `sim be "$OFF"` → `vpn_be BE / grey / grey`,
    `vpn_sn SN / grey / 0x0`. *(Both labels grey; the ONLY difference is the dot — the core of
    this change. If `vpn_be` is `0xffcc7b6e` the orange branch survived: hard fail.)*
11. **Disconnected, `country=sg`** — `sim sg "$OFF"` → `vpn_be BE / grey / 0x0`,
    `vpn_sn SN / grey / grey`.
12. **Connected to BE** — `sim be "$BEC"` → `vpn_be BE / 0xffaa2222 / 0xffaa2222`,
    `vpn_sn SN / grey / 0x0`.
13. **Connected to SG** — `sim sg "$SGC"` → `vpn_be BE / grey / 0x0`,
    `vpn_sn SN / 0xffaa2222 / 0xffaa2222`.
14. **Connecting** — `sim sg "$SGN"` → `vpn_sn SN / 0xffeed49f / 0xffeed49f`;
    `vpn_be BE / grey / 0x0`.
15. **Refresh-needed beats connected** — `sim be "$BEC" refresh` →
    `vpn_be BE / 0xffc6a0f6 / 0xffc6a0f6`, `vpn_sn SN / grey / 0x0`.
16. **Third country (known gap)** — `sim fr "$OFF"` → **both** `grey` and **both** dots `0x0`
    (no dot anywhere).
17. **Missing `country` file** — `sim "" "$OFF"` → falls back to `sg`: identical to item 11.
18. **Broken `vpnutil` output** — `sim be 'not json'` → `vpn_be BE / grey / grey`,
    `vpn_sn SN / grey / 0x0` (same as item 10; no crash, no empty label).
19. **Busy attribution + dot** (uses the real `/tmp` lock dir; cleaned in item 21):
    ```sh
    mkdir /tmp/nordvpn-native.click && echo vpn_be > /tmp/nordvpn-native.click/owner
    sim be "$OFF"      # vpn_be = … / yellow / yellow   (dotted, it IS the selected one)
    echo vpn_sn > /tmp/nordvpn-native.click/owner
    sim be "$OFF"      # vpn_sn = … / yellow / 0x0      (busy but NOT selected -> no dot)
                       # vpn_be = BE / grey / grey      (keeps its dot while SN works)
    ```
20. **Stale lock still ignored by the painter.**
    `touch -t 202001010000 /tmp/nordvpn-native.click; sim be "$OFF"` → no `…` on either icon,
    dots per item 10.
21. **Cleanup + restore the truth (mandatory):**
    ```sh
    rm -f /tmp/nordvpn-native.click/owner; rmdir /tmp/nordvpn-native.click
    rm -rf $D/stub $D/vpn_test.sh
    NAME=vpn_be $SB/plugins/vpn.sh                       # real painter, real state
    ls -d /tmp/nordvpn-native.click 2>&1                 # must be "No such file or directory"
    cat ~/.config/nordvpn-native/country; /opt/homebrew/bin/vpnutil list | head -5
    ```
    `country` and every `vpnutil` status must equal the baseline — **proof of no VPN mutation**.

## C. Layout neutrality (the dot must never move anything)

22. **Geometry is identical dot-on / dot-off / today's baseline.**
    ```sh
    g(){ for i in vpn_be vpn_sn connectivity; do printf "%-13s " $i; \
         sketchybar --query $i | jq -c '.bounding_rects."display-1"'; done; }
    g;                                     sketchybar --set vpn_be icon.color=0xffaa2222; sleep 0.4
    g;                                     sketchybar --set vpn_be icon.color=0x0;        sleep 0.4
    g;                                     NAME=vpn_be $SB/plugins/vpn.sh
    ```
    All three blocks must be **identical**, with `vpn_be` size `30`, `vpn_sn` size `31`,
    `connectivity` size `83` or `85` — the same numbers round 1 recorded (`05-qa-round1.md`
    item 8: be 2194→sn 2224 = 30 wide; sn 2224 + 31).
23. **The label did not move.** `vpn_sn.origin[0] - vpn_be.origin[0] == 30` and
    `connectivity.origin[0] == wifi.origin[0]`; visual order still non-decreasing across
    `wifi, ethernet, vpn_be, vpn_sn` (re-run round-1 item 8's loop).
24. **Item paddings untouched.** For both items
    `jq -c '[.geometry.padding_left,.geometry.padding_right]'` → `[0,0]`; and
    `jq -c '[.label.padding_left,.label.padding_right]'` → `[6,6]` for both (tokens
    `ELEMENT_GAP`/`DIVISION_PAD` still 6 — `grep -n 'padding' configs/sketchybar/items/vpn.sh`
    shows only token references for the label paddings).
25. **(OPTIONAL, deepest check — pixel probe.)** Only if you want to confirm the dot's *ink*.
    Reference: dot ink **5 px** wide, rows **28-32**, centred on the element; label ink rows
    **15-24**; division pill rows **5-34**.
    ```sh
    X=$(sketchybar --query vpn_be | jq -r '.bounding_rects."display-1".origin[0]|floor')
    screencapture -x -R$((X-6)),0,44,42 $D/dot.png
    cat > $D/probe.py <<'EOF'
    import sys,zlib,struct
    d=open(sys.argv[1],'rb').read();p=8;idat=b''
    while p<len(d):
        n,t=struct.unpack('>I',d[p:p+4])[0],d[p+4:p+8]
        if t==b'IHDR': w,h,dep,ct=struct.unpack('>IIBB',d[p+8:p+18])
        elif t==b'IDAT': idat+=d[p+8:p+8+n]
        p+=12+n
    nch={0:1,2:3,4:2,6:4}[ct];raw=zlib.decompress(idat);st=w*nch;rows=[];prev=bytearray(st);q=0
    for _ in range(h):
        f=raw[q];q+=1;L=bytearray(raw[q:q+st]);q+=st
        if f==1:
            for i in range(nch,st):L[i]=(L[i]+L[i-nch])&255
        elif f==2:
            for i in range(st):L[i]=(L[i]+prev[i])&255
        elif f==3:
            for i in range(st):L[i]=(L[i]+(((L[i-nch] if i>=nch else 0)+prev[i])>>1))&255
        elif f==4:
            for i in range(st):
                a=L[i-nch] if i>=nch else 0;b=prev[i];c=prev[i-nch] if i>=nch else 0
                pa,pb,pc=abs(b-c),abs(a-c),abs(a+b-2*c)
                L[i]=(L[i]+(a if pa<=pb and pa<=pc else (b if pb<=pc else c)))&255
        rows.append(bytes(L));prev=L
    ox=int(sys.argv[2])
    for y in range(h):
        r=rows[y];hit=[x for x in range(w) if max(abs(r[x*nch]-30),abs(r[x*nch+1]-30),abs(r[x*nch+2]-30))>45]
        if hit:print("y=%2d x %d..%d n=%d"%(y,ox+hit[0],ox+hit[-1],len(hit)))
    EOF
    python3 $D/probe.py $D/dot.png $((X-6)); rm -f $D/dot.png $D/probe.py
    ```
    Expect label ink rows 15-24 and, **iff BE is the selected country**, a 5-px run at rows
    28-32 centred on `X+15`; nothing in rows 25-27 / 33-34.

## D. Nothing from round 1 regressed

26. **Click decision tree unchanged** (stubbed `nord`, exactly as round-1 item 23):
    ```sh
    printf '#!/bin/bash\necho "$@" >> %s/nord-calls.log\n' "$D" > $D/nord-stub.sh; : > $D/nord-calls.log
    sed "s|^NORD=.*|NORD=\"$D/nord-stub.sh\"|" $SB/plugins/vpn_click.sh > $D/vpn_click_test.sh
    grep -n '^NORD=' $D/vpn_click_test.sh
    NAME=vpn_be bash $D/vpn_click_test.sh; NAME=vpn_sn bash $D/vpn_click_test.sh; cat $D/nord-calls.log
    ```
    With `country=be` the log is exactly `toggle` then `sg` (with `country=sg`: `be` then
    `toggle`). Real `nord.sh` never ran: `country` + `vpnutil list` unchanged.
27. **Busy paint now carries the dot, correctly gated.**
    `grep -n 'ACTION" = toggle\|--set "$NAME"' configs/sketchybar/plugins/vpn_click.sh` shows
    ONE `--set "$NAME"` carrying `label=`, `label.color=` **and** `icon.color="$DOT"`, with
    `DOT=$YELLOW` only on the `toggle` branch and `$TRANSPARENT` otherwise (no hardcoded item
    name, no second `--set`).
28. **Lock machinery untouched.** `grep -n 'CLICK_LOCK=' configs/sketchybar/plugins/vpn.sh
    configs/sketchybar/plugins/vpn_click.sh` → both literally `/tmp/nordvpn-native.click`
    (no `$NAME`/`$MY_CC` interpolation — per-icon locks are a hard fail); `release()` still
    used at all three sites; no `rm -rf`; `CLICK_STALE=200` in both.
29. **`$NAME` guard, event wiring, single snapshot.** `NAME=vpn bash $D/vpn_click_test.sh; echo $?`
    → `0` with no new log line. `grep -c 'add event vpn_change' configs/sketchybar/items/vpn.sh`
    → `1`; two `--subscribe … system_woke wifi_change vpn_change` lines; exactly one
    `"$VPNUTIL" list` in `plugins/vpn.sh`; `grep -n 'nord' configs/sketchybar/plugins/vpn.sh`
    → comments/paths only (the poller must never shell out to the CLI).
30. **Bracket + item set unchanged (no new item was added).**
    `sketchybar --query connectivity | jq -c .bracket` → `["vpn_be","vpn_sn","wifi","ethernet"]`;
    `sketchybar --query vpn` → not found; `git diff --stat -- configs/sketchybar/sketchybarrc
    configs/aerospace/performance-mode.sh configs/sketchybar/plugins/wifi_click.sh` → **empty**.
31. **Performance mode still round-trips and the dot comes back.**
    ```sh
    cat /tmp/performance-mode.state 2>/dev/null || echo "(absent)"
    ~/workspace/configs/aerospace/performance-mode.sh; echo "exit=$?"
    sketchybar --query vpn_be | jq -c '{d:.geometry.drawing,f:.scripting.update_freq}'
    ~/workspace/configs/aerospace/performance-mode.sh; echo "exit=$?"
    sketchybar --query vpn_be | jq -c '{d:.geometry.drawing,f:.scripting.update_freq,ic:.icon.color}'
    ```
    Both runs exit 0 (the script is `set -euo pipefail`); one pass gives
    `drawing=off, update_freq=0`, the other `drawing=on, update_freq=30`; after the OFF pass the
    selected icon's `.icon.color` is a real colour again (its `sketchybar --update` re-ran the
    painter). End with the state file exactly as you found it.
32. **Cleanup:** `rm -f $D/nord-stub.sh $D/vpn_click_test.sh $D/nord-calls.log`;
    `ls $D` → only the numbered `.md` planning docs.

## E. Docs + index are in sync (project rule — same change, not follow-up)

33. `docs/vpn/guide-nordvpn-native.md` **Bar item** row describes the **two channels** (colour
    = tunnel: grey/red/yellow/magenta; dot = selected country, same colour, one at a time),
    names the zero-layout-cost icon-slot mechanism + `theme.sh SEL_DOT_*` +
    `icon.color=$TRANSPARENT`, and keeps the click split (dot-less → `nord <cc>`, dotted →
    `nord toggle`), busy `…`, shared lock + `owner`, 200 s stale-steal.
34. Same file — **no live-colour "orange" statement survives**:
    `grep -n -i 'orange' docs/vpn/guide-nordvpn-native.md` returns only the *historical*
    test-matrix line, explicitly marked superseded. The `refresh-needed` state-dir line (~23)
    and the "Stale pins" paragraph (~65) still say **magenta**.
35. Same file — the BE/SN caveat bullet (~75) now also says **no dot is drawn** when the
    selected country is fr/my/us/vn.
36. `_index.md` — the theme.sh bullet (~36) lists `SEL_DOT_*` and says the dot is an element's
    ICON slot pulled under its label at zero layout cost; the items bullet (~39) describes the
    two channels and **contains no "orange"**; the plugins bullet (~40) says `vpn.sh` paints
    label colour = tunnel state and the icon slot = the selection dot.
37. `docs/window-manager/guide-window-manager.md` — the theme.sh token list (~163) includes the
    four `SEL_DOT_*` tokens; a new bullet records the **lesson** (label/item backgrounds cannot
    be shrunk to a dot — `label.background.padding_*` does nothing to the width, item
    `background.padding_*` only translates the fill; hence the icon slot + negative
    `icon.padding_right`; show/hide via colour, never `icon.drawing`); the state-driven-items
    line (~190) describes colour+dot with no "orange".
38. **No stale colour claims anywhere.** `grep -rni 'orange' docs/ _index.md` → only the
    superseded test-matrix line; `grep -rn 'selected + not connected\|selected+not connected'
    docs/ _index.md` → **no hits**.
39. **`grep -rn 'SEL_DOT' docs/ _index.md` → hits in all three doc files** (guide-vpn,
    WM guide, `_index.md`) — i.e. the new token family is documented, not silently introduced.

## F. Guardrails (all must be true)

40. **Changed-file set is exactly 7 tracked files** — `git status --short` / `git diff --stat`:
    `configs/sketchybar/theme.sh`, `configs/sketchybar/items/vpn.sh`,
    `configs/sketchybar/plugins/vpn.sh`, `configs/sketchybar/plugins/vpn_click.sh`,
    `docs/vpn/guide-nordvpn-native.md`, `docs/window-manager/guide-window-manager.md`,
    `_index.md` (+ the untracked/modified `sprint/vpn-rework/*.md`, + a possibly-modified
    `configs/dot-claude` submodule pointer, which is pre-existing). Anything else = fail.
41. **Untouched, verify empty diffs:** `scripts/vpn/`, `zsh/alias/vpn.zsh`, `configs/nordvpn/`,
    `configs/sketchybar/colors.sh`, `configs/sketchybar/icons.sh`,
    `configs/sketchybar/sketchybarrc`, `configs/aerospace/*` (incl. `performance-mode.sh`,
    `aerospace.toml`, `lib-paths.sh`), `configs/sketchybar/plugins/wifi_click.sh`.
42. **No git operation was performed by the implementer.** `git diff --cached` → empty (nothing
    staged); `git log -1 --format='%H %an %s'` → either `db1f3df` or a **later automatic
    `checkpoint`** commit authored by the hourly LaunchAgent (`scripts/checkpoint_cronjob.sh`);
    **no** commit with a hand-written message exists (`git log --oneline -5` shows only
    `checkpoint`/pre-existing subjects), and `git reflog -3` shows no
    `commit (amend)`/`reset`/`checkout`/`stash` entries from this session.
43. **No linting / no formatter config.** No new `.shellcheckrc`/`.editorconfig`/prettier file;
    `git diff --summary` → empty (no mode/rename churn); the diff of each touched file contains
    only the intended lines (no whitespace reflow). Files keep exec bit `755` and UTF-8
    (`file configs/sketchybar/items/vpn.sh`); `●` = U+25CF (`printf '%s' '●' | xxd` → `e2 97 8f`),
    `…` = U+2026 (`e2 80 a6`).
44. **No notifications.** `grep -rn 'display notification\|osascript' configs/sketchybar/items/vpn.sh
    configs/sketchybar/plugins/vpn.sh configs/sketchybar/plugins/vpn_click.sh
    configs/sketchybar/theme.sh` → **no hits**.
45. **No VPN mutation, no direct tunnel control.** `grep -rn 'vpnutil start\|vpnutil stop\|nord.sh'
    configs/sketchybar/plugins/vpn.sh` → nothing (`vpn_click.sh` may reference `nord.sh` — that
    is the sanctioned single entry point). Post-QA, `cat ~/.config/nordvpn-native/country`,
    `cat ~/.config/nordvpn-native/enabled` and `vpnutil list` equal the baseline (item 21), and
    `~/.config/nordvpn-native/refresh-needed` is still absent.
46. **Nothing written outside the repo** except the transient `/tmp/nordvpn-native.click` used
    in §B (removed by item 21); all scratch confined to `/Users/teazyou/workspace/sprint/vpn-rework/`
    and deleted by items 21/32.
47. **Bar healthy after the change.** `sketchybar --reload` ran; both items + the bracket paint;
    no sketchybar error output; `grep -n 'display=main' configs/sketchybar/sketchybarrc` still
    present and byte-unchanged. (Note: this build's `--query bar` exposes no `display` key —
    round-1 finding; verify from the config line, not the query.)
48. **Round-1 supersessions are honoured, not contradicted.** `06-plan-dot.md` §B lists the
    seven round-1 acceptance items this change intentionally inverts (icon.drawing on, icon
    value `●`, precedence ends in GREY not ORANGE, the plugin may set `icon.color`, live-click
    expectations). Confirm each superseded item now reads as in that table, and that **no other**
    round-1 item was silently broken (items 26-31 above cover the load-bearing ones).
49. **User-visible spec check (read the two rendered states from §B, items 10 and 12):**
    disconnected ⇒ **both labels grey**, dot **only** under the selected one, dot **grey**;
    connected ⇒ selected label **red** with a **red** dot, other label grey with **no** dot.
    No orange in either. If the reviewer wants R1 semantics instead (both icons red whenever
    the VPN is up), that is the documented one-line alternative in `06-plan-dot.md` §1 — flag
    it as a product question, not a defect.
50. **(OPTIONAL, user-performed — the only VPN-mutating test.)** Click the dot-less icon → it
    shows `…`, then within ~15 s it becomes red **and gains the dot** while the other icon goes
    grey and loses its dot. Click the dotted red icon → `…`, then it turns **grey but keeps its
    dot** (was orange before this change) and `vpnutil list` shows nothing Connected; click
    again → red+dot. During either action, clicking the other icon does nothing (shared lock).
    Restore the user's original state afterwards (baseline: `country=be`, disconnected).
