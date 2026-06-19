# Clean-code / Refactor Review — SketchyBar plugins

**Slice:** `configs/sketchybar/plugins/*.sh` (25 files)
**Lens:** Maintainability and structure only (no correctness/perf defects).

## Summary

The plugins are mostly small, single-purpose scripts and read cleanly. The
maintainability issues that stand out are: (1) `aerospace.sh` hardcodes raw color
hex literals that already exist as named constants in the very `colors.sh` it
sources, defeating the "recolor the whole bar from one line" design stated in
`colors.sh`; (2) two independent app-name alias maps (`shorten_app_name()` in
`aerospace.sh` and `icon_map.sh`) duplicate the same Chrome/Code/Edge/... data
and will drift; (3) four near-identical `date`-formatter one-liners
(`calendar.sh`, `clock.sh`, `date.sh`, `time.sh`); (4) `zen.sh` repeats its full
item list verbatim in both `zen_on`/`zen_off`; (5) inconsistent JSON read-back in
`title.sh` (grep/cut vs. `jq` used everywhere else); (6) the network update_freq
`5` is a magic number coupled to a value defined in the item file. Findings below
are ranked; none require breaking Bash 3.2 or the symlink model.

---

### clean-code-sketchybar-plugins-01 — `aerospace.sh` hardcodes color hex that already exist as named constants

**Severity:** medium
**File:** `configs/sketchybar/plugins/aerospace.sh:127-159`

**Description:** `aerospace.sh` sources `colors.sh` (line 10) yet writes raw hex
literals for its bubble/label colors. The focus-bubble value `0xffb22222` is
*identical* to `BORDER_ACTIVE` (and therefore `PINK`) defined in `colors.sh`.
`colors.sh` explicitly documents the intent: "so the whole bar recolors from this
one line." Hardcoding the same hex here breaks that single-source-of-truth and
means a palette change silently skips the spaces indicator. The other tints
(`0xff8a3048`, `0xff75283d`, `0xff1a1a2e`, `0xfffff0f3`, `0xffb35060`,
`0xff6e4250`) are likewise un-named magic colors that belong in the shared
palette.

**Evidence:**
```sh
# line 131-132
BG_COLOR="0xffb22222"   # == BORDER_ACTIVE / PINK in colors.sh
...
BG_COLOR="0xff8a3048"
BG_COLOR="0xff75283d"
...
ICON_COLOR="0xff1a1a2e"
LABEL_COLOR="0xfffff0f3"
ICON_COLOR="0xffb35060"
```

**Recommendation:** Use `$BORDER_ACTIVE` (or `$PINK`) for the focus bubble, and
add named exports in `colors.sh` for the secondary/tertiary monitor tints and the
icon/label shades (e.g. `SPACE_MON2_BG`, `SPACE_MON3_BG`, `SPACE_ICON_DARK`,
`SPACE_FOCUS_LABEL`, `SPACE_INACTIVE`, `SPACE_DOT`), then reference them here. This
restores the documented one-line recolor.

---

### clean-code-sketchybar-plugins-02 — Two duplicate app-name alias maps (`shorten_app_name` vs `icon_map.sh`)

**Severity:** medium
**File:** `configs/sketchybar/plugins/aerospace.sh:31-51` and `configs/sketchybar/plugins/icon_map.sh:7-107`

**Description:** Both files maintain a hand-curated map keyed on the same macOS
app display names — "Google Chrome", "Visual Studio Code", "Microsoft Edge",
"Microsoft Word/Excel/PowerPoint/Outlook", "Brave Browser", "Docker Desktop",
"System Preferences/Settings", "Activity Monitor", etc. `shorten_app_name()`
returns a short text label; `icon_map.sh` returns a glyph token. They encode the
same knowledge ("what canonical apps exist and how to refer to them") in two
places, so adding/renaming an app requires editing both and they will drift.

**Evidence:**
```sh
# aerospace.sh
"Google Chrome") echo "Chrome" ;;
"Visual Studio Code") echo "Code" ;;
"Microsoft Edge") echo "Edge" ;;
"Brave Browser") echo "Brave" ;;
"Docker Desktop") echo "Docker" ;;
```
```sh
# icon_map.sh
"Google Chrome"|"Chrome") icon_result=":google_chrome:" ;;
"Code"|"Visual Studio Code") icon_result=":code:" ;;
"Microsoft Edge") icon_result=":microsoft_edge:" ;;
"Brave Browser") icon_result=":brave_browser:" ;;
"Docker Desktop"|"Docker") icon_result=":docker:" ;;
```

**Recommendation:** Centralize the app-name aliases in one shared helper (e.g. a
`plugins/app_names.sh` sourced by both), so the short-name and the icon lookup
draw from a single canonical list. Bash 3.2 rules out `declare -A`, but a single
`case` function (like `icon_map.sh` already is) can return both, or the two
helpers can live side by side in one file so edits stay co-located.

---

### clean-code-sketchybar-plugins-03 — Four near-identical `date`-formatter one-liners

**Severity:** low
**File:** `configs/sketchybar/plugins/calendar.sh:5`, `clock.sh:2`, `date.sh:2`, `time.sh:2`

**Description:** `calendar.sh`, `clock.sh`, `date.sh`, and `time.sh` are all the
same one-line pattern — `sketchybar --set $NAME label="$(date '+...')"` — differing
only in the format string (and calendar.sh additionally sets an icon). This is
boilerplate that could be one parameterized plugin driven by the item's
configuration, reducing four files to one.

