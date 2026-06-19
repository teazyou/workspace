# Performance Implementation Plan — Window Manager Config Refactor

## Summary

Consolidated the Performance review findings across aerospace-core, aerospace-scripts,
sketchybar-core, sketchybar-plugins, and borders-autoraise into an ordered, concrete
implementation plan. The dominant wins are eliminating recurring heavyweight subprocess
spawns on hot timers/events:

- `system_profiler SPDisplaysDataType` runs twice per 5s display-profile tick (no-op path).
- `system_profiler SPBluetoothDataType` (0.5-3s) runs every 5s just to pick a headset icon.
- One workspace switch fans out ~30 `aerospace` subprocesses across 10 spaces items.
- `sketchybar --update` force-runs every item script at every bar (re)start.
- `network_speed.sh` runs the whole route+netstat pipeline twice per 5s (two items).

Overlapping findings were merged: the two `system_profiler` display findings
(aerospace-core-01 + aerospace-scripts-01) and the two aerospace-fan-out findings
(sketchybar-core-01 + sketchybar-plugins-02) describe the same code from plist vs script
sides — each is one change here. Several low-severity micro-fork findings
(empty-watcher contains_pair / list-workspaces, open-dock-app head, resource-plugin fork
chains) are grouped into small, behavior-preserving cleanups.

### Dropped / not planned

- **performance-aerospace-core-02** (exec-on-workspace-change `/bin/bash -c` wrapper):
  the reviewer self-flagged "no change recommended"; two chained commands genuinely need
  a shell and folding them crosses a shared-script boundary for no measurable gain. Dropped.
- **performance-borders-autoraise-01** (AutoRaise 200ms idle poll): reviewer rated it
  "Acceptable; documented trade-off." The guide documents `pollMillis=200` as deliberate
  fly-over debouncing. Changing it alters focus feel, not a perf bug. Dropped.
- **ethernet.sh full event-subscription rewrite** (performance-sketchybar-plugins-03,
  aggressive variant): subscribing to a network-change event + /tmp interface cache is a
  behavior-affecting redesign with more risk than reward at 5s cadence. Kept only the
  safe, in-place fork reduction (see change S5). Cache-to-/tmp variant deferred (open Q).

### Constraints honored

Bash 3.2 compatible (parallel arrays, no `declare -A` / `mapfile`); symlink model intact
(edits to source files in `configs/`, `cp`-through preserved); no macOS notifications added;
no linting; documented behavior preserved. Where a change could alter documented behavior
(removing `sketchybar --update`) the plan keeps the behavior via an explicit dependency.

---

## Ordered Change List

Order rationale: A-changes (display-profile) are independent. The sketchybar startup
change (S2) depends on the spaces coordinator change (S1) so the bar still paints at
startup after `--update` is dropped. Plugin cleanups (S3-S6) are independent leaf edits.

### A1 — Halve display-profile wakeups (plist interval 5s → 15s)
- **id:** perf-a1-displayprofile-interval
- **file:** `/Users/teazyou/workspace/configs/aerospace/com.aerospace.display-profile.plist`
- **change:** Change `<key>StartInterval</key><integer>5</integer>` (lines 13-14) to
  `<integer>15</integer>`. Physical display replug is rare; 15s still feels instant and
  cuts the no-op `system_profiler` storm 3x. (Startup `--force` chain via
  `secondary-bar-toggle.sh` already applies immediately on every AeroSpace (re)start, so
  the perceived latency on a real swap is bounded by 15s only for hot swaps.) Update the
  guide line "runs apply-display-profile.sh every 5 seconds" in `guide-window-manager.md`
  to match.
- **rationale:** Cuts ~17k/day wakeups to ~5.7k/day and the paired `system_profiler` work
  proportionally, with no UX loss given the startup `--force` path.
- **addresses:** performance-aerospace-core-01
- **risk:** low
- **depends on:** none

### A2 — Capture system_profiler once per tick in apply-display-profile.sh
- **id:** perf-a2-displayprofile-singlecapture
- **file:** `/Users/teazyou/workspace/configs/aerospace/apply-display-profile.sh`
- **change:** Add one capture per invocation of `SPDisplaysDataType` and feed all three
  consumers from it instead of re-spawning. Concretely: in `main()`, capture
  `SP_DISPLAYS="$(system_profiler SPDisplaysDataType 2>/dev/null)"` once at the top, then:
  (a) `builtin_is_main()` reads from a passed-in string / global instead of calling
  `system_profiler` at line 36; (b) `get_fingerprint()` line 292 greps `$SP_DISPLAYS`
  instead of re-spawning; (c) `get_monitors_config()` line 159 reads
  `printf '%s\n' "$SP_DISPLAYS"` instead of the process substitution. Keep `builtin_is_main`
  callable from `get_fingerprint` (fingerprint stage) by passing the captured blob (e.g.
  `builtin_is_main "$SP_DISPLAYS"` with `local data="${1:-$(system_profiler ...)}"` so the
  function stays standalone-safe). Net: 2 spawns → 1 on the no-op path, ~4 → 1 on change
  ticks. Pure refactor — same awk/grep logic, same output.
