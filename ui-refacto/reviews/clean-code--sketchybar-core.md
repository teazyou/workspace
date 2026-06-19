# Clean-code / refactor review — SketchyBar entry point + items

**Slice:** `configs/sketchybar/sketchybarrc`, `colors.sh`, `icons.sh`, and all `items/*.sh`.
**Lens:** Maintainability and structure only (no correctness/perf defects).

## Summary

The SketchyBar config is functional and follows a consistent "array + `--add`/`--set`" pattern, but it carries a large amount of copy-paste structure that makes coordinated visual changes error-prone. The biggest offenders are eight byte-for-byte-identical bracket-style blocks spread across `sketchybarrc` and `spaces.sh`, six near-identical "spacer" item definitions, and a fleet of system-monitor item files (cpu/ram/battery/network_*) that repeat the same font/padding/color skeleton. There is also hidden coupling (item files depend on `FONT`/`PLUGIN_DIR` defined in `sketchybarrc` but inherited only via `source`), magic font strings and poll intervals repeated everywhere, raw icon glyphs inlined in items that duplicate the named constants in `icons.sh`, and dead/commented code. None of the recommendations require violating Bash 3.2, the symlink model, the no-notifications rule, or manual-linting; all are achievable with plain shell helpers and shared constant vars.

---

## clean-code-sketchybar-core-01 — Eight identical bracket-style blocks duplicated across two files

**Severity:** high
**File:** `configs/sketchybar/sketchybarrc:67-169` and `configs/sketchybar/items/spaces.sh:75-114`

**Description:** The bar groups every cluster of items into a bracket with the same visual style. The style array is re-declared verbatim eight times: `calendar_bracket`, `audio_bracket`, `traffic_bracket`, `resources_bracket`, `connectivity_bracket` in `sketchybarrc`, plus `spaces_main_bracket`, `spaces_secondary_bracket`, `spaces_third_bracket` in `spaces.sh`. The five in `sketchybarrc` are byte-identical; the three in `spaces.sh` differ only in that they omit the `background.padding_left/right=0` lines. A single theme change (e.g. border color, corner radius) has to be applied in eight places, and the spaces.sh trio already drift from the sketchybarrc five.

**Evidence:** From `sketchybarrc` (repeated for audio, traffic, resources, connectivity):
```bash
calendar_bracket=(
  background.color=$DARK_BG
  background.corner_radius=10
  background.border_width=1
  background.border_color=$PINK
  blur_radius=2
  background.height=32
  background.drawing=on
  background.padding_left=0
  background.padding_right=0
)
```
From `spaces.sh` (`spaces_main_bracket`, `spaces_secondary_bracket`, `spaces_third_bracket` are identical to each other):
```bash
spaces_main_bracket=(
  background.color=$DARK_BG
  background.corner_radius=10
  background.border_width=1
  background.border_color=$PINK
  blur_radius=2
  background.height=32
  background.drawing=on
)
```

**Recommendation:** Define the bracket style once as a shared array (e.g. `GROUP_BRACKET=(...)` exported from `colors.sh`/a new `styles.sh`, or declared once in `sketchybarrc`), then `--set <bracket> "${GROUP_BRACKET[@]}"` for all groups. Bash 3.2 supports plain indexed arrays, so this is compatible. The spaces.sh trio can reuse the same array (its `background.padding_left/right=0` omission is the only delta and can be folded in).

---

## clean-code-sketchybar-core-02 — Six near-identical "spacer" items copy-pasted

**Severity:** medium
**File:** `configs/sketchybar/sketchybarrc:82,89,97,105` and `configs/sketchybar/items/spaces.sh:50-51,56-57`

**Description:** Every inter-group gap is an invisible item created with the same four-property incantation. It appears four times in `sketchybarrc` (`spacer0`-`spacer3`, `width=5`) and twice in `spaces.sh` (`spaces_spacer_main`, `spaces_spacer_secondary`, `width=3`). The drawing-off triple (`background.drawing=off icon.drawing=off label.drawing=off`) is identical in all six.

**Evidence:**
```bash
# sketchybarrc:82
sketchybar --add item spacer0 right --set spacer0 width=5 background.drawing=off icon.drawing=off label.drawing=off
# spaces.sh:50-51
sketchybar --add item spaces_spacer_main left \
           --set spaces_spacer_main width=3 background.drawing=off icon.drawing=off label.drawing=off
```

**Recommendation:** Add a tiny helper, e.g. `add_spacer() { sketchybar --add item "$1" "$2" --set "$1" width="$3" background.drawing=off icon.drawing=off label.drawing=off; }` defined once (in `sketchybarrc` or a sourced helper) and call `add_spacer spacer0 right 5`. Removes the repeated property triple and the magic `width` values become named call arguments.

---

