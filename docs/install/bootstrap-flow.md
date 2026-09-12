# Fresh-Mac bootstrap and supervised recovery

The [recovery guide](supervised-recovery-plan.md) is the authoritative operational sequence and the sole handoff prompt template. Read it alongside this guide before changing any installer. The implementation is an **implemented candidate**. The user explicitly authorized committing and pushing all repository changes on 2026-09-12; public availability must be verified against the remote revision. Clean-Mac validation remains pending even after publication.

## Phase 1 and its stop boundary

The public command remains source-compatible and selects the version currently published on `master`:

```sh
curl -fsSL https://raw.githubusercontent.com/teazyou/workspace/master/scripts/installs/bootstrap.sh | bash
```

[`bootstrap.sh`](../../scripts/installs/bootstrap.sh) ensures macOS/architecture compatibility, at least 12 GiB free for the minimum toolset, bounded HTTPS connectivity, working CLT clang/Swift, native Homebrew and Git, and a safe `~/workspace` checkout. It selects only the five minimum casks from the inventory below and the native Claude CLI. It independently verifies minimum receipts, application structure/signatures, both CLI versions, and the active guide contract, then prints `Step1done`, authentication instructions, two concrete CLI launch commands, and the **short main-session prompt**, with workspace, guide, trusted origin, full revision, and both executable paths printed separately before its copy boundaries. It then exits. Authentication, first-open UI validation, and the remaining setup are explicitly pending.

One authenticated local AI provider is sufficient. The AI runs the existing installation scripts, verifies results, and repairs/reruns a script if it fails. Either installed CLI can supervise this directly in the main session; no model or delegation capability is required, and no agents are used. Verify actual local file and shell access on this Mac. If the selected session lacks that access, move the same prompt to an installed local CLI; remain in guidance mode only while local access is unavailable.

Brave is installed solely as an application for human account sign-in. Bootstrap does not change the default browser, open/quit apps, restore browser data, configure its Dock entry, or touch account state. Managed shell links, iTerm preferences, Node/NVM, fonts, window management, and macOS preferences are phase 2 work. Rosetta is not installed unconditionally: selected minimum artifacts are native/universal. Apple Silicon/macOS 26 is the acceptance target; Intel and other OS releases remain separately unverified compatibility paths.

### Entry safety, source validation, and reruns

Piped source is downloaded into a private temporary directory and run as a file with `/dev/tty` as stdin, so installers cannot consume the script pipe. Missing TTY, failed/invalid download, and interruption stop with a concrete rerun message. CLT waits visibly for at most 30 minutes; Control-C cancels. Homebrew installation checks administrator membership and obtains sudo interactively; its temporary sudo refresher is stopped on exit. Download requests have connection/total timeouts; Git HTTPS transfers stop after 60 seconds below one byte/second. There is no automatic retry loop. Full Xcode and App Store sign-in are deferred.

Homebrew is resolved at `/opt/homebrew/bin/brew` on native arm64 or `/usr/local/bin/brew` on Intel; unexpected PATH shadowing/prefix and translated execution stop. `shellenv` is initialized even when Brew was already installed but absent from PATH. No login shell is sourced.

After Git is ready, bootstrap resolves trusted HTTPS `master` once to a full commit, re-downloads **that immutable bootstrap**, and compares its bytes with the executing source before sourcing repository helpers. Branch movement or unpublished local code stops instead of mixing revisions. For an authorized published staging candidate, download the script from its immutable full revision and invoke `bash bootstrap.sh --revision FULL_COMMIT_ID`; clone and handoff use the same revision. The command is a trust decision in the publisher’s HTTPS source, not independent cryptographic release authentication.