- **rationale:** Removes the redundant second (and on change ticks third/fourth)
  `system_profiler` spawn per tick; complements A1's frequency cut for the largest
  aerospace-side CPU saving.
- **addresses:** performance-aerospace-core-01 (paired out-of-slice fix), performance-aerospace-scripts-01
- **risk:** medium (touches fingerprint + monitor parsing; a wrong refactor could break
  display detection / the 7-9 assignment. Mitigate: keep functions standalone-callable,
  diff the emitted `outer.top` + fingerprint before/after on the current display set.)
- **depends on:** none (independent of A1; both touch the same flow but different files)

### S1 — Single-coordinator workspace render (collapse ~30 aerospace spawns → ~3)
- **id:** perf-s1-spaces-coordinator
- **files:**
  - `/Users/teazyou/workspace/configs/sketchybar/items/spaces.sh`
  - `/Users/teazyou/workspace/configs/sketchybar/plugins/aerospace.sh`
- **change:** Stop having all 10 `space.$sid` items each run `aerospace.sh $sid` on
  `aerospace_workspace_change`. Instead introduce ONE hidden coordinator item (e.g.
  `spaces_coordinator`, drawing=off) subscribed to `aerospace_workspace_change` whose
  script queries the three states ONCE: `aerospace list-workspaces --monitor all --visible`,
  `aerospace list-workspaces --focused`, and a single
  `aerospace list-windows --all --format '%{workspace}|%{app-name}'` (replacing the
  per-workspace `list-windows --workspace`). The coordinator builds per-workspace
  label/color/icon state (reusing the existing `shorten_app_name`, star-collapse, and
  group-first/last/dot logic, kept Bash 3.2 with parallel arrays) and emits ONE batched
  `sketchybar --set space.1 ... --set space.2 ... --set space.0 ...`. In `spaces.sh`,
  remove `script="$PLUGIN_DIR/aerospace.sh $sid"` and the `aerospace_workspace_change`
  subscription from the per-item loop; KEEP `click_script="aerospace workspace $sid"` and
  `--subscribe space.$sid mouse.clicked` (cheap, per-item). Add the coordinator item +
  subscription. Refactor `aerospace.sh` into the coordinator that loops over the 10 ids
  internally rather than taking a single `$1`.
- **rationale:** Workspace switching is the hottest user path. Collapses ~10 shell procs +
  ~30 aerospace IPC round-trips per switch to ~1 shell + ~3 queries + 1 batched set.
- **addresses:** performance-sketchybar-core-01, performance-sketchybar-plugins-02
- **risk:** high (rewrites the most-edited, visually load-bearing script; the
  occupied/number-only/dot three-state rendering, per-monitor color tiers, and
  group-first/last padding must be preserved exactly. Mitigate: port the existing
  branching verbatim into the loop; verify all three states + multi-monitor colors render
  before/after; confirm `list-windows --all` field format matches per-workspace output.)
- **depends on:** none

### S2 — Remove blanket `sketchybar --update` at config load
- **id:** perf-s2-drop-blanket-update
- **file:** `/Users/teazyou/workspace/configs/sketchybar/sketchybarrc`
- **change:** Remove the final `sketchybar --update` (lines 171-172, incl. the
  "never do this in production" comment). To preserve the documented startup paint:
  replace it with a single targeted trigger so the spaces coordinator paints once —
  `sketchybar --trigger aerospace_workspace_change` — and rely on `update_freq` items
  self-populating on their first tick (they already ship literal `label=` defaults, e.g.
  network_up/down `label="0 B/s"`). This removes the synchronous run of every polling
  plugin (cpu/ram/battery/volume/headset/vpn/wifi/ethernet/network) at every bar restart
  while still guaranteeing the workspace strip renders immediately via S1's coordinator.
- **rationale:** Eliminates the startup thundering-herd that recurs on every aerospace
  startup / perf-mode toggle / display-profile flip, without leaving the spaces strip blank.
