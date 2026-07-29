# Researcher B — nord CLI / state / locking side. READ-ONLY, no mutations made.

Pre-read done: docs/vpn/guide-nordvpn-native.md (full), _index.md (vpn section).
Live state at research time (read via `cat`, not `nord status` — avoids side-effect flag writes):
`country=be enabled=1 boot-id=2050EBE2-... (== live kern.bootsessionuuid, no-reboot-since) refresh-needed=ABSENT fail-stamp=ABSENT`. `vpnutil list`: Nord-BE=Connected, FR/MY/SG/US/VN=Disconnected. Matches brief.

No VPN state mutated. No file edited. No git touched. No lint run.

---

## Q1 — "active country" derivation

`country` semantics, by write-site:
- `scripts/vpn/nord.sh:112` — writes ONLY after `start_cc` returns 0 (success). Same line clears `refresh-needed`.
- `scripts/vpn/nord-connect.sh:34` — writes `sg` ONLY on boot-id mismatch (reboot). Normal (non-boot) reconnect path only **reads** it (`nord-connect.sh:46`), never writes.
- `nord off` (`nord.sh:116-122`) — never touches `country`. Confirmed no write in that branch.
- `nord.sh` failure paths (`start_cc` fail, `nord.sh:111`; `nord-connect.sh` fail, `nord-connect.sh:93-98`) — never touch `country`.

So `country` = "last successfully-connected-to (or boot-reset) target", NOT "currently connected". Divergence enumeration:

| Case | `country` says | reality (`vpnutil list`) | bar if `country`-only | bar if `country` + `vpnutil list` |
|---|---|---|---|---|
| a. failed switch (`start_cc` fails, `nord.sh:91-94`) | OLD cc (unchanged) | nothing Connected (stop_all ran first) ; `refresh-needed` touched (`nord.sh:92`) | wrongly shows OLD cc as "connected/red" | correctly shows OLD-cc icon active-but-orange (refresh-needed override already forces orange, `plugins/vpn.sh:28`) |
| b. `nord off` | unchanged (e.g. `be`) | nothing Connected, `enabled=0` | can't tell off from "trying" | active icon = active-but-disconnected = ORANGE (matches spec: "active, not connected = orange") — **`enabled` not needed at all**, see Q6 |
| c. hand-started in System Settings (e.g. Nord-FR via GUI, bypasses CLI entirely) | unchanged, e.g. `be` (not fr) | Nord-FR Connected, Nord-BE Disconnected | BE icon wrongly "connected" | BE icon correctly shows active-but-disconnected=ORANGE, but **real connected country (FR) is invisible in a 2-icon UI** — genuine product-level gap, not a code bug. Flagging, not deciding. |
| d. post-reboot | forced to `sg` (`nord-connect.sh:34`) | nothing connected until watcher's RunAtLoad succeeds | SN "active" instantly (correct per rule) | same — matches Q9 |
| e. `refresh-needed` set | unchanged | active-cc's tunnel down | n/a | forces ORANGE on whichever icon matches `country` (global flag, not per-cc — see Q5) |
| f. watcher-initiated connect (`nord-connect.sh:79-92`) | **unchanged** — watcher never writes `country` outside the boot branch | if success: target now Connected; if fail: same shape as (a) | — | no new divergence: watcher follows the existing `country`, doesn't set it, so accuracy chain is unbroken vs (a)/(d) already covered |

**Verdict: `country` alone is insufficient (case a, b, c). Must combine with a live `vpnutil list` read. `enabled` is NOT needed by the derivation (case b shows why).**

Recommended `active_cc` derivation (pseudo-code, bar-side, no CLI change):
```
country      = cat CFG_DIR/country  (default sg)
conn_cc      = vpnutil list -> Connected name, strip "Nord-", lowercase, else ""
connecting_cc= same for Connecting, else ""
refresh      = exists(CFG_DIR/refresh-needed)   # today: global bool, see Q5 re per-cc tagging

for icon in {be, sn(=sg)}:
  if icon.cc != country:            color = GREY                      # not the selected target — unconditional per literal spec
  elif icon.cc == conn_cc:          color = PINK   (red, connected)
  elif icon.cc == connecting_cc:    color = YELLOW (connecting)
  else:                             color = ORANGE (active, not connected: off / failed / mid-boot-wait)
  if refresh_applies(icon.cc):      color = ORANGE  # override, same priority as today (plugins/vpn.sh:28)
  if busy_lock_target == icon.cc:   color = YELLOW; label = "…"        # highest priority, see Q7
```
Known gap left unresolved by design (flag only): if `country` ∉ {be, sg} (reachable — CLI still accepts all 6 via terminal, `nord.sh:3,36-40`), NEITHER icon matches → both fall to the `!= country` branch → both GREY. Not decided here; open decision, see bottom.

