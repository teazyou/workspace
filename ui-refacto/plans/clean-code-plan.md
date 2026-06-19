# Clean-code / refactor implementation plan — window-manager configs

## Summary

This plan turns the consolidated clean-code review findings into a concrete, ordered set of edits for the AeroSpace + SketchyBar + JankyBorders + AutoRaise config slice (repo root `/Users/teazyou/workspace`). All edits respect the repo's hard constraints: **Bash 3.2 compatibility** (no `declare -A`, no `mapfile`), the **symlink model** (edit source files in `configs/`, write through symlinks with `cp` not `mv`), **no macOS notifications**, **no linter/auto-lint**, and **no change to documented runtime behavior**.

The centerpiece is a new sourced helper `configs/aerospace/lib-paths.sh` that becomes the single source of truth for the cross-script `/tmp` state-file paths and the two coupled timing constants. Several findings collapse into it; the rest are localized renames, a single-source-of-truth color fix in SketchyBar, and pure documentation reconciliation.

### What was dropped or downgraded (and why)

- **clean-code-aerospace-core-03** (plist `PATH` block duplicated; "centralize via installer template"): DROPPED. The plists are each individually symlinked declarative files; there is no generation/templating step in this repo to hang a shared template on, and inventing one is out of scope and higher-risk than the 3-line duplication it removes. The borders-autoraise reviewer reached the same "no shared-helper opportunity that respects the per-tool symlink model" conclusion for the sibling autoraise plist.
- **clean-code-sketchybar-plugins-03** (collapse the four date-formatter one-liners into one parameterized plugin): DOWNGRADED to a no-op. Of the four, `time.sh` and `date.sh` are wired to the live `time`/`date` items (via `items/calendar.sh`), `calendar.sh` plugin is referenced by no active item path in `sketchybarrc` (the `calendar` group is built from `time`+`date`), and `clock.sh` is unused. A parameterized rewrite would have to re-wire `script=`/env on live items for marginal gain and real regression risk. Not worth it against the "few high-confidence findings" bar.
- **clean-code-sketchybar-plugins-04 (zen.sh)** and **clean-code-sketchybar-plugins-05 (title.sh)**: DROPPED as live edits. Both plugins are **dead code** — no active item file creates the items they drive (`title`, `title_proxy`, `aerospace.mode`, `front_app.*`, `apple.logo` are all in disabled/commented item files per `sketchybarrc`). Refactoring unreachable scripts is low value and the `grep/cut`→`jq` change can't even be exercised. Captured as an open question (delete vs keep) instead.
- **clean-code-sketchybar-plugins-06** (network `update_freq` magic `5`): KEPT but as the low-risk local-constant form only (name `UPDATE_FREQ=5` in `network_speed.sh`), NOT the "pass interval via env from the item" form, which would touch the live `network_up`/`network_down` item definitions for little benefit. The item files already hardcode `update_freq=5`; a comment cross-reference plus a named constant is the safe fix.
- **borders/autoraise inline hex + autoraise poll constants**: confirmed NON-actionable (standalone tools, the config file *is* the named-constant home). Only the two documentation-rot findings remain.

---

## Ordered change list

Changes are ordered so dependencies come first: the shared lib (CC-01) lands before the scripts that source it.

---

### CC-01 — Add shared `lib-paths.sh` for cross-script state paths + coupled timing constants

- **id:** CC-01
- **file:** `configs/aerospace/lib-paths.sh` (NEW)
- **change:** Create a sourced helper (no shebang needed for a sourced lib; add `#!/bin/bash` header comment for editor consistency, mark non-executable). Define, Bash-3.2-safe, plain functions + constants:
  - `AERO_TMP="/tmp"` prefix constant.
  - `grace_file() { echo "/tmp/aerospace-empty-watcher-grace-$1"; }`
  - `mru_file()   { echo "/tmp/aerospace-ws-mru-mon-$1.state"; }`
  - `mru_lock()   { echo "/tmp/aerospace-ws-mru-mon-$1.lock"; }`
  - `SECONDARY_BAR_STATE="/tmp/secondary-bar.state"`
  - `PERFORMANCE_MODE_STATE="/tmp/performance-mode.state"`
  - The two coupled grace/placement constants with the invariant documented in ONE place: `GRACE_SECONDS=20` and `PLACEMENT_CAP_SECONDS=18` with a comment stating `GRACE_SECONDS` must stay ≥ `PLACEMENT_CAP_SECONDS`.
  - `POLL_INTERVAL=0.5` (watcher poll) as a named constant.
  - A `file_age_seconds() { echo $(( $(date +%s) - $(stat -f %m "$1" 2>/dev/null || echo 0) )); }` helper (used by CC-04).
