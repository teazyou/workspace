# Bugs / Correctness Review — SketchyBar Plugins

**Slice:** `configs/sketchybar/plugins/*.sh` (25 files)
**Lens:** Bugs / correctness only (no style, no pure perf).

## Summary

I read all 25 plugin scripts. Only `aerospace.sh` is actively wired into the bar
(via `items/spaces.sh`); most others (`title.sh`, `zen.sh`, `space.sh`,
`aerospace_mode.sh`, `front_app_display.sh`, `network_speed.sh`, `spotify.sh`,
`github.sh`, `brew.sh`) are disabled / not sourced per the guide, so defects there
are real but low-impact today.

I verified several suspected bugs on the live system and **cleared** them:
`battery.sh`'s `grep -Eo "\d+%"` works on this macOS's real `/usr/bin/grep`;
`cpu.sh` / `ram.sh` field offsets parse correctly; `headset.sh`'s
`Connected:` / `Not Connected:` awk anchors still exist in `system_profiler`
output. The repo is Bash-3.2-clean in the one hot path (`aerospace.sh` uses
parallel indexed arrays, no `declare -A` / `mapfile`).

The findings below are the genuine correctness defects that remain. The slice is
otherwise solid; the highest-impact file (`aerospace.sh`) has only a minor
multi-monitor colour bug.

---

## bugs-sketchybar-plugins-01 — `aerospace.sh`: `MONITOR_INDEX` is positional in the visible list, not tied to a monitor

- **Severity:** low
- **File:** `configs/sketchybar/plugins/aerospace.sh:70-79`, used at `:132-140`

**Description.** The secondary/tertiary highlight colour is chosen from
`MONITOR_INDEX`, but `MONITOR_INDEX` is just the 1-based position of the
workspace inside the `aerospace list-workspaces --monitor all --visible` output —
which is ordered by monitor-id, and *includes the focused workspace*. The code
assumes that position maps to "2 = secondary, 3 = tertiary", which only holds by
accident of ordering.

**Evidence.**
```sh
MONITOR_COUNT=0
for ws in $VISIBLE_WORKSPACES; do
    MONITOR_COUNT=$((MONITOR_COUNT + 1))
    if [ "$ws" = "$WORKSPACE_ID" ]; then
        IS_VISIBLE=true
        if [ "$ws" != "$FOCUSED_WS" ]; then
            MONITOR_INDEX=$MONITOR_COUNT
        fi
    fi
done
...
    if [ "$MONITOR_INDEX" -eq 2 ]; then
        BG_COLOR="0xff8a3048"
    elif [ "$MONITOR_INDEX" -ge 3 ]; then
        BG_COLOR="0xff75283d"
```
Live check: `list-workspaces --monitor all --visible` printed `3\n7` with `3`
focused. If AeroSpace instead listed the secondary monitor's workspace first
(focused workspace second), a non-focused visible workspace would land on
`MONITOR_INDEX=1` → the `else` branch, and on a 3-monitor rig the
tertiary monitor can be coloured as secondary (`8a3048`) or vice-versa depending
purely on enumeration order. Impact is contained because the index-2 and `else`
branches use the same colour, so only the 3rd monitor's colour is actually at
risk.

**Recommendation.** Derive the colour from the workspace's real monitor identity,
e.g. `aerospace list-workspaces --monitor all --visible --format '%{monitor-id} %{workspace}'`
and key the colour off `monitor-id` (or focused vs. each non-focused monitor-id),
instead of the loop counter.

---

## bugs-sketchybar-plugins-02 — `title.sh`: change-detection grep never matches SketchyBar's JSON, re-animates every tick

- **Severity:** medium (in a currently-disabled plugin → low effective impact)
- **File:** `configs/sketchybar/plugins/title.sh:27`

**Description.** The "only animate if the label changed" guard parses
`sketchybar --query title_proxy` with `grep -o '"value":"[^"]*"'`. SketchyBar's
`--query` emits pretty-printed JSON with a space after the colon
(`"value": "..."`), so the no-space pattern `"value":"..."` never matches.
`CURRENT_LABEL` is therefore always empty, the `!=` test is always true, and the
three-stage drop-in animation fires on **every** invocation — defeating the whole
guard and causing constant title jitter. It also extracts the first `"value":`
in the document, which is not guaranteed to be the label's value.

**Evidence.**
```sh
CURRENT_LABEL=$(sketchybar --query title_proxy 2>/dev/null | grep -o '"value":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ "$CURRENT_LABEL" != "$LABEL" ]; then
    ...
```

**Recommendation.** Parse with `jq` (already used in `zen.sh` / `volume_click.sh`):
`CURRENT_LABEL=$(sketchybar --query title_proxy 2>/dev/null | jq -r '.label.value')`.

---

## bugs-sketchybar-plugins-03 — `network_speed.sh`: one wrong reading after an interface switch, and `${NAME:-default}` cache collision

- **Severity:** low
- **File:** `configs/sketchybar/plugins/network_speed.sh:49,60-65`

**Description.** Two correctness edges in the speed calc:
1. The previous-bytes cache file is keyed `prev_bytes_${NAME:-default}`. If the
   script is ever invoked without `$NAME` (e.g. a `forced`/manual run), both the
   up and down code paths fall back to the *same* `prev_bytes_default` file and
   clobber each other, yielding a garbage delta.
2. When the default route flips interface (Wi-Fi ⇄ Ethernet), `PREV_*` belongs to
   the old interface while `BYTES_*` belongs to the new one. The subtraction can
   be large-positive (not just negative), so the `-lt 0` clamp at lines 64-65
   does **not** catch it — the bar shows a single spurious huge spike before the
   next tick self-corrects.

**Evidence.**
```sh
CACHE_FILE="$CACHE_DIR/prev_bytes_${NAME:-default}"
...
SPEED_IN=$(( (BYTES_IN - PREV_IN) / 5 ))
SPEED_OUT=$(( (BYTES_OUT - PREV_OUT) / 5 ))
[ "$SPEED_IN" -lt 0 ] && SPEED_IN=0
[ "$SPEED_OUT" -lt 0 ] && SPEED_OUT=0
```

**Recommendation.** Persist the interface name alongside the byte counts and reset
the delta to 0 when the cached interface differs from the current one; also key the
cache on the interface (not `$NAME`) or guard against an empty `$NAME`.

---

## Cleared (checked, not bugs)

- `battery.sh:7` `grep -Eo "\d+%"` — works on this macOS's real `/usr/bin/grep`
  (verified: `87%` → match, `ddd%` → no match).
- `cpu.sh` field 3/5 + `bc` — parses `CPU usage: X% user, Y% sys` correctly.
- `ram.sh` — `Pages wired down` field 4 and `compressor` field 5 offsets confirmed.
- `headset.sh` — `Connected:` / `Not Connected:` awk anchors present in
  `SPBluetoothDataType` output on this OS.
- `title.sh:17` `cut -d'|' -f4` against `%{app-name}|||%{window-title}` — correct
  (the empty f2/f3 are intentional; f4 is the title).
- Pervasive unquoted `--set $NAME` / `$SID` / `$SELECTED` — SketchyBar item names
  contain no whitespace/globs, so word-splitting is not triggered.
