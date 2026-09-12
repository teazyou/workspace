# Fresh-Mac install & bootstrap flow

How a brand-new macOS machine goes from nothing to this fully-wired workspace, via `scripts/installs/**`.

**Read this when:** doing a fresh-Mac setup, adding/removing/reordering an install step, debugging why something didn't get installed or wired after bootstrap, or changing a symlink target. If you're touching anything under [`scripts/installs/`](../../scripts/installs/), the ordering constraints in this doc are load-bearing and live nowhere else.

---

## Overview: the two-stage handoff

Setup is split in two because of a chicken-and-egg problem: the real installer lives *inside* the repo, but the repo isn't on disk yet.

1. **[`bootstrap.sh`](../../scripts/installs/bootstrap.sh)** — the curl one-liner entry point. Gets the machine to the bare minimum needed to clone the repo (CLT → Rosetta → Homebrew → brew git → `git clone`), then `exec`s into the main installer. Run remotely:
   ```
   curl -fsSL https://raw.githubusercontent.com/teazyou/workspace/master/scripts/installs/bootstrap.sh | bash
   ```
2. **[`installation.sh`](../../scripts/installs/installation.sh)** — the orchestrator. Runs 13 numbered steps, each a self-contained `install_*` / `setup_*` sub-script, designed for repeat runs; see the checks and limits below.

**Why bootstrap re-execs itself from a tempfile.** When invoked as `curl … | bash`, the script's stdin *is* the pipe still carrying the rest of its own source. Any child process that reads stdin (parts of the brew installer do) consumes that source; bash then hits EOF and exits silently mid-install. To avoid this, bootstrap detects the piped case (`[[ ! -t 0 ]]` and `WORKSPACE_BOOTSTRAP_REEXEC` unset), downloads a fresh copy to `mktemp /tmp/workspace-bootstrap.XXXXXX.sh`, sets `WORKSPACE_BOOTSTRAP_REEXEC=1`, and re-execs it with stdin reattached to `/dev/tty`. The same `< /dev/tty` trick is applied at the final handoff (`exec bash "$WORKSPACE/scripts/installs/installation.sh" < /dev/tty`) so that interactive prompts work even under the pipe.