- **rationale:** Establishes a single source of truth for the `/tmp` contract that producers and consumers currently re-type as independent literals, and for the grace/placement invariant that today lives only in a guide comment. Everything else in the aerospace-scripts slice depends on this file existing.
- **addresses:** clean-code-aerospace-scripts-01, -03, -04, -05; clean-code-aerospace-core-01
- **risk:** low (new file, nothing sources it yet)
- **dependsOn:** none

---

### CC-02 — Source `lib-paths.sh` and replace literals in `open-dock-app.sh`

- **id:** CC-02
- **file:** `configs/aerospace/open-dock-app.sh`
- **change:** After the header block, add `source "$(dirname "$0")/lib-paths.sh"`. Replace `grace_file="/tmp/aerospace-empty-watcher-grace-${workspace}"` (line 53) with `grace_file="$(grace_file "$workspace")"` (or assign to a distinct var to avoid shadowing the function name — use `grace_marker="$(grace_file "$workspace")"` and update the two later references at lines 54 and 80). Replace the bare loop bound `while [[ $i -lt 90 ]]` (line 60) with a derived `max_iters=$(( PLACEMENT_CAP_SECONDS * 5 ))` (5 = 1/0.2s sleep) computed once before the loop, plus a one-line comment cross-referencing `GRACE_SECONDS`. Leave the two `aerospace move-mouse window-lazy-center` warp calls in place (CC-04 optionally extracts them).
- **rationale:** Removes the hand-built grace-marker literal shared with the watcher and names the opaque `90` (= 18s) placement cap, tying it structurally to the grace cap.
- **addresses:** clean-code-aerospace-scripts-01, -03
- **risk:** low (paths/values are byte-identical to today; behavior unchanged)
- **dependsOn:** CC-01

---

### CC-03 — Source `lib-paths.sh` and replace literals in `empty-workspace-watcher.sh`

- **id:** CC-03
- **file:** `configs/aerospace/empty-workspace-watcher.sh`
- **change:** Add `source "$(dirname "$0")/lib-paths.sh"` near the top. Remove the local `grace_seconds=20` (line 37) and use `$GRACE_SECONDS`. Replace `grace_file="/tmp/aerospace-empty-watcher-grace-${vis}"` (line 75) with `grace_file="$(grace_file "$vis")"` (use a non-shadowing var name as in CC-02). Replace `mru_file="/tmp/aerospace-ws-mru-mon-${mon}.state"` (line 92) with `mru_file="$(mru_file "$mon")"` (again non-shadowing var). Replace both literal `sleep 0.5` (lines 51, 135) with `sleep "$POLL_INTERVAL"`. Optionally replace the inline grace-age expression (line 77) with `age=$(file_age_seconds "$grace_marker")` (ties into CC-04).
- **rationale:** Unifies the watcher onto the shared path builders and the named poll/grace constants; both `sleep 0.5` sites now move together.
- **addresses:** clean-code-aerospace-scripts-01, -03, -04, -05
- **risk:** low (identical paths/values; daemon behavior unchanged)
- **dependsOn:** CC-01

---

### CC-04 — Source `lib-paths.sh` in `track-workspace-mru.sh` (MRU file + lock builders)

- **id:** CC-04
- **file:** `configs/aerospace/track-workspace-mru.sh`
- **change:** Add `source "$(dirname "$0")/lib-paths.sh"`. Replace `file="/tmp/aerospace-ws-mru-mon-${mon}.state"` (line 19) with `file="$(mru_file "$mon")"` and `lock="/tmp/aerospace-ws-mru-mon-${mon}.lock"` (line 20) with `lock="$(mru_lock "$mon")"`.
- **rationale:** This script is the *writer* of the MRU file the watcher reads; pairing both ends on the same builder is the core of finding -01 (a rename now changes one place).
- **addresses:** clean-code-aerospace-scripts-01, -04
- **risk:** low (identical paths; `exec-on-workspace-change` hot path, but logic unchanged)
- **dependsOn:** CC-01

---

### CC-05 — Rename `gaming_mode_*` → `performance_mode_*` and use shared state constant in `performance-mode.sh`

