# Bugs / Correctness Review — AeroSpace core config + LaunchAgents

Slice files:
- `configs/aerospace/aerospace.toml`
- `configs/aerospace/com.aerospace.display-profile.plist`
- `configs/aerospace/com.aerospace.empty-watcher.plist`
- `scripts/aerospace-restart.sh`

## Summary

This slice is largely clean for the correctness lens. The two LaunchAgent plists are
well-formed and match the documented intent (display-profile = `StartInterval`-driven,
empty-watcher = `RunAtLoad`+`KeepAlive`+`ThrottleInterval`). The TOML is syntactically
valid; the `display.*` / `built-in.*` entries that look odd in `[gaps]` and
`[workspace-to-monitor-force-assignment]` are deliberately rewritten by
`apply-display-profile.sh` (out of this slice), so the committed values are documented as
"last state" and are not bugs.

Three concrete issues found, all low/medium severity: a startup ordering race between
`aerospace-restart.sh` and AeroSpace's own `after-startup-command` over the
display-profile agent, an incorrect inline comment that claims all three agents are
`KeepAlive` (one is not), and the restart script's "wait for AeroSpace" loop gating on
process existence rather than server readiness.

---

## bugs-aerospace-core-01 — Restart script races AeroSpace's own startup over the display-profile agent

- Severity: medium
- File: `scripts/aerospace-restart.sh:43-55` (interacts with `aerospace.toml:14-23` and `configs/aerospace/performance-mode.sh:19-20`)

Description:
The documented default at startup is performance mode **ON**, which means
`performance-mode.sh` boots **out** `com.aerospace.display-profile`
(`performance-mode.sh:20`). `aerospace.toml`'s `after-startup-command` runs perf-mode
*after* polling up to ~6 s for SketchyBar (`aerospace.toml:22`). Meanwhile
`aerospace-restart.sh` only waits for the AeroSpace **process to exist** and then
unconditionally bootstraps all three agents — including display-profile — back in
(lines 46-55). The end-state of display-profile (loaded vs. unloaded) therefore depends
purely on whether restart's `bootstrap` loop runs before or after the async perf-mode
boot-out fires.

Evidence:
```sh
# aerospace-restart.sh
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pgrep -x AeroSpace >/dev/null 2>&1 && break   # succeeds the instant the process spawns
  sleep 0.5
done
for agent in "${AGENTS[@]}"; do
  launchctl bootstrap "$DOMAIN" "$AGENTS_DIR/$agent.plist" 2>/dev/null \   # re-loads display-profile
```
```toml
# aerospace.toml after-startup-command
'... for i in {1..20}; do sketchybar --query volume ...; done; ...; performance-mode.sh'
```
```sh
# performance-mode.sh (perf ON path)
launchctl bootout "$GUI_DOMAIN" "$DISPLAY_PROFILE_PLIST" 2>/dev/null || true
```

In the common timing (restart bootstraps fast, perf-mode boots out ~6 s later) the state
lands correctly (display-profile unloaded, matching perf-ON). But the ordering is not
guaranteed: if SketchyBar comes up before restart reaches its bootstrap loop, perf-mode's
boot-out can run *first* and restart's bootstrap then re-loads display-profile, leaving it
running while perf mode is nominally ON — contradicting the guide
(`guide-window-manager.md:104` "performance mode … unloads display-profile LaunchAgent").

Recommendation:
Have `aerospace-restart.sh` either (a) skip re-bootstrapping `com.aerospace.display-profile`
and let the `after-startup-command` own its load/unload state, or (b) wait for the
`after-startup-command` to finish (e.g. poll `/tmp/performance-mode.state` existence) before
bootstrapping, so the two writers don't race over the same agent.

---

## bugs-aerospace-core-02 — Inline comment claims all three agents are `KeepAlive`; display-profile is not

- Severity: low
- File: `scripts/aerospace-restart.sh:27`

Description:
The comment over the bootout loop asserts every agent is `KeepAlive=true`, which is the
stated reason they "must be booted out, not just killed." But
`com.aerospace.display-profile.plist` has **no** `KeepAlive` key — it is
`StartInterval`-driven (`com.aerospace.display-profile.plist:13-17`). Only empty-watcher
and autoraise are `KeepAlive`. This is a factual mismatch in the rationale; it does not
break the loop (`bootout` is correct for both agent types) but the justification is wrong
and could mislead future edits about why the loop exists.

Evidence:
```sh
# aerospace-restart.sh:27
# Unload LaunchAgents (KeepAlive=true, so they must be booted out, not just killed)
```
```xml
<!-- com.aerospace.display-profile.plist: no KeepAlive, StartInterval instead -->
<key>StartInterval</key>
<integer>5</integer>
<key>RunAtLoad</key>
<true/>
```

Recommendation:
Reword the comment to note the agents are `KeepAlive`/auto-relaunching (empty-watcher,
autoraise) *or* `StartInterval`-scheduled (display-profile), all of which `launchctl bootout`
correctly stops, whereas `killall` would not.

---

## bugs-aerospace-core-03 — "Wait for AeroSpace" loop gates on process existence, not server readiness

- Severity: low
- File: `scripts/aerospace-restart.sh:45-49`

Description:
The comment says "Wait for AeroSpace to be up before the agents that depend on it," but the
loop breaks as soon as `pgrep -x AeroSpace` matches — i.e. the instant the process spawns,
which is well before AeroSpace's control socket is accepting commands. The agents
bootstrapped immediately afterward (empty-watcher, display-profile) both shell out to the
`aerospace` CLI, which will error against a not-yet-ready server.

Evidence:
```sh
for _ in 1 2 3 4 5 6 7 8 9 10; do
  pgrep -x AeroSpace >/dev/null 2>&1 && break   # process exists != server ready
  sleep 0.5
done
```

This is low severity because both daemons retry (empty-watcher polls every 500 ms,
display-profile every 5 s) and self-heal once the server is up; the practical impact is a
few seconds of stderr noise / a missed first tick.

Recommendation:
If a cleaner start is wanted, gate on actual readiness, e.g.
`aerospace list-workspaces --all >/dev/null 2>&1 && break` instead of `pgrep`.