- **addresses:** performance-sketchybar-core-02
- **risk:** medium (without the targeted trigger the spaces strip would be blank until the
  first manual switch; the dependency on S1 + the explicit trigger removes that. Verify
  the bar paints fully at a cold `sketchybar` (re)start.)
- **depends on:** perf-s1-spaces-coordinator

### S3 — headset.sh: drop system_profiler SPBluetoothDataType from the 5s poll
- **id:** perf-s3-headset-cheap-source
- **files:**
  - `/Users/teazyou/workspace/configs/sketchybar/plugins/headset.sh`
  - `/Users/teazyou/workspace/configs/sketchybar/items/headset.sh` (update_freq)
- **change:** Replace `system_profiler SPBluetoothDataType` (line 8) with a cheap
  connected-device check. Preferred: `system_profiler` removed in favor of
  `ioreg -r -l -n AppleHSBluetoothDevice` / `ioreg`-based connected-audio query, or
  `defaults read /Library/Preferences/com.apple.Bluetooth` lookup; if `blueutil` is not a
  guaranteed dependency, do NOT introduce it (keep zero new deps — use `ioreg`). Keep the
  two-icon output identical. Additionally raise `update_freq` in items/headset.sh from 5
  to 30 and (optionally) subscribe the item to `system_woke` so reconnects after sleep
  repaint promptly. Net: removes the single biggest plugin-side CPU/wakeup cost.
- **rationale:** A 0.5-3s subprocess every 5s purely to choose between two glyphs is the
  worst offender in the plugin set; ioreg is milliseconds and a 30s cadence is ample for a
  rarely-changing headset state.
