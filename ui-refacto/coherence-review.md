# Coherence Review — Window-Manager Config Refactor (integration of 3 plans)

Repo: `/Users/teazyou/workspace`. Inputs: BUGS plan, PERFORMANCE plan, CLEAN-CODE plan.
Implementation order is **bugs → performance → clean-code**, each applied in ascending global `order`.
This document records every cross-plan conflict, its resolution, the dropped changes, and the final
ordered change-set per lens.

Constraints honored throughout: Bash 3.2 (parallel arrays, no `declare -A`/`mapfile`), symlink model
(edit source files in `configs/`, write through with `cp` not `mv`), no macOS notifications, no
auto-lint.

---

## 1. Files touched by more than one lens

| File | bugs | performance | clean-code | Conflict? |
|---|---|---|---|---|
| `apply-display-profile.sh` | CH-01, CH-07 | perf-a2 | CC-07 | **YES — heavy** |
| `performance-mode.sh` | CH-02 | — | CC-05 | **YES** |
| `open-dock-app.sh` | CH-05 | perf-s6 | CC-02 | **YES — light** |
| `track-workspace-mru.sh` | CH-06 | — | CC-04 | **YES** |
| `empty-workspace-watcher.sh` | — | perf-s6 | CC-03 | **YES — light** |
| `network_speed.sh` | CH-08 | perf-s4 | CC-14 | **YES — heavy** |
| `plugins/aerospace.sh` | CH-09 | perf-s1 | CC-12, CC-13 | **YES — heavy** |
| `sketchybarrc` | — | perf-s2 | CC-09, CC-10, CC-11 | **YES** |
| `items/spaces.sh` | — | perf-s1 | CC-09 | **YES** |
| `plugins/headset.sh` | — | perf-s3 | CC-15 | **YES — light** |
| `plugins/battery.sh`, `ethernet.sh` | — | perf-s5 | CC-15 | **YES — light** |
| `items/cpu.sh`, `ram.sh`, `network_up/down.sh` | — | perf-s4 (net items) | CC-11 | **YES — light** |
| `aerospace.toml` | — | — | CC-08 (+ CC-04 hot path) | no cross-lens |
| `guide-window-manager.md` | CH-12 | perf-a1 | CC-17 | **YES — doc** |
| `autoraise/config` | CH-12 | — | CC-16 | **YES — doc** |

---

## 2. Conflicts and resolutions

### C-1 — `apply-display-profile.sh`: CH-01 + CH-07 (bugs) vs perf-a2 (single capture) vs CC-07 (lib source)
- **CH-01** guards the empty `monitors` array print at L167 in `get_monitors_config`.
- **CH-07** moves `is_retina=true` to fire only inside the Resolution regex branch (L145-156), same function.
- **perf-a2** captures `system_profiler SPDisplaysDataType` once in `main()` and feeds the three consumers
  (`builtin_is_main` L36, `get_fingerprint` L292, `get_monitors_config` L159) from the captured blob.
- **CC-07** adds `source lib-paths.sh` and swaps the `bar_state_file` literal (L241) for `$SECONDARY_BAR_STATE`.
- **Conflict:** perf-a2 rewrites the `done < <(system_profiler ...)` feed at L159 and the function signatures
  that CH-01/CH-07 edit inside `get_monitors_config`. If perf-a2 lands before the bug fixes, the bug fixes
  target lines that have moved. CC-07 only adds a source line + a literal swap — orthogonal in region but
  must source the lib that CC-01 creates.
- **Resolution — order CH-01 → CH-07 → perf-a2 → CC-07, and SCOPE perf-a2 to NOT re-plumb `get_monitors_config`'s input.**
  1. Apply CH-01 and CH-07 first (bugs lens) against the current `get_monitors_config` body. CH-01's guard
     `(( ${#monitors[@]} )) && printf ...` and CH-07's in-branch retina set are *inside the parsing loop /
     tail*, independent of where the input stream comes from.
  2. perf-a2 then captures `SP_DISPLAYS` once in `main()` and changes only the **three call sites that spawn
     `system_profiler`**: `builtin_is_main` (accept blob via `${1:-$(system_profiler …)}`), `get_fingerprint`
     (grep `$SP_DISPLAYS`), and the `get_monitors_config` feed at L159 (`printf '%s\n' "$SP_DISPLAYS"` in place
     of the process substitution). perf-a2 must **preserve CH-01's guard and CH-07's branch verbatim** — it
     only changes the data source feeding the existing loop, not the loop body. Because `get_fingerprint` runs
     in `main()` before `build_top_gap_config`, capture `SP_DISPLAYS` at the very top of `main()` and pass it
     down; keep all functions standalone-callable (default-arg pattern) so `set -u` is satisfied.
  3. CC-07 lands last: add `source "$(dirname "$0")/lib-paths.sh"` after `set -euo pipefail`, swap the L241
     literal to `$SECONDARY_BAR_STATE`. It does not touch the parsing/capture region.