## clean-code-sketchybar-core-03 — System-monitor item files repeat the same skeleton

**Severity:** medium
**File:** `configs/sketchybar/items/cpu.sh`, `ram.sh`, `network_up.sh`, `network_down.sh`, `battery.sh`, `volume.sh`

**Description:** The "icon + numeric label" items share an identical visual skeleton: `icon.font="$FONT:Normal:15.0"`, `icon.color=$PINK`, `label.font="$FONT:Bold:14.0"`, `label.color=$PINK`, `background.drawing=off`, `padding_left=0`, `padding_right=0`, `update_freq=5`, differing only in icon glyph, label seed text, the two icon padding values, and script path. cpu.sh, ram.sh, network_up.sh, network_down.sh are nearly line-for-line copies. Any global restyle of the monitor pills (font size, accent color, poll rate) must be edited in 5-6 files.

**Evidence:** `ram.sh:4-20` vs `cpu.sh:4-20` vs `network_up.sh:4-20` are the same array with only `icon=`, `label=`, and `script=` changed:
```bash
ram=(
  icon=󰘚
  icon.font="$FONT:Normal:15.0"
  icon.color=$PINK
  icon.padding_left=6
  icon.padding_right=2
  label.font="$FONT:Bold:14.0"
  label.color=$PINK
  label.padding_left=2
  label.padding_right=8
  label=0%
  background.drawing=off
  padding_left=0
  padding_right=0
  update_freq=5
  script="$PLUGIN_DIR/ram.sh"
)
```

**Recommendation:** Factor the shared skeleton into a base array (e.g. `MONITOR_ITEM_BASE=(...)`) and compose per-item: `sketchybar --add item ram right --set ram "${MONITOR_ITEM_BASE[@]}" icon=$RAM label=0% script="$PLUGIN_DIR/ram.sh"` (later `--set` args win). Keeps Bash 3.2 compatibility (indexed arrays only) and centralizes the font/color/poll defaults.

---

## clean-code-sketchybar-core-04 — Magic font strings and poll intervals not named constants

**Severity:** medium
**File:** all `items/*.sh` (e.g. `cpu.sh:5,11`, `ram.sh:5,11`, `volume.sh:5,11`, `battery.sh:6,11`, `calendar.sh:8,14`)

**Description:** The font specifiers `"$FONT:Normal:15.0"` and `"$FONT:Bold:14.0"` and the poll interval `update_freq=5` are hard-coded as string literals in roughly a dozen files. `colors.sh` already centralizes colors but there is no equivalent for fonts or intervals, so a font-weight or refresh-rate change requires a multi-file sweep with no single source of truth. `sketchybarrc` even defines its own different defaults (`icon.font="$FONT:Bold:19.0"`, `label.font="$FONT:Bold:12.0"`) that every item then overrides, so the `--default` block buys little.

**Evidence:** `"$FONT:Normal:15.0"` appears in cpu/ram/network_up/network_down/volume/vpn/wifi/ethernet/headset/battery/calendar; `update_freq=5` appears in cpu, ram, network_up, network_down, volume, vpn, wifi, ethernet, headset, battery.

**Recommendation:** Add named constants alongside the existing color palette (e.g. in `colors.sh` or a new `fonts.sh`): `export ICON_FONT_15="$FONT:Normal:15.0"`, `export LABEL_FONT_14="$FONT:Bold:14.0"`, `export MONITOR_POLL=5`, and reference those. Note `FONT` itself would then need to live in the sourced file (see finding 05).

---

## clean-code-sketchybar-core-05 — `FONT`/`PLUGIN_DIR`/`ITEM_DIR` are implicit globals from `sketchybarrc`

**Severity:** medium
**File:** `configs/sketchybar/sketchybarrc:6-10`, consumed by every `items/*.sh`

**Description:** `FONT`, `PLUGIN_DIR`, and `ITEM_DIR` are defined as plain (non-`export`ed) variables in `sketchybarrc` and every item file references `$FONT` and `$PLUGIN_DIR` (e.g. `cpu.sh:5`, `cpu.sh:19`). This only works because the items are pulled in with `source` from the same process. Unlike `colors.sh`/`icons.sh` — which `export` their values and are explicitly sourced — the item files have an undeclared dependency on `sketchybarrc`'s locals. An item file run standalone (or sourced before `FONT` is set) silently produces broken font/script paths, and a reader of `cpu.sh` cannot tell where `$FONT` comes from.

**Evidence:** `sketchybarrc:10` `FONT="JetBrainsMono Nerd Font"` (no `export`), `sketchybarrc:7` `PLUGIN_DIR="$HOME/.config/sketchybar/plugins"` (no `export`); `cpu.sh:5` uses `"$FONT:Normal:15.0"` and `cpu.sh:19` `script="$PLUGIN_DIR/cpu.sh"` with no local definition or sourcing of these vars.

