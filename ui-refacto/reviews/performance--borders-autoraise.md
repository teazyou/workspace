# Performance Review — JankyBorders + AutoRaise

## Summary

Slice reviewed: `configs/borders/bordersrc`, `configs/autoraise/config`, `configs/autoraise/com.autoraise.daemon.plist`.

This slice is almost entirely declarative and has very little code that runs on a hot path:

- `bordersrc` spawns the `borders` daemon exactly once at config-load time. There is no loop, no per-tick subprocess spawning, nothing to optimize for runtime efficiency. **Clean for this lens.**
- `com.autoraise.daemon.plist` runs the AutoRaise binary once under `KeepAlive`. No `StartInterval`, no per-tick relaunch. **Clean for this lens.**
- `autoraise/config` only sets key=value tuning for AutoRaise's internal (compiled C) poll loop. The single performance-relevant lever here is `pollMillis`, which directly sets how often the daemon wakes to query the accessibility API. One low-severity finding below; it is a deliberate, documented trade-off, not a defect.

No high-severity performance issues were found in this slice. The poll cadence is the only runtime-cost knob, and it lives in a compiled binary the config merely parameterizes.

---

## Findings

### performance-borders-autoraise-01 — Continuous 5 Hz accessibility poll while the mouse is idle

- **Severity:** low
- **File:** `configs/autoraise/config:12` (with `:30` and `:34`)
- **How often the hot path runs:** every 200 ms (5 times/second), continuously, for the lifetime of the daemon — including when the mouse is completely stationary.

**Description**

`pollMillis=200` sets the AutoRaise daemon to wake every 200 ms and read the pointer position / the window under the cursor (an accessibility-API query) on every tick. `requireMouseStop=false` and `mouseDelta=1.0` gate only the *focus action* (whether a raise is issued), not the *wake*: the daemon still polls 5×/s even when the cursor has not moved. There is no idle back-off, so the cost is paid 24/7 rather than only during cursor motion.

This is small per tick (it's the AutoRaise binary doing the work, not a bash fork), but it is the only continuous runtime cost in this slice, and the config's own comments confirm the wake happens on every tick regardless of motion.

**Evidence**

`configs/autoraise/config`:
```
# How often the mouse position is polled (ms). With requireMouseStop=false (below)
# this interval IS the fly-over debounce: focus lands on whatever is under the cursor
# at each tick ...
pollMillis=200
```
```
# false: don't wait for the mouse to stop — focus whatever is under the cursor at each
# poll tick. ...
requireMouseStop=false
```
```
# Ignore mouse jitter smaller than this before considering a focus change. ...
mouseDelta=1.0
```

**Recommendation**

This is a deliberate, documented latency-vs-cost trade-off (the comment explains 200 ms is the chosen fly-over debounce), so it is acceptable as-is. If idle CPU ever matters, the cheapest lever is raising `pollMillis` (e.g. 250–300 ms) to cut wake frequency, accepting slightly less snappy focus. AutoRaise has no native idle-backoff setting, so the value here is the only available knob — no code change in this repo can make the poll motion-gated. Treat this as a tuning note, not a bug.