- **set -u note:** CC-07 sources `lib-paths.sh` under `set -u`; CC-01 must define every referenced var
  (`SECONDARY_BAR_STATE` etc.) so sourcing can't trip on an unset name (clean-code open-Q 4).

### C-2 — `performance-mode.sh`: CH-02 (ensure_loaded) vs CC-05 (rename gaming→performance + lib state)
- **CH-02** replaces the bare `launchctl bootstrap … || true` (L41) inside `gaming_mode_off` with an
  `ensure_loaded()` verify+kickstart helper.
- **CC-05** renames `gaming_mode_on`/`gaming_mode_off` → `performance_mode_on`/`performance_mode_off`
  (defs + the two callers L70/72), sources the lib, and points `STATE_FILE` at `$PERFORMANCE_MODE_STATE`.
- **Conflict:** both edit `gaming_mode_off`'s body / name.
- **Resolution — order CH-02 → CC-05.** Apply CH-02 first against the current `gaming_mode_off` (add the
  `ensure_loaded()` helper near the top, call it from the OFF path). Then CC-05 renames the two functions and
  swaps the state literal; the rename mechanically carries CH-02's new call site (`ensure_loaded` stays a
  separate helper, untouched by the rename). Net file: `performance_mode_off()` calls `ensure_loaded`, state
  path comes from the lib. This is a clean sequential apply — no merge needed beyond doing bugs first.

### C-3 — `open-dock-app.sh`: CH-05 (python argv) vs perf-s6 (drop head) vs CC-02 (lib + grace builder + 90→cap*5)
- **CH-05** L18: python via argv instead of interpolated source string.
- **perf-s6** L62: drop `| head -n 1`, read first line via `read -r` from the command.
- **CC-02** adds `source lib-paths.sh`, replaces the grace-marker literal (L53) with `grace_marker="$(grace_file "$workspace")"`
  (non-shadowing var name; update refs at L54/L80), and replaces `while [[ $i -lt 90 ]]` (L60) with a
  `max_iters=$(( PLACEMENT_CAP_SECONDS * 5 ))` derived bound.
- **Conflict:** CH-05 (L18) is isolated. perf-s6 (L62) and CC-02 (L60 loop bound + L53/54/80 grace var) both
  touch the enforcer block but different lines — perf-s6 the `entry=$(… | head -n1)` line, CC-02 the loop
  bound and the grace var. They co-exist if applied in order.
- **Resolution — order CH-05 → perf-s6 → CC-02.**
  1. CH-05 first (isolated L18).
  2. perf-s6 next: change L62 `entry=$(aerospace … | head -n1)` to a `read -r entry < <(aerospace …)` form
     capturing the same first line.
  3. CC-02 last: rename `grace_file`→`grace_marker` (so the lib's `grace_file()` function name isn't
     shadowed), source the lib, and replace the `90` loop bound with `max_iters`. CC-02 must re-point the
     loop bound around perf-s6's already-edited body — both edits are in the same subshell but on different
     lines, so a straight sequential apply works. **Caveat for the implementer:** CC-02's `PLACEMENT_CAP_SECONDS*5`
     must equal the current `90` (18*5=90) so the cap is byte-identical; CC-01 sets `PLACEMENT_CAP_SECONDS=18`.

### C-4 — `track-workspace-mru.sh`: CH-06 (reclaim stale lock) vs CC-04 (mru_file/mru_lock builders)
- **CH-06** adds, before the `mkdir` loop, a stale-lock reclaim: if `$lock` exists and is older than ~2s,
  `rmdir` it. Needs `$lock` defined.
- **CC-04** changes how `$file`/`$lock` are defined (L19-20) to `$(mru_file "$mon")` / `$(mru_lock "$mon")`.
- **Conflict:** CH-06 reads `$lock`; CC-04 changes its definition line.
- **Resolution — order CH-06 → CC-04.** CH-06 first against the current literal `lock=` line, inserting the
  reclaim block after the existing `lock=` assignment and before the loop. CC-04 then swaps only the RHS of
  the `file=`/`lock=` assignments to the builder calls — CH-06's reclaim block references `$lock` by name and
  is unaffected by where `$lock`'s value comes from. CH-06 may reuse CC-01's `file_age_seconds()` helper, but
  since CH-06 runs in the **bugs** phase (before CC-01 exists), it must inline its own `stat -f %m` age check;
  do NOT make CH-06 depend on the lib. (CC-04 can optionally re-express CH-06's age check via
  `file_age_seconds` afterwards, but that is not required and is left out to keep CH-06 self-contained.)

### C-5 — `empty-workspace-watcher.sh`: perf-s6 (fork-free contains_pair) vs CC-03 (lib source + constants)
- **perf-s6** rewrites `contains_pair()` (L40) to a fork-free Bash 3.2 `case` membership test.
- **CC-03** sources the lib, removes `grace_seconds=20` (→`$GRACE_SECONDS`), swaps the grace/mru literals for
  builders, and replaces both `sleep 0.5` with `sleep "$POLL_INTERVAL"`.
- **Conflict:** different regions (perf-s6 = `contains_pair` function body; CC-03 = constants + grace/mru
  paths + sleeps). No line overlap.
