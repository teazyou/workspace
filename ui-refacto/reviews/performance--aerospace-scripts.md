# Performance Review — AeroSpace helper scripts

**Slice:** `configs/aerospace/*.sh` (apply-display-profile, empty-workspace-watcher, open-dock-app, performance-mode, secondary-bar-toggle, track-workspace-mru)
**Lens:** Runtime efficiency only — hot-loop subprocess spawns, repeated expensive queries, redundant per-tick/per-event work.

## Summary

The two genuinely hot paths are `empty-workspace-watcher.sh` (500ms forever-loop) and `open-dock-app.sh`'s placement enforcer (200ms poll). The watcher's unavoidable cost is the three `aerospace list-*` calls per tick; the avoidable cost is a `printf | grep` membership probe (`contains_pair`) spawned per-monitor per-tick, and a redundant `aerospace list-workspaces --monitor` call that re-derives data already present in the per-tick snapshot. `apply-display-profile.sh` runs `system_profiler SPDisplaysDataType` (a heavyweight call, ~hundreds of ms) up to **three** times for a single change-detection pass on the 5s LaunchAgent. The other scripts are event-driven (per keypress / per workspace change) and are clean for this lens.

---

## performance-aerospace-scripts-01 — `system_profiler` called up to 3× per display-profile pass

**File:** `configs/aerospace/apply-display-profile.sh` — `get_fingerprint()` (l.292), `builtin_is_main()` (l.36), `get_monitors_config()` (l.159)
**Severity:** medium
**Frequency:** every 5s via `com.aerospace.display-profile.plist` (when performance mode is OFF).

`system_profiler SPDisplaysDataType` is one of the most expensive calls in the whole stack (commonly 150–600ms, spins up IORegistry/display enumeration). The 5s agent invokes it:

1. `get_fingerprint()` (l.292) — runs `system_profiler` once, and *inside* the same fingerprint it calls `builtin_is_main` (l.299) which runs `system_profiler` **again** (l.36).

```sh
# l.292
resolutions=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Resolution:" | sort)
...
# l.299  — second full system_profiler inside the same fingerprint
builtin_is_main && bim="main"
```

So even the no-change early-exit path (the overwhelmingly common case — displays rarely change) pays **two** full `system_profiler` runs every 5 seconds. When a change *is* detected it pays more: `build_top_gap_config` → `get_monitors_config` (l.159, third run) and `companion_ws_pattern` → `builtin_is_main` (l.60, fourth run).

**Evidence:** `get_fingerprint` line 292 and line 299 both trigger `system_profiler`; the function is the first thing `main()` runs every tick (l.356).

**Recommendation:** Capture `system_profiler SPDisplaysDataType` **once** per pass into a variable and feed that text to `get_fingerprint`, `builtin_is_main`, and `get_monitors_config` (e.g. pass the blob as an argument, or write it to a tmp var that the awk/grep stages read from). At minimum, fold the `builtin_is_main` signal into the single capture used by `get_fingerprint` so the common no-change tick makes exactly one `system_profiler` call instead of two. This halves (or quarters on change ticks) the dominant cost of the 5s agent.

---

## performance-aerospace-scripts-02 — `contains_pair` forks `printf | grep` per monitor every tick

**File:** `configs/aerospace/empty-workspace-watcher.sh` — `contains_pair()` (l.40), called l.70
**Severity:** low
**Frequency:** 2× per second × monitor count (the visible-ws non-empty check runs every tick for every monitor, before any early-out).

```sh
# l.40
contains_pair() {
    printf '%s\n' "$1" | grep -qFx "$2"
}
# l.70 — runs for EVERY monitor EVERY tick
if contains_pair "$nonempty_pairs" "$mon $vis"; then
    continue
fi
```

Each call forks a subshell pipeline (`printf` + `grep` = 2 processes). With 2 monitors that is 4 forks/tick → **~8 forks/second, continuously, forever**, just to answer "is `<mon> <vis>` in this blob". This is the single most-executed code in the slice.

**Evidence:** `contains_pair` is the first per-monitor operation in the loop (l.70) and is reached on every tick because the non-empty case is the common case.

