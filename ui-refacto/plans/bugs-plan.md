# Bugs / correctness — implementation plan

Repo: `/Users/teazyou/workspace`. Scope: window-manager config refactor (aerospace, sketchybar,
borders, autoraise + the restart script). Planning only — no edits applied in this step.

## Summary

Consolidated the 5 review units into **12 planned changes**. The two genuinely
functional bugs are:

- A `set -u` empty-array crash in `apply-display-profile.sh` that can abort the gap rebuild
  (`bugs-aerospace-scripts-01`, medium).
- A restart-vs-performance-mode ordering race that can leave the display-profile LaunchAgent
  running while performance mode is nominally ON (`bugs-aerospace-core-01`, medium).

Everything else is low-severity robustness, an injection hardening, or stale comment/guide text.

Decisions / things dropped or narrowed (see Open Questions for the deferred ones):

- **`bug-02` (title.sh broken change-check):** `title.sh` / a `title` / `title_proxy` item is
  **not wired anywhere** (not sourced in `sketchybarrc`, no item adds it). It is dead code.
  The fix is small and self-contained, so it is kept as a low-risk correctness fix for if it is
  ever re-enabled, but it has **zero current runtime effect**.
- **`bug-03` "NAME cache collides":** dropped — incorrect. `network_speed.sh` already keys its
  cache file by `${NAME}` (`prev_bytes_network_up` vs `prev_bytes_network_down`), so up/down do
  not collide. Only the interface-flip spike half of that finding is real and planned.
- **`bug-01` (MONITOR_INDEX positional):** kept but minimized — a true monitor-id rewrite is
  involved and risks the documented multi-monitor color behavior; only 2 distinct non-focused
  bubble colors exist today. Planned as a low-risk guard, with the deeper rewrite left as an
  open question.
- No notifications are added anywhere (repo rule). All shell stays Bash 3.2 compatible.
  No auto-linting. All edits are to the repo source-of-truth files (symlink model respected).

## Ordered change list

Order: independent functional fixes first, then the launchctl-helper shared change they both want,
then robustness, then cosmetic plugin fixes, then doc-only edits last.

---

### CH-01 — Guard empty monitor array in `apply-display-profile.sh`
- **file:** `configs/aerospace/apply-display-profile.sh`
- **change:** In `get_monitors_config` (line ~167), wrap the final
  `printf '%s\n' "${monitors[@]}"` so it only runs when the array is non-empty
  (`(( ${#monitors[@]} )) && printf '%s\n' "${monitors[@]}"`), or early-`return 0` on an empty
  array. This stops the Bash 3.2 unbound-variable abort under `set -euo pipefail` when
  `system_profiler` returns no block carrying both a name and a Resolution line (clamshell, login,
  transient hot-plug read). Downstream `build_top_gap_config` already handles zero `gap_entries`
  (line 248 emits `default_gap`), so an empty stream is safe.
- **rationale:** Prevents the whole script aborting → config never rewritten, aerospace never
  reloaded. The only medium functional bug in the scripts slice.
- **addresses:** bugs-aerospace-scripts-01
- **risk:** low
- **dependsOn:** —

---

### CH-02 — Add a launchctl bootstrap helper (verify + kickstart) in `performance-mode.sh`
- **file:** `configs/aerospace/performance-mode.sh`
- **change:** Replace the bare
  `launchctl bootstrap "$GUI_DOMAIN" "$DISPLAY_PROFILE_PLIST" 2>/dev/null || true` in
  `gaming_mode_off` (line 41) with a small `ensure_loaded()` helper: attempt `bootstrap`, then
  `launchctl print "$GUI_DOMAIN/com.aerospace.display-profile"` to confirm it loaded; if not loaded
  (e.g. the prior `bootout` from `gaming_mode_on` had not finished tearing down), retry the
  bootstrap once after a short `sleep 0.3`, and finally `launchctl kickstart` the service so it is
  actually running. Keep it idempotent and silent of spurious stderr but **not** swallowing real
  failure into `|| true`.
