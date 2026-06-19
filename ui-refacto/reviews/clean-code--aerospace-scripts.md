# Clean-code / Refactor Review — AeroSpace helper scripts

**Slice:** `configs/aerospace/*.sh` (apply-display-profile, empty-workspace-watcher, open-dock-app, performance-mode, secondary-bar-toggle, track-workspace-mru)
**Lens:** Maintainability & structure only (no correctness/perf defects).

## Summary

The six scripts are individually readable and reasonably well commented, but they form a tightly-coupled set that shares a contract entirely through hand-built `/tmp` string literals and prose. There is **no shared helper/lib file** (each script is fully standalone — no `source` between them). The highest-value refactor is centralizing the shared `/tmp` state-file path scheme so a rename/typo can't silently break the cross-script contract. Smaller findings: a misleading `gaming_mode_*` naming holdover, coupled grace-cap magic numbers expressed as bare literals in two files, and inconsistent use of named state-file constants vs inline paths. None of the recommendations require Bash 4 features, a linter, or break the symlink model.

---

## clean-code-aerospace-scripts-01 — Shared `/tmp` state-file paths are hand-built string literals duplicated across files, with no single source of truth

**Severity:** medium
**File:** `configs/aerospace/empty-workspace-watcher.sh:75,92`, `configs/aerospace/open-dock-app.sh:53`, `configs/aerospace/track-workspace-mru.sh:19`, `configs/aerospace/apply-display-profile.sh:241`, `configs/aerospace/secondary-bar-toggle.sh:12`

**Description:**
The scripts communicate exclusively through `/tmp` files whose paths are re-typed as string literals in every script that touches them. The exact same scheme is reconstructed in multiple files with no shared constant:

- Grace marker `aerospace-empty-watcher-grace-<ws>` is built in **open-dock-app.sh** (writer) and **empty-workspace-watcher.sh** (reader).
- MRU file `aerospace-ws-mru-mon-<mon>.state` is built in **track-workspace-mru.sh** (writer) and **empty-workspace-watcher.sh** (reader).
- Bar-state `secondary-bar.state` is built in **secondary-bar-toggle.sh** (writer) and **apply-display-profile.sh** (reader).

Because each path is an independent literal, a rename or typo in one file silently desynchronizes the producer/consumer pair — the daemon just stops finding the marker, with no error. This is the classic case for a shared constants helper.

**Evidence:**
```sh
# open-dock-app.sh:53
grace_file="/tmp/aerospace-empty-watcher-grace-${workspace}"
# empty-workspace-watcher.sh:75
grace_file="/tmp/aerospace-empty-watcher-grace-${vis}"

# track-workspace-mru.sh:19
file="/tmp/aerospace-ws-mru-mon-${mon}.state"
# empty-workspace-watcher.sh:92
mru_file="/tmp/aerospace-ws-mru-mon-${mon}.state"

# secondary-bar-toggle.sh:12
STATE_FILE="/tmp/secondary-bar.state"
# apply-display-profile.sh:241
local bar_state_file="/tmp/secondary-bar.state"
```

**Recommendation:**
Add a single sourced helper (e.g. `configs/aerospace/lib-paths.sh`) defining the `/tmp` prefix and path-builder functions, e.g. `grace_file()`, `mru_file()`, and constants for `SECONDARY_BAR_STATE` / `PERFORMANCE_STATE`. Each script `source "$(dirname "$0")/lib-paths.sh"` (matching the existing `"$(dirname "$0")/apply-display-profile.sh"` invocation pattern in secondary-bar-toggle.sh) and calls the builder instead of re-typing the literal. Stays Bash 3.2-safe (plain functions, no associative arrays) and the symlink model is unaffected since the lib lives in the same repo dir.

---

## clean-code-aerospace-scripts-02 — `performance-mode.sh` functions named `gaming_mode_on`/`gaming_mode_off`, contradicting the file's own "performance mode" naming

**Severity:** low
**File:** `configs/aerospace/performance-mode.sh:18,39,70,72`

**Description:**
The file, its header comment, the state file (`/tmp/performance-mode.state`), the echo strings (`"Performance mode ON"`), the guide, and the aerospace.toml binding all call this feature **performance mode**. The two core functions are instead named `gaming_mode_on` / `gaming_mode_off` — a stale name from an earlier concept. This inconsistent vocabulary inside a single small file forces a reader to mentally map "gaming" == "performance" and is exactly the kind of naming drift a clean-code pass should flag.

**Evidence:**
```sh
# performance-mode.sh
gaming_mode_on() {        # :18
  ...
  echo "Performance mode ON"   # :36
gaming_mode_off() {       # :39
  ...
  echo "Performance mode OFF"  # :65
  gaming_mode_off         # :70
  gaming_mode_on          # :72
```

