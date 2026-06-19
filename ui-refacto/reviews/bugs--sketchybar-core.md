# Bugs / Correctness Review — SketchyBar entry point + items

**Slice:** `configs/sketchybar/sketchybarrc`, `colors.sh`, `icons.sh`, and all `items/*.sh`
**Lens:** Correctness & reliability defects only (shell quoting, word-splitting, Bash 3.2 compat, event wiring, edge cases).

## Summary

This slice is almost entirely **declarative** SketchyBar configuration: each file builds a bash array of `key=value` pairs and passes it to `sketchybar --set`. There is essentially no control flow, no polling/lock logic, no state files, and no monitor-name handling in these files (that lives in the plugins and aerospace slices). I read every file fully and cross-checked the event wiring against the aerospace TOML and the plugins directory.

No high- or medium-severity correctness bugs were found. The custom event `aerospace_workspace_change` is correctly declared (`spaces.sh:11`) and triggered (`aerospace.toml`); `volume_change`, `wifi_change`, `power_source_change`, and `system_woke` are all SketchyBar built-in events so subscribing without `--add event` is valid. The one `for` loop (`spaces.sh:14`) uses `"${!ARR[@]}"`, which is Bash 3.2 safe; there is no `declare -A` / `mapfile` / `&>>` anywhere in the slice.

Only one genuinely verifiable, low-severity robustness issue is reported below.

---

## bugs-sketchybar-core-01 — `time`/`date` items embed a definition-time `$(date)` that masks a stale first paint

**Severity:** low
**File:** `configs/sketchybar/items/calendar.sh:16`, `:38`

**Description:**
Both items hard-code an initial label computed at config-load time:

```bash
label="$(date '+%H:%M')"   # time_item, line 16
label="$(date '+%a %d')"   # date_item, line 38
```

while also defining `script="$PLUGIN_DIR/time.sh"` / `date.sh` with `update_freq`. This is not a crash, but it is a correctness smell: the embedded `$(date)` is evaluated **once**, in the wall-clock second the bar config is sourced. If the config reload (e.g. `aerospace-restart.sh`, performance-mode toggle, or `sketchybar --reload`) and the first `update_freq` tick straddle a minute boundary, the bar can briefly show a label that is up to one minute stale until the plugin script runs. The embedded value duplicates what the plugin already produces, so the two can disagree.

**Evidence:** `label="$(date '+%H:%M')"` at `calendar.sh:16` and `label="$(date '+%a %d')"` at `:38`, each paired with a `script=` + `update_freq` that recomputes the same field.

**Recommendation:** Drop the inline `$(date ...)` and rely on the plugin (the bar fires every item's `script` once on `--update`, which `sketchybarrc:172` already does), or accept the redundancy as an intentional fast first paint and document it. Low priority; no functional breakage.

---

## Notes (not reported as findings)

- **Disabled files** (`apple.sh`, `settings.sh`, `front_app.sh`, `brew.sh`, `github.sh`, `spotify.sh`) are not sourced by `sketchybarrc`, so any issues in them are dormant. They were scanned; `apple.sh`'s `\$NAME` escaping is correct for deferred expansion, and `front_app.sh`'s `aerospace_workspace_change` subscription would resolve correctly if enabled.
- `PLUGIN_DIR`/`ITEM_DIR`/`FONT` (`sketchybarrc:6,7,10`) are not `export`ed, but every item file is `source`d into the same shell, so the variables are in scope and the `$PLUGIN_DIR/...` `script=` values expand to absolute paths at source time. Correct.
- All `script=`-referenced plugins (`time.sh`, `date.sh`, `network_speed.sh`, `aerospace.sh`, etc.) exist in `plugins/`. No dangling references.
- Spacer item names (`spacer0..3` on the right, `spaces_spacer_main`/`spaces_spacer_secondary` on the left) and `space.0..space.9` are all unique; no `--add item` name collisions.
- Bracket membership (`resources ram cpu battery`, `traffic network_down network_up`, etc.) matches the source/add order, so the adjacency SketchyBar requires for brackets holds.
