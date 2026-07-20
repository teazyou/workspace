# Claude Quota Keepalive (experimental)

An **experimental** LaunchAgent that keeps the Claude Code subscription's 5-hour
usage block cycling, so a long idle gap doesn't cost you a full fresh block on
your next real prompt. It is deliberately **not** part of the fresh-Mac install
flow — you load it by hand.

**Read this when:** changing the ping cadence, the model, the wait time, or the
work dir; or when deciding whether to enable/disable it on a machine.

---

## What it is

The subscription quota works in **5-hour blocks that start on the FIRST message
sent**. If you go quiet, the block eventually expires; your next prompt then
starts a brand-new full 5-hour block.

[`scripts/claude/quota_keepalive.sh`](../../scripts/claude/quota_keepalive.sh)
sends a **near-zero-cost `"hello"` to the `haiku` model** on every run. Driven
by the LaunchAgent every **hour**, a new block therefore starts at most
~1 h after the previous one expires. Net effect: after any long absence the
current block is already partly elapsed and resets sooner, instead of restarting
the full 5 hours on your first real prompt.

## The mechanism

- Interactive `claude` (**not** `-p` print mode) needs a TTY for its Ink UI, and
  launchd provides none. The call is wrapped in **`script -q /dev/null`**, which
  allocates a pseudo-TTY.
- The session is **killed after `WAIT_SECONDS` (15s)** — by then the request has
  already been sent, which is all that's needed to (re)arm the quota block. The
  wrapper's child `claude` PID is collected (`pgrep -P`) before the wrapper is
  killed, then both are `kill -9`'d.
- The ping runs from **`~/tmp`** (`WORK_DIR`), created if missing.
- **First-run trust seeding:** a headless run can't answer the folder-trust
  dialog, which would block the prompt from ever submitting. On first run the
  script uses `jq` to set `hasTrustDialogAccepted: true` for `~/tmp` in
  **`~/.claude.json`** (requires `jq`).
- Each run appends one line to the log.

## Where everything lives

| Piece | Path |
|---|---|
| Script | [`scripts/claude/quota_keepalive.sh`](../../scripts/claude/quota_keepalive.sh) |
| LaunchAgent plist | [`configs/claude/com.teazyou.claude-quota-keepalive.plist`](../../configs/claude/com.teazyou.claude-quota-keepalive.plist) — symlinked into `~/Library/LaunchAgents/` |
| Run log | `logs/quota_keepalive.log` (one line per run) |
| launchd stderr | `logs/quota_keepalive.launchd.err.log` |
| Trust flag written | `~/.claude.json` (`.projects["~/tmp"].hasTrustDialogAccepted`) |

Plist essentials: `Label` = `com.teazyou.claude-quota-keepalive`,
`StartInterval` = **3600** (hourly), `RunAtLoad` = true. `ProgramArguments`
runs `/bin/bash scripts/claude/quota_keepalive.sh`.

Overridable via env: `QUOTA_KEEPALIVE_CLAUDE_BIN` (defaults to
`~/.local/bin/claude`).

## Enable / disable

**Experimental and NOT wired into the fresh-Mac install flow** (`installation.sh`
/ `setup_symlinks.sh`) — you load it by hand.

Enable (load):

```sh
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.teazyou.claude-quota-keepalive.plist
```

Disable (unload, then optionally remove the symlink):

```sh
launchctl bootout gui/$UID/com.teazyou.claude-quota-keepalive
rm ~/Library/LaunchAgents/com.teazyou.claude-quota-keepalive.plist
```
