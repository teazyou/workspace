# Bugs / Correctness Review — AeroSpace helper scripts

Slice: the six `configs/aerospace/*.sh` helper scripts (apply-display-profile, empty-workspace-watcher, open-dock-app, performance-mode, secondary-bar-toggle, track-workspace-mru).

## Summary

The scripts are generally well-built and the documented Bash-3.2 constraints are respected in most places. I found a few concrete correctness defects, the most serious being a `set -u` "unbound variable" crash on an empty array in `apply-display-profile.sh` that aborts the whole display-profile rebuild when `system_profiler` returns no usable monitor (a real scenario at login / clamshell / GUI-less invocation). The remainder are lower-severity edge cases (stale lockdir, python single-quote fragility, snapshot/act race already accepted by the guide). Verified findings only; speculative items omitted.

---

## bugs-aerospace-scripts-01 — Empty monitor array crashes the rebuild under `set -u`

- Severity: medium
- File: `configs/aerospace/apply-display-profile.sh:167` (also `:36` interplay)

Description: `get_monitors_config()` builds a local array `monitors=()` and ends with `printf '%s\n' "${monitors[@]}"`. The script runs under `set -euo pipefail` (line 5). In Bash 3.2 (the repo's hard target), expanding an **empty** array as `"${monitors[@]}"` with `nounset` active raises `monitors[@]: unbound variable` and the function exits non-zero, which under `set -e` aborts the whole script.

This is reachable: if `system_profiler SPDisplaysDataType` yields no block with both a name and a `Resolution:` line (no display attached, clamshell with lid closed and no external yet enumerated, or a transient empty read right after a hot-plug), `monitors` stays empty. The `get_fingerprint()` guard at line 294 only bails when `Resolution:` lines are *entirely* absent; a partial/odd profiler output can pass the fingerprint check yet still leave `monitors` empty in `build_top_gap_config`'s consumer. When it crashes here, `update_aerospace_config` never runs and no reload happens — a silent failed rebuild.

Evidence:
```bash
set -euo pipefail        # line 5
local monitors=()        # line 126
...
printf '%s\n' "${monitors[@]}"   # line 167  → "monitors[@]: unbound variable" when empty
```
Reproduced in Bash 3.2.57:
```
$ /bin/bash -c 'set -euo pipefail; a=(); printf "%s\n" "${a[@]}"'
/bin/bash: a[@]: unbound variable   (exit 1)
```

Recommendation: Guard the expansion, e.g. `(( ${#monitors[@]} )) && printf '%s\n' "${monitors[@]}"`, or early-return when the array is empty. (`gap_entries` in `build_top_gap_config` is already guarded via `${#gap_entries[@]}`, so only this site is exposed.)

---

## bugs-aerospace-scripts-02 — `Retina`/`Main Display` substring match is too loose and `is_retina` can mis-fire

- Severity: low
- File: `configs/aerospace/apply-display-profile.sh:146`

Description: `get_monitors_config()` decides Retina via `if [[ "$line" =~ "Retina" ]]`. This matches **any** line in the monitor block containing the literal "Retina", not just the resolution line. macOS prints "Retina" in `Display Type:` (e.g. `Display Type: Built-in Liquid Retina XDR Display`) and may print it in `UI Looks like:` / model strings on external Apple displays. Because the flag is sticky within a block, a non-built-in Apple display whose `Display Type` contains "Retina" but whose `Resolution:` line does **not** (e.g. an external Studio/Pro Display) would still be classified `is_retina=true` and routed through the MacBook retina gap table (lines 80–91), producing the wrong top gap for that monitor.

Evidence:
```bash
if [[ "$line" =~ "Retina" ]]; then   # line 146 — matches Display Type, not only Resolution
    is_retina=true
fi
```
Real profiler output shows `Display Type: Built-in Liquid Retina XDR Display` on its own line, separate from `Resolution:`.

Recommendation: Tie the retina flag to the resolution line specifically, e.g. set `is_retina=true` only inside the existing `Resolution: ... Retina` regex branch (line 156), matching `Resolution:[[:space:]].*Retina`.

---

## bugs-aerospace-scripts-03 — Stale mkdir lockdir permanently blocks MRU writes for a monitor

- Severity: low
- File: `configs/aerospace/track-workspace-mru.sh:22-30`

Description: The MRU writer serialises with `mkdir "$lock"` and removes it via `trap '... rmdir' EXIT`. The trap is only installed *after* a successful `mkdir`. If the process is killed by an uncatchable signal (SIGKILL), or dies between `mkdir` and the `trap` line, the lockdir is orphaned. Every subsequent invocation then fails all 5 `mkdir` attempts, sleeps ~250ms, and `exit 0`s without writing — so that monitor's `/tmp/aerospace-ws-mru-mon-<id>.state` silently stops updating until `/tmp` is cleared (reboot). This degrades `empty-workspace-watcher.sh`'s MRU-based bounce target selection (it falls back to first-listed workspace), so the documented "newest-first MRU" behaviour silently stops working.

Evidence:
```bash
for _ in 1 2 3 4 5; do
    if mkdir "$lock" 2>/dev/null; then
        trap 'rmdir "$lock" 2>/dev/null' EXIT   # installed only after mkdir
        ...
        exit 0
    fi
    sleep 0.05
done
exit 0   # silent give-up; no staleness recovery
```

Recommendation: Treat a lockdir older than a short threshold as stale and reclaim it (e.g. before the loop, `rmdir`/remove the lockdir if its mtime is older than a few seconds), or use a more robust lock with PID + age check. Low severity because `/tmp` clears on reboot and the watcher has fallbacks, but the failure is silent and sticky.

---

## bugs-aerospace-scripts-04 — `open-dock-app.sh` interpolates the app path into a single-quoted python literal

- Severity: low
- File: `configs/aerospace/open-dock-app.sh:18`

Description: The URL-decode step builds Python source by string-interpolating `$app_path` inside a single-quoted literal:
`python3 -c "import urllib.parse; print(urllib.parse.unquote('$app_path'))"`. If `$app_path` (the `_CFURLString` with `file://` stripped) contains a literal single quote, the Python string terminates early and the command fails with a `SyntaxError`, so `bundle_id` can't be derived and the script silently falls back to plain `open` (losing workspace placement + cursor warp). In the typical case CFURLString percent-encodes `'` as `%27`, so this is an edge case, but app bundles with an unencoded apostrophe in their path do occur, and any unexpected metacharacter in the path is fed unquoted to a code interpreter.

Evidence:
```bash
app_path=$(python3 -c "import urllib.parse; print(urllib.parse.unquote('$app_path'))")
```
Reproduced: a path containing `'` produces `SyntaxError: ... print(urllib.parse.unquote('/Apps/It's%20Me.app'))`.

Recommendation: Pass the path as an argument instead of interpolating into source, e.g. `python3 -c 'import sys,urllib.parse;print(urllib.parse.unquote(sys.argv[1]))' "$app_path"`. This removes the injection/quoting surface entirely.

---

## bugs-aerospace-scripts-05 — Performance-mode `bootout`/`bootstrap` only no-op-protected, can race the OFF→ON restore

- Severity: low
- File: `configs/aerospace/performance-mode.sh:20,41`

Description: `gaming_mode_on` does `launchctl bootout` the display-profile agent and `gaming_mode_off` does `launchctl bootstrap` it, each with `2>/dev/null || true`. The `|| true` swallows the real failure mode where `bootstrap` is issued while the previous `bootout` hasn't fully torn the service down (launchd reports the label still loaded). In that window the OFF path's `bootstrap` fails and is silently ignored, leaving the display-profile LaunchAgent **not reloaded** after performance mode is turned off — so hot display changes are no longer auto-applied until the next full WM restart. The guide states OFF "reloads LaunchAgent"; this can silently not happen.

Evidence:
```bash
launchctl bootout   "$GUI_DOMAIN" "$DISPLAY_PROFILE_PLIST" 2>/dev/null || true   # line 20
launchctl bootstrap "$GUI_DOMAIN" "$DISPLAY_PROFILE_PLIST" 2>/dev/null || true   # line 41
```

Recommendation: Make the restore resilient — check `launchctl print "$GUI_DOMAIN/<label>"` and retry the bootstrap, or `kickstart` the service, rather than swallowing the error. At minimum, don't mask the bootstrap failure unconditionally.

---

## Notes (checked, NOT reported)

- `empty-workspace-watcher.sh` snapshot-then-act race (state can change between the per-tick snapshot and the bounce) is real but explicitly accepted by the guide ("~100ms flicker accepted") and self-corrects next tick — out of scope as a defect.
- `update_aerospace_config`'s awk `outer\.top` rewrite is correctly section-gated (`in_gaps`) and the commented example `gaps.outer.top = ...` lives above the `[gaps]` header, so it isn't rewritten. No bug.
- `builtin_is_main()` awk block-boundary logic was traced against real `system_profiler` output and is correct for both built-in-main and external-main cases.
- `track-workspace-mru.sh` has no `set -e`, so `grep -vFx` returning non-zero on no-match does not abort the pipeline. No bug.
- `focus-monitor` by numeric id (avoiding glob-metachar monitor names) is correct and matches the guide.
