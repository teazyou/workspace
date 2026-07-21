# CLAUDE.md

`~/workspace` is the centralized source of truth for this macOS environment: app configs, zsh configs/aliases, helper shell functions, and install/system scripts.

## Symlink model

Config files in this repo are **symlinked** into their real system locations (e.g. `~/.zshrc` links to a file here). Editing a file here changes live system behavior immediately. New config files should be saved here and symlinked into place so the repo stays the single point for backup, export, and edit.

## Repository map

See _index.md for the map of what lives where (directories, key files, symlink targets).

The window-manager setup (aerospace + borders + sketchybar) is documented in `docs/window-manager/guide-window-manager.md`. All prose/context docs live in `docs/` (subfoldered by area); see the `## docs` section of `_index.md` for the full list.

## Conventions

- **Read the associated context before acting.** Before working on any request, identify its topic and read the matching guide under `docs/` (and the relevant config files) FIRST — so you already know what exists, where it is, and why, instead of self-discovering by trial and error. The full list of guides is the `## docs` section of `_index.md`; start every task from `_index.md` + this file.
- **Keep the map and the guides current.** When you add, move, remove, rename, or change the behavior of a file or symlink target, update BOTH `_index.md` AND the affected `docs/` guide in the same change so they never drift. Any new context/guide/reference documentation you write MUST live in `docs/`, in the matching area subfolder (create one if needed) — never place prose docs next to the configs they describe.
- **NEVER lint in this folder or plan for it.** Linting is done manually.
- **`configs/dot-claude/` (= `~/.claude`) is SELF-CONTAINED.** The private dot-claude submodule alone must deploy the exact same Claude Code config on a fresh machine: everything `~/.claude` needs (settings, helper scripts like `statusline.sh`, agents, skills, commands, hooks) lives INSIDE the submodule, wired via `~/.claude/...` paths ONLY — never absolute machine paths (`/Users/<name>/...`), never paths into other repos (`~/workspace/...`). Deploy = clone + symlink `~/.claude` → done, nothing else needed. New committable config must be re-allowed in BOTH allowlists (the submodule's `.gitignore` + the mirrored block in this repo's root `.gitignore`). Full philosophy: the submodule's README.md.

## Index

@../_index.md