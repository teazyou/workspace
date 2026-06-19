# Clean-code / refactor review — AeroSpace core config + LaunchAgents

Slice files reviewed in full:
- `configs/aerospace/aerospace.toml`
- `configs/aerospace/com.aerospace.display-profile.plist`
- `configs/aerospace/com.aerospace.empty-watcher.plist`
- `scripts/aerospace-restart.sh`

## Summary

This slice is mostly clean for the maintainability/structure lens. `aerospace-restart.sh` is well-factored (named arrays, a clear stop/start split, no duplicated process lists). The TOML is necessarily verbose because AeroSpace has no loop/variable construct, so the per-key repetition of `move-mouse window-lazy-center` and the `cmd-1..9 → open-dock-app.sh N` rows is not a real refactor target — it is the only way the format can express those bindings, and the guide documents the intent. The findings below are the genuine maintainability issues: a state-file path that is duplicated across the slice boundary, an inconsistent home-path style inside the TOML, and the duplicated PATH/log boilerplate between the two plists (low value because plists cannot share constants).

---

## clean-code-aerospace-core-01 — State-file paths hardcoded in TOML duplicate the toggle scripts' own constants

**Severity:** medium
**File:** `configs/aerospace/aerospace.toml:22`

**Description:**
The startup command resets the two toggle-state files by literal path:
`rm -f /tmp/performance-mode.state /tmp/secondary-bar.state`. Those exact paths are *also* defined as the single source of truth inside the scripts the same line then invokes — `performance-mode.sh:8` (`STATE_FILE="/tmp/performance-mode.state"`) and `secondary-bar-toggle.sh:12` (`STATE_FILE="/tmp/secondary-bar.state"`), and `apply-display-profile.sh:241` reads `/tmp/secondary-bar.state` a fourth time. The state-file contract is therefore expressed in four places across the slice boundary. If a path is ever renamed, the TOML's `rm -f` silently goes stale: the reset no longer clears the real state file, so a (re)start would no longer "re-establish the defaults deterministically" as the comment on lines 18-21 promises — a maintenance trap with no error.

**Evidence:**
```toml
# aerospace.toml:22
'exec-and-forget for i in {1..20}; do sketchybar --query volume >/dev/null 2>&1 && break; sleep 0.3; done; rm -f /tmp/performance-mode.state /tmp/secondary-bar.state; "$HOME"/workspace/configs/aerospace/secondary-bar-toggle.sh; "$HOME"/workspace/configs/aerospace/performance-mode.sh'
```
```sh
# performance-mode.sh:8
STATE_FILE="/tmp/performance-mode.state"
# secondary-bar-toggle.sh:12
STATE_FILE="/tmp/secondary-bar.state"
```

**Recommendation:**
Make the scripts own their reset instead of the TOML hardcoding the paths. Add a `--reset-state` (or `--default`) flag to each toggle script that does `rm -f "$STATE_FILE"` against its own constant, then have the TOML startup line call `secondary-bar-toggle.sh --reset-state` / `performance-mode.sh --reset-state` (or a tiny shared `state-paths.sh` sourced by all four scripts that exports `PERF_STATE` / `SECONDARY_BAR_STATE`). The path string then lives in exactly one place and the TOML can never drift from it.

---

## clean-code-aerospace-core-02 — Inconsistent home-path style for the same script directory in one file

**Severity:** low
**File:** `configs/aerospace/aerospace.toml:22` vs `:28,:235-243,:263-264`

**Description:**
The TOML refers to the very same `~/workspace/configs/aerospace/` directory two different ways within a single file: line 22 uses `"$HOME"/workspace/...` while every other invocation (lines 28, 235-243, 263, 264) uses `~/workspace/...`. Both work, but mixing the two styles for an identical prefix is a needless inconsistency that makes the file harder to scan and grep (`grep '~/workspace'` misses line 22; `grep '\$HOME'` misses the rest) and invites copy-paste of the wrong style for the next binding.

**Evidence:**
```toml
# line 22  ->  "$HOME"/workspace/configs/aerospace/secondary-bar-toggle.sh
# line 235 ->  exec-and-forget ~/workspace/configs/aerospace/open-dock-app.sh 0
# line 263 ->  exec-and-forget ~/workspace/configs/aerospace/performance-mode.sh
```

**Recommendation:**
Pick one style and apply it everywhere. `~/workspace/...` is the majority style in this file and reads more cleanly; normalize line 22 to it (AeroSpace runs these through a shell that performs tilde expansion, as the other lines already rely on).

---

## clean-code-aerospace-core-03 — Duplicated PATH and log-path boilerplate across the two LaunchAgent plists

**Severity:** low
**File:** `configs/aerospace/com.aerospace.display-profile.plist:25-29` and `configs/aerospace/com.aerospace.empty-watcher.plist:28-32`

**Description:**
Both LaunchAgents repeat the identical `EnvironmentVariables > PATH` block (`/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin`) and the same `/tmp/<label>.std{out,err}.log` log-path convention. The autoraise agent (`configs/autoraise/com.autoraise.daemon.plist`, outside this slice) follows the same template, so the PATH string is maintained in (at least) three plists. If the Homebrew prefix ever changes (e.g. an Intel-vs-Apple-Silicon split), every plist must be edited by hand with no shared definition and no failure signal if one is missed.

**Evidence:**
```xml
<!-- both plists, identical -->
<key>EnvironmentVariables</key>
<dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
</dict>
```

**Recommendation:**
Low priority — plists are static XML and cannot reference a shared constant, so there is no in-format dedup. The right place to centralize is generation: have `scripts/installs/setup_symlinks.sh` (or a dedicated installer step) emit these plists from one template that defines the PATH and log-dir once, rather than three checked-in copies drifting independently. If that is more machinery than the value warrants, leave as-is and accept the duplication; do not hand-template the XML in a way that complicates the symlink-source-of-truth model.
