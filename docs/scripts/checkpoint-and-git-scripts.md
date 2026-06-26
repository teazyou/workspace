# Checkpoint & Git/Maintenance Scripts

How automatic "checkpoint" commits work, and how this repo's **transparent `git push`
wrapper** reroutes every push through a cleanup script. These two systems are linked: the
checkpoint job ultimately calls the same `gpush.sh` your interactive `git push` does.

**Read this when:** debugging why a repo did (or didn't) auto-commit/auto-push, changing
which repos are checkpointed or the schedule, touching anything under
[`scripts/git/`](../../scripts/git/) or the `scripts/checkpoint_*` files, or wondering why
`git push` behaves oddly in a shell (it's intercepted — see below).

---

## The `git push` interception (the surprise)

[`zsh/alias/git.zsh`](../../zsh/alias/git.zsh) defines a shell **function** named `git`
(not an alias) that shadows the real binary:

```sh
git() {
  if [ "$1" = "push" ]; then
    shift
    sh "$SCRIPTS/git/gpush.sh" "$@"
  else
    command git "$@"
  fi
}
```

So in any interactive shell, **`git push …` does NOT run `/usr/bin/git push`** — it runs
[`gpush.sh`](../../scripts/git/gpush.sh) with the remaining args. Every other git subcommand
passes straight through via `command git`. Implications:

- A bare `git push` in this environment cleans `.DS_Store`, prints status, then pushes — see
  the wrapper below. This is intentional; don't "fix" a push that looks like it's doing extra
  work.
- Scripts that must bypass the wrapper call `command git push` explicitly (that is exactly
  what `gpush.sh` itself does on its final line, so it doesn't recurse into itself).
- The function only exists in an interactive zsh that sourced `git.zsh`. A LaunchAgent or a
  `bash` subshell does **not** have it; those reach `gpush.sh` only because the checkpoint
  code calls it by path.

The matching aliases in the same file: `gst`→`gstatus.sh`, `gco`→`gcommit.sh`,
`gpu`→`gpush.sh`, plus `gcreate`/`gdelete` (branch create/delete) and `gbranch`/`gclean`.

---

## The git helper scripts (`scripts/git/`)

All five print coloured `[ … ]` log lines using the `CW8`/`COK`/`CKO`/`CWH` color vars
(from `zsh/configs/colors.zsh`, present in an interactive shell; the checkpoint cron also
sets a PATH but those vars are simply empty there, which is harmless).

| Script | What it does |
|---|---|
| [`gstatus.sh`](../../scripts/git/gstatus.sh) | `git status -s`. Exit **1** if not a git repo (status code 128), exit **2** if the tree is already clean (`git status --porcelain` empty), else 0. Used as a precondition gate by the others. |
| [`gcommit.sh`](../../scripts/git/gcommit.sh) | `git commit -m <msg>`. With an arg, uses it as the message; with no arg, prompts interactively (blank = cancel). Runs `dstore.sh silent` + `gstatus.sh` first. Commits only — **never pushes** ("Done! (not pushed!)"). Exits non-zero when there's nothing to commit. |
| [`gpush.sh`](../../scripts/git/gpush.sh) | The push wrapper (below). |
| [`gcreate.sh`](../../scripts/git/gcreate.sh) | `git checkout -b <branch>` then `git push --set-upstream origin <branch>`. (Uses `command`-bypassing `git push`? No — it calls plain `git push`, but inside a script run via `sh`, so the zsh `git()` function does not apply; it hits the real binary.) |
| [`gdelete.sh`](../../scripts/git/gdelete.sh) | `git branch -D <branch>` → `git push origin :<branch>` (delete remote) → `git remote prune origin`. |

### `gpush.sh` — the transparent push wrapper

Pipeline on every push:

1. `sh dstore.sh silent` — strip `.DS_Store` / `_DS_Store` from the tree (aborts the push if
   that fails).
2. `gstatus.sh` — print `git status -s`.
3. `command git push "$@"` — the **real** push, with all forwarded args. `command` is what
   keeps it from re-entering the zsh `git()` shadow.
4. On success: `run_repo_specific_cleanup` (a per-repo extension point matched on the
   `<owner>/<name>` parsed from `remote.origin.url`; currently every block is commented, so
   it's a no-op template — the `secondbrain` aggressive-gc block is intentionally disabled
   because the hourly checkpoint would otherwise gc the vault every idle hour) and
   `run_local_post_push_hook` (runs an executable `.git/hooks/post-push` if one exists).
5. On failure: prints "Push failed." and exits 1 (so the checkpoint loop treats it as
   unpushed and retries next run).

---

## The checkpoint system (auto-commit + auto-push)

Three files plus a LaunchAgent. The shared logic lives in
[`checkpoint_functions.sh`](../../scripts/checkpoint_functions.sh); two different front-ends
drive it with **opposite gating**.

### Watched repos (`CHECKPOINT_FOLDERS`)

Defined in `checkpoint_functions.sh`, **in this order**:

1. `~/workspace/configs/dot-claude` — the private submodule, **listed first on purpose** so
   its own commit is pushed *before* the parent repo records the bumped gitlink.
2. `~/workspace`
3. `~/secondbrain`

`checkpoint_folder` accepts both a `.git` *directory* (normal repo) and a `.git` *file* (a
submodule's `gitdir:` pointer), or it would skip the submodule.

### `checkpoint_folder()` — the per-repo action

`git add -A` → `gcommit.sh "checkpoint"` (not `&&`-chained, because gcommit exits non-zero on
an empty tree and that must not gate the push) → push **only when the local branch is ahead
of upstream** (`git rev-list --count @{u}..HEAD != 0`, a network-free local check, so an idle
repo doesn't do a pointless push round-trip). The ahead-check **fails open**: no upstream /
detached HEAD ⇒ empty count ⇒ `"" != "0"` holds ⇒ `gpush.sh` still runs. A commit left behind
by an earlier failed push still counts as "ahead", so it gets retried.

### Two front-ends, opposite gates

- [`checkpoint_all.sh`](../../scripts/checkpoint_all.sh) — **manual** runner: loops
  `CHECKPOINT_FOLDERS` and calls `checkpoint_folder` on each **unconditionally**. Use it to
  force a checkpoint now (fronted by the `checkpoint` alias group in
  `zsh/alias/checkpoint.zsh`).
- [`checkpoint_cronjob.sh`](../../scripts/checkpoint_cronjob.sh) — the **scheduled**
  (LaunchAgent) entry, with an **inverted eligibility gate**: it checkpoints a repo **only
  when its working tree is byte-for-byte UNCHANGED since the previous run** (i.e. you've
  stopped typing), so work-in-progress is never committed mid-edit.

The gate is a git **content fingerprint**, not `find -mmin`: `working_tree_signature()`
stages the whole tree (`git add -A`) into a *throwaway* `GIT_INDEX_FILE` and takes its
`write-tree` hash. Because it stages into a scratch index that honours `.gitignore`, the
repo's real index is untouched and ignored paths (`logs/`, the state dir, …) don't perturb
the hash. The per-repo previous fingerprint is cached in
`logs/checkpoint_state/<slug>.sig`. Logic per repo:

| Condition | Action |
|---|---|
| signature unavailable (`sig` empty) | `skip … (signature unavailable)` |
| `sig != prev` (changed in the last interval) | `skip … (modified in the last hour)` — still typing |
| `sig == prev` (idle) | `checkpoint <folder>` → `checkpoint_folder` |

There is deliberately **no "skip if clean" shortcut**: an idle-but-clean repo is still run
through `checkpoint_folder`, so a commit an earlier run made but couldn't push (network/cred
failure) gets its push retried. The log is at `logs/checkpoint_cron.log` and self-trims to
the last 1000 lines.

> **Net behaviour contrast:** `checkpoint_all.sh` = "commit/push everything *right now*".
> `checkpoint_cronjob.sh` = "commit/push only the repos that went *quiet* since last hour."
> Both ultimately funnel through `gcommit.sh` + `gpush.sh`.

### The schedule (LaunchAgent, not cron)

[`install_checkpoint_launchd.sh`](../../scripts/installs/install_checkpoint_launchd.sh) (step
16 of the install — see [bootstrap-flow.md](../install/bootstrap-flow.md)) writes
`~/Library/LaunchAgents/com.teazyou.checkpoint.plist` with:

- `StartCalendarInterval` → **Minute 0**: fires at **minute 0 of every hour** (this is where
  the hourly cadence is actually defined — the scripts themselves are schedule-agnostic).
- `RunAtLoad` → **false**: it does *not* fire on login/bootstrap.
- Logs to `logs/checkpoint_launchd.{out,err}.log`.

**Why a LaunchAgent and not cron:** the checkpoint `git push` uses an HTTPS remote whose
credentials live in the macOS **login keychain**. cron runs outside the GUI login session and
can't reach that keychain (`fatal: could not read Username for 'https://github.com'`), so push
would fail; a LaunchAgent runs inside the user's GUI session and can. The installer also
**migrates away** any leftover `checkpoint_cronjob.sh` crontab entry, and re-bootstraps the
agent on every install so the latest plist wins.

> **Fresh-machine note:** the first hourly push can still fail until the GitHub credential is
> cached in the login keychain (which happens the first time you run an interactive
> `git push`/`git clone` over HTTPS). `git add`/`commit` succeed regardless and the job
> self-heals on the next run.

---

## Supporting one-off scripts

- [`dstore.sh`](../../scripts/dstore.sh) — recursively deletes both `.DS_Store` **and**
  `_DS_Store` files from the current tree. `dstore.sh silent` (used by `gpush.sh`) suppresses
  per-step echoes and errors; bare `dstore.sh` is verbose for manual use.
