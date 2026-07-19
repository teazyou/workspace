# Patch Version Watcher

An experimental background LaunchAgent that re-applies this repo's two
hand-maintained app patches automatically **after the app that owns them
updates**. Both patches live inside a bundle that the app's own updater
replaces wholesale on every update, silently wiping the edit — so without this
watcher you have to remember to re-run each patch by hand after every update.

**Read this when:** the transparency / panel styling "came back to stock" after
an update, changing the poll interval, adding a third tracked patch, or touching
[`scripts/patch-watcher.sh`](../../scripts/patch-watcher.sh) /
[`configs/claude/com.teazyou.patch-watcher.plist`](../../configs/claude/com.teazyou.patch-watcher.plist).

---

## What it tracks (two patches, two version sources)

| Patch script | Invalidated by | Version read |
|---|---|---|
| [`scripts/obsidian/patch-transparency.sh`](../../scripts/obsidian/patch-transparency.sh) | **Obsidian app** version | `defaults read /Applications/Obsidian.app/Contents/Info CFBundleShortVersionString` |
| [`scripts/claude/patch-vscode-panel.sh`](../../scripts/claude/patch-vscode-panel.sh) | **Claude Code VS Code EXTENSION** version | newest `~/.vscode/extensions/anthropic.claude-code-*` dir, version parsed from the name |

> **Why the Claude one is the EXTENSION version, not the VS Code app version:**
> that patch edits files *inside the Claude Code extension's own directory*
> (`webview/index.css` + `extension.js`). Updating VS Code itself leaves those
> files untouched; only an **extension** bump ships fresh copies that undo the
> patch. So the extension version is the correct invalidation signal — tracking
> the VS Code app version would both miss real invalidations and trigger
> pointless re-patches.

The extension version is parsed from the newest matching directory name (the
same `ls -dt … | head -1` selection the patch script itself uses, so the version
recorded always matches the copy that was actually patched):

```
anthropic.claude-code-2.1.215-darwin-arm64   ->   2.1.215
```

---

## Watcher logic (per tool, each tick)

1. Read the current version. If the app / extension isn't installed, **skip that
   tool quietly** (no log line).
2. Compare to the last-recorded version in the state file.
3. If they match, do nothing.
4. If they differ (or nothing is recorded yet):
   - **Obsidian only:** if Obsidian is currently running (`pgrep -x Obsidian`),
     log `deferred (Obsidian running)` and **leave the recorded version
     unchanged** so it retries on a later tick once the app is closed. See the
     safety note below.
   - Otherwise run the patch script. On **success** record the new version; on
     **failure** log it and leave the recorded version unchanged so it retries
     next tick.

Because the patch scripts are idempotent, the very first tick (empty state)
simply applies each patch once and records the version — no special first-run
handling needed.

### Obsidian defer-while-running safety

`patch-transparency.sh` **quits Obsidian** if it finds it running (the asar it
rewrites is memory-mapped while the app is open). Having a background timer force
your editor closed would be hostile, so the watcher never invokes it while
Obsidian is up: it logs the pending update and waits. The Claude panel patch has
no such hazard (it only rewrites files; you just reload the VS Code window when
convenient), so it is **never** deferred.

---

## State files

One bare-version file per tool under `logs/patch_state/` (gitignored via
`logs/*`):

```
logs/patch_state/obsidian.version          # e.g. 1.12.7
logs/patch_state/claude-code-ext.version   # e.g. 2.1.215
```

Each file holds just the last successfully-patched version string. Deleting a
file (or the whole dir) forces a re-patch on the next tick — the simplest way to
manually force a re-apply through the watcher. The activity log is
`logs/patch_watcher.log` (self-trimmed to the last 1000 lines); launchd's own
stdout/stderr go to `logs/patch_watcher.launchd.{out,err}.log`.

---

## The LaunchAgent

[`configs/claude/com.teazyou.patch-watcher.plist`](../../configs/claude/com.teazyou.patch-watcher.plist)
— Label `com.teazyou.patch-watcher`, `StartInterval` **1800** (30 min),
`RunAtLoad` true, invokes `scripts/patch-watcher.sh` via `/bin/bash`. Symlinked
into `~/Library/LaunchAgents/`.

Like the [quota keepalive](../../scripts/claude/quota_keepalive.sh) agent this is
**EXPERIMENTAL and deliberately NOT wired into the fresh-Mac install flow**
(`installation.sh` / `setup_symlinks.sh`). Load it by hand:

```sh
# symlink the plist into place (once)
ln -sf ~/workspace/configs/claude/com.teazyou.patch-watcher.plist \
       ~/Library/LaunchAgents/com.teazyou.patch-watcher.plist

# load  (RunAtLoad fires one tick immediately)
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.teazyou.patch-watcher.plist

# unload / disable
launchctl bootout gui/$UID/com.teazyou.patch-watcher
rm ~/Library/LaunchAgents/com.teazyou.patch-watcher.plist
```

To reload after editing the plist: `bootout` then `bootstrap` again.

---

## Performance & interval rationale

The per-tick cost is tiny: ~2 plist/dir reads plus a couple of `pgrep`s — a few
milliseconds, **no network**, negligible CPU. Nothing runs unless a version
actually changed.

A 5-minute poll would be equally harmless performance-wise, but it is wasteful:
app / extension updates land only every few days to weeks, so the watcher would
do thousands of no-op ticks between real events. **30 minutes** means at most
~30 min of running the unpatched app after an update lands — and that only
matters once you actually reopen the app and notice the styling reverted. That
trade-off is comfortably in favour of the lazier interval.

**Changing the interval:** edit the `<integer>` under `StartInterval` in the
plist (value is in **seconds**: 1800 = 30 min, 900 = 15 min, 300 = 5 min), then
`bootout` + `bootstrap` to reload. The script itself is schedule-agnostic.