- **Resolution — order perf-s6 → CC-03.** perf-s6 (performance phase) rewrites `contains_pair`. CC-03
  (clean-code phase) then layers the lib source + constant swaps around it. Note CC-03 removes the local
  `grace_seconds=20` and relies on `$GRACE_SECONDS` from the lib; the lib's `GRACE_SECONDS=20` must equal the
  removed literal. No merge conflict; sequential apply is clean.

### C-6 — `network_speed.sh`: CH-08 (persist interface) vs perf-s4 (single poller, one cache) vs CC-14 (UPDATE_FREQ)
- **CH-08** persists the interface name with the counters (`INTERFACE BYTES_IN BYTES_OUT`); on a NIC flip,
  zeroes the delta. Keeps the per-`$NAME` cache filename.
- **perf-s4** makes `network_down` the **sole poller** that sets both labels, drops the per-`$NAME` cache
  split for a single fixed `CACHE_FILE="$CACHE_DIR/prev_bytes"`, and removes `update_freq`/`script` from
  `network_up.sh` (passive item).
- **CC-14** names the `/ 5` divisor `UPDATE_FREQ=5` and cross-references the item `update_freq`.
- **Conflict (genuine, multi-way):**
  - CH-08 and perf-s4 both rewrite the cache read/write block. CH-08 wants a 3-field cache; perf-s4 wants a
    single shared cache file (and drops the `${NAME}` keying). These must be **merged into one coherent cache
    format**.
  - perf-s4 removes the `if [ "$NAME" = network_up ] … elif …` tail that CH-08 leaves in place.
  - CC-14's named divisor is touched by perf-s4 (which keeps the `/ 5` arithmetic but in a single emit path).