- **id:** CC-05
- **file:** `configs/aerospace/performance-mode.sh`
- **change:** Rename the two functions `gaming_mode_on`/`gaming_mode_off` → `performance_mode_on`/`performance_mode_off` (definitions at lines 18/39 and the two callers at lines 70/72). Add `source "$(dirname "$0")/lib-paths.sh"` and replace `STATE_FILE="/tmp/performance-mode.state"` (line 8) with `STATE_FILE="$PERFORMANCE_MODE_STATE"` (or use the shared var directly). Keep the `echo "Performance mode ON/OFF"` stdout lines (they are not notifications). No external caller references the function names (aerospace.toml calls the script, not the functions).
- **rationale:** Removes the stale `gaming` vocabulary that contradicts every other reference in the file/stack, and folds the performance-mode state path onto the shared constant.
- **addresses:** clean-code-aerospace-scripts-02; clean-code-aerospace-core-01 (state path)
- **risk:** low (file-internal rename; no external callers)
- **dependsOn:** CC-01

---

### CC-06 — Source `lib-paths.sh` in `secondary-bar-toggle.sh` (bar-state constant)

- **id:** CC-06
- **file:** `configs/aerospace/secondary-bar-toggle.sh`
- **change:** Add `source "$(dirname "$0")/lib-paths.sh"` and replace `STATE_FILE="/tmp/secondary-bar.state"` (line 12) with `STATE_FILE="$SECONDARY_BAR_STATE"`. Leave the `apply-display-profile.sh --force` delegation untouched.
- **rationale:** The bar-state path is duplicated between this writer and `apply-display-profile.sh`'s reader; centralizing here is half of that pairing.
- **addresses:** clean-code-aerospace-scripts-01, -04; clean-code-aerospace-core-01
- **risk:** low
- **dependsOn:** CC-01

---

### CC-07 — Use shared bar-state constant in `apply-display-profile.sh`

- **id:** CC-07
- **file:** `configs/aerospace/apply-display-profile.sh`
- **change:** Add `source "$(dirname "$0")/lib-paths.sh"` near the top (after `set -euo pipefail`). Replace the local `local bar_state_file="/tmp/secondary-bar.state"` (line 241) with a reference to `$SECONDARY_BAR_STATE`. Do NOT touch `STATE_FILE`/`LOG_FILE` (the display-profile fingerprint/log — those are private to this script, not cross-script contract). Leave all gap-calculation logic untouched.
- **rationale:** Completes the bar-state pairing started in CC-06 so the path lives in exactly one place across producer and consumer.
- **addresses:** clean-code-aerospace-scripts-01; clean-code-aerospace-core-01
- **risk:** low (path identical; this script is run every 5s by a LaunchAgent, but only the literal is replaced)
- **dependsOn:** CC-01, CC-06

---

### CC-08 — Reset shared state via the toggle scripts (or shared constants) in `aerospace.toml` startup

- **id:** CC-08
- **file:** `configs/aerospace/aerospace.toml`
- **change:** In the third `after-startup-command` (line 22), the hardcoded `rm -f /tmp/performance-mode.state /tmp/secondary-bar.state` duplicates the now-centralized paths. Since TOML cannot source a shell lib, the cleanest in-scope option is to source the lib inline in that one shell command: change the `exec-and-forget` body to `... rm -f /tmp/performance-mode.state /tmp/secondary-bar.state; ...` → `... source ~/workspace/configs/aerospace/lib-paths.sh; rm -f "$PERFORMANCE_MODE_STATE" "$SECONDARY_BAR_STATE"; ...`. Also normalize the path style in this line: replace the `"$HOME"/workspace/...` form (used twice for the two toggle script invocations) with the `~/workspace/...` tilde form used everywhere else in the file (lines 28, 235-243). NOTE: the `~` must be unquoted to expand — keep the script paths unquoted exactly as the existing `~/workspace/...` bindings do.
- **rationale:** Eliminates the fourth copy of the two state paths (so a rename in the lib propagates to the reset) and normalizes the lone `$HOME`-form path to the file's tilde convention (clean-code-aerospace-core-02).
- **addresses:** clean-code-aerospace-core-01, clean-code-aerospace-core-02
- **risk:** medium (this is the startup command that establishes default modes deterministically; the `source` + var-expansion must be verified to run under the `exec-and-forget` `/bin/bash -c` context, and tilde expansion must still resolve. Test by reloading AeroSpace and confirming bar-hidden + performance-mode-ON defaults still land.)
- **dependsOn:** CC-01

---

### CC-09 — Promote SketchyBar bracket style to one shared array

