# Performance lens — implementation log

Implemented the `performance` lens changes (orders 100-170) of the reconciled
WM-stack change-set. Many performance edits were **already present** in the live
config (an earlier run/lens applied them); those are recorded as skips with the
evidence that confirmed they were in place. Only the genuinely-pending edits were
made.

All edited shell scripts pass `bash -n`. No lint, no reloads, no commits.

## Edits made

### perf-a1 — display-profile interval (order 100) — PARTIAL (doc line only)
- `configs/aerospace/com.aerospace.display-profile.plist`: **already** `StartInterval=15` (no edit needed).
- `configs/guide-window-manager.md` L72 "runs apply-display-profile.sh every 15 seconds": **already** updated (no edit needed).
- `configs/guide-window-manager.md` L68: changed the related stale hot-swap latency
  figure "within ~5s" → "within ~15s". This sentence describes the detection
  cadence that the StartInterval drives, so it was left stale by the prior partial
  apply. Updated to keep the doc tracking the live config (repo convention).

### perf-s3 — headset cadence (order 150)
- `configs/sketchybar/plugins/headset.sh`: **already** ioreg-based (no edit needed).
- `configs/sketchybar/items/headset.sh`: `update_freq=5` → `update_freq=30`. The
  `--subscribe headset system_woke` was already present. This was the one pending
  half of perf-s3.

### perf-s5 — fork-collapse to one awk per plugin (order 160)
- `configs/sketchybar/plugins/ram.sh`: replaced the 6× `echo|grep|awk|tr` page-count
  extractions + arithmetic with a **single awk** over `vm_stat` output. It captures
  each `Pages …` line, strips the trailing dot, and computes
  `(active+wired+compressed)*100/(used+free+inactive+speculative)`. Output string
  `"${PERCENT}%"` is byte-identical. Verified live: 42%.
- `configs/sketchybar/plugins/cpu.sh`: replaced the `grep|tail|echo|awk|tr|bc|cut`
  chain with a **single awk** over `top -l 1 -n 0`. It matches `^CPU` lines (last
  assignment wins, equivalent to the old `tail -1`), strips `%` from user ($3) and
  sys ($5), and prints the truncated integer sum. Empty/absent → "0". Output
  `"${TOTAL:-0}%"` unchanged. Verified live: 10%.
- `configs/sketchybar/plugins/battery.sh`: replaced the two `grep|cut` parses with a
  **single awk** over `pmset -g batt` emitting `"<percent> <0|1>"` (percent = first
  `NN%` token; flag = 1 when an `AC Power` line is present). Because `CHARGING` is now
  always non-empty ("0"/"1"), the downstream charging check was updated from
  `[[ "$CHARGING" != "" ]]` to `[[ "$CHARGING" == "1" ]]` (same semantics). The
  `PERCENTAGE` empty-guard still works (no battery → empty percent token). Verified
  live: "96 1".
- `configs/sketchybar/plugins/ethernet.sh`: **awk collapse intentionally skipped**.
  perf-s5 explicitly marks the ethernet awk as "optional within S5 if it risks the
  iface-name regex". The ethernet parse is not a fork chain over already-captured
  output — it drives a `networksetup | grep -A1` feed and runs a per-interface
  `ifconfig … status: active` probe inside the loop. Collapsing that into one awk
  would risk the `en[0-9]+` iface-name regex and change the active-link probe, so it
  was left as-is per the spec's allowance.

### perf-s6 — micro-fork reductions (order 170)
- `configs/aerospace/empty-workspace-watcher.sh`: rewrote `contains_pair()` from
  `printf | grep -qFx` to a **fork-free Bash 3.2** `case` membership test that wraps
  both the blob and the needle in newlines so the glob only matches a complete line
  (no partial-line false positives). Functionally verified: "2 7" matches, "2 70"
  rejected, first/last lines match.
- `configs/aerospace/open-dock-app.sh` (enforcer subshell L62): replaced
  `entry=$(aerospace … | head -n 1)` with `read -r entry < <(aerospace …)` —
  one fewer fork per 200ms poll tick, same first-row result.

## Skips (already applied by a prior lens/run — verified, no edit needed)

- **perf-a1 plist** — `StartInterval` already 15; guide L72 already "every 15 seconds".
- **perf-a2 single-capture** (`apply-display-profile.sh`) — `main()` already captures
  `SP_DISPLAYS` once and feeds `builtin_is_main` / `get_fingerprint` /
  `get_monitors_config` via `${1:-…}` default-arg blobs; CH-01 array guard (L174) and
  CH-07 in-branch retina set (L160) both present and preserved.
- **perf-s1 coordinator** (`plugins/aerospace.sh` + `items/spaces.sh`) — already a
  single hidden `aerospace_coordinator` item driving one batched `--set`; the 3 render
  states, color tiers, group padding, `shorten_app_name`/star-collapse, and CH-09's
  MONITOR_INDEX comment are all present.
- **perf-s2 drop-update** (`sketchybarrc`) — the final `sketchybar --update` is already
  replaced by `sketchybar --trigger aerospace_workspace_change` with the explanatory
  comment.
- **perf-s4 network single-poller** (`plugins/network_speed.sh`, `items/network_up.sh`,
  `items/network_down.sh`) — already single poller: one `CACHE_FILE` storing
  `INTERFACE BYTES_IN BYTES_OUT`, CH-08 interface-flip guard carried in, one batched
  `--set network_down … --set network_up …`. `network_up` is passive (no
  update_freq/script); `network_down` keeps `update_freq=5` + script.
- **perf-s3 headset plugin** — `plugins/headset.sh` already ioreg-based (only the item
  `update_freq` was pending; edited above).

## Notes / cross-lens
- Did NOT touch any clean-code (CC-*) or bug (CH-*) regions beyond what perf specifies.
  The already-present perf-a2/perf-s1/perf-s4 code already carries the corresponding
  bug-fix hunks (CH-01/CH-07/CH-08/CH-09) verbatim, consistent with the global ordering.
- Bash 3.2 compatibility preserved (no `declare -A`/`mapfile`; the new `contains_pair`
  uses only `case`). No macOS notifications added. No reloads/restarts/commits.