- **addresses:** performance-sketchybar-plugins-01
- **risk:** medium (the `ioreg` query must reliably detect the same "headphones/headset
  connected" condition as the current `Minor Type` awk; validate against a real connected
  headset and a disconnected state before relying on it. Pick the query that matches the
  user's actual device class.)
- **depends on:** none

### S4 — network_speed.sh: poll once, set both items
- **id:** perf-s4-network-single-poll
- **files:**
  - `/Users/teazyou/workspace/configs/sketchybar/plugins/network_speed.sh`
  - `/Users/teazyou/workspace/configs/sketchybar/items/network_up.sh`
  - `/Users/teazyou/workspace/configs/sketchybar/items/network_down.sh`
- **change:** Make `network_down` the sole poller and have it set both labels. In
  `network_down.sh` keep `update_freq=5` + `script=...network_speed.sh`. In
  `network_up.sh` REMOVE `update_freq=5` and `script=...` (it becomes a passive display
  item). In `network_speed.sh` replace the `if [ "$NAME" = network_up ] ... elif ...`
  tail (lines 67-74) with a single emit:
  `sketchybar --set network_down label="$(format_speed $SPEED_IN)" --set network_up label="$(format_speed $SPEED_OUT)"`.
  Consolidate the cache file to one name (drop the per-`$NAME` `prev_bytes_*` split since a
  single poller has no race) — use a fixed `CACHE_FILE="$CACHE_DIR/prev_bytes"`.
- **rationale:** The route+netstat+bc pipeline already computes both directions every call;
  running it twice per 5s is pure duplication. Halves the network poll forks.
- **addresses:** performance-sketchybar-core-03
- **risk:** low (single-poller removes the prior race the dual cache files guarded against;
  verify both up and down labels still update on the same 5s tick).
- **depends on:** none

### S5 — Resource & ethernet plugins: collapse fork chains to single awk (no behavior change)
- **id:** perf-s5-fork-chain-collapse
- **files:**
  - `/Users/teazyou/workspace/configs/sketchybar/plugins/ram.sh`
  - `/Users/teazyou/workspace/configs/sketchybar/plugins/cpu.sh`
  - `/Users/teazyou/workspace/configs/sketchybar/plugins/battery.sh`
  - `/Users/teazyou/workspace/configs/sketchybar/plugins/ethernet.sh`
- **change:** Replace per-field `echo|grep|awk|tr|cut|bc` reparse chains with one awk per
  plugin over the already-captured output:
  - `ram.sh`: pipe `vm_stat` once into a single awk that accumulates the page fields and
    prints the integer percentage (drops ~18 forks → ~1; `pagesize` no longer needed for
    the percentage since it cancels out in the ratio).
  - `cpu.sh`: one awk over `$CPU_INFO` to sum user+sys and truncate (drops `tr`, `bc`,
    `cut`).
  - `battery.sh`: fold the `grep -Eo "\d+%" | cut` and `grep 'AC Power'` into one awk pass
    over `$BATTERY_INFO` (low priority, smallest win).
  - `ethernet.sh`: keep `networksetup -listallhardwareports` (do NOT add the /tmp interface
    cache — deferred, see open questions) but reduce the `grep -A1` + per-iface `ifconfig |
    grep` into a tighter pass; the safe, in-slice win here is minor, so this file is
    optional within S5 if the awk rewrite risks the interface-name regex.
  All edits are output-identical (same `${PERCENT}%` / `${TOTAL}%` strings, same icon
  logic).
- **rationale:** These run every 5s; converting ~18 forks (ram) and ~5 (cpu) to 1 each is
  free CPU with zero visible change.
- **addresses:** performance-sketchybar-plugins-04, performance-sketchybar-plugins-03 (safe
  in-place portion only)
- **risk:** low (pure parsing refactor; validate each plugin emits the identical label
  string as before on the same input).
- **depends on:** none

### S6 — empty-workspace-watcher.sh + open-dock-app.sh: trim hot-loop micro-forks
- **id:** perf-s6-watcher-microforks
- **files:**
  - `/Users/teazyou/workspace/configs/aerospace/empty-workspace-watcher.sh`
  - `/Users/teazyou/workspace/configs/aerospace/open-dock-app.sh`
- **change:**
  - `empty-watcher` `contains_pair()` (line 40): replace `printf | grep -qFx` per monitor
    per tick with a fork-free Bash 3.2 match — wrap `$nonempty_pairs` in leading/trailing
    newlines once per tick and test `case $'\n'"$nonempty_pairs"$'\n' in *$'\n'"$2"$'\n'*)`.
    Removes ~8 forks/sec from the always-run early-out.
  - `empty-watcher` line 84: the per-monitor `aerospace list-workspaces --monitor "$mon"`
    is only needed for the assignment-order list; it is NOT derivable from the already-
    snapshotted `visible_pairs`/`nonempty_pairs` (which omit empty workspaces), so this
    query must stay for correctness. Flag-only — do NOT remove (review's suggestion to
    filter from a per-tick snapshot would need an `--empty all` snapshot; treat as a
    deferred enhancement, see open questions). No change in this slice.
  - `open-dock-app.sh` line 62: drop the wasteful `| head -n 1` and read the first line via
    `read -r` from the command (or `IFS= read -r entry < <(aerospace list-windows ...)`),
    removing one fork per 200ms poll on the cold-launch enforcer. Leave the poll cadence
    as-is (the 18s/20s grace coupling with empty-watcher is documented and intentional).
- **rationale:** Cheap, behavior-preserving fork reductions on two always-running hot
  loops (500ms daemon, 200ms enforcer).
- **addresses:** performance-aerospace-scripts-02, performance-aerospace-scripts-04,
  (performance-aerospace-scripts-03 flagged-only / deferred)
- **risk:** low (the `case` membership test must exactly replicate `grep -qFx` semantics
  for the `"<mon> <ws>"` lines — validate with a multi-monitor non-empty set; the
  open-dock `read` must capture the same first-line value `head -n1` produced).
- **depends on:** none

---

## Open Questions

1. **headset cheap source (S3):** Which exact `ioreg`/`defaults` query reliably reports the
   user's specific Bluetooth audio device as connected? Needs validation against the real
   device class before replacing the `system_profiler` awk. Is `blueutil` already installed
   (would be the cleanest, but adds a dependency)?
2. **empty-watcher line 84 (S6 / scripts-03):** Worth adding an `--empty all` per-tick
   snapshot to also eliminate the per-monitor `list-workspaces` fork? It saves one fork per
   non-empty-visible monitor per tick but adds a snapshot + awk filter; net win is small and
   it touches the fallback-ordering logic. Deferred unless the orchestrator wants it.
3. **ethernet /tmp interface cache (S5/plugins-03):** The aggressive variant (cache the
   discovered ethernet iface to /tmp, refresh on long interval/event) is a behavior change.
   Keep deferred, or is a longer `update_freq` on the ethernet item (10-15s) an acceptable
   middle ground given hardware ports rarely change?
4. **S1 `list-windows --all` format:** Confirm `aerospace list-windows --all` is supported
   alongside `--format '%{workspace}|%{app-name}'` in the installed AeroSpace version
   (open-dock-app.sh notes `--all` conflicts with some filtering flags; here no filter is
   applied, so it should be fine — verify).
5. **Verification gate:** Per repo convention, after editing aerospace-driving scripts run
   `aerospace reload-config` and a `sketchybar` reload, then have the user verify spaces
   render (all three states + multi-monitor colors), headset icon, and network labels before
   commit. No notifications, no linting.