---

## Q2 — is `nord <cc>` safe / how long does it block

Timing derived from code constants (sleep-count × interval, `curl --max-time` caps) — **not empirically measured**; running it live would mutate VPN state (disallowed this assignment).

- `lock_acquire` (`nord.sh:49-57`): loop 1..60, `sleep 1` only after a failed `mkdir`. Success at try *k* ⇒ elapsed `(k-1)`s (0–59s). All 60 fail ⇒ ~60s then `return 1` (caller `exit 1`, `nord.sh:108`).
- `stop_all` (`nord.sh:59-70`): 3 rounds × (stop-cmds + wait-loop 1..20×1s). Success at round/try boundary ⇒ 0–~60s. All 3 rounds exhausted ⇒ ~60s then `return 1` (`nord.sh:110` `exit 1`).
- `start_cc` (`nord.sh:75-95`): `base` curl ≤6s (`nord.sh:80,72-73`) + poll loop 1..45×1s (sleep-then-check, success at try *k* ⇒ +k s, range 1–45s) + on non-Connected-but-still-Connecting, one more `exit_ip_only` ≤6s check (`nord.sh:87-89`) before accept/reject. Failure exit path: `vpnutil stop` + `touch FLAG` (`nord.sh:91-92`), ~instant.
- Final `exit_ip()` (`nord.sh:114`, success path only): ≤6s.

| | Best | Typical | Worst (still resolves) |
|---|---|---|---|
| lock_acquire | ~0s | ~0–1s | succeeds ≤59s, else fails at 60s |
| stop_all | ~0.5s | ~2–5s | succeeds ≤~60s, else fails at ~60s |
| start_cc | ~2–4s | ~5–15s | succeeds ≤~51s (incl. moved-IP grace), else fails ~51–57s |
| final exit_ip (success only) | ~0.5s | ~1s | 6s |
| **TOTAL `nord <cc>` success** | **~4–6s** | **~8–15s** | **up to ~176–182s (≈3min) — pathological stacking of all 3 worst-cases** |
| **TOTAL `nord <cc>` fail, fastest mode (lock never frees)** | — | — | **~60s flat** |
| **TOTAL `nord <cc>` fail via failed `start_cc`, lock/stop uncontended** | — | — | **~55–65s** |
| **TOTAL `nord off`** (stop-only, no start_cc) | ~0.5–1s | ~2–5s | fails ~119s (lock 60 + stop 60) |

**Click-lock comparison** (`plugins/vpn_click.sh:18-19`, 200s stale-steal): 200s > 182s theoretical absolute worst (≈18s / ~9% margin — thin) and ≫ typical 8–15s (>10× margin). **This is a pre-existing number, unchanged by this feature** — `nord toggle`'s "on" branch (`nord.sh:124`, `exec "$0" on`) already runs the identical lock→stop_all→start_cc chain today, so the 2-icon redesign does not itself widen the worst case; it only changes *how often* the lock gets contended (Q7). Verdict: **200s does not strictly need to change** for this feature alone; flag the thin absolute-worst margin as pre-existing, not newly introduced. If paranoia wanted: bump to ~240s, cheap and orthogonal.

**Overlap risk beyond current lock:** none found. `lock_acquire`'s `mkdir` success sets `trap 'rmdir "$LOCK"' EXIT` (`nord.sh:52`) on the **whole script process**, not just the mutating sub-phase — so the lock is held from acquire to final `exit 0`/`exit 1`, covering `stop_all`+`start_cc`+writes+final `exit_ip` as one atomic unit. A second `nord.sh` invocation (e.g. second icon clicked) simply retries `mkdir` for up to 60s (per lock_acquire), then gives up — see Q7 for whether this is reachable at all given the click-lock layer above it.

---

## Q3 — does `nord <cc>` already do exactly what "click grey icon" needs