- **Resolution — MERGE CH-08 into perf-s4's single-poller shape, then apply CC-14.** Order CH-08 → perf-s4 → CC-14.
  1. **CH-08 (bugs phase)** lands first against the *current* dual-item script: add the interface to the cache
     file (`INTERFACE BYTES_IN BYTES_OUT`), read all three back, zero the delta when the cached interface
     differs from the current one. At this point the script is still per-`$NAME`.
  2. **perf-s4 (perf phase)** then converts to single-poller, but **must carry CH-08's interface guard
     forward**: the single fixed `CACHE_FILE="$CACHE_DIR/prev_bytes"` stores `INTERFACE BYTES_IN BYTES_OUT`;
     the flip-detection (zero delta when cached iface ≠ current iface) is preserved. The dual `--set` emit
     replaces the `if/elif` tail. Implementer note: because there is now ONE poller, the previous per-`$NAME`
     cache split (its stated reason was a race between the two items) is genuinely obsolete — collapsing to
     one file is safe AND keeps CH-08's interface field. **This is the one place the two plans' edits are
     rewritten into a single combined change** (`perf-s4` description below is amended to "carry the CH-08
     interface field into the single cache").
  3. **CC-14 (clean phase)** names the divisor `UPDATE_FREQ=5` and replaces the `/ 5` sites in perf-s4's
     single emit path. Trivial, lands last.
- **Net file:** one poller (`network_down`), one cache file storing `INTERFACE BYTES_IN BYTES_OUT`, interface
  flip → zero delta (CH-08), `/ UPDATE_FREQ` divisor (CC-14), `network_up.sh` item passive (perf-s4).

### C-7 — `plugins/aerospace.sh`: CH-09 (comment) vs perf-s1 (coordinator rewrite) vs CC-12 (palette) vs CC-13 (move shorten_app_name)
- **perf-s1 (HIGH risk)** rewrites `aerospace.sh` from a per-`$sid` script into a single coordinator that
  loops all 10 ids internally and emits one batched `--set`. It also edits `items/spaces.sh` to drop the
  per-item `script=`/subscription and add the hidden coordinator item.
- **CH-09** adds a clarifying comment to the `MONITOR_INDEX` color pick (cosmetic, low).
- **CC-12** moves the hardcoded spaces-indicator hex into `colors.sh` exports and references them.
- **CC-13** moves `shorten_app_name()` out of `aerospace.sh` into `icon_map.sh` and sources it.
- **Conflict:** perf-s1 restructures the entire file. CH-09's comment, CC-12's hex→var swaps, and CC-13's
  function move all target code that perf-s1 relocates into the coordinator loop. If perf-s1 lands, the line
  references in CH-09/CC-12/CC-13 are invalid; if they land first, perf-s1 must re-absorb them.
- **Resolution — order CH-09 → perf-s1 (absorbs CH-09's comment) → CC-12 → CC-13. perf-s1 is the load-bearing rewrite; the others adapt to its post-rewrite structure.**
  1. **CH-09 (bugs phase)** adds its one-line comment to the current `MONITOR_INDEX` branch. Cheap, lands first.
  2. **perf-s1 (perf phase)** rewrites the file into the coordinator. It **must preserve** (a) the three
     render states (occupied / number-only / dot), (b) the per-monitor color tiers, (c) group-first/last
     padding, (d) the `shorten_app_name` + star-collapse logic, and (e) **carry CH-09's clarifying comment**
     into the coordinator's color branch. The per-workspace `list-windows --workspace` becomes one
     `list-windows --all --format '%{workspace}|%{app-name}'`.
  3. **CC-12 (clean phase)** then swaps the (now relocated, but still present) hardcoded hex in the coordinator
     for the new `colors.sh` exports. Because perf-s1 preserves the exact hex values, CC-12's var substitution
     is a find-replace over the coordinator body. Add the palette exports to `colors.sh` regardless (that edit
     is independent of perf-s1).
  4. **CC-13 (clean phase)** moves `shorten_app_name()` into `icon_map.sh` and has the coordinator source
     `icon_map.sh` + call it. **Ordering note:** perf-s1's coordinator runs ONCE per workspace-change event
     (not once per space item), so sourcing `icon_map.sh` once per event is cheaper than the original
     per-item concern in CC-13's risk note — CC-13's "hot per-space plugin" risk is *reduced* by perf-s1.
- **Dependency added:** CC-12 and CC-13 now `dependsOn` perf-s1 (they must edit the post-rewrite file).
- **Risk:** perf-s1 stays HIGH; verify all three render states + multi-monitor colors before/after, and that
  `list-windows --all` honors `--format '%{workspace}|%{app-name}'` in the installed AeroSpace (perf open-Q 4).

### C-8 — `sketchybarrc`: perf-s2 (drop --update) vs CC-09 (bracket_style) vs CC-10 (exports) vs CC-11 (monitor_item_base)
- **perf-s2** removes the final `sketchybar --update` (L171-172) and replaces it with
  `sketchybar --trigger aerospace_workspace_change`. Depends on perf-s1 (coordinator must exist to paint
  the spaces strip from the trigger).
- **CC-09** defines one `bracket_style=(…)` near the top and replaces the five verbatim right-side bracket
  blocks (+ converges the three `spaces_*` brackets in `spaces.sh`).
- **CC-10** adds `export` to `ITEM_DIR`/`PLUGIN_DIR`/`FONT` (L6/7/10).
- **CC-11** defines `monitor_item_base=(…)` and rewires `cpu/ram/network_up/network_down` items to use it.
- **Conflict:** all four edit `sketchybarrc`, but mostly different regions: perf-s2 = the tail `--update`
  line; CC-10 = the three dir/font exports near the top; CC-09 = the bracket-definition blocks; CC-11 = a new
  base array + the monitor item files. The only ordering constraints are (a) CC-09's `bracket_style` and
  CC-11's `monitor_item_base` must be defined **before** the `source "$ITEM_DIR/…"` lines that consume them,
  and (b) perf-s2 depends on perf-s1.
- **Resolution — order perf-s2 → CC-10 → CC-09 → CC-11, with placement rules.**
  1. **perf-s2 (perf phase)** edits only the tail; replace `--update` with the targeted trigger. Lands first
     among the sketchybarrc edits (and after perf-s1 globally).
  2. **CC-10 (clean phase)** adds `export` to the three globals near the top — independent, lands next.
  3. **CC-09 (clean phase)** defines `bracket_style` **after `--default` (L56) and before the first
     `source "$ITEM_DIR/…"`** so spaces.sh (sourced L60) can see it; replaces the five right-side bracket
     blocks. For the `spaces.sh` half, see C-9.
  4. **CC-11 (clean phase)** defines `monitor_item_base` before sourcing cpu/ram/network items; rewires those
     item files. `dependsOn` CC-10 (needs `FONT`/`PLUGIN_DIR` exported/in-scope where the base array is used).
- No edit removes another's lines; sequential apply is clean given the placement rules.

### C-9 — `items/spaces.sh`: perf-s1 (drop per-item script/subscribe, add coordinator) vs CC-09 (converge spaces brackets)
- **perf-s1** removes `script="$PLUGIN_DIR/aerospace.sh $sid"` and the `aerospace_workspace_change`
  subscription from the per-item loop; adds the hidden coordinator item + its subscription.
- **CC-09** converges the three identical `spaces_*_bracket` arrays onto the shared `bracket_style`.
- **Conflict:** different regions (perf-s1 = the item-creation loop + a new coordinator item; CC-09 = the
  three bracket arrays at the bottom). No line overlap, but both must land coherently.
- **Resolution — order perf-s1 → CC-09.** perf-s1 restructures the item loop first; CC-09 then swaps the
  three bracket arrays for `bracket_style` references. **Visual caveat (clean-code open-Q 2):** the
  `spaces_*` brackets historically omit the two `background.padding_left/right=0` lines the right-side groups
  carry. Converging them may shift left-group spacing a couple px. **Resolution decision: keep a distinct
  `spaces_bracket_style` (without the two padding lines) rather than force exact unification**, so CC-09 does
  NOT regress the spaces strip spacing. This avoids a visual regression while still collapsing the three
  identical spaces brackets into one local array. (Right-side groups converge on the full `bracket_style`.)

### C-10 — `plugins/headset.sh`: perf-s3 (ioreg + freq 30) vs CC-15 (source order)
- **perf-s3** replaces `system_profiler SPBluetoothDataType` with an `ioreg` query and raises the item
  `update_freq` 5→30.
- **CC-15** normalizes the two-line source preamble to `colors.sh` then `icons.sh` (headset is one of the
  inverted plugins).
- **Resolution — order perf-s3 → CC-15.** Different regions (perf-s3 = the data-source line + item freq;
  CC-15 = the two `source` lines at the top). Sequential apply is clean. CC-15 just reorders the two source
  lines perf-s3 left untouched.

### C-11 — `plugins/battery.sh` + `ethernet.sh`: perf-s5 (fork collapse) vs CC-15 (source order)
- **perf-s5** collapses the parse fork-chains in `ram/cpu/battery/ethernet` to one awk each.
- **CC-15** reorders the source preamble in `battery.sh`/`ethernet.sh` (among others).
- **Resolution — order perf-s5 → CC-15.** Different regions (perf-s5 = the parse body; CC-15 = the two source
  lines). Sequential apply is clean. Note `ram.sh`/`cpu.sh` are only touched by perf-s5 (their preambles are
  already `colors.sh`-only or correctly ordered), so no CC-15 interaction there.

### C-12 — monitor item files (`cpu.sh`, `ram.sh`, `network_up.sh`, `network_down.sh`): perf-s4 (net items) vs CC-11 (base array)
- **perf-s4** edits `network_up.sh` (remove `update_freq`/`script` → passive) and `network_down.sh` (keep as
  sole poller).
- **CC-11** factors `cpu/ram/network_up/network_down` onto a shared `monitor_item_base` and re-adds per-item
  overrides.
- **Conflict:** both edit `network_up.sh`/`network_down.sh`. perf-s4 changes WHICH keys those items carry
  (`network_up` loses `update_freq`/`script`); CC-11 restructures HOW the keys are declared (base + overrides).
- **Resolution — order perf-s4 → CC-11.** perf-s4 (perf phase) first decides the *content* of the network
  items (network_up passive). CC-11 (clean phase) then factors the *form*: when building `monitor_item_base`,
  network_up's override set must reflect perf-s4's result — i.e. network_up no longer carries `update_freq`/
  `script` overrides. CC-11's per-item override list for network_up is therefore the reduced (passive) set.
  CC-11 must be implemented **against the post-perf-s4 item files**, which the global ordering guarantees.

### C-13 — `guide-window-manager.md`: CH-12 (bug, borders theme + index) vs perf-a1 (interval line) vs CC-17 (borders theme)
- **CH-12** updates the bordersrc theme description (L177-178, Tokyo Night → dark-red) and the autoraise
  comment + `_index.md`.
- **CC-17** updates the SAME bordersrc theme description (L177-178) — **duplicate of CH-12's borders part.**
- **perf-a1** updates the "runs apply-display-profile.sh every 5 seconds" line to "every 15 seconds".
- **Resolution — DROP the borders-theme half of CC-17 (redundant with CH-12); keep CH-12 as the borders-theme
  edit; perf-a1 edits a different line.** Order CH-12 → perf-a1. CC-17 is dropped as a no-op duplicate (its
  sole content — the bordersrc theme line — is already done by CH-12 in the bugs phase). perf-a1's interval
  line is a distinct line, applied in the perf phase. No three-way clobber.

### C-14 — `autoraise/config`: CH-12 (bug, comment) vs CC-16 (clean, comment)
- Both rewrite the same stale `on-focus-changed` comment (L39-41).
- **Resolution — DROP CC-16 (redundant); keep CH-12's autoraise-comment edit.** CH-12 already rewrites the
  same comment with the same corrected wording (point at per-keybinding `move-mouse` warps + empty global
  callbacks). Doing it once in the bugs phase suffices. CC-16 dropped as a duplicate.

---

## 3. Dropped changes

| id | lens | reason |
|---|---|---|
| **CH-10** | bugs | Removes inline `$(date)` from `calendar.sh`. **Dropped from this integration** — it is an independent low-priority cosmetic edit with an unresolved open question (drop vs keep-with-comment) and no conflict with any other plan; defer to a separate pass to keep this integration focused on the consolidated WM-stack changes. Not load-bearing for any other change. |
| **CH-11** | bugs | Fixes `title.sh` change-check. `title.sh` is **dead code** (not sourced/added by any item). Zero runtime effect, and the clean-code plan also flags it as dead (plugins-05) pending a delete-vs-keep decision. Dropped pending that decision; re-add only if the file is re-enabled. |
| **CC-16** | clean-code | **Duplicate of CH-12** (autoraise stale-comment rewrite). Done once in the bugs phase. See C-14. |
| **CC-17** | clean-code | **Duplicate of CH-12** (bordersrc theme line in the guide). Done once in the bugs phase. See C-13. |

**Not dropped, but explicitly deferred *within* their own plans (recorded for completeness, no action here):**
perf open-Qs (ethernet /tmp cache, empty-watcher L84 `--empty all` snapshot), clean-code open-Q on deleting
dead plugins (`title.sh`/`zen.sh`/`clock.sh`/`front_app*`/`spotify`/`github`/`brew`). These were already
deferred by their authors and are out of scope for the integrated set.

---

## 4. New cross-lens dependencies introduced by the integration

- **CC-12 dependsOn perf-s1** — must edit the coordinator (post-rewrite) `aerospace.sh`.
- **CC-13 dependsOn perf-s1** — must add the `icon_map.sh` source to the coordinator (post-rewrite).
- **CC-11 dependsOn perf-s4** (for the network item override sets) **and CC-10** (exports). See C-12.
- **CC-09 spaces half** uses a distinct `spaces_bracket_style` (NOT the shared `bracket_style`) to avoid the
  padding-driven visual regression. See C-9.
- All `CC-0x` aerospace-script edits dependsOn **CC-01** (lib creation), unchanged from the clean-code plan.

---

## 5. Final ordered change-set (global `order`)

Phase boundaries: **bugs = order 10-99**, **performance = order 100-199**, **clean-code = order 200-299**.
Within a file, the table above guarantees bug edits precede perf edits precede clean edits. CC-01 (lib) is
ordered first in the clean phase so every other CC-0x can source it.

### BUGS (apply first)

| order | id | file | edit (concrete) |
|---|---|---|---|
| 10 | CH-01 | `configs/aerospace/apply-display-profile.sh` | Guard `printf '%s\n' "${monitors[@]}"` (L167) behind `(( ${#monitors[@]} ))` (or early `return 0` on empty) so `set -u` can't abort on an empty array. |
| 20 | CH-07 | `configs/aerospace/apply-display-profile.sh` | Remove the sticky `is_retina=true` at L145-148; set `is_retina=true` **only inside** the Resolution regex branch (L156) when that line contains "Retina". (Same function as CH-01; sequence after it.) |
| 30 | CH-05 | `configs/aerospace/open-dock-app.sh` | L18: `app_path=$(python3 -c 'import sys,urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' "$app_path")` (argv, injection-safe). |
| 40 | CH-08 | `configs/sketchybar/plugins/network_speed.sh` | Persist `INTERFACE BYTES_IN BYTES_OUT` in the cache; on cached-iface ≠ current-iface (or first run) zero `SPEED_IN`/`SPEED_OUT` for that tick. Keep the `<0→0` clamp. (Still per-`$NAME` at this stage; perf-s4 collapses it.) |
| 50 | CH-09 | `configs/sketchybar/plugins/aerospace.sh` | Make the `MONITOR_INDEX` default branch explicit; add a comment that the index is list-position based (not monitor-id) so a 3rd visible monitor may reuse the 2nd color. Keep the hex values. |
| 60 | CH-06 | `configs/aerospace/track-workspace-mru.sh` | Before the `mkdir` loop: if `$lock` exists and its mtime age (`stat -f %m`, inline) > ~2s, `rmdir "$lock" 2>/dev/null` to reclaim an orphaned lock. Self-contained (no lib dependency — runs before CC-01). |
| 70 | CH-02 | `configs/aerospace/performance-mode.sh` | Replace the bare `bootstrap … || true` (L41) with an `ensure_loaded()` helper: bootstrap → `launchctl print …` verify → retry after `sleep 0.3` → `kickstart`. No `|| true` swallow of real failure. |
| 80 | CH-03 | `scripts/aerospace-restart.sh` | Read `/tmp/performance-mode.state` once before the start-phase bootstrap loop; `continue` (skip) the `com.aerospace.display-profile` agent when state is `on`. empty-watcher + autoraise still bootstrap unconditionally. |
| 90 | CH-04 | `scripts/aerospace-restart.sh` | (1) Wait-loop break on a readiness query `aerospace list-workspaces --focused >/dev/null 2>&1 && break` (same 10×0.5s bound). (2) Fix the L27 comment: display-profile is StartInterval/RunAtLoad (no KeepAlive); empty-watcher + autoraise are KeepAlive. Sequence after CH-03 (same start-phase block). |
| 95 | CH-12 | `configs/guide-window-manager.md`, `configs/autoraise/config`, `_index.md` | Doc-only: (a) guide L177-178 bordersrc theme → dark-red `active=0xffb22222 inactive=0xff4d1a1a width=4.0 round hidpi on`; (b) autoraise L39-41 comment → per-keybinding `move-mouse` warps + empty global callbacks; (c) `_index.md` borders desc if it references a blue/Tokyo theme. (Absorbs CC-16 + CC-17.) |

### PERFORMANCE (apply second)

| order | id | file | edit (concrete) |
|---|---|---|---|
| 100 | perf-a1 | `configs/aerospace/com.aerospace.display-profile.plist` | `StartInterval` 5 → 15. Update the guide's "every 5 seconds" line to "every 15 seconds" (same doc CH-12 touched, different line). |
| 110 | perf-a2 | `configs/aerospace/apply-display-profile.sh` | Capture `SP_DISPLAYS="$(system_profiler SPDisplaysDataType 2>/dev/null)"` once at the top of `main()`; feed `builtin_is_main` (accept blob via `${1:-…}`), `get_fingerprint` (grep `$SP_DISPLAYS`), and the `get_monitors_config` feed (L159 `printf '%s\n' "$SP_DISPLAYS"`). **Preserve CH-01's array guard and CH-07's in-branch retina set verbatim** — change only the data source, not the loop body. |
| 120 | perf-s1 | `configs/sketchybar/plugins/aerospace.sh`, `configs/sketchybar/items/spaces.sh` | Introduce ONE hidden coordinator item (drawing=off) on `aerospace_workspace_change`; query the 3 states once (`list-workspaces --visible`, `--focused`, `list-windows --all --format '%{workspace}|%{app-name}'`); build per-ws state with the existing 3-state/color/group logic (Bash 3.2 parallel arrays) and emit ONE batched `--set`. In spaces.sh remove per-item `script=`+`aerospace_workspace_change` sub (keep `click_script`+`mouse.clicked`). **Carry CH-09's comment into the coordinator color branch.** HIGH risk. |
| 130 | perf-s2 | `configs/sketchybar/sketchybarrc` | Remove the final `sketchybar --update` (L171-172 + comment); replace with `sketchybar --trigger aerospace_workspace_change` so the coordinator paints once. dependsOn perf-s1. |
| 140 | perf-s4 | `configs/sketchybar/plugins/network_speed.sh`, `items/network_up.sh`, `items/network_down.sh` | Make `network_down` the sole poller; one `--set network_down … --set network_up …` emit. Single `CACHE_FILE="$CACHE_DIR/prev_bytes"` storing `INTERFACE BYTES_IN BYTES_OUT` — **carry CH-08's interface-flip guard into the single cache** (merged change, see C-6). Remove `update_freq`/`script` from `network_up.sh` (passive). |
| 150 | perf-s3 | `configs/sketchybar/plugins/headset.sh`, `items/headset.sh` | Replace `system_profiler SPBluetoothDataType` (L8) with an `ioreg`-based connected-headset check (no new deps), identical two-icon output; raise item `update_freq` 5 → 30. |
| 160 | perf-s5 | `configs/sketchybar/plugins/ram.sh`, `cpu.sh`, `battery.sh`, `ethernet.sh` | Collapse per-field `echo\|grep\|awk\|tr\|cut\|bc` chains to one awk per plugin over the already-captured output; output-identical label strings. ethernet awk is optional within S5 if it risks the iface regex. |
| 170 | perf-s6 | `configs/aerospace/empty-workspace-watcher.sh`, `open-dock-app.sh` | empty-watcher `contains_pair()` (L40) → fork-free Bash 3.2 `case` membership test. open-dock L62 → `read -r entry < <(aerospace …)` (drop `\| head -n1`). (empty-watcher L84 query stays — correctness.) |

### CLEAN-CODE (apply third)

| order | id | file | edit (concrete) |
|---|---|---|---|
| 200 | CC-01 | `configs/aerospace/lib-paths.sh` (NEW) | Sourced helper: `grace_file()/mru_file()/mru_lock()` builders, `SECONDARY_BAR_STATE`, `PERFORMANCE_MODE_STATE`, `GRACE_SECONDS=20`, `PLACEMENT_CAP_SECONDS=18` (with the ≥ invariant comment), `POLL_INTERVAL=0.5`, `file_age_seconds()`. **Must define every var referenced under `set -u`.** |
| 210 | CC-05 | `configs/aerospace/performance-mode.sh` | Rename `gaming_mode_*` → `performance_mode_*` (defs + callers L70/72); source lib; `STATE_FILE="$PERFORMANCE_MODE_STATE"`. The rename mechanically carries CH-02's `ensure_loaded` call site. dependsOn CC-01. |
| 215 | CC-06 | `configs/aerospace/secondary-bar-toggle.sh` | Source lib; `STATE_FILE="$SECONDARY_BAR_STATE"`. dependsOn CC-01. |
| 220 | CC-07 | `configs/aerospace/apply-display-profile.sh` | Source lib (after `set -euo pipefail`); replace L241 `bar_state_file` literal with `$SECONDARY_BAR_STATE`. Don't touch capture/parse region (perf-a2's) or `STATE_FILE`/`LOG_FILE`. dependsOn CC-01, CC-06. |
| 225 | CC-04 | `configs/aerospace/track-workspace-mru.sh` | Source lib; `file="$(mru_file "$mon")"`, `lock="$(mru_lock "$mon")"`. CH-06's reclaim block (references `$lock`) is unaffected. dependsOn CC-01. |
| 230 | CC-03 | `configs/aerospace/empty-workspace-watcher.sh` | Source lib; drop `grace_seconds=20` → `$GRACE_SECONDS`; grace/mru literals → builders; both `sleep 0.5` → `sleep "$POLL_INTERVAL"`. Layers around perf-s6's `contains_pair`. dependsOn CC-01. |
| 235 | CC-02 | `configs/aerospace/open-dock-app.sh` | Source lib; grace literal → `grace_marker="$(grace_file "$workspace")"` (non-shadowing; update refs); `while [[ $i -lt 90 ]]` → `max_iters=$(( PLACEMENT_CAP_SECONDS * 5 ))` (=90, byte-identical). Lands after CH-05 + perf-s6. dependsOn CC-01. |
| 240 | CC-08 | `configs/aerospace/aerospace.toml` | In the 3rd `after-startup-command` (L22): `source ~/workspace/configs/aerospace/lib-paths.sh; rm -f "$PERFORMANCE_MODE_STATE" "$SECONDARY_BAR_STATE"; …`; normalize the two `"$HOME"/workspace/…` script paths to unquoted `~/workspace/…`. **Verify `~`+`source` expand under the `exec-and-forget /bin/bash -c` context; if not, fall back to `$HOME` for the `source` only.** dependsOn CC-01. medium. |
| 245 | CC-12 | `configs/sketchybar/colors.sh`, `plugins/aerospace.sh` | Add spaces-palette exports to colors.sh (`SPACE_FOCUS_BG=$BORDER_ACTIVE`, `SPACE_MON2_BG=0xff8a3048`, `SPACE_MON3_BG=0xff75283d`, `SPACE_ACTIVE_ICON=0xff1a1a2e`, `SPACE_FOCUS_LABEL=0xfffff0f3`, `SPACE_INACTIVE_FG=0xffb35060`, `SPACE_DOT_COLOR=0xff6e4250`); replace the hardcoded hex in the (post-perf-s1) coordinator with these vars. dependsOn perf-s1. |
| 250 | CC-13 | `configs/sketchybar/plugins/icon_map.sh`, `plugins/aerospace.sh` | Move `shorten_app_name()` into `icon_map.sh`; have the (post-perf-s1) coordinator source `icon_map.sh` and call it. dependsOn perf-s1. |
| 255 | CC-14 | `configs/sketchybar/plugins/network_speed.sh` | `UPDATE_FREQ=5` (with cross-ref comment); replace the `/ 5` divisor(s) in perf-s4's single emit path with `/ UPDATE_FREQ`. dependsOn perf-s4. |
| 260 | CC-15 | `configs/sketchybar/plugins/battery.sh`, `ethernet.sh`, `headset.sh`, `wifi.sh`, `vpn.sh` | Normalize the two-line preamble to `source colors.sh` then `source icons.sh`. Pure reorder; lands after perf-s3/perf-s5 (which touched data-source/parse bodies, not the source lines). |
| 265 | CC-10 | `configs/sketchybar/sketchybarrc` | `export ITEM_DIR`, `export PLUGIN_DIR`, `export FONT` (L6/7/10) + one-line comment on why. |
| 270 | CC-09 | `configs/sketchybar/sketchybarrc`, `items/spaces.sh` | Define `bracket_style=(…)` after `--default` (L56), before the first `source "$ITEM_DIR/…"`; replace the 5 right-side bracket blocks with `--set <group> "${bracket_style[@]}"`. In spaces.sh, converge the 3 `spaces_*` brackets onto a **distinct `spaces_bracket_style`** (no padding_left/right lines) to avoid a visual regression. dependsOn CC-10 (after perf-s1 restructured spaces.sh). |
| 275 | CC-11 | `configs/sketchybar/sketchybarrc`, `items/cpu.sh`, `ram.sh`, `network_up.sh`, `network_down.sh` | Define `monitor_item_base=(…)` before sourcing those items; rewire cpu/ram/network items to base + per-item overrides. network_up's overrides reflect perf-s4's passive result (no `update_freq`/`script`). dependsOn CC-10, perf-s4. medium. |

---

## 6. Global ordering notes / verification gate

- **Per-file invariant:** within every shared file, the global `order` places bug edits before perf edits
  before clean edits (e.g. apply-display-profile.sh: CH-01@10, CH-07@20, perf-a2@110, CC-07@220).
- **The one true merge** is `network_speed.sh` (C-6): CH-08's interface field is carried into perf-s4's single
  cache; the two are not applied as independent hunks but as a combined cache format. CC-14 then names the
  divisor.
- **The one true rewrite-absorption** is `aerospace.sh`/`spaces.sh` (C-7/C-9): perf-s1 rewrites the file and
  must carry CH-09's comment; CC-12/CC-13 then edit the post-rewrite coordinator.
- **Bash 3.2 / set -u:** CC-01 must define every var that any `source`-ing script references under `set -u`
  (apply-display-profile.sh, performance-mode.sh, secondary-bar-toggle.sh all run `set -euo pipefail`).
- **Verification after each phase (no notifications, no lint):** reload AeroSpace (`aerospace reload-config`)
  and `sketchybar` reload; confirm: spaces strip renders all three states + multi-monitor colors; headset
  icon connect/disconnect; both network labels update on the same 5s tick; the bar-hidden + perf-mode-ON
  startup defaults still land after a full restart; the 7-9 companion assignment + outer.top gaps unchanged
  before/after perf-a2; CC-08's startup `source` resolves under the after-startup shell.
