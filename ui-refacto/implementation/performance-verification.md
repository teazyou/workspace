# Performance Lens — Verification

**Verdict: PASS.** All 7 performance changes (orders 100-170) are present and correct. No regressions found, no fixes required, no reloads/commits performed.

Environment confirmed: system `/bin/bash` is **3.2.57** (Bash 3.2 constraint is the live runtime). Every edited shell script passes `bash -n`. No `osascript`/notification calls introduced. No symlink targets touched.

## Per-change checks

### perf-a1 — display-profile interval 5 → 15 — PASS
- `com.aerospace.display-profile.plist`: `StartInterval` 5 → 15 (diff confirmed).
- `guide-window-manager.md`: interval line "every 5 seconds" → "every 15 seconds" (L72) **and** the sibling hot-swap latency line "within ~5s" → "within ~15s" (L68). Both updated; consistent with the plist.

### perf-a2 — single system_profiler capture — PASS (was already present; verified in place)
- `apply-display-profile.sh` main() captures `sp_displays="$(system_profiler SPDisplaysDataType 2>/dev/null)"` once (L373) and feeds it to `get_fingerprint`, `build_top_gap_config` (→ `get_monitors_config`), and `companion_ws_pattern`.
- The 6 helper functions use `local sp_displays="${1:-$(system_profiler ...)}"` default-arg blobs, so they remain standalone-callable under `set -u` while taking the captured blob in the hot path.
- **CH-01 guard preserved**: `if (( ${#monitors[@]} )); then printf '%s\n' "${monitors[@]}"; fi` (L176-177).
- **CH-07 retina preserved**: `is_retina` defaults false (L134/146); set true ONLY inside the Resolution branch (L163). Not sticky.

### perf-s1 — single coordinator item — PASS (already present; verified)
- `plugins/aerospace.sh` runs once per `aerospace_workspace_change`, driven by the hidden `aerospace_coordinator` item; one batched `--set`. 3 render states / color tiers / group padding / shorten_app_name present; CH-09's list-position color comment carried.
- `items/spaces.sh`: per-item `script=`/subscription removed; `click_script` + `mouse.clicked` retained; hidden coordinator item added with `drawing=off` + the `aerospace_workspace_change` subscription.

### perf-s2 — drop `--update`, trigger instead — PASS (already present; verified)
- `sketchybarrc` tail uses `sketchybar --trigger aerospace_workspace_change` (L176) with the explanatory "thundering herd" comment; no `--update` remains.

### perf-s3 — ioreg headset + item freq 30 — PASS
- `plugins/headset.sh` is ioreg-based (already present): `ioreg -r -c IOBluetoothDevice -l | awk` matching connected + minor class 4/6, identical two-icon output. Ran live with exit 0.
- `items/headset.sh`: `update_freq` 5 → 30 (this run's edit; diff confirmed). `system_woke` subscription already present.

### perf-s5 — fork-collapse to one awk (ram, cpu, battery) — PASS
- **ram.sh**: 6 grep|awk|tr extractions + arithmetic → one awk over `vm_stat`. Verified **byte-identical output vs old (43%)** on the same machine. `/Pages active/` vs `/Pages inactive/` confirmed distinct (no cross-match); field indices ($3 free/active/inactive/speculative, $4 wired, $5 compressor) verified against live `vm_stat` labels.
- **cpu.sh**: grep|tail|echo|awk|tr|bc|cut → one awk over `top`. `/^CPU/` last-line-wins == old `tail -1`. **Same-snapshot parity confirmed (7% == 7%)**; the earlier 15-vs-7 difference was two independent `top` samples, not a logic divergence.
- **battery.sh**: two grep|cut parses → one awk emitting `"<percent> <0|1>"`. Downstream charging check correctly updated `!= ""` → `== "1"` to match the now-always-non-empty flag; empty-percent guard intact. **Verified live (99, charging=1).** here-string `<<<` is Bash 3.2-safe.
- **ethernet.sh correctly skipped** per perf-s5's optional clause (its parse drives a networksetup feed + per-iface ifconfig active probe, not a fork chain over captured output; an awk rewrite would risk the `en[0-9]+` regex). Noted, not a defect.

### perf-s6 — micro-fork reductions — PASS
- **empty-workspace-watcher.sh** `contains_pair()`: `printf|grep -qFx` → fork-free Bash 3.2 `case` with newline-wrapped blob+needle. **Membership tested live**: exact matches pass; partial (`1 50` vs `1 5`) and substring (`0 3` vs `10 3`) candidates correctly rejected — no false positives. Whole-line semantics equal the old `grep -Fx`.
- **open-dock-app.sh** enforcer: `... | head -n 1` → `read -r entry < <(aerospace ...)` (one fewer fork per 200ms tick); first-row semantics preserved.

## Cross-lens edits riding on these files (verified non-regressing)
The perf-s6 files also carry their CC-02/CC-03 clean-code edits (sourcing `lib-paths.sh`, `grace_file`/`mru_file` builders, `POLL_INTERVAL`, `GRACE_SECONDS`, `PLACEMENT_CAP_SECONDS`). Verified:
- `lib-paths.sh` exists and defines every referenced name; sourcing succeeds.
- `grace_file 5` → `/tmp/aerospace-empty-watcher-grace-5`, `mru_file 1` → `/tmp/aerospace-ws-mru-mon-1.state` — **byte-identical to the replaced literals**.
- `PLACEMENT_CAP_SECONDS * 5 = 90` — **byte-identical to the old `< 90` loop bound**.
- `GRACE_SECONDS=20`, `POLL_INTERVAL=0.5` equal the removed literals.
- Neither perf-s6 script enables `set -u`/`set -e`, so the new source line carries no unset-var risk.
- network_speed.sh single-poller (perf-s4) + UPDATE_FREQ divisor (CC-14): CH-08 interface-flip guard carried (`PREV_IFACE != INTERFACE` zeroes delta), single shared `CACHE_FILE` (`INTERFACE BYTES_IN BYTES_OUT`), one batched dual `--set`; network_up passive, network_down sole poller. Verified.

## Fixes applied
None — implementation was correct as delivered.

## Remaining issues
None.
