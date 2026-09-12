# Portable macOS preferences

[`setup_macos.sh`](../../scripts/installs/setup_macos.sh) restores the selected current-user settings from [`preferences.json`](../../configs/macos/preferences.json), using [`apply_macos.swift`](../../scripts/installs/apply_macos.swift). The capture was rechecked on macOS **26.5.2**, 12 September 2026; the saved Dock now uses ChatGPT Desktop in position 4, and the desired input-source list is ABC only. These are declarative settings applied to native preference keys, not symlinked native plists.

The normal installer already supplies Command Line Tools before this step. The helper uses their Swift compiler, Foundation/CFPreferences, AppKit, and Carbon Text Input Source Services; no new package is needed. Application installation, including ChatGPT Desktop, precedes this step so the captured app pins can resolve.

## Captured settings

| Area | Captured value |
|---|---|
| Finder | Path bar, status bar, and hidden files enabled; preferred list view `Nlsv`; new windows use `PfAF` (Recents). No existing per-folder view or window state is copied. |
| Dock | Auto-hide enabled; **tile size 52**; recent applications disabled; launch animation disabled; minimize into application icon enabled. Unset orientation/magnification/minimize-effect keys were not converted into invented settings. |
| Dock app order | iTerm → Visual Studio Code → Obsidian → ChatGPT Desktop → Calendar → Spotify. Apps are addressed by standard paths plus stable bundle IDs. |
| Dock folder | `~/Downloads`, using the destination user's home, captured `arrangement=2`, `displayas=0`, `showas=1`. These native folder presentation values retain the captured stack/grid settings. |
| Menu shortcuts | **No `NSUserKeyEquivalents` overrides were found** in the global domain or registered application preference domains. The source intentionally contains an empty mapping; applying it does not clear destination shortcuts. |
| Input sources | Enable and select ABC (`com.apple.keylayout.ABC`). Other enabled sources remain intact. |
| Sidebar | No automatic favorites export or import. The modern private sidebar store does not provide a supported stable write mechanism used by this setup; recreate favorites manually below. |

The saved input-source list contains ABC only. Vietnamese Simple Telex is no longer requested for restoration. The helper deliberately retains other destination sources, so deleting a source from this file does **not** disable an already-enabled source on another Mac. Neither input-method history nor dictionaries, predictions, character palette state, or transient input state is captured.

ChatGPT Desktop occupies managed Dock position 4 at `/Applications/ChatGPT.app`, with its verified internal bundle identifier `com.openai.codex`. That identifier refers here to the desktop application, not the `codex` terminal binary. Claude Desktop and Claude Code installation remain separate and unchanged.

This file is an explicit saved configuration: changes made in the macOS interface are **not automatically captured** into the workspace. Update the portable source when changing the intended saved setup; the apply helper restores the source to macOS, and is not a background synchronization service.

The old baseline behavior remains in the shell script: fast keyboard repeat (`KeyRepeat=2`, `InitialKeyRepeat=15`), press-and-hold accents disabled, PNG screenshots in `~/Pictures/Screenshots`, dark appearance, expanded save panels, and `.DS_Store` suppression on network/USB volumes. The old Dock size 36 is replaced by the current captured **52**. Touch ID setup and wallpaper remain separate installer steps.

## System shortcuts are separate from menu shortcuts

The source contains only the selected saved `AppleSymbolicHotKeys` entries below. Names/standard chords were checked against Apple's installed `/System/Library/ExtensionKit/Extensions/KeyboardSettings.appex/Contents/Resources/en_GB.lproj/DefaultShortcutsTable.xml` on the capture machine. Persisted entries are not proof that every value differs from Apple's defaults: several explicit enable/disable flags match defaults.

| IDs | Saved state and manual destination |
|---|---|
| 15, 17, 19, 21, 23, 25, 26 | Disabled: Accessibility shortcuts for turn zoom on/off, zoom in, zoom out, invert colours, image smoothing, increase contrast, decrease contrast. |
| 16, 18, 20, 22, 24 | Saved disabled companion flags for the corresponding accessibility shortcut family. These have no recorded custom key chord and no independent modern UI row is assumed. |
| 60 | Disabled: Input Sources → Select the previous input source; saved Control-Space. |
| 61 | Disabled: Input Sources → Select next source in Input menu; saved Control-Option-Space. |
| 64 | Enabled: Spotlight → Show Spotlight search; Command-Space. |
| 65 | Disabled: Spotlight → Show Finder search window; Option-Command-Space. |
| 79, 81 | Enabled: Mission Control → Move to previous/next space. The source contains **enabled-only flags**, preserving the destination's existing key binding; Apple's current defaults are Control-Left/Right Arrow. |
| 80, 82 | Enabled slow-animation companions of 79/81, also enabled-only. No invented chord is written. |
| 164 | **Manual only:** enabled modifier-only Dictation shortcut, Control. Its machine-format sentinel was deliberately replaced with a human-readable instruction and is never written. |

The helper merges captured fields into each selected entry. Unknown IDs and fields, including existing bindings on enabled-only entries, remain untouched. Shortcut IDs are private preference conventions, so automatic symbolic-shortcut writes run only on the captured **macOS major version 26**. Other macOS versions produce a visible manual notice and leave all symbolic shortcut entries intact. The ordinary targeted preferences and public input-source API remain available.