**Recommendation:**
Rename to `performance_mode_on` / `performance_mode_off` (or `perf_mode_*`) to match every other reference in the file and stack. Pure local rename, no external callers (functions are file-internal).

---

## clean-code-aerospace-scripts-03 — Coupled grace-cap timing constants are bare literals in two files, with the (intentional) relationship only in prose

**Severity:** medium
**File:** `configs/aerospace/empty-workspace-watcher.sh:37,60`, `configs/aerospace/open-dock-app.sh:60`

**Description:**
The guide documents a deliberate coupling: the watcher's 20s grace cap is "intentionally slightly longer than open-dock-app.sh's ~18s placement-enforcer cap." But the two values live as unrelated literals in two files — `grace_seconds=20` in the watcher, and an opaque `90` loop bound × `sleep 0.2` (= 18s) in open-dock-app.sh. The `90` in particular is a magic number with no named meaning; the relationship that makes them correct is captured only in a comment in a third file. A future tuning of one side has no structural signal pointing at the other.

**Evidence:**
```sh
# empty-workspace-watcher.sh:37
grace_seconds=20
# empty-workspace-watcher.sh:60
if [[ $age -lt $grace_seconds ]]; then

# open-dock-app.sh:60  (90 iterations * 0.2s sleep ≈ 18s, never named)
while [[ $i -lt 90 ]]; do
    sleep 0.2
```

**Recommendation:**
Name the enforcer cap in open-dock-app.sh, e.g. `placement_cap_seconds=18` with `max_iters=$(( placement_cap_seconds * 5 ))` (5 ticks/sec), and add an inline comment cross-referencing `grace_seconds`. Better still, define both `GRACE_SECONDS` and `PLACEMENT_CAP_SECONDS` in the shared lib from finding 01 so the "grace must exceed cap" invariant lives in one place.

---

## clean-code-aerospace-scripts-04 — State-file path is a named constant in some scripts but an inline literal in others; poll interval `0.5` repeated

**Severity:** low
**File:** `configs/aerospace/apply-display-profile.sh:8`, `configs/aerospace/performance-mode.sh:8`, `configs/aerospace/secondary-bar-toggle.sh:12` vs `configs/aerospace/empty-workspace-watcher.sh:51,135`

**Description:**
Convention is inconsistent across the slice. `apply-display-profile.sh`, `performance-mode.sh`, and `secondary-bar-toggle.sh` all hoist their state path into a top-level `STATE_FILE=` / `LOG_FILE=` constant, but `empty-workspace-watcher.sh` and `track-workspace-mru.sh` inline every `/tmp/...` path at use-site. Separately, the watcher's 500ms poll interval is written as the literal `sleep 0.5` twice (the early-continue path and the loop tail), so a tuning change must be made in two spots — and the guide explicitly lists "poll interval" as something you Edit for.

**Evidence:**
```sh
# Named-constant convention (good):
# performance-mode.sh:8
STATE_FILE="/tmp/performance-mode.state"

# Inline literals + duplicated poll interval (inconsistent):
# empty-workspace-watcher.sh:51
        sleep 0.5
# empty-workspace-watcher.sh:135
    sleep 0.5
```

**Recommendation:**
Apply the named-constant convention uniformly: in `empty-workspace-watcher.sh` add `poll_interval=0.5` near `grace_seconds` and use it in both `sleep` sites; pull the grace/MRU path builders from the finding-01 lib. Minimal, mechanical, and aligns every script in the slice on one convention.

---

## clean-code-aerospace-scripts-05 — Repeated cursor-warp call and inline grace-age computation are un-named one-offs

**Severity:** low
**File:** `configs/aerospace/open-dock-app.sh:74,133`, `configs/aerospace/empty-workspace-watcher.sh:77`

**Description:**
`aerospace move-mouse window-lazy-center` is the documented "warp the cursor onto the focused window" idiom and appears twice in open-dock-app.sh (the cold-launch landing path and the running-app focus path), each accompanied by a multi-line explanatory comment. The grace-marker age check is an inline literal-heavy expression `$(( $(date +%s) - $(stat -f %m "$grace_file" ...) ))` that re-implements "how old is this marker." Both are small candidates for a named helper so the intent reads once and the idiom is consistent if reused later.

**Evidence:**
```sh
# open-dock-app.sh:74  and  :133  (same call, two sites)
aerospace move-mouse window-lazy-center 2>/dev/null
...
aerospace move-mouse window-lazy-center

# empty-workspace-watcher.sh:77  (inline age math)
age=$(( $(date +%s) - $(stat -f %m "$grace_file" 2>/dev/null || echo 0) ))
```

**Recommendation:**
Optional, low-priority: extract a `warp_cursor_to_focused()` wrapper (single home for the comment) and a `file_age_seconds <path>` helper in the shared lib. Only worth doing if finding 01's lib is adopted; otherwise leave as-is to respect the "few high-confidence findings" bar.