An absent workspace is cloned without checkout before the resolved commit is selected. Existing checkouts/worktrees must have the exact root, trusted origin, revision, and unchanged recovery sources. Git-byte hashes check recovery roots (`scripts`, `functions`, `configs`, `zsh`, `docs`, `AGENTS.md`, `_index.md`, `.gitignore`), including actual file bytes even with index skip flags; Git replacement objects are disabled so local replacement refs cannot substitute another tree; redirected components, staged recovery edits, and untracked/ignored shadow files within those roots stop. Unrelated changes outside those roots are preserved. Nothing resets, cleans, stashes, pulls over, or unstages existing work. A failed partial clone remains for explicit diagnosis. A phase-1 rerun can legitimately reject phase-2 repairs or generated display/iTerm changes: resume the reviewed phase-2 session and reconcile its recorded diffs instead of discarding them.

[`recovery_checks.sh`](../../scripts/installs/recovery_checks.sh) shares read-only app/CLI checks and renders the one template. The guide’s exact active status/contract header and one marked template section must pass before printing success. A draft that merely mentions the marker fails. Application first-open/authentication remain human checks; damaged apps with receipts require diagnosis, never forced replacement or quarantine stripping.

## Single package inventory

[`install_brew.sh`](../../scripts/installs/install_brew.sh) is the sole inventory, reused for installation, `--list`, and `--verify-only`:

| Selection | Formulae | Casks |
|---|---|---|
| `--phase minimal` | None; Git is a bootstrap prerequisite | `iterm2`, `chatgpt`, `claude`, `codex`, `brave-browser` |
| `--phase remaining` | `python`, `nvm`, `sketchybar`, `borders`, `ripgrep`, `mas`, `gh` | `visual-studio-code`, `google-chrome`, `spotify`, `bitwarden`, `nikitabobko/tap/aerospace`, `font-hack-nerd-font`, `font-sketchybar-app-font`, `discord`, `obsidian` |
| `--phase all` or no arguments | Both groups | Both groups |

The only explicit normal tap is `felixkratz/formulae`, added for remaining/all. VPN-only dependencies remain in the [VPN guide](../vpn/guide-nordvpn-native.md). Homebrew resolves required dependencies. The inventory preserves all earlier targets and adds only Brave.

[`functions/brew.sh`](../../functions/brew.sh) has one caller, the inventory script, and performs no work when sourced. Helpers check receipts, show dry-run diagnostics for missing targets, propagate failures, and verify receipts after installs. The caller collects failures and independently checks commands, app bundles, and font file artifacts. A zero receipt check alone is insufficient. Required dependency changes must be reviewed by the main session **before** running the package row; the script’s own dry-run output is diagnostic, not a substitute for that review.