After signing in again, open **System Settings → Keyboard → Keyboard Shortcuts** and check the rows above. On other major versions, set those rows manually. For accessibility companion flags without a visible row, disable the parent accessibility shortcut; the exact old companion representation is not promised across OS versions. Apple documents the [Keyboard Shortcuts settings](https://support.apple.com/guide/mac-help/mchlp2262/mac).

For Dictation, open **System Settings → Keyboard → Dictation → Shortcut**, select **Press Control Key Twice** if offered, and check its behavior in a text field. The setup does not enable Dictation, download its resources, or grant microphone permission. If that modifier-only choice is unavailable on the target release, its exact restoration remains manual and unsupported by this helper; do not substitute an invented chord.

## Apply and existing-state handling

On the destination Mac, run the normal installer, or rerun this step alone:

```sh
bash ~/workspace/scripts/installs/setup_macos.sh
```

To inspect only what the captured helper would change, without writes or process restarts:

```sh
xcrun swift ~/workspace/scripts/installs/apply_macos.swift \
  ~/workspace/configs/macos/preferences.json --dry-run
```

The helper reads and writes individual current-user preference keys using CFPreferences. It merges nested menu/system shortcuts instead of replacing their domains. For Dock arrays it puts the managed pins first, reuses matching existing tiles, removes duplicate instances of those managed pins, and retains unrelated existing pins afterwards. This intentionally preserves additional pins on an existing Mac; a fresh Mac's remaining default pins can be removed manually if the six-app layout alone is wanted.

A missing application is resolved by its captured bundle ID if possible. Otherwise its pin is skipped with an explicit notice, with no package installation or broken pin. Missing Downloads likewise produces a notice. Install the missing app or create Downloads, then rerun the step. The helper never imports captured GUIDs, timestamps, bookmarks, aliases, recent apps, or window state into the repository.

Before each changed key is written, its prior value (or an explicit absent marker) is saved under `~/Library/Application Support/workspace/macos-backups/<unique-run>/`. Run directories are mode `0700`, snapshots `0600`; unchanged reruns create no backup. These **local** snapshots contain only changed keys, not whole domains, but an existing Dock-array snapshot can include that destination's bookmark metadata. They belong outside the public repository. Input-source enable/selection changes have separate before-state records. Keep these snapshots private; restoring a present preference uses only that snapshot's `value` for its named domain/key, and restoring an absent marker deletes only that key. Input before-state records must be restored through Input Sources settings rather than imported as a plist. No automatic rollback command is provided.

Input sources are enabled/selected through public TIS APIs, without rewriting `com.apple.HIToolbox` history or replacing its whole enabled-source list. Unavailable sources/APIs, unsuccessful enables, and unsuccessful selection produce visible manual instructions. They are not treated as a successful input restoration. The portable helper does not disable input sources on an existing Mac. To remove an unwanted source there, use **System Settings → Keyboard → Text Input → Edit**, select that source, and click **−**; keep ABC enabled.

The shell step retains its existing Finder/Dock restart at the end when **actually applied**. Keyboard shortcut caches can still require signing out and back in. The helper's dry run does not restart anything.

## Manual post-reset items

1. **Input source fallback:** Open **System Settings → Keyboard → Text Input → Edit**. Use **+** to add **English → ABC** if missing. Enable **Show Input menu in menu bar**, then choose **ABC** from that menu. Keep any other sources you need. These are Apple's [Input Sources settings](https://support.apple.com/guide/mac-help/mchl84525d76/mac). Do this when a helper notice appears; after an automatic run, verify ABC is present and selected there.
2. **Finder sidebar:** Choose **Finder → Settings → Sidebar** to enable the standard favorites you want. For an ordinary local folder, use **Go → Go to Folder** to open it, then drag its folder icon into **Favorites** and drag to the intended order. Remove an unwanted favorite with its context menu **Remove from Sidebar**. The current exact favorite set/order was not extracted from private alias/bookmark storage; choose it manually on the destination. Cloud/account items and unavailable volumes need their own account/mount setup and are excluded. Apple documents [customizing the Finder sidebar](https://support.apple.com/guide/mac-help/mchl83c9e8b8/mac).
3. **Shortcuts:** Verify the table above and restore the Dictation modifier shortcut manually. Sign out and in if the saved shortcut settings do not become active.

## Focused verification

Run the isolated fixture suite:

```sh
python3 ~/workspace/scripts/installs/tests/test_macos_preferences.py
```

It uses temporary plist domains and fake application paths to check dry-run immutability, typed/nested merge behavior, unknown key and binding preservation, Dock order and additional-pin retention, absent targets, simulated input-source selection, private backup modes, and zero-change repeated runs. The shell wrapper runs with a temporary `HOME` and mocked `defaults`, `xcrun`, and `killall`, checking retained baseline behavior without reaching live preferences or processes. Fixture mode uses simulated input state and **never calls TIS**.

The Swift helper compiles, and shell syntax parsing passed. The ChatGPT/ABC-only source has isolated fixture coverage. Native source enabling/selection, actual Dock restoration, shortcut cache activation, logout/login, and a full fresh-Mac bootstrap were **not** tested.

On the current Mac, **System Settings → Keyboard → Text Input → Edit shows only ABC**, ABC is enabled and selected, and the Vietnamese parent input method is disabled. The other Vietnamese modes are disabled. Apple's installed `TextInputSources.h` documents that an input mode is selectable only when its parent is enabled; `kTISPropertyInputSourceIsSelectCapable` is a static capability, not evidence of current availability. Vietnamese Simple Telex is therefore unavailable as an active input source.

macOS still remembers the child's enabled preference under that disabled parent. That dormant flag was not erased, and no direct HIToolbox rewrite or native input-method deletion was used. If the parent is deliberately enabled again later, the remembered mode may reappear. Other persisted input-source entries remain unchanged. The portable helper preserves other destination input sources; remove an unwanted destination source through the same settings sheet using **−**.

Verification does not run live Dock/Finder restoration or a full setup.