- **id:** CC-09
- **file:** `configs/sketchybar/sketchybarrc` (+ `configs/sketchybar/items/spaces.sh`)
- **change:** Define the bracket style once near the top of `sketchybarrc` (after `--default`), e.g. `bracket_style=(background.color=$DARK_BG background.corner_radius=10 background.border_width=1 background.border_color=$PINK blur_radius=2 background.height=32 background.drawing=on background.padding_left=0 background.padding_right=0)`. Replace the four verbatim blocks (`calendar_bracket`, `audio_bracket`, `traffic_bracket`, `resources_bracket`, `connectivity_bracket` — lines 67-77, 112-122, 127-137, 142-152, 157-167) with `--set <group> "${bracket_style[@]}"`. In `spaces.sh`, the three `spaces_*_bracket` arrays (lines 75-83, 89-97, 103-111) are identical to each other but **omit** the two `background.padding_left/right=0` lines present in the right-side groups; reconcile by sourcing/duplicating the same `bracket_style` (the padding values default consistently, and the reviewer flagged the trio has "drifted" — converging them on one definition is the intent). Because `spaces.sh` is sourced from `sketchybarrc` in the same process, the `bracket_style` array defined in `sketchybarrc` is visible to it — define it before `source "$ITEM_DIR/spaces.sh"` (line 60). Verify the padding additions to the spaces brackets are visually acceptable (they were absent before); if the two padding lines change spacing, keep a `spaces_bracket_style` variant without them rather than forcing exact unification.
- **rationale:** Collapses eight near-identical bracket declarations to one, so a theme change is a single edit; converges the drifted spaces trio.
- **addresses:** clean-code-sketchybar-core-01
- **risk:** medium (the spaces brackets differ from the right-side ones by two padding lines; unifying may shift left-group spacing by a couple px — needs a visual check after reload, hence keep a `spaces_bracket_style` fallback if it regresses)
- **dependsOn:** none

---

### CC-10 — Export FONT / PLUGIN_DIR / ITEM_DIR (and key palette vars) so item/plugin files have an explicit dependency

- **id:** CC-10
- **file:** `configs/sketchybar/sketchybarrc`
- **change:** Add `export` to the three globals item files consume: `export ITEM_DIR=...`, `export PLUGIN_DIR=...`, `export FONT=...` (lines 6, 7, 10). `colors.sh`/`icons.sh` already `export` their vars. This is the minimal, lowest-risk half of the finding (the "move into an already-sourced config" alternative is more churn for no functional gain since everything is sourced in-process). Add a one-line comment that these are exported because `items/*.sh` and some `plugins/*.sh` (run as separate processes via `script=`) rely on `FONT`/`PLUGIN_DIR`.
- **rationale:** Item files reference `FONT`/`PLUGIN_DIR`/`ITEM_DIR` with no local definition; today it only works via in-process sourcing. Exporting makes the dependency explicit and robust if any consumer is ever spawned as a subprocess.
- **addresses:** clean-code-sketchybar-core-05
- **risk:** low (adding `export` to already-set vars cannot break in-process sourcing)
- **dependsOn:** none

---

### CC-11 — Factor the system-monitor item skeleton (`cpu`/`ram`/`network_up`/`network_down`)

- **id:** CC-11
- **file:** `configs/sketchybar/sketchybarrc` (define shared base) + `items/cpu.sh`, `items/ram.sh`, `items/network_up.sh`, `items/network_down.sh`
- **change:** Introduce a shared base array for the icon+numeric-label skeleton (the lines identical across cpu/ram/network: `icon.font`, `icon.color=$PINK`, `label.font`, `label.color=$PINK`, `background.drawing=off`, `padding_left/right=0`, `update_freq=5`). Two viable shapes — pick the lower-risk one at implement time: (a) define `monitor_item_base=(...)` in `sketchybarrc` before sourcing these items and have each item do `sketchybar --add item X right --set X "${monitor_item_base[@]}" icon=<glyph> label=<seed> icon.padding_left=<n> icon.padding_right=<n> script="$PLUGIN_DIR/<x>.sh"` (later `--set` args override base); or (b) a small helper function `add_monitor_item NAME GLYPH SEED SCRIPT ILPAD IRPAD`. Per-item differences to preserve exactly: glyph, seed label (`0%` vs `0 B/s`), `icon.padding_left/right` (cpu 6/2, ram 6/2, network_up 8/2), `label.padding_right` (cpu 6, ram 8, network_up 6), and `script` path (network_*.sh both → `network_speed.sh`). Do NOT fold in `battery`/`volume` in this pass — the finding lists them as "share a skeleton" but they have meaningfully more divergence (volume has click handling, battery has charging states); leaving them out keeps the change high-confidence.
- **rationale:** Removes 4-5 near-line-for-line copies so a restyle of the monitor pills is one edit instead of five.
- **addresses:** clean-code-sketchybar-core-03
- **risk:** medium (per-item padding/label-padding asymmetries must be carried through precisely or the bar spacing shifts; verify each pill renders identically after reload)
- **dependsOn:** CC-10 (relies on `FONT`/`PLUGIN_DIR` being available where the base array is defined; if the base is defined in `sketchybarrc` this is automatic)