- **rationale:** Performance-mode OFF is documented to reload the display-profile agent (guide
  line 105). A swallowed bootstrap race leaves it unloaded so hot display changes stop auto-applying
  until a full WM restart.
- **addresses:** bugs-aerospace-scripts-05
- **risk:** low
- **dependsOn:** —

---

### CH-03 — Make `aerospace-restart.sh` not re-load display-profile while perf mode is ON
- **file:** `scripts/aerospace-restart.sh`
- **change:** In the start-phase bootstrap loop (lines 51-55), special-case
  `com.aerospace.display-profile`: only bootstrap it when performance mode is OFF, i.e. when
  `/tmp/performance-mode.state` is absent or not `on`. Because the default at startup is perf-mode
  ON (aerospace.toml after-startup-command), the restart should normally leave display-profile
  booted out, matching what `performance-mode.sh gaming_mode_on` does. Concretely: read the state
  file once before the loop; inside the loop `continue` for the display-profile agent when state is
  `on`. (empty-watcher and autoraise still bootstrap unconditionally.)
- **rationale:** Today the restart re-bootstraps all 3 agents after a bare `pgrep` wait, which can
  re-load display-profile *after* perf mode booted it out, leaving it running while perf mode is
  nominally ON (guide line 104/68). This change makes restart honor the perf-mode contract.
- **addresses:** bugs-aerospace-core-01
- **risk:** medium
- **dependsOn:** —

---

### CH-04 — Fix readiness check + stale KeepAlive comment in `aerospace-restart.sh`
- **file:** `scripts/aerospace-restart.sh`
- **change:** Two edits in the same file:
  1. Wait-loop (lines 46-49): change the break condition from "process exists"
     (`pgrep -x AeroSpace`) to "AeroSpace answers a query" — e.g.
     `aerospace list-workspaces --focused >/dev/null 2>&1 && break` — so the agents that depend on
     the socket are bootstrapped only once AeroSpace is actually ready. Keep the same bounded
     10×0.5s timeout and fall through after it so a slow start still proceeds (daemons self-retry).
  2. Comment (line 27): correct the "they're KeepAlive" claim to note display-profile is
     **StartInterval-driven (RunAtLoad, no KeepAlive)** while empty-watcher and autoraise are
     KeepAlive — the bootout loop still works, only the rationale was wrong.
- **rationale:** Breaking on process existence races the socket; the comment misstates agent
  semantics. Both are correctness/clarity, no behavior regression.
- **addresses:** bugs-aerospace-core-03, bugs-aerospace-core-02
- **risk:** low
- **dependsOn:** CH-03 (same start-phase block; sequence the edits to avoid conflicting hunks)

---

### CH-05 — Pass app path via argv to python3 in `open-dock-app.sh`
- **file:** `configs/aerospace/open-dock-app.sh`
- **change:** Line 18: stop interpolating `$app_path` into a single-quoted python source string.
  Instead pass it as an argv arg and read it from `sys.argv`:
  `app_path=$(python3 -c 'import sys,urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' "$app_path")`.
- **rationale:** A literal single quote / metacharacter in an app path currently terminates the
  Python string early → `SyntaxError` → no `bundle_id` → silent fallback to plain `open` (loses
  workspace placement + cursor warp). argv passing is injection-safe and equivalent for normal paths.
- **addresses:** bugs-aerospace-scripts-04
- **risk:** low
- **dependsOn:** —

---

### CH-06 — Reclaim a stale MRU lockdir in `track-workspace-mru.sh`
- **file:** `configs/aerospace/track-workspace-mru.sh`
- **change:** Before the 5-attempt `mkdir` loop, if `$lock` already exists and is older than a short
  threshold (e.g. mtime > ~2s — well above the ~250ms max hold), `rmdir "$lock" 2>/dev/null` to
  reclaim an orphaned lock (the EXIT trap can be skipped on SIGKILL or a death between `mkdir` and
  `trap`). Use a portable Bash-3.2 / BSD-stat age check (`stat -f %m` on macOS) and guard so a live
  holder is never clobbered. Keep the existing loop + trap otherwise.