**Recommendation:** `nonempty_pairs` is already a newline-delimited string in memory. Replace the per-monitor pipeline with a fork-free bash test using a newline-wrapped substring match, e.g. `case $'\n'"$nonempty_pairs"$'\n' in *$'\n'"$mon $vis"$'\n'*) continue;; esac`. This is Bash 3.2 compatible (no `declare -A`/`mapfile`) and eliminates ~8 forks/sec. The same pattern applies to the `grep -qFx` membership probes in the MRU walk (l.96–97, l.108), though those only execute on the rarer bounce path.

---

## performance-aerospace-scripts-03 — redundant `aerospace list-workspaces --monitor` re-derives snapshot data on the bounce path

**File:** `configs/aerospace/empty-workspace-watcher.sh` — l.84
**Severity:** low
**Frequency:** per monitor, only on ticks where that monitor's visible ws is empty (bounce path) — bursty, not every tick.

```sh
# l.84 — extra aerospace query, per monitor, when bouncing
mon_ws_list=$(aerospace list-workspaces --monitor "$mon" --format '%{workspace}' 2>/dev/null)
```

The tick already snapshotted `nonempty_pairs` (l.48) and `visible_pairs` (l.47) with one global `aerospace list-workspaces --monitor all` each. Issuing a *fourth* `aerospace list-workspaces` scoped to a single monitor spawns another aerospace IPC round-trip to fetch the per-monitor workspace set. Because the hard-fallback (l.121) needs the full assignment list (including empty workspaces, which `nonempty_pairs` lacks), the snapshot can't fully replace it today — but the global "all workspaces / all monitors incl. empty" list could be snapshotted **once per tick** alongside the existing three queries and filtered per monitor with the in-memory `awk` already used at l.88, removing the per-monitor IPC.

**Evidence:** l.47–48 already pull `--monitor all` snapshots; l.84 then re-queries the same daemon per monitor for a subset that a single per-tick "all workspaces incl. empty" snapshot would cover.

**Recommendation:** Add one `aerospace list-workspaces --monitor all --format '%{monitor-id} %{workspace}'` (no `--empty` filter) to the per-tick snapshot block (l.46–48) and derive `mon_ws_list` from it via the existing `awk -v m="$mon"` filter, instead of forking a fresh `aerospace` call per monitor on the bounce path.

---

## performance-aerospace-scripts-04 — placement enforcer re-runs full `list-windows` query every 200ms with extra `head` fork

**File:** `configs/aerospace/open-dock-app.sh` — l.58–82
**Severity:** low
**Frequency:** every 200ms for up to ~18s (≤90 iterations) per *cold* app launch (cmd+1–9 on a not-running app only).

```sh
# l.62 — full window query + head fork, every 200ms, up to 90×
entry=$(aerospace list-windows --monitor all --app-bundle-id "$bundle_id" --format '%{window-id}|%{workspace}' 2>/dev/null | head -n 1)
```

Each poll spawns `aerospace list-windows` plus a `head` process (`head` is redundant — the loop only consumes the first line and could read it with `read` from the command, or rely on the app having a single startup window). Worst case is 90 aerospace IPC calls + 90 `head` forks per stuck launch. This is bounded and only on cold launches, so impact is modest, but the `head` fork is pure waste and the 200ms cadence never backs off as the wait lengthens.

**Evidence:** l.62 inside the backgrounded `while [[ $i -lt 90 ]]` loop (l.60).

**Recommendation:** Drop the `| head -n 1` and read the first line directly, e.g. `IFS= read -r entry < <(aerospace list-windows ...)`, eliminating one fork per poll. Optionally apply light backoff (e.g. widen the sleep after the first few seconds) so a launch that never produces a window costs far fewer than 90 IPC round-trips.

---

## Clean for this lens

- `performance-mode.sh` — runs once per toggle (keypress). The per-item `sketchybar --set` loop is many invocations but is a one-shot user action, not a hot path. No finding.
- `secondary-bar-toggle.sh` — once per toggle; delegates to apply-display-profile (covered by 01). No finding.
- `track-workspace-mru.sh` — once per workspace change; single `aerospace list-workspaces` + one `awk`, lock-guarded with a tight 250ms bail. No hot-loop cost. No finding.