---

### CC-12 — Restore single-source-of-truth colors in `plugins/aerospace.sh`

- **id:** CC-12
- **file:** `configs/sketchybar/plugins/aerospace.sh` (+ `configs/sketchybar/colors.sh`)
- **change:** In `colors.sh`, add named exports for the spaces-indicator palette currently hardcoded in `aerospace.sh`: e.g. `SPACE_FOCUS_BG=$BORDER_ACTIVE` (the `0xffb22222` focus bubble is byte-identical to `BORDER_ACTIVE`/`PINK`), plus `SPACE_MON2_BG=0xff8a3048`, `SPACE_MON3_BG=0xff75283d`, `SPACE_ACTIVE_ICON=0xff1a1a2e`, `SPACE_FOCUS_LABEL=0xfffff0f3`, `SPACE_INACTIVE_FG=0xffb35060`, `SPACE_DOT_COLOR=0xff6e4250`. In `aerospace.sh`, replace the corresponding hardcoded hex (lines 131, 135, 137, 152-153, 158-159, 171) with these vars. The file already `source`s `colors.sh` (line 10). Use `$BORDER_ACTIVE` (or the new `$SPACE_FOCUS_BG` alias) for the focus bubble so a palette change recolors the spaces indicator, restoring the documented "whole bar recolors from one line" intent.
- **rationale:** The hardcoded `0xffb22222` defeats the explicit single-source-of-truth design in `colors.sh`; a palette edit silently skips the workspace indicator today.
- **addresses:** clean-code-sketchybar-plugins-01
- **risk:** low (values are identical; only indirection added — verify the spaces indicator colors are unchanged after a reload)
- **dependsOn:** none

---

### CC-13 — Co-locate the two app-name alias maps (`shorten_app_name` + `icon_map`)

- **id:** CC-13
- **file:** `configs/sketchybar/plugins/aerospace.sh`, `configs/sketchybar/plugins/icon_map.sh`
- **change:** `shorten_app_name()` (aerospace.sh:31-51) and `__icon_map()` (icon_map.sh) encode the same app-display-name knowledge twice. Bash 3.2 rules out a shared `declare -A`. Lowest-risk consolidation: move `shorten_app_name()` INTO `icon_map.sh` (which already exists as the shared app-name helper home), and have `aerospace.sh` `source` `icon_map.sh` and call it, instead of defining its own copy. Keep both as separate `case` functions in one file (one returns the short label, one the glyph) so the two app lists sit adjacent and drift is visible in one place. Verify `aerospace.sh` doesn't already source `icon_map.sh` elsewhere (it currently does not use glyphs, so this adds a source). Do NOT attempt a single function returning both forms — that changes call sites and is riskier.
- **rationale:** Adding/renaming an app today requires editing two files in two plugins; co-locating the two maps in `icon_map.sh` makes the duplication visible and the edit local.
- **addresses:** clean-code-sketchybar-plugins-02
- **risk:** medium (adds a `source icon_map.sh` to a hot per-space plugin invoked once per workspace item on every workspace change; must confirm no name collisions and that sourcing cost is negligible — it is a `case` function, no side effects)
- **dependsOn:** none

---

### CC-14 — Name the network poll interval constant in `network_speed.sh`

- **id:** CC-14
- **file:** `configs/sketchybar/plugins/network_speed.sh`
- **change:** Add `UPDATE_FREQ=5  # MUST match update_freq in items/network_up.sh + items/network_down.sh` near the top, and replace the two `/ 5` divisors (lines 60-61) with `/ UPDATE_FREQ`. Do NOT plumb the interval in via env from the item files (out-of-scope churn on live items); the named constant + cross-reference comment is the safe fix.
- **rationale:** Removes the bare `5` magic number duplicated in two arithmetic sites and documents its coupling to the item `update_freq`.
- **addresses:** clean-code-sketchybar-plugins-06
- **risk:** low (arithmetic identical)
- **dependsOn:** none