**Evidence:**
```sh
# clock.sh
sketchybar --set $NAME label="$(date '+%a %d %b %H:%M')"
# date.sh
sketchybar --set $NAME label="$(date '+%a %d')"
# time.sh
sketchybar --set $NAME label="$(date '+%H:%M')"
# calendar.sh
sketchybar --set $NAME icon="$CALENDAR" label="$(date '+%a %d %b %I:%M %p')"
```

**Recommendation:** Collapse into a single `datetime.sh` that reads the format
from an env var (e.g. `$DATE_FORMAT`, set per item via `--set ... <fmt>` or an
exported var in the item definition). Respect existing conventions if the item
files cannot easily pass a format — at minimum drop the unused duplicates if some
of these four are not referenced by any active item.

---

### clean-code-sketchybar-plugins-04 — `zen.sh` repeats the full item list in both branches

**Severity:** low
**File:** `configs/sketchybar/plugins/zen.sh:3-19`

**Description:** `zen_on()` and `zen_off()` list the exact same six item
selectors (`apple.logo`, `/space\..*/`, `aerospace.mode`, `/front_app\..*/`,
`battery`, `cpu`), differing only by `drawing=off` vs `drawing=on`. Adding or
removing a hidden item means editing the list in two places, and the lists can
silently desync.

**Evidence:**
```sh
zen_on() {
  sketchybar --set apple.logo drawing=off \
             --set '/space\..*/' drawing=off \
             ... --set cpu drawing=off
}
zen_off() {
  sketchybar --set apple.logo drawing=on \
             ... --set cpu drawing=on
}
```

**Recommendation:** Define the selector list once (e.g. a space-separated
`ZEN_ITEMS` string) and loop, passing the desired `drawing` state, so the item set
is declared a single time.

---

### clean-code-sketchybar-plugins-05 — `title.sh` parses sketchybar JSON with grep/cut instead of `jq`

**Severity:** low
**File:** `configs/sketchybar/plugins/title.sh:27`

**Description:** To read back the current label, `title.sh` greps the raw query
output and slices it with `cut`. Every other plugin that inspects sketchybar/JSON
output uses `jq` (`volume_click.sh:15`, `zen.sh:26`, `github.sh:7`). The
ad-hoc `grep -o '"value":"..."' | head -1 | cut -d'"' -f4` is brittle (breaks on
escaped quotes in titles) and inconsistent with the established convention.

**Evidence:**
```sh
CURRENT_LABEL=$(sketchybar --query title_proxy 2>/dev/null | grep -o '"value":"[^"]*"' | head -1 | cut -d'"' -f4)
```
vs. the convention elsewhere:
```sh
# volume_click.sh:15
INITIAL_WIDTH=$(sketchybar --query volume | jq -r ".slider.width")
```

**Recommendation:** Use `jq -r '.label.value'` (or the correct path) for
consistency and robustness against special characters in window titles.

---

### clean-code-sketchybar-plugins-06 — Network `update_freq` magic number `5` duplicated and cross-file coupled

**Severity:** low
**File:** `configs/sketchybar/plugins/network_speed.sh:59-61`

**Description:** The divisor `5` (seconds between polls) is a magic number that
must match the `update_freq` configured in the network item definition file. It
appears in a comment and twice in arithmetic with no named constant, so a change
to the item's poll interval silently produces wrong speeds here.

**Evidence:**
```sh
# Calculate speed (bytes per second, update_freq is 5 seconds)
SPEED_IN=$(( (BYTES_IN - PREV_IN) / 5 ))
SPEED_OUT=$(( (BYTES_OUT - PREV_OUT) / 5 ))
```

**Recommendation:** Name it once (`UPDATE_FREQ=5` near the top) and derive both
divisions from it; ideally pass the interval in via env so the item file remains
the single source of truth for the poll cadence.

---

### clean-code-sketchybar-plugins-07 — Inconsistent `source` ordering of colors.sh / icons.sh across plugins

**Severity:** low
**File:** multiple — e.g. `battery.sh:3-4`, `ethernet.sh:3-4`, `headset.sh:3-4`, `wifi.sh:3-4`, `vpn.sh:3-4` vs `aerospace_mode.sh:3-4`, `github.sh:3-4`, `spotify.sh:3-4`, `volume.sh:3-4`

**Description:** The two-line `source colors.sh` / `source icons.sh` preamble is
repeated across ~12 plugins with no consistent order: some source `icons.sh`
first then `colors.sh`, others the reverse. It is harmless boilerplate today but
is exactly the kind of repeated header a small shared `_lib.sh` (sourcing both)
would centralize, and the ordering inconsistency signals copy-paste drift.

**Evidence:**
```sh
# battery.sh / ethernet.sh / headset.sh / wifi.sh / vpn.sh
source "$HOME/.config/sketchybar/icons.sh"
source "$HOME/.config/sketchybar/colors.sh"
```
```sh
# aerospace_mode.sh / github.sh / spotify.sh / volume.sh
source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icons.sh"
```

**Recommendation:** Add a single `plugins/_lib.sh` (or extend an existing shared
file) that sources both palettes, and have plugins `source` that one file. At
minimum, normalize the ordering so the preamble is identical everywhere.
