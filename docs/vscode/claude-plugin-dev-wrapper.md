# Loading a Claude Code plugin from disk inside the VS Code extension

Goal: get the terminal behaviour

```sh
claude --plugin-dir /Users/teazyou/dev/client-edouard/.sopaios
```

(load the plugin from its working copy every session, never a cached install)
when Claude Code runs **inside** the VS Code extension (`anthropic.claude-code`),
which spawns the `claude` process itself and exposes no setting for CLI args.

## The hook

The extension has one relevant setting:

| Setting | Description |
|---|---|
| `claudeCode.claudeProcessWrapper` | "Executable path used to launch the Claude process." |

It takes a **path, not a command line** — flags cannot be typed into it.

## Why a wrapper script works

From `extension.js` in `~/.vscode/extensions/anthropic.claude-code-<ver>-darwin-arm64/`,
`resolveClaudeBinary()`:

- reads `claudeCode.claudeProcessWrapper`;
- if non-empty, returns `{ pathToClaudeCodeExecutable: <setting>, executableArgs, env }`
  and returns early, skipping every other binary-resolution path;
- `executableArgs` is non-empty **only** if the extension finds a bundled CLI —
  `resources/native-binaries/<platform>-<arch>/claude`, `resources/native-binary/claude`,
  or `resources/claude-code/cli.js` (then `executableArgs = [process.execPath, cli.js]`).

On this install neither `resources/native-binaries/` nor `resources/claude-code/`
exists, so `executableArgs` is `[]`: **the setting's value is spawned directly as
the claude executable**, receiving only the extension's own runtime flags (the
stream-json / print-mode flags it uses to drive the SDK). Nothing is prepended.

So: point the setting at a script that `exec`s the real binary with `--plugin-dir`
injected ahead of `"$@"`. That script is [`scripts/claude/sopaios.sh`](../../scripts/claude/sopaios.sh)
(also fronted by the `sopaios` terminal alias, `zsh/alias/claude.zsh`).

## Wiring it

1. `chmod +x scripts/claude/sopaios.sh` (already done).
2. Set, in VS Code settings (Workspace `.vscode/settings.json` preferred, User works too):

   ```json
   { "claudeCode.claudeProcessWrapper": "/Users/teazyou/workspace/scripts/claude/sopaios.sh" }
   ```

3. **Reload the VS Code window** — the setting is only read when the process is spawned.

## Gotchas

- **Absolute path to `claude` inside the script is mandatory.** The extension
  host's `PATH` is not the interactive shell's `PATH`, so a bare `claude` may not
  resolve. The script defaults to `$HOME/.local/bin/claude` (a symlink to the
  versioned Mach-O arm64 binary), overridable with `SOPAIOS_CLAUDE_BIN`.
- **`executableArgs: []` is install-specific.** If a future extension version
  ships a bundled CLI, the wrapper is invoked as `wrapper <node> <cli.js> ...args`
  instead. The script detects that shape (arg 1 = executable file, arg 2 = an
  existing `*.js`) and execs `node cli.js --plugin-dir … "$@"`. Re-check this after
  extension updates.
- **Setting scope.** It is read via `workspace.getConfiguration("claudeCode")`, so
  it should be settable per-workspace. If it turns out to be global-only, add a
  `case "$PWD" in` guard in the wrapper so `--plugin-dir` is only injected for this
  project and everything else passes through untouched.
- **Stale namespace.** An older `claude-code.*` settings namespace was migrated to
  `claudeCode.*`; docs/config may still reference `claude-code.claudeProcessWrapper`.
- The script exits 1 with a message on stderr if the plugin dir or the binary is
  missing, rather than silently launching a plugin-less session.

Plugin dir is overridable with `SOPAIOS_PLUGIN_DIR` (default
`/Users/teazyou/dev/client-edouard/.sopaios`).
