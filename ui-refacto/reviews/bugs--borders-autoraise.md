# Bugs / Correctness Review — JankyBorders + AutoRaise

## Summary

Reviewed `configs/borders/bordersrc`, `configs/autoraise/config`, and
`configs/autoraise/com.autoraise.daemon.plist` against the documented intent in
`configs/guide-window-manager.md`.

These three files are small and almost entirely declarative (no shell loops,
no poll/lock logic, no state files, no traps), so the usual correctness hazards
(word-splitting, Bash 3.2 incompatibilities, race conditions) do not apply here.
All AutoRaise config keys/values were verified against the installed binary
(`AutoRaise 5.6`): `pollMillis`, `delay`, `disableKey`, `requireMouseStop`,
`mouseDelta`, and `ignoreSpaceChanged` are all recognized and in range, and the
plist is well-formed with absolute paths.

The only real defects are **stale comments that contradict the actual
runtime configuration** — specifically the claim that cursor warping is driven
by AeroSpace's `on-focus-changed` callback, which is in fact set to `[]`
(empty) in `aerospace.toml`. These are correctness defects in the
documentation-as-spec sense (code/comment contradicts the live wiring) but are
low severity because they do not change runtime behavior of AutoRaise itself.

## Findings

### bugs-borders-autoraise-01 — `config` comment claims warping uses `on-focus-changed`, but that callback is empty

- **File:** `configs/autoraise/config:39-41`
- **Severity:** low
- **Description:** The trailing comment block asserts that cursor warping is
  performed by AeroSpace's `on-focus-changed` callback. The actual
  `aerospace.toml` sets `on-focus-changed = []` (line 65) and
  `on-focused-monitor-changed = []` (line 64); warping is instead appended to
  each individual keybinding (`alt-hjkl`, `alt-1-9`, etc.). The guide itself
  documents this deliberate change (guide lines 56-57). So the AutoRaise config
  comment describes a mechanism that no longer exists, which will mislead anyone
  reasoning about why AutoRaise's own warp is disabled.
- **Evidence:**
  ```
  # Cursor warping is handled by AeroSpace's mouse-follows-focus callback
  # (on-focus-changed = move-mouse window-lazy-center in aerospace.toml), so
  # AutoRaise's own warp is left disabled to avoid two tools fighting over the cursor.
  ```
  vs. `aerospace.toml:65` → `on-focus-changed = []`.
- **Recommendation:** Update the comment to reflect reality: warping is attached
  to the individual AeroSpace keybindings (and inside `open-dock-app.sh`), not
  to `on-focus-changed`. The substantive point ("AutoRaise's own warp stays
  disabled so the two tools don't fight over the cursor") is still correct and
  should be kept.

### bugs-borders-autoraise-02 — Guide's documented border colors do not match `bordersrc`

- **File:** `configs/borders/bordersrc:10-11` (and guide line 177)
- **Severity:** low
- **Description:** The guide describes the border theme as "Tokyo Night theme:
  active=0xffc0caf5, inactive=0xff414868". The actual `bordersrc` uses a dark-red
  theme (`active_color=0xffb22222`, `inactive_color=0xff4d1a1a`). This is a
  guide-vs-code contradiction. The `bordersrc` file is internally consistent and
  valid (correct `0xAARRGGBB` format, valid `style`/`width`/`hidpi` options), and
  the red theme is the newer intent per recent commit history, so the defect is
  in the stale guide, not the code. Flagged because the review treats the guide
  as the spec.
- **Evidence:**
  ```
  active_color=0xffb22222
  inactive_color=0xff4d1a1a
  ```
  vs. guide line 177: `Tokyo Night theme: active=0xffc0caf5, inactive=0xff414868`.
- **Recommendation:** Update `guide-window-manager.md` line 177 (and the
  `_index.md` description, which says active=0xffc0caf5) to the current red
  theme so the documented spec matches the live config.
