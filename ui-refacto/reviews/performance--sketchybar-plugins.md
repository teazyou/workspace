# Performance Review — SketchyBar plugins

Slice: `configs/sketchybar/plugins/*.sh`. Lens: runtime efficiency only.

## Summary

The plugin set is mostly reasonable, but a handful of hot-path scripts spawn
heavyweight or redundant subprocesses on short poll/event cycles. The two
highest-impact issues are `headset.sh` shelling out to `system_profiler
SPBluetoothDataType` every 5 s (one of the slowest tools on macOS), and
`aerospace.sh` issuing three separate `aerospace list-*` queries per workspace
item — and there are 10 workspace items, so a single workspace switch fans out
to ~30 aerospace IPC queries. Several smaller scripts (`cpu.sh`, `ram.sh`,
`battery.sh`, `network_speed.sh`, `ethernet.sh`) parse with long
echo|grep|awk|tr|cut fork chains that could each be collapsed to one `awk`.
These run on 5 s timers and per workspace-change events.

Findings below are ordered by impact. The default-ON performance mode hides the
resource/connectivity items, so some of these timers only run while the user has
toggled performance mode OFF — but they are still real per-tick costs in that
state and are noted as such.

---

## performance-sketchybar-plugins-01 — `headset.sh` spawns `system_profiler SPBluetoothDataType` every 5 s

Severity: high
File: `configs/sketchybar/plugins/headset.sh:8` (driven by `items/headset.sh:15`, `update_freq=5`)

### Description
The headset item polls every 5 seconds and each tick runs:

```sh
HEADSET_STATUS=$(system_profiler SPBluetoothDataType 2>/dev/null | awk ...)
```

`system_profiler SPBluetoothDataType` is one of the most expensive informational
commands on macOS — it routinely takes 0.5–3 s of wall time and forks a heavy
helper that walks the full Bluetooth stack. Running it on a 5 s loop means a
slow subprocess is spawned ~12×/min, ~17k times/day, purely to decide between
two icons. This is the single biggest CPU/wakeup cost in the plugin set.

### Evidence
```sh
# headset.sh:8
HEADSET_STATUS=$(system_profiler SPBluetoothDataType 2>/dev/null | awk '/Connected:/{flag=1} /Not Connected:/{flag=0} flag && /Minor Type: Headphones|Minor Type: Headset/{print}')
```
```sh
# items/headset.sh:15
update_freq=5
```

### Recommendation
Replace `system_profiler` with a far cheaper source and/or back off the cadence:
- Query the IORegistry instead: `ioreg -r -l -n "BNBMouseDevice"`-style lookups,
  or more practically `ioreg -c AppleHSBluetoothDevice`/`system_profiler` is
  avoidable via `defaults read /Library/Preferences/com.apple.Bluetooth` /
  `blueutil --connected` (if available). Any of these are an order of magnitude
  cheaper than `SPBluetoothDataType`.
- At minimum, raise `update_freq` substantially (e.g. 30–60 s) and/or drive the
  item primarily off the existing `system_woke` subscription plus a Bluetooth
  power/connection event, since headset connect/disconnect is a rare, bursty
  event, not something that needs 5 s polling.

---

## performance-sketchybar-plugins-02 — `aerospace.sh` issues 3 aerospace queries per item × 10 items per workspace change

Severity: high
File: `configs/sketchybar/plugins/aerospace.sh:54-57,87` (script of all 10 `space.$sid` items, subscribed to `aerospace_workspace_change`)

### Description
`items/spaces.sh` creates 10 workspace items (1–9, 0), each with
`script="$PLUGIN_DIR/aerospace.sh $sid"` and subscribed to
`aerospace_workspace_change`. So every workspace switch fires `aerospace.sh`
**10 times**. Each invocation independently runs three separate `aerospace`
IPC queries:

```sh
VISIBLE_WORKSPACES=$(aerospace list-workspaces --monitor all --visible ...)   # line 54
FOCUSED_WS=$(aerospace list-workspaces --focused ...)                          # line 57
APP_LIST=$(aerospace list-windows --workspace "$WORKSPACE_ID" --format ...)    # line 87
```

The first two queries (`--visible`, `--focused`) return identical results for
every one of the 10 items, yet are re-executed 10× per switch. Net: ~30
`aerospace list-*` subprocess + IPC round-trips per single workspace change,
where ~12 of them are fully redundant recomputations of the same global state.
On a multi-monitor setup the user changes workspaces frequently, so this is a
genuine hot path.

