# Bugs / correctness lens — implementation log

Phase: bugs (order 10–99). All edits applied in ascending order. No reloads, no
commits. Each shell script passed `bash -n` after editing.

## CH-01 (order 10) — apply-display-profile.sh: guard empty monitors array
File: `configs/aerospace/apply-display-profile.sh`

Wrapped the final `printf '%s\n' "${monitors[@]}"` in `get_monitors_config` behind
`if (( ${#monitors[@]} )); then ... fi`. Under `set -euo pipefail`, expanding an
empty array with `nounset` aborts; this guard lets the function emit nothing and
return cleanly when `system_profiler` yields no name+Resolution block, so the gap
rebuild doesn't abort. Comment added explaining the nounset hazard.

## CH-07 (order 20) — apply-display-profile.sh: retina scoping
File: `configs/aerospace/apply-display-profile.sh`

Removed the sticky `if [[ "$line" =~ "Retina" ]]; then is_retina=true; fi` block
that matched ANY line in a monitor block (it would set retina from a "Display Type:
Retina" line even on an external display). Now `is_retina=true` is set ONLY inside
the Resolution regex branch, and only when that Resolution line itself contains
"Retina". An external display whose Resolution line lacks "Retina" is no longer
routed through the MacBook retina gap table. The `Main Display: Yes` and
`Resolution:` detection are otherwise unchanged. Note the two bug fixes share the
function; both verified to leave the loop body / parse region otherwise intact for
the later perf-a2 single-capture rework.

## CH-05 (order 30) — open-dock-app.sh: python argv
File: `configs/aerospace/open-dock-app.sh`

Changed the URL-decode line from interpolating `$app_path` into a single-quoted
python source string to passing the path as `sys.argv[1]`:
`python3 -c 'import sys,urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' "$app_path"`.
A single quote or metacharacter in an app path no longer terminates the python
string (which caused a SyntaxError → empty bundle_id → silent fallback to plain
`open`, losing placement + cursor warp). Only L18 touched; the grace-marker /
enforcer region was left for perf-s6 + CC-02.

## CH-08 (order 40) — network_speed.sh: persist interface, zero on flip
File: `configs/sketchybar/plugins/network_speed.sh`

`get_bytes` now emits `INTERFACE BYTES_IN BYTES_OUT` (and `none 0 0` on no default
route). The cache file stores all three; the reader reads `PREV_IFACE PREV_IN
PREV_OUT`. On first run (`PREV_IFACE` empty) or an interface flip
(`PREV_IFACE != INTERFACE`), `SPEED_IN`/`SPEED_OUT` are zeroed for that tick
instead of computing a delta against an unrelated interface's counters (which
produced a one-tick spike past the `<0 → 0` clamp). The `<0 → 0` overflow clamp is
kept. Still per-`$NAME` at this stage (per the merge plan, perf-s4 later collapses
this to a single shared cache + single poller, carrying this interface-flip guard
forward).

## CH-09 (order 50) — aerospace.sh: MONITOR_INDEX color comment
File: `configs/sketchybar/plugins/aerospace.sh`

Added a comment in the `IS_VISIBLE` color branch documenting that `MONITOR_INDEX`
is the workspace's POSITION in the visible-workspace enumeration (list order), not
a stable monitor id — so the color tier tracks enumeration position and a 3rd
physical monitor may reuse the 2nd tier's color depending on listing order; this
is cosmetic, not a bug. Also annotated the existing `else` default branch as the
"visible but index unresolved" fallback. Hex values unchanged. (This comment is
to be carried into the perf-s1 coordinator rewrite.)

## CH-06 (order 60) — track-workspace-mru.sh: reclaim stale lockdir
File: `configs/aerospace/track-workspace-mru.sh`

Before the mkdir-lock loop, added a self-contained reclaim block: if `$lock`
exists and its mtime age (`date +%s` minus inline `stat -f %m "$lock"`) > 2s,
`rmdir "$lock" 2>/dev/null`. This frees an orphaned lockdir whose EXIT trap was
skipped on SIGKILL (which would otherwise permanently block MRU writes for that
monitor and degrade the watcher's newest-first bounce). No lib dependency (runs in
the bugs phase before CC-01); references `$lock` by name so CC-04's later RHS swap
is unaffected. The ~2s threshold is far above the ~250ms a real writer holds the
lock.

