# Bugs / correctness lens — QA verification

**Verdict: PASS.** All 10 intended bugs-lens changes (CH-01, CH-07, CH-05, CH-08,
CH-09, CH-06, CH-02, CH-03, CH-04, CH-12) are present and correct in the final
integrated working tree, and survived the downstream perf + clean-code edits
exactly as the conflict resolutions prescribed. Every edited shell script passes
`bash -n`. No fixes were required. No regressions found.

> Context: the working tree contains all three lenses (bugs + performance +
> clean-code) layered in global order, plus some unrelated pre-existing changes
> (vscode/iterm2, dot-claude submodule). This review verifies the bugs edits are
> intact *after* the perf/clean layers landed on top of them.

## Per-change verification

### CH-01 — apply-display-profile.sh: guard empty monitors array — PASS
`get_monitors_config` final emit is wrapped in `if (( ${#monitors[@]} )); then
printf '%s\n' "${monitors[@]}"; fi` with the nounset-hazard comment. Survives
perf-a2 (which only swapped the loop's data source to `printf '%s\n'
"$sp_displays"`). Guard region untouched by perf-a2/CC-07.

### CH-07 — apply-display-profile.sh: retina scoping — PASS
The sticky any-line `if [[ "$line" =~ "Retina" ]]; then is_retina=true; fi` block
is removed. `is_retina=true` is now set ONLY inside the `Resolution:` regex branch
and only when that Resolution line itself contains "Retina". External-display
misrouting fixed. Preserved verbatim under perf-a2's data-source swap.

### CH-05 — open-dock-app.sh: python argv — PASS
`python3 -c 'import sys,urllib.parse; print(urllib.parse.unquote(sys.argv[1]))'
"$app_path"` — path passed as argv, not interpolated into single-quoted source.
Isolated at L18; perf-s6 (read from process substitution) and CC-02 (grace_marker
rename, PLACEMENT_CAP cap) landed on the separate enforcer subshell without
touching it.

### CH-08 — network_speed.sh: persist interface, zero on flip — MERGED, PASS
`get_bytes` emits `INTERFACE BYTES_IN BYTES_OUT` (`none 0 0` on no route). The
interface-flip guard (`[ -z "$PREV_IFACE" ] || [ "$PREV_IFACE" != "$INTERFACE" ]`
zeroes the delta) is carried forward into perf-s4's single shared cache
(`$CACHE_DIR/prev_bytes`, storing all three fields) and single-poller dual
`--set`. The `<0 → 0` overflow clamp is kept. CC-14's `UPDATE_FREQ=5` names the
divisor. This is the intended non-mechanical MERGE, executed correctly — the
old per-`$NAME` cache split is gone (now genuinely obsolete with one poller), and
`items/network_up.sh` is correctly passive (no update_freq/script).

### CH-09 — aerospace.sh: MONITOR_INDEX color comment — PASS (carried into rewrite)
perf-s1 rewrote the plugin into the once-per-event coordinator; CH-09's comment is
carried into the coordinator's color-tier branch (aerospace.sh L140–144:
"MONITOR_INDEX is the workspace's POSITION in the visible-workspace enumeration
(list order), not a stable monitor id … a 3rd physical monitor can reuse the 2nd
tier's color"). Hex values preserved (and subsequently swapped to colors.sh vars
by CC-12, per plan).

### CH-06 — track-workspace-mru.sh: reclaim stale lockdir — PASS
Self-contained reclaim block before the mkdir loop: `[[ -d "$lock" ]]` →
`stat -f %m` (BSD/macOS) age check `> 2`s → `rmdir "$lock" 2>/dev/null`. References
`$lock` by name, so CC-04's later RHS swap (`lock="$(mru_lock "$mon")"`) is
unaffected — block sits between the builder assignment and the lock loop. Inline
stat (not lib's `file_age_seconds`), as required for the bugs phase ordering.

### CH-02 — performance-mode.sh: ensure_loaded helper — PASS
`ensure_loaded()` (bootstrap → `launchctl print` verify → retry after `sleep 0.3`
→ kickstart; returns 0/1) added; the bare `bootstrap … || true` in the OFF path
is replaced with `ensure_loaded "$DISPLAY_PROFILE_PLIST" || true`. The `|| true`
at the call site is intentional (keeps the rest of the best-effort OFF restore
alive under set -e). CC-05's rename (`gaming_mode_* → performance_mode_*`)
mechanically carried the call site, since `ensure_loaded` is a separate helper.

### CH-03 — aerospace-restart.sh: skip display-profile when perf ON — PASS
`PERF_STATE` read once from `/tmp/performance-mode.state` before the start-phase
loop; the loop `continue`s past `com.aerospace.display-profile` when
`PERF_STATE == on`. empty-watcher + AutoRaise bootstrap unconditionally. The
literal `/tmp/performance-mode.state` equals lib's `PERFORMANCE_MODE_STATE` (this
script is not a lib consumer, so the literal is correct and contract-consistent).

### CH-04 — aerospace-restart.sh: readiness wait + comment fix — PASS
Wait-loop break changed to `aerospace list-workspaces --focused >/dev/null 2>&1`
(socket readiness, same 10×0.5s bound). Unload-block comment corrected:
display-profile is RunAtLoad + StartInterval (no KeepAlive); empty-watcher +
AutoRaise are KeepAlive.

### CH-12 — docs — PASS (incl. correctly-skipped part c)
- (a) guide bordersrc line → "Dark-red theme: active=0xffb22222,
  inactive=0xff4d1a1a" — verified against live `configs/borders/bordersrc`
  (active_color=0xffb22222, inactive_color=0xff4d1a1a, width=4.0, round, hidpi=on).
- (b) autoraise/config comment rewritten to per-keybinding move-mouse warps +
  empty global callbacks — verified against `aerospace.toml`
  (`on-focus-changed = []`, `on-focused-monitor-changed = []`).
- (c) `_index.md` borders entry references no blue/Tokyo theme (just "JankyBorders
  window-border config"), so the conditional edit was correctly a no-op. (The
  `_index.md` diff present is the unrelated custom.css entry, not CH-12.)
- The guide's "~15s" / "every 15 seconds" edits are perf-a1 (a different line),
  correctly co-existing with CH-12's theme-line edit (no clobber).

## Cross-cutting checks

- **`bash -n` on every edited shell script: all PASS** (apply-display-profile,
  open-dock-app, track-workspace-mru, performance-mode, empty-workspace-watcher,
  secondary-bar-toggle, lib-paths, aerospace-restart, network_speed, aerospace
  plugin, icon_map, cpu, ram, battery, headset, sketchybarrc, colors, spaces item,
  network_up item, headset item).
- **lib-paths.sh sources cleanly under `set -euo pipefail`** (the flagged
  highest-risk failure mode). Every var referenced by bugs/perf/clean consumers is
  defined: `PERFORMANCE_MODE_STATE`, `SECONDARY_BAR_STATE`, `GRACE_SECONDS=20`,
  `PLACEMENT_CAP_SECONDS=18`, `POLL_INTERVAL=0.5`, and the `grace_file`/`mru_file`/
  `mru_lock`/`file_age_seconds` builders. Builders produce byte-identical paths to
  the old literals (verified at runtime).
- **Constraint compliance**: no `osascript "display notification"` added; Bash 3.2
  compatible (no associative arrays / mapfile in the bugs edits or lib); symlink
  model respected (edits in-repo); documented behavior kept in sync (guide +
  autoraise comment + bordersrc).
- **No accidental unrelated-line edits** in any bugs file. perf-a2 in
  apply-display-profile.sh changed only the data source (single capture +
  default-arg blobs), leaving CH-01's guard and CH-07's branch verbatim, as the
  resolution required.

## Fixes applied
None — no problems found.

## Remaining issues
None for the bugs lens.

## Notes
- Verdict is scoped to the bugs lens. The perf/clean layers present in the same
  working tree were inspected only where they touch or carry bugs edits; their own
  correctness is for their respective reviewers.