**Recommendation:** Move `FONT`/`PLUGIN_DIR`/`ITEM_DIR` into one of the already-sourced config files (e.g. `export FONT=...` in a fonts/paths file sourced before items), or at minimum `export` them in `sketchybarrc` and add a comment in the item files noting the dependency. This makes the contract between `sketchybarrc` and the item files explicit.

---

## clean-code-sketchybar-core-06 — Raw icon glyphs inlined in items duplicate `icons.sh` constants

**Severity:** low
**File:** `configs/sketchybar/items/cpu.sh:5`, `ram.sh:5`, `calendar.sh:7,16`, `spotify.sh:17`

**Description:** `icons.sh` exists to centralize Nerd Font glyphs as named constants, and most items use them (`$RAM`, `$VOLUME_100`, `$WIFI_CONNECTED`, etc.). But several items inline the raw glyph instead: `cpu.sh` uses `icon=󰍛` while `icons.sh` already exports `ACTIVITY=󰍛`; `ram.sh` uses `icon=󰘚` while `RAM=󰘚` is exported; `calendar.sh` inlines a clock glyph and `spotify.sh` inlines `󰓇`, neither of which has a constant. This defeats the purpose of `icons.sh` and means a glyph change is not discoverable from the icon registry.

**Evidence:**
```bash
# cpu.sh:5
  icon=󰍛            # icons.sh:7 already has: export ACTIVITY=󰍛
# ram.sh:5
  icon=󰘚            # icons.sh:64 already has: export RAM=󰘚
# calendar.sh:7
  icon=󱑎            # no constant in icons.sh
```

**Recommendation:** Reference the existing constants (`cpu.sh` → `icon=$ACTIVITY` or add a `CPU` alias; `ram.sh` → `icon=$RAM`) and add named exports in `icons.sh` for the inlined clock and spotify glyphs (e.g. `CLOCK`, `SPOTIFY`). Keeps `icons.sh` the single source of truth it is meant to be.

---

## clean-code-sketchybar-core-07 — Dead / commented-out code in spaces.sh and disabled item files

**Severity:** low
**File:** `configs/sketchybar/items/spaces.sh:61-71`; `configs/sketchybar/sketchybarrc:59,63`; disabled files `apple.sh`, `settings.sh`, `front_app.sh`, `brew.sh`, `github.sh`, `spotify.sh`

**Description:** `spaces.sh` carries an 11-line commented-out `new_space` block. `sketchybarrc` has two commented-out `source` lines (`apple.sh`, `settings.sh`) plus a documented set of item files that are never sourced at all (`front_app.sh`, `brew.sh`, `github.sh`, `spotify.sh`). The guide documents these as "disabled," but inside the code they read as clutter and the commented block in particular is dead weight that obscures the active logic.

**Evidence:**
```bash
# spaces.sh:61-71
# Add new space button - CriticalElement style (DISABLED)
# sketchybar --add item new_space left                        \
# ... 9 more commented lines ...
# sketchybarrc:59
# source "$ITEM_DIR/apple.sh"
# sketchybarrc:63
# source "$ITEM_DIR/settings.sh"
```

**Recommendation:** Delete the commented `new_space` block in `spaces.sh` (git history preserves it). For the disabled item files, the symlink/source-of-truth model means they are intentionally retained; that is acceptable, but consider grouping the disabled-source comments in `sketchybarrc` into a single clearly-labeled "disabled items" block rather than scattering them, and drop the inline commented `source` lines in favor of that one note.

---

## clean-code-sketchybar-core-08 — Repeated `POPUP_CLICK_SCRIPT` toggle string across popup items

**Severity:** low
**File:** `configs/sketchybar/items/apple.sh:4`, `github.sh:3`, and the analogous `spotify.sh:4` popup toggle

**Description:** The popup-toggle click script `sketchybar --set \$NAME popup.drawing=toggle` is redefined per-file as a local `POPUP_CLICK_SCRIPT`, and `apple.sh` additionally hard-codes `POPUP_OFF="sketchybar --set apple.logo popup.drawing=off"`. These are the same idiom across the popup-bearing items with no shared definition.

**Evidence:**
```bash
# apple.sh:4
POPUP_CLICK_SCRIPT="sketchybar --set \$NAME popup.drawing=toggle"
# github.sh:3
POPUP_CLICK_SCRIPT="sketchybar --set \$NAME popup.drawing=toggle"
```

**Recommendation:** Define the toggle string once (e.g. `export POPUP_TOGGLE='sketchybar --set $NAME popup.drawing=toggle'` in a shared helper sourced by `sketchybarrc`) and reference it. Minor, and these files are mostly disabled, so low priority — but it removes the last of the cross-file copy-paste.
