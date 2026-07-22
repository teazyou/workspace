# Native NordVPN IKEv2 — authoritative guide

**Goal:** replace the NordVPN GUI app (measured ~545 MB RAM + ~8% of a core, continuously idle) with the macOS-native IKEv2/IPsec VPN engine, driven by one CLI command, with **zero resident processes and zero polling**. The tunnel itself is carried by Apple's built-in Network Extension daemons (`neagent`/`nesessionmanager`), which run on every Mac anyway — this stack adds **no** process of its own.

User contract:
- `nord <country>` — one command to switch (belgium, france, singapore, vietnam, usa, malaysia).
- Always reconnects by itself (login, wake, network change) — event-driven, never polled.
- `nord off` (or the sketchybar VPN icon click, or the System Settings VPN toggle) = durable off.
- **Every reboot resets to Singapore + enabled** (deliberate: chosen over "remember last country").
- The NordVPN GUI app is left completely alone (user manages it).

## Components

| Piece | Path | Role |
|---|---|---|
| CLI | `scripts/vpn/nord.sh` (alias `nord` via `zsh/alias/vpn.zsh`) | switch/on/off/toggle/status/list/refresh |
| Reconnect agent | `scripts/vpn/nord-connect.sh` + `configs/nordvpn/com.teazyou.nordvpn-native.plist` (symlink in `~/Library/LaunchAgents/`) | event-driven one-shot: `RunAtLoad` + `WatchPaths` on resolv.conf |
| Bundle generator | `scripts/vpn/nord-gen-bundle.sh` | renders the 6-country `.mobileconfig` from live "best server" API data |
| Bar item | `configs/sketchybar/items/vpn.sh` + `plugins/vpn.sh` | red+CC label=connected, yellow=connecting, grey=off, **orange=refresh needed**; click = `nord toggle` |
| State dir | `~/.config/nordvpn-native/` (0700, **outside the repo**) | see below |
| Log | `logs/nordvpn-native.log` | agent activity (gitignored) |

`~/.config/nordvpn-native/` contents: `credentials` (NORD_USER/NORD_PASS service credentials, 0600, **never committed/logged**), `nord-root.der` (NordVPN Root CA), `nord-bundle.mobileconfig` (rendered profile, 0600 — embeds the credentials), `servers` (cc=hostname pins manifest), `country` (target cc), `enabled` (1/0), `boot-id` (kern.boottime of last seen boot), `refresh-needed` (flag file → bar turns orange).

## Design decisions (do not silently reverse)

1. **IKEv2 over WireGuard** — native NE engine, zero of our processes while connected; WireGuard would keep a `wireguard-go` userspace process alive forever.
2. **ONE 6-payload profile, approved once.** macOS 26 removed headless profile installs (`profiles install` refuses; spike-verified). So all 6 countries + the Root CA payload ship in one `.mobileconfig`; after a single System Settings approval, `vpnutil` can start any of them headlessly. Consequence: server hostnames are **frozen at approval time** (see Refresh).
3. **NO VPN On-Demand.** Tested live: an On-Demand-enabled payload fights manual control of the *other* payloads for macOS's **single personal-VPN slot** — observed both configs stuck "Connecting" forever with **all traffic blackholed** (no internet at all until one was toggled off by hand). Auto-reconnect is instead event-driven via launchd (next point). Do not re-add `OnDemandEnabled/OnDemandRules` to any payload.
4. **Reconnect = launchd one-shot, not a daemon.** `RunAtLoad` (login) + `WatchPaths` on `/var/run/resolv.conf` + `/etc/resolv.conf` (fires on every network change: wake, Wi-Fi join, tunnel up/down). The script runs for seconds and exits; `ThrottleInterval 15` caps event bursts. **No StartInterval, no KeepAlive, no polling — keep it that way.**
5. **Reboot → Singapore.** Boot detection compares `sysctl -n kern.boottime` against the stored `boot-id`. (A `/tmp` marker was rejected: macOS purges `/tmp` files after ~3 days of uptime → false "boot" mid-session.)
6. **Control tool = `vpnutil`** (Homebrew `timac/vpnstatus/vpnutil`, tap trusted via `brew trust timac/vpnstatus`). It is the only CLI that can start/stop profile-installed IKEv2 configs — `scutil --nc` cannot even see them. `networksetup` can't either.
7. **Secrets stay out of the repo**: credentials + rendered mobileconfig live only in `~/.config/nordvpn-native/`, 0600. Repo scripts contain no secrets.

