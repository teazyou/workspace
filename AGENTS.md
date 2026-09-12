# Workspace Instructions

`~/workspace` is the centralized source of truth for the managed parts of this macOS environment: app configs, zsh configs/aliases, helper shell functions, and install/system scripts.

## Activation model

Many config files in this repo are symlinked into the locations that use them (for example, `~/.zshrc` links to a file here). Editing a symlinked source makes the new file contents available at the linked path, but each application decides when to reload them. Other domains use their documented activation method instead of a symlink. In particular, macOS preferences are a saved snapshot applied by the macOS setup helper; changes made in System Settings are not captured into the repository automatically. Keep new managed configuration here and document how it is activated so the repo remains the central point for backup, export, and edit.

## Repository map

See _index.md for the map of what lives where (directories, key files, symlink targets).

The window-manager setup (aerospace + borders + sketchybar) is documented in `docs/window-manager/guide-window-manager.md`. All prose/context docs live in `docs/` (subfoldered by area); see the `## docs` section of `_index.md` for the full list.

## Conventions

- **Read the associated context before acting.** Before working on any request, identify its topic and read the matching guide under `docs/` (and the relevant config files) FIRST — so you already know what exists, where it is, and why, instead of self-discovering by trial and error. The full list of guides is the `## docs` section of `_index.md`; start every task from `_index.md` + this file.
- **Keep the map and the guides current.** When you add, move, remove, rename, or change the behavior of a file or symlink target, update BOTH `_index.md` AND the affected `docs/` guide in the same change so they never drift. Any new context/guide/reference documentation you write MUST live in `docs/`, in the matching area subfolder (create one if needed) — never place prose docs next to the configs they describe.
- **NEVER lint in this folder or plan for it.** Linting is done manually.

## Index

[_index.md](_index.md)
