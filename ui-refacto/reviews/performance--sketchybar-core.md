# Performance Review — SketchyBar entry point + items

Slice: `configs/sketchybar/sketchybarrc`, `colors.sh`, `icons.sh`, and every `items/*.sh`.
Lens: runtime efficiency only (subprocess spawns in hot paths, redundant/duplicated work per tick/event, excessive forking). Correctness/style ignored.

## Summary

The static item definitions (colors.sh, icons.sh, and most right-side items) are clean: they are config arrays evaluated once at bar load, and the polling items use sensible `update_freq=5`. Three real performance problems were found, all rooted in how items are *wired* (subscriptions / shared scripts), not in the plugins themselves:

1. The 10 workspace items each independently subscribe to the same `aerospace_workspace_change` event and each spawn `aerospace.sh`, which runs 3 `aerospace` CLI queries — so a single workspace switch fans out to ~30 `aerospace` subprocesses, two of the three queries returning identical data across all 10 items.
2. `sketchybar --update` at the end of `sketchybarrc` force-runs every item script at config load (the comment itself says "never do this in production"), multiplying the fan-out above on every bar (re)start.
3. `network_down` and `network_up` are two separate items both driven by `network_speed.sh` at `update_freq=5`, so the same `route` + `netstat` pipeline (with its grep/awk/head forks) runs twice every 5s, fully computing both directions each time but emitting only one.

---

## performance-sketchybar-core-01 — Workspace-change event fans out to ~30 aerospace subprocesses

**Severity:** high
**File:** `configs/sketchybar/items/spaces.sh:44-46` (and the per-item `script` at line 41)

**Description:**
All 10 workspace items (`space.1`…`space.0`) are created in a loop, each with `script="$PLUGIN_DIR/aerospace.sh $sid"` and each `--subscribe`d to `aerospace_workspace_change`. When that event fires (every workspace switch — one of the hottest user-driven paths in the stack), SketchyBar runs all 10 item scripts. Each `aerospace.sh` invocation spawns three `aerospace` CLI calls (`list-workspaces --visible`, `list-workspaces --focused`, `list-windows --workspace`). The first two are *global* queries whose result is identical for all 10 items, yet they are re-executed 10× per event.

Net cost per single workspace switch: 10 shell processes + ~30 `aerospace` process spawns, ~20 of them redundant.

**Evidence:**
```bash
# items/spaces.sh
script="$PLUGIN_DIR/aerospace.sh $sid"
...
sketchybar --add item space.$sid left    \
           --set space.$sid "${space[@]}" \
           --subscribe space.$sid aerospace_workspace_change mouse.clicked
```
```bash
# plugins/aerospace.sh (invoked once per item)
VISIBLE_WORKSPACES=$(aerospace list-workspaces --monitor all --visible 2>/dev/null)  # global, same for all 10
FOCUSED_WS=$(aerospace list-workspaces --focused 2>/dev/null)                         # global, same for all 10
APP_LIST=$(aerospace list-windows --workspace "$WORKSPACE_ID" ...)                    # per-workspace
```

**Recommendation:**
Drive the workspace render from a single subscribed item instead of 10. One coordinator item subscribed to `aerospace_workspace_change` queries the two global states once (`list-workspaces --visible`, `--focused`) plus `aerospace list-windows --all --format '%{workspace} %{app-name}'` once, then emits a single batched `sketchybar --set space.1 … --set space.0 …`. That collapses ~30 aerospace spawns to ~3 per switch. Keep `mouse.clicked`/`click_script` on the individual items (cheap, fires only on the clicked one). This stays Bash 3.2-compatible (parallel arrays, as `aerospace.sh` already does).

---

## performance-sketchybar-core-02 — `sketchybar --update` force-runs every item script at load

**Severity:** medium
**File:** `configs/sketchybar/sketchybarrc:171-172`

**Description:**
The final `sketchybar --update` forces *every* item script to execute at config load. The inline comment acknowledges this is wrong ("never do this in production"). Combined with finding 01, this means every bar (re)start immediately spawns the full 10-item × 3-query workspace fan-out plus a synchronous run of every polling plugin (cpu, ram, battery, volume, headset, vpn, wifi, ethernet, network_down, network_up). On a stack that restarts the bar on every `aerospace` startup / perf-mode toggle / display-profile flip, this is repeated avoidable work.

**Evidence:**
```bash
# Forcing all item scripts to run (never do this in production)
sketchybar --update
```

**Recommendation:**
Remove the `sketchybar --update` line. Items with `update_freq` already self-populate on their first tick, and event-driven items populate on their first event. If an immediate first paint of a specific item is desired, trigger only that item (`sketchybar --set <item> ...` is already done inline for items with literal `label=` defaults like time/date/ram). Dropping the blanket update removes the startup thundering-herd of script spawns.

---

## performance-sketchybar-core-03 — network_up and network_down double-run the same network_speed pipeline every 5s

**Severity:** medium
**File:** `configs/sketchybar/items/network_down.sh:18-19` and `configs/sketchybar/items/network_up.sh:18-19`

**Description:**
`network_down` and `network_up` are two independent items, both with `update_freq=5` and both `script="$PLUGIN_DIR/network_speed.sh"`. The plugin computes *both* directions on every call (it reads `route` + `netstat` and calculates `SPEED_IN` and `SPEED_OUT`) but only emits the one matching `$NAME`. Because there are two items, the entire pipeline runs twice every 5 seconds. Each run forks: `route -n get default | grep | awk`, then `netstat -ib | grep -w | head -1`, then two more `echo | awk` (bytes in/out), plus `bc` for formatting — roughly 8-10 forks per call, so ~16-20 forks every 5s where ~half is duplicated work already computed by the sibling.

**Evidence:**
```bash
# items/network_down.sh
update_freq=5
script="$PLUGIN_DIR/network_speed.sh"
# items/network_up.sh
update_freq=5
script="$PLUGIN_DIR/network_speed.sh"
```
```bash
# plugins/network_speed.sh — computes both, emits one
SPEED_IN=$(( (BYTES_IN - PREV_IN) / 5 ))
SPEED_OUT=$(( (BYTES_OUT - PREV_OUT) / 5 ))
if [ "$NAME" = "network_up" ]; then ... elif [ "$NAME" = "network_down" ]; then ... fi
```

**Recommendation:**
Make one item the poller and have it set both labels in a single invocation. e.g. keep `network_down` with `update_freq=5` and `script=network_speed.sh`, drop the `script`/`update_freq` from `network_up`, and change the plugin's tail to `sketchybar --set network_down label="$DOWN" --set network_up label="$UP"`. That halves the poll forks (one `route`/`netstat` pipeline per 5s instead of two) while keeping both labels live. (The plugin's per-`$NAME` cache file would consolidate to one, which also removes the now-pointless second cache write.)