## Concurrency & correctness rules (hard-won, keep intact)

- **Single-slot rule:** never `vpnutil start` a config while another is `Connected`/`Connecting` — two `Connecting` configs deadlock the slot and blackhole all traffic. Both scripts strictly stop→confirm-down→start.
- **Never leave a dangling `Connecting`:** a failed start is always followed by `vpnutil stop` of the target (a wedged `Connecting` also blackholes traffic).
- **Shared lock** `/tmp/nordvpn-native.lock` (mkdir-atomic): the CLI waits up to 60 s for it; the watcher takes it **non-blocking** (CLI wins) and only around its mutating phase. Tunnel transitions rewrite resolv.conf → the watcher fires after every `nord` action; the lock + its post-lock re-checks make that harmless.
- **`nord off` writes `enabled=0` BEFORE stopping** so a mid-flight watcher aborts instead of redialing.
- **Success detection:** `vpnutil`'s status can lag the tunnel by minutes (observed on slow servers). Success = target reaches `Connected` within 45 s, **or** still `Connecting` but the public exit IP moved off the pre-start baseline. Country-based checks are wrong twice over: the user may physically be in the target country, and some pins are virtual locations (see VN caveat).
- The watcher respects an already-Connected config (a human choice via System Settings is never overridden).

## Flows

- **`nord france`** → lock → stop all → start Nord-FR → write `country=fr`, `enabled=1` → `sketchybar --trigger vpn_change`.
- **Login / wake / network change** → launchd fires `nord-connect.sh` → boot-id check (reboot? reset sg/enabled) → if enabled && nothing connected/connecting → wait for real network (≤120 s, one-shot, then exits) → lock → re-check → start saved country.
- **`nord off`** → `enabled=0` → stop all. Durable across network events; only a reboot (or `nord on`/switch/toggle) re-enables.
- **`nord refresh`** → regenerate bundle from current API "best" per country → `open` it → **one manual approval** in System Settings (General → Device Management → NordVPN Native IKEv2 → Install). The profile's top-level `PayloadUUID` is content-derived — unchanged pins produce the identical profile (macOS ignores it), changed pins register as an update. Payload UUIDs are stable (uuid5) so the install **replaces** rather than duplicates.

## Ops

```sh
nord status      # target, enabled, tunnels, exit IP, pinned-server DNS health
nord list        # countries, pins, live states
tail -f ~/workspace/logs/nordvpn-native.log
launchctl kickstart gui/$(id -u)/com.teazyou.nordvpn-native   # force a watcher run
launchctl bootout  gui/$(id -u)/com.teazyou.nordvpn-native    # disable the agent
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.teazyou.nordvpn-native.plist  # re-enable
```

**Stale pins / dead server:** connect failures and `nord status` DNS checks set `~/.config/nordvpn-native/refresh-needed` → the bar's VPN icon turns **orange** → run `nord refresh` (one approval click). The flag clears on the next successful connect or healthy `status`.

**Fresh-Mac note:** deliberately **NOT** wired into `installation.sh`/`setup_symlinks.sh` (same policy as the quota-keepalive agent) — it needs interactive pieces regardless: service credentials from the Nord dashboard (email-code gated), one profile approval, `brew trust timac/vpnstatus`, and the LaunchAgent symlink + `launchctl bootstrap` above.

## Caveats

- **Vietnam pins are virtual locations** — they geolocate to Hong Kong (e.g. ipinfo says HK). Anthropic/Claude is unavailable there → **using `nord vietnam` logs Claude Code out**. Known, accepted; prefer sg/my when using Claude.
- vpnutil `status` lag: `Connecting` shown while already routing (see success detection above).
- The IKEv2 password sits in the installed profile; the profile file itself is 0600 and the account password is never involved (service credentials only, rotatable from the Nord dashboard).
- `configs/dot-claude-preset/` note: the sketchybar plugin needs `/opt/homebrew/bin` prepended to PATH (sketchybar's env has no Homebrew) — already handled inside `plugins/vpn.sh`.

## Verified test matrix (2026-07-22, macOS 26.5.2)

All six countries connect via `nord <cc>`; off durable across a forced watcher run; toggle cycle; boot simulation (garbage boot-id + kickstart → reset to sg/enabled + auto-connect in ~7 s); Wi-Fi flap self-heal; bar states red/orange/grey + CC label; single approval covers all 6 payloads.
