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
2. **[`installation.sh`](../../scripts/installs/installation.sh)** — the orchestrator. Runs 17 numbered steps, each a self-contained `install_*` / `setup_*` sub-script, all idempotent.

**Why bootstrap re-execs itself from a tempfile.** When invoked as `curl … | bash`, the script's stdin *is* the pipe still carrying the rest of its own source. Any child process that reads stdin (parts of the brew installer do) consumes that source; bash then hits EOF and exits silently mid-install. To avoid this, bootstrap detects the piped case (`[[ ! -t 0 ]]` and `WORKSPACE_BOOTSTRAP_REEXEC` unset), downloads a fresh copy to `mktemp /tmp/workspace-bootstrap.XXXXXX.sh`, sets `WORKSPACE_BOOTSTRAP_REEXEC=1`, and re-execs it with stdin reattached to `/dev/tty`. The same `< /dev/tty` trick is applied at the final handoff (`exec bash "$WORKSPACE/scripts/installs/installation.sh" < /dev/tty`) so that interactive prompts work even under the pipe.

**State before vs. after.**
- *Before bootstrap:* a stock Mac, nothing assumed except an Administrator account.
- *After bootstrap, before installation.sh:* CLT, Rosetta (Apple Silicon only), Homebrew on PATH, brew's `git`, and `~/workspace` cloned over HTTPS — **non-recursively** (the private `configs/dot-claude` submodule is deliberately *not* fetched here; it can't be until `gh` is authed much later, see step 15).
- *After installation.sh:* everything below, minus the known gaps (see [Known limitations](#known-limitations--what-the-flow-does-not-wire)).

Bootstrap hard-fails early if the user isn't in the `admin` group (`dseditgroup -o checkmember -m "$(whoami)" admin`) — the Homebrew install can't chown its prefix otherwise. It pre-caches sudo (`sudo -v`) and runs a 60s background keepalive (`while kill -0 "$$"…; sudo -n true`) so a long brew download doesn't time out the 5-minute sudo window under `NONINTERACTIVE=1`. The `ensure_brew_on_path` helper sources `brew shellenv` from `/opt/homebrew/bin/brew` (Apple Silicon) or `/usr/local/bin/brew` (Intel) **on every run**, not just right after install — fixing the historical "had to run it 2-3 times" flakiness where brew existed but wasn't yet on the child shell's PATH.

---

## The 17-step orchestration

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
| 10 | Window manager services (sketchybar, borders, aerospace LaunchAgent) | [`install_window_manager.sh`](../../scripts/installs/install_window_manager.sh) |
| 11 | Node LTS via NVM | [`install_node.sh`](../../scripts/installs/install_node.sh) |
| 12 | MySQL + PostgreSQL initial setup | [`install_database.sh`](../../scripts/installs/install_database.sh) |
| 13 | Xcode via mas | [`install_xcode_mas.sh`](../../scripts/installs/install_xcode_mas.sh) |
| 14 | Clone secondbrain + create ~/dev | [`clone_repos.sh`](../../scripts/installs/clone_repos.sh) |
| 15 | dot-claude submodule + ~/.claude symlink | [`setup_dot_claude.sh`](../../scripts/installs/setup_dot_claude.sh) |
| 16 | Hourly checkpoint LaunchAgent | [`install_checkpoint_launchd.sh`](../../scripts/installs/install_checkpoint_launchd.sh) |
| 17 | Docling CLI (uv tool + ML models) | [`install_docling.sh`](../../scripts/installs/install_docling.sh) |

All sub-scripts source [`helper_prompt.sh`](../../scripts/installs/helper_prompt.sh) for the `log_ok` / `log_err` / `log_wait` / `log_info` / `log_step` output helpers and the `prompt_continue` / `prompt_command` manual-pause helpers. `helper_prompt.sh` defaults the path vars (`: "${INSTALLS:=…}"`) so each sub-script can also be run standalone, and it normalises the `\033[…m` color strings from `zsh/configs/colors.zsh` into real escapes via `printf %b` (zsh's `echo` interprets them, bash's doesn't).

---

## Ordering / dependency graph (the load-bearing constraints)

The step order is **not** arbitrary. These four constraints are the reason it is what it is, and none of them is documented anywhere else in prose:

1. **`install_brew` runs first** because it provides the tools every later step consumes: `nvm` (→ step 11), `mas` (→ step 13), `gh` (→ steps 14/15), `mysql` + `postgresql@N` (→ step 12), plus `sketchybar`/`borders`/`aerospace` casks (→ step 10). A later step that can't find its tool fails loudly with "did install_brew.sh run?" (e.g. `install_node.sh`, `install_xcode_mas.sh`, `clone_repos.sh`, `install_database.sh`).
2. **`setup_symlinks` (step 3) MUST precede `install_window_manager` (step 10).** `install_window_manager.sh` loads the display-profile LaunchAgent with `launchctl bootstrap "gui/$UID_" "$PLIST"` where `$PLIST=~/Library/LaunchAgents/com.aerospace.display-profile.plist` — and that path is a **symlink created by `setup_symlinks.sh`**. The window-manager script **hard-exits** (`exit 1`) if the symlink is missing: `"LaunchAgent symlink missing: $PLIST (setup_symlinks.sh should have created it)"`.
3. **`clone_repos`'s `gh auth login` (step 14) is the auth GATE for the private dot-claude submodule (step 15).** The `configs/dot-claude` submodule is a *private* repo, uncloneable until `gh` holds a token. `setup_dot_claude.sh` checks `gh auth status` and **hard-exits** if not authenticated (`"gh CLI is not authenticated. Run clone_repos.sh first…"`). It then runs `gh auth setup-git` to wire git's HTTPS to the gh token before `git submodule update --init configs/dot-claude`. This is also why bootstrap clones the repo non-recursively — the submodule simply can't come down that early.
4. **`install_touch_id_sudo` (step 7) runs before `install_xcode_mas` (step 13).** The Xcode step needs `sudo` for `xcodebuild -license accept` and `-runFirstLaunch`; with Touch-ID-for-sudo already wired, those prompts are a fingerprint instead of a typed password. (Functional even without it — sudo just falls back to a password — but the ordering is intentional.)

Note also: `setup_dot_claude` (15) runs **after** `clone_repos` (14), and `oh_my_zsh` (2) runs **before** `setup_symlinks` (3) on purpose — the OMZ installer is told `KEEP_ZSHRC=yes RUNZSH=no CHSH=no` so it never writes its own `~/.zshrc`, leaving the slot clean for step 3 to symlink our real one into place. And `install_docling` (17) is deliberately **last and self-contained**: uv is *not* in `install_brew.sh`'s formula list — the docling installer idempotently installs uv itself (`brew install uv`), so its only ordering requirement is Homebrew on PATH (true from bootstrap onward); sitting last also puts its ~1.2 GB model prefetch after every interactive pause point, so the tail of the run is unattended.

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
| 6 install_vscode_ext | `code --install-extension … --force` is itself a no-op when present | resolves the `code` CLI from PATH, else the in-bundle absolute path. **interactive fallback:** if `code` is missing it prompts you to open VSCode once. Installs `bracketpaircolordlw.bracket-pair-color-dlw`, `chunsen.bracket-select`, `eamodio.gitlens`. |
| 7 install_touch_id_sudo | uncommented `auth sufficient pam_tid.so` already present in `/etc/pam.d/sudo_local` | copies Apple's `sudo_local.template` (needs Sonoma+), `sed`-uncomments the `pam_tid.so` line, and **appends** it directly if the template format isn't recognised. **requires sudo once.** |
| 8 setup_macos | none — `defaults write` is naturally idempotent | Finder (path/status bar, hidden files), keyboard (`KeyRepeat=2`, `InitialKeyRepeat=15`, press-and-hold off), screenshots (`~/Pictures/Screenshots`, png), Dock (autohide, `tilesize=36`), dark mode, expanded save panels, `.DS_Store` off on network/USB. `killall Finder Dock` to apply. |
| 9 setup_wallpaper | none — re-applies each run | uses `/System/Library/Desktop Pictures/Solid Colors/Black.png`, falls back to a generated 1×1 black PNG. Sets via `osascript … every desktop`, then deletes `~/Library/Application Support/Dock/desktoppicture.db` to bust the Sonoma+ cache. |
| 10 install_window_manager | `pgrep -xq AeroSpace`; LaunchAgent: `launchctl print "gui/$UID_/com.aerospace.display-profile"` | launches `AeroSpace.app` once (its `after-startup-command` brings up sketchybar + borders — the script only *sanity-checks* those with `pgrep`, deliberately **not** `brew services start`, to avoid racing AeroSpace). **Hard-exits if the display-profile symlink is missing** (see constraint 2). |
| 11 install_node | `nvm install --lts` is a no-op when LTS present | sources `nvm.sh` from `$(brew --prefix)/opt/nvm/nvm.sh`; `nvm alias default 'lts/*'`. |
| 12 install_database | MySQL: `brew services list` shows `mysql started`; secure step: marker file **`~/.workspace_mysql_secured`**; Postgres: service `started` + `createdb` ignores "exists" | uses `brew services run` (**not** `start`) so neither DB registers a login auto-start. **interactive:** `mysql_secure_installation` (you set the root password — no creds in this public repo). To re-run the secure step: `rm ~/.workspace_mysql_secured`. Creates a default DB named after `$(whoami)` so bare `psql` works. |
| 13 install_xcode_mas | `[[ -d /Applications/Xcode.app ]]` (install step only) | App Store ID `497799835` via `mas install`. **interactive:** must be signed into the App Store first (`mas account` check; Apple removed `mas signin`). Always runs `sudo xcodebuild -license accept` + `-runFirstLaunch` even on re-runs. |
| 14 clone_repos | `~/dev`: `[[ -d ]]`; gh: `gh auth status`; secondbrain: `[[ -d ~/secondbrain/.git ]]` | **interactive:** `gh auth login` (browser/device-code flow) — the auth gate for step 15. `mkdir -p ~/dev` (empty; the `dev` zsh function cd's here). `gh repo clone teazyou/secondbrain`. |
| 15 setup_dot_claude | submodule: populated (`$SRC/settings.json` or non-empty + `.git`); symlink: `~/.claude` already `-L` → `$SRC` | `gh auth setup-git` → `git -C "$WORKSPACE" submodule update --init configs/dot-claude` → symlink `~/.claude → configs/dot-claude`. A pre-existing real `~/.claude` dir is **moved** to `~/.claude.bak.$(date +%s)`, never deleted (OAuth token lives in Keychain, so the move doesn't log you out). Verifies `~/.claude/settings.json` resolves. **Treats the submodule as a black box** — only this wiring matters. |
| 16 install_checkpoint_launchd | already-loaded label → `bootout` then `bootstrap` (always reload) | writes `~/Library/LaunchAgents/com.teazyou.checkpoint.plist` (`StartCalendarInterval` minute 0, `RunAtLoad=false`). First migrates away any old `checkpoint_cronjob.sh` crontab entry. LaunchAgent (not cron) because cron can't reach the login-keychain GitHub credential for `git push`. |
| 17 install_docling | uv: `command -v uv` or `~/.local/bin/uv` present; docling: `[[ -x ~/.local/bin/docling ]]`; models: `~/.cache/docling/models` exists non-empty | isolated uv tool env with **uv-managed Python 3.12** (system python3 is 3.9, docling needs ≥3.10; uv auto-downloads the interpreter). Installs uv via `brew install uv` if absent — uv is NOT in `install_brew.sh`. Binary-path checks (not `command -v`) for the same no-`~/.zshrc` reason as step 5. Model prefetch (`docling-tools models download`, ~1.2 GB → enables offline `--artifacts-path` use) tolerates failure: the partial dir is removed and the run **continues** (docling fetches models on first use). Force redo: `uv tool uninstall docling` / `rm -rf ~/.cache/docling/models`. |

### Full `install_brew.sh` formula + cask lists (read from source)

This is the **complete** list — do not trust partial audits.

**Taps:** `felixkratz/formulae` (provides `sketchybar` + `borders`).

**Formulae:** `python`, `nvm`, `mysql`, `sketchybar`, `borders`, `ripgrep`, `ollama`, `gemini-cli`, `opencode`, `mas`, `gh`, plus **`postgresql@N`** — resolved at runtime to the highest installed/available `postgresql@N` (via `brew list --formula`, then `brew search`), falling back to `postgresql@17` if detection fails. All others are pinned to *latest* (no `@version`) on purpose, so the script keeps working for years.

**Casks:** `iterm2`, `visual-studio-code`, `brave-browser`, `spotify`, `dbeaver-community`, `keepingyouawake`, `transmission`, `vlc`, `nordvpn`, `bitwarden`, `onyx`, `nikitabobko/tap/aerospace`, `font-hack-nerd-font`, `font-sketchybar-app-font`, `cleanmymac`, `discord`, `obsidian`.

> Note: `aerospace` lives in its own tap (`nikitabobko/tap/aerospace`); the two `font-*` casks are required by sketchybar (nerd-font glyphs + the app-icon font used by `plugins/icon_map.sh`).

---

## Symlink targets created

[`setup_symlinks.sh`](../../scripts/installs/setup_symlinks.sh) (step 3) creates exactly **6** links. Its `make_link` helper: already-correct link → no-op; wrong link → `rm`; real file/folder → moved to `<name>.bak.$(date +%s)` (never deleted).

| System path (link) | → repo source |
|---|---|
| `~/.zshrc` | `zsh/zshrc.zsh` |
| `~/.aerospace.toml` | `configs/aerospace/aerospace.toml` |
| `~/Library/LaunchAgents/com.aerospace.display-profile.plist` | `configs/aerospace/com.aerospace.display-profile.plist` |
| `~/.config/borders` | `configs/borders` (whole dir) |
| `~/.config/sketchybar` | `configs/sketchybar` (whole dir) |
| `~/Library/Application Support/Code/User/settings.json` | `configs/vscode/settings.json` |

Plus a 7th, whole-folder link made later by [`setup_dot_claude.sh`](../../scripts/installs/setup_dot_claude.sh) (step 15), with the same `.bak.<ts>` backup discipline:

| System path (link) | → repo source |
|---|---|
| `~/.claude` | `configs/dot-claude` (the private submodule) |

> **`setup_symlinks.sh` and `_index.md` currently OVERCLAIM this as "the canonical map."** It covers only **6 of the 8** documented symlinks in `_index.md`. The two missing from the script are the AutoRaise config and the AutoRaise daemon plist (see next section). Treat the "canonical map" label as aspirational until the code is fixed — `setup_symlinks.sh` is *a* map, not *the* map.

---

## Known limitations — what the flow does NOT wire

This is the biggest hidden gap in the whole install, and nothing in `scripts/installs/` does it for you.

### 1. AutoRaise (focus-follows-mouse) is entirely absent post-bootstrap

Three independent omissions stack up:

- **The binary is never installed.** There is **no `autoraise` formula or cask** anywhere in `install_brew.sh`. Yet `configs/autoraise/com.autoraise.daemon.plist` hard-codes `ProgramArguments` → `/opt/homebrew/bin/AutoRaise`. So even if the agent were loaded, it would fail to exec a binary that doesn't exist.
- **The config is never symlinked.** `setup_symlinks.sh` does not link `configs/autoraise/config` → `~/.config/AutoRaise/config`.
- **The daemon is never loaded.** No `installs/` script does `launchctl bootstrap` on `com.autoraise.daemon.plist`.

**Net effect:** after a clean bootstrap, focus-follows-mouse does **not** work at all. AutoRaise must be installed (e.g. `brew install --cask autoraise` / from its GitHub) **and** wired (config symlinked, daemon bootstrapped) out-of-band.

### Contrast: `aerospace-restart.sh` *does* manage both

[`scripts/aerospace-restart.sh`](../../scripts/aerospace-restart.sh) — the **runtime** restart helper, not part of the install — boots out and re-bootstraps **both** LaunchAgents (`com.aerospace.display-profile`, `com.autoraise.daemon`) and kills/relaunches `AeroSpace`, `sketchybar`, `borders`, `AutoRaise`. So the runtime story is complete; the *install* story is not. If you ever fix the install gap, mirror what `aerospace-restart.sh` already does.

### 2. Case-sensitivity fragility (latent)

The repo dir is **lowercase** `configs/autoraise`, but the intended symlink target is `~/.config/AutoRaise/config` (**capital** A). This works on the default case-*insensitive* APFS and would silently break on a case-*sensitive* volume. Worth knowing before anyone "fixes" the casing or clones onto a case-sensitive disk.

---

## Interactive pause points (why an unattended run is impossible)

Several steps stop and wait for a human; you cannot fully automate this end-to-end:

- **iTerm2 must be quit** before `defaults write` (step 4) — else it clobbers the repo plist on quit.
- **VS Code first-open** if the `code` CLI isn't found yet (step 6).
- **App Store sign-in** before `mas install` (step 13) — Apple removed `mas signin`.
- **`gh auth login`** browser/device-code flow (step 14) — and it gates step 15.
- **`mysql_secure_installation`** interactive root-password setup (step 12).
- **sudo / Touch ID prompts** for `pam_tid.so` (step 7) and the Xcode license accept (step 13). Homebrew's one sudo prompt is handled earlier, in bootstrap.

---

## How to change things safely

- **Add/remove/reorder a step:** edit only the relevant `next_step "…"` + `bash "$INSTALLS/…"` pair in [`installation.sh`](../../scripts/installs/installation.sh). The `N/TOTAL` numbering recomputes itself from the `grep -c '^next_step '` count — don't hand-number anything. But **re-check the four ordering constraints above** before moving a step; the dependency graph is the real contract.
- **Add a brew formula/cask:** add a `brewInstall`/`caskInstall` line in [`install_brew.sh`](../../scripts/installs/install_brew.sh) (order within the file is irrelevant — each line is independent) **and** update the formula/cask list in this doc and in [`_index.md`](../../_index.md).
- **Add a symlink:** add a `make_link` call in [`setup_symlinks.sh`](../../scripts/installs/setup_symlinks.sh), then update the symlink table here and the map in [`_index.md`](../../_index.md) (keep all three in sync — this is exactly the kind of drift that produced the "canonical map" overclaim).
- **Re-run a finished step:** every sub-script is idempotent, so `bash ~/workspace/scripts/installs/<script>.sh` is safe. To force a redo, clear its idempotency marker first (delete `~/.workspace_mysql_secured`, move the relevant `.app` / symlink aside, `launchctl bootout` the agent, etc. — see the cheat-sheet column).
- **Re-run the whole orchestrator:** `bash ~/workspace/scripts/installs/installation.sh`. It resumes from wherever a partial install left off.
