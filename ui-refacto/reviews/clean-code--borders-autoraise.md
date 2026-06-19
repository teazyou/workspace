# Clean-code / refactor review — JankyBorders + AutoRaise slice

**Lens:** Maintainability & structure only (no correctness/perf defects).
**Files reviewed (read in full):**
- `/Users/teazyou/workspace/configs/borders/bordersrc`
- `/Users/teazyou/workspace/configs/autoraise/config`
- `/Users/teazyou/workspace/configs/autoraise/com.autoraise.daemon.plist`

## Summary

This slice is small and almost entirely declarative: one short bash wrapper
(`bordersrc`), one `key=value` config (`autoraise/config`), and one standard
LaunchAgent plist. There is **no cross-file logic duplication, no over-long
function, and no shared-helper extraction opportunity** that would respect the
repo's per-tool symlink-source-of-truth model (the three files are three
different formats for three different tools, each symlinked individually).

The only real maintainability issues are **stale/contradictory comments** that
describe a superseded architecture and will actively mislead future edits.
Magic-number observations (hex colors, `/tmp` log paths) are noted but do not
rise to actionable findings under the repo conventions. Two findings total, both
documentation-drift / comment-rot.

---

## clean-code-borders-autoraise-01 — Stale comment in `autoraise/config` describes a removed `on-focus-changed` warp callback

- **Severity:** medium
- **File:** `/Users/teazyou/workspace/configs/autoraise/config:39-41`

**Description.** The trailing comment block claims AeroSpace performs cursor
warping via an `on-focus-changed` callback, and the in-comment code snippet even
spells out `on-focus-changed = move-mouse window-lazy-center`. But the live
`aerospace.toml` has `on-focus-changed = []` (empty) and `on-focused-monitor-changed
= []`; the `move-mouse window-lazy-center` warp is instead appended to each
individual keybinding. This is the exact architecture the guide stresses was
deliberately changed (guide line 56). A future editor tuning AutoRaise will read
this comment and believe global mouse-follows-focus is still wired on a callback,
which is false. Comment rot of this kind is a maintainability hazard precisely
because it reads as authoritative.

**Evidence.**
```
# autoraise/config:39-41
# Cursor warping is handled by AeroSpace's mouse-follows-focus callback
# (on-focus-changed = move-mouse window-lazy-center in aerospace.toml), so
# AutoRaise's own warp is left disabled to avoid two tools fighting over the cursor.
```
Contradicted by `aerospace.toml:64-65`:
```
on-focused-monitor-changed = []
on-focus-changed = []
```
and per-binding warps such as `aerospace.toml:175` `alt-h = ['focus left', 'move-mouse window-lazy-center']`.

**Recommendation.** Reword to match reality without naming a callback that no
longer exists, e.g.: "Cursor warping is handled by AeroSpace — `move-mouse
window-lazy-center` is appended to the individual focus/workspace keybindings
(the global `on-focus-changed` callback is deliberately empty). AutoRaise's own
warp stays disabled so the two tools don't fight over the cursor." The
*intent* (AutoRaise warp off, AeroSpace owns warping) is correct and should be
kept; only the mechanism description is stale.

---

## clean-code-borders-autoraise-02 — `bordersrc` header comment documents a color format but the file/theme have diverged from the architecture guide

- **Severity:** low
- **File:** `/Users/teazyou/workspace/configs/borders/bordersrc:1-12`

**Description.** A pure documentation-drift note. `bordersrc` is a "Dark red
themed" config (`active_color=0xffb22222`, `inactive_color=0xff4d1a1a`), but the
architecture guide (`guide-window-manager.md:177-178`) still documents this file
as the "Tokyo Night theme: active=0xffc0caf5, inactive=0xff414868". The guide is
the stated spec for this slice, so the mismatch is worth flagging for the sync
convention the repo enforces (keep docs in step with the files). The hex color
literals themselves are *not* an actionable magic-number finding: JankyBorders is
a standalone tool symlinked on its own, and the only palette in the repo
(`configs/sketchybar/colors.sh`) is a separate app's shell-export file that
`bordersrc` cannot reasonably source — so inlining the two colors here is the
correct, conventional choice. The inline format comment (lines 4-5) and the
commented "Additional options available" block (lines 13-17) are intentional
reference documentation, consistent with the repo's commenting style, and should
**not** be treated as dead code.

**Evidence.**
```
# bordersrc:11-12
    active_color=0xffb22222
    inactive_color=0xff4d1a1a
```
vs `guide-window-manager.md:177-178`:
```
- JankyBorders config (window border styling)
- Tokyo Night theme: active=0xffc0caf5, inactive=0xff414868
```

**Recommendation.** Update the `./configs/borders/bordersrc` description in
`guide-window-manager.md` (and the matching `_index.md` entry if it states a
theme) to the current dark-red values, per the repo's "keep the guide/index in
sync" convention. No change to `bordersrc` itself is warranted.

---

## Non-findings (checked, deliberately not reported)

- **Shared lockdir / state-file / monitor-id / `/tmp`-path helpers:** none of
  these patterns appear in this slice — those live in the aerospace `*.sh`
  scripts (other slice). Nothing to centralize here.
- **`/tmp/autoraise.{stdout,stderr}.log` in the plist:** standard, single-use
  LaunchAgent log paths; mirrors the documented `com.aerospace.*` pattern. Not a
  magic-string worth extracting.
- **`pollMillis` / `delay` / `mouseDelta` "magic numbers" in `autoraise/config`:**
  this *is* the named-config file — each value is a documented key with an
  extensive explanatory comment. That is the correct home for these constants.
