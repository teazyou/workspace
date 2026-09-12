# Native NordVPN IKEv2 — authoritative guide

**Goal:** replace the NordVPN GUI app (measured ~545 MB RAM + ~8% of a core, continuously idle) with the macOS-native IKEv2/IPsec VPN engine, driven by one CLI command, with **zero resident processes and zero polling**. The tunnel itself is carried by Apple's built-in Network Extension daemons (`neagent`/`nesessionmanager`), which run on every Mac anyway — this stack adds **no** process of its own.

User contract:
- `nord <country>` — one command to switch (belgium, france, singapore, vietnam, usa, malaysia).
- Attempts reconnection after login and watched resolver-file changes (typically wake/network change) — event-driven, without periodic polling. Dependency checks, failure cooldowns, and missed filesystem events can prevent an attempt; see the fresh-Mac checks below.
- `nord off` (or a connected sketchybar VPN icon click) = durable off. A System Settings VPN toggle does **not** write this stack's `enabled` file and is not a durable-off command.
- **State persists across reboots** — the machine comes back on whatever country/on-off state it had at shutdown. Nothing forces a default country.
- The NordVPN GUI app is **fully uninstalled** (2026-07-22: `brew uninstall --zap --cask nordvpn` + manual purge of the container/prefs leftovers zap's globs missed — its root helper daemon had still been running on demand). Only this native stack remains; service credentials are account-level and unaffected.

## Components

| Piece | Path | Role |
|---|---|---|
| CLI | `scripts/vpn/nord.sh` (alias `nord` via `zsh/alias/vpn.zsh`) | switch/on/off/toggle/status/list/refresh |
| Reconnect agent | `scripts/vpn/nord-connect.sh` + `configs/nordvpn/com.teazyou.nordvpn-native.plist` (symlink in `~/Library/LaunchAgents/`) | event-driven one-shot: `RunAtLoad` + `WatchPaths` on resolv.conf |
| Bundle generator | `scripts/vpn/nord-gen-bundle.sh` | renders the 6-country `.mobileconfig` from live "best server" API data |
| Bar item | `configs/sketchybar/items/vpn.sh` + `plugins/vpn.sh` + `plugins/vpn_click.sh` | two text items — **BE** (Belgium) and **SN** (Singapore, code `sg`) — **colour is the only channel**: grey = not connected, red = connected, yellow = connecting, magenta = `nord refresh` needed. There is deliberately **no "selected country" marker** (orange, then a dot, then a thin underline were each tried and removed on 2026-07-30): when both read grey the VPN is simply off, and which country `nord on` would dial is not worth bar space — `nord status` says so. Click = `vpn_click.sh`, predictable straight from the visible colour: a **grey** icon connects that country (`nord <cc>` switch + on — or `nord toggle` if it happens to be the selected one, same outcome), the **red** one disconnects (`nord toggle`); paints that icon busy (yellow "…") instantly and ignores re-clicks on EITHER icon until the action ends (200 s stale-steal). ONE shared click lock `/tmp/nordvpn-native.click`, whose `owner` file names the clicked item so `plugins/vpn.sh` keeps the busy look on the right icon while the other keeps rendering its real state. |
| State dir | `~/.config/nordvpn-native/` (0700, **outside the repo**) | see below |
| Log | `logs/nordvpn-native.log` | agent activity (gitignored) |

`~/.config/nordvpn-native/` contents: `credentials` (NORD_USER/NORD_PASS service credentials, 0600, **never committed/logged**), `nord-root.der` (NordVPN Root CA), `nord-bundle.mobileconfig` (rendered profile, 0600 — embeds the credentials), `servers` (cc=hostname pins manifest), `country` (target cc), `enabled` (1/0), `refresh-needed` (flag file → the selected country's bar icon turns magenta), `fail-stamp` (10-min same-network failure cooldown).

## Design decisions (do not silently reverse)

1. **IKEv2 over WireGuard** — native NE engine, zero of our processes while connected; WireGuard would keep a `wireguard-go` userspace process alive forever.
2. **ONE 6-payload profile, approved once.** macOS 26 removed headless profile installs (`profiles install` refuses; spike-verified). So all 6 countries + the Root CA payload ship in one `.mobileconfig`; after a single System Settings approval, `vpnutil` can start any of them headlessly. Consequence: server hostnames are **frozen at approval time** (see Refresh).
3. **NO VPN On-Demand.** Tested live: an On-Demand-enabled payload fights manual control of the *other* payloads for macOS's **single personal-VPN slot** — observed both configs stuck "Connecting" forever with **all traffic blackholed** (no internet at all until one was toggled off by hand). Auto-reconnect is instead event-driven via launchd (next point). Do not re-add `OnDemandEnabled/OnDemandRules` to any payload.
4. **Reconnect = launchd one-shot, not a daemon.** `RunAtLoad` (load/login) + `WatchPaths` on `/var/run/resolv.conf` + `/etc/resolv.conf` react to resolver-file changes, often caused by wake, Wi-Fi joins, or tunnel transitions. There is no dedicated wake trigger or guarantee of observing every change (`man launchd.plist` explicitly warns that WatchPaths events can be missed). The process exits after its bounded network/connection attempts; `ThrottleInterval 15` limits relaunch bursts. **No StartInterval, no KeepAlive, no periodic polling — keep it that way.** The short retry loops inside one invocation are not a persistent monitor.
5. **Reboot keeps the last state — no boot reset.** `country`/`enabled` are read from disk as-is, so the VPN comes back exactly as you left it and `nord off` survives a reboot. If a "reset to country X on boot" rule is ever wanted, detect the boot with `sysctl -n kern.bootsessionuuid` against a stored id — the two obvious alternatives are field-tested WRONG: a `/tmp` marker (macOS purges `/tmp` after ~3 days of uptime → false "boot" mid-session) and `kern.boottime` (recalculated after every sleep/wake → every wake looks like a reboot and force-re-enables a VPN the user turned off).
6. **Control tool = `vpnutil`** (Homebrew `timac/vpnstatus/vpnutil`, tap trusted via `brew trust timac/vpnstatus`). It is the only CLI that can start/stop profile-installed IKEv2 configs — `scutil --nc` cannot even see them. `networksetup` can't either.
7. **Secrets stay out of the repo**: credentials + rendered mobileconfig live only in `~/.config/nordvpn-native/`, 0600. Repo scripts contain no secrets.

## Concurrency & correctness rules (hard-won, keep intact)

- **Single-slot rule:** never `vpnutil start` a config while another is `Connected`/`Connecting` — two `Connecting` configs deadlock the slot and blackhole all traffic. Both scripts strictly stop→confirm-down→start.
- **Never leave a dangling `Connecting`:** a failed start is always followed by `vpnutil stop` of the target (a wedged `Connecting` also blackholes traffic).
- **Shared lock** `/tmp/nordvpn-native.lock` (mkdir-atomic): the CLI waits up to 60 s for it; the watcher takes it **non-blocking** (CLI wins) and only around its mutating phase. Tunnel transitions rewrite resolv.conf → the watcher fires after every `nord` action; the lock + its post-lock re-checks make that harmless.
- **`nord off` writes `enabled=0` BEFORE stopping** so a mid-flight watcher aborts instead of redialing.
- **Success detection:** `vpnutil`'s status can lag the tunnel by minutes (observed on slow servers). The CLI checks `Connected` for 45 iterations with 1-second sleeps, then accepts `Connecting` if the public exit IP moved off the pre-start baseline. The agent uses 30 iterations and then accepts an IP change without requiring `Connecting`. Command runtimes add to those sleeps. These are connection heuristics, not DNS/IPv6 leak tests. Country-based checks are wrong twice over: the user may physically be in the target country, and some pins are virtual locations (see VN caveat).
- The watcher respects an already-Connected config (a human choice via System Settings is never overridden).
- **Failure cooldown:** after a failed reconnect, the watcher arms a 10-min cooldown keyed to the network fingerprint (default-route interface+gateway, `fail-stamp` file) and stays quiet on that network. Without it, a network where the tunnel can't establish gets a connect→blackhole→fail→retry storm that makes the whole machine's internet unusable (2026-07-22 home-Wi-Fi incident). A different network or elapsed 600 seconds permits another event-triggered attempt; successful **agent** connection removes the stamp. CLI connections bypass the cooldown but do not delete that stamp; `status`, `list`, and `refresh` do not reset it. Expiry alone does not schedule a retry.
- The watcher's net-probe includes an IP-literal fallback (`http://1.1.1.1`) so a dead tunnel's leftover scoped DNS resolver can't blind it. **`nord rescue`** is the user escape hatch: durable off + stop all + Wi-Fi flap (rebuilds routes/DNS) + connectivity report.

## Flows

- **`nord france`** → lock → write `enabled=1` → stop all → start Nord-FR → on success write `country=fr` → `sketchybar --trigger vpn_change`. A failed switch leaves the previous saved country and `enabled=1`.
- **Login / watched resolver-file change** → launchd fires `nord-connect.sh` → if enabled && nothing connected/connecting → check cooldown → wait for network (40 retries with 3-second sleeps, plus probe timeouts) → lock → re-check → start saved country. The source's “120s” message describes sleep time, not a strict wall-clock cap.
- **`nord off`** → `enabled=0` → stop all. Durable across network events **and reboots**; only `nord on`/switch/toggle re-enables.
- **`nord refresh`** → regenerate bundle from current API "best" per country → `open` it → **one manual approval** in System Settings (General → Device Management → NordVPN Native IKEv2 → Install). VPN/CA payload UUIDs and the profile identifier are stable to support replacement. The top-level UUID changes with the manifest or service **username**, but excludes the password and CA bytes: password-only or CA-only changes can be ignored as the same installed version. See the refresh limitation below.

## Fresh-Mac setup (manual, outside the main installer)

Phase 1 of the [reinstallation process](../install/bootstrap-flow.md) stops before installing or activating this stack. Follow these steps during supervised phase 2 or standalone setup after the repository is present; the NordVPN GUI app and the separate VPNStatus GUI are not required. An AI helper can guide the public setup and verify non-secret results. The human completes Nord sign-in/email verification, edits credentials locally, and approves the profile. Do not read credentials or the rendered profile into a chat, log, or repository.

### 1. Prerequisites and supported paths

Use an administrator account, an active NordVPN subscription, access to its registered email, working internet, and macOS with permission to install configuration profiles. This repository was exercised on macOS 26; use that target for this setup. Homebrew currently requires macOS 15 or newer on supported hardware plus Xcode or Command Line Tools. See [Homebrew installation requirements](https://docs.brew.sh/Installation); if those are missing, use that official procedure (CLT: `xcode-select --install`) or the repository bootstrap before continuing.

**The current implementation assumes Apple Silicon Homebrew at `/opt/homebrew` and the checkout at `/Users/teazyou/workspace`.** Both control scripts hardcode `/opt/homebrew/bin/vpnutil`; the plist hardcodes the script and log paths under `/Users/teazyou/workspace`. A different account, checkout, or Intel Homebrew prefix requires an implementation change before agent activation. Changing the symlink alone cannot fix those embedded paths. This guide does not silently change them.

In a terminal, initialize Homebrew and verify the checkout:

```sh
eval "$(/opt/homebrew/bin/brew shellenv)"
test "$HOME" = /Users/teazyou
test -f /Users/teazyou/workspace/scripts/vpn/nord-gen-bundle.sh
test -f /Users/teazyou/workspace/configs/nordvpn/com.teazyou.nordvpn-native.plist
```

Stop on a failed check. The complete dependency inventory for the three VPN scripts is:

| Dependency | Provision/use |
|---|---|
| `vpnutil` | Manual Homebrew formula below; must exist at `/opt/homebrew/bin/vpnutil`. |
| `jq` | Required by **all three scripts** for API and VPN JSON. Use working system `jq` when available; manual fallback below. It is not a dependency in the upstream vpnutil formula. |
| `python3` | Generator only, using standard-library `os`, `plistlib`, `uuid`, `hashlib`; no pip packages. The main installer already includes `python`; if following this guide alone and Python is absent, `brew install python`. |
| `bash`, `curl`, `awk`, `cat`, `chmod`, `date`, `dirname`, `grep`, `head`, `host`, `mkdir`, `mv`, `networksetup`, `open`, `rm`, `rmdir`, `route`, `sed`, `seq`, `sleep`, `touch`, `tr` | macOS system tools (plus shell builtins such as `source`, `read`, `echo`, `command`, `trap`, `test`). `host` checks pin DNS; `networksetup` is used only by rescue. |
| `sketchybar` | Optional status-bar notifications; connection control does not require it. |
| `brew`, `git`, `xcode-select`, `env`, `openssl`, `nano`, `stat`, `ln`, `readlink`, `mktemp`, `id`, `launchctl`, `tail` | Additional tools for the setup/verification commands in this guide; macOS/CLT/Homebrew provide them. |

Install only the control CLI. The explicit tap/trust/install sequence follows [Timac's upstream installation](https://github.com/Timac/VPNStatus) and [Homebrew's current trust model](https://docs.brew.sh/Tap-Trust):

```sh
brew tap timac/vpnstatus
brew trust --formula timac/vpnstatus/vpnutil
brew install timac/vpnstatus/vpnutil
test -x /opt/homebrew/bin/vpnutil
python3 -c 'import plistlib, uuid, hashlib; print("Python dependencies OK")'
```

`brew trust timac/vpnstatus` is the whole-tap alternative historically used here; it trusts all present and future items in that tap. The formula-only command above is sufficient. A fully qualified `brew install timac/vpnstatus/vpnutil` also grants that formula trust under current Homebrew. Use current Homebrew if `brew trust` is unknown. The [upstream formula](https://raw.githubusercontent.com/Timac/homebrew-vpnstatus/master/Formula/vpnutil.rb) installs the CLI and declares only macOS as a dependency; it does not bring in `jq` or Python.

**Explicit jq decision:** this Mac supplies `/usr/bin/jq` (`jq-1.7.1-apple`), and [Apple's text_cmds source](https://github.com/apple-oss-distributions/text_cmds/tree/main/jq) includes jq. Verify the target instead of adding a redundant formula to the main installer:

```sh
command -v jq
jq --version
/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/bash --noprofile --norc -c \
  'printf '\''{"VPNs":[{"name":"Nord-SG"}]}'\'' | jq -e '\''.VPNs[] | select(.name=="Nord-SG") | .name=="Nord-SG"'\'''
```

The last check must print `true` and succeed; it models the agent's system PATH without running the VPN. If interactive `jq` is absent, `brew install jq` is the [official manual fallback](https://jqlang.org/download/), followed by the same checks. **If only Homebrew jq works and the minimal-PATH check fails, automatic reconnect is blocked on that target:** the plist sets no PATH and its non-login shell does not source `.zshrc`. An interactive PATH export alone does not fix that. Report the required script/plist environment correction before activating the agent; do not claim that bootstrap or an unrelated global environment setting covers it. The current Mac passes this check. VPN-only dependencies remain outside the main installer.

### 2. Create the private credentials file

The human opens [Nord Account](https://my.nordaccount.com/) and selects **NordVPN → Advanced settings → Set up NordVPN manually → Service credentials → Verify email**, then enters the code received at the registered email. Copy the service username/password, rather than the normal account login. This navigation and email gate come from [Nord's macOS IKEv2 instructions](https://support.nordvpn.com/hc/en-us/articles/19921536696977-How-to-connect-to-NordVPN-with-IKEv2-IPSec-on-macOS).

Create the directory and a placeholder file without overwriting an existing file or following a credentials symlink:

```sh
(
  set -eu
  umask 077
  vpn_cfg="$HOME/.config/nordvpn-native"
  test ! -L "$vpn_cfg"
  mkdir -p "$vpn_cfg"
  chmod 700 "$vpn_cfg"
  if [ ! -e "$vpn_cfg/credentials" ] && [ ! -L "$vpn_cfg/credentials" ]; then
    (set -C; cat > "$vpn_cfg/credentials" <<'CREDENTIALS'
NORD_USER='REPLACE_WITH_SERVICE_USERNAME'
NORD_PASS='REPLACE_WITH_SERVICE_PASSWORD'
CREDENTIALS
    )
  fi
  test ! -L "$vpn_cfg/credentials"
  chmod 600 "$vpn_cfg/credentials"
)
```

The human now edits that file locally with `nano ~/.config/nordvpn-native/credentials`, replaces both placeholders, and saves it. It is a Bash-sourced file: two quoted assignments, no spaces around `=`, no account email or extra commands. Single quotes preserve literal characters; a literal apostrophe must be represented as `'\''` inside the quoted value. Do not put actual values in shell command arguments/history, request them in chat, or use `bash -x`. The generator only checks nonempty values; placeholders also pass, so the human must confirm replacement.

Verify permissions using metadata only:

```sh
stat -f '%Lp %N' ~/.config/nordvpn-native ~/.config/nordvpn-native/credentials
```

Expected modes are `700` for the directory and `600` for the file. The scripts do not consistently enforce directory/runtime-file modes themselves; this setup creates the private boundary before they run.

### 3. Acquire and verify the Root CA

Nord's public macOS instructions link directly to [the IKEv2 Root CA](https://downloads.nordcdn.com/certificates/root.der). The downloaded file was verified as **DER**, not PEM, during this guide's preparation. Fetch it over verified HTTPS to a temporary file in the private directory, parse it, check its CA metadata and validity, and verify its self-signature before accepting it:

```sh
(
  set -eu
  umask 077
  vpn_cfg="$HOME/.config/nordvpn-native"
  vpn_ca_tmp="$(mktemp "$vpn_cfg/nord-root-download.XXXXXX")"
  trap 'rm -f "$vpn_ca_tmp" "$vpn_ca_tmp.pem"' EXIT
  curl -fL --proto '=https' --proto-redir '=https' --max-time 30 \
    https://downloads.nordcdn.com/certificates/root.der -o "$vpn_ca_tmp"
  /usr/bin/openssl x509 -inform DER -in "$vpn_ca_tmp" \
    -noout -subject -issuer -dates -sha256 -fingerprint
  /usr/bin/openssl x509 -inform DER -in "$vpn_ca_tmp" -noout -text | grep -A3 'Basic Constraints'
  /usr/bin/openssl x509 -inform DER -in "$vpn_ca_tmp" -noout -subject -nameopt RFC2253 | \
    grep -Fx 'subject= CN=NordVPN Root CA,O=NordVPN,C=PA'
  /usr/bin/openssl x509 -inform DER -in "$vpn_ca_tmp" -noout -issuer -nameopt RFC2253 | \
    grep -Fx 'issuer= CN=NordVPN Root CA,O=NordVPN,C=PA'
  /usr/bin/openssl x509 -inform DER -in "$vpn_ca_tmp" -noout -text | grep -q 'CA:TRUE'
  /usr/bin/openssl x509 -inform DER -in "$vpn_ca_tmp" -outform PEM -out "$vpn_ca_tmp.pem"
  /usr/bin/openssl verify -check_ss_sig -CAfile "$vpn_ca_tmp.pem" "$vpn_ca_tmp.pem"
  test ! -e "$vpn_cfg/nord-root.der"
  test ! -L "$vpn_cfg/nord-root.der"
  mv "$vpn_ca_tmp" "$vpn_cfg/nord-root.der"
  chmod 600 "$vpn_cfg/nord-root.der"
)
```

Expected public metadata: subject and issuer both `C=PA, O=NordVPN, CN=NordVPN Root CA`, `CA:TRUE`, and verification ending in `OK`. At verification on 2026-09-12 its validity was 2016-01-01 through 2035-12-31. The temporary PEM is only for verification; the final `nord-root.der` remains DER. These [x509 parsing/conversion options](https://docs.openssl.org/3.0/man1/openssl-x509/) were also checked with macOS's `/usr/bin/openssl`; `verify -check_ss_sig` checks the self-signature and current validity.

The authenticated official download is the source of identity trust. A displayed fingerprint or successful self-signature alone is not independent proof of Nord ownership; no unverified fixed fingerprint is prescribed here. If metadata differs, download/parse/verification fails, or the destination already exists, stop and review the official certificate link and existing **public certificate** before continuing. Do not rename a PEM or HTML error page to `.der`, use `curl -k`, or overwrite a working CA blindly. This repository embeds the CA in the bundle; the separate manual Keychain/VPN-entry creation steps in Nord's generic guide are replaced by the bundle approval below.

### 4. Generate and approve all six connections

Run the generator directly so errors are visible:

```sh
(umask 077; bash ~/workspace/scripts/vpn/nord-gen-bundle.sh)
```

It checks the credentials file and `nord-root.der` exist, sources the credentials, and rejects missing/empty `NORD_USER` or `NORD_PASS`. It queries the live Nord recommendations API for technology `ikev2`, limit `1`, in order **be, fr, my, sg, us, vn** (country IDs **21, 74, 131, 195, 228, 234**). It prints six public `pin: cc -> hostname` lines, writes `servers` as six `cc=hostname` lines, and produces `nord-bundle.mobileconfig` with six VPN payloads **Nord-BE, Nord-FR, Nord-MY, Nord-SG, Nord-US, Nord-VN** plus **NordVPN Root CA**. Both final files are mode `600` under `~/.config/nordvpn-native/`; the profile contains the service password. The generator validates presence, not certificate identity or credential correctness.

Success prints `wrote .../nord-bundle.mobileconfig`, removes `refresh-needed`, and opens the profile. Opening is **not** installation. The human goes to **System Settings → General → Device Management → NordVPN Native IKEv2 → Install**, reviews the six VPN connections and CA, then completes macOS authentication. Apple's [Device Management instructions](https://support.apple.com/en-gb/guide/mac-help/mh35474/mac) describe this settings pane. The locally generated profile is unsigned. No headless install, six separate profiles, or On-Demand rules are needed.

Failure handling: `missing ... (NORD_USER/NORD_PASS)` or `missing ... (NordVPN Root CA)` means the named file is absent; `credentials file must define ...` means empty/missing variables; `API lookup failed for <cc>` means a timeout, network/API response, or jq failure. Fix the prerequisite and rerun. A partial `servers.tmp` can remain and is replaced on the next run. A Python failure can occur after the manifest was updated, so the manifest alone does not prove a current profile exists or is installed. Do not show the credentials/profile to diagnose errors. `nord refresh` currently prints its final approval hint even when the generator fails, so use the direct command's exit result and the actual Device Management installation as evidence.

### 5. Connect and establish durable off

The normal zsh setup loads [`zsh/alias/vpn.zsh`](../../zsh/alias/vpn.zsh). For a new terminal that has not loaded it, set the same command explicitly:

```sh
alias nord='bash "$HOME/workspace/scripts/vpn/nord.sh"'
nord list
nord status
nord singapore
nord status
nord off
nord status
```

Always supply a subcommand: the current no-argument dispatch references unset `$1` despite its intended status default. `list` should show all six installed names and pins. `status` reports target, enabled state, tunnels, public exit IP/location, and DNS reachability of pins; it can update `refresh-needed`, so it is not purely read-only. First-run state defaults to `sg` and enabled `1` when those files do not exist. After a successful connection, expect `Nord-SG` connected (or the explicit status-lag/IP-change message), saved target `sg`, and enabled `1`. After `off`, expect enabled `0` and no connected/connecting tunnels. Inspect the printed report: `status` normally reaches the script’s final `exit 0`, so a successful exit does not prove that the tunnel or pinned-server checks are healthy.

Accepted switches: `belgium|be`, `france|fr`, `malaysia|my`, `singapore|sg`, `usa|us|united-states`, `vietnam|vn`. `nord on` reconnects the saved country (default Singapore); `nord toggle` flips connection state. There are no `nord connect` or `nord disconnect` subcommands. Control operations stop every connected/connecting VPN returned by `vpnutil`, without filtering to `Nord-*`, despite the source comment saying “Nord”; use this as the sole personal VPN controller and do not run competing VPN clients.

### 6. Link and load the reconnect LaunchAgent

Proceed only after the path and minimal-PATH jq checks pass, the profile is installed, and `nord off` has succeeded. Create the exact link without overwriting a different existing object:

```sh
(
  set -eu
  test "$HOME" = /Users/teazyou
  mkdir -p "$HOME/Library/LaunchAgents" /Users/teazyou/workspace/logs
  vpn_agent="$HOME/Library/LaunchAgents/com.teazyou.nordvpn-native.plist"
  vpn_source=/Users/teazyou/workspace/configs/nordvpn/com.teazyou.nordvpn-native.plist
  if [ -L "$vpn_agent" ] && [ "$(readlink "$vpn_agent")" = "$vpn_source" ]; then
    :
  elif [ -e "$vpn_agent" ] || [ -L "$vpn_agent" ]; then
    printf '%s\n' 'Existing LaunchAgent differs; inspect before replacing it.' >&2
    exit 1
  else
    ln -s "$vpn_source" "$vpn_agent"
  fi
)
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.teazyou.nordvpn-native.plist"
launchctl print "gui/$(id -u)/com.teazyou.nordvpn-native"
```

Run as the logged-in user, without `sudo`. On a rerun, `launchctl print` can confirm it is already loaded; skip duplicate bootstrap. A loaded one-shot may be idle with no PID, which is expected. Loading fires RunAtLoad, but the prior `nord off` keeps it disabled. This link remains outside `setup_symlinks.sh`.

### 7. Validate reconnection, persistence, and refresh

These are **manual post-reset checks**, not tests performed during documentation preparation. They deliberately change connections; perform them when a brief network interruption is acceptable.

1. **Durable off:** after `nord off`, run `launchctl kickstart "gui/$(id -u)/com.teazyou.nordvpn-native"`, then `nord status`. Expect enabled `0` and no tunnel. A later login/reboot should preserve this; do not treat a stopped process as an unloaded agent.
2. **Reconnect while enabled:** run `nord on` and verify status. With no other VPN controller running, briefly turn the active Nord connection off in System Settings → VPN while leaving this stack enabled; this simulates a drop, not durable off. A resolver-file change should trigger the agent. If it does not, `launchctl kickstart "gui/$(id -u)/com.teazyou.nordvpn-native"` tests the one-shot explicitly. Check `nord status` and `tail -n 30 ~/workspace/logs/nordvpn-native.log` for `reconnecting Nord-...` then `connected ...`, or a concrete network/cooldown failure. A normal sleep/wake or network change can test the real event later. Do not add periodic retries to compensate for an unobserved event.
3. **Persistence:** after a successful country selection, the next ordinary reboot/login should reconnect that saved country when enabled, or stay off when disabled. No forced default/reset exists. Use `nord off` to finish testing in a durable-off state if desired.
4. **Stale pins:** `nord status` prints `DEAD PINS: ... -> run 'nord refresh'` when any pinned hostname fails its DNS lookup; connection failure also sets `refresh-needed`. DNS success means name resolution, not IKEv2 health. A healthy status clears the flag even if a connect recently failed, and the generator clears it before approval. Do not deliberately corrupt pins or infer installation from the flag disappearing.
5. **Refresh:** use `nord off`, then `nord refresh`, complete the same Device Management approval, and run `nord list`, `nord on`, `nord status`. This generates current recommendations for all six countries, not only the selected one. Unchanged pins/username produce the same top-level UUID and may be ignored as already installed. `servers` describes the latest generated bundle, not an independent reading of installed profile endpoints.

**Credential/CA update limitation:** the generator's UUID hash includes manifest bytes and `NORD_USER`, but omits `NORD_PASS` and CA bytes. If only the service password or CA changes, successful generation does not establish that macOS installed that change. A deliberate removal/reinstall of this exact profile may be needed after durable off, with its connection loss understood; do not auto-remove profiles or rotate credentials to test this guide. Fixing update identity is a separate implementation task. None of these setup steps alters scripts or the LaunchAgent environment.

## Ops

```sh
nord status      # target, enabled, tunnels, exit IP, pinned-server DNS health
nord rescue      # internet broken? durable off + Wi-Fi flap + connectivity report
nord list        # countries, pins, live states
tail -f ~/workspace/logs/nordvpn-native.log
launchctl kickstart gui/$(id -u)/com.teazyou.nordvpn-native   # force a watcher run
launchctl bootout  gui/$(id -u)/com.teazyou.nordvpn-native    # disable the agent
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.teazyou.nordvpn-native.plist  # re-enable
```

**Stale pins / dead server:** connect failures and `nord status` DNS checks set `~/.config/nordvpn-native/refresh-needed` → the selected country's BE/SN bar icon turns **magenta** when represented → run `nord refresh` and approve the profile. Successful connection, healthy `status`, or successful generation clears the flag; generation alone does not prove installation.

**Fresh-Mac note:** deliberately **NOT** wired into `installation.sh`/`setup_symlinks.sh`. Follow [Fresh-Mac setup](#fresh-mac-setup-manual-outside-the-main-installer) for prerequisites, formula trust, system-jq verification/manual fallback, credentials, verified CA, profile approval, and the exact LaunchAgent link/bootstrap.

## Caveats

- **Vietnam location caveat:** previously observed VN pins geolocated to Hong Kong, and using `nord vietnam` caused Claude Code logout. This is a recorded observation, not a guarantee about every newly recommended VN server. As checked on 2026-09-12, [Anthropic's supported-region list](https://www.anthropic.com/supported-countries) includes Vietnam, Singapore, and Malaysia but omits Hong Kong. Verify the actual exit location; sg/my were the working choices recorded here.
- vpnutil `status` lag: `Connecting` shown while already routing (see success detection above).
- The IKEv2 password sits in the installed profile; the profile file itself is 0600 and the account password is never involved (service credentials only, rotatable from the Nord dashboard).
- The sketchybar plugin needs `/opt/homebrew/bin` prepended to PATH (sketchybar's env has no Homebrew) — already handled inside `plugins/vpn.sh`.
- `nord rescue` assumes Wi-Fi is `en0` and turns that interface off/on; verify the interface with `networksetup -listallhardwareports` before using it. It is an emergency network mutation, not a harmless status check or a portable fix for every Mac.
- **Only BE/SN are represented on the bar**; the CLI still supports all 6 countries. If the selected country is fr/my/us/vn (or a config is started by hand outside `nord`), **both** bar icons render grey — indistinguishable from "VPN off", since nothing marks the selected country — and the real exit stays unrepresented: a known 2-icon limitation, not a bug.
- **A reboot does not change the target** (design decision 5) — the selected country and the on/off state are whatever they were at shutdown, so the bar comes back showing the state you left.

## Verified test matrix (2026-07-22, macOS 26.5.2)

All six countries connect via `nord <cc>`; off durable across a forced watcher run; toggle cycle; reboot preserves `country`/`enabled`; Wi-Fi flap self-heal; bar states red/orange/grey + CC label (**superseded 2026-07-30: two-icon BE/SN bar, colour-only — orange, then a selection dot, then a selection underline were all tried and dropped; see the Bar item row and re-verify per that table**); single approval covers all 6 payloads.
