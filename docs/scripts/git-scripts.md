# Git & Maintenance Scripts

How this repo’s transparent `git push` wrapper routes pushes through a cleanup script,
and how the other Git workflow helpers behave.

**Read this when:** touching [`scripts/git/`](../../scripts/git/),
[`zsh/alias/git.zsh`](../../zsh/alias/git.zsh), or the supporting cleanup script.

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
  what `gpush.sh` itself does for the push, so it doesn't recurse into itself).
- The function only exists in an interactive zsh that sourced `git.zsh`. A LaunchAgent or a
  `bash` subshell does **not** have it; scripts invoke `gpush.sh` by path when they need
  the wrapper.

The matching aliases in the same file: `gst`→`gstatus.sh`, `gco`→`gcommit.sh`,
`gpu`→`gpush.sh`, plus `gcreate`/`gdelete` (branch create/delete) and `gbranch`/`gclean`.

---

## The git helper scripts (`scripts/git/`)

All five print coloured `[ … ]` log lines using the `CW8`/`COK`/`CKO`/`CWH` color vars
(from `zsh/configs/colors.zsh`, present in an interactive shell). When these variables
are unset in a subshell, their empty values simply omit the colors.

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
   `<owner>/<name>` parsed from `remote.origin.url`; currently no repository-specific
   actions are configured) and
   `run_local_post_push_hook` (runs an executable `.git/hooks/post-push` if one exists).
5. On failure: prints "Push failed." and exits 1.

---

## Supporting one-off scripts

- [`dstore.sh`](../../scripts/dstore.sh) — recursively deletes both `.DS_Store` **and**
  `_DS_Store` files from the current tree. `dstore.sh silent` (used by `gpush.sh`) suppresses
  per-step echoes and errors; bare `dstore.sh` is verbose for manual use.