Checked against `nord.sh:104-115` (switch|on branch), line-by-line:

| requirement | evidence | met? |
|---|---|---|
| (a) writes `enabled=1` | `nord.sh:109` `echo 1 > "$CFG_DIR/enabled"` — unconditional, first mutating step | YES |
| (b) stops everything first (single-slot safe) | `nord.sh:110` `stop_all \|\| exit 1` — stops ALL Nord configs (`stop_all` iterates `in_state Connected;in_state Connecting`, not just current target), waits till none remain | YES |
| (c) starts target | `nord.sh:111` `start_cc "$cc"` | YES |
| (d) writes `country` | `nord.sh:112` — success-only | YES |
| (e) clears `refresh-needed` | `nord.sh:112` `rm -f "$FLAG"` — same line, success-only | YES |
| (f) fires `vpn_change` | `nord.sh:113` `bar_refresh` (→ `sketchybar --trigger vpn_change`, `nord.sh:47`); also fired on failure (`nord.sh:111` `{ bar_refresh; exit 1; }`) | YES |

**Verdict: `nord belgium` / `nord singapore` already implements the full grey-icon-click contract. Zero CLI changes required for this behaviour.**

Latent (non-)issue: since grey by definition means "the other one" in a 2-icon world, the click can never target the already-active cc, so the "redundant reconnect of an already-connected target" footgun (harmless but wasteful blip) can't be triggered via the specified UI flow. Only reachable via a stray manual terminal call — out of scope.

---

## Q4 — toggle semantics on the active icon

`nord toggle` (`nord.sh:123-125`): `if in_state Connected;Connecting non-empty -> exec off; else -> exec on` (which reconnects **whatever `country` says**, default sg, `nord.sh:106`). This is a **global** "is *anything* up" check, not per-cc.