Normal phases export `HOMEBREW_NO_INSTALL_CLEANUP`, `HOMEBREW_NO_INSTALL_UPGRADE`, and `HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK`. They never explicitly upgrade or clean packages. Required dependencies may still need changes; protect the active AI/terminal host and defer disruptive work until a safe handoff exists. Blanket maintenance is a separate `install_brew.sh --maintenance` manual operation after that safety review. These controls are documented by [Homebrew](https://docs.brew.sh/Manpage).

Current mapping was rechecked against Homebrew API metadata on 2026-09-12: [`chatgpt`](https://formulae.brew.sh/cask/chatgpt) supplies `/Applications/ChatGPT.app` with retained identity `com.openai.codex`; [`codex`](https://formulae.brew.sh/cask/codex) supplies Homebrew’s `bin/codex`. [`claude`](https://formulae.brew.sh/cask/claude) supplies `/Applications/Claude.app`; native Claude Code remains `~/.local/bin/claude` and requires no Node installation. Existing Homebrew Claude Code receipts or another Claude executable on PATH stop native CLI setup for diagnosis. Neither a second Claude CLI distribution nor the deprecated separate Codex desktop cask is included. [`brave-browser`](https://formulae.brew.sh/cask/brave-browser) supplies `/Applications/Brave Browser.app` only.

## Explicit manual installer and dependencies

[`installation.sh`](../../scripts/installs/installation.sh) remains an explicit **manual** route. Bootstrap never invokes it, and the supervised prompt uses individual scripts. It initializes Brew/native Claude PATH and exports `WORKSPACE`, `SCRIPTS`, `INSTALLS`, `FUNCTIONS`, `APP_CONFIGS`. It auto-numbers these 13 stages:

| # | Script | Acceptance / important limits |
|---|---|---|
| 1 | `install_brew.sh` | Full inventory receipts and artifacts; no default maintenance. |
| 2 | `install_oh_my_zsh.sh` | Verify `~/.oh-my-zsh/oh-my-zsh.sh`; legacy directory-only skip can mask an incomplete installation. Uses `KEEP_ZSHRC=yes RUNZSH=no CHSH=no`. |
| 3 | `install_node.sh` | Sources `$HOMEBREW_PREFIX/opt/nvm/nvm.sh`; install/select LTS, set default `lts/*`; verify Node **and npm**. |
| 4 | `setup_symlinks.sh` | Verify all five links below; unique backups preserve wrong links and real files. |
| 5 | `install_iterm2.sh` | Custom folder + load flag skip check; if iTerm is running or process inspection fails, stops without writes. Transfer the active session first, human quits iTerm, then rerun. |
| 6 | `install_claude.sh` | Normally verifies Brew Desktop and native CLI. `--cli-only` omits Desktop work; `--desktop-fallback` is a diagnosed missing-app repair after Python. |
| 7 | `install_vscode_ext.sh` | Verify `bracketpaircolordlw.bracket-pair-color-dlw` and `chunsen.bracket-select` in `code --list-extensions`. In-bundle CLI fallback; first-open may be human work. |
| 8 | `install_touch_id_sudo.sh` | Human sudo/Touch ID; intended `pam_tid.so` line only. Review unexpected existing PAM contents before mutation. |
| 9 | `setup_macos.sh` | Captured preference helper and baseline defaults; normal Finder/Dock restart. Follow [macOS guide](macos-preferences.md), including dry-run, private backups, exact values, and manual gaps. |
| 10 | `setup_wallpaper.sh` | Solid black on every available desktop; Python fallback and declared Dock wallpaper-cache reset. Verify visually. |
| 11 | `install_window_manager.sh` | AeroSpace owns SketchyBar/Borders startup; verify all three processes and UI. No duplicate Brew services or WM LaunchAgent. Generated display config diffs are legitimate. |
| 12 | `install_xcode_mas.sh` | App Store sign-in, disk, human sudo/license; verify the actual Xcode developer directory and first-launch components. Legacy script may mask first-launch errors/select CLT. |
| 13 | `setup_dev.sh` | Creates `~/dev`, preserving projects; non-directory conflict fails. |

Brew precedes every dependency consumer. **Oh My Zsh and Node precede managed shell links**; Touch ID precedes Xcode; Dock apps precede macOS settings. Phase 2’s exact A–P sequence table and acceptance criteria live only in [the recovery guide](supervised-recovery-plan.md#exact-remaining-sequence-and-acceptance).

Managed shell correction: [`path.zsh`](../../zsh/configs/path.zsh) initializes native Homebrew and prepends `~/.local/bin`; [`nvm.zsh`](../../zsh/configs/nvm.zsh) loads the same Brew NVM source as the installer. [`zshrc.zsh`](../../zsh/zshrc.zsh) no longer appends another account’s hardcoded CLI path. First test these loaders in `zsh -f`; before a normal new interactive shell, review `git.zsh` (writes global identity), OMZ update behavior, and iTerm hooks. Activation is a new shell after dependencies and links, not phase 1. No unrelated shell policy changed.

The iTerm installer retains exactly `PrefsCustomFolder=$APP_CONFIGS/iterm2` and `LoadPrefsFromCustomFolder=1`. It does not set the **Always** save-back choice; explain that choice and let the human decide. Existing custom-folder preferences are a two-way live file, not a symlink. Preserve any legitimate save-back diff. CLI and safe Desktop fallback downloads use checked HTTPS transfers and private temporary directories; existing broken files/apps are diagnosed, never deleted or force-replaced. The Desktop fallback requires confirmed process absence (a process-inspection error stops without repair), verifies signature and Gatekeeper assessment, and retains first-open quarantine handling.

## Symlink targets created

The five ordinary links are created by [`setup_symlinks.sh`](../../scripts/installs/setup_symlinks.sh). Already-correct links are no-ops. Wrong links and real files/directories move into a unique private `<target>.bak.XXXXXX/original` directory; the old link destination and backup location are printed. No existing backup is overwritten.

| System path | Repository source |
|---|---|
| `~/.zshrc` | `zsh/zshrc.zsh` |
| `~/.aerospace.toml` | `configs/aerospace/aerospace.toml` |
| `~/.config/borders` | `configs/borders` |
| `~/.config/sketchybar` | `configs/sketchybar` |
| `~/Library/Application Support/Code/User/settings.json` | `configs/vscode/settings.json` |

The sixth documented link is the separate native VPN LaunchAgent, wired only after its guide’s checks and human approval.

## Additional setup and honest completion

The supervised recovery includes the entire [native VPN procedure](../vpn/guide-nordvpn-native.md#fresh-mac-setup-manual-outside-the-main-installer): fixed-path/minimal-PATH verification, narrowly trusted `vpnutil`, Python/jq checks, human-only credentials, verified Root CA, generated six-country profile with manual approval, durable off before the exact LaunchAgent link/load, and scheduled-with-the-human connection interruption tests. No live secrets enter AI context. Runtime VPN limitations remain visible in its guide; no polling or automatic profile removal is added.

The [manual macOS extras](macos-preferences.md#manual-post-reset-items) remain: Dictation double-Control if offered, sidebar favorites/order, ABC/input menu review, version-gated shortcut handling, and safe logout/login verification. Existing macOS configuration is preserved: Dock size 52, six managed apps with ChatGPT at position 4 plus Downloads, ABC-only desired input while retaining destination sources, selected shortcuts gated to macOS 26, existing baseline preferences and scoped backups. Brave has no managed Dock entry.

Human authentication, system/administrator/privacy permissions, App Store sign-in, credentials, profile approval, iTerm shutdown, VPN timing, and logout/reboot are explicit gates. The main session executes one row at a time, inspects source, verifies actual outcomes, diagnoses and makes bounded source repairs, retries at most once after justified repair, and continues only independent work when blocked. The final report marks each item verified, blocked, user-deferred, or pending human validation; script exits alone never establish complete restoration.

## Focused local verification and reruns

Implementation verification on 2026-09-12: `python3 scripts/installs/tests/test_supervised_recovery.py` passed all **24 tests**, including Bash/zsh parsing checks and independent review regressions for Git replacement objects and indeterminate Desktop process checks. Run that command for isolated fixtures/mocks. Every host-affecting command is stubbed or replaced by an isolated fixture; a temporary HOME alone is not treated as isolation. No lint, live bootstrap/recovery, package/app operation, preferences, or VPN setup is used for implementation tests. The unchanged macOS preference suite is not rerun merely for this split.

For a scoped rerun, initialize the recovery guide’s environment and invoke `/bin/bash "$INSTALLS/<exact script from the table>"`. Some older scripts need `INSTALLS` set before their helper can initialize defaults. Preserve failed evidence and existing data; never delete state to force success. The explicit manual full command remains `bash ~/workspace/scripts/installs/installation.sh`; it can prompt, restart Finder/Dock, launch WM, and reapply defaults, so it is not the supervised resume method.

Fresh-machine candidate testing, human first-open/authentication, both provider paths independently, interruptions/reruns, real app/CLT signatures, fresh-shell startup, UI permissions, native VPN, and logout/login/wake behavior remain unperformed until separately authorized on a compatible test machine. Publication was separately authorized for this change; local changes alone do not update the GitHub command, so verify the pushed revision and raw source before reporting public availability. Publishing the candidate does not replace clean-Mac trials.
