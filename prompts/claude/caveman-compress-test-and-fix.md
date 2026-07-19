# caveman-compress — e2e test & fix (handover)

Paste-prompt: end-to-end test `scripts/claude/caveman_compress.sh`, fix it if broken.

---

Task: prove `scripts/claude/caveman_compress.sh` works end-to-end, fix it if it doesn't. It has NEVER been e2e-tested — only `bash -n` + the arg-validation paths (usage / bad flag / missing file).

Read first: repo `CLAUDE.md` + the `_index.md` entry for the script, the script itself, and `configs/dot-claude/commands/caveman-compress.md` (= `~/.claude/commands/caveman-compress.md`, the `/caveman-compress` slash command it drives).

## Spec invariants — a fix must never change these
- CLI: `caveman-compress [--opus|--sonnet|--haiku] [--low|--medium|--high|--xhigh|--max] [--<seconds>] <file>`; defaults opus / xhigh / 600s timeout.
- NEVER `claude -p` (print mode soon removed from subscription plans): background **interactive** session under a pseudo-TTY (`script -q <log>`), stdout discarded (silent run).
- Records target file mtime+size -> polls every 300ms -> on change: grace (≤60s, until `</result>` appears in log) -> kill session -> print the `<result>…</result>` block -> rm log -> exit 0. On timeout: kill, KEEP log, exit 1.
- Kill ONLY the session it started: pty-wrapper PID must still be a direct child of the script (ppid check) + claude child collected via `pgrep -P` before the kill. This guarantee must survive any fix.
- bash 3.2 compatible, macOS `stat -f`.

## Test procedure — cheap models only, every run burns real quota
1. Scratch file OUTSIDE the repo (mktemp dir): ~10 lines of verbose prose containing concrete facts (paths, numbers, commands) so compression is verifiable.
2. Snapshot `pgrep -fl claude` (your own session is a claude process — diff before/after, don't just count).
3. From `~/workspace` (trusted cwd): `./scripts/claude/caveman_compress.sh --haiku --low --240 <scratch-file>` — Bash tool timeout ≥300000ms.
4. PASS = exit 0; stdout = compression report (orig -> new bytes, % saved); scratch file rewritten telegraphic with ALL facts preserved; temp log deleted; no new claude/`script` processes left running.
5. FAIL -> read the log (path printed on stderr; raw pty typescript — strip ANSI first, e.g. `perl -pe 's/\x1b\[[0-9;:?]*[ -\/]*[@-~]//g'`). Suspects in likely order:
   - trust/permission dialog blocked the session (prompt UI visible in log) — the command's `allowed-tools` frontmatter + the script's `--add-dir` are supposed to prevent this;
   - `/caveman-compress` not found (command file not visible at `~/.claude/commands/`);
   - `</result>` split by TUI line-wrap so `grep`/extraction misses it;
   - edit lands but final answer never streams within the 60s grace;
   - wrong claude binary (`CAVEMAN_CLAUDE_BIN` fallback logic).
6. After any fix: re-run (still `--haiku --low`) until it PASSES twice in a row. Kill stray sessions only if you can attribute the PID to your own runs.

## Rules for fixes
- Fix mechanics, not behavior; keep every invariant above.
- May touch the script and/or the slash-command file. Slash command changed -> commit+push submodule `configs/dot-claude` FIRST, then the parent repo.
- Behavior/mechanics changed -> update the script's header comment AND its `_index.md` entry in the same change.
- NEVER bare `git commit` (a concurrent process stages files in this repo): `git add <paths> && git commit -m "…" -- <paths>`, then push. Commit+push once the test passes.
- Delete all scratch artifacts when done.

Report back: what failed, root cause, fix applied, proof (final run stdout + scratch file before/after byte counts).