### Evidence
```sh
# aerospace.sh:54
VISIBLE_WORKSPACES=$(aerospace list-workspaces --monitor all --visible 2>/dev/null)
# aerospace.sh:57
FOCUSED_WS=$(aerospace list-workspaces --focused 2>/dev/null)
# aerospace.sh:87
APP_LIST=$(aerospace list-windows --workspace "$WORKSPACE_ID" --format '%{app-name}' 2>/dev/null)
```
```sh
# items/spaces.sh:41,46  (×10 items)
script="$PLUGIN_DIR/aerospace.sh $sid"
... --subscribe space.$sid aerospace_workspace_change mouse.clicked
```

### Recommendation
The globally-shared `--visible`/`--focused` state should be computed once per
event, not once per item. Two viable patterns within the bash-3.2 constraint:
- Have a single event-driven script query the focused/visible workspaces **and**
  all windows once (`aerospace list-windows --all --format
  '%{workspace}|%{app-name}'`), then emit a batched `sketchybar --set space.1 ...
  --set space.2 ...` for all 10 items in one process — eliminating both the
  per-item re-query of global state and the per-item `sketchybar` fork.
- Or cache the `--visible`/`--focused` results to a `/tmp` file keyed on the
  event so the 10 per-item invocations read the file instead of re-querying
  aerospace twice each.
Either removes ~20 of the ~30 subprocesses per workspace switch.

---

## performance-sketchybar-plugins-03 — `ethernet.sh` runs `networksetup -listallhardwareports` every 5 s

Severity: medium
File: `configs/sketchybar/plugins/ethernet.sh:18` (driven by `items/ethernet.sh`, `update_freq=5`)

### Description
On each 5 s tick the ethernet plugin runs `networksetup
-listallhardwareports` (a slow, fork-heavy SystemConfiguration call) piped
through grep, then loops calling `ifconfig` per matched interface. The hardware
port list is effectively static between hot-plug events — re-enumerating every
5 s to check link status is wasteful.

### Evidence
```sh
# ethernet.sh:18
done < <(networksetup -listallhardwareports | grep -A1 "Ethernet Adapter\|Thunderbolt Ethernet\|USB.*LAN")
# ethernet.sh:13
if ifconfig "$IFACE" 2>/dev/null | grep -q "status: active"; then
```

### Recommendation
`networksetup -listallhardwareports` only needs to be run when the interface set
changes; cache the discovered ethernet interface name(s) to `/tmp` (refresh on a
much longer interval or on a network-change event) and on the 5 s tick only run
the cheap `ifconfig "$IFACE"` link-status check against the cached interface.
Better still, subscribe the item to a network-change event rather than polling at
all.

---

## performance-sketchybar-plugins-04 — Resource plugins parse with long fork chains instead of a single awk

Severity: low
File: `configs/sketchybar/plugins/cpu.sh:3-6`, `ram.sh:7-15`, `battery.sh:6-8`, `network_speed.sh:11,19-21` (all on 5 s timers)

### Description
Several 5 s-cadence plugins capture command output into a variable and then
re-parse it with multiple `echo "$VAR" | grep | awk | tr | cut` pipelines.
Each `echo|grep|awk` link is its own subprocess, multiplied per field:

- `ram.sh` runs **six** separate `echo "$VM_STAT" | grep ... | awk ... | tr ...`
  pipelines (3 forks each = ~18 forks) over one captured `vm_stat` string.
- `cpu.sh` runs two `echo | awk | tr` chains plus an `echo | bc | cut`.
- `battery.sh` runs `echo | grep | cut` plus `echo | grep`.
- `network_speed.sh` parses one `netstat`/`route` line with multiple
  `echo | awk` calls.

Each of these reparses an already-captured string, so the forks are pure
overhead. At 5 s cadence this is minor but recurring (and multiplied by the
network item existing as two copies, network_up and network_down).

### Evidence
```sh
# ram.sh:10-15 (one of six identical-shaped lines)
PAGES_FREE=$(echo "$VM_STAT" | grep "Pages free" | awk '{print $3}' | tr -d '.')
PAGES_ACTIVE=$(echo "$VM_STAT" | grep "Pages active" | awk '{print $3}' | tr -d '.')
...
# cpu.sh:4-6
USER=$(echo "$CPU_INFO" | awk '{print $3}' | tr -d '%')
SYS=$(echo "$CPU_INFO" | awk '{print $5}' | tr -d '%')
TOTAL=$(echo "$USER + $SYS" | bc 2>/dev/null | cut -d. -f1)
```

### Recommendation
Collapse each plugin's parsing into a single `awk` invocation that reads the raw
command output once and emits the final field(s) — e.g. pipe `vm_stat` straight
into one `awk` that accumulates the page counts and prints the percentage, and
let `cpu.sh` do the user+sys sum and truncation inside one `awk` (dropping `bc`,
`tr`, and `cut`). This turns ~18 forks into 1 for `ram.sh` and ~5 into 1 for
`cpu.sh`. Pure parsing change, no behavior difference.
