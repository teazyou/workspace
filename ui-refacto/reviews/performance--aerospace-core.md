# Performance review — AeroSpace core config + LaunchAgents

**Slice:** `configs/aerospace/aerospace.toml`, `com.aerospace.display-profile.plist`, `com.aerospace.empty-watcher.plist`, `scripts/aerospace-restart.sh`
**Lens:** Runtime efficiency only (hot-loop subprocess spawns, repeated expensive calls, redundant per-tick work).

## Summary

The dominant performance issue in this slice is the **display-profile LaunchAgent's 5-second `StartInterval`** driving `apply-display-profile.sh`, whose no-change early-exit path still spawns **two full `system_profiler SPDisplaysDataType` calls every 5 seconds, forever** — each measured at ~0.32s wall / ~0.12s CPU on this machine. That is ~0.64s of `system_profiler` work every 5s, 24/7, purely to confirm "nothing changed." This is the one high-value finding. A second, lower-severity finding is the per-workspace-change `exec-on-workspace-change` wrapper that forks an extra `/bin/bash -c`. `aerospace-restart.sh` is a one-shot manual script with no hot path, and `com.aerospace.empty-watcher.plist` correctly delegates polling to the script (the script's own per-tick cost is outside this slice's files). Findings limited to my files below.

---

## performance-aerospace-core-01 — display-profile agent runs `system_profiler` twice every 5s on the no-op path

**Severity:** high
**File:** `configs/aerospace/com.aerospace.display-profile.plist:13-14` (the `StartInterval` = 5 that makes the path hot); driven script `configs/aerospace/apply-display-profile.sh:292` and `:36`/`:299`.

**Hot path frequency:** every 5 seconds, continuously, whenever AeroSpace is running and performance mode is OFF (perf mode unloads this agent). ~17,000 invocations/day.

**Description:**
The plist fires `apply-display-profile.sh` every 5s. The very first thing `main()` does is compute a fingerprint to decide whether anything changed (the common case is "no change"). Computing that fingerprint costs **two** `system_profiler SPDisplaysDataType` spawns:

1. `get_fingerprint()` runs `system_profiler SPDisplaysDataType | grep -E "Resolution:" | sort` (line 292).
2. Inside the same function, `builtin_is_main` is called (line 299), which runs `system_profiler SPDisplaysDataType | awk ...` (line 36) — a **second** full enumeration of the same hardware.

So on the overwhelmingly-common no-change tick, the agent spawns `system_profiler` twice (plus `grep`, `sort`, `awk`, `md5`, `cut`) before exiting at line 361-363. Measured cost of one `system_profiler SPDisplaysDataType` here: `real 0.32s`. Two of them = ~0.64s wall every 5s, just to early-exit.

**Evidence:**
```sh
# com.aerospace.display-profile.plist
<key>StartInterval</key>
<integer>5</integer>
```
```sh
# apply-display-profile.sh get_fingerprint() — line 292
resolutions=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Resolution:" | sort)
...
# line 299 — a SECOND system_profiler via builtin_is_main
builtin_is_main && bim="main"
```
```sh
# builtin_is_main() — line 36
system_profiler SPDisplaysDataType 2>/dev/null | awk '...'
```
Measured: `system_profiler SPDisplaysDataType` → `real 0.32`.

**Recommendation (no slice-file constraint violated):**
- Cheapest, highest-leverage fix: raise the plist `StartInterval` from `5` to `15`–`30`. Display connect/disconnect is rare and the guide already accepts up to ~5s latency; 15-30s still feels instant for a physical replug and cuts the wakeups 3-6x. (Edit is in my slice file — the plist.)
- Independently, in the driven script, capture `system_profiler SPDisplaysDataType` **once** per tick into a variable and feed both the resolution-grep and `builtin_is_main`/awk from that single capture, halving the spawns per tick. (Out of slice but worth noting as the paired fix.)

---

## performance-aerospace-core-02 — `exec-on-workspace-change` forks an extra `/bin/bash -c` wrapper per workspace switch

**Severity:** low
**File:** `configs/aerospace/aerospace.toml:27-29`

**Hot path frequency:** once per workspace change (alt+1-9, alt-tab, MRU-driven bounces from the empty-watcher, etc.) — event-driven, can fire in bursts when the empty-watcher bounces monitors.

**Description:**
The callback is declared as `['/bin/bash', '-c', '<two commands>']`, which forks a `/bin/bash` interpreter on every workspace change purely to chain a `sketchybar --trigger` and `track-workspace-mru.sh`. AeroSpace runs `exec-on-workspace-change` directly; the explicit `/bin/bash -c` adds one shell process per event on top of the two commands it runs. Because the empty-watcher's bounces also generate workspace-change events, this can fire repeatedly in quick succession.

**Evidence:**
```toml
exec-on-workspace-change = ['/bin/bash', '-c',
    'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE; ~/workspace/configs/aerospace/track-workspace-mru.sh "$AEROSPACE_FOCUSED_WORKSPACE"'
]
```

**Recommendation:**
This is low severity and partly unavoidable: two commands need a shell, and the `sketchybar --trigger` is genuinely useful. The only real saving would be to fold the `sketchybar --trigger` into `track-workspace-mru.sh` (so a single script invocation does both) — but that expands a shared script's responsibility and crosses out of this slice, so flag-only. No change recommended inside the `.toml` itself beyond awareness; the dominant cost is finding 01.

---

## Files with no performance findings

- **`com.aerospace.empty-watcher.plist`** — correctly uses `KeepAlive` + `RunAtLoad` with **no** `StartInterval` (the guide notes the script owns its 500ms loop). The plist adds no redundant per-tick work; the daemon's per-tick query cost lives in `empty-workspace-watcher.sh`, which is outside this slice's file list.
- **`scripts/aerospace-restart.sh`** — one-shot, manually-invoked (`aerostart` alias). Its `sleep 1` and the 10-iteration `pgrep` wait run once per restart; not a hot path. No efficiency issue.