- **rationale:** An orphaned lockdir permanently blocks MRU writes for that monitor until `/tmp`
  clears, silently degrading empty-workspace-watcher's newest-first bounce (documented behavior,
  guide line 122).
- **addresses:** bugs-aerospace-scripts-03
- **risk:** medium
- **dependsOn:** —

---

### CH-07 — Scope Retina detection to the resolution line in `apply-display-profile.sh`
- **file:** `configs/aerospace/apply-display-profile.sh`
- **change:** In `get_monitors_config`, remove the standalone sticky
  `if [[ "$line" =~ "Retina" ]]; then is_retina=true; fi` (lines 145-148) and set `is_retina=true`
  **only inside** the existing Resolution regex branch (line 156), when the Resolution line itself
  contains "Retina". This reflects the resolution line specifically instead of any line in the block
  (e.g. a Display Type line on an external Apple display).
- **rationale:** A non-built-in Apple display whose *Display Type* says Retina but whose Resolution
  line does not currently gets routed through the MacBook retina gap table → wrong top gap.
- **addresses:** bugs-aerospace-scripts-02
- **risk:** low
- **dependsOn:** CH-01 (same function; sequence edits to avoid overlapping hunks)

---

### CH-08 — Track the interface to suppress network-speed flip spikes in `network_speed.sh`
- **file:** `configs/sketchybar/plugins/network_speed.sh`
- **change:** Persist the interface name alongside the byte counters in the cache file (write
  `INTERFACE BYTES_IN BYTES_OUT`; read all three back). When the cached interface differs from the
  current one (Wi-Fi↔Ethernet flip, or first run), treat the delta as a fresh baseline: set
  `SPEED_IN`/`SPEED_OUT` to 0 for that tick rather than subtracting counters from a different NIC.
  Keep the existing `< 0 → 0` clamp as a backstop. Do **not** change the cache filename keying
  (already per-`$NAME`; the "collision" half of the finding is not real).
- **rationale:** On an interface flip the new NIC's absolute counters are unrelated to the old NIC's,
  producing a one-tick speed spike past the intended clamp. Resetting the delta on interface change
  fixes it. Low impact in practice (these items are hidden in the default perf-mode-ON profile).
- **addresses:** bug-03 (interface-flip half only)
- **risk:** low
- **dependsOn:** —

---

### CH-09 — Guard the MONITOR_INDEX positional color pick in `aerospace.sh`
- **file:** `configs/sketchybar/plugins/aerospace.sh`
- **change:** Minimal-risk improvement only: keep the existing 2-vs-≥3 color buckets but make the
  default branch explicit and add a short comment that the index is list-position based (not
  monitor-id), so a 3rd visible monitor may reuse the 2nd color. (A full monitor-id rewrite is
  deferred — see Open Questions.) Concretely, leave the `0xff8a3048` / `0xff75283d` values intact
  and document the limitation inline so future edits don't assume per-monitor stability.
- **rationale:** The color is keyed off enumeration position, not a stable monitor identity, so on
  3+ monitors a workspace can get the wrong bubble color. Cosmetic; documented behavior is "distinct
  colors per monitor" but only two non-focused colors exist anyway.
- **addresses:** bug-01
- **risk:** low
- **dependsOn:** —

---

### CH-10 — Drop or document the definition-time `$(date)` in `calendar.sh`
- **file:** `configs/sketchybar/items/calendar.sh`
- **change:** Remove the inline `label="$(date '+%H:%M')"` (line 16) and `label="$(date '+%a %d')"`
  (line 38). Both items already define a `script=` plugin (`time.sh` / `date.sh`) with `update_freq`,
  and `sketchybarrc` runs `sketchybar --update` at the end of load, which fires every item's script
  once. Removing the inline value eliminates the redundant second source of truth and the
  up-to-a-minute stale first paint on a reload that straddles a minute boundary. (Alternative if a
  guaranteed fast first paint is wanted: keep it but add a comment flagging the redundancy — pick the
  removal unless the user prefers the fast-paint variant.)