- Active icon clicked while connected (normal case): something IS connected (it's this icon's own cc, by the accuracy chain in Q1) → toggle→off. Matches spec.
- Active icon clicked while disconnected (normal case, e.g. after boot or after `off`): nothing connected → toggle→on, reconnects `country` (== this icon's own cc). Matches spec.
- Active icon clicked while a **different** (non-{be,sg}) country is Connected (Q1 case c, hand-started): `in_state Connected` non-empty (that other cc) → toggle picks **off**, stopping the OTHER country, not starting this icon's cc. Surprising relative to a naive "toggle THIS icon" reading, but only reachable via the already-flagged external-actor gap (Q1c) — not a toggle bug, a consequence of toggle being global-not-per-cc combined with a 2-icon UI over a 6-country CLI.
- Active icon clicked while `country` is itself a non-BE/SN value: can't arise for "the active icon" as defined (active = `country`-match) unless the UI's own fallback-both-grey state (Q1 open gap) is somehow still showing one as clickable-active — edge case of the open gap, not a new toggle issue.
- Active icon clicked with `refresh-needed` set: toggle logic doesn't read the flag at all (display-only signal) → behaviour unaffected, no surprise.

**Verdict: toggle semantics are correct for both spec'd directions under normal (CLI/bar-exclusive, BE/SN-only) usage. Divergence only surfaces through the already-flagged external-actor gap (Q1c), not a defect in `toggle` itself.**

---

## Q5 — failure feedback path

`start_cc` fail (`nord.sh:91-94`): `country` unchanged, `refresh-needed` touched (`nord.sh:92`, unconditional empty-touch — boolean, not tagged to a cc), `bar_refresh` fired (`nord.sh:111`), `exit 1`. Same shape in `nord-connect.sh:93-97`.

Under the 2-icon model, the icon that falls back after a failed switch is the **OLD** active cc (per Q1's derivation, since `country` never advanced) — shown ORANGE (active+refresh-needed). The **just-clicked** (failed) icon reverts to GREY. This can read as "I clicked BE, it went `…`, then BE went back to grey and the *other* icon turned orange" — mildly confusing, but:
1. It is the direct, inherited consequence of `refresh-needed` being a single **global** flag today (not new — the 1-icon model has the identical imprecision, just invisible because there was only ever one label to paint).
2. It self-resolves: the click-handler (which statically knows the cc it just called, e.g. hardcoded `nord belgium` in a per-icon click script) can paint ITS OWN icon orange/failed immediately on non-zero exit from `nord <cc>`, without any new CFG_DIR file — **but** that paint is only as durable as the next repaint tick / `vpn_change` (which fires immediately on the same failure, `nord.sh:111`), so a persisted signal is needed for it to *stick* past that immediate repaint.

**Minimal-change option (recommended):** repurpose the *existing* `refresh-needed` file's content from empty-touch to a cc-tag: `nord.sh:92` `touch "$FLAG"` → `echo "$1" > "$FLAG"` (the failing `$cc`, already in scope); `nord-connect.sh:96` `touch "$CFG_DIR/refresh-needed"` → `echo "$cc" > ...` (same var already in scope, `nord-connect.sh:46`). Zero new files, zero new directories, same clear-sites (`nord.sh:112`, `nord.sh:148`, `nord-connect.sh:85,90`) already `rm -f` it wholesale. Bar-side reader (`plugins/vpn.sh:28`) would need a per-icon tweak from `[ -f "$FLAG" ]` to `[ "$(cat "$FLAG" 2>/dev/null)" = "$MY_CC" ]` — **that read-side change is bar-territory, not scripts/vpn/*, flagging for Researcher A, not deciding here.**
One wrinkle: `nord.sh:143-150` (status dead-pin sweep) can find **multiple** dead ccs at once (`$dead` is space-joined) — a single-cc-tag format doesn't fit that call site as cleanly; would need a space-list instead of a single cc there. Small, but non-zero, complexity.

**Zero-change alternative:** accept the imprecision as-is (matches "prefer minimal", literally zero diff anywhere) — old-cc-goes-orange, clicked-cc-goes-grey, both are still individually "truthful" (old cc really isn't connected; clicked cc really isn't the selected target since the switch didn't stick) even if the pairing reads oddly for a moment. **This is the true minimal option and is what "prefer minimal-change" points to if perfect failure-attribution isn't required.**

**Recommendation: ship zero-change first (spec doesn't ask for failure-specific display, only busy-in-flight display); revisit the cc-tag repurposing only if the human finds the old-cc-goes-orange behavior confusing in practice.** Open decision, not decided here.

---

## Q6 — does the CLI need a new/changed subcommand

No. Both required actions are already covered:
- grey-icon click = `nord <cc>` (Q3, zero change).
- active-icon click = `nord toggle` (Q4, matches normal-path semantics, zero change).

Read-side: **the bar does not call the CLI for status today at all.** `plugins/vpn.sh:15-19` calls `$VPNUTIL list` + `jq` **directly**, and reads `$CFG_DIR/refresh-needed` **directly** (`plugins/vpn.sh:11,28`) — it never shells out to `nord status`. So a hypothetical `nord active-cc` read command would be redundant with what the bar plugin already does itself, and would be *worse* (going through `nord status`, `nord.sh:138-152`, has side effects — it re-touches/clears `refresh-needed` via the DNS-health sweep, `nord.sh:143-150` — a periodic 30s-freq bar poller must NOT invoke that path). Note also `plugins/vpn.sh` currently reads **neither** `country` nor `enabled` (confirmed: no `country`/`enabled` string anywhere in that file) — this is genuinely NEW plumbing the 2-icon redesign must add on the bar side, but it's a plain file-read, no CLI call needed.

"Quiet/non-blocking mode so the click handler returns sooner" — not needed. `click_script` already runs as its own subprocess under sketchybar (doesn't freeze the rest of the bar); the existing single-icon `vpn_click.sh:28` already runs `nord toggle` synchronously and blocks only that click's own lifecycle, which is the accepted existing design. Extending to two icons doesn't change this shape.

**Verdict: no new/changed CLI subcommand needed. Zero `scripts/vpn/*` behaviour change required for the core ask (Q3+Q4+Q6 all confirm zero-change is sufficient); the only candidate touch is the OPTIONAL Q5 refresh-needed cc-tag, which is small and deferred as an open decision.**

---

## Q7 — concurrency with two clickable icons

Silent-drop-on-second-click (current single-icon behaviour, `plugins/vpn_click.sh:17-22`: `mkdir` fails → age<200 → `exit 0`) is **correct** for two icons **PROVIDED the click lock stays global/shared** (one `CLICK_LOCK` path for both icons — true today since `CLICK_LOCK="/tmp/nordvpn-native.click"` is a fixed literal, `vpn_click.sh:13`, not parameterized per icon). Reasoning: the single-VPN-slot invariant means two concurrent switch/toggle actions are never logically valid simultaneously anyway (they'd stomp the same slot) — queueing adds a consumer/daemon (against the zero-polling philosophy, doc:30 "no polling, no resident process"); cancel-and-replace risks a half-completed stop/start. Silent-drop is the simplest safe option and matches existing design philosophy.

**Cross-cutting flag for the bar-side build (not my file to edit, but load-bearing for the single-slot invariant): the click lock MUST remain one shared lock across both new icons, not per-icon.** If it became per-icon, both clicks could reach `bash "$NORD" ...` concurrently; `nord.sh`'s own `/tmp/nordvpn-native.lock` (`nord.sh:30`) would still prevent an actual double-`vpnutil start` (true mutex, held for the whole action per Q2), but the SECOND click would then silently block up to ~60s inside `lock_acquire` before failing (`nord.sh:55-56`, "ERROR: lock busy... 60s") — its icon would show "…" for a full minute then just revert with nothing having happened. Worse UX than an instant drop, still not unsafe (no double-start), but a UX regression the human should know is 100% dependent on keeping the click lock shared.

**Busy-attribution note (bar-side, not CLI):** since the shared lock carries no "which cc" info today, per-icon "…" needs the click handler to record its OWN cc (which it already knows statically — it's calling `nord belgium` literally) into a small marker (e.g. a file inside `$CLICK_LOCK` dir, written right after `mkdir` succeeds) so the periodic repaint can attribute "…" to the right icon and leave the OTHER icon on its normally-derived colour. Because the lock is exclusive, only one icon is ever busy at a time — the marker only ever needs to name one cc. Zero `scripts/vpn/*` involvement; pure `/tmp` + bar-side.

**Watcher-mid-click trace (`nord-connect.sh` fired by `WatchPaths` on every `nord.sh`-caused resolv.conf rewrite):**
- If `nord.sh` currently holds `/tmp/nordvpn-native.lock`: watcher's own acquire is **non-blocking** (`nord-connect.sh:71` `mkdir "$LOCK" 2>/dev/null || exit 0`) → fails instantly → watcher exits silently. No wait, no deadlock.
- If `nord.sh` has already finished and released the lock by the time the watcher's mutating phase runs: watcher re-checks state first (`nord-connect.sh:75-77`) — since `nord.sh` just wrote the new `country` and left the target Connected (success case) or nothing connected (failure case, but `enabled` still 1), the watcher's `grep -qE 'Connected|Connecting'` (`:77`) will typically already be true (target just connected) → `exit 0` immediately, no redundant start attempted. If `nord.sh` failed (nothing connected), the watcher WOULD attempt its own reconnect of the (unchanged) saved `country` — this is existing, accepted, intentional self-heal behaviour (doc:43, failure-cooldown exists precisely to bound this), not a new risk from 2 icons.
- If the watcher reaches its mutating phase FIRST (holds the lock) while a click starts: click's `nord.sh` `lock_acquire` just retries `mkdir` up to 60s (`nord.sh:49-54`) — watcher's own mutating phase is short (poll cap 30×1s, `nord-connect.sh:82`, or instant-exit if already settled) so this resolves well inside that window in practice.

**Verdict: no deadlock, no double-start, under the new 2-icon flow — same guarantees as today, unchanged by adding a second icon, CONTINGENT on the click lock staying shared (see flag above).**

---

## Q8 — consumers of state files + `vpn_change`

Full-repo grep (`.sh`/`.zsh`/`.toml`/`.plist`/`.md`) for `nordvpn-native`, `CFG_DIR`, `vpn_change`, and literal `vpn` item-name usage:

**`$CFG_DIR/country`** — write: `nord.sh:112`, `nord-connect.sh:34`. Read: `nord.sh:106,139`, `nord-connect.sh:46`. **`plugins/vpn.sh` does NOT read it today** (confirmed — no `country` string in that file) — the 1-icon bar has never needed "selected target when nothing's connected"; it only reads live `vpnutil list` output. **This is new plumbing the 2-icon feature must add to the bar side**, not a pre-existing consumer that could break.

**`$CFG_DIR/enabled`** — write: `nord.sh:109,117,129`, `nord-connect.sh:35`. Read: `nord.sh:140`, `nord-connect.sh:41,75`. **Also not read by `plugins/vpn.sh` today**, and per Q1, doesn't need to be for the 2-icon derivation either (fully inferable from `country`+`vpnutil list`).

**`$CFG_DIR/refresh-needed`** — write/touch: `nord.sh:92,148`, `nord-connect.sh:96`. Clear: `nord.sh:112,148`, `nord-connect.sh:85,90`. Read: **only** `plugins/vpn.sh:28`. No other consumer found.

**`sketchybar --trigger vpn_change`** — fired: `nord.sh:47` (called from `:111,113,120,134,160`), `nord-connect.sh:85,91,97`, and redundantly re-fired by `vpn_click.sh:23` (EXIT trap, safety net). **Subscribed: only `items/vpn.sh:32`** (`--subscribe vpn system_woke wifi_change vpn_change`) — the event itself is declared once (`items/vpn.sh:29`). **No other item/script subscribes.** Splitting the item means **both** new items must each carry their own `--subscribe ... vpn_change` line — required bar-side change, not found to be handled anywhere yet (expected, since split hasn't happened).

**New situation needing `vpn_change`?** Yes, one gap found: `nord-connect.sh:33-38` (boot-id-mismatch reset: `country=sg`, `enabled=1`, `boot-id` write) does **not** itself fire `vpn_change` — the next trigger only comes later, on the watcher's own subsequent connect success/fail (`:85/91/97`), or the bar's own `update_freq=30` tick, or its `system_woke` subscription. So there's a real (if short, self-healing) window right after boot where `country` has already flipped to `sg` but the bar hasn't been told yet. Small optional 1-line addition (`sketchybar --trigger vpn_change` right after `nord-connect.sh:37`) would make SN-becomes-active instant at login instead of relying on the ≤30s poll / wake-event catch-up. **Flagging as optional, not required (self-heals ≤30s), not applied (read-only).**

**Other consumers checked, none found to reference `vpn` item/plugin/state beyond what's already known:** `docs/window-manager/guide-window-manager.md:109,111,151,181,187,190,191` — all **prose descriptions**, will need a wording pass if the item is split (see bottom), not executable consumers. `configs/aerospace/performance-mode.sh:54,72` — **executable consumer**, hardcodes the single item name `vpn` in two `--set vpn drawing=... update_freq=...` calls (full context: lines 45-58 = OFF-restore branch, lines 60-73 = ON-minimal branch) — **will break/silently no-op on a renamed/absent `vpn` item** if the item is split into two differently-named items without updating these two call sites. Flagging as a concrete break point for whoever implements the split (not my file to touch).

---

## Q9 — boot reset expectation check

Confirmed in code: `nord-connect.sh:32` reads `kern.bootsessionuuid`; `nord-connect.sh:33` compares to stored `boot-id`; on mismatch, `nord-connect.sh:34-37` unconditionally sets `country=sg`, `enabled=1`. This runs at `RunAtLoad` (every login, `com.teazyou.nordvpn-native.plist:17-18`) before any other check.

**Consequence for the 2-icon model: every reboot makes SN the "active" icon (per the Q1 derivation), regardless of which one (BE or SN) was active before the reboot.** This is a pre-existing, deliberate, documented design choice (doc:9 "Every reboot resets to Singapore + enabled", design decision #5, doc:31, with two field-tested rejected alternatives). **Flagging for the human to knowingly accept or reject for the 2-icon UI specifically — not deciding it here, per instructions.**

---

# DELIVERABLE B SUMMARY

**Recommended `active_cc` derivation:** see Q1 pseudo-code. Core rule: `icon.cc == country` file (not `enabled`, not a naive "whichever vpnutil reports connected") decides which icon is "in use"; combine with a live `vpnutil list` read to pick RED vs ORANGE for that icon. Non-matching icon is unconditionally GREY (matches literal user spec, no further vpnutil check needed for it).

**Timing (Q2, code-derived, not measured):**
- `nord <cc>` success: best ~4–6s, typical ~8–15s, worst ~176–182s (≈3min, pathological stacking, not realistic in practice).
- `nord <cc>` fail: fastest mode (lock timeout) ~60s flat; via failed `start_cc` (lock/stop uncontended) ~55–65s.
- `nord off`: best ~0.5–1s, typical ~2–5s, worst ~119s.
- Click-lock 200s stale-steal (`plugins/vpn_click.sh:19`) still numerically covers the absolute worst-case (~18s margin, thin but pre-existing — `nord toggle`'s "on" branch already runs this identical chain today) and comfortably covers realistic worst (~3×+ margin). **No change required by this feature's math alone.**

**Verdict on `scripts/vpn/*` changes: NONE REQUIRED.** `nord <cc>` (Q3) and `nord toggle` (Q4) already implement the full click contract end-to-end with zero modification. The only candidate diff is the OPTIONAL Q5 hardening (repurpose `refresh-needed`'s content from boolean-touch to a cc-tag, `nord.sh:92`+`nord-connect.sh:96`, ~2-4 lines, no new files) for precise per-icon failure attribution — **deferred as an open decision, not required by the stated spec** (which only mandates a busy indicator, not a failure indicator). If adopted later, minimal diff shape: change `touch "$FLAG"` → `echo "$cc" > "$FLAG"` at the two write sites, and the multi-cc dead-pin sweep (`nord.sh:143-150`) would need a space-list instead of single-cc format.

**Open decisions (not mine to make):**
1. `refresh-needed` cc-tagging (Q5) — ship zero-change first, revisit only if old-cc-goes-orange-on-failed-switch reads as confusing in practice.
2. Fallback rendering when `country` ∉ {be, sg} (Q1/Q4) — reachable via terminal `nord france/vietnam/usa/malaysia`; both icons would show GREY under the recommended rule. Acceptable or needs a third state?
3. During a SWITCH (grey-icon click), does only the clicked/incoming icon show "…", or should the outgoing active icon also show a transitional state? Literal spec says "that icon" (singular) — flagging the ambiguity, not resolving it.
4. Boot-reset-always-picks-SN (Q9) — accept as-is for the 2-icon UI, or special-case it?
5. Whether to add the optional 1-line `vpn_change` trigger right after the boot-reset write (`nord-connect.sh:37`) for instant (vs ≤30s-lagged) bar correctness at login (Q8).
6. **Cross-cutting hard requirement for whoever builds the bar side: the click lock (`/tmp/nordvpn-native.click`) MUST stay one shared lock across both icons, never per-icon** (Q7) — this is load-bearing for the single-slot invariant's UX safety, not optional.

**Known product-level gap, not a bug:** a non-{BE,SN} country connected via System Settings or terminal `nord <other-cc>` is invisible to a 2-icon UI (Q1c, Q4) — the CLI still supports all 6 countries and always will; the bar simply can't represent the other 4 in this design. Flag-only.

**`_index.md` bullets that will need editing IF/when the item is actually split** (none edited by me — read-only):
- `## configs` → `configs/sketchybar/items/*.sh` bullet — currently states "8 SOURCED items" and describes vpn as one item; becomes 9 items, vpn description needs splitting into two.
- `## configs` → `configs/sketchybar/plugins/*.sh` bullet — `vpn_click.sh` description ("click = `nord toggle`") needs the new switch-vs-toggle branching described.
- Possibly `## configs` → sketchybarrc bullet if bracket membership prose is touched (low priority, prose is generic today).

**`docs/vpn/guide-nordvpn-native.md` sections that will need editing IF/when implemented:**
- "Components" table, "Bar item" row (doc:19) — single-icon description → two-icon description.
- "Caveats" — worth adding the Q1c/Q4 known-gap (non-BE/SN country invisible to the 2-icon bar) and the Q9 boot-reset-picks-SN consequence for the 2-icon context specifically.
- No changes needed to the CLI-contract sections ("Flows", "Ops", "Concurrency & correctness rules") since `scripts/vpn/*` itself is unchanged (verdict above) — unless the optional Q5 refresh-needed retagging is adopted, in which case the `refresh-needed` bullet (doc:23, doc:65) needs a one-line semantic update (boolean flag → cc-tag).

**Explicit UNKNOWNs:**
- Exact per-invocation overhead of `vpnutil`/`jq` process startup — not measured (would require live timing runs; disallowed — read-only, no VPN mutation).
- Researcher A's planned item/lock naming scheme for the split (e.g. `vpn_be.sh`/`vpn_sn.sh` vs one script handling two instances) — not in my file set, coordinate before implementing Q7's shared-lock requirement.