**State before vs. after.**
- *Before bootstrap:* a stock Mac, nothing assumed except an Administrator account.
- *After bootstrap, before installation.sh:* CLT, Rosetta (Apple Silicon only), Homebrew on PATH, brew's `git`, and `~/workspace` cloned over HTTPS.
- *After installation.sh:* everything below, minus the known gaps (see [Known limitations](#known-limitations--what-the-flow-does-not-wire)).

Bootstrap hard-fails early if the user isn't in the `admin` group (`dseditgroup -o checkmember -m "$(whoami)" admin`) — the Homebrew install can't chown its prefix otherwise. It pre-caches sudo (`sudo -v`) and runs a 60s background keepalive (`while kill -0 "$$"…; sudo -n true`) so a long brew download doesn't time out the 5-minute sudo window under `NONINTERACTIVE=1`. The `ensure_brew_on_path` helper sources `brew shellenv` from `/opt/homebrew/bin/brew` (Apple Silicon) or `/usr/local/bin/brew` (Intel) **on every run**, not just right after install — fixing the historical "had to run it 2-3 times" flakiness where brew existed but wasn't yet on the child shell's PATH.

---

## The 13-step orchestration

[`installation.sh`](../../scripts/installs/installation.sh) auto-numbers its steps: `TOTAL_STEPS=$(grep -c '^next_step ' "${BASH_SOURCE[0]}")`, and a `next_step()` wrapper prints `"N/TOTAL — title"`. Adding or removing a step means editing only its own line — no other numbers need updating. All sub-scripts are invoked via `bash "$INSTALLS/<script>"` (a fresh subshell so a `set -e` failure bubbles up without poisoning the orchestrator's environment). `installation.sh` first exports the path vars every sub-script relies on: `WORKSPACE`, `SCRIPTS`, `FUNCTIONS`, `INSTALLS`, `APP_CONFIGS`.

| # | Step title | Sub-script |
|---|-----------|-----------|
| 1 | Homebrew taps + formulae + casks | [`install_brew.sh`](../../scripts/installs/install_brew.sh) |
| 2 | Oh-My-Zsh | [`install_oh_my_zsh.sh`](../../scripts/installs/install_oh_my_zsh.sh) |
| 3 | Symlinks (zshrc, aerospace, borders, sketchybar, vscode) | [`setup_symlinks.sh`](../../scripts/installs/setup_symlinks.sh) |
| 4 | iTerm2 preferences (custom-folder mode) | [`install_iterm2.sh`](../../scripts/installs/install_iterm2.sh) |
| 5 | Claude Desktop + Claude Code (native install) | [`install_claude.sh`](../../scripts/installs/install_claude.sh) |
| 6 | VSCode extensions | [`install_vscode_ext.sh`](../../scripts/installs/install_vscode_ext.sh) |
| 7 | Touch ID for sudo | [`install_touch_id_sudo.sh`](../../scripts/installs/install_touch_id_sudo.sh) |
| 8 | macOS defaults | [`setup_macos.sh`](../../scripts/installs/setup_macos.sh) |
| 9 | Wallpaper (solid black) | [`setup_wallpaper.sh`](../../scripts/installs/setup_wallpaper.sh) |
| 10 | Window manager services (aerospace → sketchybar, borders) | [`install_window_manager.sh`](../../scripts/installs/install_window_manager.sh) |
| 11 | Node LTS via NVM | [`install_node.sh`](../../scripts/installs/install_node.sh) |
| 12 | Xcode via mas | [`install_xcode_mas.sh`](../../scripts/installs/install_xcode_mas.sh) |
| 13 | Create ~/dev | [`setup_dev.sh`](../../scripts/installs/setup_dev.sh) |

All sub-scripts source [`helper_prompt.sh`](../../scripts/installs/helper_prompt.sh) for the `log_ok` / `log_err` / `log_wait` / `log_info` / `log_step` output helpers and the `prompt_continue` / `prompt_command` manual-pause helpers. `helper_prompt.sh` defaults the path vars (`: "${INSTALLS:=…}"`) once sourced; older standalone sub-scripts need `INSTALLS` set before that source line (see rerun instructions below). It normalises the `\033[…m` color strings from `zsh/configs/colors.zsh` into real escapes via `printf %b` (zsh's `echo` interprets them, bash's doesn't).

---

## Ordering / dependency graph (the load-bearing constraints)

The step order is **not** arbitrary. These two constraints are the reason it is what it is, and none of them is documented anywhere else in prose:

1. **`install_brew` runs first** because it provides Python (→ Claude), `nvm` (→ step 11), `mas` (→ step 12), the window-manager formulae/cask (→ step 10), and the applications used by the Dock capture (→ step 8).
2. **`install_touch_id_sudo` (step 7) runs before `install_xcode_mas` (step 12).** The Xcode step needs `sudo` for `xcodebuild -license accept` and `-runFirstLaunch`; with Touch ID already wired, those prompts can use a fingerprint. A password remains the fallback.

`oh_my_zsh` (2) runs **before** `setup_symlinks` (3): the OMZ installer uses `KEEP_ZSHRC=yes RUNZSH=no CHSH=no`, leaving `~/.zshrc` for the workspace link. macOS setup (8) uses Swift from bootstrap's CLT and applies captured Dock entries after Homebrew has supplied the selected apps, including ChatGPT Desktop at managed Dock position 4. Native VPN dependencies and activation remain separate manual work.

---

## Per-step cheat-sheet (idempotency check + gotchas)

Each value below is read from the sub-script's actual source. The "idempotency check" is what makes a re-run skip finished work.

| Step | Idempotency check (skip condition) | Notes |
|---|---|---|
| 1 install_brew | per-formula/cask short-circuit inside `brewInstall`/`caskInstall` ([`functions/brew.sh`](../../functions/brew.sh)) | full list below. `brew upgrade`/`cleanup`/`services cleanup` at the end are wrapped with `|| log_err` so one broken cask can't abort the run. |
| 2 oh_my_zsh | `[[ -d "$HOME/.oh-my-zsh" ]]` | installs with `KEEP_ZSHRC=yes RUNZSH=no CHSH=no`. |
| 3 setup_symlinks | per-link: already correct `-L` link → no-op | real files moved aside to `<name>.bak.$(date +%s)`; see [symlink targets](#symlink-targets-created). |
| 4 install_iterm2 | `PrefsCustomFolder == $CONFIGS/iterm2 && LoadPrefsFromCustomFolder == 1` (via `defaults read`) | **interactive:** if iTerm2 is running it pauses (`prompt_command`) to have you quit it — otherwise iTerm2 overwrites the repo plist on quit. |
| 5 install_claude | Desktop: `[[ -d /Applications/Claude.app ]]`; Code: `[[ -x "$HOME/.local/bin/claude" ]]` | native installs (not brew cask). Desktop pulled from `downloads.claude.ai/releases/darwin/universal/RELEASES.json` (first entry, parsed with `python3`, extracted with `ditto`, quarantine stripped via `xattr -dr`). Code via `curl -fsSL https://claude.ai/install.sh | bash`. The binary-path check (not `command -v`) matters because this subshell doesn't source `~/.zshrc`, so `~/.local/bin` isn't on PATH. |
| 6 install_vscode_ext | `code --install-extension … --force` is itself a no-op when present | resolves the `code` CLI from PATH, else the in-bundle absolute path. **interactive fallback:** if `code` is missing it prompts you to open VSCode once. Installs `bracketpaircolordlw.bracket-pair-color-dlw`, `chunsen.bracket-select`. |
| 7 install_touch_id_sudo | uncommented `auth sufficient pam_tid.so` already present in `/etc/pam.d/sudo_local` | copies Apple's `sudo_local.template` (needs Sonoma+), `sed`-uncomments the `pam_tid.so` line, and **appends** it directly if the template format isn't recognised. **requires sudo once.** |
| 8 setup_macos | captured helper compares managed values; unchanged reruns skip writes/backups; baseline defaults reapply | [Portable source and manual gaps](macos-preferences.md): Finder, Dock size **52**/ordered apps/Downloads, 20 selected symbolic shortcut entries (automatic only on macOS 26), ABC as the sole desired input source, enabled and selected; existing destination sources remain intact. ChatGPT Desktop (`/Applications/ChatGPT.app`) occupies managed Dock position 4. Swift merges managed keys and uses public input-source APIs; scoped private backups. Existing keyboard, screenshots, dark mode, save-panel and `.DS_Store` setup stays; Finder/Dock restart on a real setup run. |
| 9 setup_wallpaper | none — re-applies each run | uses `/System/Library/Desktop Pictures/Solid Colors/Black.png`, falls back to a generated 1×1 black PNG. Sets via `osascript … every desktop`, then deletes `~/Library/Application Support/Dock/desktoppicture.db` to bust the Sonoma+ cache. |
| 10 install_window_manager | `pgrep -xq AeroSpace` | launches `AeroSpace.app` once (its `after-startup-command` brings up sketchybar + borders, then generates the per-monitor gaps via `apply-display-profile.sh --force` — the script only *sanity-checks* sketchybar/borders with `pgrep`, deliberately **not** `brew services start`, to avoid racing AeroSpace). No LaunchAgent involved — the WM stack has none. |
| 11 install_node | `nvm install --lts` is a no-op when LTS present | sources `nvm.sh` from `$(brew --prefix)/opt/nvm/nvm.sh`; `nvm alias default 'lts/*'`. |
| 12 install_xcode_mas | `[[ -d /Applications/Xcode.app ]]` (install step only) | App Store ID `497799835` via `mas install`. **interactive:** must be signed into the App Store first (`mas account` check; Apple removed `mas signin`). Always runs `sudo xcodebuild -license accept` + `-runFirstLaunch` even on re-runs. |
| 13 setup_dev | `[[ -d "$HOME/dev" ]]` | Creates `~/dev` for the `dev` zsh function. Existing projects are preserved; a conflicting non-directory stops the stage. |

### Full `install_brew.sh` formula + cask lists (read from source)

This is the **complete** list — do not trust partial audits.

**Taps:** `felixkratz/formulae` (provides `sketchybar` + `borders`).

**Formulae:** `python`, `nvm`, `sketchybar`, `borders`, `ripgrep`, `mas`, `gh`. **Bootstrap separately installs `git`.** These are the complete explicitly requested formula targets; Homebrew resolves their dependencies.

**Casks:** `iterm2`, `visual-studio-code`, `google-chrome`, `chatgpt`, `codex`, `spotify`, `bitwarden`, `nikitabobko/tap/aerospace`, `font-hack-nerd-font`, `font-sketchybar-app-font`, `discord`, `obsidian`.

**OpenAI package mapping:** [`chatgpt`](https://formulae.brew.sh/cask/chatgpt) supplies `/Applications/ChatGPT.app` (its retained internal quit/bundle identifier is `com.openai.codex`); [`codex`](https://formulae.brew.sh/cask/codex) supplies `bin/codex` to Homebrew's binary directory for the terminal command. These are one desktop application and one CLI. The [deprecated separate desktop cask](https://formulae.brew.sh/cask/codex-app) is excluded. This mapping was checked against Homebrew metadata on 2026-09-12.

> Note: `aerospace` lives in its own tap (`nikitabobko/tap/aerospace`); the two `font-*` casks are required by sketchybar (nerd-font glyphs + the app-icon font used by `plugins/icon_map.sh`).

---

## Symlink targets created

[`setup_symlinks.sh`](../../scripts/installs/setup_symlinks.sh) (step 3) creates exactly **5** links. Its `make_link` helper: already-correct link → no-op; wrong link → `rm`; real file/folder → moved to `<name>.bak.$(date +%s)` (never deleted).

| System path (link) | → repo source |
|---|---|
| `~/.zshrc` | `zsh/zshrc.zsh` |
| `~/.aerospace.toml` | `configs/aerospace/aerospace.toml` |
| `~/.config/borders` | `configs/borders` (whole dir) |
| `~/.config/sketchybar` | `configs/sketchybar` (whole dir) |
| `~/Library/Application Support/Code/User/settings.json` | `configs/vscode/settings.json` |

> **`setup_symlinks.sh` is *a* map, not *the* map.** Its 5 links are everything this flow wires. Other symlinks documented in `_index.md` (e.g. the nordvpn LaunchAgent plist) are wired out-of-band — see [Known limitations](#known-limitations--what-the-flow-does-not-wire).

---

## Known limitations — what the flow does NOT wire

The WM stack (AeroSpace + SketchyBar + JankyBorders) is fully wired by the flow: step 3 symlinks all three configs and step 10 launches the stack — no LaunchAgent involved anywhere (`AeroSpace` starts at login via `start-at-login`; its after-startup-command spawns sketchybar + borders and runs `apply-display-profile.sh`). What the flow deliberately leaves out:

### 1. Native NordVPN IKEv2 (deliberately not wired)

The VPN stack (`scripts/vpn/`, `configs/nordvpn/`) is **intentionally absent** from `installation.sh`/`setup_symlinks.sh`. Follow the standalone [fresh-Mac VPN procedure](../vpn/guide-nordvpn-native.md#fresh-mac-setup-manual-outside-the-main-installer): check its `/opt/homebrew` and `/Users/teazyou/workspace` layout assumptions, tap/trust/install `vpnutil`, verify Python and `jq` under the agent's minimal PATH (use the documented manual fallback only if needed), obtain email-gated Nord service credentials and the officially verified Root CA, generate and manually approve the profile, then create the exact LaunchAgent symlink and bootstrap it. The current Mac's system `jq` passes; this is a target preflight, not an unconditional missing dependency. Credentials, profiles, pins, and runtime state remain outside the repository.

### 2. macOS manual restoration

[macOS's focused guide](macos-preferences.md) records the captured keys and exact manual steps. No menu-shortcut overrides were present. Dictation's double-Control shortcut (ID 164) and Finder sidebar favorites remain manual. The six portable Dock applications (with ChatGPT Desktop at managed position 4) and Downloads are managed, and ABC is enabled/selected, while unrelated existing pins and input sources are preserved; missing apps or unavailable input sources produce notices. Symbolic-shortcut writes are gated to macOS 26; on other major versions follow the manual shortcut table. Review shortcuts/input sources after logging out/in because macOS caches some preferences. Do not treat raw preference-file equality as proof every target macOS version applies the same UI behavior.

### 3. Existing installer failure limits

The Brew helpers deliberately log install/tap failures and return success so later targets still run; upgrade/cleanup also tolerate errors. Window-manager process checks can report missing processes without failing the stage. Consequently the final “complete” line does not verify every package or process. Review failed log lines and confirm the selected casks/apps, both VS Code extensions, and window-manager processes on the target. Native Claude installs, App Store Xcode, and Node LTS are separate steps, not extra Brew casks/formulae. No full clean-Mac bootstrap was run during the reset-preparation implementation.

---

## Interactive pause points (why an unattended run is impossible)

Several steps stop and wait for a human; you cannot fully automate this end-to-end:

- **iTerm2 must be quit** before `defaults write` (step 4) — else it clobbers the repo plist on quit.
- **VS Code first-open** if the `code` CLI isn't found yet (step 6).
- **App Store sign-in** before `mas install` (step 12) — Apple removed `mas signin`.
- **sudo / Touch ID prompts** for `pam_tid.so` (step 7) and the Xcode license accept (step 12). Homebrew's one sudo prompt is handled earlier, in bootstrap.

---

## How to change things safely

- **Add/remove/reorder a step:** edit only the relevant `next_step "…"` + `bash "$INSTALLS/…"` pair in [`installation.sh`](../../scripts/installs/installation.sh). The `N/TOTAL` numbering recomputes itself from the `grep -c '^next_step '` count — don't hand-number anything. But **re-check the ordering constraints above** before moving a step; the dependency graph is the real contract.
- **Add a brew formula/cask:** add a `brewInstall`/`caskInstall` line in [`install_brew.sh`](../../scripts/installs/install_brew.sh) (order within the file is irrelevant — each line is independent) **and** update the formula/cask list in this doc and in [`_index.md`](../../_index.md).
- **Add a symlink:** add a `make_link` call in [`setup_symlinks.sh`](../../scripts/installs/setup_symlinks.sh), then update the symlink table here and the map in [`_index.md`](../../_index.md) (keep all three in sync — this is exactly the kind of drift that produced the "canonical map" overclaim).
- **Re-run a finished step:** use the relevant standalone command in its guide. Several older scripts source `"$INSTALLS/helper_prompt.sh"` before the helper can initialize paths, so supply `INSTALLS="$HOME/workspace/scripts/installs"` when invoking those directly, for example `INSTALLS="$HOME/workspace/scripts/installs" bash "$HOME/workspace/scripts/installs/install_vscode_ext.sh"`. A rerun can launch the window manager, reapply baseline preferences, or upgrade packages; read the cheat-sheet first. Do not delete application data to force a rerun.
- **Re-run the whole orchestrator:** `bash ~/workspace/scripts/installs/installation.sh`. It resumes from wherever a partial install left off.