- **rationale:** Correctness smell / duplicated source of truth; no crash. Low priority.
- **addresses:** bugs-sketchybar-core-01
- **risk:** low
- **dependsOn:** —

---

### CH-11 — Fix the unwired title.sh change-check (dead-code correctness)
- **file:** `configs/sketchybar/plugins/title.sh`
- **change:** Replace the brittle
  `grep -o '"value":"[^"]*"'` label read (line 27) — which does not match the JSON SketchyBar
  actually emits (it has a space after the key, `"value": "..."`), so `CURRENT_LABEL` is always
  empty and the animate path re-runs every tick — with a `jq`-based read of the label value
  (`sketchybar --query title_proxy | jq -r '.label.value'`), or a `grep -E` whose pattern tolerates
  the space. NOTE: this file is **not currently sourced or added** by any item, so the change has no
  live effect; it is fixed only so the file is correct if ever re-enabled.
- **rationale:** Real correctness bug, but in dead code. Kept low-priority and clearly flagged.
- **addresses:** bug-02
- **risk:** low
- **dependsOn:** —

---

### CH-12 — Stale doc/comment corrections (guide + autoraise config + index)
- **files:** `configs/guide-window-manager.md`, `configs/autoraise/config`,
  `configs/borders/bordersrc` (comment only), `_index.md`
- **change:** Doc-only edits, no runtime effect:
  1. `guide-window-manager.md` line ~177: replace the "Tokyo Night theme: active=0xffc0caf5,
     inactive=0xff414868" with the actual dark-red theme from `bordersrc`
     (`active_color=0xffb22222`, `inactive_color=0xff4d1a1a`, width 4.0, round, hidpi on).
  2. `autoraise/config` lines 39-41: reword the comment so it no longer claims warping is done by
     AeroSpace's `on-focus-changed` callback (that array is empty in aerospace.toml); point it at the
     explicit per-keybinding `move-mouse window-lazy-center` warps and `open-dock-app.sh` instead.
     (The guide already describes this correctly — mirror that wording.)
  3. `bordersrc` top comment already says "Dark red themed borders" so no change there beyond
     confirming; update `_index.md`'s borders description if it still references a blue/Tokyo theme.
- **rationale:** Stale docs mislead future edits; the repo convention requires `_index.md` and guides
  to stay in sync with reality. No behavior change.
- **addresses:** bugs-borders-autoraise-02, bugs-borders-autoraise-01
- **risk:** low
- **dependsOn:** —

---

## Open questions

1. **CH-03 / CH-04 ordering & restart semantics:** Should `aerospace-restart.sh` alternatively
   *always* bootstrap display-profile and let `performance-mode.sh` re-boot it out (relying on the
   after-startup-command), instead of restart inspecting `/tmp/performance-mode.state`? The
   state-file check is the most direct fix but couples restart to the perf-mode contract — confirm
   that is acceptable.
2. **CH-09 depth:** Do you want the full monitor-id-keyed color rewrite in `aerospace.sh` (stable
   per-monitor colors on 3+ monitors), or is the documented 2-color minimal guard enough? The full
   rewrite touches the visible-workspace enumeration and is higher risk.
3. **CH-10 variant:** Drop the inline `$(date)` entirely (preferred), or keep it as an intentional
   fast first paint with a comment? Pick one.
4. **CH-11 jq dependency:** `title.sh` is dead code. Is `jq` guaranteed present in this environment,
   or should the fix stay grep-based to avoid adding a dependency to a file that may be re-enabled?
5. **CH-06 lock threshold:** Confirm a ~2s stale-lock reclaim threshold is comfortably above the
   real max hold (~250ms) and below any tolerance for missed MRU updates.
