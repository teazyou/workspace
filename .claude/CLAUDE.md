# CLAUDE.md

`~/workspace` is the centralized source of truth for this macOS environment: app configs, zsh configs/aliases, helper shell functions, and install/system scripts.

## Symlink model

Config files in this repo are **symlinked** into their real system locations (e.g. `~/.zshrc` links to a file here). Editing a file here changes live system behavior immediately. New config files should be saved here and symlinked into place so the repo stays the single point for backup, export, and edit.

## Repository map

See @../_index.md for the map of what lives where (directories, key files, symlink targets).

The window-manager setup (aerospace + borders + sketchybar) is documented in `configs/guide-window-manager.md`.

## Conventions

- **Keep `_index.md` in sync.** When you add, move, remove, or rename a file, or change a symlink target, update `_index.md` in the same change so the map stays accurate.
- **NEVER lint in this folder or plan for it.** Linting is done manually.

## Index

@../_index.md