---

### CC-15 — Normalize `colors.sh` / `icons.sh` source ordering across plugins

- **id:** CC-15
- **file:** `configs/sketchybar/plugins/*.sh` (the ~12 plugins with the two-line preamble)
- **change:** Pick one canonical order — `source colors.sh` then `source icons.sh` (matches `sketchybarrc` line 3-4 order) — and apply it uniformly to the plugins that currently invert it (`battery.sh`, `ethernet.sh`, `headset.sh`, `wifi.sh`, `vpn.sh` source icons-then-colors). Pure reordering of two independent `source` lines; no functional effect. Do NOT introduce a `plugins/_lib.sh` aggregator in this pass — it is the heavier option the reviewer offered "or at minimum normalize the ordering," and a new sourced file is more surface than the cosmetic drift warrants here.
- **rationale:** Removes the copy-paste-drift signal; trivial and risk-free.
- **addresses:** clean-code-sketchybar-plugins-07
- **risk:** low
- **dependsOn:** none

---

### CC-16 — Fix stale on-focus-changed comment in `autoraise/config`

- **id:** CC-16
- **file:** `configs/autoraise/config`
- **change:** Rewrite the trailing comment (lines 39-41) so it no longer claims a global `on-focus-changed = move-mouse window-lazy-center` callback. New wording: warping is handled by AeroSpace via `move-mouse window-lazy-center` **appended to the individual focus/workspace keybindings** (the global `on-focus-changed` and `on-focused-monitor-changed` callbacks are deliberately empty), so AutoRaise's own warp stays disabled and the two tools don't fight over the cursor. Keep the intent; fix only the mechanism description to match `aerospace.toml:64-65` + the per-binding warps.
- **rationale:** The current comment misdescribes live wiring and reads as authoritative; it would mislead anyone tuning AutoRaise.
- **addresses:** clean-code-borders-autoraise-01
- **risk:** low (comment only)
- **dependsOn:** none

---

### CC-17 — Reconcile bordersrc theme in `guide-window-manager.md`

- **id:** CC-17
- **file:** `configs/guide-window-manager.md`
- **change:** Update lines 177-178 of the `./configs/borders/bordersrc` description from the stale "Tokyo Night theme: active=0xffc0caf5, inactive=0xff414868" to the current dark-red values `active=0xffb22222, inactive=0xff4d1a1a` (and `width=4.0` matches; the guide says `width=4.0` already). No change to `bordersrc` itself (inline hex is correct for a standalone symlinked tool). `_index.md` contains no Tokyo Night / theme-color statement for borders (verified), so no `_index.md` edit is required by this finding.
- **rationale:** Repo convention requires the guide to stay in sync with the configs; the documented theme contradicts the live file.
- **addresses:** clean-code-borders-autoraise-02
- **risk:** low (doc only)
- **dependsOn:** none

---

## Open questions

1. **Dead SketchyBar plugins (`title.sh`, `zen.sh`, and `clock.sh`, plus `front_app*.sh`, `spotify.sh`, `github.sh`, `brew.sh`):** these reference items that no active item file creates. Should they be deleted outright (and dropped from `_index.md`'s "25 plugins" count + the guide), or kept as a parked toolbox? This plan leaves them untouched; the plugins-04/-05 findings against them are moot until that decision is made.
2. **CC-09 spaces-bracket unification:** the left-side `spaces_*` brackets historically omit the two `background.padding_left/right=0` lines the right-side groups carry. Is converging them on the identical `bracket_style` (adding those two lines to the spaces brackets) visually acceptable, or should the left group keep a distinct `spaces_bracket_style`? Needs a visual check after reload.
3. **CC-08 startup `source` in TOML:** confirm that `source ~/workspace/configs/aerospace/lib-paths.sh` inside the `exec-and-forget` `/bin/bash -c` string expands `~` and the state vars correctly in that context (AeroSpace runs after-startup commands via its own shell). If tilde-in-source is unreliable there, fall back to `source "$HOME/workspace/configs/aerospace/lib-paths.sh"` for the `source` call only while still normalizing the two **script-invocation** paths to tilde form.
4. **Ordering of the lib constants vs. `set -euo pipefail`:** `apply-display-profile.sh`, `performance-mode.sh`, `secondary-bar-toggle.sh` run under `set -u`; confirm `lib-paths.sh` defines every referenced var so sourcing under `-u` can't trip on an unset name.