## CH-02 (order 70) — performance-mode.sh: ensure_loaded helper
File: `configs/aerospace/performance-mode.sh`

Added an `ensure_loaded()` helper (bootstrap → `launchctl print` verify → retry
after `sleep 0.3` → verify again → `kickstart`; returns 0 on success, 1 if still
not loaded). Replaced the bare `launchctl bootstrap ... || true` in
`gaming_mode_off()` with `ensure_loaded "$DISPLAY_PROFILE_PLIST" || true`. This
stops a swallowed bootstrap race from leaving the display-profile agent unloaded
until a full WM restart. The `|| true` at the call site is intentional so a genuine
load failure doesn't abort the rest of the best-effort OFF restore under
`set -euo pipefail`. `ensure_loaded` is a separate helper, so CC-05's later
`gaming_mode_* → performance_mode_*` rename mechanically carries the call site.

## CH-03 (order 80) — aerospace-restart.sh: skip display-profile when perf mode ON
File: `scripts/aerospace-restart.sh`

Read `/tmp/performance-mode.state` once into `PERF_STATE` before the start-phase
bootstrap loop. In the loop, when `agent == com.aerospace.display-profile` and
`PERF_STATE == on`, print a "skipped … (performance mode ON)" line and `continue`.
empty-watcher + AutoRaise still bootstrap unconditionally. This prevents a restart
from re-loading display-profile that perf mode deliberately booted out.

## CH-04 (order 90) — aerospace-restart.sh: readiness wait + comment fix
File: `scripts/aerospace-restart.sh`

(1) Changed the start-phase wait loop break condition from
`pgrep -x AeroSpace` to `aerospace list-workspaces --focused >/dev/null 2>&1`
(same 10×0.5s bound) so it breaks on the socket being ready, not mere process
existence (which races the socket the agents depend on).
(2) Rewrote the unload-block comment: display-profile is RunAtLoad + StartInterval
(no KeepAlive); empty-watcher + AutoRaise are KeepAlive; all three are booted out
(not just killed) so launchd doesn't immediately respawn the KeepAlive ones.

## CH-12 (order 95) — docs
Files: `configs/guide-window-manager.md`, `configs/autoraise/config`,
(`_index.md` — no change needed).

(a) guide bordersrc theme line: replaced the stale
`Tokyo Night theme: active=0xffc0caf5, inactive=0xff414868` with
`Dark-red theme: active=0xffb22222, inactive=0xff4d1a1a` (verified against the live
`configs/borders/bordersrc`: active=0xffb22222, inactive=0xff4d1a1a, width=4.0,
round, hidpi=on). The width/style/hidpi line was already correct and kept.
(b) autoraise/config L39–41 comment: rewrote the stale claim that warping is a
global `on-focus-changed = move-mouse` callback. Verified in aerospace.toml that
`on-focus-changed = []` and `on-focused-monitor-changed = []` are empty and warps
are per-keybinding `move-mouse window-lazy-center` appends. New comment states the
per-keybinding warp + empty global callbacks + AutoRaise warp disabled rationale.
This absorbs the dropped CC-16 (autoraise comment) and CC-17 (borders theme line).
(c) `_index.md` borders description: inspected — it does NOT reference a blue/Tokyo
theme (just "JankyBorders window-border config"), so no edit was required. Recorded
as a no-op rather than a forced change.

## Skips
None. All bugs-lens changes (CH-01, CH-02, CH-03, CH-04, CH-05, CH-06, CH-07,
CH-08, CH-09, CH-12) were applied. CH-10, CH-11, CC-16, CC-17 are droppedChanges
not assigned to this implementer (CC-16/CC-17 are absorbed by CH-12). CH-12 part
(c) was a conditional that evaluated to a no-op (no stale theme reference in
_index.md).
